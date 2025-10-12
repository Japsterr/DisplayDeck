unit AuthServiceImplementation;

interface

uses
  System.SysUtils,
  System.Hash,
  XData.Server.Module,
  XData.Service.Common,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  Data.DB,
  uEntities,
  AuthService,
  Winapi.Windows;

type
  [ServiceImplementation]
  TAuthService = class(TInterfacedObject, IAuthService)
  private
    function GetConnection: TFDConnection;
    function HashPassword(const Password: string): string;
    function VerifyPassword(const Password, Hash: string): Boolean;
    function GenerateJWT(const UserId: Integer; const Email: string): string;
    function GetUserByEmail(const Email: string): TUser;
    procedure LogError(const Msg: string);
  public
    function Register(const Request: TRegisterRequest): TAuthResponse;
    function Login(const Request: TLoginRequest): TAuthResponse;
  end;

implementation

uses
  uServerContainer,
  System.JSON,
  System.DateUtils,
  System.NetEncoding,
  System.IOUtils;

{ TAuthService }

function TAuthService.GetConnection: TFDConnection;
begin
  // Get the shared connection from the server container
  Result := ServerContainer.FDConnection;
  OutputDebugString(PChar('AuthService.GetConnection: Connection object = ' + IntToHex(IntPtr(Result), 8)));
  OutputDebugString(PChar('AuthService.GetConnection: Connection connected = ' + BoolToStr(Result.Connected, True)));
end;

function TAuthService.HashPassword(const Password: string): string;
begin
  // Simple SHA256 hash with salt - in production, use proper password hashing like bcrypt
  Result := THashSHA2.GetHashString(Password + 'DisplayDeckSalt2024', THashSHA2.TSHA2Version.SHA256);
end;

function TAuthService.VerifyPassword(const Password, Hash: string): Boolean;
begin
  Result := HashPassword(Password) = Hash;
end;

function TAuthService.GenerateJWT(const UserId: Integer; const Email: string): string;
begin
  // Simplified JWT implementation for now - in production, use a proper JWT library
  // Format: header.payload.signature (simplified)
  Result := Format('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.%s.%s',
    [TNetEncoding.Base64.Encode(Format('{"userId":%d,"email":"%s","iat":%d,"exp":%d}',
      [UserId, Email, DateTimeToUnix(Now), DateTimeToUnix(IncHour(Now, 24))])).Replace('+', '-').Replace('/', '_').Replace('=', ''),
     TNetEncoding.Base64.Encode('signature').Replace('+', '-').Replace('/', '_').Replace('=', '')]);
end;

function TAuthService.GetUserByEmail(const Email: string): TUser;
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := GetConnection;
    Query.SQL.Text := 'SELECT UserID, OrganizationID, Email, PasswordHash, Role, CreatedAt, UpdatedAt ' +
                      'FROM Users WHERE Email = :Email';
    Query.ParamByName('Email').AsString := Email;
    Query.Open;

    if Query.IsEmpty then
      Exit(nil);

    Result := TUser.Create;
    Result.Id := Query.FieldByName('UserID').AsInteger;
    Result.OrganizationId := Query.FieldByName('OrganizationID').AsInteger;
    Result.Email := Query.FieldByName('Email').AsString;
    Result.PasswordHash := Query.FieldByName('PasswordHash').AsString;
    Result.Role := Query.FieldByName('Role').AsString;
    Result.CreatedAt := Query.FieldByName('CreatedAt').AsDateTime;
    Result.UpdatedAt := Query.FieldByName('UpdatedAt').AsDateTime;
  finally
    Query.Free;
  end;
end;

procedure TAuthService.LogError(const Msg: string);
var
  LogFile: string;
begin
  try
    LogFile := TPath.Combine(ExtractFilePath(ParamStr(0)), 'server_error.log');
    TFile.AppendAllText(LogFile, FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ' ' + Msg + sLineBreak, TEncoding.UTF8);
  except
    // ignore logging errors
  end;
end;

function TAuthService.Register(const Request: TRegisterRequest): TAuthResponse;
var
  Query: TFDQuery;
  ExistingUser: TUser;
  NewOrgId, NewUserId: Integer;
