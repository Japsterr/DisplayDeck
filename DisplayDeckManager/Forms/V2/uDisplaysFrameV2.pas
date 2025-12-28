unit uDisplaysFrameV2;

interface

uses
  System.SysUtils, System.Classes, System.UITypes, System.Math,
  FMX.Types, FMX.Controls, FMX.StdCtrls, FMX.Objects, FMX.Layouts, FMX.Edit, FMX.Graphics,
  FMX.ListBox, FMX.Controls.Presentation,
  uFrameBase,
  uApiClient;

type
  TDisplaysFrameV2 = class(TFrameBase)
  private
    FOrgId: Integer;
    FDisplays: TArray<TDisplayData>;
    FFilteredIds: TArray<Integer>;
    FSelectedId: Integer;

    // Header actions
    BtnRefresh: TButton;
    BtnNew: TButton;

    // Main content
    FiltersCard: TRectangle;
    LayoutFilters: TLayout;
    LblFilterIcon: TLabel;
    EdtSearch: TEdit;
    CbStatus: TComboBox;
    LstDisplays: TListBox;

    // Inspector
    LblInspectorHeader: TLabel;
    LblId: TLabel;
    LblStatus: TLabel;
    LblLastSeen: TLabel;

    LblName: TLabel;
    EdtName: TEdit;

    LblOrientation: TLabel;
    CbOrientation: TComboBox;

    LblProvisioning: TLabel;
    EdtProvisioningToken: TEdit;
    BtnCopyToken: TButton;

    BtnSave: TButton;
    BtnDelete: TButton;

    function CreateMdl2Icon(const AParent: TFmxObject; const ACodePoint: Word;
      const ASize: Single; const AColor: TAlphaColor; const AAlign: TAlignLayout): TLabel;
    function StatusToBadgeColor(const AStatus: string): TAlphaColor;
    function NormalizeStatus(const AStatus: string): string;
    function FormatLastSeen(const ALastSeen: string): string;

    procedure ApplyThemeLocal;

    procedure BtnRefreshClick(Sender: TObject);
    procedure BtnNewClick(Sender: TObject);
    procedure EdtSearchChange(Sender: TObject);
    procedure CbStatusChange(Sender: TObject);
    procedure LstDisplaysItemClick(const Sender: TCustomListBox; const Item: TListBoxItem);

    procedure BtnCopyTokenClick(Sender: TObject);
    procedure BtnSaveClick(Sender: TObject);
    procedure BtnDeleteClick(Sender: TObject);

    procedure RefreshData;
    procedure ApplyFilter;
    procedure RebuildList;

    function FindDisplayIndexById(const AId: Integer): Integer;
    procedure SelectDisplay(const AId: Integer);
    procedure PopulateInspectorForSelected;
    procedure PopulateInspectorForNew;
  public
    procedure Initialize(const AOrgId: Integer);
  end;

implementation

{$R *.fmx}

uses
  System.StrUtils,
  FMX.Platform,
  uTheme;

const
  // Segoe MDL2 Assets codepoints (Windows)
  ICON_SEARCH  = $E721;
  ICON_MONITOR = $E7F4;
  ICON_COPY    = $E8C8;
  ICON_CHEVRON = $E76C;
  ICON_PLUS    = $E710;
  ICON_REFRESH = $E72C;
  ICON_SAVE    = $E74E;
  ICON_DELETE  = $E74D;

procedure TDisplaysFrameV2.Initialize(const AOrgId: Integer);
var
  ThemeCb: TProc;
