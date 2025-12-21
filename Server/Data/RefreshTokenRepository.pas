unit RefreshTokenRepository;

interface

uses
  System.SysUtils,
  FireDAC.Comp.Client;

type
  TRefreshTokenRepository = class
  public
    class procedure StoreToken(const OrganizationId, UserId: Integer; const TokenHash: string; const ExpiresAt: TDateTime);
    class function ValidateToken(const TokenHash: string; out OrganizationId: Integer; out UserId: Integer): Boolean;
    class procedure TouchLastUsed(const TokenHash: string);
    class procedure RevokeToken(const TokenHash: string);
    class procedure RevokeAllForUser(const OrganizationId, UserId: Integer);
  end;

implementation

uses
  FireDAC.Stan.Param,
  uServerContainer;

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

class procedure TRefreshTokenRepository.StoreToken(const OrganizationId, UserId: Integer; const TokenHash: string; const ExpiresAt: TDateTime);
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'insert into RefreshTokens (OrganizationID, UserID, TokenHash, ExpiresAt) values (:Org,:User,:Hash,:Exp)';
      Q.ParamByName('Org').AsInteger := OrganizationId;
      Q.ParamByName('User').AsInteger := UserId;
      Q.ParamByName('Hash').AsString := TokenHash;
      Q.ParamByName('Exp').AsDateTime := ExpiresAt;
      Q.ExecSQL;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TRefreshTokenRepository.ValidateToken(const TokenHash: string; out OrganizationId: Integer; out UserId: Integer): Boolean;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  Result := False;
  OrganizationId := 0;
  UserId := 0;

  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'select OrganizationID, UserID, ExpiresAt, RevokedAt from RefreshTokens where TokenHash=:Hash';
      Q.ParamByName('Hash').AsString := TokenHash;
      Q.Open;
      if Q.Eof then Exit(False);
      if (Q.FindField('RevokedAt') <> nil) and (not Q.FieldByName('RevokedAt').IsNull) then Exit(False);
      if Q.FieldByName('ExpiresAt').AsDateTime < Now then Exit(False);
      OrganizationId := Q.FieldByName('OrganizationID').AsInteger;
      UserId := Q.FieldByName('UserID').AsInteger;
      Result := True;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class procedure TRefreshTokenRepository.TouchLastUsed(const TokenHash: string);
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'update RefreshTokens set LastUsedAt=NOW() where TokenHash=:Hash';
      Q.ParamByName('Hash').AsString := TokenHash;
      Q.ExecSQL;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class procedure TRefreshTokenRepository.RevokeToken(const TokenHash: string);
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'update RefreshTokens set RevokedAt=NOW() where TokenHash=:Hash and RevokedAt is null';
      Q.ParamByName('Hash').AsString := TokenHash;
      Q.ExecSQL;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class procedure TRefreshTokenRepository.RevokeAllForUser(const OrganizationId, UserId: Integer);
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'update RefreshTokens set RevokedAt=NOW() where OrganizationID=:Org and UserID=:User and RevokedAt is null';
      Q.ParamByName('Org').AsInteger := OrganizationId;
      Q.ParamByName('User').AsInteger := UserId;
      Q.ExecSQL;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

end.
