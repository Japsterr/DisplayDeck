unit DeviceServiceImplementation;

interface

uses
  System.SysUtils,
  XData.Server.Module,
  XData.Service.Common,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  Data.DB,
  uEntities,
  DeviceService;

type
  [ServiceImplementation]
  TDeviceService = class(TInterfacedObject, IDeviceService)
  private
    function GetConnection: TFDConnection;
    function GetDeviceByProvisioningToken(const Token: string): TDisplay;
    function GetDeviceCampaigns(DeviceId: Integer): TArray<TCampaign>;
  public
    function GetConfig(const Request: TDeviceConfigRequest): TDeviceConfigResponse;
    function SendLog(const Request: TDeviceLogRequest): TDeviceLogResponse;
  end;

implementation

uses
  uServerContainer;

{ TDeviceService }

function TDeviceService.GetConnection: TFDConnection;
begin
  // Get the shared connection from the server container
  Result := ServerContainer.FDConnection;
end;

function TDeviceService.GetDeviceByProvisioningToken(const Token: string): TDisplay;
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := GetConnection;
    Query.SQL.Text := 'SELECT DisplayID, OrganizationID, Name, Orientation, LastSeen, CurrentStatus, ProvisioningToken, CreatedAt, UpdatedAt ' +
                      'FROM Displays WHERE ProvisioningToken = :Token';
    Query.ParamByName('Token').AsString := Token;
    Query.Open;

    if Query.IsEmpty then
      Exit(nil);

    Result := TDisplay.Create;
    Result.Id := Query.FieldByName('DisplayID').AsInteger;
    Result.OrganizationId := Query.FieldByName('OrganizationID').AsInteger;
    Result.Name := Query.FieldByName('Name').AsString;
    Result.Orientation := Query.FieldByName('Orientation').AsString;
    if not Query.FieldByName('LastSeen').IsNull then
      Result.LastSeen := Query.FieldByName('LastSeen').AsDateTime;
    Result.CurrentStatus := Query.FieldByName('CurrentStatus').AsString;
    Result.ProvisioningToken := Query.FieldByName('ProvisioningToken').AsString;
    Result.CreatedAt := Query.FieldByName('CreatedAt').AsDateTime;
    Result.UpdatedAt := Query.FieldByName('UpdatedAt').AsDateTime;
  finally
    Query.Free;
  end;
end;

function TDeviceService.GetDeviceCampaigns(DeviceId: Integer): TArray<TCampaign>;
var
  Query: TFDQuery;
  List: TArray<TCampaign>;
  Campaign: TCampaign;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := GetConnection;
    Query.SQL.Text := 'SELECT c.CampaignID, c.OrganizationID, c.Name, c.Orientation, c.CreatedAt, c.UpdatedAt ' +
                      'FROM Campaigns c ' +
                      'INNER JOIN DisplayCampaigns dc ON c.CampaignID = dc.CampaignID ' +
                      'WHERE dc.DisplayID = :DisplayId ' +
                      'ORDER BY dc.IsPrimary DESC, c.Name';
    Query.ParamByName('DisplayId').AsInteger := DeviceId;
    Query.Open;

    SetLength(List, 0);
    while not Query.Eof do
    begin
      Campaign := TCampaign.Create;
      Campaign.Id := Query.FieldByName('CampaignID').AsInteger;
      Campaign.OrganizationId := Query.FieldByName('OrganizationID').AsInteger;
      Campaign.Name := Query.FieldByName('Name').AsString;
      Campaign.Orientation := Query.FieldByName('Orientation').AsString;
      Campaign.CreatedAt := Query.FieldByName('CreatedAt').AsDateTime;
      Campaign.UpdatedAt := Query.FieldByName('UpdatedAt').AsDateTime;

      SetLength(List, Length(List) + 1);
      List[High(List)] := Campaign;
      Query.Next;
    end;

    Result := List;
  finally
    Query.Free;
  end;
end;

function TDeviceService.GetConfig(const Request: TDeviceConfigRequest): TDeviceConfigResponse;
var
  Device: TDisplay;
begin
  Result := TDeviceConfigResponse.Create;
  Device := nil; // Initialize to nil

  try
    // Get device by provisioning token
    Device := GetDeviceByProvisioningToken(Request.ProvisioningToken);
    if not Assigned(Device) then
    begin
      Result.Success := False;
      Result.Message := 'Invalid provisioning token';
      Exit;
    end;

    // Update last seen timestamp
    try
      var Query := TFDQuery.Create(nil);
      try
        Query.Connection := GetConnection;
        Query.SQL.Text := 'UPDATE Displays SET LastSeen = CURRENT_TIMESTAMP, CurrentStatus = :Status WHERE DisplayID = :Id';
        Query.ParamByName('Id').AsInteger := Device.Id;
        Query.ParamByName('Status').AsString := 'Online';
        Query.ExecSQL;
      finally
        Query.Free;
      end;
    except
      // Log error but don't fail the request
    end;

    // Get campaigns for this device
    Result.Campaigns := GetDeviceCampaigns(Device.Id);

    Result.Success := True;
    Result.Device := Device;
    Result.Message := 'Configuration retrieved successfully';

  except
    on E: Exception do
    begin
      Result.Success := False;
      Result.Message := 'Failed to get device configuration: ' + E.Message;
      if Assigned(Device) then
        Device.Free;
    end;
  end;
end;

function TDeviceService.SendLog(const Request: TDeviceLogRequest): TDeviceLogResponse;
begin
  Result := TDeviceLogResponse.Create;

  try
    // For now, just log to console. In production, you might want to store logs in database
    WriteLn(Format('[%s] Device %d (%s): %s',
      [FormatDateTime('yyyy-mm-dd hh:nn:ss', Request.Timestamp),
       Request.DisplayId, Request.LogType, Request.Message]));

    // Optionally store in database if needed
    // You could create a DeviceLogs table for this

    Result.Success := True;
    Result.Message := 'Log received successfully';

  except
    on E: Exception do
    begin
      Result.Success := False;
      Result.Message := 'Failed to process log: ' + E.Message;
    end;
  end;
end;

initialization
  RegisterServiceType(TDeviceService);

end.