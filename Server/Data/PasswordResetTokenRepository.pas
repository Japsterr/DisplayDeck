unit PasswordResetTokenRepository;

interface

uses
  System.SysUtils,
  FireDAC.Comp.Client;

type
  TPasswordResetTokenRepository = class
  public
    class procedure InvalidateOutstandingForUser(const UserId: Integer);
    class procedure StoreToken(const UserId: Integer; const TokenHash: string; const ExpiresAt: TDateTime);
    class function ConsumeToken(const TokenHash: string; out UserId: Integer): Boolean;
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

class procedure TPasswordResetTokenRepository.InvalidateOutstandingForUser(const UserId: Integer);
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'update PasswordResetTokens set UsedAt=NOW() where UserID=:User and UsedAt is null';
      Q.ParamByName('User').AsInteger := UserId;
      Q.ExecSQL;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class procedure TPasswordResetTokenRepository.StoreToken(const UserId: Integer; const TokenHash: string; const ExpiresAt: TDateTime);
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'insert into PasswordResetTokens (UserID, TokenHash, ExpiresAt) values (:User,:Hash,:Exp)';
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

class function TPasswordResetTokenRepository.ConsumeToken(const TokenHash: string; out UserId: Integer): Boolean;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  Result := False;
  UserId := 0;

  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'select UserID, ExpiresAt, UsedAt from PasswordResetTokens where TokenHash=:Hash';
      Q.ParamByName('Hash').AsString := TokenHash;
      Q.Open;
      if Q.Eof then Exit(False);
      if (Q.FindField('UsedAt') <> nil) and (not Q.FieldByName('UsedAt').IsNull) then Exit(False);
      if Q.FieldByName('ExpiresAt').AsDateTime < Now then Exit(False);

      UserId := Q.FieldByName('UserID').AsInteger;

      Q.Close;
      Q.SQL.Text := 'update PasswordResetTokens set UsedAt=NOW() where TokenHash=:Hash and UsedAt is null';
      Q.ParamByName('Hash').AsString := TokenHash;
      Q.ExecSQL;

      Result := True;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

end.
