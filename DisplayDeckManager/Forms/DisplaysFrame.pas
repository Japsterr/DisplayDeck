unit DisplaysFrame;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants, 
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  FMX.Objects, FMX.Layouts, FMX.ListView.Types, FMX.ListView.Appearances,
  FMX.ListView.Adapters.Base, FMX.ListView, FMX.Controls.Presentation, FMX.Edit,
  FMX.ListBox, uApiClient, System.JSON;

type
  // Local display record to hold UI data
  TLocalDisplayData = record
    Id: Integer;
    Name: string;
    Orientation: string;
    LastSeen: TDateTime;
    CurrentStatus: string;
    ProvisioningToken: string;
  end;

  TFrame5 = class(TFrame)
    LayoutBackground: TLayout;
    RectBackground: TRectangle;
    LayoutMain: TLayout;
    LayoutHeader: TLayout;
    lblTitle: TLabel;
    btnAddDisplay: TButton;
    LayoutContent: TLayout;
    LayoutListView: TLayout;
    RectListCard: TRectangle;
    ListView1: TListView;
    LayoutDetailPanel: TLayout;
    RectDetailCard: TRectangle;
    LayoutDetailContent: TLayout;
    lblDetailTitle: TLabel;
    LayoutFormFields: TLayout;
    VertScrollBox1: TVertScrollBox;
    LayoutFormContent: TLayout;
    lblNameLabel: TLabel;
    edtName: TEdit;
    LayoutSpacer1: TLayout;
    lblOrientationLabel: TLabel;
    cboOrientation: TComboBox;
    LayoutSpacer2: TLayout;
    lblStatusLabel: TLabel;
    lblStatusValue: TLabel;
    LayoutSpacer3: TLayout;
    lblLastSeenLabel: TLabel;
    lblLastSeenValue: TLabel;
    LayoutSpacer4: TLayout;
    lblProvisioningLabel: TLabel;
    lblProvisioningValue: TLabel;
    LayoutSpacer5: TLayout;
    LayoutButtons: TLayout;
    btnSave: TButton;
    LayoutSpacer6: TLayout;
    btnDelete: TButton;
    LayoutSpacer7: TLayout;
    lblCurrentPlayingLabel: TLabel;
    lblCurrentPlayingValue: TLabel;
    btnRefreshPlaying: TButton;
    LayoutSpacer8: TLayout;
    btnPairDisplay: TButton;
    btnSetPrimary: TButton;
    procedure btnAddDisplayClick(Sender: TObject); // repurposed as new display creation, pairing via separate button
    procedure ListView1ItemClick(const Sender: TObject; const AItem: TListViewItem);
    procedure btnSaveClick(Sender: TObject);
    procedure btnDeleteClick(Sender: TObject);
    procedure cboOrientationChange(Sender: TObject);
    procedure btnRefreshPlayingClick(Sender: TObject);
    procedure btnPairDisplayClick(Sender: TObject);
    procedure btnSetPrimaryClick(Sender: TObject);
  private
    FDisplays: array of TLocalDisplayData;
    FSelectedDisplayId: Integer;
    FIsNewDisplay: Boolean;
    FOrganizationId: Integer;
    FPlayingTimer: TTimer;
    procedure LoadDisplays;
    procedure PopulateOrientationCombo;
    procedure ShowDisplayDetails(const Display: TLocalDisplayData);
    procedure ClearDisplayDetails;
    procedure EnableDetailPanel(AEnabled: Boolean);
    function ValidateDisplayData: Boolean;
    procedure SaveDisplay;
    procedure DeleteDisplay;
    function GetCurrentDisplayData: TLocalDisplayData;
    function FindDisplayById(AId: Integer): Integer;
    procedure LoadCurrentPlaying(ADisplayId: Integer);
    procedure PairDisplayFlow;
    procedure SetPrimaryCampaignFlow;
    procedure PlayingTimerTick(Sender: TObject);
  public
    procedure Initialize(AOrganizationId: Integer);
  end;

implementation

{$R *.fmx}

uses
  System.DateUtils, FMX.DialogService, FMX.DialogService.Sync, uTheme;

