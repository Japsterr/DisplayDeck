unit uMainForm;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.TabControl,
  FMX.StdCtrls, FMX.Controls.Presentation;

type
  TMainForm = class(TForm)
    TabControl: TTabControl;
    tabCampaigns: TTabItem;
    tabMedia: TTabItem;
    tabDisplays: TTabItem;
    tabSettings: TTabItem;
    btnLogout: TButton;
    procedure FormCreate(Sender: TObject);
    procedure btnLogoutClick(Sender: TObject);
    procedure TabControlChange(Sender: TObject);
  private
    { Private declarations }
    procedure ShowLoginForm;
    procedure LoadCampaignsTab;
    procedure LoadMediaTab;
    procedure LoadDisplaysTab;
  public
    { Public declarations }
  end;

var
  MainForm: TMainForm;

implementation

{$R *.fmx}

uses
  uLoginForm, uCampaignListForm, uMediaLibraryForm, uDisplayManagerForm, uApiClient;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  // Check if user is logged in
  if TApiClient.Instance.AuthToken.IsEmpty then
  begin
    ShowLoginForm;
  end
  else
  begin
    LoadCampaignsTab;
  end;
end;

procedure TMainForm.ShowLoginForm;
var
  LoginForm: TLoginForm;
begin
  LoginForm := TLoginForm.Create(Self);
  try
    if LoginForm.ShowModal = mrOk then
    begin
      LoadCampaignsTab;
    end
    else
    begin
      Application.Terminate;
    end;
  finally
    LoginForm.Free;
  end;
end;

procedure TMainForm.LoadCampaignsTab;
var
  CampaignForm: TCampaignListForm;
begin
  // Clear existing controls
  tabCampaigns.DeleteChildren;

  // Create campaign list form
  CampaignForm := TCampaignListForm.Create(tabCampaigns);
  CampaignForm.Parent := tabCampaigns;
  CampaignForm.Align := TAlignLayout.Client;
end;

procedure TMainForm.LoadMediaTab;
var
  MediaForm: TMediaLibraryForm;
begin
  // Clear existing controls
  tabMedia.DeleteChildren;

  // Create media library form
  MediaForm := TMediaLibraryForm.Create(tabMedia);
  MediaForm.Parent := tabMedia;
  MediaForm.Align := TAlignLayout.Client;
end;

procedure TMainForm.LoadDisplaysTab;
var
  DisplayForm: TDisplayManagerForm;
begin
  // Clear existing controls
  tabDisplays.DeleteChildren;

  // Create display manager form
  DisplayForm := TDisplayManagerForm.Create(tabDisplays);
  DisplayForm.Parent := tabDisplays;
  DisplayForm.Align := TAlignLayout.Client;
end;

procedure TMainForm.btnLogoutClick(Sender: TObject);
begin
  TApiClient.Instance.AuthToken := '';
  ShowLoginForm;
end;

procedure TMainForm.TabControlChange(Sender: TObject);
begin
  case TabControl.TabIndex of
    0: LoadCampaignsTab;
    1: LoadMediaTab;
    2: LoadDisplaysTab;
  end;
end;

end.