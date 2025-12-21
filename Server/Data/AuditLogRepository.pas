unit AuditLogRepository;

interface

uses
  System.SysUtils,
  System.JSON,
  FireDAC.Comp.Client;

type
  TAuditLogRepository = class
  public
    class procedure WriteEvent(const OrganizationId: Integer; const UserId: Integer; const Action, ObjectType, ObjectId: string; const Details: TJSONObject; const RequestId, IpAddress, UserAgent: string);
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

class procedure TAuditLogRepository.WriteEvent(const OrganizationId: Integer; const UserId: Integer; const Action, ObjectType, ObjectId: string; const Details: TJSONObject; const RequestId, IpAddress, UserAgent: string);
var
  C: TFDConnection;
  Q: TFDQuery;
  DetailsText: string;
begin
  if OrganizationId <= 0 then Exit;

  DetailsText := '';
  if Assigned(Details) then
    DetailsText := Details.ToJSON;

  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text := 'insert into AuditLogs (OrganizationID, UserID, Action, ObjectType, ObjectId, Details, RequestId, IpAddress, UserAgent) values (:Org,:User,:Act,:Type,:Obj,:Details::jsonb,:Req,:Ip,:UA)';
      Q.ParamByName('Org').AsInteger := OrganizationId;
      if UserId > 0 then
        Q.ParamByName('User').AsInteger := UserId
      else
        Q.ParamByName('User').Clear;
      Q.ParamByName('Act').AsString := Action;
      Q.ParamByName('Type').AsString := ObjectType;
      Q.ParamByName('Obj').AsString := ObjectId;
      if DetailsText <> '' then
        Q.ParamByName('Details').AsString := DetailsText
      else
        Q.ParamByName('Details').AsString := '{}';
      Q.ParamByName('Req').AsString := RequestId;
      Q.ParamByName('Ip').AsString := IpAddress;
      Q.ParamByName('UA').AsString := Copy(UserAgent, 1, 255);
      try
        Q.ExecSQL;
      except
        // audit failures must never break API
      end;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

end.