{ TFrame5 }

procedure TFrame5.Initialize(AOrganizationId: Integer);
begin
  FOrganizationId := AOrganizationId;
  PopulateOrientationCombo;
  ClearDisplayDetails;
  EnableDetailPanel(False);
  LoadDisplays;
  // Auto refresh current playing every 20s when a display is selected
  FPlayingTimer := TTimer.Create(Self);
  FPlayingTimer.Interval := 20000; // 20 seconds
  FPlayingTimer.OnTimer := PlayingTimerTick;
  
  // Theme styling
  StyleBackground(RectBackground);
  StyleCard(RectListCard);
  StyleCard(RectDetailCard);
  
  StyleHeaderLabel(lblTitle);
  StyleSubHeaderLabel(lblDetailTitle);
  
  StyleMutedLabel(lblNameLabel);
  StyleMutedLabel(lblOrientationLabel);
  StyleMutedLabel(lblStatusLabel);
  StyleMutedLabel(lblLastSeenLabel);
  StyleMutedLabel(lblProvisioningLabel);
  StyleMutedLabel(lblCurrentPlayingLabel);
  
  StyleInput(edtName);
  
  StylePrimaryButton(btnSave);
  StyleDangerButton(btnDelete);
  StylePrimaryButton(btnPairDisplay);
  StylePrimaryButton(btnSetPrimary);
  StylePrimaryButton(btnRefreshPlaying);
end;

procedure TFrame5.PopulateOrientationCombo;
begin
  cboOrientation.Items.Clear;
  cboOrientation.Items.Add('Portrait');
  cboOrientation.Items.Add('Landscape');
  cboOrientation.ItemIndex := 0;
end;

procedure TFrame5.LoadDisplays;
var
  Item: TListViewItem;
  I: Integer;
  StatusColor: TAlphaColor;
  ApiDisplays: TArray<uApiClient.TDisplayData>;
  LastSeenDate: TDateTime;
begin
  ListView1.Items.Clear;
  
  try
    // Call API to get displays
    ApiDisplays := TApiClient.Instance.GetDisplays(FOrganizationId);
    
    SetLength(FDisplays, Length(ApiDisplays));
    
    for I := 0 to High(ApiDisplays) do
    begin
      // Convert API data to local format
      FDisplays[I].Id := ApiDisplays[I].Id;
      FDisplays[I].Name := ApiDisplays[I].Name;
      FDisplays[I].Orientation := ApiDisplays[I].Orientation;
      FDisplays[I].CurrentStatus := ApiDisplays[I].CurrentStatus;
      FDisplays[I].ProvisioningToken := ApiDisplays[I].ProvisioningToken;
      
      // Convert LastSeen string to TDateTime
      if TryISO8601ToDate(ApiDisplays[I].LastSeen, LastSeenDate) then
        FDisplays[I].LastSeen := LastSeenDate
      else
        FDisplays[I].LastSeen := 0;
      
      // Add to ListView
      Item := ListView1.Items.Add;
      Item.Text := FDisplays[I].Name;
      Item.Detail := Format('%s • %s', [
        FDisplays[I].Orientation,
        FDisplays[I].CurrentStatus
      ]);
      Item.Tag := FDisplays[I].Id;
      
      // Color code by status
      if FDisplays[I].CurrentStatus = 'Online' then
        StatusColor := $FF2ECC71  // Green
      else
        StatusColor := $FFE74C3C; // Red
      
      Item.Objects.TextObject.TextColor := StatusColor;
    end;
  except
    on E: Exception do
      TDialogService.ShowMessage('Error loading displays: ' + E.Message);
  end;
end;

procedure TFrame5.ListView1ItemClick(const Sender: TObject; const AItem: TListViewItem);
var
  DisplayId: Integer;
  Index: Integer;
begin
  if AItem = nil then Exit;
  
  DisplayId := AItem.Tag;
  Index := FindDisplayById(DisplayId);
  
  if Index >= 0 then
  begin
    FSelectedDisplayId := DisplayId;
    FIsNewDisplay := False;
    ShowDisplayDetails(FDisplays[Index]);
    EnableDetailPanel(True);
  end;
