unit ProvisioningTokenRepository;

interface

uses
  System.SysUtils, System.DateUtils;

type
  TProvisioningTokenInfo = record
    Token: string;
    ExpiresAt: TDateTime;
  end;

  TProvisioningTokenRepository = class
  public
    class function CreateToken(const TTLSeconds: Integer = 900): TProvisioningTokenInfo;
    class function ValidateAndClaim(const Token: string): Boolean;
    class function ExistsValid(const Token: string): Boolean;
  end;

implementation

uses
  FireDAC.Comp.Client, FireDAC.Stan.Param, uServerContainer;

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

function RandomToken: string;
var
  G: TGUID;
begin
  CreateGUID(G);
  Result := StringReplace(G.ToString, '{', '', [rfReplaceAll]);
  Result := StringReplace(Result, '}', '', [rfReplaceAll]);
  Result := StringReplace(Result, '-', '', [rfReplaceAll]);
  Result := LowerCase(Result);
end;

class function TProvisioningTokenRepository.CreateToken(const TTLSeconds: Integer): TProvisioningTokenInfo;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  Result.Token := RandomToken;
  Result.ExpiresAt := IncSecond(Now, TTLSeconds);
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'insert into ProvisioningTokens (Token, ExpiresAt, Claimed) values (:T, :E, false)';
      Q.ParamByName('T').AsString := Result.Token;
      Q.ParamByName('E').AsDateTime := Result.ExpiresAt;
      Q.ExecSQL;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TProvisioningTokenRepository.ExistsValid(const Token: string): Boolean;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  Result := False;
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'select 1 from ProvisioningTokens where Token=:T and Claimed=false and ExpiresAt > now()';
      Q.ParamByName('T').AsString := Token;
      Q.Open;
      Result := not Q.Eof;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TProvisioningTokenRepository.ValidateAndClaim(const Token: string): Boolean;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  Result := False;
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      // Atomically mark as claimed if valid
      Q.SQL.Text := 'update ProvisioningTokens set Claimed=true where Token=:T and Claimed=false and ExpiresAt > now()';
      Q.ParamByName('T').AsString := Token;
      Q.ExecSQL;
      Result := Q.RowsAffected > 0;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

end.
