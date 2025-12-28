unit uAppShell;

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Layouts, FMX.Objects, FMX.ListBox, FMX.StdCtrls, FMX.Controls.Presentation,
  uAppSession;

type
  TAppRoute = (arLogin, arRegister, arDashboard, arDisplays, arCampaigns, arMedia, arAnalytics, arProfile, arSettings);

  TAppShellForm = class(TForm)
  private
    FSession: TAppSession;
    FCurrentFrame: TFrame;

    LayoutRoot: TLayout;
    LayoutBody: TLayout;
    RectBg: TRectangle;
    LayoutNav: TLayout;
    RectNav: TRectangle;
    LayoutNavHeader: TLayout;
    LblNavTitle: TLabel;
    LstNav: TListBox;
    LayoutTop: TLayout;
    RectTopBg: TRectangle;
    LblTopTitle: TLabel;
    BtnLogout: TButton;
    LayoutContent: TLayout;

    procedure BuildUi;
    procedure ApplyTheme;

    procedure ClearCurrentFrame;
    procedure SetTopTitle(const ATitle: string);

    procedure Navigate(const ARoute: TAppRoute);

    procedure ShowLogin;
    procedure ShowRegister;

    procedure HandleLoginSuccess(Sender: TObject; const AToken: string;
      AUserId, AOrganizationId: Integer; const AUserName, AEmail, AOrgName: string);
    procedure HandleRegisterSuccess(Sender: TObject; const AToken: string;
      AUserId, AOrganizationId: Integer; const AUserName, AEmail, AOrgName: string);
    procedure HandleLoginRequest(Sender: TObject);
    procedure HandleRegisterRequest(Sender: TObject);

    procedure LstNavItemClick(const Sender: TCustomListBox; const Item: TListBoxItem);
    procedure BtnLogoutClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  AppShellForm: TAppShellForm;

implementation

uses
  System.IniFiles,
  uTheme, uApiClient,
  uAppSettings,
  LoginFrame, RegisterFrame,
  DisplaysFrame, CampaignsFrame, MediaLibraryFrame, AnalyticsFrame, ProfileFrame, SettingsFrame,
  uDashboardFrameV2,
  uDisplaysFrameV2,
  uCampaignsFrameV2;

{ TAppShellForm }

constructor TAppShellForm.Create(AOwner: TComponent);
begin
  // Code-only form (no .fmx). Use CreateNew to avoid resource streaming.
  inherited CreateNew(AOwner);
  FSession := TAppSession.Empty;

  // Load theme settings as early as possible so frames initialize with correct colors.
  try
    var IniFile := TIniFile.Create(GetSettingsIniPath);
    try
      SetTypographyScale(IniFile.ReadFloat('Theme', 'FontScale', 1.0));
      var PresetName := IniFile.ReadString('Theme', 'Preset', '');
      var Preset: TThemePreset;
      if (PresetName <> '') and TryParseThemePreset(PresetName, Preset) then
        SetThemePreset(Preset, False)
      else
      begin
        // Backward compatibility
        if IniFile.ReadBool('Theme', 'DarkMode', False) then
          SetThemePreset(tpDarkBlue, False)
        else
          SetThemePreset(tpLightBlue, False);
      end;
    finally
      IniFile.Free;
    end;
  except
    // Ignore settings load issues; defaults are fine.
  end;

  BuildUi;

  RegisterThemeChangedCallback(Self,
    procedure
    begin
      ApplyTheme;
    end);

  ApplyTheme;
  Navigate(arLogin);
end;

destructor TAppShellForm.Destroy;
begin
  UnregisterThemeChangedCallbacks(Self);
  inherited;
end;

procedure TAppShellForm.BuildUi;
  function AddNavItem(const AText: string; const ARoute: TAppRoute): TListBoxItem;
  begin
    Result := TListBoxItem.Create(Self);
    Result.Parent := LstNav;
    Result.Text := AText;
    Result.Tag := Ord(ARoute);
    Result.Height := 44;
    Result.StyledSettings := Result.StyledSettings - [TStyledSetting.FontColor];
  end;
