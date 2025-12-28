unit uDashboardFrameV2;

interface

uses
  System.SysUtils, System.Classes, System.UITypes, FMX.Types, FMX.Controls, FMX.StdCtrls, FMX.Objects,
  FMX.Graphics,
  FMX.Layouts, FMX.Edit, FMX.ListBox, uFrameBase;

type
  TDashboardFrameV2 = class(TFrameBase)
  private
    FOrgId: Integer;

    // Header actions
    BtnPair: TButton;
    BtnRefresh: TButton;

    // Main content (dashboard grid)
    LayoutKpis: TLayout;
    RectKpiDisplays: TRectangle;
    RectKpiCampaigns: TRectangle;
    RectKpiMedia: TRectangle;
    RectKpiDisplaysStrip: TRectangle;
    RectKpiCampaignsStrip: TRectangle;
    RectKpiMediaStrip: TRectangle;
    RectKpiDisplaysIconBg: TRectangle;
    RectKpiCampaignsIconBg: TRectangle;
    RectKpiMediaIconBg: TRectangle;
    LblKpiDisplaysIcon: TLabel;
    LblKpiCampaignsIcon: TLabel;
    LblKpiMediaIcon: TLabel;
    LblKpiDisplaysValue: TLabel;
    LblKpiCampaignsValue: TLabel;
    LblKpiMediaValue: TLabel;
    LblKpiDisplaysHint: TLabel;
    LblKpiCampaignsHint: TLabel;
    LblKpiMediaHint: TLabel;

    LayoutRow2: TLayout;
    RectActivity: TRectangle;
    RectAlerts: TRectangle;
    LblActivityHeader: TLabel;
    LstActivity: TListBox;

    LblAlertsHeader: TLabel;

    // Pairing UI
    BtnCloseDrawer: TButton;
    LblPairHelp: TLabel;
    EdtPairToken: TEdit;
    EdtDisplayName: TEdit;
    CbOrientation: TComboBox;
    BtnClaim: TButton;

    // Alerts UI (shown in main area)
    LblOfflineHeader: TLabel;
    LstOffline: TListBox;
    LblWebhookHeader: TLabel;
    LblWebhookStatus: TLabel;

    procedure RefreshData;
    procedure BtnRefreshClick(Sender: TObject);

    procedure BtnPairClick(Sender: TObject);
    procedure BtnCloseDrawerClick(Sender: TObject);
    procedure BtnClaimClick(Sender: TObject);
    procedure ApplyThemeLocal;
    procedure FrameResized(Sender: TObject);

    function WithAlpha(const C: TAlphaColor; const A: Byte): TAlphaColor; inline;

    function CreateMdl2Icon(const AParent: TFmxObject; const ACodePoint: Word;
      const ASize: Single; const AColor: TAlphaColor; const AAlign: TAlignLayout): TLabel;
    function CreateMetricCard(const AParent: TFmxObject; out AValueLbl, AHintLbl: TLabel;
      const ATitle: string; const AAccent: TAlphaColor; const AIcon: Word;
      out AStrip: TRectangle; out AIconBg: TRectangle; out AIconLbl: TLabel): TRectangle;
    procedure UpdateDashboardLayout;
  public
    procedure Initialize(const AOrgId: Integer);
  end;

implementation

{$R *.fmx}

uses
  uApiClient, uTheme;

const
  // Segoe MDL2 Assets codepoints
  ICON_MONITOR = $E7F4;
  ICON_FLAG    = $E7C1;
  ICON_IMAGE   = $EB9F;

