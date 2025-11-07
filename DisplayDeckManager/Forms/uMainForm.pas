unit uMainForm;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Objects,
  FMX.Layouts, LoginFrame, RegisterFrame, DashboardFrame, FMX.ListBox,
  FMX.Controls.Presentation, FMX.StdCtrls, ProfileFrame, DisplaysFrame,
  CampaignsFrame, MediaLibraryFrame, AnalyticsFrame, SettingsFrame, uApiClient;

type
  TMenuSection = (msNone, msDashboard, msProfile, msDisplays, 
                  msCampaigns, msMedia, msAnalytics, msSettings);

  TForm1 = class(TForm)
    StyleBook1: TStyleBook;
    LayoutNavigation: TLayout;
    LayoutContent: TLayout;
    Rectangle1: TRectangle;
    Layout1: TLayout;
    Label1: TLabel;
    LayoutSpacer: TLayout;
    lstMenu: TListBox;
    ListBoxItem1: TListBoxItem;
    ListBoxItem2: TListBoxItem;
    ListBoxItem3: TListBoxItem;
    ListBoxItem4: TListBoxItem;
    ListBoxItem5: TListBoxItem;
    ListBoxItem6: TListBoxItem;
    ListBoxItem7: TListBoxItem;
    procedure FormCreate(Sender: TObject);
    procedure lstMenuItemClick(const Sender: TCustomListBox;
      const Item: TListBoxItem);
  private
    { Private declarations }
    FCurrentFrame: TFrame;
    FCurrentSection: TMenuSection;
    FCurrentUserName: string;
    FCurrentUserEmail: string;
    FCurrentUserId: Integer;
    FCurrentOrgId: Integer;
    FCurrentOrgName: string;
    FAuthToken: string;
    procedure LoadLoginFrame;
    procedure LoadRegisterFrame;
    procedure LoadDashboardFrame;
    procedure LoadProfileFrame;
    procedure LoadDisplaysFrame;
    procedure LoadCampaignsFrame;
    procedure LoadMediaLibraryFrame;
    procedure LoadAnalyticsFrame;
    procedure LoadSettingsFrame;
    procedure HandleLoginSuccess(Sender: TObject; const AToken: string; 
      AUserId, AOrganizationId: Integer; const AUserName, AEmail, AOrgName: string);
    procedure HandleRegisterRequest(Sender: TObject);
    procedure HandleRegisterSuccess(Sender: TObject; const AToken: string; 
      AUserId, AOrganizationId: Integer; const AUserName, AEmail, AOrgName: string);
    procedure HandleLoginRequest(Sender: TObject);
    procedure HandleNavigateToSection(const SectionTag: Integer);
    procedure ClearCurrentFrame;
    procedure LoadSection(ASection: TMenuSection);
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.fmx}

procedure TForm1.FormCreate(Sender: TObject);
begin
  // Initialize fields to prevent garbage values
  FCurrentUserId := 0;
  FCurrentOrgId := 0;
  FAuthToken := '';
  FCurrentUserName := '';
  FCurrentUserEmail := '';
  FCurrentOrgName := '';
  
  // Hide navigation panel initially (show after login)
  LayoutNavigation.Visible := False;
  
  // Set form properties
  Caption := 'DisplayDeck Manager';
  
  // Load the login frame
  LoadLoginFrame;
end;

procedure TForm1.ClearCurrentFrame;
begin
  if Assigned(FCurrentFrame) then
  begin
    FCurrentFrame.Free;
    FCurrentFrame := nil;
  end;
end;

procedure TForm1.LoadLoginFrame;
var
  LoginFrm: TFrame1;
begin
  ClearCurrentFrame;
  
  // Create and setup login frame
  LoginFrm := TFrame1.Create(Self);
  LoginFrm.Parent := LayoutContent;
  LoginFrm.Align := TAlignLayout.Client;
  
  // Wire up events
  LoginFrm.OnLoginSuccess := HandleLoginSuccess;
  LoginFrm.OnRegisterRequest := HandleRegisterRequest;
  
  FCurrentFrame := LoginFrm;
  
  // Hide navigation while on login
  LayoutNavigation.Visible := False;
