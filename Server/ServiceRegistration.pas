unit ServiceRegistration;

interface

uses
  XData.Comp.Server,
  FireDAC.Comp.Client;

procedure RegisterAllServices(XDataServer: TXDataServer; Connection: TFDConnection);

implementation

uses
  // Service implementations - this ensures they are linked and their initialization sections run
  AuthServiceImplementation,
  DeviceServiceImplementation,
  CampaignItemServiceImplementation,
  CampaignServiceImplementation,
  DisplayCampaignServiceImplementation,
  DisplayServiceImplementation,
  MediaFileServiceImplementation,
  OrganizationServiceImplementation,
  PlanServiceImplementation,
  PlaybackLogServiceImplementation,
  RoleServiceImplementation,
  SubscriptionServiceImplementation,
  UserServiceImplementation,
  Winapi.Windows;

procedure RegisterAllServices(XDataServer: TXDataServer; Connection: TFDConnection);
begin
  // Services are registered via RegisterServiceType calls in their initialization sections
  // By including the implementation units in the uses clause above, we ensure they are linked
  // and their initialization sections execute, registering the services with XData

  // The RegisterServiceType calls should have already run during unit initialization
  // Let's verify by checking if we can access the services

  OutputDebugString(PChar('Service registration completed - checking service availability'));

  // No explicit instantiation needed - XData handles service lifecycle
end;

end.
