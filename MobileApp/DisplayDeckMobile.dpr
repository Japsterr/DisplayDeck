program DisplayDeckMobile;

uses
  System.StartUpCopy,
  System.Classes,
  System.SysUtils,
  FMX.Forms,
  FMX.Types,
  FMX.DialogService,
{$IFDEF ANDROID} Androidapi.Log,{$ENDIF}
  uAppExceptions in 'Utils\uAppExceptions.pas',
  uTheme in 'Styles\uTheme.pas',
  fSplash in 'Forms\fSplash.pas' {SplashForm},
  fLogin in 'Forms\fLogin.pas' {LoginForm},
  fMain in 'Forms\fMain.pas' {MainForm},
  uAppConfig in 'Config\uAppConfig.pas',
  uModels in 'Models\uModels.pas',
  uApiClient in 'Services\uApiClient.pas',
  uAuthService in 'Services\uAuthService.pas',
  uDisplayService in 'Services\uDisplayService.pas',
  uCampaignService in 'Services\uCampaignService.pas',
  uAssignmentService in 'Services\uAssignmentService.pas';

{$R *.res}

begin
  try
    Application.Initialize;
    // Prefer platform dialogs to reduce FragmentManager timing issues
    TDialogService.PreferredMode := TDialogService.TPreferredMode.Platform;
    InitAppExceptions;
    {$IFDEF ANDROID} __android_log_write(android_LogPriority.ANDROID_LOG_DEBUG, 'DisplayDeck', 'App Initialize'); {$ENDIF}
    // Create Login first and explicitly make it the MainForm
    Application.CreateForm(TLoginForm, LoginForm);
    {$IFDEF ANDROID} __android_log_write(android_LogPriority.ANDROID_LOG_DEBUG, 'DisplayDeck', 'Login Created'); {$ENDIF}
    Application.MainForm := LoginForm;
    {$IFDEF ANDROID} __android_log_write(android_LogPriority.ANDROID_LOG_DEBUG, 'DisplayDeck', 'Login Set As MainForm'); {$ENDIF}
    // Let FMX manage showing the MainForm during the message loop
    Application.Run;
  except
    on E: Exception do
    begin
      {$IFDEF ANDROID}
      __android_log_write(android_LogPriority.ANDROID_LOG_ERROR, 'DisplayDeck', PAnsiChar(UTF8String('Fatal during startup: ' + E.ClassName + ': ' + E.Message)));
      {$ENDIF}
      raise;
    end;
  end;
end.
