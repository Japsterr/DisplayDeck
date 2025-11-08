unit CampaignsFrame;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants, 
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  FMX.Objects, FMX.Layouts, FMX.ListView.Types, FMX.ListView.Appearances,
  FMX.ListView.Adapters.Base, FMX.ListView, FMX.Controls.Presentation, FMX.Edit,
  FMX.ListBox, uApiClient, System.JSON, FMX.DialogService, FMX.DialogService.Sync;

type
  TCampaignData = record
    Id: Integer;
    Name: string;
    Orientation: string;
  end;

  TFrame6 = class(TFrame)
    LayoutBackground: TLayout;
    RectBackground: TRectangle;
    LayoutMain: TLayout;
    LayoutHeader: TLayout;
    lblTitle: TLabel;
    btnAddCampaign: TButton;
    LayoutContent: TLayout;
    LayoutListView: TLayout;
    RectListCard: TRectangle;
    ListView1: TListView;
    LayoutDetailPanel: TLayout;
    RectDetailCard: TRectangle;
    LayoutDetailContent: TLayout;
    lblDetailTitle: TLabel;
    VertScrollBox1: TVertScrollBox;
    LayoutFormContent: TLayout;
    lblNameLabel: TLabel;
    edtName: TEdit;
    LayoutSpacer1: TLayout;
    lblOrientationLabel: TLabel;
    cboOrientation: TComboBox;
    LayoutSpacer2: TLayout;
    LayoutButtons: TLayout;
    btnSave: TButton;
    LayoutSpacer3: TLayout;
    btnManageMedia: TButton;
    LayoutSpacer4: TLayout;
    btnAssignDisplays: TButton;
    LayoutSpacer5: TLayout;
    btnDelete: TButton;
    procedure btnAddCampaignClick(Sender: TObject);
    procedure ListView1ItemClick(const Sender: TObject; const AItem: TListViewItem);
    procedure btnSaveClick(Sender: TObject);
    procedure btnDeleteClick(Sender: TObject);
    procedure btnManageMediaClick(Sender: TObject);
    procedure btnAssignDisplaysClick(Sender: TObject);
  private
    FCampaigns: array of TCampaignData;
    FSelectedCampaignId: Integer;
    FIsNew: Boolean;
    FOrganizationId: Integer;
    procedure LoadCampaigns;
    procedure ShowDetails(const Campaign: TCampaignData);
    procedure ClearDetails;
    procedure EnableDetailPanel(AEnabled: Boolean);
  public
    procedure Initialize(AOrganizationId: Integer);
  end;

implementation

{$R *.fmx}

{ TFrame6 }

procedure TFrame6.Initialize(AOrganizationId: Integer);
begin
  FOrganizationId := AOrganizationId;
  cboOrientation.Items.Clear;
  cboOrientation.Items.Add('Portrait');
  cboOrientation.Items.Add('Landscape');
  cboOrientation.ItemIndex := 0;
  ClearDetails;
  EnableDetailPanel(False);
  LoadCampaigns;
end;

procedure TFrame6.LoadCampaigns;
var
  Item: TListViewItem;
  I: Integer;
  ApiCampaigns: TArray<uApiClient.TCampaignData>;
begin
  ListView1.Items.Clear;
  
  try
    // Call API to get campaigns
    ApiCampaigns := TApiClient.Instance.GetCampaigns(FOrganizationId);
    
    SetLength(FCampaigns, Length(ApiCampaigns));
    
    for I := 0 to High(ApiCampaigns) do
    begin
      FCampaigns[I].Id := ApiCampaigns[I].Id;
      FCampaigns[I].Name := ApiCampaigns[I].Name;
      FCampaigns[I].Orientation := ApiCampaigns[I].Orientation;
      
      Item := ListView1.Items.Add;
      Item.Text := FCampaigns[I].Name;
      Item.Detail := FCampaigns[I].Orientation;
      Item.Tag := FCampaigns[I].Id;
    end;
  except
    on E: Exception do
      ShowMessage('Error loading campaigns: ' + E.Message);
  end;
end;

procedure TFrame6.ListView1ItemClick(const Sender: TObject; const AItem: TListViewItem);
var
  CampaignId: Integer;
  I: Integer;
begin
  if AItem = nil then Exit;
  
  CampaignId := AItem.Tag;
  for I := 0 to High(FCampaigns) do
  begin
    if FCampaigns[I].Id = CampaignId then
    begin
      FSelectedCampaignId := CampaignId;
      FIsNew := False;
      ShowDetails(FCampaigns[I]);
      EnableDetailPanel(True);
      Break;
    end;
  end;
end;

procedure TFrame6.ShowDetails(const Campaign: TCampaignData);
begin
  lblDetailTitle.Text := 'Campaign Details';
  edtName.Text := Campaign.Name;
  
  if SameText(Campaign.Orientation, 'Portrait') then
    cboOrientation.ItemIndex := 0
  else
    cboOrientation.ItemIndex := 1;
  
  btnDelete.Visible := True;
  btnManageMedia.Enabled := True;
  btnAssignDisplays.Enabled := True;
