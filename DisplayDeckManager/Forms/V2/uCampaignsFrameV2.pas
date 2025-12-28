unit uCampaignsFrameV2;

interface

uses
  System.SysUtils, System.Classes, System.UITypes, System.Math, System.StrUtils,
  System.Generics.Collections, System.Generics.Defaults, System.DateUtils, System.JSON,
  FMX.Types, FMX.Controls, FMX.StdCtrls, FMX.Objects, FMX.Layouts, FMX.Edit, FMX.Graphics,
  FMX.ListBox, FMX.Controls.Presentation, FMX.Memo,
  uFrameBase,
  uApiClient;

type
  TCampaignsFrameV2 = class(TFrameBase)
  private
    FOrgId: Integer;
    FCampaigns: TArray<TCampaignData>;
    FDisplays: TArray<TDisplayData>;
    FMedia: TArray<TMediaFileData>;

    FFilteredIds: TArray<Integer>;
    FSelectedCampaignId: Integer;

    // Selected campaign details cache
    FSchedules: TArray<TScheduleData>;
    FItems: TArray<TCampaignItemData>;
    FAssignments: TArray<TDisplayCampaignAssignmentData>;

    FAssignmentsLoading: Boolean;
    FDetailsLoadSeq: Integer;

    FSelectedScheduleId: Integer;
    FSelectedAssignmentId: Integer;
    FSelectedItemId: Integer;

    // Header actions
    BtnRefresh: TButton;
    BtnNew: TButton;

    // Main content
    FiltersCard: TRectangle;
    LayoutFilters: TLayout;
    LblFilterIcon: TLabel;
    EdtSearch: TEdit;
    CbOrientation: TComboBox;
    CbStatus: TComboBox;
    LstCampaigns: TListBox;

    // Inspector (campaign)
    LblInspectorHeader: TLabel;
    LblCampaignId: TLabel;
    LblCampaignMeta: TLabel;
    LblCampaignStatus: TLabel;

    LblName: TLabel;
    EdtName: TEdit;

    LblOrientation: TLabel;
    CbCampaignOrientation: TComboBox;

    BtnSaveCampaign: TButton;
    BtnDeleteCampaign: TButton;

    // Deployment section
    LblDeployHeader: TLabel;
    DeployErrorCard: TRectangle;
    LblDeployError: TLabel;
    LstAssignments: TListBox;
    LayoutAssign: TLayout;
    CbAssignDisplay: TComboBox;
    BtnAssign: TButton;
    BtnUnassign: TButton;
    BtnSetPrimary: TButton;

    // Schedule section
    LblScheduleHeader: TLabel;
    LstSchedules: TListBox;
    BtnNewSchedule: TButton;

    LblStart: TLabel;
    EdtStart: TEdit;
    LblEnd: TLabel;
    EdtEnd: TEdit;

    LblRecurring: TLabel;
    MemoRecurring: TMemo;

    LayoutRecBuilder: TLayout;
    CbDow: array[0..6] of TCheckBox;
    EdtRecStart: TEdit;
    EdtRecEnd: TEdit;
    BtnApplyRecurrence: TButton;

    BtnSaveSchedule: TButton;
    BtnDeleteSchedule: TButton;

    // Playlist section
    LblPlaylistHeader: TLabel;
    LstItems: TListBox;
    LayoutAddMedia: TLayout;
    CbAddMedia: TComboBox;
    EdtDuration: TEdit;
    BtnAddItem: TButton;
    BtnRemoveItem: TButton;
    BtnMoveUp: TButton;
    BtnMoveDown: TButton;

    function CreateMdl2Icon(const AParent: TFmxObject; const ACodePoint: Word;
      const ASize: Single; const AColor: TAlphaColor; const AAlign: TAlignLayout): TLabel;

    procedure ApplyThemeLocal;

    procedure ClearDeployError;
    procedure ShowDeployError(const Msg: string);

    // Filters + list
    procedure BtnRefreshClick(Sender: TObject);
    procedure BtnNewClick(Sender: TObject);
    procedure EdtSearchChange(Sender: TObject);
    procedure CbOrientationChange(Sender: TObject);
    procedure CbStatusChange(Sender: TObject);
    procedure LstCampaignsItemClick(const Sender: TCustomListBox; const Item: TListBoxItem);

    // Campaign actions
    procedure BtnSaveCampaignClick(Sender: TObject);
    procedure BtnDeleteCampaignClick(Sender: TObject);

    // Deployment actions
    procedure LstAssignmentsItemClick(const Sender: TCustomListBox; const Item: TListBoxItem);
    procedure BtnAssignClick(Sender: TObject);
    procedure BtnUnassignClick(Sender: TObject);
    procedure BtnSetPrimaryClick(Sender: TObject);

    // Schedule actions
    procedure LstSchedulesItemClick(const Sender: TCustomListBox; const Item: TListBoxItem);
    procedure BtnNewScheduleClick(Sender: TObject);
    procedure BtnApplyRecurrenceClick(Sender: TObject);
    procedure BtnSaveScheduleClick(Sender: TObject);
    procedure BtnDeleteScheduleClick(Sender: TObject);

    // Playlist actions
    procedure LstItemsItemClick(const Sender: TCustomListBox; const Item: TListBoxItem);
    procedure BtnAddItemClick(Sender: TObject);
    procedure BtnRemoveItemClick(Sender: TObject);
    procedure BtnMoveUpClick(Sender: TObject);
    procedure BtnMoveDownClick(Sender: TObject);

    procedure RefreshBaseData;
    procedure ApplyFilter;
    procedure RebuildCampaignList;

    function FindCampaignIndexById(const AId: Integer): Integer;
    procedure SelectCampaign(const AId: Integer);

    procedure PopulateInspectorForNew;
    procedure PopulateInspectorForSelected;

    procedure RefreshSelectedDetails;
    procedure RebuildSchedulesList;
    procedure RebuildAssignmentsList;
    procedure RebuildItemsList;

    function GetDisplayName(const ADisplayId: Integer): string;
    function GetMediaName(const AMediaId: Integer): string;

    procedure RebuildAssignDisplayChoices;
    procedure RebuildAddMediaChoices;

    function TryParseHm(const S: string; out H, M: Integer): Boolean;
    function BuildRecurringPatternFromBuilder: string;
    function MatchesRecurringLocal(const Pattern: string; const NowLocal: TDateTime): Boolean;
    function IsScheduleActiveNow(const Sch: TScheduleData): Boolean;

    function SortItemsByDisplayOrder(const AItems: TArray<TCampaignItemData>): TArray<TCampaignItemData>;
  public
    procedure Initialize(const AOrgId: Integer);
  end;

implementation

{$R *.fmx}

uses
  FMX.DialogService,
  uTheme;

const
  // Segoe MDL2 Assets codepoints
  ICON_SEARCH  = $E721;
  ICON_FLAG    = $E7C1;
  ICON_PLUS    = $E710;
  ICON_REFRESH = $E72C;
  ICON_SAVE    = $E74E;
  ICON_DELETE  = $E74D;
  ICON_LINK    = $E71B;
  ICON_UNLINK  = $E711;
  ICON_STAR    = $E734;
  ICON_CLOCK   = $E823;
  ICON_LIST    = $EA37;
  ICON_UP      = $E70E;
  ICON_DOWN    = $E70D;

procedure TCampaignsFrameV2.Initialize(const AOrgId: Integer);
var
  ThemeCb: TProc;
