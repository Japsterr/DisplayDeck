unit ServiceRegistration;

interface

uses
  XData.Comp.Server,
  XData.Service.Common,
  FireDAC.Comp.Client;

procedure RegisterAllServices(XDataServer: TXDataServer; Connection: TFDConnection);

implementation

uses
  // Service interfaces
  AuthService,
  DeviceService,
  CampaignItemService,
  CampaignService,
  DisplayCampaignService,
  DisplayService,
  MediaFileService,
  HealthService,
  OrganizationService,
  PlanService,
  PlaybackLogService,
  RoleService,
  SubscriptionService,
  UserService,
  // Service implementations - this ensures they are linked and their initialization sections run
  AuthServiceImplementation,
  DeviceServiceImplementation,
  CampaignItemServiceImplementation,
  CampaignServiceImplementation,
  DisplayCampaignServiceImplementation,
  DisplayServiceImplementation,
  MediaFileServiceImplementation,
  HealthServiceImplementation,
  OrganizationServiceImplementation,
  PlanServiceImplementation,
  PlaybackLogServiceImplementation,
  RoleServiceImplementation,
  SubscriptionServiceImplementation,
  UserServiceImplementation,
  Winapi.Windows,
  System.IOUtils,
  System.SysUtils;

procedure RegisterAllServices(XDataServer: TXDataServer; Connection: TFDConnection);
var
  LogFile: string;
begin
  // Register services globally - XData server will automatically use them
  // This is the correct TMS XData pattern

  LogFile := TPath.Combine(ExtractFilePath(ParamStr(0)), 'service_registration.log');
  TFile.AppendAllText(LogFile, FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ': Registering services globally...' + sLineBreak);

  // Register service types globally (TMS XData pattern)
  RegisterServiceType(TAuthService);
  TFile.AppendAllText(LogFile, 'Registered TAuthService globally' + sLineBreak);

  RegisterServiceType(TDeviceService);
  TFile.AppendAllText(LogFile, 'Registered TDeviceService globally' + sLineBreak);

  RegisterServiceType(TCampaignItemService);
  TFile.AppendAllText(LogFile, 'Registered TCampaignItemService globally' + sLineBreak);

  RegisterServiceType(TCampaignService);
  TFile.AppendAllText(LogFile, 'Registered TCampaignService globally' + sLineBreak);

  RegisterServiceType(TDisplayCampaignService);
  TFile.AppendAllText(LogFile, 'Registered TDisplayCampaignService globally' + sLineBreak);

  RegisterServiceType(TDisplayService);
  TFile.AppendAllText(LogFile, 'Registered TDisplayService globally' + sLineBreak);

  RegisterServiceType(TMediaFileService);
  TFile.AppendAllText(LogFile, 'Registered TMediaFileService globally' + sLineBreak);

  RegisterServiceType(THealthService);
  TFile.AppendAllText(LogFile, 'Registered THealthService globally' + sLineBreak);

  RegisterServiceType(TOrganizationService);
  TFile.AppendAllText(LogFile, 'Registered TOrganizationService globally' + sLineBreak);

  RegisterServiceType(TPlanService);
  TFile.AppendAllText(LogFile, 'Registered TPlanService globally' + sLineBreak);

  RegisterServiceType(TPlaybackLogService);
  TFile.AppendAllText(LogFile, 'Registered TPlaybackLogService globally' + sLineBreak);

  RegisterServiceType(TRoleService);
  TFile.AppendAllText(LogFile, 'Registered TRoleService globally' + sLineBreak);

  RegisterServiceType(TSubscriptionService);
  TFile.AppendAllText(LogFile, 'Registered TSubscriptionService globally' + sLineBreak);

  RegisterServiceType(TUserService);
  TFile.AppendAllText(LogFile, 'Registered TUserService globally' + sLineBreak);

  TFile.AppendAllText(LogFile, 'All services registered globally - XData server will use them' + sLineBreak);
end;

end.