begin
  FOrgId := AOrgId;
  FSelectedId := 0;

  SetTitle('Displays');
  SetInspectorVisible(True, 'Display');
  SetInspectorWidth(400);

  // Header actions
  BtnRefresh := TButton.Create(Self);
  BtnRefresh.Parent := HeaderRight;
  BtnRefresh.Align := TAlignLayout.Right;
  BtnRefresh.Width := 120;
  BtnRefresh.Text := WideChar(ICON_REFRESH) + ' Refresh';
  BtnRefresh.OnClick := BtnRefreshClick;
  StylePrimaryButton(BtnRefresh);
  if Assigned(BtnRefresh) then
    BtnRefresh.TextSettings.Font.Family := 'Segoe UI';

  BtnNew := TButton.Create(Self);
  BtnNew.Parent := HeaderRight;
  BtnNew.Align := TAlignLayout.Right;
  BtnNew.Width := 120;
  BtnNew.Margins.Right := SPACE_SM;
  BtnNew.Text := WideChar(ICON_PLUS) + ' New';
  BtnNew.OnClick := BtnNewClick;
  StylePrimaryButton(BtnNew);
  if Assigned(BtnNew) then
    BtnNew.TextSettings.Font.Family := 'Segoe UI';

  // Filters card
  FiltersCard := TRectangle.Create(Self);
  FiltersCard.Parent := BodyContent;
  FiltersCard.Align := TAlignLayout.MostTop;
  FiltersCard.Height := 64;
  FiltersCard.Margins.Top := SPACE_SM;
  StyleCard(FiltersCard);

  LayoutFilters := TLayout.Create(Self);
  LayoutFilters.Parent := FiltersCard;
  LayoutFilters.Align := TAlignLayout.Client;
  LayoutFilters.Padding.Left := SPACE_MD;
  LayoutFilters.Padding.Right := SPACE_MD;
  LayoutFilters.Padding.Top := SPACE_SM;
  LayoutFilters.Padding.Bottom := SPACE_SM;

  LblFilterIcon := CreateMdl2Icon(LayoutFilters, ICON_SEARCH, 16, ColorMuted, TAlignLayout.Left);
  if Assigned(LblFilterIcon) then
  begin
    LblFilterIcon.Margins.Right := SPACE_SM;
    LblFilterIcon.Width := 22;
  end;

  EdtSearch := TEdit.Create(Self);
  EdtSearch.Parent := LayoutFilters;
  EdtSearch.Align := TAlignLayout.Client;
  EdtSearch.Height := 44;
  EdtSearch.TextPrompt := 'Search displays…';
  EdtSearch.OnChange := EdtSearchChange;
  StyleInput(EdtSearch);

  CbStatus := TComboBox.Create(Self);
  CbStatus.Parent := LayoutFilters;
  CbStatus.Align := TAlignLayout.Right;
  CbStatus.Width := 180;
  CbStatus.Height := 44;
  CbStatus.Margins.Left := SPACE_SM;
  CbStatus.Items.Add('All');
  CbStatus.Items.Add('Online');
  CbStatus.Items.Add('Offline');
  CbStatus.ItemIndex := 0;
  CbStatus.OnChange := CbStatusChange;

  LstDisplays := TListBox.Create(Self);
  LstDisplays.Parent := BodyContent;
  LstDisplays.Align := TAlignLayout.Top;
  LstDisplays.Height := 600;
  LstDisplays.Margins.Top := SPACE_SM;
  LstDisplays.ShowCheckboxes := False;
  // Avoid nested scrolling; outer scroll box handles it.
  LstDisplays.ShowScrollBars := False;
  LstDisplays.OnItemClick := LstDisplaysItemClick;

  // Inspector content
  LblInspectorHeader := TLabel.Create(Self);
  LblInspectorHeader.Parent := InspectorContent;
  LblInspectorHeader.Align := TAlignLayout.Top;
  LblInspectorHeader.Height := 28;
  LblInspectorHeader.Text := 'Details';
  StyleSubHeaderLabel(LblInspectorHeader);

  LblId := TLabel.Create(Self);
  LblId.Parent := InspectorContent;
  LblId.Align := TAlignLayout.Top;
  LblId.Height := 22;
  LblId.Margins.Top := 8;
  StyleMutedLabel(LblId);

  LblStatus := TLabel.Create(Self);
  LblStatus.Parent := InspectorContent;
  LblStatus.Align := TAlignLayout.Top;
  LblStatus.Height := 22;
  StyleMutedLabel(LblStatus);

  LblLastSeen := TLabel.Create(Self);
  LblLastSeen.Parent := InspectorContent;
  LblLastSeen.Align := TAlignLayout.Top;
  LblLastSeen.Height := 22;
  StyleMutedLabel(LblLastSeen);

  LblName := TLabel.Create(Self);
  LblName.Parent := InspectorContent;
  LblName.Align := TAlignLayout.Top;
  LblName.Height := 22;
  LblName.Margins.Top := 14;
  LblName.Text := 'Name';
  StyleMutedLabel(LblName);

  EdtName := TEdit.Create(Self);
  EdtName.Parent := InspectorContent;
  EdtName.Align := TAlignLayout.Top;
  EdtName.Height := 44;
  EdtName.TextPrompt := 'Display name';
  StyleInput(EdtName);

  LblOrientation := TLabel.Create(Self);
  LblOrientation.Parent := InspectorContent;
  LblOrientation.Align := TAlignLayout.Top;
  LblOrientation.Height := 22;
  LblOrientation.Margins.Top := 14;
  LblOrientation.Text := 'Orientation';
  StyleMutedLabel(LblOrientation);

  CbOrientation := TComboBox.Create(Self);
  CbOrientation.Parent := InspectorContent;
  CbOrientation.Align := TAlignLayout.Top;
  CbOrientation.Height := 44;
  CbOrientation.Items.Add('Landscape');
  CbOrientation.Items.Add('Portrait');
  CbOrientation.ItemIndex := 0;

  LblProvisioning := TLabel.Create(Self);
  LblProvisioning.Parent := InspectorContent;
  LblProvisioning.Align := TAlignLayout.Top;
  LblProvisioning.Height := 22;
  LblProvisioning.Margins.Top := 14;
  LblProvisioning.Text := 'Provisioning token';
  StyleMutedLabel(LblProvisioning);

  EdtProvisioningToken := TEdit.Create(Self);
  EdtProvisioningToken.Parent := InspectorContent;
  EdtProvisioningToken.Align := TAlignLayout.Top;
  EdtProvisioningToken.Height := 44;
  EdtProvisioningToken.ReadOnly := True;
  EdtProvisioningToken.TextPrompt := '(not available yet)';
  StyleInput(EdtProvisioningToken);

  BtnCopyToken := TButton.Create(Self);
  BtnCopyToken.Parent := InspectorContent;
  BtnCopyToken.Align := TAlignLayout.Top;
  BtnCopyToken.Height := 40;
  BtnCopyToken.Margins.Top := 10;
  BtnCopyToken.Text := WideChar(ICON_COPY) + ' Copy token';
  BtnCopyToken.OnClick := BtnCopyTokenClick;
  StylePrimaryButton(BtnCopyToken);
  if Assigned(BtnCopyToken) then
    BtnCopyToken.TextSettings.Font.Family := 'Segoe UI';

  BtnSave := TButton.Create(Self);
  BtnSave.Parent := InspectorContent;
  BtnSave.Align := TAlignLayout.Top;
  BtnSave.Height := 44;
  BtnSave.Margins.Top := 18;
  BtnSave.Text := WideChar(ICON_SAVE) + ' Save';
  BtnSave.OnClick := BtnSaveClick;
  StylePrimaryButton(BtnSave);
  if Assigned(BtnSave) then
    BtnSave.TextSettings.Font.Family := 'Segoe UI';

  BtnDelete := TButton.Create(Self);
  BtnDelete.Parent := InspectorContent;
  BtnDelete.Align := TAlignLayout.Top;
  BtnDelete.Height := 44;
  BtnDelete.Margins.Top := 10;
  BtnDelete.Text := WideChar(ICON_DELETE) + ' Delete';
  BtnDelete.OnClick := BtnDeleteClick;
  StyleDangerButton(BtnDelete);
  if Assigned(BtnDelete) then
    BtnDelete.TextSettings.Font.Family := 'Segoe UI';

  PopulateInspectorForNew;
  RefreshData;

  ApplyThemeLocal;
  ThemeCb :=
    procedure
    begin
      ApplyThemeLocal;
      RebuildList;
    end;
  RegisterThemeChangedCallback(Self, ThemeCb);
