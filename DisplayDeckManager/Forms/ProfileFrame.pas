unit ProfileFrame;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.Objects, FMX.Layouts, FMX.Edit;

type
  TFrame4 = class(TFrame)
    LayoutBackground: TLayout;
    RectBackground: TRectangle;
    LayoutMain: TLayout;
    RectCard: TRectangle;
    LayoutCardContent: TLayout;
    lblTitle: TLabel;
    ScrollBoxProfile: TVertScrollBox;
    LayoutForm: TLayout;
    lblSectionUser: TLabel;
    lblFullName: TLabel;
    edtFullName: TEdit;
    lblEmail: TLabel;
    edtEmail: TEdit;
    lblSectionOrganization: TLabel;
    lblOrgName: TLabel;
    edtOrgName: TEdit;
    lblSubscription: TLabel;
    edtSubscription: TEdit;
    lblSectionSecurity: TLabel;
    lblNewPassword: TLabel;
    edtNewPassword: TEdit;
    lblConfirmPassword: TLabel;
    edtConfirmPassword: TEdit;
    LayoutButtons: TLayout;
    btnSaveProfile: TButton;
    procedure btnSaveProfileClick(Sender: TObject);
  private
    FUserId: Integer;
    FOrganizationId: Integer;
    procedure LoadUserProfile;
    function ValidateForm: Boolean;
  public
    procedure Initialize(AUserId, AOrganizationId: Integer; const AUserName, AEmail: string);
  end;

implementation

{$R *.fmx}

uses
  System.JSON, FMX.DialogService, uTheme;

// API Base: http://localhost:2001/tms/xdata
// Endpoints:
//   GET  /users/{UserId} - Get user profile
//   PUT  /users/{UserId} - Update user profile
//   PUT  /users/{UserId}/password - Change password
//   GET  /organizations/{OrgId} - Get organization details
//   PUT  /organizations/{OrgId} - Update organization

procedure TFrame4.Initialize(AUserId, AOrganizationId: Integer; const AUserName, AEmail: string);
begin
  FUserId := AUserId;
  FOrganizationId := AOrganizationId;
  edtEmail.Text := AEmail;
  edtFullName.Text := AUserName;
  LoadUserProfile;
end;

procedure TFrame4.LoadUserProfile;
begin
  // Placeholder values until wired to real API
  if edtOrgName.Text = '' then
    edtOrgName.Text := 'Organization';
  if edtSubscription.Text = '' then
    edtSubscription.Text := 'Free';
end;

function TFrame4.ValidateForm: Boolean;
begin
  Result := False;

  if Trim(edtFullName.Text) = '' then
  begin
    TDialogService.ShowMessage('Please enter your full name');
    Exit;
  end;

  if Trim(edtOrgName.Text) = '' then
  begin
    TDialogService.ShowMessage('Please enter organization name');
    Exit;
  end;

  // If password fields are filled, validate them
  if (Trim(edtNewPassword.Text) <> '') or (Trim(edtConfirmPassword.Text) <> '') then
  begin
    if Length(Trim(edtNewPassword.Text)) < 6 then
    begin
      TDialogService.ShowMessage('Password must be at least 6 characters');
      Exit;
    end;

    if edtNewPassword.Text <> edtConfirmPassword.Text then
    begin
      TDialogService.ShowMessage('Passwords do not match');
      Exit;
    end;
  end;

  Result := True;
end;

procedure TFrame4.btnSaveProfileClick(Sender: TObject);
begin
  if not ValidateForm then
    Exit;

  // TODO: API call to update user/organization and optional password
  TDialogService.ShowMessage('Profile updated successfully');

  // Clear password fields
  edtNewPassword.Text := '';
  edtConfirmPassword.Text := '';
end;

end.