procedure TDashboardFrameV2.Initialize(const AOrgId: Integer);
begin
  FOrgId := AOrgId;
  SetTitle('Dashboard');

  // Inspector as drawer (Pair display)
  SetInspectorAsDrawer(True);
  SetInspectorWidth(420);
  SetInspectorVisible(False, 'Pair display');

  BtnCloseDrawer := TButton.Create(Self);
  BtnCloseDrawer.Parent := InspectorContent;
  BtnCloseDrawer.Align := TAlignLayout.Top;
  BtnCloseDrawer.Height := 40;
  BtnCloseDrawer.Text := 'Close';
  BtnCloseDrawer.Margins.Top := 8;
  BtnCloseDrawer.OnClick := BtnCloseDrawerClick;
  StylePrimaryButton(BtnCloseDrawer);

  LblPairHelp := TLabel.Create(Self);
  LblPairHelp.Parent := InspectorContent;
  LblPairHelp.Align := TAlignLayout.Top;
  LblPairHelp.Height := 72;
  LblPairHelp.Margins.Top := 10;
  LblPairHelp.WordWrap := True;
  LblPairHelp.Text := 'Enter a provisioning token to pair a new display. You can optionally give it a friendly name and set orientation.';
  StyleMutedLabel(LblPairHelp);

  EdtPairToken := TEdit.Create(Self);
  EdtPairToken.Parent := InspectorContent;
  EdtPairToken.Align := TAlignLayout.Top;
  EdtPairToken.Height := 44;
  EdtPairToken.Margins.Bottom := 10;
  EdtPairToken.TextPrompt := 'Provisioning token';
  StyleInput(EdtPairToken);

  EdtDisplayName := TEdit.Create(Self);
  EdtDisplayName.Parent := InspectorContent;
  EdtDisplayName.Align := TAlignLayout.Top;
  EdtDisplayName.Height := 44;
  EdtDisplayName.Margins.Bottom := 10;
  EdtDisplayName.TextPrompt := 'Display name';
  StyleInput(EdtDisplayName);

  CbOrientation := TComboBox.Create(Self);
  CbOrientation.Parent := InspectorContent;
  CbOrientation.Align := TAlignLayout.Top;
  CbOrientation.Height := 44;
  CbOrientation.Margins.Bottom := 12;
  CbOrientation.Items.Add('Landscape');
  CbOrientation.Items.Add('Portrait');
  CbOrientation.ItemIndex := 0;

  BtnClaim := TButton.Create(Self);
  BtnClaim.Parent := InspectorContent;
  BtnClaim.Align := TAlignLayout.Top;
  BtnClaim.Height := 44;
  BtnClaim.Text := 'Claim Display';
  BtnClaim.OnClick := BtnClaimClick;
  StylePrimaryButton(BtnClaim);

  // Header actions
  BtnPair := TButton.Create(Self);
  BtnPair.Parent := HeaderRight;
  BtnPair.Align := TAlignLayout.Right;
  BtnPair.Width := 160;
  BtnPair.Margins.Right := 10;
  BtnPair.Text := 'Pair display';
  BtnPair.OnClick := BtnPairClick;
  StylePrimaryButton(BtnPair);

  BtnRefresh := TButton.Create(Self);
  BtnRefresh.Parent := HeaderRight;
  BtnRefresh.Align := TAlignLayout.Right;
  BtnRefresh.Width := 140;
  BtnRefresh.Text := 'Refresh';
  BtnRefresh.OnClick := BtnRefreshClick;
  StylePrimaryButton(BtnRefresh);

  // Main content: KPI row
  LayoutKpis := TLayout.Create(Self);
  LayoutKpis.Parent := BodyContent;
  LayoutKpis.Align := TAlignLayout.Top;
  LayoutKpis.Height := 120;
  LayoutKpis.Margins.Top := SPACE_SM;

  RectKpiDisplays := CreateMetricCard(LayoutKpis, LblKpiDisplaysValue, LblKpiDisplaysHint, 'Displays',
    ColorPrimary, ICON_MONITOR, RectKpiDisplaysStrip, RectKpiDisplaysIconBg, LblKpiDisplaysIcon);
  RectKpiDisplays.Align := TAlignLayout.Left;
  RectKpiDisplays.Margins.Right := SPACE_SM;

  RectKpiCampaigns := CreateMetricCard(LayoutKpis, LblKpiCampaignsValue, LblKpiCampaignsHint, 'Campaigns',
    ColorAccent2, ICON_FLAG, RectKpiCampaignsStrip, RectKpiCampaignsIconBg, LblKpiCampaignsIcon);
  RectKpiCampaigns.Align := TAlignLayout.Left;
  RectKpiCampaigns.Margins.Right := SPACE_SM;

  RectKpiMedia := CreateMetricCard(LayoutKpis, LblKpiMediaValue, LblKpiMediaHint, 'Media',
    ColorAccent3, ICON_IMAGE, RectKpiMediaStrip, RectKpiMediaIconBg, LblKpiMediaIcon);
  RectKpiMedia.Align := TAlignLayout.Client;

  // Row 2: Activity + Alerts
  LayoutRow2 := TLayout.Create(Self);
  LayoutRow2.Parent := BodyContent;
  LayoutRow2.Align := TAlignLayout.Top;
  LayoutRow2.Height := 440;
  LayoutRow2.Margins.Top := SPACE_SM;

  RectAlerts := TRectangle.Create(Self);
  RectAlerts.Parent := LayoutRow2;
  RectAlerts.Align := TAlignLayout.Right;
  RectAlerts.Width := 420;
  RectAlerts.Margins.Left := SPACE_SM;
  StyleCard(RectAlerts);
  RectAlerts.Padding.Left := SPACE_MD;
  RectAlerts.Padding.Right := SPACE_MD;
  RectAlerts.Padding.Top := SPACE_MD;
  RectAlerts.Padding.Bottom := SPACE_MD;

  LblAlertsHeader := TLabel.Create(Self);
  LblAlertsHeader.Parent := RectAlerts;
  LblAlertsHeader.Align := TAlignLayout.Top;
  LblAlertsHeader.Height := 28;
  LblAlertsHeader.Text := 'Alerts';
  StyleSubHeaderLabel(LblAlertsHeader);

  LblOfflineHeader := TLabel.Create(Self);
  LblOfflineHeader.Parent := RectAlerts;
  LblOfflineHeader.Align := TAlignLayout.Top;
  LblOfflineHeader.Height := 24;
  LblOfflineHeader.Margins.Top := 12;
  LblOfflineHeader.Text := 'Offline displays';
  StyleMutedLabel(LblOfflineHeader);

  LstOffline := TListBox.Create(Self);
  LstOffline.Parent := RectAlerts;
  LstOffline.Align := TAlignLayout.Top;
  LstOffline.Height := 200;
  LstOffline.Margins.Top := 6;
  LstOffline.Margins.Bottom := 10;
  LstOffline.ShowCheckboxes := False;
  // Avoid nested scroll; outer scrollbox handles it.
  LstOffline.ShowScrollBars := False;

  LblWebhookHeader := TLabel.Create(Self);
  LblWebhookHeader.Parent := RectAlerts;
  LblWebhookHeader.Align := TAlignLayout.Top;
  LblWebhookHeader.Height := 24;
  LblWebhookHeader.Margins.Top := 8;
  LblWebhookHeader.Text := 'Webhooks';
  StyleMutedLabel(LblWebhookHeader);

  LblWebhookStatus := TLabel.Create(Self);
  LblWebhookStatus.Parent := RectAlerts;
  LblWebhookStatus.Align := TAlignLayout.Top;
  LblWebhookStatus.Height := 120;
  LblWebhookStatus.Margins.Top := 6;
  LblWebhookStatus.WordWrap := True;
  LblWebhookStatus.TextSettings.Font.Size := FONT_SIZE_BODY;
  LblWebhookStatus.TextSettings.FontColor := ColorText;
  LblWebhookStatus.StyledSettings := LblWebhookStatus.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size];
  LblWebhookStatus.Text := 'Loading...';

  RectActivity := TRectangle.Create(Self);
  RectActivity.Parent := LayoutRow2;
  RectActivity.Align := TAlignLayout.Client;
  StyleCard(RectActivity);
  RectActivity.Padding.Left := SPACE_MD;
  RectActivity.Padding.Right := SPACE_MD;
  RectActivity.Padding.Top := SPACE_MD;
  RectActivity.Padding.Bottom := SPACE_MD;

  LblActivityHeader := TLabel.Create(Self);
  LblActivityHeader.Parent := RectActivity;
  LblActivityHeader.Align := TAlignLayout.Top;
  LblActivityHeader.Height := 28;
  LblActivityHeader.Text := 'Recent activity';
  StyleSubHeaderLabel(LblActivityHeader);

  LstActivity := TListBox.Create(Self);
  LstActivity.Parent := RectActivity;
  LstActivity.Align := TAlignLayout.Client;
  LstActivity.Margins.Top := 10;
  LstActivity.ShowCheckboxes := False;
  LstActivity.ShowScrollBars := False;

  RefreshData;
  ApplyThemeLocal;

  OnResize := FrameResized;
  UpdateDashboardLayout;

  // Also restyle on theme changes (base only styles header/inspector chrome).
  RegisterThemeChangedCallback(Self,
    procedure
    begin
      ApplyThemeLocal;
    end);
