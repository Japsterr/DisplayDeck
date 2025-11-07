unit fMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.TabControl,
  FMX.Controls.Presentation, FMX.ListBox, FMX.Edit, FMX.Layouts;

type
  TMainForm = class(TForm)
    Tabs: TTabControl;
    TabDisplays: TTabItem;
    TabCampaigns: TTabItem;
    TabAccount: TTabItem;
    ListDisplays: TListBox;
    BtnRefreshDisplays: TButton;
    BtnClaimDisplay: TButton;
    EditProvisioningToken: TEdit;
    ListCampaigns: TListBox;
    BtnRefreshCampaigns: TButton;
    BtnAssignCampaign: TButton;
    EditBaseUrl: TEdit;
    BtnSaveBaseUrl: TButton;
    BtnLogout: TButton;
    procedure FormCreate(Sender: TObject);
    procedure BtnRefreshDisplaysClick(Sender: TObject);
    procedure BtnClaimDisplayClick(Sender: TObject);
    procedure BtnRefreshCampaignsClick(Sender: TObject);
    procedure BtnAssignCampaignClick(Sender: TObject);
    procedure BtnScanQRClick(Sender: TObject);
    procedure BtnSaveBaseUrlClick(Sender: TObject);
    procedure BtnLogoutClick(Sender: TObject);
  private
    procedure LoadDisplays;
    procedure LoadCampaigns;
  public
  end;

var
  MainForm: TMainForm;

implementation

{$R *.fmx}

uses uDisplayService, uCampaignService, uAuthService, uModels, uAssignmentService, uAppConfig, fLogin, uApiClient, FMX.Dialogs, FMX.DialogService, FMX.DialogService.Async, FMX.Objects, uTheme
{$IFDEF ANDROID}, Androidapi.Log{$ENDIF};

procedure TMainForm.FormCreate(Sender: TObject);
begin
  {$IFDEF ANDROID} __android_log_write(android_LogPriority.ANDROID_LOG_DEBUG, 'DisplayDeck', 'Main FormCreate'); {$ENDIF}
  Tabs.ActiveTab := TabDisplays;
  // Load current base URL into settings field if present
  if Assigned(EditBaseUrl) then
    EditBaseUrl.Text := TAppConfig.BaseUrl;
  // Apply theme background colors in code to avoid FMX DFM parse issues
  if FindComponent('RectHomeBg') is TRectangle then
    (FindComponent('RectHomeBg') as TRectangle).Fill.Color := THEME_BG;
  if FindComponent('RectCampBg') is TRectangle then
    (FindComponent('RectCampBg') as TRectangle).Fill.Color := THEME_BG;
  if FindComponent('RectMediaBg') is TRectangle then
    (FindComponent('RectMediaBg') as TRectangle).Fill.Color := THEME_BG;
  if FindComponent('RectDevBg') is TRectangle then
    (FindComponent('RectDevBg') as TRectangle).Fill.Color := THEME_BG;
  if FindComponent('RectAccBg') is TRectangle then
    (FindComponent('RectAccBg') as TRectangle).Fill.Color := THEME_BG;
end;

procedure TMainForm.BtnScanQRClick(Sender: TObject);
begin
  // TODO: Integrate QR scanner. For now, this is a placeholder that sets a sample token.
  EditProvisioningToken.Text := 'PROV-PLACEHOLDER-1234';
end;

procedure TMainForm.BtnRefreshDisplaysClick(Sender: TObject);
begin
  LoadDisplays;
end;

procedure TMainForm.BtnSaveBaseUrlClick(Sender: TObject);
begin
  if Assigned(EditBaseUrl) then
  begin
    TAppConfig.SetBaseUrl(EditBaseUrl.Text.Trim);
    TAppConfig.Save;
    // Inform user via platform dialog on UI thread to avoid lifecycle issues
    TThread.ForceQueue(nil,
      procedure
      begin
        TDialogService.PreferredMode := TDialogService.TPreferredMode.Platform;
        TDialogServiceAsync.MessageDialog(
          'Base URL saved. New requests will use the updated address.',
          TMsgDlgType.mtInformation,
          [TMsgDlgBtn.mbOK],
          TMsgDlgBtn.mbOK,
          0,
          procedure(const AResult: TModalResult)
          begin
            // no-op
          end
        );
      end);
  end;
end;

procedure TMainForm.BtnLogoutClick(Sender: TObject);
begin
  {$IFDEF ANDROID} __android_log_write(android_LogPriority.ANDROID_LOG_DEBUG, 'DisplayDeck', 'Main BtnLogoutClick'); {$ENDIF}
  // Simple logout: clear token and go back to login
  ApiClient.SetToken('');
  Application.CreateForm(TLoginForm, LoginForm);
  LoginForm.Show;
  // Do not close the (possibly main) form; hide it to avoid app termination
  Self.Hide;
end;

procedure TMainForm.BtnClaimDisplayClick(Sender: TObject);
var OrgId: Integer;
begin
  OrgId := TAuthService.Instance.CurrentUser.OrganizationId;
  if OrgId = 0 then
    raise Exception.Create('Not authenticated');
  if EditProvisioningToken.Text.Trim = '' then
    raise Exception.Create('Enter ProvisioningToken');
  TDisplayService.Instance.ClaimDisplay(OrgId, EditProvisioningToken.Text.Trim, 'New Display', 'Landscape');
  LoadDisplays;
end;

procedure TMainForm.BtnRefreshCampaignsClick(Sender: TObject);
begin
  LoadCampaigns;
end;

procedure TMainForm.LoadDisplays;
var L: TArray<TDisplay>;
    D: TDisplay;
begin
  ListDisplays.Items.Clear;
  L := TDisplayService.Instance.ListDisplays(TAuthService.Instance.CurrentUser.OrganizationId);
  for D in L do
    ListDisplays.Items.Add(Format('%d: %s (%s)', [D.Id, D.Name, D.Orientation]));
end;

procedure TMainForm.LoadCampaigns;
var L: TArray<TCampaign>;
    C: TCampaign;
begin
  ListCampaigns.Items.Clear;
  L := TCampaignService.Instance.ListCampaigns(TAuthService.Instance.CurrentUser.OrganizationId);
  for C in L do
    ListCampaigns.Items.Add(Format('%d: %s', [C.Id, C.Name]));
end;

procedure TMainForm.BtnAssignCampaignClick(Sender: TObject);
var OrgId, DisplayId, CampaignId: Integer; S: string;
begin
  OrgId := TAuthService.Instance.CurrentUser.OrganizationId;
  if (ListDisplays.ItemIndex < 0) or (ListCampaigns.ItemIndex < 0) then
    raise Exception.Create('Select a display and a campaign first');

  // Parse IDs from list captions like "12: Name"
  S := ListDisplays.ListItems[ListDisplays.ItemIndex].Text;
  DisplayId := StrToIntDef(S.Substring(0, S.IndexOf(':')), 0);
  S := ListCampaigns.ListItems[ListCampaigns.ItemIndex].Text;
  CampaignId := StrToIntDef(S.Substring(0, S.IndexOf(':')), 0);

  if (DisplayId = 0) or (CampaignId = 0) then
    raise Exception.Create('Unable to parse IDs from selection');

  TAssignmentService.Instance.AssignCampaignToDisplay(OrgId, DisplayId, CampaignId);
end;

end.