begin
  Caption := 'DisplayDeck Manager (v2)';
  Width := 1280;
  Height := 800;

  LayoutRoot := TLayout.Create(Self);
  LayoutRoot.Parent := Self;
  LayoutRoot.Align := TAlignLayout.Client;

  // Top bar should span the full window width.
  LayoutTop := TLayout.Create(Self);
  LayoutTop.Parent := LayoutRoot;
  LayoutTop.Align := TAlignLayout.Top;
  LayoutTop.Height := 56;
  LayoutTop.Padding.Left := 24;
  LayoutTop.Padding.Right := 24;

  RectBg := TRectangle.Create(Self);
  RectBg.Parent := LayoutRoot;
  RectBg.Align := TAlignLayout.Contents;
  RectBg.HitTest := False;
  // Admin canvas should be clean and neutral; keep gradients for auth screens.
  StyleBackground(RectBg);
  RectBg.SendToBack;

  // Body holds nav + content, below the top bar.
  LayoutBody := TLayout.Create(Self);
  LayoutBody.Parent := LayoutRoot;
  LayoutBody.Align := TAlignLayout.Client;

  // Left nav
  LayoutNav := TLayout.Create(Self);
  LayoutNav.Parent := LayoutBody;
  LayoutNav.Align := TAlignLayout.Left;
  LayoutNav.Width := 240;

  RectNav := TRectangle.Create(Self);
  RectNav.Parent := LayoutNav;
  RectNav.Align := TAlignLayout.Contents;
  RectNav.Stroke.Kind := TBrushKind.None;
  StyleNavBackground(RectNav);

  // Nav header (avoids the "random" empty block at top-left)
  LayoutNavHeader := TLayout.Create(Self);
  LayoutNavHeader.Parent := LayoutNav;
  LayoutNavHeader.Align := TAlignLayout.Top;
  LayoutNavHeader.Height := 56;
  LayoutNavHeader.Padding.Left := 16;
  LayoutNavHeader.Padding.Right := 16;

  LblNavTitle := TLabel.Create(Self);
  LblNavTitle.Parent := LayoutNavHeader;
  LblNavTitle.Align := TAlignLayout.Client;
  LblNavTitle.Text := 'DisplayDeck';
  LblNavTitle.StyledSettings := LblNavTitle.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size];
  LblNavTitle.TextSettings.Font.Size := 16;
  LblNavTitle.TextSettings.Font.Style := [TFontStyle.fsBold];
  LblNavTitle.TextSettings.HorzAlign := TTextAlign.Leading;

  LstNav := TListBox.Create(Self);
  LstNav.Parent := LayoutNav;
  LstNav.Align := TAlignLayout.Client;
  LstNav.ItemHeight := 44;
  LstNav.OnItemClick := LstNavItemClick;
  LstNav.ShowCheckboxes := False;
  LstNav.ShowScrollBars := False;

  RectTopBg := TRectangle.Create(Self);
  RectTopBg.Parent := LayoutTop;
  RectTopBg.Align := TAlignLayout.Contents;
  RectTopBg.HitTest := False;
  RectTopBg.Fill.Kind := TBrushKind.Solid;
  RectTopBg.Fill.Color := ColorCard;
  RectTopBg.Stroke.Kind := TBrushKind.Solid;
  RectTopBg.Stroke.Color := ColorCardBorder;
  RectTopBg.Stroke.Thickness := 1;
  RectTopBg.SendToBack;

  LblTopTitle := TLabel.Create(Self);
  LblTopTitle.Parent := LayoutTop;
  LblTopTitle.Align := TAlignLayout.Left;
  LblTopTitle.Width := 700;
  LblTopTitle.Text := '';
  StyleHeaderLabel(LblTopTitle);

  BtnLogout := TButton.Create(Self);
  BtnLogout.Parent := LayoutTop;
  BtnLogout.Align := TAlignLayout.Right;
  BtnLogout.Width := 140;
  BtnLogout.Text := 'Logout';
  BtnLogout.OnClick := BtnLogoutClick;
  StyleDangerButton(BtnLogout);

  // Content
  LayoutContent := TLayout.Create(Self);
  LayoutContent.Parent := LayoutBody;
  LayoutContent.Align := TAlignLayout.Client;

  // Nav items (route tags)
  AddNavItem('Dashboard', arDashboard);
  AddNavItem('Displays', arDisplays);
  AddNavItem('Campaigns', arCampaigns);
  AddNavItem('Media', arMedia);
  AddNavItem('Analytics', arAnalytics);
  AddNavItem('Profile', arProfile);
  AddNavItem('Settings', arSettings);