end;

procedure TDashboardFrameV2.ApplyThemeLocal;
begin
  if Assigned(LblActivityHeader) then StyleSubHeaderLabel(LblActivityHeader);
  if Assigned(LblAlertsHeader) then StyleSubHeaderLabel(LblAlertsHeader);
  if Assigned(LblOfflineHeader) then StyleMutedLabel(LblOfflineHeader);
  if Assigned(LblWebhookHeader) then StyleMutedLabel(LblWebhookHeader);
  if Assigned(LblWebhookStatus) then
  begin
    LblWebhookStatus.TextSettings.FontColor := ColorText;
    LblWebhookStatus.StyledSettings := LblWebhookStatus.StyledSettings - [TStyledSetting.FontColor];
  end;

  if Assigned(RectKpiDisplays) then StyleCard(RectKpiDisplays);
  if Assigned(RectKpiCampaigns) then StyleCard(RectKpiCampaigns);
  if Assigned(RectKpiMedia) then StyleCard(RectKpiMedia);
  if Assigned(RectActivity) then StyleCard(RectActivity);
  if Assigned(RectAlerts) then StyleCard(RectAlerts);

  // KPI accents (re-apply on theme change)
  if Assigned(RectKpiDisplaysStrip) then RectKpiDisplaysStrip.Fill.Color := ColorPrimary;
  if Assigned(RectKpiCampaignsStrip) then RectKpiCampaignsStrip.Fill.Color := ColorAccent2;
  if Assigned(RectKpiMediaStrip) then RectKpiMediaStrip.Fill.Color := ColorAccent3;

  if Assigned(RectKpiDisplaysIconBg) then RectKpiDisplaysIconBg.Fill.Color := WithAlpha(ColorPrimary, $22);
  if Assigned(RectKpiCampaignsIconBg) then RectKpiCampaignsIconBg.Fill.Color := WithAlpha(ColorAccent2, $22);
  if Assigned(RectKpiMediaIconBg) then RectKpiMediaIconBg.Fill.Color := WithAlpha(ColorAccent3, $22);

  if Assigned(LblKpiDisplaysIcon) then
  begin
    LblKpiDisplaysIcon.TextSettings.FontColor := ColorPrimary;
    LblKpiDisplaysIcon.StyledSettings := LblKpiDisplaysIcon.StyledSettings - [TStyledSetting.FontColor];
  end;
  if Assigned(LblKpiCampaignsIcon) then
  begin
    LblKpiCampaignsIcon.TextSettings.FontColor := ColorAccent2;
    LblKpiCampaignsIcon.StyledSettings := LblKpiCampaignsIcon.StyledSettings - [TStyledSetting.FontColor];
  end;
  if Assigned(LblKpiMediaIcon) then
  begin
    LblKpiMediaIcon.TextSettings.FontColor := ColorAccent3;
    LblKpiMediaIcon.StyledSettings := LblKpiMediaIcon.StyledSettings - [TStyledSetting.FontColor];
  end;

  if Assigned(LblKpiDisplaysValue) then
  begin
    LblKpiDisplaysValue.TextSettings.FontColor := ColorPrimary;
    LblKpiDisplaysValue.StyledSettings := LblKpiDisplaysValue.StyledSettings - [TStyledSetting.FontColor];
  end;
  if Assigned(LblKpiCampaignsValue) then
  begin
    LblKpiCampaignsValue.TextSettings.FontColor := ColorAccent2;
    LblKpiCampaignsValue.StyledSettings := LblKpiCampaignsValue.StyledSettings - [TStyledSetting.FontColor];
  end;
  if Assigned(LblKpiMediaValue) then
  begin
    LblKpiMediaValue.TextSettings.FontColor := ColorAccent3;
    LblKpiMediaValue.StyledSettings := LblKpiMediaValue.StyledSettings - [TStyledSetting.FontColor];
  end;

  if Assigned(BtnPair) then StylePrimaryButton(BtnPair);
  if Assigned(BtnRefresh) then StylePrimaryButton(BtnRefresh);
  if Assigned(BtnCloseDrawer) then StylePrimaryButton(BtnCloseDrawer);

  StyleInput(EdtPairToken);
  StyleInput(EdtDisplayName);
  if Assigned(BtnClaim) then StylePrimaryButton(BtnClaim);

  if Assigned(LblPairHelp) then StyleMutedLabel(LblPairHelp);