begin
  FOrgId := AOrgId;
  FSelectedCampaignId := 0;
  FSelectedScheduleId := 0;
  FSelectedAssignmentId := 0;
  FSelectedItemId := 0;

  SetTitle('Campaigns');
  SetInspectorVisible(True, 'Campaign');
  SetInspectorWidth(460);

  // Header actions
  BtnRefresh := TButton.Create(Self);
  BtnRefresh.Parent := HeaderRight;
  BtnRefresh.Align := TAlignLayout.Right;
  BtnRefresh.Width := 120;
  BtnRefresh.Text := WideChar(ICON_REFRESH) + ' Refresh';
  BtnRefresh.OnClick := BtnRefreshClick;
  StylePrimaryButton(BtnRefresh);
  BtnRefresh.TextSettings.Font.Family := 'Segoe UI';

  BtnNew := TButton.Create(Self);
  BtnNew.Parent := HeaderRight;
  BtnNew.Align := TAlignLayout.Right;
  BtnNew.Width := 120;
  BtnNew.Margins.Right := SPACE_SM;
  BtnNew.Text := WideChar(ICON_PLUS) + ' New';
  BtnNew.OnClick := BtnNewClick;
  StylePrimaryButton(BtnNew);
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
  LblFilterIcon.Margins.Right := SPACE_SM;
  LblFilterIcon.Width := 22;

  EdtSearch := TEdit.Create(Self);
  EdtSearch.Parent := LayoutFilters;
  EdtSearch.Align := TAlignLayout.Client;
  EdtSearch.Height := 44;
  EdtSearch.TextPrompt := 'Search campaigns…';
  EdtSearch.OnChange := EdtSearchChange;
  StyleInput(EdtSearch);

  CbOrientation := TComboBox.Create(Self);
  CbOrientation.Parent := LayoutFilters;
  CbOrientation.Align := TAlignLayout.Right;
  CbOrientation.Width := 160;
  CbOrientation.Height := 44;
  CbOrientation.Margins.Left := SPACE_SM;
  CbOrientation.Items.Add('All');
  CbOrientation.Items.Add('Landscape');
  CbOrientation.Items.Add('Portrait');
  CbOrientation.ItemIndex := 0;
  CbOrientation.OnChange := CbOrientationChange;

  CbStatus := TComboBox.Create(Self);
  CbStatus.Parent := LayoutFilters;
  CbStatus.Align := TAlignLayout.Right;
  CbStatus.Width := 160;
  CbStatus.Height := 44;
  CbStatus.Margins.Left := SPACE_SM;
  CbStatus.Items.Add('All');
  CbStatus.Items.Add('Active');
  CbStatus.Items.Add('Inactive');
  CbStatus.ItemIndex := 0;
  CbStatus.OnChange := CbStatusChange;

  LstCampaigns := TListBox.Create(Self);
  LstCampaigns.Parent := BodyContent;
  LstCampaigns.Align := TAlignLayout.Top;
  LstCampaigns.Height := 700;
  LstCampaigns.Margins.Top := SPACE_SM;
  LstCampaigns.ShowCheckboxes := False;
  LstCampaigns.ShowScrollBars := False;
  LstCampaigns.OnItemClick := LstCampaignsItemClick;

  // Inspector content
  LblInspectorHeader := TLabel.Create(Self);
  LblInspectorHeader.Parent := InspectorContent;
  LblInspectorHeader.Align := TAlignLayout.Top;
  LblInspectorHeader.Height := 28;
  LblInspectorHeader.Text := 'Details';
  StyleSubHeaderLabel(LblInspectorHeader);

  LblCampaignId := TLabel.Create(Self);
  LblCampaignId.Parent := InspectorContent;
  LblCampaignId.Align := TAlignLayout.Top;
  LblCampaignId.Height := 22;
  LblCampaignId.Margins.Top := 8;
  StyleMutedLabel(LblCampaignId);

  LblCampaignMeta := TLabel.Create(Self);
  LblCampaignMeta.Parent := InspectorContent;
  LblCampaignMeta.Align := TAlignLayout.Top;
  LblCampaignMeta.Height := 22;
  LblCampaignMeta.Margins.Top := 2;
  StyleMutedLabel(LblCampaignMeta);

  LblCampaignStatus := TLabel.Create(Self);
  LblCampaignStatus.Parent := InspectorContent;
  LblCampaignStatus.Align := TAlignLayout.Top;
  LblCampaignStatus.Height := 22;
  LblCampaignStatus.Margins.Top := 2;
  StyleMutedLabel(LblCampaignStatus);

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
  EdtName.TextPrompt := 'Campaign name';
  StyleInput(EdtName);

  LblOrientation := TLabel.Create(Self);
  LblOrientation.Parent := InspectorContent;
  LblOrientation.Align := TAlignLayout.Top;
  LblOrientation.Height := 22;
  LblOrientation.Margins.Top := 10;
  LblOrientation.Text := 'Orientation';
  StyleMutedLabel(LblOrientation);

  CbCampaignOrientation := TComboBox.Create(Self);
  CbCampaignOrientation.Parent := InspectorContent;
  CbCampaignOrientation.Align := TAlignLayout.Top;
  CbCampaignOrientation.Height := 44;
  CbCampaignOrientation.Items.Add('Landscape');
  CbCampaignOrientation.Items.Add('Portrait');
  CbCampaignOrientation.ItemIndex := 0;

  BtnSaveCampaign := TButton.Create(Self);
  BtnSaveCampaign.Parent := InspectorContent;
  BtnSaveCampaign.Align := TAlignLayout.Top;
  BtnSaveCampaign.Height := 44;
  BtnSaveCampaign.Margins.Top := 14;
  BtnSaveCampaign.Text := WideChar(ICON_SAVE) + ' Save campaign';
  BtnSaveCampaign.OnClick := BtnSaveCampaignClick;
  StylePrimaryButton(BtnSaveCampaign);
  BtnSaveCampaign.TextSettings.Font.Family := 'Segoe UI';

  BtnDeleteCampaign := TButton.Create(Self);
  BtnDeleteCampaign.Parent := InspectorContent;
  BtnDeleteCampaign.Align := TAlignLayout.Top;
  BtnDeleteCampaign.Height := 44;
  BtnDeleteCampaign.Margins.Top := 10;
  BtnDeleteCampaign.Text := WideChar(ICON_DELETE) + ' Delete campaign';
  BtnDeleteCampaign.OnClick := BtnDeleteCampaignClick;
  StyleDangerButton(BtnDeleteCampaign);
  BtnDeleteCampaign.TextSettings.Font.Family := 'Segoe UI';

  // Deployment
  LblDeployHeader := TLabel.Create(Self);
  LblDeployHeader.Parent := InspectorContent;
  LblDeployHeader.Align := TAlignLayout.Top;
  LblDeployHeader.Height := 28;
  LblDeployHeader.Margins.Top := 18;
  LblDeployHeader.Text := WideChar(ICON_LINK) + ' Deployment';
  StyleSubHeaderLabel(LblDeployHeader);

  DeployErrorCard := TRectangle.Create(Self);
  DeployErrorCard.Parent := InspectorContent;
  DeployErrorCard.Align := TAlignLayout.Top;
  DeployErrorCard.Height := 54;
  DeployErrorCard.Margins.Top := 8;
  DeployErrorCard.Padding.Left := 12;
  DeployErrorCard.Padding.Right := 12;
  DeployErrorCard.Padding.Top := 10;
  DeployErrorCard.Padding.Bottom := 10;
  DeployErrorCard.XRadius := 10;
  DeployErrorCard.YRadius := 10;
  DeployErrorCard.Stroke.Kind := TBrushKind.Solid;
  DeployErrorCard.Stroke.Thickness := 1;
  DeployErrorCard.Fill.Kind := TBrushKind.Solid;
  DeployErrorCard.Visible := False;

  LblDeployError := TLabel.Create(Self);
  LblDeployError.Parent := DeployErrorCard;
  LblDeployError.Align := TAlignLayout.Client;
  LblDeployError.WordWrap := True;
  LblDeployError.Text := '';
  LblDeployError.StyledSettings := LblDeployError.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size];
  LblDeployError.TextSettings.Font.Size := 12;

  LstAssignments := TListBox.Create(Self);
  LstAssignments.Parent := InspectorContent;
  LstAssignments.Align := TAlignLayout.Top;
  LstAssignments.Height := 160;
  LstAssignments.ShowScrollBars := False;
  LstAssignments.OnItemClick := LstAssignmentsItemClick;

  LayoutAssign := TLayout.Create(Self);
  LayoutAssign.Parent := InspectorContent;
  LayoutAssign.Align := TAlignLayout.Top;
  LayoutAssign.Height := 44;
  LayoutAssign.Margins.Top := 8;

  CbAssignDisplay := TComboBox.Create(Self);
  CbAssignDisplay.Parent := LayoutAssign;
  CbAssignDisplay.Align := TAlignLayout.Client;
  CbAssignDisplay.Height := 44;

  BtnAssign := TButton.Create(Self);
  BtnAssign.Parent := LayoutAssign;
  BtnAssign.Align := TAlignLayout.Right;
  BtnAssign.Width := 110;
  BtnAssign.Text := 'Assign';
  BtnAssign.OnClick := BtnAssignClick;
  StylePrimaryButton(BtnAssign);

  BtnUnassign := TButton.Create(Self);
  BtnUnassign.Parent := InspectorContent;
  BtnUnassign.Align := TAlignLayout.Top;
  BtnUnassign.Height := 40;
  BtnUnassign.Margins.Top := 6;
  BtnUnassign.Text := WideChar(ICON_UNLINK) + ' Unassign selected';
  BtnUnassign.OnClick := BtnUnassignClick;
  StyleDangerButton(BtnUnassign);
  BtnUnassign.TextSettings.Font.Family := 'Segoe UI';

  BtnSetPrimary := TButton.Create(Self);
  BtnSetPrimary.Parent := InspectorContent;
  BtnSetPrimary.Align := TAlignLayout.Top;
  BtnSetPrimary.Height := 40;
  BtnSetPrimary.Margins.Top := 6;
  BtnSetPrimary.Text := WideChar(ICON_STAR) + ' Make primary on selected display';
  BtnSetPrimary.OnClick := BtnSetPrimaryClick;
  StylePrimaryButton(BtnSetPrimary);
  BtnSetPrimary.TextSettings.Font.Family := 'Segoe UI';

  // Schedules
  LblScheduleHeader := TLabel.Create(Self);
  LblScheduleHeader.Parent := InspectorContent;
  LblScheduleHeader.Align := TAlignLayout.Top;
  LblScheduleHeader.Height := 28;
  LblScheduleHeader.Margins.Top := 18;
  LblScheduleHeader.Text := WideChar(ICON_CLOCK) + ' Schedule';
  StyleSubHeaderLabel(LblScheduleHeader);

  LstSchedules := TListBox.Create(Self);
  LstSchedules.Parent := InspectorContent;
  LstSchedules.Align := TAlignLayout.Top;
  LstSchedules.Height := 120;
  LstSchedules.ShowScrollBars := False;
  LstSchedules.OnItemClick := LstSchedulesItemClick;

  BtnNewSchedule := TButton.Create(Self);
  BtnNewSchedule.Parent := InspectorContent;
  BtnNewSchedule.Align := TAlignLayout.Top;
  BtnNewSchedule.Height := 36;
  BtnNewSchedule.Margins.Top := 6;
  BtnNewSchedule.Text := WideChar(ICON_PLUS) + ' New schedule';
  BtnNewSchedule.OnClick := BtnNewScheduleClick;
  StylePrimaryButton(BtnNewSchedule);
  BtnNewSchedule.TextSettings.Font.Family := 'Segoe UI';

  LblStart := TLabel.Create(Self);
  LblStart.Parent := InspectorContent;
  LblStart.Align := TAlignLayout.Top;
  LblStart.Height := 22;
  LblStart.Margins.Top := 10;
  LblStart.Text := 'StartTime (ISO8601 UTC, blank = no start)';
  StyleMutedLabel(LblStart);

  EdtStart := TEdit.Create(Self);
  EdtStart.Parent := InspectorContent;
  EdtStart.Align := TAlignLayout.Top;
  EdtStart.Height := 40;
  EdtStart.TextPrompt := '2025-12-21T08:00:00Z';
  StyleInput(EdtStart);

  LblEnd := TLabel.Create(Self);
  LblEnd.Parent := InspectorContent;
  LblEnd.Align := TAlignLayout.Top;
  LblEnd.Height := 22;
  LblEnd.Margins.Top := 8;
  LblEnd.Text := 'EndTime (ISO8601 UTC, blank = no end)';
  StyleMutedLabel(LblEnd);

  EdtEnd := TEdit.Create(Self);
  EdtEnd.Parent := InspectorContent;
  EdtEnd.Align := TAlignLayout.Top;
  EdtEnd.Height := 40;
  EdtEnd.TextPrompt := '2025-12-21T18:00:00Z';
  StyleInput(EdtEnd);

  LblRecurring := TLabel.Create(Self);
  LblRecurring.Parent := InspectorContent;
  LblRecurring.Align := TAlignLayout.Top;
  LblRecurring.Height := 22;
  LblRecurring.Margins.Top := 8;
  LblRecurring.Text := 'RecurringPattern (optional JSON)';
  StyleMutedLabel(LblRecurring);

  MemoRecurring := TMemo.Create(Self);
  MemoRecurring.Parent := InspectorContent;
  MemoRecurring.Align := TAlignLayout.Top;
  MemoRecurring.Height := 84;
  MemoRecurring.Lines.Clear;

  LayoutRecBuilder := TLayout.Create(Self);
  LayoutRecBuilder.Parent := InspectorContent;
  LayoutRecBuilder.Align := TAlignLayout.Top;
  LayoutRecBuilder.Height := 88;
  LayoutRecBuilder.Margins.Top := 8;

  // Days of week checkboxes
  for var i := 0 to 6 do
  begin
    CbDow[i] := TCheckBox.Create(Self);
    CbDow[i].Parent := LayoutRecBuilder;
    CbDow[i].Align := TAlignLayout.Left;
    CbDow[i].Width := 56;
    CbDow[i].Text := Copy('SunMonTueWedThuFriSat', i*3+1, 3);
  end;

  EdtRecStart := TEdit.Create(Self);
  EdtRecStart.Parent := LayoutRecBuilder;
  EdtRecStart.Align := TAlignLayout.Right;
  EdtRecStart.Width := 70;
  EdtRecStart.Height := 36;
  EdtRecStart.TextPrompt := '08:00';
  StyleInput(EdtRecStart);

  EdtRecEnd := TEdit.Create(Self);
  EdtRecEnd.Parent := LayoutRecBuilder;
  EdtRecEnd.Align := TAlignLayout.Right;
  EdtRecEnd.Width := 70;
  EdtRecEnd.Height := 36;
  EdtRecEnd.Margins.Right := 8;
  EdtRecEnd.TextPrompt := '18:00';
  StyleInput(EdtRecEnd);

  BtnApplyRecurrence := TButton.Create(Self);
  BtnApplyRecurrence.Parent := InspectorContent;
  BtnApplyRecurrence.Align := TAlignLayout.Top;
  BtnApplyRecurrence.Height := 36;
  BtnApplyRecurrence.Margins.Top := 6;
  BtnApplyRecurrence.Text := 'Apply recurrence builder';
  BtnApplyRecurrence.OnClick := BtnApplyRecurrenceClick;
  StylePrimaryButton(BtnApplyRecurrence);

  BtnSaveSchedule := TButton.Create(Self);
  BtnSaveSchedule.Parent := InspectorContent;
  BtnSaveSchedule.Align := TAlignLayout.Top;
  BtnSaveSchedule.Height := 40;
  BtnSaveSchedule.Margins.Top := 8;
  BtnSaveSchedule.Text := WideChar(ICON_SAVE) + ' Save schedule';
  BtnSaveSchedule.OnClick := BtnSaveScheduleClick;
  StylePrimaryButton(BtnSaveSchedule);
  BtnSaveSchedule.TextSettings.Font.Family := 'Segoe UI';

  BtnDeleteSchedule := TButton.Create(Self);
  BtnDeleteSchedule.Parent := InspectorContent;
  BtnDeleteSchedule.Align := TAlignLayout.Top;
  BtnDeleteSchedule.Height := 40;
  BtnDeleteSchedule.Margins.Top := 6;
  BtnDeleteSchedule.Text := WideChar(ICON_DELETE) + ' Delete schedule';
  BtnDeleteSchedule.OnClick := BtnDeleteScheduleClick;
  StyleDangerButton(BtnDeleteSchedule);
  BtnDeleteSchedule.TextSettings.Font.Family := 'Segoe UI';

  // Playlist
  LblPlaylistHeader := TLabel.Create(Self);
  LblPlaylistHeader.Parent := InspectorContent;
  LblPlaylistHeader.Align := TAlignLayout.Top;
  LblPlaylistHeader.Height := 28;
  LblPlaylistHeader.Margins.Top := 18;
  LblPlaylistHeader.Text := WideChar(ICON_LIST) + ' Playlist';
  StyleSubHeaderLabel(LblPlaylistHeader);

  LstItems := TListBox.Create(Self);
  LstItems.Parent := InspectorContent;
  LstItems.Align := TAlignLayout.Top;
  LstItems.Height := 180;
  LstItems.ShowScrollBars := False;
  LstItems.OnItemClick := LstItemsItemClick;

  LayoutAddMedia := TLayout.Create(Self);
  LayoutAddMedia.Parent := InspectorContent;
  LayoutAddMedia.Align := TAlignLayout.Top;
  LayoutAddMedia.Height := 44;
  LayoutAddMedia.Margins.Top := 8;

  CbAddMedia := TComboBox.Create(Self);
  CbAddMedia.Parent := LayoutAddMedia;
  CbAddMedia.Align := TAlignLayout.Client;
  CbAddMedia.Height := 44;

  EdtDuration := TEdit.Create(Self);
  EdtDuration.Parent := LayoutAddMedia;
  EdtDuration.Align := TAlignLayout.Right;
  EdtDuration.Width := 70;
  EdtDuration.Height := 44;
  EdtDuration.Margins.Left := 8;
  EdtDuration.Text := '10';
  EdtDuration.TextPrompt := 'sec';
  StyleInput(EdtDuration);

  BtnAddItem := TButton.Create(Self);
  BtnAddItem.Parent := InspectorContent;
  BtnAddItem.Align := TAlignLayout.Top;
  BtnAddItem.Height := 40;
  BtnAddItem.Margins.Top := 6;
  BtnAddItem.Text := WideChar(ICON_PLUS) + ' Add media';
  BtnAddItem.OnClick := BtnAddItemClick;
  StylePrimaryButton(BtnAddItem);
  BtnAddItem.TextSettings.Font.Family := 'Segoe UI';

  BtnRemoveItem := TButton.Create(Self);
  BtnRemoveItem.Parent := InspectorContent;
  BtnRemoveItem.Align := TAlignLayout.Top;
  BtnRemoveItem.Height := 40;
  BtnRemoveItem.Margins.Top := 6;
  BtnRemoveItem.Text := WideChar(ICON_DELETE) + ' Remove selected item';
  BtnRemoveItem.OnClick := BtnRemoveItemClick;
  StyleDangerButton(BtnRemoveItem);
  BtnRemoveItem.TextSettings.Font.Family := 'Segoe UI';

  var LayoutMove := TLayout.Create(Self);
  LayoutMove.Parent := InspectorContent;
  LayoutMove.Align := TAlignLayout.Top;
  LayoutMove.Height := 40;
  LayoutMove.Margins.Top := 6;

  BtnMoveUp := TButton.Create(Self);
  BtnMoveUp.Parent := LayoutMove;
  BtnMoveUp.Align := TAlignLayout.Left;
  BtnMoveUp.Width := 150;
  BtnMoveUp.Text := WideChar(ICON_UP) + ' Move up';
  BtnMoveUp.OnClick := BtnMoveUpClick;
  StylePrimaryButton(BtnMoveUp);

  BtnMoveDown := TButton.Create(Self);
  BtnMoveDown.Parent := LayoutMove;
  BtnMoveDown.Align := TAlignLayout.Left;
  BtnMoveDown.Width := 150;
  BtnMoveDown.Margins.Left := 10;
  BtnMoveDown.Text := WideChar(ICON_DOWN) + ' Move down';
  BtnMoveDown.OnClick := BtnMoveDownClick;
  StylePrimaryButton(BtnMoveDown);

  PopulateInspectorForNew;
  RefreshBaseData;

  ApplyThemeLocal;
  ThemeCb :=
    procedure
    begin
      ApplyThemeLocal;
      RebuildCampaignList;
    end;
  RegisterThemeChangedCallback(Self, ThemeCb);