end;

procedure TFrame5.ShowDisplayDetails(const Display: TLocalDisplayData);
var
  TimeDiff: Int64;
  TimeStr: string;
begin
  lblDetailTitle.Text := 'Display Details';
  edtName.Text := Display.Name;
  
  // Set orientation
  if SameText(Display.Orientation, 'Portrait') then
    cboOrientation.ItemIndex := 0
  else if SameText(Display.Orientation, 'Landscape') then
    cboOrientation.ItemIndex := 1;
  
  // Status with color
  lblStatusValue.Text := Display.CurrentStatus;
  if SameText(Display.CurrentStatus, 'Online') then
    lblStatusValue.TextSettings.FontColor := $FF4CD964 // Green
  else
    lblStatusValue.TextSettings.FontColor := $FFFF453A; // Red
  
  // Last seen with relative time
  TimeDiff := SecondsBetween(Now, Display.LastSeen);
  if TimeDiff < 60 then
    TimeStr := 'Just now'
  else if TimeDiff < 3600 then
    TimeStr := Format('%d minutes ago', [TimeDiff div 60])
  else if TimeDiff < 86400 then
    TimeStr := Format('%d hours ago', [TimeDiff div 3600])
  else
    TimeStr := FormatDateTime('mmm d "at" h:nn am/pm', Display.LastSeen);
  
  lblLastSeenValue.Text := TimeStr;
  
  // Provisioning token
  if Display.ProvisioningToken <> '' then
    lblProvisioningValue.Text := Display.ProvisioningToken
  else
    lblProvisioningValue.Text := 'Not generated';
  
  btnDelete.Visible := True;
  // Load current playing info asynchronously
  LoadCurrentPlaying(Display.Id);
end;

procedure TFrame5.ClearDisplayDetails;
begin
  lblDetailTitle.Text := 'Display Details';
  edtName.Text := '';
  cboOrientation.ItemIndex := 0;
  lblStatusValue.Text := 'Not registered';
  lblStatusValue.TextSettings.FontColor := $FF95A5A6;
  lblLastSeenValue.Text := 'Never';
  lblProvisioningValue.Text := 'Not generated';
  btnDelete.Visible := False;
  lblCurrentPlayingValue.Text := 'No data';
end;

procedure TFrame5.EnableDetailPanel(AEnabled: Boolean);
begin
  edtName.Enabled := AEnabled;
  cboOrientation.Enabled := AEnabled;
  btnSave.Enabled := AEnabled;
  btnDelete.Enabled := AEnabled and not FIsNewDisplay;
end;

procedure TFrame5.LoadCurrentPlaying(ADisplayId: Integer);
var
  CP: uApiClient.TCurrentPlaying;
begin
  lblCurrentPlayingValue.Text := 'Loading...';
  try
    CP := TApiClient.Instance.GetDisplayCurrentPlaying(ADisplayId);
    if (CP.MediaFileId > 0) then
      lblCurrentPlayingValue.Text := Format('%s (Media %d) started %s', [CP.MediaFileName, CP.MediaFileId, CP.StartedAt])
    else
      lblCurrentPlayingValue.Text := 'Idle';
  except
    on E: Exception do
      lblCurrentPlayingValue.Text := 'Error: ' + E.Message;
  end;
end;

procedure TFrame5.PlayingTimerTick(Sender: TObject);
begin
  if (FSelectedDisplayId > 0) then
    try
      LoadCurrentPlaying(FSelectedDisplayId);
    except
      // silent errors to avoid UI spam
    end;
end;

procedure TFrame5.btnRefreshPlayingClick(Sender: TObject);
begin
  if FSelectedDisplayId > 0 then
    LoadCurrentPlaying(FSelectedDisplayId);
end;

procedure TFrame5.PairDisplayFlow;
var
  Inputs: array of string;
  Token, Name, Orientation: string;
  NewDisp: uApiClient.TDisplayData;
