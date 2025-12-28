program DisplayDeckManager;

uses
  System.StartUpCopy,
  FMX.Forms,
  uMainForm in 'Forms\uMainForm.pas' {Form1},
  uDisplaysFrameV2 in 'Forms\V2\uDisplaysFrameV2.pas',
  uCampaignsFrameV2 in 'Forms\V2\uCampaignsFrameV2.pas',
  uAppShell in 'Forms\V2\uAppShell.pas' {AppShellForm},
  uFrameBase in 'Forms\V2\uFrameBase.pas',
  uDashboardFrameV2 in 'Forms\V2\uDashboardFrameV2.pas',
  uAppSession in 'Forms\V2\uAppSession.pas',
  uApiClient in 'Forms\uApiClient.pas',
  LoginFrame in 'Forms\LoginFrame.pas' {Frame1: TFrame},
  RegisterFrame in 'Forms\RegisterFrame.pas' {Frame2: TFrame},
  DashboardFrame in 'Forms\DashboardFrame.pas' {Frame3: TFrame},
  ProfileFrame in 'Forms\ProfileFrame.pas' {Frame4: TFrame},
  DisplaysFrame in 'Forms\DisplaysFrame.pas' {Frame5: TFrame},
  CampaignsFrame in 'Forms\CampaignsFrame.pas' {Frame6: TFrame},
  MediaLibraryFrame in 'Forms\MediaLibraryFrame.pas' {Frame7: TFrame},
  AnalyticsFrame in 'Forms\AnalyticsFrame.pas' {Frame8: TFrame},
  SettingsFrame in 'Forms\SettingsFrame.pas' {Frame9: TFrame},
  uTheme in 'Forms\uTheme.pas',
  uAppSettings in 'Forms\uAppSettings.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TAppShellForm, AppShellForm);
  Application.Run;
end.