end;

procedure TAppShellForm.ApplyTheme;
begin
  if Assigned(RectBg) then
    StyleBackground(RectBg);
  StyleNavBackground(RectNav);
  if Assigned(LblNavTitle) then
  begin
    LblNavTitle.TextSettings.FontColor := TAlphaColorRec.White;
    LblNavTitle.StyledSettings := LblNavTitle.StyledSettings - [TStyledSetting.FontColor];
  end;
  if Assigned(RectTopBg) then
  begin
    RectTopBg.Fill.Color := ColorCard;
    RectTopBg.Stroke.Color := ColorCardBorder;
  end;
  if Assigned(LblTopTitle) then
    StyleHeaderLabel(LblTopTitle);
  if Assigned(BtnLogout) then
    StyleDangerButton(BtnLogout);

  // Admin panel: enforce readable buttons everywhere (fixes white-on-white from FMX style quirks)
  if FSession.IsAuthenticated then
  begin
    EnsureButtonsReadable(LayoutTop);
    EnsureButtonsReadable(LayoutContent);
  end;

  // Nav items text color
  if Assigned(LstNav) then
    for var i := 0 to LstNav.Items.Count - 1 do
      if LstNav.ListItems[i] <> nil then
        StyleMenuItem(LstNav.ListItems[i], i = LstNav.ItemIndex);
end;

procedure TAppShellForm.SetTopTitle(const ATitle: string);
begin
  LblTopTitle.Text := ATitle;
end;

procedure TAppShellForm.ClearCurrentFrame;
begin
  if Assigned(FCurrentFrame) then
  begin
    FCurrentFrame.Parent := nil;
    FCurrentFrame.Free;
    FCurrentFrame := nil;
  end;
end;

procedure TAppShellForm.Navigate(const ARoute: TAppRoute);
begin
  if (not FSession.IsAuthenticated) and (ARoute <> arLogin) and (ARoute <> arRegister) then
  begin
    ShowLogin;
    Exit;
  end;

  case ARoute of
    arLogin: ShowLogin;
    arRegister: ShowRegister;
    arDashboard:
      begin
        ClearCurrentFrame;
        var F := TDashboardFrameV2.Create(nil);
        F.Parent := LayoutContent;
        F.Align := TAlignLayout.Client;
        F.Initialize(FSession.OrganizationId);
        FCurrentFrame := F;
        SetTopTitle('Dashboard');
        EnsureButtonsReadable(F);
      end;
    arDisplays:
      begin
        ClearCurrentFrame;
        var F := TDisplaysFrameV2.Create(nil);
        F.Parent := LayoutContent;
        F.Align := TAlignLayout.Client;
        F.Initialize(FSession.OrganizationId);
        FCurrentFrame := F;
        SetTopTitle('Displays');
        EnsureButtonsReadable(F);
      end;
    arCampaigns:
      begin
        ClearCurrentFrame;
        var F := TCampaignsFrameV2.Create(nil);
        F.Parent := LayoutContent;
        F.Align := TAlignLayout.Client;
        F.Initialize(FSession.OrganizationId);
        FCurrentFrame := F;
        SetTopTitle('Campaigns');
        EnsureButtonsReadable(F);
      end;
    arMedia:
      begin
        ClearCurrentFrame;
        var F := TFrame7.Create(nil);
        F.Parent := LayoutContent;
        F.Align := TAlignLayout.Client;
        F.Initialize(FSession.OrganizationId);
        FCurrentFrame := F;
        SetTopTitle('Media');
        EnsureButtonsReadable(F);
      end;
    arAnalytics:
      begin
        ClearCurrentFrame;
        var F := TFrame8.Create(nil);
        F.Parent := LayoutContent;
        F.Align := TAlignLayout.Client;
        F.Initialize(FSession.OrganizationId);
        FCurrentFrame := F;
        SetTopTitle('Analytics');
        EnsureButtonsReadable(F);
      end;
    arProfile:
      begin
        ClearCurrentFrame;
        var F := TFrame4.Create(nil);
        F.Parent := LayoutContent;
        F.Align := TAlignLayout.Client;
        F.Initialize(FSession.UserId, FSession.OrganizationId, FSession.UserName, FSession.UserEmail);
        FCurrentFrame := F;
        SetTopTitle('Profile');
        EnsureButtonsReadable(F);
      end;
    arSettings:
      begin
        ClearCurrentFrame;
        var F := TSettingsFrame.Create(nil);
        F.Parent := LayoutContent;
        F.Align := TAlignLayout.Client;
        F.Initialize;
        FCurrentFrame := F;
        SetTopTitle('Settings');
        EnsureButtonsReadable(F);
      end;
  end;

  // Show/hide nav based on auth
  LayoutNav.Visible := FSession.IsAuthenticated;
  LayoutTop.Visible := FSession.IsAuthenticated;
  BtnLogout.Visible := FSession.IsAuthenticated;
  ApplyTheme;