end;

function TDashboardFrameV2.WithAlpha(const C: TAlphaColor; const A: Byte): TAlphaColor;
begin
  Result := (TAlphaColor(A) shl 24) or (C and $00FFFFFF);
end;

procedure TDashboardFrameV2.BtnPairClick(Sender: TObject);
begin
  SetInspectorVisible(True, 'Pair display');
  if Assigned(EdtPairToken) then
    EdtPairToken.SetFocus;
end;

procedure TDashboardFrameV2.BtnCloseDrawerClick(Sender: TObject);
begin
  SetInspectorVisible(False);
end;

procedure TDashboardFrameV2.FrameResized(Sender: TObject);
begin
  UpdateDashboardLayout;
end;

function TDashboardFrameV2.CreateMdl2Icon(const AParent: TFmxObject; const ACodePoint: Word;
  const ASize: Single; const AColor: TAlphaColor; const AAlign: TAlignLayout): TLabel;
begin
  Result := TLabel.Create(Self);
  Result.Parent := AParent;
  Result.Align := AAlign;
  Result.Width := ASize + 8;
  Result.Height := ASize + 8;
  Result.Text := WideChar(ACodePoint);
  Result.TextSettings.Font.Family := 'Segoe MDL2 Assets';
  Result.TextSettings.Font.Size := ASize;
  Result.TextSettings.FontColor := AColor;
  Result.StyledSettings := Result.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size, TStyledSetting.Family];
  Result.TextSettings.HorzAlign := TTextAlign.Center;
  Result.TextSettings.VertAlign := TTextAlign.Center;
  Result.HitTest := False;