end;

function TDisplaysFrameV2.CreateMdl2Icon(const AParent: TFmxObject; const ACodePoint: Word;
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

function TDisplaysFrameV2.NormalizeStatus(const AStatus: string): string;
var
  S: string;
begin
  S := LowerCase(Trim(AStatus));
  if S = '' then Exit('unknown');
  if SameText(S, 'online') then Exit('online');
  if SameText(S, 'offline') then Exit('offline');
  Result := S;
end;

function TDisplaysFrameV2.StatusToBadgeColor(const AStatus: string): TAlphaColor;
var
  S: string;
begin
  S := NormalizeStatus(AStatus);
  if S = 'online' then Exit(ColorSuccess);
  if S = 'offline' then Exit(ColorDanger);
  Result := ColorCardBorder;              // neutral
end;

function TDisplaysFrameV2.FormatLastSeen(const ALastSeen: string): string;
var
  S: string;
begin
  S := Trim(ALastSeen);
  if S = '' then Exit('last seen: n/a');
  Result := 'last seen: ' + S;
end;

procedure TDisplaysFrameV2.ApplyThemeLocal;
begin
  if Assigned(FiltersCard) then
    StyleCard(FiltersCard);

  StyleSubHeaderLabel(LblInspectorHeader);
  StyleMutedLabel(LblId);
  StyleMutedLabel(LblStatus);
  StyleMutedLabel(LblLastSeen);
  StyleMutedLabel(LblName);
  StyleMutedLabel(LblOrientation);
  StyleMutedLabel(LblProvisioning);

  StyleInput(EdtSearch);
  StyleInput(EdtName);
  StyleInput(EdtProvisioningToken);

  if Assigned(LblFilterIcon) then
  begin
    LblFilterIcon.TextSettings.FontColor := ColorMuted;
    LblFilterIcon.StyledSettings := LblFilterIcon.StyledSettings - [TStyledSetting.FontColor];
  end;

  if Assigned(CbStatus) then
  begin
    // Styling is style-driven for TComboBox; keep defaults.
  end;

  if Assigned(CbOrientation) then
  begin
    // Styling is style-driven for TComboBox; keep defaults.
  end;

  StylePrimaryButton(BtnRefresh);
  StylePrimaryButton(BtnNew);
  StylePrimaryButton(BtnCopyToken);
  StylePrimaryButton(BtnSave);
  StyleDangerButton(BtnDelete);
end;

procedure TDisplaysFrameV2.BtnRefreshClick(Sender: TObject);
begin
  RefreshData;
end;

procedure TDisplaysFrameV2.BtnNewClick(Sender: TObject);
begin
  SelectDisplay(0);
end;

procedure TDisplaysFrameV2.EdtSearchChange(Sender: TObject);
begin
  ApplyFilter;
end;

procedure TDisplaysFrameV2.CbStatusChange(Sender: TObject);
begin
  ApplyFilter;
end;

procedure TDisplaysFrameV2.LstDisplaysItemClick(const Sender: TCustomListBox; const Item: TListBoxItem);
begin
  if Item = nil then Exit;
  SelectDisplay(Item.Tag);
end;

procedure TDisplaysFrameV2.BtnCopyTokenClick(Sender: TObject);
var
  Clip: IFMXClipboardService;
  S: string;
begin
  S := Trim(EdtProvisioningToken.Text);
  if S = '' then Exit;
  if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Clip) then
    Clip.SetClipboard(S);
