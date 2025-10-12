unit uLoginForm;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Edit,
  FMX.StdCtrls, FMX.Controls.Presentation, FMX.Layouts;

type
  TLoginForm = class(TForm)
    Layout1: TLayout;
    edtEmail: TEdit;
    edtPassword: TEdit;
    btnLogin: TButton;
    btnRegister: TButton;
    lblTitle: TLabel;
    procedure btnLoginClick(Sender: TObject);
    procedure btnRegisterClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
    function ValidateInput: Boolean;
    procedure PerformLogin;
    procedure PerformRegister;
  public
    { Public declarations }
  end;

var
  LoginForm: TLoginForm;

implementation

{$R *.fmx}

uses
  uApiClient, uEntities;

procedure TLoginForm.FormCreate(Sender: TObject);
begin
  lblTitle.Text := 'DisplayDeck Login';
  edtEmail.TextPrompt := 'Email';
  edtPassword.TextPrompt := 'Password';
  edtPassword.Password := True;
end;

function TLoginForm.ValidateInput: Boolean;
begin
  Result := False;

  if Trim(edtEmail.Text).IsEmpty then
  begin
    ShowMessage('Please enter your email address');
    edtEmail.SetFocus;
    Exit;
  end;

  if Trim(edtPassword.Text).IsEmpty then
  begin
    ShowMessage('Please enter your password');
    edtPassword.SetFocus;
    Exit;
  end;

  Result := True;
end;

procedure TLoginForm.btnLoginClick(Sender: TObject);
begin
  if not ValidateInput then
    Exit;

  PerformLogin;
end;

procedure TLoginForm.btnRegisterClick(Sender: TObject);
begin
  if Trim(edtEmail.Text).IsEmpty then
  begin
    ShowMessage('Please enter your email address');
    edtEmail.SetFocus;
    Exit;
  end;

  if Trim(edtPassword.Text).IsEmpty then
  begin
    ShowMessage('Please enter your password');
    edtPassword.SetFocus;
    Exit;
  end;

  PerformRegister;
end;

procedure TLoginForm.PerformLogin;
var
  LoginRequest: TLoginRequest;
  Response: TAuthResponse;
begin
  LoginRequest := TLoginRequest.Create;
  try
    LoginRequest.Email := Trim(edtEmail.Text);
    LoginRequest.Password := edtPassword.Text;

    Response := TApiClient.Instance.Login(LoginRequest);

    try
      if Response.Success then
      begin
        ModalResult := mrOk;
      end
      else
      begin
        ShowMessage('Login failed: ' + Response.Message);
      end;
    finally
      Response.Free;
    end;
  finally
    LoginRequest.Free;
  end;
end;

procedure TLoginForm.PerformRegister;
var
  RegisterRequest: TRegisterRequest;
  Response: TAuthResponse;
  OrgName: string;
begin
  OrgName := InputBox('Organization', 'Enter your organization name:', '');
  if OrgName.IsEmpty then
    Exit;

  RegisterRequest := TRegisterRequest.Create;
  try
    RegisterRequest.Email := Trim(edtEmail.Text);
    RegisterRequest.Password := edtPassword.Text;
    RegisterRequest.OrganizationName := OrgName;

    Response := TApiClient.Instance.Register(RegisterRequest);

    try
      if Response.Success then
      begin
        ShowMessage('Registration successful! You can now login.');
      end
      else
      begin
        ShowMessage('Registration failed: ' + Response.Message);
      end;
    finally
      Response.Free;
    end;
  finally
    RegisterRequest.Free;
  end;
end;

end.