end;

function TDashboardFrameV2.CreateMetricCard(const AParent: TFmxObject; out AValueLbl, AHintLbl: TLabel;
  const ATitle: string; const AAccent: TAlphaColor; const AIcon: Word;
  out AStrip: TRectangle; out AIconBg: TRectangle; out AIconLbl: TLabel): TRectangle;
var
  TitleLbl: TLabel;
  Inner: TLayout;
  TitleRow: TLayout;
begin
  Result := TRectangle.Create(Self);
  Result.Parent := AParent;
  Result.Height := 120;
  StyleCard(Result);

  AStrip := TRectangle.Create(Self);
  AStrip.Parent := Result;
  AStrip.Align := TAlignLayout.Top;
  AStrip.Height := 6;
  AStrip.Fill.Kind := TBrushKind.Solid;
  AStrip.Fill.Color := AAccent;
  AStrip.Stroke.Kind := TBrushKind.None;

  Inner := TLayout.Create(Self);
  Inner.Parent := Result;
  Inner.Align := TAlignLayout.Client;
  Inner.Padding.Left := SPACE_MD;
  Inner.Padding.Right := SPACE_MD;
  Inner.Padding.Top := SPACE_SM;
  Inner.Padding.Bottom := SPACE_SM;

  TitleRow := TLayout.Create(Self);
  TitleRow.Parent := Inner;
  TitleRow.Align := TAlignLayout.Top;
  TitleRow.Height := 32;

  AIconBg := TRectangle.Create(Self);
  AIconBg.Parent := TitleRow;
  AIconBg.Align := TAlignLayout.Left;
  AIconBg.Width := 32;
  AIconBg.Height := 32;
  AIconBg.Margins.Right := 10;
  AIconBg.Fill.Kind := TBrushKind.Solid;
  // 13% alpha tint of the accent color
  AIconBg.Fill.Color := WithAlpha(AAccent, $22);
  AIconBg.Stroke.Kind := TBrushKind.None;
  AIconBg.XRadius := 10;
  AIconBg.YRadius := 10;

  AIconLbl := CreateMdl2Icon(AIconBg, AIcon, 16, AAccent, TAlignLayout.Client);
  AIconLbl.Width := 32;

  TitleLbl := TLabel.Create(Self);
  TitleLbl.Parent := TitleRow;
  TitleLbl.Align := TAlignLayout.Client;
  TitleLbl.Height := 32;
  TitleLbl.Text := ATitle;
  StyleMutedLabel(TitleLbl);

  AValueLbl := TLabel.Create(Self);
  AValueLbl.Parent := Inner;
  AValueLbl.Align := TAlignLayout.Top;
  AValueLbl.Height := 46;
  AValueLbl.Text := '—';
  AValueLbl.TextSettings.Font.Size := FONT_SIZE_HEADER;
  AValueLbl.TextSettings.FontColor := AAccent;
  AValueLbl.TextSettings.Font.Style := [TFontStyle.fsBold];
  AValueLbl.StyledSettings := AValueLbl.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size];

  AHintLbl := TLabel.Create(Self);
  AHintLbl.Parent := Inner;
  AHintLbl.Align := TAlignLayout.Top;
  AHintLbl.Height := 18;
  AHintLbl.Text := '';
  StyleMutedLabel(AHintLbl);