end;

procedure TDisplaysFrameV2.BtnSaveClick(Sender: TObject);
begin
  // Save is used for both create and update.
  ShowLoading('Saving...');
  TThread.CreateAnonymousThread(
    procedure
    var
      Name, Orientation: string;
      SelId: Integer;
      Disp: TDisplayData;
      UiOk: TThreadProcedure;
      UiErr: TThreadProcedure;
    begin
      Name := Trim(EdtName.Text);
      if Name = '' then
      begin
        UiErr :=
          procedure
          begin
            ShowError('Name is required.');
          end;
        TThread.Queue(nil, UiErr);
        Exit;
      end;

      if (CbOrientation.ItemIndex >= 0) and (CbOrientation.ItemIndex < CbOrientation.Items.Count) then
        Orientation := CbOrientation.Items[CbOrientation.ItemIndex]
      else
        Orientation := 'Landscape';

      SelId := FSelectedId;

      try
        if SelId = 0 then
        begin
          Disp := TApiClient.Instance.CreateDisplay(FOrgId, Name, Orientation);
        end
        else
        begin
          var Idx := FindDisplayIndexById(SelId);
          if Idx < 0 then
            raise Exception.Create('Selected display not found.');

          Disp := FDisplays[Idx];
          Disp.Name := Name;
          Disp.Orientation := Orientation;
          Disp := TApiClient.Instance.UpdateDisplay(Disp);
        end;

        UiOk :=
          procedure
          begin
            if (csDestroying in ComponentState) then Exit;
            HideOverlay;
            RefreshData;
            SelectDisplay(Disp.Id);
          end;
        TThread.Queue(nil, UiOk);
      except
        on E: Exception do
        begin
          UiErr :=
            procedure
            begin
              if (csDestroying in ComponentState) then Exit;
              ShowError('Save failed: ' + E.Message);
            end;
          TThread.Queue(nil, UiErr);
        end;
      end;
    end).Start;
