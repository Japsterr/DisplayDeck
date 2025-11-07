unit fSplash;

interface

uses System.Classes, FMX.Forms, FMX.Types, FMX.Controls, FMX.Objects, FMX.Layouts, FMX.StdCtrls, FMX.Graphics, uTheme;

type
  TSplashForm = class(TForm)
    Root: TLayout;
    Bg: TRectangle;
    Title: TLabel;
    Sub: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    procedure GoNext;
  end;

var
  SplashForm: TSplashForm;

implementation

{$R *.fmx}

uses fLogin, System.SysUtils, FMX.Platform, FMX.DialogService
{$IFDEF ANDROID}, Androidapi.Log{$ENDIF};

procedure TSplashForm.FormCreate(Sender: TObject);
begin
  {$IFDEF ANDROID} __android_log_write(android_LogPriority.ANDROID_LOG_DEBUG, 'DisplayDeck', 'Splash FormCreate'); {$ENDIF}
  Root := TLayout.Create(Self); Root.Parent := Self; Root.Align := TAlignLayout.Client;
  Bg := TRectangle.Create(Self); Bg.Parent := Root; Bg.Align := TAlignLayout.Client; Bg.Fill.Color := THEME_BG; Bg.Stroke.Kind := TBrushKind.None;
  Title := TLabel.Create(Self); Title.Parent := Root; Title.Text := 'DisplayDeck'; Title.Position.Y := 220; Title.TextSettings.Font.Size := 28; Title.TextSettings.FontColor := THEME_TEXT;
  Sub := TLabel.Create(Self); Sub.Parent := Root; Sub.Text := 'Dynamic Digital Signage.'; Sub.Position.Y := 260; Sub.TextSettings.Font.Size := 16; Sub.TextSettings.FontColor := THEME_TEXT_MUTE;
end;

procedure TSplashForm.FormShow(Sender: TObject);
begin
  {$IFDEF ANDROID} __android_log_write(android_LogPriority.ANDROID_LOG_DEBUG, 'DisplayDeck', 'Splash FormShow'); {$ENDIF}
  TThread.CreateAnonymousThread(
    procedure
    begin
      Sleep(800);
      TThread.Queue(nil, GoNext);
    end
  ).Start;
end;

procedure TSplashForm.GoNext;
begin
  {$IFDEF ANDROID} __android_log_write(android_LogPriority.ANDROID_LOG_DEBUG, 'DisplayDeck', 'Splash GoNext'); {$ENDIF}
  if not Assigned(LoginForm) then
    Application.CreateForm(TLoginForm, LoginForm);
  TThread.Queue(nil,
    procedure
    begin
      {$IFDEF ANDROID} __android_log_write(android_LogPriority.ANDROID_LOG_DEBUG, 'DisplayDeck', 'Showing Login'); {$ENDIF}
      LoginForm.Show;
      // Do not close the first (main) form on mobile; hide it to keep app alive
      Hide;
    end);
end;

end.