end;

procedure TDashboardFrameV2.UpdateDashboardLayout;
var
  W, CardW, Gap: Single;
const
  MIN_CARD_W = 200;
begin
  if not Assigned(LayoutKpis) then Exit;
  Gap := SPACE_SM;
  W := LayoutKpis.Width;
  if W <= 0 then Exit;
  CardW := (W - 2 * Gap) / 3;
  if CardW < MIN_CARD_W then
    CardW := MIN_CARD_W;
  if Assigned(RectKpiDisplays) then RectKpiDisplays.Width := CardW;
  if Assigned(RectKpiCampaigns) then RectKpiCampaigns.Width := CardW;
end;

procedure TDashboardFrameV2.BtnClaimClick(Sender: TObject);
var
  Token, Name, Orientation: string;
  OrgId: Integer;
begin
  Token := '';
  Name := '';
  Orientation := '';
  if Assigned(EdtPairToken) then Token := EdtPairToken.Text.Trim;
  if Assigned(EdtDisplayName) then Name := EdtDisplayName.Text.Trim;
  if Assigned(CbOrientation) and (CbOrientation.ItemIndex >= 0) then Orientation := CbOrientation.Items[CbOrientation.ItemIndex];

  if Token = '' then
  begin
    ShowError('Please enter a provisioning token.');
    Exit;
  end;

  OrgId := FOrgId;
  if OrgId = 0 then OrgId := 1;

  if Assigned(BtnClaim) then BtnClaim.Enabled := False;
  ShowLoading('Claiming display...');
  TThread.CreateAnonymousThread(
    procedure
    var
      NewDisplay: TDisplayData;
      UiOk: TThreadProcedure;
      UiErr: TThreadProcedure;
    begin
      try
        NewDisplay := TApiClient.Instance.ClaimDisplay(OrgId, Token, Name, Orientation);
        UiOk :=
          procedure
          begin
            if (csDestroying in ComponentState) then Exit;
            if NewDisplay.Id > 0 then
            begin
              if Assigned(EdtPairToken) then EdtPairToken.Text := '';
              if Assigned(EdtDisplayName) then EdtDisplayName.Text := '';
              HideOverlay;
              RefreshData;
              SetInspectorVisible(False);
            end
            else
            begin
              ShowError('Failed to claim display. Please check the token and try again.');
            end;
            if Assigned(BtnClaim) then BtnClaim.Enabled := True;
          end;
        TThread.Queue(nil, UiOk);
      except
        on E: Exception do
        begin
          UiErr :=
            procedure
            begin
              if (csDestroying in ComponentState) then Exit;
              ShowError('Error: ' + E.Message);
              if Assigned(BtnClaim) then BtnClaim.Enabled := True;
            end;
          TThread.Queue(nil, UiErr);
        end;
      end;
    end).Start;
end;

procedure TDashboardFrameV2.BtnRefreshClick(Sender: TObject);
begin
  RefreshData;
end;