begin
  OutputDebugString(PChar('AuthService.Register: Starting registration for ' + Request.Email));
  Result := TAuthResponse.Create;

  // Check if user already exists
  try
    ExistingUser := GetUserByEmail(Request.Email);
  except
    on E: Exception do
    begin
      LogError('AuthService.Register GetUserByEmail failed: ' + E.ClassName + ': ' + E.Message);
      Result.Success := False;
      Result.Message := 'Registration failed: ' + E.Message;
      Exit;
    end;
  end;
  if Assigned(ExistingUser) then
  begin
    Result.Success := False;
    Result.Message := 'User with this email already exists';
    ExistingUser.Free;
    Exit;
  end;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := GetConnection;

    // Start transaction
    Query.Connection.StartTransaction;

    try
      // Create organization
      Query.SQL.Text := 'INSERT INTO Organizations (Name, CreatedAt, UpdatedAt) ' +
                        'VALUES (:Name, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) ' +
                        'RETURNING OrganizationID';
      Query.ParamByName('Name').AsString := Request.OrganizationName;
      Query.Open;
      NewOrgId := Query.Fields[0].AsInteger;

      // Create user
      Query.SQL.Text := 'INSERT INTO Users (OrganizationID, Email, PasswordHash, Role, CreatedAt, UpdatedAt) ' +
                        'VALUES (:OrgId, :Email, :PasswordHash, :Role, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) ' +
                        'RETURNING UserID';
      Query.ParamByName('OrgId').AsInteger := NewOrgId;
      Query.ParamByName('Email').AsString := Request.Email;
      Query.ParamByName('PasswordHash').AsString := HashPassword(Request.Password);
      Query.ParamByName('Role').AsString := 'Owner';
      Query.Open;
      NewUserId := Query.Fields[0].AsInteger;

      // Create default subscription (Free plan)
      Query.SQL.Text := 'INSERT INTO Subscriptions (OrganizationID, PlanID, Status, CreatedAt, UpdatedAt) ' +
                        'VALUES (:OrgId, 1, :Status, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)';
      Query.ParamByName('OrgId').AsInteger := NewOrgId;
      Query.ParamByName('Status').AsString := 'Active';
      Query.ExecSQL;

      // Commit transaction
      Query.Connection.Commit;

      // Return success response
      Result.Success := True;
      Result.Message := 'Registration successful';
      Result.Token := GenerateJWT(NewUserId, Request.Email);
      Result.User := GetUserByEmail(Request.Email);

    except
      on E: Exception do
      begin
        Query.Connection.Rollback;
        LogError('AuthService.Register failed: ' + E.ClassName + ': ' + E.Message);
        Result.Success := False;
        Result.Message := 'Registration failed: ' + E.Message;
      end;
    end;

  finally
    Query.Free;
  end;
end;

function TAuthService.Login(const Request: TLoginRequest): TAuthResponse;
var
  User: TUser;
begin
  Result := TAuthResponse.Create;

  // Get user by email
  try
    User := GetUserByEmail(Request.Email);
  except
    on E: Exception do
    begin
      LogError('AuthService.Login GetUserByEmail failed: ' + E.ClassName + ': ' + E.Message);
      Result.Success := False;
      Result.Message := 'Login failed: ' + E.Message;
      Exit;
    end;
  end;
  if not Assigned(User) then
  begin
    Result.Success := False;
    Result.Message := 'Invalid email or password';
    Exit;
  end;

  // Verify password
  if not VerifyPassword(Request.Password, User.PasswordHash) then
  begin
    Result.Success := False;
    Result.Message := 'Invalid email or password';
    User.Free;
    Exit;
  end;

  // Return success response
  Result.Success := True;
  Result.Message := 'Login successful';
  Result.Token := GenerateJWT(User.Id, User.Email);
  Result.User := User;
end;

initialization
  OutputDebugString(PChar('Registering AuthService...'));
  RegisterServiceType(TAuthService);
  OutputDebugString(PChar('AuthService registered successfully'));

end.