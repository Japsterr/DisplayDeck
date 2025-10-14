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
begin
  // This procedure is now effectively a no-op.
  // Its purpose is served by having all service implementation units
  // in the 'uses' clause above, which ensures they are linked into the
  // final executable. The actual registration now happens in uServerContainer.
end;

end.
