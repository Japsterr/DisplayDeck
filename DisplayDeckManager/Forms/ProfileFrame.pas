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