end;

procedure TDisplaysFrameV2.BtnDeleteClick(Sender: TObject);
begin
  if FSelectedId = 0 then Exit;

  ShowLoading('Deleting...');
  TThread.CreateAnonymousThread(
    procedure
    var
      SelId: Integer;
      Ok: Boolean;
      UiOk: TThreadProcedure;
      UiErr: TThreadProcedure;
    begin
      SelId := FSelectedId;
      try
        Ok := TApiClient.Instance.DeleteDisplay(SelId);
        UiOk :=
          procedure
          begin
            if (csDestroying in ComponentState) then Exit;
            if Ok then
            begin
              HideOverlay;
              RefreshData;
              SelectDisplay(0);
            end
            else
              ShowError('Delete failed.');
          end;
        TThread.Queue(nil, UiOk);
      except
        on E: Exception do
        begin
          UiErr :=
            procedure
            begin
              if (csDestroying in ComponentState) then Exit;
              ShowError('Delete failed: ' + E.Message);
            end;
          TThread.Queue(nil, UiErr);
        end;
      end;
    end).Start;
end;

procedure TDisplaysFrameV2.RefreshData;
begin
  ShowLoading('Loading displays...');
  TThread.CreateAnonymousThread(
    procedure
    var
      OrgId: Integer;
      Data: TArray<TDisplayData>;
      UiOk: TThreadProcedure;
      UiErr: TThreadProcedure;
    begin
      OrgId := FOrgId;
      if OrgId = 0 then OrgId := 1;
      try
        Data := TApiClient.Instance.GetDisplays(OrgId);
        UiOk :=
          procedure
          begin
            if (csDestroying in ComponentState) then Exit;
            FDisplays := Data;
            ApplyFilter;
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
              ShowError('Failed to load displays: ' + E.Message);
            end;
          TThread.Queue(nil, UiErr);
        end;
      end;
    end).Start;
end;

procedure TDisplaysFrameV2.ApplyFilter;
var
  Search: string;
  WantStatus: string;
  Ids: TArray<Integer>;
  Cnt: Integer;

  function IsOnline(const S: string): Boolean;
  begin
    Result := SameText(Trim(S), 'online');
  end;

  function MatchesStatus(const Status: string): Boolean;
  begin
    if WantStatus = 'all' then Exit(True);
    if WantStatus = 'online' then Exit(IsOnline(Status));
    if WantStatus = 'offline' then Exit(not IsOnline(Status));
    Result := True;
  end;

  function MatchesSearch(const Name: string): Boolean;
  begin
    if Search = '' then Exit(True);
    Result := ContainsText(Name, Search);
  end;

begin
  Search := Trim(EdtSearch.Text);
  case CbStatus.ItemIndex of
    1: WantStatus := 'online';
    2: WantStatus := 'offline';
  else
    WantStatus := 'all';
  end;

  Cnt := 0;
  SetLength(Ids, Length(FDisplays));
  for var D in FDisplays do
  begin
    if MatchesStatus(D.CurrentStatus) and MatchesSearch(D.Name) then
    begin
      Ids[Cnt] := D.Id;
      Inc(Cnt);
    end;
  end;
  SetLength(Ids, Cnt);
  FFilteredIds := Ids;
  RebuildList;

  // Keep selection if it still exists.
  if (FSelectedId <> 0) and (FindDisplayIndexById(FSelectedId) < 0) then
    SelectDisplay(0);
end;