procedure TDashboardFrameV2.RefreshData;
begin
  ShowLoading('Loading dashboard...');
  TThread.CreateAnonymousThread(
    procedure
    var
      Displays: TArray<TDisplayData>;
      Campaigns: TArray<TCampaignData>;
      MediaFiles: TArray<TMediaFileData>;
      Webhooks: TArray<TWebhookData>;
      OrgId: Integer;
      OfflineText: TArray<string>;
      OfflineCount: Integer;
      ActiveHooks, InactiveHooks: Integer;
      UiOk: TThreadProcedure;
      UiErr: TThreadProcedure;
    begin
      OrgId := FOrgId;
      if OrgId = 0 then OrgId := 1;
      try
        Displays := TApiClient.Instance.GetDisplays(OrgId);
        Campaigns := TApiClient.Instance.GetCampaigns(OrgId);
        MediaFiles := TApiClient.Instance.GetMediaFiles(OrgId);
        Webhooks := TApiClient.Instance.GetWebhooks(OrgId);

        // Offline displays = anything not explicitly "online"
        OfflineCount := 0;
        for var D in Displays do
          if not SameText(Trim(D.CurrentStatus), 'online') then
            Inc(OfflineCount);
        SetLength(OfflineText, 0);
        if OfflineCount > 0 then
        begin
          for var D in Displays do
          begin
            if not SameText(Trim(D.CurrentStatus), 'online') then
            begin
              var ItemText := D.Name;
              if (D.LastSeen <> '') then
                ItemText := ItemText + '  (last seen: ' + D.LastSeen + ')';
              SetLength(OfflineText, Length(OfflineText) + 1);
              OfflineText[High(OfflineText)] := ItemText;
              if Length(OfflineText) >= 6 then Break;
            end;
          end;
        end;

        ActiveHooks := 0;
        InactiveHooks := 0;
        for var H in Webhooks do
          if H.IsActive then Inc(ActiveHooks) else Inc(InactiveHooks);

        UiOk :=
          procedure
          begin
            if (csDestroying in ComponentState) then Exit;
            if Assigned(LblKpiDisplaysValue) then
              LblKpiDisplaysValue.Text := IntToStr(Length(Displays));
            if Assigned(LblKpiCampaignsValue) then
              LblKpiCampaignsValue.Text := IntToStr(Length(Campaigns));
            if Assigned(LblKpiMediaValue) then
              LblKpiMediaValue.Text := IntToStr(Length(MediaFiles));

            if Assigned(LblKpiDisplaysHint) then
              LblKpiDisplaysHint.Text := Format('Offline: %d', [OfflineCount]);
            if Assigned(LblKpiCampaignsHint) then
              LblKpiCampaignsHint.Text := 'Total campaigns';
            if Assigned(LblKpiMediaHint) then
              LblKpiMediaHint.Text := 'Media files';

            // Recent activity (simple placeholder list for now)
            if Assigned(LstActivity) then
            begin
              LstActivity.Clear;
              var Added := 0;
              for var D in Displays do
              begin
                var It := TListBoxItem.Create(Self);
                It.Text := 'Display: ' + D.Name + ' (' + Trim(D.CurrentStatus) + ')';
                It.Parent := LstActivity;
                Inc(Added);
                if Added >= 5 then Break;
              end;
              if (Added = 0) then
              begin
                var It := TListBoxItem.Create(Self);
                It.Text := 'No recent activity yet.';
                It.Parent := LstActivity;
              end;
            end;

            // Alerts
            if Assigned(LblOfflineHeader) then
              LblOfflineHeader.Text := Format('Offline displays (%d)', [OfflineCount]);
            if Assigned(LstOffline) then
            begin
              LstOffline.Clear;
              if OfflineCount = 0 then
              begin
                var It := TListBoxItem.Create(Self);
                It.Text := 'All displays online.';
                It.Parent := LstOffline;
              end
              else
              begin
                for var S in OfflineText do
                begin
                  var It := TListBoxItem.Create(Self);
                  It.Text := S;
                  It.Parent := LstOffline;
                end;
              end;
            end;

            if Assigned(LblWebhookStatus) then
            begin
              if Length(Webhooks) = 0 then
                LblWebhookStatus.Text := 'No webhooks configured.' + sLineBreak + 'Tip: add one in Settings later.'
              else
                LblWebhookStatus.Text := Format('Webhooks configured: %d (active: %d, inactive: %d).',
                  [Length(Webhooks), ActiveHooks, InactiveHooks]) + sLineBreak +
                  'Delivery failures tracking is not exposed yet (we can add it next).';
            end;

            HideOverlay;
          end;
        TThread.Queue(nil, UiOk);
      except
        on E: Exception do
        begin
          UiErr :=
            procedure
            begin
              if (csDestroying in ComponentState) then Exit;
              ShowError('Failed to load dashboard: ' + E.Message);
            end;
          TThread.Queue(nil, UiErr);
        end;
      end;
    end).Start;
end;

end.
