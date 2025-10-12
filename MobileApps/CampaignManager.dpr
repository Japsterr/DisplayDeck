program CampaignManager;

uses
  System.StartUpCopy,
  FMX.Forms,
  uMainForm in 'uMainForm.pas' {MainForm},
  uLoginForm in 'uLoginForm.pas' {LoginForm},
  uCampaignListForm in 'uCampaignListForm.pas' {CampaignListForm},
  uCampaignEditForm in 'uCampaignEditForm.pas' {CampaignEditForm},
  uMediaLibraryForm in 'uMediaLibraryForm.pas' {MediaLibraryForm},
  uDisplayManagerForm in 'uDisplayManagerForm.pas' {DisplayManagerForm},
  uApiClient in 'uApiClient.pas',
  uEntities in 'uEntities.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.