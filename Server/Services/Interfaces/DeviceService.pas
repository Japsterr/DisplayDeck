unit DeviceService;

interface

uses
  XData.Service.Common,
  uEntities;

type
  TDeviceConfigRequest = class
  private
    FProvisioningToken: string;
  public
    property ProvisioningToken: string read FProvisioningToken write FProvisioningToken;
  end;

  TDeviceConfigResponse = class
  private
    FDevice: TDisplay;
    FCampaigns: TArray<TCampaign>;
    FSuccess: Boolean;
    FMessage: string;
  public
    constructor Create;
    destructor Destroy; override;
    property Device: TDisplay read FDevice write FDevice;
    property Campaigns: TArray<TCampaign> read FCampaigns write FCampaigns;
    property Success: Boolean read FSuccess write FSuccess;
    property Message: string read FMessage write FMessage;
  end;

  TDeviceLogRequest = class
  private
    FDisplayId: Integer;
    FLogType: string;
    FMessage: string;
    FTimestamp: TDateTime;
  public
    property DisplayId: Integer read FDisplayId write FDisplayId;
    property LogType: string read FLogType write FLogType;
    property Message: string read FMessage write FMessage;
    property Timestamp: TDateTime read FTimestamp write FTimestamp;
  end;

  TDeviceLogResponse = class
  private
    FSuccess: Boolean;
    FMessage: string;
  public
    property Success: Boolean read FSuccess write FSuccess;
    property Message: string read FMessage write FMessage;
  end;

  [ServiceContract]
  IDeviceService = interface(IInvokable)
    ['{98765432-1234-1234-1234-123456789ABC}']

    function GetConfig(const Request: TDeviceConfigRequest): TDeviceConfigResponse;
    function SendLog(const Request: TDeviceLogRequest): TDeviceLogResponse;
  end;

implementation

{ TDeviceConfigResponse }

constructor TDeviceConfigResponse.Create;
begin
  inherited;
  FDevice := nil;
  SetLength(FCampaigns, 0);
  FSuccess := False;
end;

destructor TDeviceConfigResponse.Destroy;
var
  i: Integer;
begin
  if Assigned(FDevice) then
    FDevice.Free;

  for i := 0 to High(FCampaigns) do
    if Assigned(FCampaigns[i]) then
      FCampaigns[i].Free;

  inherited;
end;

initialization
  RegisterServiceType(TypeInfo(IDeviceService));

end.