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
    RectLoginBtn: TRectangle;
    LblLoginBtn: TLabel;
    LayoutSpacer4: TLayout;
    RectLoginError: TRectangle;
    LblLoginError: TLabel;
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
  StyleGradientBackground(RectBackground);
  
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
  // Use a style-independent button surface (rectangle + label)
  RectLoginBtn.Fill.Kind := TBrushKind.Solid;
  RectLoginBtn.Fill.Color := ColorPrimary;
  RectLoginBtn.Stroke.Kind := TBrushKind.None;
  RectLoginBtn.XRadius := 10;
  RectLoginBtn.YRadius := 10;
  RectLoginBtn.Height := 50;
  RectLoginBtn.Margins.Top := 20;
  RectLoginBtn.Cursor := crHandPoint;
  RectLoginBtn.HitTest := True;
  LblLoginBtn.TextSettings.FontColor := TAlphaColorRec.White;
  LblLoginBtn.StyledSettings := LblLoginBtn.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size];
  LblLoginBtn.TextSettings.Font.Size := 16;
  LblLoginBtn.TextSettings.Font.Style := [TFontStyle.fsBold];
  LblLoginBtn.TextSettings.HorzAlign := TTextAlign.Center;
  LblLoginBtn.TextSettings.VertAlign := TTextAlign.Center;
  LblLoginBtn.HitTest := False;
  LblLoginBtn.Text := 'Login';

  // Inline error callout (themed)
  if Assigned(RectLoginError) then
  begin
    RectLoginError.Fill.Kind := TBrushKind.Solid;
    RectLoginError.Fill.Color := $FFFEE2E2; // Red 100
    RectLoginError.Stroke.Kind := TBrushKind.None;
    RectLoginError.XRadius := 10;
    RectLoginError.YRadius := 10;
    RectLoginError.Visible := False;
  end;
  if Assigned(LblLoginError) then
  begin
    LblLoginError.TextSettings.FontColor := $FF991B1B; // Red 800
    LblLoginError.StyledSettings := LblLoginError.StyledSettings - [TStyledSetting.FontColor];
    LblLoginError.WordWrap := True;
  end;
  
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

  if Assigned(RectLoginError) then
    RectLoginError.Visible := False;

  // Prevent double-clicks without relying on styled disabled state.
  RectLoginBtn.HitTest := False;
  RectLoginBtn.Opacity := 0.92;
  LblLoginBtn.Text := 'Logging in...';
  
  try
    // Call API to authenticate
    LoginResult := TApiClient.Instance.Login(edEmail.Text, edPassword.Text);
    
    if LoginResult.Success then
    begin
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
      RectLoginBtn.HitTest := True;
      RectLoginBtn.Opacity := 1.0;
      LblLoginBtn.Text := 'Login';
    end;
  except
    on E: Exception do
    begin
      ShowError('Login failed: ' + E.Message);
      RectLoginBtn.HitTest := True;
      RectLoginBtn.Opacity := 1.0;
      LblLoginBtn.Text := 'Login';
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
  if Assigned(LblLoginError) and Assigned(RectLoginError) then
  begin
    LblLoginError.Text := AMessage;
    RectLoginError.Visible := True;
    Exit;
  end;

  // Fallback
  TDialogServiceSync.MessageDialog(AMessage, TMsgDlgType.mtError, [TMsgDlgBtn.mbOK], TMsgDlgBtn.mbOK, 0);
end;

end.
