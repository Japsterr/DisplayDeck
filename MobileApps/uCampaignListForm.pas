unit uCampaignListForm;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Layouts,
  FMX.ListBox, FMX.StdCtrls, FMX.Controls.Presentation, FMX.ListView.Types,
  FMX.ListView.Appearances, FMX.ListView.Adapters.Base, FMX.ListView,
  uApiClient, uEntities;

type
  TCampaignListForm = class(TForm)
    Layout: TLayout;
    CampaignListView: TListView;
    TopLayout: TLayout;
    RefreshButton: TButton;
    AddButton: TButton;
    procedure FormCreate(Sender: TObject);
    procedure RefreshButtonClick(Sender: TObject);
    procedure AddButtonClick(Sender: TObject);
    procedure CampaignListViewItemClick(const Sender: TObject;
      const AItem: TListViewItem);
  private
    FApiClient: TApiClient;
    procedure LoadCampaigns;
    procedure HandleApiError(const ErrorMessage: string);
    procedure ShowCampaignDetails(Campaign: TCampaign);
  public
    { Public declarations }
  end;

var
  CampaignListForm: TCampaignListForm;

implementation

{$R *.fmx}

procedure TCampaignListForm.FormCreate(Sender: TObject);
begin
  FApiClient := TApiClient.Instance;
  LoadCampaigns;
end;

procedure TCampaignListForm.RefreshButtonClick(Sender: TObject);
begin
  LoadCampaigns;
end;

procedure TCampaignListForm.AddButtonClick(Sender: TObject);
begin
  // TODO: Show campaign creation dialog
  ShowMessage('Campaign creation not yet implemented');
end;

procedure TCampaignListForm.CampaignListViewItemClick(const Sender: TObject;
  const AItem: TListViewItem);
begin
  // TODO: Show campaign details/edit form
  ShowMessage('Campaign details not yet implemented');
end;

procedure TCampaignListForm.LoadCampaigns;
var
  Response: TCampaignListResponse;
  Campaign: TCampaign;
  ListItem: TListViewItem;
begin
  CampaignListView.ClearItems;

  try
    Response := FApiClient.GetCampaigns;
    try
      if Response.Success then
      begin
        for Campaign in Response.Campaigns do
        begin
          ListItem := CampaignListView.Items.Add;
          ListItem.Text := Campaign.Name;
          ListItem.Detail := Campaign.Description;
          ListItem.Tag := Campaign.Id; // Store campaign ID for later use
        end;
      end
      else
      begin
        HandleApiError('Failed to load campaigns: ' + Response.Message);
      end;
    finally
      Response.Free;
    end;
  except
    on E: Exception do
      HandleApiError('Error loading campaigns: ' + E.Message);
  end;
end;

procedure TCampaignListForm.HandleApiError(const ErrorMessage: string);
begin
  ShowMessage(ErrorMessage);
end;

procedure TCampaignListForm.ShowCampaignDetails(Campaign: TCampaign);
begin
  // TODO: Implement campaign details view
end;

end.