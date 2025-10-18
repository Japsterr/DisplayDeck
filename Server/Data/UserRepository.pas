unit UserRepository;

interface

uses System.SysUtils, uEntities, FireDAC.Comp.Client;

type
  TUserRepository = class
  public
    class function FindByEmail(const Email: string): TUser;
    class function CreateUser(const OrganizationId: Integer; const Email, Password, Role: string): TUser;
  end;

implementation

uses FireDAC.Stan.Param, uServerContainer, PasswordUtils;

function NewConnection: TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  try
    Result.Params.Assign(ServerContainer.FDConnection.Params);
    Result.LoginPrompt := False;
    Result.Connected := True;
  except
    Result.Free;
    raise;
  end;
end;

function MapUser(const Q: TFDQuery): TUser;
begin
  Result := TUser.Create;
  Result.Id := Q.FieldByName('UserID').AsInteger;
  Result.OrganizationId := Q.FieldByName('OrganizationID').AsInteger;
  Result.Email := Q.FieldByName('Email').AsString;
  Result.PasswordHash := Q.FieldByName('PasswordHash').AsString;
  Result.Role := Q.FieldByName('Role').AsString;
  Result.CreatedAt := Q.FieldByName('CreatedAt').AsDateTime;
  Result.UpdatedAt := Q.FieldByName('UpdatedAt').AsDateTime;
end;

class function TUserRepository.FindByEmail(const Email: string): TUser;
var Conn: TFDConnection; Q: TFDQuery;
begin
  Conn := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := Conn;
      Q.SQL.Text := 'select * from Users where lower(Email)=lower(:Email)';
      Q.ParamByName('Email').AsString := Email;
      Q.Open;
      if Q.Eof then Exit(nil);
      Result := MapUser(Q);
    finally
      Q.Free;
    end;
  finally
    Conn.Free;
  end;
end;

class function TUserRepository.CreateUser(const OrganizationId: Integer; const Email, Password, Role: string): TUser;
var Conn: TFDConnection; Q: TFDQuery; Salt, Hash, Stored: string;
begin
  Salt := GenerateSalt;
  Hash := HashPassword(Password, Salt);
  Stored := Salt + '$' + Hash;
  Conn := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := Conn;
      Q.SQL.Text := 'insert into Users (OrganizationID, Email, PasswordHash, Role) values (:OrgId, :Email, :Pwd, :Role) ' +
                    'returning *';
      Q.ParamByName('OrgId').AsInteger := OrganizationId;
      Q.ParamByName('Email').AsString := Email;
      Q.ParamByName('Pwd').AsString := Stored;
      Q.ParamByName('Role').AsString := Role;
      Q.Open;
      Result := MapUser(Q);
    finally
      Q.Free;
    end;
  finally
    Conn.Free;
  end;
end;

end.
