program DisplayDeckManager;

uses
  System.StartUpCopy,
  FMX.Forms,
  uMainForm in 'Forms\uMainForm.pas' {Form1},
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
  uTheme in 'Forms\uTheme.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
