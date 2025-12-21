unit LoginFrame;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants, 
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  FMX.Objects, FMX.Layouts, FMX.Edit, FMX.Controls.Presentation, uApiClient,
  FMX.DialogService.Sync, uTheme;

type
  // Event type for when login succeeds
  TLoginSuccessEvent = procedure(Sender: TObject; const AToken: string; 
    AUserId, AOrganizationId: Integer; const AUserName, AEmail, AOrgName: string) of object;
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
    procedure Initialize;
  end;

implementation

{$R *.fmx}

procedure TFrame1.Initialize;
begin
  // Gradient background for visual interest - VIBRANT & DARK
  RectBackground.Fill.Kind := TBrushKind.Gradient;
  RectBackground.Fill.Gradient.StartPosition.Point := TPointF.Create(0, 0);
  RectBackground.Fill.Gradient.StopPosition.Point := TPointF.Create(1, 1);
  RectBackground.Fill.Gradient.Color := $FF0F172A; // Slate 900 (Dark)
  RectBackground.Fill.Gradient.Color1 := $FF2563EB; // Blue 600 (Vibrant)
  
  StyleCard(RectCard);
  // Center the card
  LayoutCenter.Align := TAlignLayout.Center;
  RectCard.Width := 420; // Slightly wider
  RectCard.Height := 480; // Slightly taller
  
  StyleHeaderLabel(lblTitle);
  lblTitle.TextAlign := TTextAlign.Center;
  lblTitle.TextSettings.FontColor := ColorPrimary; // Make title pop
  lblTitle.StyledSettings := lblTitle.StyledSettings - [TStyledSetting.FontColor];
  
  StyleInput(edEmail);
  StyleInput(edPassword);
  StylePrimaryButton(btnLogin);
  btnLogin.Height := 50; // Even taller button
  btnLogin.Margins.Top := 20;
  
  // Style register link
  lblRegister.TextSettings.FontColor := $FFFFFFFF; // White text on dark bg (if outside card) or Primary if inside
  // Wait, lblRegister is inside LayoutContent which is inside RectCard?
  // Let's check structure. RectCard contains LayoutContent.
  // So lblRegister is on the White Card. So it should be Primary.
  lblRegister.TextSettings.FontColor := ColorPrimary;
  lblRegister.StyledSettings := lblRegister.StyledSettings - [TStyledSetting.FontColor];
  lblRegister.Cursor := crHandPoint;
  lblRegister.HitTest := True;
  lblRegister.TextAlign := TTextAlign.Center;
end;

procedure TFrame1.btnLoginClick(Sender: TObject);
var
  LoginResult: TLoginResponse;
begin
  // Validate input
  if not ValidateInput then
    Exit;

  // Disable button to prevent double-clicks
  btnLogin.Enabled := False;
  btnLogin.Text := 'Logging in...';
  
  try
    // Call API to authenticate
    LoginResult := TApiClient.Instance.Login(edEmail.Text, edPassword.Text);
    
    if LoginResult.Success then
    begin
      // Show success message
      ShowMessage('Login successful! Welcome back.');
      
      // Clear password field for security
      edPassword.Text := '';
      
      // Trigger success event with user data
      if Assigned(FOnLoginSuccess) then
        FOnLoginSuccess(Self, LoginResult.Token, LoginResult.UserId, 
          LoginResult.OrganizationId, LoginResult.UserName, LoginResult.UserEmail, 
          LoginResult.OrganizationName);
    end
    else
    begin
      // Show error message
      ShowError(LoginResult.Message);
      btnLogin.Enabled := True;
      btnLogin.Text := 'Login';
    end;
  except
    on E: Exception do
    begin
      ShowError('Login failed: ' + E.Message);
      btnLogin.Enabled := True;
      btnLogin.Text := 'Login';
    end;
  end;
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
  TDialogServiceSync.MessageDialog(AMessage, TMsgDlgType.mtError, [TMsgDlgBtn.mbOK], TMsgDlgBtn.mbOK, 0);
end;

end.
