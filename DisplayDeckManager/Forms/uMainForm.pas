unit uMainForm;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Objects,
  FMX.Layouts, LoginFrame, RegisterFrame, DashboardFrame, FMX.ListBox,
  FMX.Controls.Presentation, FMX.StdCtrls, ProfileFrame, DisplaysFrame,
  CampaignsFrame, MediaLibraryFrame, AnalyticsFrame, SettingsFrame, uApiClient,
  System.IOUtils, uTheme;

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
    procedure MenuItemMouseEnter(Sender: TObject);
    procedure MenuItemMouseLeave(Sender: TObject);
    procedure AttachMenuHover(Item: TListBoxItem);
    procedure ApplyGlobalTheme; // live restyling when theme changes
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

  // Attempt to load logo images at runtime (handles relative build output path)
  var LogoPath := TPath.Combine(ExtractFilePath(ParamStr(0)), '..'+PathDelim+'Logo'+PathDelim+'Logo.png');
  if FileExists(LogoPath) then
  begin
    var ImgTop := FindComponent('imgLogoTop') as TImage;
    var ImgBottom := FindComponent('imgLogoBottom') as TImage;
    if Assigned(ImgTop) then
    begin
      ImgTop.Bitmap.LoadFromFile(LogoPath);
      ImgTop.Width := 140; ImgTop.Height := 40;
    end;
    if Assigned(ImgBottom) then
    begin
      ImgBottom.Bitmap.LoadFromFile(LogoPath);
      ImgBottom.Width := 140; ImgBottom.Height := 40;
    end;
  end;
  
  // Load the login frame
  LoadLoginFrame;
  // Apply theme to navigation background if present
  var NavRect := FindComponent('Rectangle1') as TRectangle;
  if Assigned(NavRect) then StyleNavBackground(NavRect);
  // Style menu items: first one active by default
  for var i := 0 to lstMenu.Items.Count - 1 do
  begin
    var It := lstMenu.ListItems[i];
    StyleMenuItem(It, i=0);
    AttachMenuHover(It);
  end;
  // Register callback for live dark/light mode changes
  RegisterThemeChangedCallback(ApplyGlobalTheme);
end;

procedure TForm1.ClearCurrentFrame;
begin
  if Assigned(FCurrentFrame) then
  begin
    // Detach parent to avoid FMX access during destruction of child controls
    FCurrentFrame.Parent := nil;
    FCurrentFrame.Free;
    FCurrentFrame := nil;
  end;
end;

procedure TForm1.MenuItemMouseEnter(Sender: TObject);
var
  It: TListBoxItem;
begin
  if not (Sender is TListBoxItem) then Exit;
  It := TListBoxItem(Sender);
  // Do not override active item's styling
  if (lstMenu.ItemIndex >= 0) and (lstMenu.ListItems[lstMenu.ItemIndex] = It) then Exit;
  It.TextSettings.FontColor := ColorNavHover;
  It.StyledSettings := It.StyledSettings - [TStyledSetting.FontColor];
  It.Opacity := 1.0;
end;

procedure TForm1.MenuItemMouseLeave(Sender: TObject);
var
  It: TListBoxItem;
  Active: Boolean;
begin
  if not (Sender is TListBoxItem) then Exit;
  It := TListBoxItem(Sender);
  Active := (lstMenu.ItemIndex >= 0) and (lstMenu.ListItems[lstMenu.ItemIndex] = It);
  StyleMenuItem(It, Active);
end;

procedure TForm1.AttachMenuHover(Item: TListBoxItem);
begin
  if Item = nil then Exit;
  Item.OnMouseEnter := MenuItemMouseEnter;
  Item.OnMouseLeave := MenuItemMouseLeave;
end;

procedure TForm1.ApplyGlobalTheme;
var
  NavRect: TRectangle;
begin
  // Restyle navigation background
  NavRect := Rectangle1;
  if Assigned(NavRect) then StyleNavBackground(NavRect);
  // Restyle menu items preserving active selection
  for var i := 0 to lstMenu.Items.Count - 1 do
    StyleMenuItem(lstMenu.ListItems[i], i = lstMenu.ItemIndex);
  // Restyle active frame selectively
  if Assigned(FCurrentFrame) then
  begin
    if FCurrentFrame is TFrame3 then // Dashboard
    begin
      var D := TFrame3(FCurrentFrame);
      StyleBackground(D.RectBackground);
      StyleCard(D.RectQuickActions);
      StyleCard(D.RectCardDisplays);
      StyleCard(D.RectCardCampaigns);
      StyleCard(D.RectCardMedia);
    end
    else if FCurrentFrame is TFrame5 then // Displays
    begin
      var DF := TFrame5(FCurrentFrame);
      StyleBackground(DF.RectBackground);
      StyleCard(DF.RectListCard);
      StyleCard(DF.RectDetailCard);
      StyleHeaderLabel(DF.lblDetailTitle);
      StyleMutedLabel(DF.lblNameLabel);
      StyleMutedLabel(DF.lblOrientationLabel);
      StyleMutedLabel(DF.lblStatusLabel);
      StyleMutedLabel(DF.lblLastSeenLabel);
      StyleMutedLabel(DF.lblProvisioningLabel);
      StylePrimaryButton(DF.btnSave);
      StyleDangerButton(DF.btnDelete);
      StylePrimaryButton(DF.btnPairDisplay);
      StylePrimaryButton(DF.btnSetPrimary);
      StylePrimaryButton(DF.btnRefreshPlaying);
    end
    else if FCurrentFrame is TFrame9 then // Settings
    begin
      var SF := TFrame9(FCurrentFrame);
      // Attempt to find rectangles/cards by name
      var Bg := SF.RectBackground;
      var Card := SF.RectCard;
      StyleBackground(Bg);
      StyleCard(Card);
      StyleHeaderLabel(SF.lblTitle);
    end;
  end;
end;

procedure TForm1.LoadLoginFrame;
var
  LoginFrm: TFrame1;
begin
  ClearCurrentFrame;
  
  // Create and setup login frame
  LoginFrm := TFrame1.Create(nil);
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
  RegisterFrm := TFrame2.Create(nil);
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
  DashboardFrm := TFrame3.Create(nil);
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
  ProfileFrm := TFrame4.Create(nil);
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
  DisplaysFrm := TFrame5.Create(nil);
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
  CampaignsFrm := TFrame6.Create(nil);
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
  MediaFrm := TFrame7.Create(nil);
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
  AnalyticsFrm := TFrame8.Create(nil);
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
  SettingsFrm := TFrame9.Create(nil);
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
  // Update menu item styles for active highlight
  for var i := 0 to lstMenu.Items.Count - 1 do
    StyleMenuItem(lstMenu.ListItems[i], lstMenu.ListItems[i] = Item);
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
  for var i := 0 to lstMenu.Items.Count - 1 do
    StyleMenuItem(lstMenu.ListItems[i], i = lstMenu.ItemIndex);
end;

end.
