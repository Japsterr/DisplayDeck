unit RegisterFrame;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants, 
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  FMX.Edit, FMX.Controls.Presentation, FMX.Objects, FMX.Layouts;

type
  // Event types
  TRegisterSuccessEvent = procedure(Sender: TObject) of object;
  TLoginRequestEvent = procedure(Sender: TObject) of object;

  TFrame2 = class(TFrame)
    LayoutBackground: TLayout;
    RectBackground: TRectangle;
    LayoutCenter: TLayout;
    RectCard: TRectangle;
    LayoutContent: TLayout;
    lblTitle: TLabel;
    LayoutSpacer1: TLayout;
    edOrganizationName: TEdit;
    LayoutSpacer2: TLayout;
    edEmail: TEdit;
    LayoutSpacer3: TLayout;
    edPassword: TEdit;
    LayoutSpacer4: TLayout;
    edPasswordConfirm: TEdit;
    LayoutSpacer5: TLayout;
    btnRegister: TButton;
    LayoutSpacer6: TLayout;
    lblLogin: TLabel;
    LayoutBottom: TLayout;
    procedure btnRegisterClick(Sender: TObject);
    procedure lblLoginClick(Sender: TObject);
  private
    { Private declarations }
    FOnRegisterSuccess: TRegisterSuccessEvent;
    FOnLoginRequest: TLoginRequestEvent;
    procedure ShowError(const AMessage: string);
    function ValidateInput: Boolean;
  public
    { Public declarations }
    property OnRegisterSuccess: TRegisterSuccessEvent read FOnRegisterSuccess write FOnRegisterSuccess;
    property OnLoginRequest: TLoginRequestEvent read FOnLoginRequest write FOnLoginRequest;
  end;

implementation

{$R *.fmx}

procedure TFrame2.btnRegisterClick(Sender: TObject);
begin
  // Validate input
  if not ValidateInput then
    Exit;

  // TODO: Call API client to register
  // For now, just show what we'd do:
  
  // Disable button to prevent double-clicks
  btnRegister.Enabled := False;
  btnRegister.Text := 'Creating account...';
  
  // This is where we'll call the API
  // Example:
  // var Response := TApiClient.Instance.PostJson('/auth/register', 
  //   '{"Email":"' + edEmail.Text + 
  //   '","Password":"' + edPassword.Text + 
  //   '","OrganizationName":"' + edOrganizationName.Text + '"}');
  
  // For now, simulate success (REMOVE THIS LATER)
  ShowMessage('Registration would happen here with:' + #13#10 + 
              'Organization: ' + edOrganizationName.Text + #13#10 +
              'Email: ' + edEmail.Text + #13#10 +
              'Password: ' + edPassword.Text);
  
  // Reset button state BEFORE triggering event (which may destroy this frame)
  btnRegister.Enabled := True;
  btnRegister.Text := 'Create Account';
  
  // On success, trigger the event
  // This may destroy the frame, so nothing should execute after this
  if Assigned(FOnRegisterSuccess) then
    FOnRegisterSuccess(Self);
end;

procedure TFrame2.lblLoginClick(Sender: TObject);
begin
  // Trigger login request event (switch back to login frame)
  if Assigned(FOnLoginRequest) then
    FOnLoginRequest(Self);
end;

function TFrame2.ValidateInput: Boolean;
begin
  Result := False;
  
  // Check organization name
  if edOrganizationName.Text.Trim.IsEmpty then
  begin
    ShowError('Please enter your organization name');
    edOrganizationName.SetFocus;
    Exit;
  end;
  
  // Check organization name length
  if edOrganizationName.Text.Trim.Length < 2 then
  begin
    ShowError('Organization name must be at least 2 characters');
    edOrganizationName.SetFocus;
    Exit;
  end;
  
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
    ShowError('Please enter a password');
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
  
  // Check password confirmation
  if edPasswordConfirm.Text.Trim.IsEmpty then
  begin
    ShowError('Please confirm your password');
    edPasswordConfirm.SetFocus;
    Exit;
  end;
  
  // Check passwords match
  if edPassword.Text <> edPasswordConfirm.Text then
  begin
    ShowError('Passwords do not match');
    edPasswordConfirm.SetFocus;
    Exit;
  end;
  
  Result := True;
end;

procedure TFrame2.ShowError(const AMessage: string);
begin
  // For now, use simple MessageDlg
  // Later we can make this prettier with an in-form error label
  MessageDlg(AMessage, TMsgDlgType.mtError, [TMsgDlgBtn.mbOK], 0);
end;

end.
