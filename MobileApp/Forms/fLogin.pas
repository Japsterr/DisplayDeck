unit fLogin;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Edit, FMX.Layouts,
  FMX.Controls.Presentation, FMX.Objects, FMX.Graphics, FMX.VirtualKeyboard;

type
  TLoginForm = class(TForm)
    LayoutRoot: TLayout;
    RectCard: TRectangle;
    LabelTitle: TLabel;
    EditEmail: TEdit;
    EditPassword: TEdit;
    BtnLogin: TButton;
    BtnRegister: TButton;
    LabelMessage: TLabel;
    TimerShow: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure BtnLoginClick(Sender: TObject);
    procedure BtnRegisterClick(Sender: TObject);
    procedure TimerShowTimer(Sender: TObject);
  private
    procedure NavigateToMain;
  public
  end;

var
  LoginForm: TLoginForm;

implementation

{$R *.fmx}

uses uAuthService, fMain, uTheme
{$IFDEF ANDROID}, Androidapi.Log{$ENDIF};

procedure TLoginForm.FormCreate(Sender: TObject);
var
  BG: TRectangle;
begin
  {$IFDEF ANDROID} __android_log_write(android_LogPriority.ANDROID_LOG_DEBUG, 'DisplayDeck', 'Login FormCreate'); {$ENDIF}
  // Ensure a background exists and fills the client
  if FindComponent('RectBackground') is TRectangle then
  begin
    (FindComponent('RectBackground') as TRectangle).Fill.Color := THEME_BG;
    (FindComponent('RectBackground') as TRectangle).Stroke.Kind := TBrushKind.None;
  end
  else
  begin
    BG := TRectangle.Create(Self);
    BG.Name := 'RectBackground';
    BG.Parent := Self;
    BG.Align := TAlignLayout.Client;
    BG.Fill.Color := THEME_BG;
    BG.Stroke.Kind := TBrushKind.None;
  end;

  // Ensure root layout exists
  if not Assigned(LayoutRoot) then
  begin
    LayoutRoot := TLayout.Create(Self);
    LayoutRoot.Parent := Self;
  end;
  LayoutRoot.Align := TAlignLayout.Client;

  // Ensure card exists
  if not Assigned(RectCard) then
  begin
    RectCard := TRectangle.Create(Self);
    RectCard.Parent := LayoutRoot;
    RectCard.Position.X := 20;
    RectCard.Position.Y := 100;
    RectCard.Size.Width := 320;
    RectCard.Size.Height := 360;
    RectCard.XRadius := 12;
    RectCard.YRadius := 12;
    RectCard.Stroke.Kind := TBrushKind.None;
  end;
  RectCard.Fill.Color := THEME_SURFACE;

  // Ensure children controls exist
  if not Assigned(LabelTitle) then
  begin
    LabelTitle := TLabel.Create(Self);
    LabelTitle.Parent := RectCard;
    LabelTitle.Position.X := 16;
    LabelTitle.Position.Y := 16;
    LabelTitle.Text := 'DisplayDeck';
    LabelTitle.TextSettings.Font.Size := 24;
    LabelTitle.TextSettings.FontColor := THEME_TEXT;
  end;

  if not Assigned(EditEmail) then
  begin
    EditEmail := TEdit.Create(Self);
    EditEmail.Parent := RectCard;
    EditEmail.Position.X := 16;
    EditEmail.Position.Y := 72;
    EditEmail.Size.Width := 288;
    EditEmail.Size.Height := 32;
    EditEmail.TextPrompt := 'Email';
    EditEmail.KeyboardType := TVirtualKeyboardType.EmailAddress;
  end;

  if not Assigned(EditPassword) then
  begin
    EditPassword := TEdit.Create(Self);
    EditPassword.Parent := RectCard;
    EditPassword.Position.X := 16;
    EditPassword.Position.Y := 120;
    EditPassword.Size.Width := 288;
    EditPassword.Size.Height := 32;
    EditPassword.TextPrompt := 'Password';
    EditPassword.Password := True;
  end
  else
    EditPassword.Password := True;

  if not Assigned(BtnLogin) then
  begin
    BtnLogin := TButton.Create(Self);
    BtnLogin.Parent := RectCard;
    BtnLogin.Position.X := 16;
    BtnLogin.Position.Y := 180;
    BtnLogin.Size.Width := 288;
    BtnLogin.Size.Height := 36;
    BtnLogin.Text := 'Login';
    BtnLogin.OnClick := BtnLoginClick;
  end;

  if not Assigned(BtnRegister) then
  begin
    BtnRegister := TButton.Create(Self);
    BtnRegister.Parent := RectCard;
    BtnRegister.Position.X := 16;
    BtnRegister.Position.Y := 228;
    BtnRegister.Size.Width := 288;
    BtnRegister.Size.Height := 36;
    BtnRegister.Text := 'Register';
    BtnRegister.OnClick := BtnRegisterClick;
  end;

  if not Assigned(LabelMessage) then
  begin
    LabelMessage := TLabel.Create(Self);
    LabelMessage.Parent := RectCard;
    LabelMessage.Position.X := 16;
    LabelMessage.Position.Y := 280;
    LabelMessage.Size.Width := 288;
    LabelMessage.Size.Height := 17;
    LabelMessage.TextSettings.FontColor := THEME_OFFLINE;
  end;

  // A tiny timer to reinforce Z-order after first layout pass
  TimerShow := TTimer.Create(Self);
  TimerShow.Enabled := False;
  TimerShow.Interval := 250;
  TimerShow.OnTimer := TimerShowTimer;
end;

procedure TLoginForm.FormShow(Sender: TObject);
begin
  {$IFDEF ANDROID} __android_log_write(android_LogPriority.ANDROID_LOG_DEBUG, 'DisplayDeck', 'Login FormShow'); {$ENDIF}
  // Ensure form is visible after splash closes
  Self.Visible := True;
  if Assigned(LayoutRoot) then LayoutRoot.BringToFront;
  if Assigned(RectCard) then RectCard.BringToFront;
  if Assigned(TimerShow) then TimerShow.Enabled := True;
end;

procedure TLoginForm.NavigateToMain;
begin
  {$IFDEF ANDROID} __android_log_write(android_LogPriority.ANDROID_LOG_DEBUG, 'DisplayDeck', 'Login NavigateToMain'); {$ENDIF}
  if not Assigned(MainForm) then
    Application.CreateForm(TMainForm, MainForm);
  MainForm.Show;
  // Keep login around but hidden to avoid destroying focus during transition
  Self.Hide;
end;

procedure TLoginForm.TimerShowTimer(Sender: TObject);
begin
  TimerShow.Enabled := False;
  if Assigned(LayoutRoot) then LayoutRoot.BringToFront;
  if Assigned(RectCard) then RectCard.BringToFront;
end;

procedure TLoginForm.BtnLoginClick(Sender: TObject);
begin
  LabelMessage.Text := '';
  try
    if TAuthService.Instance.Login(EditEmail.Text, EditPassword.Text) then
      NavigateToMain
    else
      LabelMessage.Text := 'Invalid email or password';
  except
    on E: Exception do
      LabelMessage.Text := E.Message;
  end;
end;

procedure TLoginForm.BtnRegisterClick(Sender: TObject);
begin
  LabelMessage.Text := '';
  try
    if TAuthService.Instance.Register(EditEmail.Text, EditPassword.Text, 'My Organization') then
      NavigateToMain
    else
      LabelMessage.Text := 'Registration failed';
  except
    on E: Exception do
      LabelMessage.Text := E.Message;
  end;
end;

end.
