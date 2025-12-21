unit ApiKeyRepository;

interface

uses
  System.SysUtils,
  FireDAC.Comp.Client;

type
  TApiKeyInfo = record
    ApiKeyId: Int64;
    OrganizationId: Integer;
    Name: string;
    Scopes: string;
    ExpiresAt: TDateTime;
    HasExpiresAt: Boolean;
    Revoked: Boolean;
  end;

  TApiKeyRepository = class
  public
    class function CreateKey(const OrganizationId, CreatedByUserId: Integer; const Name, Scopes, KeyHash: string; const ExpiresAt: TDateTime; const HasExpiresAt: Boolean): Int64;
    class function FindByHash(const KeyHash: string; out Info: TApiKeyInfo): Boolean;
    class procedure TouchLastUsed(const ApiKeyId: Int64);
    class function RevokeKey(const OrganizationId: Integer; const ApiKeyId: Int64): Boolean;
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

class function TApiKeyRepository.CreateKey(const OrganizationId, CreatedByUserId: Integer; const Name, Scopes, KeyHash: string; const ExpiresAt: TDateTime; const HasExpiresAt: Boolean): Int64;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      if HasExpiresAt then
        Q.SQL.Text := 'insert into ApiKeys (OrganizationID, Name, KeyHash, Scopes, CreatedByUserID, ExpiresAt) values (:Org,:Name,:Hash,:Scopes,:User,:Exp) returning ApiKeyID'
      else
        Q.SQL.Text := 'insert into ApiKeys (OrganizationID, Name, KeyHash, Scopes, CreatedByUserID) values (:Org,:Name,:Hash,:Scopes,:User) returning ApiKeyID';
      Q.ParamByName('Org').AsInteger := OrganizationId;
      Q.ParamByName('Name').AsString := Name;
      Q.ParamByName('Hash').AsString := KeyHash;
      Q.ParamByName('Scopes').AsString := Scopes;
      if CreatedByUserId > 0 then
        Q.ParamByName('User').AsInteger := CreatedByUserId
      else
        Q.ParamByName('User').Clear;
      if HasExpiresAt then
        Q.ParamByName('Exp').AsDateTime := ExpiresAt;
      Q.Open;
      Result := Q.Fields[0].AsLargeInt;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TApiKeyRepository.FindByHash(const KeyHash: string; out Info: TApiKeyInfo): Boolean;
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  Result := False;
  FillChar(Info, SizeOf(Info), 0);

  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'select * from ApiKeys where KeyHash=:Hash';
      Q.ParamByName('Hash').AsString := KeyHash;
      Q.Open;
      if Q.Eof then Exit(False);

      Info.ApiKeyId := Q.FieldByName('ApiKeyID').AsLargeInt;
      Info.OrganizationId := Q.FieldByName('OrganizationID').AsInteger;
      Info.Name := Q.FieldByName('Name').AsString;
      Info.Scopes := Q.FieldByName('Scopes').AsString;
      Info.HasExpiresAt := (Q.FindField('ExpiresAt') <> nil) and (not Q.FieldByName('ExpiresAt').IsNull);
      if Info.HasExpiresAt then
        Info.ExpiresAt := Q.FieldByName('ExpiresAt').AsDateTime;
      Info.Revoked := (Q.FindField('RevokedAt') <> nil) and (not Q.FieldByName('RevokedAt').IsNull);

      Result := True;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class procedure TApiKeyRepository.TouchLastUsed(const ApiKeyId: Int64);
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'update ApiKeys set LastUsedAt=NOW() where ApiKeyID=:Id';
      Q.ParamByName('Id').AsLargeInt := ApiKeyId;
      Q.ExecSQL;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class function TApiKeyRepository.RevokeKey(const OrganizationId: Integer; const ApiKeyId: Int64): Boolean;
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
      Q.SQL.Text := 'update ApiKeys set RevokedAt=NOW() where ApiKeyID=:Id and OrganizationID=:Org and RevokedAt is null';
      Q.ParamByName('Id').AsLargeInt := ApiKeyId;
      Q.ParamByName('Org').AsInteger := OrganizationId;
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