procedure TDisplaysFrameV2.RebuildList;
begin
  if not Assigned(LstDisplays) then Exit;
  LstDisplays.BeginUpdate;
  try
    LstDisplays.Clear;

    if Length(FFilteredIds) = 0 then
    begin
      var It := TListBoxItem.Create(Self);
      It.Parent := LstDisplays;
      It.Height := 120;
      It.Selectable := False;
      It.Text := '';
      var Card := TRectangle.Create(Self);
      Card.Parent := It;
      Card.Align := TAlignLayout.Contents;
      Card.Margins.Top := SPACE_XS;
      Card.Margins.Bottom := SPACE_XS;
      StyleCard(Card);
      var L := TLabel.Create(Self);
      L.Parent := Card;
      L.Align := TAlignLayout.Center;
      L.Width := 520;
      L.Height := 80;
      L.WordWrap := True;
      L.TextSettings.HorzAlign := TTextAlign.Center;
      L.TextSettings.VertAlign := TTextAlign.Center;
      L.TextSettings.Font.Size := 16;
      L.TextSettings.FontColor := ColorMuted;
      L.StyledSettings := L.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size];
      L.Text := 'No displays found.' + sLineBreak + 'Tip: click New to create one.';
      Exit;
    end;

    for var Id in FFilteredIds do
    begin
      var Idx := FindDisplayIndexById(Id);
      if Idx < 0 then Continue;

      var D := FDisplays[Idx];
      var It := TListBoxItem.Create(Self);
      It.Parent := LstDisplays;
      It.Height := 84;
      It.Tag := D.Id;
      It.Text := '';
      It.StyledSettings := It.StyledSettings + [TStyledSetting.Other];

      var Card := TRectangle.Create(Self);
      Card.Parent := It;
      Card.Align := TAlignLayout.Contents;
      Card.Margins.Top := 8;
      Card.Margins.Bottom := 8;
      StyleCard(Card);

      // Selected state
      if D.Id = FSelectedId then
      begin
        Card.Stroke.Color := ColorPrimary;
        Card.Stroke.Thickness := 2;
      end;

      var Row := TLayout.Create(Self);
      Row.Parent := Card;
      Row.Align := TAlignLayout.Client;
      Row.Padding.Left := SPACE_MD;
      Row.Padding.Right := SPACE_MD;
      Row.Padding.Top := SPACE_SM;
      Row.Padding.Bottom := SPACE_SM;

      var IconCircle := TRectangle.Create(Self);
      IconCircle.Parent := Row;
      IconCircle.Align := TAlignLayout.Left;
      IconCircle.Width := 44;
      IconCircle.Height := 44;
      IconCircle.Margins.Right := SPACE_SM;
      IconCircle.Fill.Kind := TBrushKind.Solid;
      IconCircle.Fill.Color := ColorPrimary;
      IconCircle.Stroke.Kind := TBrushKind.None;
      IconCircle.XRadius := 22;
      IconCircle.YRadius := 22;

      var IconLbl := CreateMdl2Icon(IconCircle, ICON_MONITOR, 18, TAlphaColorRec.White, TAlignLayout.Client);
      IconLbl.Width := 44;

      var TextCol := TLayout.Create(Self);
      TextCol.Parent := Row;
      TextCol.Align := TAlignLayout.Client;
      TextCol.Padding.Top := 2;

      var NameLbl := TLabel.Create(Self);
      NameLbl.Parent := TextCol;
      NameLbl.Align := TAlignLayout.Top;
      NameLbl.Height := 26;
      NameLbl.Text := IfThen(Trim(D.Name) <> '', D.Name, '(unnamed display)');
      NameLbl.TextSettings.Font.Size := FONT_SIZE_SUBHEADER;
      NameLbl.TextSettings.Font.Style := [TFontStyle.fsBold];
      NameLbl.TextSettings.FontColor := ColorText;
      NameLbl.StyledSettings := NameLbl.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size];

      var SubLbl := TLabel.Create(Self);
      SubLbl.Parent := TextCol;
      SubLbl.Align := TAlignLayout.Top;
      SubLbl.Height := 20;
      SubLbl.TextSettings.Font.Size := FONT_SIZE_MUTED;
      SubLbl.TextSettings.FontColor := ColorMuted;
      SubLbl.StyledSettings := SubLbl.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size];
      SubLbl.Text := FormatLastSeen(D.LastSeen);

      // Right chevron + status badge
      var RightCol := TLayout.Create(Self);
      RightCol.Parent := Row;
      RightCol.Align := TAlignLayout.Right;
      RightCol.Width := 140;

      var Chevron := CreateMdl2Icon(RightCol, ICON_CHEVRON, 14, ColorMuted, TAlignLayout.Right);
      Chevron.Width := 18;
      Chevron.Margins.Left := 10;

      var Badge := TRectangle.Create(Self);
      Badge.Parent := RightCol;
      Badge.Align := TAlignLayout.Right;
      Badge.Height := 26;
      Badge.Width := 92;
      Badge.Margins.Top := 9;
      Badge.Margins.Right := 0;
      Badge.Fill.Kind := TBrushKind.Solid;
      Badge.Fill.Color := StatusToBadgeColor(D.CurrentStatus);
      Badge.Stroke.Kind := TBrushKind.None;
      Badge.XRadius := 13;
      Badge.YRadius := 13;

      var BadgeLbl := TLabel.Create(Self);
      BadgeLbl.Parent := Badge;
      BadgeLbl.Align := TAlignLayout.Client;
      BadgeLbl.TextSettings.HorzAlign := TTextAlign.Center;
      BadgeLbl.TextSettings.VertAlign := TTextAlign.Center;
      BadgeLbl.TextSettings.Font.Size := 12;
      BadgeLbl.TextSettings.Font.Style := [TFontStyle.fsBold];
      BadgeLbl.TextSettings.FontColor := TAlphaColorRec.White;
      BadgeLbl.StyledSettings := BadgeLbl.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size];
      BadgeLbl.Text := UpperCase(NormalizeStatus(D.CurrentStatus));
    end;
  finally
    LstDisplays.EndUpdate;
  end;

  // Keep listbox sized so outer scroll handles scrolling
  LstDisplays.Height := Max(360, (Length(FFilteredIds) * 84) + 40);