begin
  // Inputs: Token, Optional Name, Orientation
  SetLength(Inputs,3);
  Inputs[0] := '';
  Inputs[1] := '';
  Inputs[2] := 'Portrait';
  // Use DialogService for cross-platform (InputQuery deprecated)
  TDialogService.InputQuery('Pair Display', ['Provisioning Token','Optional Name','Orientation (Portrait/Landscape)'], Inputs,
    procedure(const AResult: TModalResult; const AValues: array of string)
    begin
      if AResult <> mrOk then Exit;
      Token := Trim(AValues[0]);
      Name := Trim(AValues[1]);
      if Token = '' then
      begin
        TDialogService.ShowMessage('Token is required');
        Exit;
      end;
      Orientation := Trim(AValues[2]);
      if (Orientation = '') then Orientation := 'Portrait';
      if not SameText(Orientation,'Portrait') and not SameText(Orientation,'Landscape') then
      begin
        TDialogService.ShowMessage('Orientation must be Portrait or Landscape');
        Exit;
      end;
      try
        NewDisp := TApiClient.Instance.ClaimDisplay(FOrganizationId, Token, Name, Orientation);
        if NewDisp.Id > 0 then
        begin
          TDialogService.ShowMessage('Display paired successfully');
          LoadDisplays;
        end
        else
          TDialogService.ShowMessage('Pairing failed');
      except
        on E: Exception do
          TDialogService.ShowMessage('Error pairing: ' + E.Message);
      end;
    end);
end;

procedure TFrame5.btnPairDisplayClick(Sender: TObject);
begin
  PairDisplayFlow;
end;

procedure TFrame5.SetPrimaryCampaignFlow;
var
  Inputs: array of string;
  CampaignId: Integer;
  Success: Boolean;
  Campaigns: TArray<uApiClient.TCampaignData>;
  ListStr: string;
begin
  if FSelectedDisplayId <= 0 then Exit;
  SetLength(Inputs,1);
  Inputs[0] := '';
  // Build helper list of campaigns for user reference
  try
    Campaigns := TApiClient.Instance.GetCampaigns(FOrganizationId);
    if Length(Campaigns) > 0 then
    begin
      for var C in Campaigns do
        ListStr := ListStr + Format('%d=%s; ', [C.Id, C.Name]);
      ListStr := Trim(ListStr);
    end
    else
      ListStr := 'None available';
  except
    on E: Exception do ListStr := 'Error loading campaigns: ' + E.Message;
  end;
  TDialogService.InputQuery('Set Primary Campaign', ['Campaign Id (Available: '+ListStr+')'], Inputs,
    procedure(const AResult: TModalResult; const AValues: array of string)
    begin
      if AResult <> mrOk then Exit;
      CampaignId := StrToIntDef(Trim(AValues[0]),0);
      if CampaignId=0 then
      begin
        TDialogService.ShowMessage('Invalid Campaign Id');
        Exit;
      end;
      try
        Success := TApiClient.Instance.SetDisplayPrimary(FSelectedDisplayId, CampaignId);
        if Success then
          TDialogService.ShowMessage('Primary campaign updated')
        else
          TDialogService.ShowMessage('Failed to update primary campaign');
      except
        on E: Exception do
          TDialogService.ShowMessage('Error setting primary: ' + E.Message);
      end;
    end);
end;

procedure TFrame5.btnSetPrimaryClick(Sender: TObject);
begin
  SetPrimaryCampaignFlow;
end;

procedure TFrame5.btnAddDisplayClick(Sender: TObject);
begin
  // Pairing-first flow: prompt for token (and optional name) instead of manual creation
  PairDisplayFlow;
end;

function TFrame5.ValidateDisplayData: Boolean;
begin
  Result := False;
  
  if Trim(edtName.Text) = '' then
  begin
    TDialogService.ShowMessage('Please enter a display name.');
    edtName.SetFocus;
    Exit;
  end;
  
  if cboOrientation.ItemIndex < 0 then
  begin
    TDialogService.ShowMessage('Please select an orientation.');
    Exit;
  end;
  
  Result := True;
end;

