unit IdempotencyRepository;

interface

uses
  System.SysUtils,
  FireDAC.Comp.Client;

type
  TIdempotencyHit = record
    Hit: Boolean;
    StatusCode: Integer;
    ResponseBody: string;
  end;

  TIdempotencyRepository = class
  public
    class function TryGet(const Key, Method, Path: string; const OrganizationId: Integer): TIdempotencyHit;
    class procedure Store(const Key, Method, Path: string; const OrganizationId: Integer; const StatusCode: Integer; const Body: string; const ExpiresAt: TDateTime);
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

class function TIdempotencyRepository.TryGet(const Key, Method, Path: string; const OrganizationId: Integer): TIdempotencyHit;
var
  C: TFDConnection;
  Q: TFDQuery;
  OrgOk: Boolean;
begin
  Result.Hit := False;
  Result.StatusCode := 0;
  Result.ResponseBody := '';

  if Key.Trim = '' then Exit;

  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      // cleanup is opportunistic
      Q.SQL.Text := 'delete from IdempotencyKeys where ExpiresAt < NOW()';
      try Q.ExecSQL; except end;

      Q.SQL.Text := 'select OrganizationID, ResponseStatus, ResponseBody, ExpiresAt from IdempotencyKeys where IdempotencyKey=:K and Method=:M and Path=:P';
      Q.ParamByName('K').AsString := Key;
      Q.ParamByName('M').AsString := Method;
      Q.ParamByName('P').AsString := Path;
      Q.Open;
      if Q.Eof then Exit;
      if Q.FieldByName('ExpiresAt').AsDateTime < Now then Exit;

      OrgOk := True;
      if OrganizationId > 0 then
      begin
        if Q.FieldByName('OrganizationID').IsNull then
          OrgOk := False
        else
          OrgOk := (Q.FieldByName('OrganizationID').AsInteger = OrganizationId);
      end;
      if not OrgOk then Exit;

      Result.Hit := True;
      Result.StatusCode := Q.FieldByName('ResponseStatus').AsInteger;
      Result.ResponseBody := Q.FieldByName('ResponseBody').AsString;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

class procedure TIdempotencyRepository.Store(const Key, Method, Path: string; const OrganizationId: Integer; const StatusCode: Integer; const Body: string; const ExpiresAt: TDateTime);
var
  C: TFDConnection;
  Q: TFDQuery;
begin
  if Key.Trim = '' then Exit;

  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      // Insert; ignore duplicates
      Q.SQL.Text := 'insert into IdempotencyKeys (IdempotencyKey, OrganizationID, Method, Path, ResponseStatus, ResponseBody, ExpiresAt) values (:K,:Org,:M,:P,:S,:B,:E)';
      Q.ParamByName('K').AsString := Key;
      if OrganizationId > 0 then
        Q.ParamByName('Org').AsInteger := OrganizationId
      else
        Q.ParamByName('Org').Clear;
      Q.ParamByName('M').AsString := Method;
      Q.ParamByName('P').AsString := Path;
      Q.ParamByName('S').AsInteger := StatusCode;
      Q.ParamByName('B').AsString := Body;
      Q.ParamByName('E').AsDateTime := ExpiresAt;
      try
        Q.ExecSQL;
      except
        // if duplicate key, do nothing
      end;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

end.
