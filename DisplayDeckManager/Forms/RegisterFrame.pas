unit RegisterFrame;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants, 
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  FMX.Edit, FMX.Controls.Presentation, FMX.Objects, FMX.Layouts, uApiClient,
  FMX.DialogService.Sync, uTheme;

type
  // Event types
  TRegisterSuccessEvent = procedure(Sender: TObject; const AToken: string; 
    AUserId, AOrganizationId: Integer; const AUserName, AEmail, AOrgName: string) of object;
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
    RectRegisterBtn: TRectangle;
    LblRegisterBtn: TLabel;
    LayoutSpacer6: TLayout;
    RectRegisterError: TRectangle;
    LblRegisterError: TLabel;
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
    procedure Initialize;
  end;

implementation

{$R *.fmx}

procedure TFrame2.Initialize;
begin
  // Match Login screen styling for a consistent auth experience
  StyleGradientBackground(RectBackground);

  StyleCard(RectCard);
  LayoutCenter.Align := TAlignLayout.Center;
  RectCard.Width := 420;
  RectCard.Height := 620;

  StyleHeaderLabel(lblTitle);
  lblTitle.TextAlign := TTextAlign.Center;
  lblTitle.TextSettings.FontColor := ColorPrimary;
  lblTitle.StyledSettings := lblTitle.StyledSettings - [TStyledSetting.FontColor];
  
  StyleInput(edOrganizationName);
  StyleInput(edEmail);
  StyleInput(edPassword);
  StyleInput(edPasswordConfirm);

  // Use a style-independent button surface (rectangle + label)
  RectRegisterBtn.Fill.Kind := TBrushKind.Solid;
  RectRegisterBtn.Fill.Color := ColorPrimary;
  RectRegisterBtn.Stroke.Kind := TBrushKind.None;
  RectRegisterBtn.XRadius := 10;
  RectRegisterBtn.YRadius := 10;
  RectRegisterBtn.Height := 50;
  RectRegisterBtn.Margins.Top := 10;
  RectRegisterBtn.Cursor := crHandPoint;
  RectRegisterBtn.HitTest := True;
  LblRegisterBtn.TextSettings.FontColor := TAlphaColorRec.White;
  LblRegisterBtn.StyledSettings := LblRegisterBtn.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size];
  LblRegisterBtn.TextSettings.Font.Size := 16;
  LblRegisterBtn.TextSettings.Font.Style := [TFontStyle.fsBold];
  LblRegisterBtn.TextSettings.HorzAlign := TTextAlign.Center;
  LblRegisterBtn.TextSettings.VertAlign := TTextAlign.Center;
  LblRegisterBtn.HitTest := False;
  LblRegisterBtn.Text := 'Create Account';

  // Inline error callout (themed)
  if Assigned(RectRegisterError) then
  begin
    RectRegisterError.Fill.Kind := TBrushKind.Solid;
    RectRegisterError.Fill.Color := $FFFEE2E2; // Red 100
    RectRegisterError.Stroke.Kind := TBrushKind.None;
    RectRegisterError.XRadius := 10;
    RectRegisterError.YRadius := 10;
    RectRegisterError.Visible := False;
  end;
  if Assigned(LblRegisterError) then
  begin
    LblRegisterError.TextSettings.FontColor := $FF991B1B; // Red 800
    LblRegisterError.StyledSettings := LblRegisterError.StyledSettings - [TStyledSetting.FontColor];
    LblRegisterError.WordWrap := True;
  end;
  
  // Style login link
  lblLogin.TextSettings.FontColor := ColorPrimary;
  lblLogin.StyledSettings := lblLogin.StyledSettings - [TStyledSetting.FontColor];
  lblLogin.Cursor := crHandPoint;
  lblLogin.HitTest := True;
  lblLogin.TextAlign := TTextAlign.Center;
end;

procedure TFrame2.btnRegisterClick(Sender: TObject);
var
  RegisterResult: TRegisterResponse;
begin
  // Validate input
  if not ValidateInput then
    Exit;

  if Assigned(RectRegisterError) then
    RectRegisterError.Visible := False;

  // Prevent double-clicks without relying on styled disabled state.
  RectRegisterBtn.HitTest := False;
  RectRegisterBtn.Opacity := 0.92;
  LblRegisterBtn.Text := 'Creating account...';
  
  try
    // Call API to register
    RegisterResult := TApiClient.Instance.Register(edEmail.Text, edPassword.Text, 
      edOrganizationName.Text);
    
    if RegisterResult.Success then
    begin
      // Clear password fields for security
      edPassword.Text := '';
      edPasswordConfirm.Text := '';
      
      // Note: Backend auto-creates organization and returns user data
      // We use the token and userId from response
      // Trigger success event with registration data
      if Assigned(FOnRegisterSuccess) then
        FOnRegisterSuccess(Self, RegisterResult.Token, RegisterResult.UserId, 
          RegisterResult.OrganizationId, edEmail.Text, edEmail.Text, edOrganizationName.Text);
    end
    else
    begin
      // Show error message
      ShowError(RegisterResult.Message);
      RectRegisterBtn.HitTest := True;
      RectRegisterBtn.Opacity := 1.0;
      LblRegisterBtn.Text := 'Create Account';
    end;
  except
    on E: Exception do
    begin
      ShowError('Registration failed: ' + E.Message);
      RectRegisterBtn.HitTest := True;
      RectRegisterBtn.Opacity := 1.0;
      LblRegisterBtn.Text := 'Create Account';
    end;
  end;
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
  if Assigned(LblRegisterError) and Assigned(RectRegisterError) then
  begin
    LblRegisterError.Text := AMessage;
    RectRegisterError.Visible := True;
    Exit;
  end;

  // Fallback
  TDialogServiceSync.MessageDialog(AMessage, TMsgDlgType.mtError, [TMsgDlgBtn.mbOK], TMsgDlgBtn.mbOK, 0);
end;

end.