function TFrame5.GetCurrentDisplayData: TLocalDisplayData;
begin
  Result.Name := Trim(edtName.Text);
  
  if cboOrientation.ItemIndex = 0 then
    Result.Orientation := 'Portrait'
  else
    Result.Orientation := 'Landscape';
  
  if FIsNewDisplay then
  begin
    Result.Id := 0; // Will be assigned by server
    Result.CurrentStatus := 'Offline';
    Result.LastSeen := 0;
    Result.ProvisioningToken := '';
  end
  else
  begin
    Result.Id := FSelectedDisplayId;
    // Keep existing values
    var Index := FindDisplayById(FSelectedDisplayId);
    if Index >= 0 then
    begin
      Result.CurrentStatus := FDisplays[Index].CurrentStatus;
      Result.LastSeen := FDisplays[Index].LastSeen;
      Result.ProvisioningToken := FDisplays[Index].ProvisioningToken;
    end;
  end;
end;

procedure TFrame5.btnSaveClick(Sender: TObject);
begin
  if not ValidateDisplayData then Exit;
  
  SaveDisplay;
end;

procedure TFrame5.SaveDisplay;
var
  DisplayData: TLocalDisplayData;
  ApiDisplay: uApiClient.TDisplayData;
  ResultDisplay: uApiClient.TDisplayData;
begin
  DisplayData := GetCurrentDisplayData;
  
  try
    if FIsNewDisplay then
    begin
      // Create new display
      ResultDisplay := TApiClient.Instance.CreateDisplay(
        FOrganizationId,
        DisplayData.Name,
        DisplayData.Orientation
      );
      
      TDialogService.ShowMessage('Display "' + DisplayData.Name + '" created successfully');
      LoadDisplays;
      EnableDetailPanel(False);
      ClearDisplayDetails;
    end
    else
    begin
      // Update existing display - prepare ApiDisplay record
      ApiDisplay.Id := DisplayData.Id;
      ApiDisplay.Name := DisplayData.Name;
      ApiDisplay.Orientation := DisplayData.Orientation;
      ApiDisplay.CurrentStatus := DisplayData.CurrentStatus;
      ApiDisplay.ProvisioningToken := DisplayData.ProvisioningToken;
      ApiDisplay.LastSeen := DateToISO8601(DisplayData.LastSeen);
      
      ResultDisplay := TApiClient.Instance.UpdateDisplay(ApiDisplay);
      
      TDialogService.ShowMessage('Display "' + DisplayData.Name + '" updated successfully');
      LoadDisplays;
      EnableDetailPanel(False);
      ClearDisplayDetails;
    end;
  except
    on E: Exception do
      TDialogService.ShowMessage('Error saving display: ' + E.Message);
  end;
end;

procedure TFrame5.btnDeleteClick(Sender: TObject);
begin
  if FIsNewDisplay then Exit;
  
  if TDialogServiceSync.MessageDialog('Are you sure you want to delete this display?', 
                TMsgDlgType.mtConfirmation, 
                [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], TMsgDlgBtn.mbNo, 0) = mrYes then
  begin
    DeleteDisplay;
  end;
end;

procedure TFrame5.DeleteDisplay;
var
  Index: Integer;
  Success: Boolean;
begin
  Index := FindDisplayById(FSelectedDisplayId);
  if Index < 0 then Exit;
  
  try
    Success := TApiClient.Instance.DeleteDisplay(FSelectedDisplayId);
    
    if Success then
    begin
      TDialogService.ShowMessage('Display "' + FDisplays[Index].Name + '" deleted successfully');
      LoadDisplays;
      EnableDetailPanel(False);
      ClearDisplayDetails;
    end
    else
      TDialogService.ShowMessage('Failed to delete display');
  except
    on E: Exception do
      TDialogService.ShowMessage('Error deleting display: ' + E.Message);
  end;
end;

function TFrame5.FindDisplayById(AId: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(FDisplays) do
  begin
    if FDisplays[I].Id = AId then
    begin
      Result := I;
      Break;
    end;
  end;
end;

procedure TFrame5.cboOrientationChange(Sender: TObject);
begin
  // Can add preview or validation logic here if needed
end;

end.