end;

procedure TFrame6.ClearDetails;
begin
  lblDetailTitle.Text := 'Campaign Details';
  edtName.Text := '';
  cboOrientation.ItemIndex := 0;
  btnDelete.Visible := False;
  btnManageMedia.Enabled := False;
  btnAssignDisplays.Enabled := False;
end;

procedure TFrame6.EnableDetailPanel(AEnabled: Boolean);
begin
  edtName.Enabled := AEnabled;
  cboOrientation.Enabled := AEnabled;
  btnSave.Enabled := AEnabled;
end;

procedure TFrame6.btnAddCampaignClick(Sender: TObject);
begin
  FIsNew := True;
  FSelectedCampaignId := 0;
  ClearDetails;
  lblDetailTitle.Text := 'New Campaign';
  EnableDetailPanel(True);
  edtName.SetFocus;
end;

procedure TFrame6.btnSaveClick(Sender: TObject);
var
  Orientation: string;
  ResultCampaign: uApiClient.TCampaignData;
  ApiCampaign: uApiClient.TCampaignData;
begin
  if Trim(edtName.Text) = '' then
  begin
    TDialogService.ShowMessage('Please enter a campaign name.');
    Exit;
  end;
  
  if cboOrientation.ItemIndex = 0 then
    Orientation := 'Portrait'
  else
    Orientation := 'Landscape';
  
  try
    if FIsNew then
    begin
      // Create new campaign
      ResultCampaign := TApiClient.Instance.CreateCampaign(FOrganizationId, edtName.Text, Orientation);
      
      // Check if creation was successful
      if ResultCampaign.Id > 0 then
      begin
        TDialogService.ShowMessage('Campaign "' + edtName.Text + '" created successfully');
        LoadCampaigns;
        ClearDetails;
        EnableDetailPanel(False);
      end
      else
      begin
          TDialogService.ShowMessage('Failed to create campaign. Please check server logs.' + #13#10 +
              'URL: ' + TApiClient.Instance.LastURL + #13#10 +
              'Status: ' + IntToStr(TApiClient.Instance.LastResponseCode) + #13#10 +
              'Token: ' + Copy(TApiClient.Instance.GetAuthToken, 1, 20) + '...' + #13#10 +
              'OrgId: ' + IntToStr(FOrganizationId) + #13#10 +
              'Debug: ' + TApiClient.Instance.LastResponseBody);
      end;
    end
    else
    begin
      // Update existing campaign
      ApiCampaign.Id := FSelectedCampaignId;
      ApiCampaign.Name := edtName.Text;
      ApiCampaign.Orientation := Orientation;
      
      ResultCampaign := TApiClient.Instance.UpdateCampaign(ApiCampaign);
      
      if ResultCampaign.Id > 0 then
      begin
        TDialogService.ShowMessage('Campaign "' + edtName.Text + '" updated successfully');
        LoadCampaigns;
        ClearDetails;
        EnableDetailPanel(False);
      end
      else
      begin
        TDialogService.ShowMessage('Failed to update campaign.');
      end;
    end;
  except
    on E: Exception do
      TDialogService.ShowMessage('Error saving campaign: ' + E.Message + #13#10 +
                  'URL: ' + TApiClient.Instance.LastURL + #13#10 +
                  'Response: ' + TApiClient.Instance.LastResponseBody);
  end;
end;

procedure TFrame6.btnManageMediaClick(Sender: TObject);
begin
  // TODO: Show dialog to manage campaign items
  // API: GET/POST/PUT/DELETE /campaigns/{CampaignId}/items
  // Each item links MediaFileId with DisplayOrder and Duration
  TDialogService.ShowMessage('Manage media items for this campaign (dialog to be implemented)');
end;

procedure TFrame6.btnAssignDisplaysClick(Sender: TObject);
begin
  // TODO: Show dialog to assign campaign to displays
  // API: POST /displays/{DisplayId}/campaign-assignments
  //   Body: { "DisplayId", "CampaignId", "IsPrimary": true/false }
  // Note: Only displays with matching orientation can be assigned
  TDialogService.ShowMessage('Assign campaign to displays (dialog to be implemented)');
end;

procedure TFrame6.btnDeleteClick(Sender: TObject);
var
  Success: Boolean;
begin
  if FIsNew then Exit;
  
    if TDialogServiceSync.MessageDialog('Delete this campaign?', TMsgDlgType.mtConfirmation, 
      [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], TMsgDlgBtn.mbNo, 0) = mrYes then
  begin
    try
      Success := TApiClient.Instance.DeleteCampaign(FSelectedCampaignId);
      
      if Success then
      begin
        TDialogService.ShowMessage('Campaign deleted successfully');
        LoadCampaigns;
        ClearDetails;
        EnableDetailPanel(False);
      end
      else
        TDialogService.ShowMessage('Failed to delete campaign');
    except
      on E: Exception do
        TDialogService.ShowMessage('Error deleting campaign: ' + E.Message);
    end;
  end;
end;

end.
