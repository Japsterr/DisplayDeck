program DisplayDeck;

uses
  System.SysUtils,
  System.IOUtils,
  Vcl.Forms,
  uEntities in 'uEntities.pas',
  uServerContainer in 'uServerContainer.pas' {ServerContainer: TDataModule},
  uMainForm in 'uMainForm.pas' {MainForm},
  AuthService in 'Services\Interfaces\AuthService.pas',
  DeviceService in 'Services\Interfaces\DeviceService.pas',
  CampaignItemService in 'Services\Interfaces\CampaignItemService.pas',
  CampaignService in 'Services\Interfaces\CampaignService.pas',
  DisplayCampaignService in 'Services\Interfaces\DisplayCampaignService.pas',
  DisplayService in 'Services\Interfaces\DisplayService.pas',
  MediaFileService in 'Services\Interfaces\MediaFileService.pas',
  OrganizationService in 'Services\Interfaces\OrganizationService.pas',
  PlanService in 'Services\Interfaces\PlanService.pas',
  PlaybackLogService in 'Services\Interfaces\PlaybackLogService.pas',
  RoleService in 'Services\Interfaces\RoleService.pas',
  SubscriptionService in 'Services\Interfaces\SubscriptionService.pas',
  UserService in 'Services\Interfaces\UserService.pas',
  AuthServiceImplementation in 'Services\Implementations\AuthServiceImplementation.pas',
  DeviceServiceImplementation in 'Services\Implementations\DeviceServiceImplementation.pas',
  CampaignItemServiceImplementation in 'Services\Implementations\CampaignItemServiceImplementation.pas',
  CampaignServiceImplementation in 'Services\Implementations\CampaignServiceImplementation.pas',
  DisplayCampaignServiceImplementation in 'Services\Implementations\DisplayCampaignServiceImplementation.pas',
  DisplayServiceImplementation in 'Services\Implementations\DisplayServiceImplementation.pas',
  MediaFileServiceImplementation in 'Services\Implementations\MediaFileServiceImplementation.pas',
  OrganizationServiceImplementation in 'Services\Implementations\OrganizationServiceImplementation.pas',
  PlanServiceImplementation in 'Services\Implementations\PlanServiceImplementation.pas',
  PlaybackLogServiceImplementation in 'Services\Implementations\PlaybackLogServiceImplementation.pas',
  RoleServiceImplementation in 'Services\Implementations\RoleServiceImplementation.pas',
  SubscriptionServiceImplementation in 'Services\Implementations\SubscriptionServiceImplementation.pas',
  UserServiceImplementation in 'Services\Implementations\UserServiceImplementation.pas';

{$R *.res}

begin
  try
    Application.Initialize;
    Application.MainFormOnTaskbar := True;
    Application.CreateForm(TServerContainer, ServerContainer);
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
  except
    on E: Exception do
    begin
      TFile.WriteAllText(TPath.Combine(ExtractFilePath(ParamStr(0)), 'startup-error.log'),
        E.ClassName + ': ' + E.Message + sLineBreak + E.StackTrace);
      raise;
    end;
  end;
end.
