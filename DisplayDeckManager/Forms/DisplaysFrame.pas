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
    procedure btnAddDisplayClick(Sender: TObject);
    procedure ListView1ItemClick(const Sender: TObject; const AItem: TListViewItem);
    procedure btnSaveClick(Sender: TObject);
    procedure btnDeleteClick(Sender: TObject);
    procedure cboOrientationChange(Sender: TObject);
  private
    FDisplays: array of TLocalDisplayData;
    FSelectedDisplayId: Integer;
    FIsNewDisplay: Boolean;
    FOrganizationId: Integer;
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
  public
    procedure Initialize(AOrganizationId: Integer);
  end;

implementation

{$R *.fmx}

uses
  System.DateUtils;

{ TFrame5 }

procedure TFrame5.Initialize(AOrganizationId: Integer);
begin
  FOrganizationId := AOrganizationId;
  PopulateOrientationCombo;
  ClearDisplayDetails;
  EnableDetailPanel(False);
  LoadDisplays;
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
      ShowMessage('Error loading displays: ' + E.Message);
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
end;

procedure TFrame5.EnableDetailPanel(AEnabled: Boolean);
begin
  edtName.Enabled := AEnabled;
  cboOrientation.Enabled := AEnabled;
  btnSave.Enabled := AEnabled;
  btnDelete.Enabled := AEnabled and not FIsNewDisplay;
end;

procedure TFrame5.btnAddDisplayClick(Sender: TObject);
begin
  FIsNewDisplay := True;
  FSelectedDisplayId := 0;
  ClearDisplayDetails;
  lblDetailTitle.Text := 'New Display';
  EnableDetailPanel(True);
  btnDelete.Visible := False;
  edtName.SetFocus;
end;

function TFrame5.ValidateDisplayData: Boolean;
begin
  Result := False;
  
  if Trim(edtName.Text) = '' then
  begin
    ShowMessage('Please enter a display name.');
    edtName.SetFocus;
    Exit;
  end;
  
  if cboOrientation.ItemIndex < 0 then
  begin
    ShowMessage('Please select an orientation.');
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
      
      ShowMessage('Display "' + DisplayData.Name + '" created successfully');
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
      
      ShowMessage('Display "' + DisplayData.Name + '" updated successfully');
      LoadDisplays;
      EnableDetailPanel(False);
      ClearDisplayDetails;
    end;
  except
    on E: Exception do
      ShowMessage('Error saving display: ' + E.Message);
  end;
end;

procedure TFrame5.btnDeleteClick(Sender: TObject);
begin
  if FIsNewDisplay then Exit;
  
  if MessageDlg('Are you sure you want to delete this display?', 
                TMsgDlgType.mtConfirmation, 
                [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], 0) = mrYes then
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
      ShowMessage('Display "' + FDisplays[Index].Name + '" deleted successfully');
      LoadDisplays;
      EnableDetailPanel(False);
      ClearDisplayDetails;
    end
    else
      ShowMessage('Failed to delete display');
  except
    on E: Exception do
      ShowMessage('Error deleting display: ' + E.Message);
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