end;

procedure TForm1.LoadRegisterFrame;
var
  RegisterFrm: TFrame2;
begin
  ClearCurrentFrame;
  
  // Create and setup register frame
  RegisterFrm := TFrame2.Create(Self);
  RegisterFrm.Parent := LayoutContent;
  RegisterFrm.Align := TAlignLayout.Client;
  
  // Wire up events
  RegisterFrm.OnRegisterSuccess := HandleRegisterSuccess;
  RegisterFrm.OnLoginRequest := HandleLoginRequest;
  
  FCurrentFrame := RegisterFrm;
  
  // Hide navigation while on register
  LayoutNavigation.Visible := False;
end;

procedure TForm1.LoadDashboardFrame;
var
  DashboardFrm: TFrame3;
begin
  ClearCurrentFrame;
  
  // Create and setup dashboard frame
  DashboardFrm := TFrame3.Create(Self);
  DashboardFrm.Parent := LayoutContent;
  DashboardFrm.Align := TAlignLayout.Client;
  
  // Initialize with user name and wire up navigation event
  DashboardFrm.Initialize(FCurrentUserName);
  DashboardFrm.OnNavigateToSection := HandleNavigateToSection;
  
  FCurrentFrame := DashboardFrm;
  FCurrentSection := msDashboard;
  
  // Show navigation panel after successful login
  LayoutNavigation.Visible := True;
  
  // Select dashboard in menu
  if lstMenu.Items.Count > 0 then
    lstMenu.ItemIndex := 0;
end;

procedure TForm1.LoadProfileFrame;
var
  ProfileFrm: TFrame4;
begin
  ClearCurrentFrame;
  ProfileFrm := TFrame4.Create(Self);
  ProfileFrm.Parent := LayoutContent;
  ProfileFrm.Align := TAlignLayout.Client;
  ProfileFrm.Initialize(FCurrentUserId, FCurrentOrgId, FCurrentUserName, FCurrentUserEmail);
  FCurrentFrame := ProfileFrm;
  FCurrentSection := msProfile;
end;

procedure TForm1.LoadDisplaysFrame;
var
  DisplaysFrm: TFrame5;
begin
  ClearCurrentFrame;
  DisplaysFrm := TFrame5.Create(Self);
  DisplaysFrm.Parent := LayoutContent;
  DisplaysFrm.Align := TAlignLayout.Client;
  DisplaysFrm.Initialize(FCurrentOrgId);
  FCurrentFrame := DisplaysFrm;
  FCurrentSection := msDisplays;
end;

procedure TForm1.LoadCampaignsFrame;
var
  CampaignsFrm: TFrame6;
begin
  ClearCurrentFrame;
  CampaignsFrm := TFrame6.Create(Self);
  CampaignsFrm.Parent := LayoutContent;
  CampaignsFrm.Align := TAlignLayout.Client;
  CampaignsFrm.Initialize(FCurrentOrgId);
  FCurrentFrame := CampaignsFrm;
  FCurrentSection := msCampaigns;
end;

procedure TForm1.LoadMediaLibraryFrame;
var
  MediaFrm: TFrame7;
begin
  ClearCurrentFrame;
  MediaFrm := TFrame7.Create(Self);
  MediaFrm.Parent := LayoutContent;
  MediaFrm.Align := TAlignLayout.Client;
  MediaFrm.Initialize(FCurrentOrgId);
  FCurrentFrame := MediaFrm;
  FCurrentSection := msMedia;
end;

procedure TForm1.LoadAnalyticsFrame;
var
  AnalyticsFrm: TFrame8;
begin
  ClearCurrentFrame;
  AnalyticsFrm := TFrame8.Create(Self);
  AnalyticsFrm.Parent := LayoutContent;
  AnalyticsFrm.Align := TAlignLayout.Client;
  AnalyticsFrm.Initialize(FCurrentOrgId);
  FCurrentFrame := AnalyticsFrm;
  FCurrentSection := msAnalytics;
