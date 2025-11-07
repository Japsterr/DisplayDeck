unit LoginFrame;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants, 
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  FMX.Objects, FMX.Layouts, FMX.Edit, FMX.Controls.Presentation, uApiClient;

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
  end;

implementation

{$R *.fmx}

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
    
    // DEBUG: Show RAW result
    ShowMessage('=== RAW LOGIN RESULT ===' + #13#10 +
      'Success: ' + BoolToStr(LoginResult.Success, True) + #13#10 +
      'Message: ' + LoginResult.Message + #13#10 +
      'Token: ' + Copy(LoginResult.Token, 1, 20) + #13#10 +
      'UserID: ' + IntToStr(LoginResult.UserId) + #13#10 +
      'OrgID: ' + IntToStr(LoginResult.OrganizationId) + #13#10 +
      'LastURL: ' + TApiClient.Instance.LastURL + #13#10 +
      'LastCode: ' + IntToStr(TApiClient.Instance.LastResponseCode) + #13#10 +
      'LastBody: ' + Copy(TApiClient.Instance.LastResponseBody, 1, 200));
    
    if LoginResult.Success then
    begin
      // DEBUG: Show EVERYTHING we got from server
      ShowMessage('=== LOGIN DEBUG ===' + #13#10 +
        'Success: ' + BoolToStr(LoginResult.Success, True) + #13#10 +
        'Token: ' + Copy(LoginResult.Token, 1, 30) + '...' + #13#10 +
        'UserID: ' + IntToStr(LoginResult.UserId) + #13#10 +
        'OrgID: ' + IntToStr(LoginResult.OrganizationId) + #13#10 +
        'UserName: ' + LoginResult.UserName + #13#10 +
        'UserEmail: ' + LoginResult.UserEmail + #13#10 +
        'OrgName: ' + LoginResult.OrganizationName + #13#10 +
        'Message: ' + LoginResult.Message + #13#10 +
        '===================');
      
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
  // For now, use simple MessageDlg
  // Later we can make this prettier with an in-form error label
  MessageDlg(AMessage, TMsgDlgType.mtError, [TMsgDlgBtn.mbOK], 0);
end;

end.