end;

procedure TAppShellForm.ShowLogin;
begin
  ClearCurrentFrame;
  var F := TFrame1.Create(nil);
  F.Parent := LayoutContent;
  F.Align := TAlignLayout.Client;
  F.OnLoginSuccess := HandleLoginSuccess;
  F.OnRegisterRequest := HandleRegisterRequest;
  F.Initialize;
  FCurrentFrame := F;

  LayoutNav.Visible := False;
  LayoutTop.Visible := False;
  BtnLogout.Visible := False;
  SetTopTitle('');
end;

procedure TAppShellForm.ShowRegister;
begin
  ClearCurrentFrame;
  var F := TFrame2.Create(nil);
  F.Parent := LayoutContent;
  F.Align := TAlignLayout.Client;
  F.OnRegisterSuccess := HandleRegisterSuccess;
  F.OnLoginRequest := HandleLoginRequest;
  F.Initialize;
  FCurrentFrame := F;

  LayoutNav.Visible := False;
  LayoutTop.Visible := False;
  BtnLogout.Visible := False;
  SetTopTitle('');
end;

procedure TAppShellForm.HandleLoginSuccess(Sender: TObject; const AToken: string;
  AUserId, AOrganizationId: Integer; const AUserName, AEmail, AOrgName: string);
begin
  FSession.Token := AToken;
  FSession.UserId := AUserId;
  FSession.OrganizationId := AOrganizationId;
  FSession.UserName := AUserName;
  FSession.UserEmail := AEmail;
  FSession.OrganizationName := AOrgName;

  TApiClient.Instance.SetAuthToken(AToken);
  Navigate(arDashboard);
end;

procedure TAppShellForm.HandleRegisterSuccess(Sender: TObject; const AToken: string;
  AUserId, AOrganizationId: Integer; const AUserName, AEmail, AOrgName: string);
begin
  HandleLoginSuccess(Sender, AToken, AUserId, AOrganizationId, AUserName, AEmail, AOrgName);
end;

procedure TAppShellForm.HandleLoginRequest(Sender: TObject);
begin
  Navigate(arLogin);
end;

procedure TAppShellForm.HandleRegisterRequest(Sender: TObject);
begin
  Navigate(arRegister);
end;

procedure TAppShellForm.LstNavItemClick(const Sender: TCustomListBox; const Item: TListBoxItem);
begin
  if Item = nil then Exit;
  LstNav.ItemIndex := Item.Index;
  Navigate(TAppRoute(Item.Tag));
end;

procedure TAppShellForm.BtnLogoutClick(Sender: TObject);
begin
  FSession := TAppSession.Empty;
  TApiClient.Instance.ClearAuthToken;
  Navigate(arLogin);
end;

end.
