unit LoginFrame;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants, 
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  FMX.Objects, FMX.Layouts, FMX.Edit, FMX.Controls.Presentation;

type
  // Event type for when login succeeds
  TLoginSuccessEvent = procedure(Sender: TObject) of object;
  TRegisterRequestEvent = procedure(Sender: TObject) of object;

  TFrame1 = class(TFrame)
    LayoutBackground: TLayout;
    RectBackground: TRectangle;
    LayoutCenter: TLayout;
    RectCard: TRectangle;
    LayoutContent: TLayout;
    lblTitle: TLabel;
    LayoutSpacer1: TLayout;
    edEmail: TEdit;
    LayoutSpacer2: TLayout;
    edPassword: TEdit;
    LayoutSpacer3: TLayout;
    btnLogin: TButton;
    LayoutSpacer4: TLayout;
    lblRegister: TLabel;
    LayoutBottom: TLayout;
    procedure btnLoginClick(Sender: TObject);
    procedure lblRegisterClick(Sender: TObject);
  private
    { Private declarations }
    FOnLoginSuccess: TLoginSuccessEvent;
    FOnRegisterRequest: TRegisterRequestEvent;
    procedure ShowError(const AMessage: string);
    function ValidateInput: Boolean;
  public
    { Public declarations }
    property OnLoginSuccess: TLoginSuccessEvent read FOnLoginSuccess write FOnLoginSuccess;
    property OnRegisterRequest: TRegisterRequestEvent read FOnRegisterRequest write FOnRegisterRequest;
  end;

implementation

{$R *.fmx}

procedure TFrame1.btnLoginClick(Sender: TObject);
begin
  // Validate input
  if not ValidateInput then
    Exit;

  // TODO: Call API client to authenticate
  // For now, just show what we'd do:
  
  // Disable button to prevent double-clicks
  btnLogin.Enabled := False;
  btnLogin.Text := 'Logging in...';
  
  // This is where we'll call the API
  // Example:
  // var Token := TApiClient.Instance.PostJson('/auth/login', 
  //   '{"Email":"' + edEmail.Text + '","Password":"' + edPassword.Text + '"}');
  
  // For now, simulate success (REMOVE THIS LATER)
  ShowMessage('Login would happen here with:' + #13#10 + 
              'Email: ' + edEmail.Text + #13#10 +
              'Password: ' + edPassword.Text);
  
  // Reset button state BEFORE triggering event (which may destroy this frame)
  btnLogin.Enabled := True;
  btnLogin.Text := 'Login';
  
  // On success, trigger the event
  // This may destroy the frame, so nothing should execute after this
  if Assigned(FOnLoginSuccess) then
    FOnLoginSuccess(Self);
end;

procedure TFrame1.lblRegisterClick(Sender: TObject);
begin
  // Trigger register request event
  if Assigned(FOnRegisterRequest) then
    FOnRegisterRequest(Self);
end;

function TFrame1.ValidateInput: Boolean;
begin
  Result := False;
  
  // Check email
  if edEmail.Text.Trim.IsEmpty then
  begin
    ShowError('Please enter your email address');
    edEmail.SetFocus;
    Exit;
  end;
  
  // Basic email validation
  if not edEmail.Text.Contains('@') then
  begin
    ShowError('Please enter a valid email address');
    edEmail.SetFocus;
    Exit;
  end;
  
  // Check password
  if edPassword.Text.Trim.IsEmpty then
  begin
    ShowError('Please enter your password');
    edPassword.SetFocus;
    Exit;
  end;
  
  // Password length check
  if edPassword.Text.Length < 6 then
  begin
    ShowError('Password must be at least 6 characters');
    edPassword.SetFocus;
    Exit;
  end;
  
  Result := True;
end;

procedure TFrame1.ShowError(const AMessage: string);
begin
  // For now, use simple MessageDlg
  // Later we can make this prettier with an in-form error label
  MessageDlg(AMessage, TMsgDlgType.mtError, [TMsgDlgBtn.mbOK], 0);
end;

end.