end;

function TCampaignsFrameV2.CreateMdl2Icon(const AParent: TFmxObject; const ACodePoint: Word;
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

procedure TCampaignsFrameV2.ApplyThemeLocal;
begin
  if Assigned(FiltersCard) then
    StyleCard(FiltersCard);

  StyleSubHeaderLabel(LblInspectorHeader);
  StyleMutedLabel(LblCampaignId);
  StyleMutedLabel(LblCampaignMeta);
  StyleMutedLabel(LblCampaignStatus);

  StyleMutedLabel(LblName);
  StyleMutedLabel(LblOrientation);

  StyleSubHeaderLabel(LblDeployHeader);
  StyleSubHeaderLabel(LblScheduleHeader);
  StyleSubHeaderLabel(LblPlaylistHeader);

  StyleInput(EdtSearch);
  StyleInput(EdtName);
  StyleInput(EdtStart);
  StyleInput(EdtEnd);
  StyleInput(EdtRecStart);
  StyleInput(EdtRecEnd);
  StyleInput(EdtDuration);

  if Assigned(LblFilterIcon) then
  begin
    LblFilterIcon.TextSettings.FontColor := ColorMuted;
    LblFilterIcon.StyledSettings := LblFilterIcon.StyledSettings - [TStyledSetting.FontColor];
  end;

  StylePrimaryButton(BtnRefresh);
  StylePrimaryButton(BtnNew);
  StylePrimaryButton(BtnSaveCampaign);
  StyleDangerButton(BtnDeleteCampaign);

  StylePrimaryButton(BtnAssign);
  StyleDangerButton(BtnUnassign);
  StylePrimaryButton(BtnSetPrimary);

  if Assigned(DeployErrorCard) then
  begin
    DeployErrorCard.Stroke.Color := TAlphaColor(BtnUnassign.Tag);
    DeployErrorCard.Fill.Color := $10EF4444;
  end;
  if Assigned(LblDeployError) then
    LblDeployError.TextSettings.FontColor := TAlphaColor(BtnUnassign.Tag);

  StylePrimaryButton(BtnNewSchedule);
  StylePrimaryButton(BtnApplyRecurrence);
  StylePrimaryButton(BtnSaveSchedule);
  StyleDangerButton(BtnDeleteSchedule);

  StylePrimaryButton(BtnAddItem);
  StyleDangerButton(BtnRemoveItem);
  StylePrimaryButton(BtnMoveUp);
  StylePrimaryButton(BtnMoveDown);
end;

procedure TCampaignsFrameV2.ClearDeployError;
begin
  if Assigned(LblDeployError) then
    LblDeployError.Text := '';
  if Assigned(DeployErrorCard) then
    DeployErrorCard.Visible := False;
end;

procedure TCampaignsFrameV2.ShowDeployError(const Msg: string);
begin
  if not Assigned(DeployErrorCard) or not Assigned(LblDeployError) then Exit;
  LblDeployError.Text := Msg;
  DeployErrorCard.Visible := Trim(Msg) <> '';
end;

procedure TCampaignsFrameV2.BtnRefreshClick(Sender: TObject);
begin
  RefreshBaseData;
end;

procedure TCampaignsFrameV2.BtnNewClick(Sender: TObject);
begin
  SelectCampaign(0);
end;

procedure TCampaignsFrameV2.EdtSearchChange(Sender: TObject);
begin
  ApplyFilter;
end;

procedure TCampaignsFrameV2.CbOrientationChange(Sender: TObject);
begin
  ApplyFilter;
end;

procedure TCampaignsFrameV2.CbStatusChange(Sender: TObject);
begin
  ApplyFilter;
end;

procedure TCampaignsFrameV2.LstCampaignsItemClick(const Sender: TCustomListBox; const Item: TListBoxItem);
begin
  if Item = nil then Exit;
  SelectCampaign(Item.Tag);
end;

procedure TCampaignsFrameV2.BtnSaveCampaignClick(Sender: TObject);
begin
  var Name := Trim(EdtName.Text);
  var Orientation := '';
  if CbCampaignOrientation.ItemIndex >= 0 then
    Orientation := CbCampaignOrientation.Items[CbCampaignOrientation.ItemIndex];

  if Name = '' then
  begin
    TDialogService.ShowMessage('Please enter a name.');
    Exit;
  end;

  ShowLoading('Saving campaign…');
  TThread.CreateAnonymousThread(
    procedure
    begin
      try
        if FSelectedCampaignId = 0 then
          TApiClient.Instance.CreateCampaign(FOrgId, Name, Orientation)
        else
        begin
          var Idx := FindCampaignIndexById(FSelectedCampaignId);
          if Idx >= 0 then
          begin
            FCampaigns[Idx].Name := Name;
            FCampaigns[Idx].Orientation := Orientation;
            TApiClient.Instance.UpdateCampaign(FCampaigns[Idx]);
          end;
        end;

        TThread.Queue(nil,
          procedure
          begin
            HideOverlay;
            RefreshBaseData;
          end);
      except
        on E: Exception do
          TThread.Queue(nil,
            procedure
            begin
              ShowError('Save failed: ' + E.Message);
            end);
      end;
    end).Start;
end;

procedure TCampaignsFrameV2.BtnDeleteCampaignClick(Sender: TObject);
begin
  if FSelectedCampaignId = 0 then Exit;

  TDialogService.MessageDialog(
    'Delete this campaign? This also deletes schedules, assignments and playlist items.',
    TMsgDlgType.mtConfirmation,
    [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo],
    TMsgDlgBtn.mbNo,
    0,
    procedure(const AResult: TModalResult)
    begin
      if AResult <> mrYes then Exit;
      ShowLoading('Deleting…');
      TThread.CreateAnonymousThread(
        procedure
        begin
          try
            TApiClient.Instance.DeleteCampaign(FSelectedCampaignId);
            TThread.Queue(nil,
              procedure
              begin
                HideOverlay;
                SelectCampaign(0);
                RefreshBaseData;
              end);
          except
            on E: Exception do
              TThread.Queue(nil,
                procedure
                begin
                  ShowError('Delete failed: ' + E.Message);
                end);
          end;
        end).Start;
    end);
end;

procedure TCampaignsFrameV2.LstAssignmentsItemClick(const Sender: TCustomListBox; const Item: TListBoxItem);
begin
  if Item = nil then Exit;
  FSelectedAssignmentId := Item.Tag;
end;

procedure TCampaignsFrameV2.BtnAssignClick(Sender: TObject);
begin
  if FSelectedCampaignId = 0 then Exit;
  if CbAssignDisplay.ItemIndex < 0 then Exit;

  // We store the display id in TagString as text to avoid fighting combobox styles.
  var DisplayId := StrToIntDef(CbAssignDisplay.Items[CbAssignDisplay.ItemIndex], 0);
  // If list is "123 - Name" parse prefix.
  if DisplayId = 0 then
  begin
    var S := CbAssignDisplay.Items[CbAssignDisplay.ItemIndex];
    var P := Pos(' - ', S);
    if P > 0 then
      DisplayId := StrToIntDef(Copy(S, 1, P - 1), 0);
  end;

  if DisplayId = 0 then Exit;

  ShowLoading('Assigning…');
  ClearDeployError;
  TThread.CreateAnonymousThread(
    procedure
    begin
      try
        // Default to non-primary; user can promote.
        TApiClient.Instance.CreateDisplayCampaignAssignment(DisplayId, FSelectedCampaignId, False);
        TThread.Queue(nil,
          procedure
          begin
            HideOverlay;
            RefreshSelectedDetails;
          end);
      except
        on E: Exception do
          TThread.Queue(nil,
            procedure
            begin
              HideOverlay;
              ShowDeployError('Assign failed: ' + E.Message);
            end);
      end;
    end).Start;
end;

procedure TCampaignsFrameV2.BtnUnassignClick(Sender: TObject);
begin
  if FSelectedAssignmentId = 0 then Exit;

  TDialogService.MessageDialog(
    'Unassign this display from the campaign?',
    TMsgDlgType.mtConfirmation,
    [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo],
    TMsgDlgBtn.mbNo,
    0,
    procedure(const AResult: TModalResult)
    begin
      if AResult <> mrYes then Exit;
      ShowLoading('Unassigning…');
      ClearDeployError;
      TThread.CreateAnonymousThread(
        procedure
        begin
          try
            TApiClient.Instance.DeleteCampaignAssignment(FSelectedAssignmentId);
            TThread.Queue(nil,
              procedure
              begin
                HideOverlay;
                FSelectedAssignmentId := 0;
                RefreshSelectedDetails;
              end);
          except
            on E: Exception do
              TThread.Queue(nil,
                procedure
                begin
                  HideOverlay;
                  ShowDeployError('Unassign failed: ' + E.Message);
                end);
          end;
        end).Start;
    end);
end;

procedure TCampaignsFrameV2.BtnSetPrimaryClick(Sender: TObject);
begin
  if FSelectedAssignmentId = 0 then Exit;

  // Find selected assignment for display id
  var DisplayId := 0;
  var CampaignId := FSelectedCampaignId;
  for var A in FAssignments do
    if A.Id = FSelectedAssignmentId then
    begin
      DisplayId := A.DisplayId;
      Break;
    end;

  if DisplayId = 0 then Exit;

  ShowLoading('Updating primary…');
  ClearDeployError;
  TThread.CreateAnonymousThread(
    procedure
    begin
      try
        TApiClient.Instance.SetDisplayPrimary(DisplayId, CampaignId);
        TThread.Queue(nil,
          procedure
          begin
            HideOverlay;
            RefreshSelectedDetails;
          end);
      except
        on E: Exception do
          TThread.Queue(nil,
            procedure
            begin
              HideOverlay;
              ShowDeployError('Set primary failed: ' + E.Message);
            end);
      end;
    end).Start;
end;

procedure TCampaignsFrameV2.LstSchedulesItemClick(const Sender: TCustomListBox; const Item: TListBoxItem);
begin
  if Item = nil then Exit;
  FSelectedScheduleId := Item.Tag;

  for var S in FSchedules do
    if S.Id = FSelectedScheduleId then
    begin
      EdtStart.Text := S.StartTime;
      EdtEnd.Text := S.EndTime;
      MemoRecurring.Lines.Text := S.RecurringPattern;
      Exit;
    end;
end;

procedure TCampaignsFrameV2.BtnNewScheduleClick(Sender: TObject);
begin
  FSelectedScheduleId := 0;
  EdtStart.Text := '';
  EdtEnd.Text := '';
  MemoRecurring.Lines.Text := '';
end;

procedure TCampaignsFrameV2.BtnApplyRecurrenceClick(Sender: TObject);
begin
  MemoRecurring.Lines.Text := BuildRecurringPatternFromBuilder;
end;

procedure TCampaignsFrameV2.BtnSaveScheduleClick(Sender: TObject);
begin
  if FSelectedCampaignId = 0 then Exit;

  var StartIso := Trim(EdtStart.Text);
  var EndIso := Trim(EdtEnd.Text);
  var Rec := Trim(MemoRecurring.Lines.Text);

  ShowLoading('Saving schedule…');
  TThread.CreateAnonymousThread(
    procedure
    begin
      try
        if FSelectedScheduleId = 0 then
          TApiClient.Instance.CreateCampaignSchedule(FSelectedCampaignId, StartIso, EndIso, Rec)
        else
          TApiClient.Instance.UpdateSchedule(FSelectedScheduleId, StartIso, EndIso, Rec);

        TThread.Queue(nil,
          procedure
          begin
            HideOverlay;
            RefreshSelectedDetails;
          end);
      except
        on E: Exception do
          TThread.Queue(nil,
            procedure
            begin
              ShowError('Save schedule failed: ' + E.Message);
            end);
      end;
    end).Start;
end;

procedure TCampaignsFrameV2.BtnDeleteScheduleClick(Sender: TObject);
begin
  if FSelectedScheduleId = 0 then Exit;

  TDialogService.MessageDialog(
    'Delete this schedule?',
    TMsgDlgType.mtConfirmation,
    [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo],
    TMsgDlgBtn.mbNo,
    0,
    procedure(const AResult: TModalResult)
    begin
      if AResult <> mrYes then Exit;
      ShowLoading('Deleting schedule…');
      TThread.CreateAnonymousThread(
        procedure
        begin
          try
            TApiClient.Instance.DeleteSchedule(FSelectedScheduleId);
            TThread.Queue(nil,
              procedure
              begin
                HideOverlay;
                FSelectedScheduleId := 0;
                RefreshSelectedDetails;
              end);
          except
            on E: Exception do
              TThread.Queue(nil,
                procedure
                begin
                  ShowError('Delete schedule failed: ' + E.Message);
                end);
          end;
        end).Start;
    end);
end;

procedure TCampaignsFrameV2.LstItemsItemClick(const Sender: TCustomListBox; const Item: TListBoxItem);
begin
  if Item = nil then Exit;
  FSelectedItemId := Item.Tag;
end;

procedure TCampaignsFrameV2.BtnAddItemClick(Sender: TObject);
begin
  if FSelectedCampaignId = 0 then Exit;
  if CbAddMedia.ItemIndex < 0 then Exit;

  var MediaId := 0;
  var S := CbAddMedia.Items[CbAddMedia.ItemIndex];
  var P := Pos(' - ', S);
  if P > 0 then
    MediaId := StrToIntDef(Copy(S, 1, P - 1), 0)
  else
    MediaId := StrToIntDef(S, 0);

  if MediaId = 0 then Exit;

  var Duration := StrToIntDef(Trim(EdtDuration.Text), 10);
  if Duration <= 0 then Duration := 10;

  var NextOrder := 1;
  for var It in FItems do
    if It.DisplayOrder >= NextOrder then
      NextOrder := It.DisplayOrder + 1;

  ShowLoading('Adding media…');
  TThread.CreateAnonymousThread(
    procedure
    begin
      try
        TApiClient.Instance.CreateCampaignItem(FSelectedCampaignId, MediaId, NextOrder, Duration);
        TThread.Queue(nil,
          procedure
          begin
            HideOverlay;
            RefreshSelectedDetails;
          end);
      except
        on E: Exception do
          TThread.Queue(nil,
            procedure
            begin
              ShowError('Add media failed: ' + E.Message);
            end);
      end;
    end).Start;
end;

procedure TCampaignsFrameV2.BtnRemoveItemClick(Sender: TObject);
begin
  if FSelectedItemId = 0 then Exit;

  TDialogService.MessageDialog(
    'Remove this media item from the campaign playlist?',
    TMsgDlgType.mtConfirmation,
    [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo],
    TMsgDlgBtn.mbNo,
    0,
    procedure(const AResult: TModalResult)
    begin
      if AResult <> mrYes then Exit;
      ShowLoading('Removing item…');
      TThread.CreateAnonymousThread(
        procedure
        begin
          try
            TApiClient.Instance.DeleteCampaignItem(FSelectedItemId);
            TThread.Queue(nil,
              procedure
              begin
                HideOverlay;
                FSelectedItemId := 0;
                RefreshSelectedDetails;
              end);
          except
            on E: Exception do
              TThread.Queue(nil,
                procedure
                begin
                  HideOverlay;
                  ShowError('Remove failed: ' + E.Message);
                end);
          end;
        end).Start;
    end);
end;

procedure TCampaignsFrameV2.BtnMoveUpClick(Sender: TObject);
begin
  if FSelectedItemId = 0 then Exit;

  var Sorted := SortItemsByDisplayOrder(FItems);
  var Idx := -1;
  for var i := 0 to High(Sorted) do
    if Sorted[i].Id = FSelectedItemId then
    begin
      Idx := i;
      Break;
    end;
  if (Idx <= 0) then Exit;

  var A := Sorted[Idx - 1];
  var B := Sorted[Idx];

  ShowLoading('Reordering…');
  TThread.CreateAnonymousThread(
    procedure
    begin
      try
        // swap display orders
        TApiClient.Instance.UpdateCampaignItem(A.Id, A.MediaFileId, B.DisplayOrder, A.Duration);
        TApiClient.Instance.UpdateCampaignItem(B.Id, B.MediaFileId, A.DisplayOrder, B.Duration);

        TThread.Queue(nil,
          procedure
          begin
            HideOverlay;
            RefreshSelectedDetails;
          end);
      except
        on E: Exception do
          TThread.Queue(nil,
            procedure
            begin
              ShowError('Reorder failed: ' + E.Message);
            end);
      end;
    end).Start;
end;

procedure TCampaignsFrameV2.BtnMoveDownClick(Sender: TObject);
begin
  if FSelectedItemId = 0 then Exit;

  var Sorted := SortItemsByDisplayOrder(FItems);
  var Idx := -1;
  for var i := 0 to High(Sorted) do
    if Sorted[i].Id = FSelectedItemId then
    begin
      Idx := i;
      Break;
    end;
  if (Idx < 0) or (Idx >= High(Sorted)) then Exit;

  var A := Sorted[Idx];
  var B := Sorted[Idx + 1];

  ShowLoading('Reordering…');
  TThread.CreateAnonymousThread(
    procedure
    begin
      try
        TApiClient.Instance.UpdateCampaignItem(A.Id, A.MediaFileId, B.DisplayOrder, A.Duration);
        TApiClient.Instance.UpdateCampaignItem(B.Id, B.MediaFileId, A.DisplayOrder, B.Duration);

        TThread.Queue(nil,
          procedure
          begin
            HideOverlay;
            RefreshSelectedDetails;
          end);
      except
        on E: Exception do
          TThread.Queue(nil,
            procedure
            begin
              ShowError('Reorder failed: ' + E.Message);
            end);
      end;
    end).Start;
end;

procedure TCampaignsFrameV2.RefreshBaseData;
begin
  ShowLoading('Loading campaigns…');

  TThread.CreateAnonymousThread(
    procedure
    begin
      try
        var C := TApiClient.Instance.GetCampaigns(FOrgId);
        var D := TApiClient.Instance.GetDisplays(FOrgId);
        var M := TApiClient.Instance.GetMediaFiles(FOrgId);

        TThread.Queue(nil,
          procedure
          begin
            FCampaigns := C;
            FDisplays := D;
            FMedia := M;
            HideOverlay;
            ApplyFilter;

            if (FSelectedCampaignId <> 0) and (FindCampaignIndexById(FSelectedCampaignId) < 0) then
              SelectCampaign(0);

            if FSelectedCampaignId <> 0 then
              RefreshSelectedDetails
            else
              PopulateInspectorForNew;
          end);
      except
        on E: Exception do
          TThread.Queue(nil,
            procedure
            begin
              ShowError('Load failed: ' + E.Message);
            end);
      end;
    end).Start;
end;

procedure TCampaignsFrameV2.ApplyFilter;
var
  Search: string;
  WantOrientation: string;
  WantStatus: string;
  Tmp: TList<Integer>;
begin
  Search := LowerCase(Trim(EdtSearch.Text));
  WantOrientation := '';
  if CbOrientation.ItemIndex > 0 then
    WantOrientation := CbOrientation.Items[CbOrientation.ItemIndex];
  WantStatus := '';
  if CbStatus.ItemIndex > 0 then
    WantStatus := CbStatus.Items[CbStatus.ItemIndex];

  Tmp := TList<Integer>.Create;
  try
    for var i := 0 to High(FCampaigns) do
    begin
      var Ok := True;
      if (Search <> '') and (Pos(Search, LowerCase(FCampaigns[i].Name)) = 0) then
        Ok := False;

      if Ok and (WantOrientation <> '') and (not SameText(FCampaigns[i].Orientation, WantOrientation)) then
        Ok := False;

      if Ok and (WantStatus <> '') then
      begin
        // Status filter is a best-effort: we only know active for selected campaign.
        // For list filtering, just do nothing here.
      end;

      if Ok then
        Tmp.Add(FCampaigns[i].Id);
    end;

    FFilteredIds := Tmp.ToArray;
  finally
    Tmp.Free;
  end;

  RebuildCampaignList;
end;

procedure TCampaignsFrameV2.RebuildCampaignList;
begin
  if not Assigned(LstCampaigns) then Exit;
  LstCampaigns.BeginUpdate;
  try
    LstCampaigns.Clear;

    if Length(FFilteredIds) = 0 then
    begin
      var It := TListBoxItem.Create(Self);
      It.Parent := LstCampaigns;
      It.Height := 120;
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
      L.Text := 'No campaigns found.' + sLineBreak + 'Tip: click New to create one.';
      Exit;
    end;

    for var i := 0 to High(FFilteredIds) do
    begin
      var Id := FFilteredIds[i];
      var Idx := FindCampaignIndexById(Id);
      if Idx < 0 then Continue;

      var Camp := FCampaigns[Idx];

      var Item := TListBoxItem.Create(Self);
      Item.Parent := LstCampaigns;
      Item.Height := 86;
      Item.Text := '';
      Item.Tag := Camp.Id;

      var Card := TRectangle.Create(Self);
      Card.Parent := Item;
      Card.Align := TAlignLayout.Client;
      Card.Margins.Bottom := SPACE_SM;
      Card.Padding.Left := SPACE_MD;
      Card.Padding.Right := SPACE_MD;
      Card.Padding.Top := 12;
      Card.Padding.Bottom := 12;
      StyleCard(Card);

      var LeftCol := TLayout.Create(Self);
      LeftCol.Parent := Card;
      LeftCol.Align := TAlignLayout.Client;

      var TitleRow := TLayout.Create(Self);
      TitleRow.Parent := LeftCol;
      TitleRow.Align := TAlignLayout.Top;
      TitleRow.Height := 26;

      var Icon := CreateMdl2Icon(TitleRow, ICON_FLAG, 16, ColorPrimary, TAlignLayout.Left);
      Icon.Margins.Right := SPACE_XS;

      var LblTitle := TLabel.Create(Self);
      LblTitle.Parent := TitleRow;
      LblTitle.Align := TAlignLayout.Client;
      LblTitle.Text := Camp.Name;
      LblTitle.TextSettings.Font.Size := 16;
      LblTitle.TextSettings.Font.Style := [TFontStyle.fsBold];
      LblTitle.StyledSettings := LblTitle.StyledSettings - [TStyledSetting.FontColor];
      LblTitle.TextSettings.FontColor := ColorText;

      var Badge := TRectangle.Create(Self);
      Badge.Parent := TitleRow;
      Badge.Align := TAlignLayout.Right;
      Badge.Width := 90;
      Badge.Height := 24;
      Badge.Margins.Left := SPACE_SM;
      Badge.XRadius := 12;
      Badge.YRadius := 12;
      Badge.Stroke.Kind := TBrushKind.None;
      Badge.Fill.Kind := TBrushKind.Solid;
      Badge.Fill.Color := ColorCardBorder;

      var LblBadge := TLabel.Create(Self);
      LblBadge.Parent := Badge;
      LblBadge.Align := TAlignLayout.Client;
      LblBadge.Text := Camp.Orientation;
      LblBadge.TextSettings.HorzAlign := TTextAlign.Center;
      LblBadge.TextSettings.VertAlign := TTextAlign.Center;
      LblBadge.TextSettings.Font.Size := 12;
      LblBadge.StyledSettings := LblBadge.StyledSettings - [TStyledSetting.FontColor];
      LblBadge.TextSettings.FontColor := ColorText;

      var Subtitle := TLabel.Create(Self);
      Subtitle.Parent := LeftCol;
      Subtitle.Align := TAlignLayout.Top;
      Subtitle.Height := 20;
      Subtitle.Margins.Top := 4;
      Subtitle.Text := 'Select to manage schedule, deployment, playlist';
      StyleMutedLabel(Subtitle);

      if Camp.Id = FSelectedCampaignId then
      begin
        Card.Stroke.Kind := TBrushKind.Solid;
        Card.Stroke.Color := ColorPrimary;
        Card.Stroke.Thickness := 2;
      end;

      // Right chevron
      var Chevron := CreateMdl2Icon(Card, $E76C, 14, ColorMuted, TAlignLayout.Right);
      Chevron.Margins.Left := 10;
      Chevron.Align := TAlignLayout.Right;
    end;

  finally
    LstCampaigns.EndUpdate;
  end;
end;

function TCampaignsFrameV2.FindCampaignIndexById(const AId: Integer): Integer;
begin
  for var i := 0 to High(FCampaigns) do
    if FCampaigns[i].Id = AId then
      Exit(i);
  Result := -1;
end;

procedure TCampaignsFrameV2.SelectCampaign(const AId: Integer);
begin
  FSelectedCampaignId := AId;
  FSelectedScheduleId := 0;
  FSelectedAssignmentId := 0;
  FSelectedItemId := 0;
  ClearDeployError;

  if AId = 0 then
  begin
    FSchedules := nil;
    FItems := nil;
    FAssignments := nil;
    PopulateInspectorForNew;
    RebuildCampaignList;
    Exit;
  end;

  PopulateInspectorForSelected;
  RebuildCampaignList;
  RefreshSelectedDetails;
end;

procedure TCampaignsFrameV2.PopulateInspectorForNew;
begin
  LblCampaignId.Text := 'id: (new)';
  LblCampaignMeta.Text := '';
  LblCampaignStatus.Text := '';

  EdtName.Text := '';
  CbCampaignOrientation.ItemIndex := 0;

  LstSchedules.Clear;
  LstAssignments.Clear;
  LstItems.Clear;

  CbAssignDisplay.Clear;
  CbAddMedia.Clear;

  BtnDeleteCampaign.Enabled := False;
end;

procedure TCampaignsFrameV2.PopulateInspectorForSelected;
begin
  var Idx := FindCampaignIndexById(FSelectedCampaignId);
  if Idx < 0 then Exit;

  var C := FCampaigns[Idx];
  LblCampaignId.Text := Format('id: %d', [C.Id]);
  LblCampaignMeta.Text := Format('orientation: %s', [C.Orientation]);

  EdtName.Text := C.Name;
  if SameText(C.Orientation, 'Portrait') then
    CbCampaignOrientation.ItemIndex := 1
  else
    CbCampaignOrientation.ItemIndex := 0;

  BtnDeleteCampaign.Enabled := True;
end;

procedure TCampaignsFrameV2.RefreshSelectedDetails;
begin
  if FSelectedCampaignId = 0 then Exit;

  ShowLoading('Loading campaign details…');
  ClearDeployError;

  // Avoid stale deployment UI while details reload.
  FSelectedAssignmentId := 0;
  FAssignments := [];
  if Assigned(CbAssignDisplay) then
    CbAssignDisplay.Clear;

  FAssignmentsLoading := True;
  Inc(FDetailsLoadSeq);
  var LoadSeq := FDetailsLoadSeq;
  var CampaignId := FSelectedCampaignId;

  TThread.CreateAnonymousThread(
    procedure
    begin
      var S: TArray<TScheduleData>;
      var It: TArray<TCampaignItemData>;

      try
        S := TApiClient.Instance.GetCampaignSchedules(FSelectedCampaignId);
        It := TApiClient.Instance.GetCampaignItems(FSelectedCampaignId);
      except
        on E: Exception do
        begin
          TThread.Queue(nil,
            procedure
            begin
              if (LoadSeq <> FDetailsLoadSeq) or (CampaignId <> FSelectedCampaignId) then Exit;

              FAssignmentsLoading := False;
              HideOverlay;
              RebuildAssignmentsList;
              ShowError('Load details failed: ' + E.Message);
            end);
          Exit;
        end;
      end;

      TThread.Queue(nil,
        procedure
        begin
          if (LoadSeq <> FDetailsLoadSeq) or (CampaignId <> FSelectedCampaignId) then Exit;

          FSchedules := S;
          FItems := It;
          HideOverlay;

          RebuildSchedulesList;
          RebuildItemsList;
          RebuildAddMediaChoices;
          RebuildAssignmentsList; // shows loading placeholder
          LblCampaignStatus.Text := 'status: Loading deployment…';
          LblCampaignMeta.Text := Format('orientation: %s • displays: … • media: %d • schedules: %d',
            [FCampaigns[FindCampaignIndexById(FSelectedCampaignId)].Orientation, Length(FItems), Length(FSchedules)]);
        end);

      var AssignList := TList<TDisplayCampaignAssignmentData>.Create;
      try
        try
          for var D in FDisplays do
          begin
            var L := TApiClient.Instance.GetDisplayCampaignAssignments(D.Id);
            for var A in L do
              if A.CampaignId = FSelectedCampaignId then
                AssignList.Add(A);
          end;
        except
          on E: Exception do
          begin
            TThread.Queue(nil,
              procedure
              begin
                if (LoadSeq <> FDetailsLoadSeq) or (CampaignId <> FSelectedCampaignId) then Exit;

                FAssignmentsLoading := False;
                RebuildAssignmentsList;
                LblCampaignStatus.Text := 'status: Deployment load failed';
                ShowDeployError('Load deployments failed: ' + E.Message);
              end);
            Exit;
          end;
        end;

        var AArr := AssignList.ToArray;

        TThread.Queue(nil,
          procedure
          begin
            if (LoadSeq <> FDetailsLoadSeq) or (CampaignId <> FSelectedCampaignId) then Exit;

            FAssignmentsLoading := False;
            FAssignments := AArr;
            RebuildAssignmentsList;
            RebuildAssignDisplayChoices;

            // Status summary
            var Active := False;
            if Length(FAssignments) > 0 then
            begin
              if Length(FSchedules) = 0 then
                Active := True
              else
              begin
                for var Sch in FSchedules do
                  if IsScheduleActiveNow(Sch) then
                  begin
                    Active := True;
                    Break;
                  end;
              end;
            end;

            if Active then
              LblCampaignStatus.Text := 'status: Active (deployed + schedule eligible)'
            else
            begin
              if Length(FAssignments) = 0 then
                LblCampaignStatus.Text := 'status: Inactive (no displays assigned)'
              else
                LblCampaignStatus.Text := 'status: Inactive (outside schedule)';
            end;

            // Meta update
            LblCampaignMeta.Text := Format('orientation: %s • displays: %d • media: %d • schedules: %d',
              [FCampaigns[FindCampaignIndexById(FSelectedCampaignId)].Orientation, Length(FAssignments), Length(FItems), Length(FSchedules)]);
          end);
      finally
        AssignList.Free;
      end;
    end).Start;
end;

procedure TCampaignsFrameV2.RebuildSchedulesList;
begin
  if not Assigned(LstSchedules) then Exit;

  LstSchedules.BeginUpdate;
  try
    LstSchedules.Clear;

    if Length(FSchedules) = 0 then
    begin
      var Empty := TListBoxItem.Create(Self);
      Empty.Parent := LstSchedules;
      Empty.Text := '(no schedules — always active)';
      Empty.Enabled := False;
      Exit;
    end;

    for var S in FSchedules do
    begin
      var Item := TListBoxItem.Create(Self);
      Item.Parent := LstSchedules;
      Item.Height := 34;
      Item.Tag := S.Id;
      var Desc := '';
      if (S.StartTime = '') and (S.EndTime = '') then
        Desc := '(no start/end)'
      else
        Desc := Trim(S.StartTime) + ' → ' + Trim(S.EndTime);
      if S.RecurringPattern <> '' then
        Desc := Desc + ' (recurring)';
      Item.Text := Format('#%d %s', [S.Id, Desc]);
    end;
  finally
    LstSchedules.EndUpdate;
  end;
end;

procedure TCampaignsFrameV2.RebuildAssignmentsList;
begin
  if not Assigned(LstAssignments) then Exit;

  LstAssignments.BeginUpdate;
  try
    LstAssignments.Clear;

    if FAssignmentsLoading then
    begin
      var Loading := TListBoxItem.Create(Self);
      Loading.Parent := LstAssignments;
      Loading.Text := '(loading deployments…)';
      Loading.Enabled := False;
      Exit;
    end;

    if Length(FAssignments) = 0 then
    begin
      var Empty := TListBoxItem.Create(Self);
      Empty.Parent := LstAssignments;
      Empty.Text := '(no displays assigned)';
      Empty.Enabled := False;
      Exit;
    end;

    for var A in FAssignments do
    begin
      var Item := TListBoxItem.Create(Self);
      Item.Parent := LstAssignments;
      Item.Height := 34;
      Item.Tag := A.Id;
      var Name := GetDisplayName(A.DisplayId);
      if A.IsPrimary then
        Item.Text := Name + ' (primary)'
      else
        Item.Text := Name;
    end;

  finally
    LstAssignments.EndUpdate;
  end;
end;

procedure TCampaignsFrameV2.RebuildItemsList;
begin
  if not Assigned(LstItems) then Exit;

  var Sorted := SortItemsByDisplayOrder(FItems);

  LstItems.BeginUpdate;
  try
    LstItems.Clear;

    if Length(Sorted) = 0 then
    begin
      var Empty := TListBoxItem.Create(Self);
      Empty.Parent := LstItems;
      Empty.Text := '(no media)';
      Empty.Enabled := False;
      Exit;
    end;

    for var Itm in Sorted do
    begin
      var Item := TListBoxItem.Create(Self);
      Item.Parent := LstItems;
      Item.Height := 34;
      Item.Tag := Itm.Id;
      Item.Text := Format('%d. %s (%ds)', [Itm.DisplayOrder, GetMediaName(Itm.MediaFileId), Itm.Duration]);
    end;

  finally
    LstItems.EndUpdate;
  end;
end;

function TCampaignsFrameV2.GetDisplayName(const ADisplayId: Integer): string;
begin
  for var D in FDisplays do
    if D.Id = ADisplayId then
      Exit(D.Name);
  Result := Format('Display %d', [ADisplayId]);
end;

function TCampaignsFrameV2.GetMediaName(const AMediaId: Integer): string;
begin
  for var M in FMedia do
    if M.Id = AMediaId then
      Exit(M.FileName);
  Result := Format('Media %d', [AMediaId]);
end;

procedure TCampaignsFrameV2.RebuildAssignDisplayChoices;
begin
  if not Assigned(CbAssignDisplay) then Exit;
  CbAssignDisplay.Clear;

  if FSelectedCampaignId = 0 then Exit;

  var Idx := FindCampaignIndexById(FSelectedCampaignId);
  if Idx < 0 then Exit;
  var Orientation := FCampaigns[Idx].Orientation;

  for var D in FDisplays do
  begin
    if (Orientation <> '') and (D.Orientation <> '') and (not SameText(D.Orientation, Orientation)) then
      Continue;

    var Already := False;
    for var A in FAssignments do
      if A.DisplayId = D.Id then
      begin
        Already := True;
        Break;
      end;
    if Already then Continue;

    CbAssignDisplay.Items.Add(Format('%d - %s', [D.Id, D.Name]));
  end;

  if CbAssignDisplay.Items.Count > 0 then
    CbAssignDisplay.ItemIndex := 0;
end;

procedure TCampaignsFrameV2.RebuildAddMediaChoices;
begin
  if not Assigned(CbAddMedia) then Exit;
  CbAddMedia.Clear;

  if FSelectedCampaignId = 0 then Exit;

  var Idx := FindCampaignIndexById(FSelectedCampaignId);
  if Idx < 0 then Exit;
  var Orientation := FCampaigns[Idx].Orientation;

  for var M in FMedia do
  begin
    if (Orientation <> '') and (M.Orientation <> '') and (not SameText(M.Orientation, Orientation)) then
      Continue;

    CbAddMedia.Items.Add(Format('%d - %s', [M.Id, M.FileName]));
  end;

  if CbAddMedia.Items.Count > 0 then
    CbAddMedia.ItemIndex := 0;
end;

function TCampaignsFrameV2.TryParseHm(const S: string; out H, M: Integer): Boolean;
var
  P: Integer;
  SH, SM: string;
begin
  Result := False;
  H := 0;
  M := 0;
  P := Pos(':', S);
  if P <= 0 then Exit;
  SH := Trim(Copy(S, 1, P - 1));
  SM := Trim(Copy(S, P + 1, MaxInt));
  if (SH = '') or (SM = '') then Exit;
  H := StrToIntDef(SH, -1);
  M := StrToIntDef(SM, -1);
  if (H < 0) or (H > 23) or (M < 0) or (M > 59) then Exit;
  Result := True;
end;

function TCampaignsFrameV2.BuildRecurringPatternFromBuilder: string;
var
  Arr: TJSONArray;
  Obj: TJSONObject;
  HasAny: Boolean;
begin
  Result := '';
  HasAny := False;
  Obj := TJSONObject.Create;
  try
    Arr := TJSONArray.Create;
    try
      for var i := 0 to 6 do
        if Assigned(CbDow[i]) and CbDow[i].IsChecked then
        begin
          Arr.Add(i);
          HasAny := True;
        end;
      if Arr.Count > 0 then
        Obj.AddPair('daysOfWeek', Arr)
      else
        Arr.Free;

      if Trim(EdtRecStart.Text) <> '' then
      begin
        Obj.AddPair('startLocal', Trim(EdtRecStart.Text));
        HasAny := True;
      end;
      if Trim(EdtRecEnd.Text) <> '' then
      begin
        Obj.AddPair('endLocal', Trim(EdtRecEnd.Text));
        HasAny := True;
      end;

      if HasAny then
        Result := Obj.ToJSON;
    except
      on E: Exception do
        Result := '';
    end;
  finally
    Obj.Free;
  end;
end;

function TCampaignsFrameV2.MatchesRecurringLocal(const Pattern: string; const NowLocal: TDateTime): Boolean;
var
  J: TJSONValue;
  Obj: TJSONObject;
  Days: TJSONArray;
  StartStr, EndStr: string;
  Dow: Integer;
  Hs, Ms, He, Me: Integer;
  Tod: Integer;
  StartMin, EndMin: Integer;
  DayOk: Boolean;
begin
  if Trim(Pattern) = '' then Exit(True);

  J := TJSONObject.ParseJSONValue(Pattern);
  if not (J is TJSONObject) then
  begin
    J.Free;
    Exit(True);
  end;

  Obj := TJSONObject(J);
  try
    DayOk := True;
    if Obj.TryGetValue<TJSONArray>('daysOfWeek', Days) then
    begin
      DayOk := False;
      Dow := DayOfWeek(NowLocal) - 1; // 0=Sun..6=Sat
      for var i := 0 to Days.Count - 1 do
        if StrToIntDef(Days.Items[i].Value, -1) = Dow then
        begin
          DayOk := True;
          Break;
        end;
    end;

    if not DayOk then Exit(False);

    StartStr := '';
    EndStr := '';
    Obj.TryGetValue<string>('startLocal', StartStr);
    Obj.TryGetValue<string>('endLocal', EndStr);

    if (Trim(StartStr) = '') or (Trim(EndStr) = '') then
      Exit(True);

    if (not TryParseHm(StartStr, Hs, Ms)) or (not TryParseHm(EndStr, He, Me)) then
      Exit(True);

    StartMin := Hs * 60 + Ms;
    EndMin := He * 60 + Me;
    Tod := HourOf(NowLocal) * 60 + MinuteOf(NowLocal);

    if StartMin <= EndMin then
      Result := (Tod >= StartMin) and (Tod < EndMin)
    else
      // spans midnight
      Result := (Tod >= StartMin) or (Tod < EndMin);
  finally
    Obj.Free;
  end;
end;

function TCampaignsFrameV2.IsScheduleActiveNow(const Sch: TScheduleData): Boolean;
var
  NowLocal, NowUtc: TDateTime;
  StartAt, EndAt: TDateTime;
  HasStart, HasEnd: Boolean;
begin
  NowLocal := Now;
  NowUtc := TTimeZone.Local.ToUniversalTime(NowLocal);

  HasStart := False;
  HasEnd := False;
  StartAt := 0;
  EndAt := 0;

  if Trim(Sch.StartTime) <> '' then
    HasStart := TryISO8601ToDate(Trim(Sch.StartTime), StartAt, True);
  if Trim(Sch.EndTime) <> '' then
    HasEnd := TryISO8601ToDate(Trim(Sch.EndTime), EndAt, True);

  if HasStart and (NowUtc < StartAt) then Exit(False);
  if HasEnd and (NowUtc > EndAt) then Exit(False);

  if Trim(Sch.RecurringPattern) <> '' then
    Exit(MatchesRecurringLocal(Sch.RecurringPattern, NowLocal));

  Result := True;
end;

function TCampaignsFrameV2.SortItemsByDisplayOrder(const AItems: TArray<TCampaignItemData>): TArray<TCampaignItemData>;
begin
  Result := Copy(AItems);
  TArray.Sort<TCampaignItemData>(Result,
    TComparer<TCampaignItemData>.Construct(
      function(const L, R: TCampaignItemData): Integer
      begin
        Result := L.DisplayOrder - R.DisplayOrder;
      end));
end;

end.