end;

procedure TForm1.LoadSettingsFrame;
var
  SettingsFrm: TFrame9;
begin
  ClearCurrentFrame;
  SettingsFrm := TFrame9.Create(Self);
  SettingsFrm.Parent := LayoutContent;
  SettingsFrm.Align := TAlignLayout.Client;
  SettingsFrm.Initialize;
  FCurrentFrame := SettingsFrm;
  FCurrentSection := msSettings;
end;

procedure TForm1.LoadSection(ASection: TMenuSection);
begin
  case ASection of
    msDashboard: LoadDashboardFrame;
    msProfile: LoadProfileFrame;
    msDisplays: LoadDisplaysFrame;
    msCampaigns: LoadCampaignsFrame;
    msMedia: LoadMediaLibraryFrame;
    msAnalytics: LoadAnalyticsFrame;
    msSettings: LoadSettingsFrame;
  end;
end;

procedure TForm1.lstMenuItemClick(const Sender: TCustomListBox;
  const Item: TListBoxItem);
var
  Section: TMenuSection;
begin
  if Item = nil then Exit;
  
  // Map tag to section
  case Item.Tag of
    1: Section := msDashboard;
    2: Section := msProfile;
    3: Section := msDisplays;
    4: Section := msCampaigns;
    5: Section := msMedia;
    6: Section := msAnalytics;
    7: Section := msSettings;
  else
    Exit;
  end;
  
  // Load the selected section
  LoadSection(Section);
end;

procedure TForm1.HandleLoginSuccess(Sender: TObject; const AToken: string; 
  AUserId, AOrganizationId: Integer; const AUserName, AEmail, AOrgName: string);
begin
  // Store user data from login response
  FAuthToken := AToken;
  FCurrentUserId := AUserId;
  FCurrentOrgId := AOrganizationId;
  FCurrentUserName := AUserName;
  FCurrentUserEmail := AEmail;
  FCurrentOrgName := AOrgName;
  
  // Set token in API client for subsequent requests
  TApiClient.Instance.SetAuthToken(AToken);
  
  // Switch to dashboard after successful login
  LoadDashboardFrame;
end;

procedure TForm1.HandleRegisterRequest(Sender: TObject);
begin
  // User clicked "Register here" on login frame
  LoadRegisterFrame;
end;

procedure TForm1.HandleRegisterSuccess(Sender: TObject; const AToken: string; 
  AUserId, AOrganizationId: Integer; const AUserName, AEmail, AOrgName: string);
begin
  // Store user data from registration response
  FAuthToken := AToken;
  FCurrentUserId := AUserId;
  FCurrentOrgId := AOrganizationId;
  FCurrentUserName := AUserName;
  FCurrentUserEmail := AEmail;
  FCurrentOrgName := AOrgName;
  
  // Set token in API client for subsequent requests
  TApiClient.Instance.SetAuthToken(AToken);
  
  // After successful registration, auto-login to dashboard
  LoadDashboardFrame;
end;

procedure TForm1.HandleLoginRequest(Sender: TObject);
begin
  // User clicked "Login here" on register frame
  LoadLoginFrame;
end;

procedure TForm1.HandleNavigateToSection(const SectionTag: Integer);
var
  Section: TMenuSection;
begin
  // Map tag to section
  case SectionTag of
    1: Section := msDashboard;
    2: Section := msProfile;
    3: Section := msDisplays;
    4: Section := msCampaigns;
    5: Section := msMedia;
    6: Section := msAnalytics;
    7: Section := msSettings;
  else
    Exit;
  end;
  
  // Load the selected section
  LoadSection(Section);
  
  // Update menu selection
  if (SectionTag >= 1) and (SectionTag <= lstMenu.Items.Count) then
    lstMenu.ItemIndex := SectionTag - 1;
end;

end.