end;

function TDisplaysFrameV2.FindDisplayIndexById(const AId: Integer): Integer;
begin
  Result := -1;
  for var i := 0 to High(FDisplays) do
    if FDisplays[i].Id = AId then
      Exit(i);
end;

procedure TDisplaysFrameV2.SelectDisplay(const AId: Integer);
begin
  FSelectedId := AId;
  if AId = 0 then
    PopulateInspectorForNew
  else
    PopulateInspectorForSelected;

  RebuildList;
end;

procedure TDisplaysFrameV2.PopulateInspectorForSelected;
var
  Idx: Integer;
  D: TDisplayData;
  StatusText: string;
begin
  Idx := FindDisplayIndexById(FSelectedId);
  if Idx < 0 then
  begin
    PopulateInspectorForNew;
    Exit;
  end;

  D := FDisplays[Idx];
  StatusText := Trim(D.CurrentStatus);
  if StatusText = '' then StatusText := 'unknown';

  SetInspectorVisible(True, 'Display');

  LblId.Text := Format('ID: %d', [D.Id]);
  LblStatus.Text := 'Status: ' + StatusText;
  LblLastSeen.Text := 'Last seen: ' + IfThen(Trim(D.LastSeen) <> '', D.LastSeen, 'n/a');

  EdtName.Text := D.Name;
  if SameText(Trim(D.Orientation), 'portrait') then
    CbOrientation.ItemIndex := 1
  else
    CbOrientation.ItemIndex := 0;

  EdtProvisioningToken.Text := D.ProvisioningToken;
  BtnCopyToken.Enabled := Trim(D.ProvisioningToken) <> '';

  BtnDelete.Enabled := True;
end;

procedure TDisplaysFrameV2.PopulateInspectorForNew;
begin
  SetInspectorVisible(True, 'New Display');

  LblId.Text := 'ID: (new)';
  LblStatus.Text := 'Status: n/a';
  LblLastSeen.Text := 'Last seen: n/a';

  EdtName.Text := '';
  CbOrientation.ItemIndex := 0;

  EdtProvisioningToken.Text := '';
  BtnCopyToken.Enabled := False;

  BtnDelete.Enabled := False;
end;

end.
