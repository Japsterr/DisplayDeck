unit ProvisioningTokenEventRepository;

interface

uses
  System.SysUtils,
  System.JSON,
  FireDAC.Comp.Client;

type
  TProvisioningTokenEventRepository = class
  public
    class procedure WriteEvent(
      const Token, EventType, HardwareId: string;
      const DisplayId, OrganizationId, UserId: Integer;
      const Details: TJSONObject;
      const RequestId, IpAddress, UserAgent: string
    );
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

class procedure TProvisioningTokenEventRepository.WriteEvent(
  const Token, EventType, HardwareId: string;
  const DisplayId, OrganizationId, UserId: Integer;
  const Details: TJSONObject;
  const RequestId, IpAddress, UserAgent: string
);
var
  C: TFDConnection;
  Q: TFDQuery;
  DetailsText: string;
begin
  if Trim(Token) = '' then Exit;
  if Trim(EventType) = '' then Exit;

  DetailsText := '';
  if Assigned(Details) then
    DetailsText := Details.ToJSON;

  C := NewConnection;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := C;
      Q.SQL.Text :=
        'insert into ProvisioningTokenEvents '
      + '(Token, EventType, HardwareId, DisplayID, OrganizationID, UserID, Details, RequestId, IpAddress, UserAgent) '
      + 'values (:Tok,:Type,:Hw,:Disp,:Org,:User,:Details::jsonb,:Req,:Ip,:UA)';

      Q.ParamByName('Tok').AsString := Token;
      Q.ParamByName('Type').AsString := EventType;

      if Trim(HardwareId) <> '' then
        Q.ParamByName('Hw').AsString := HardwareId
      else
        Q.ParamByName('Hw').Clear;

      if DisplayId > 0 then
        Q.ParamByName('Disp').AsInteger := DisplayId
      else
        Q.ParamByName('Disp').Clear;

      if OrganizationId > 0 then
        Q.ParamByName('Org').AsInteger := OrganizationId
      else
        Q.ParamByName('Org').Clear;

      if UserId > 0 then
        Q.ParamByName('User').AsInteger := UserId
      else
        Q.ParamByName('User').Clear;

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
        // token event logging must never break API
      end;
    finally
      Q.Free;
    end;
  finally
    C.Free;
  end;
end;

end.
