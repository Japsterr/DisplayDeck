unit DashboardFrame;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants, 
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  FMX.Edit, FMX.Controls.Presentation, FMX.Objects, FMX.Layouts, FMX.ListBox,
  FMX.Effects, System.IOUtils, uApiClient;

type
  TNavigateToSectionEvent = procedure(const SectionTag: Integer) of object;

  TDashboardFrame = class(TFrame)
    VertScrollBox1: TVertScrollBox;
    LayoutHeader: TLayout;
    lblWelcome: TLabel;
    btnRefresh: TButton;
    LayoutStats: TGridPanelLayout;
    CardDisplays: TRectangle;
    ShadowEffect1: TShadowEffect;
    lblStatDisplays: TLabel;
    lblTitleDisplays: TLabel;
    CardCampaigns: TRectangle;
    ShadowEffect2: TShadowEffect;
    lblStatCampaigns: TLabel;
    lblTitleCampaigns: TLabel;
    CardMedia: TRectangle;
    ShadowEffect3: TShadowEffect;
    lblStatMedia: TLabel;
    lblTitleMedia: TLabel;
    LayoutPairing: TLayout;
    CardPairing: TRectangle;
    ShadowEffect4: TShadowEffect;
    lblPairingHeader: TLabel;
    LayoutPairingInputs: TLayout;
    edtPairingToken: TEdit;
    edtDisplayTitle: TEdit;
    cbOrientation: TComboBox;
    btnClaimDisplay: TButton;
    LayoutQuickActions: TLayout;
    lblQuickActions: TLabel;
    GridQuickActions: TGridPanelLayout;
    btnQuickAddDisplay: TButton;
    btnQuickCreateCampaign: TButton;
    btnQuickUploadMedia: TButton;
    procedure btnRefreshClick(Sender: TObject);
    procedure btnClaimDisplayClick(Sender: TObject);
    procedure btnQuickAddDisplayClick(Sender: TObject);
    procedure btnQuickCreateCampaignClick(Sender: TObject);
    procedure btnQuickUploadMediaClick(Sender: TObject);
  private
    FUserName: string;
    FOrgId: Integer;
    FOnNavigateToSection: TNavigateToSectionEvent;
    procedure LoadDashboardData;
  public
    procedure Initialize(const UserName: string; OrgId: Integer);
    property OnNavigateToSection: TNavigateToSectionEvent read FOnNavigateToSection write FOnNavigateToSection;
  end;

implementation

{$R *.fmx}

{ TDashboardFrame }

procedure TDashboardFrame.Initialize(const UserName: string; OrgId: Integer);
begin
  FUserName := UserName;
  FOrgId := OrgId;
  lblWelcome.Text := 'Welcome back, ' + UserName + '!';
  LoadDashboardData;
end;

procedure TDashboardFrame.LoadDashboardData;
begin
  // Run in background thread to avoid blocking UI
  TThread.CreateAnonymousThread(procedure
    var
      Displays: TArray<TDisplayData>;
      Campaigns: TArray<TCampaignData>;
      MediaFiles: TArray<TMediaFileData>;
      OrgId: Integer;
    begin
      OrgId := FOrgId;
      if OrgId = 0 then OrgId := 1; // Fallback

      try
        Displays := TApiClient.Instance.GetDisplays(OrgId);
        Campaigns := TApiClient.Instance.GetCampaigns(OrgId);
        MediaFiles := TApiClient.Instance.GetMediaFiles(OrgId);
        
        TThread.Synchronize(nil, procedure
          begin
            lblStatDisplays.Text := IntToStr(Length(Displays));
            lblStatCampaigns.Text := IntToStr(Length(Campaigns));
            lblStatMedia.Text := IntToStr(Length(MediaFiles));
          end);
      except
        // Handle errors or just leave as 0
      end;
    end).Start;
end;

procedure TDashboardFrame.btnClaimDisplayClick(Sender: TObject);
var
  Token, Name, Orientation: string;
  OrgId: Integer;
begin
  Token := edtPairingToken.Text.Trim;
  Name := edtDisplayTitle.Text.Trim;
  Orientation := cbOrientation.Items[cbOrientation.ItemIndex];
  OrgId := FOrgId;
  if OrgId = 0 then OrgId := 1;

  if Token = '' then
  begin
    ShowMessage('Please enter a provisioning token.');
    Exit;
  end;

  if Name = '' then
  begin
    ShowMessage('Please enter a display name.');
    Exit;
  end;

  btnClaimDisplay.Enabled := False;
  TThread.CreateAnonymousThread(procedure
    var
      NewDisplay: TDisplayData;
      ErrorMsg: string;
    begin
      try
        NewDisplay := TApiClient.Instance.ClaimDisplay(OrgId, Token, Name, Orientation);
        if NewDisplay.Id > 0 then
        begin
          TThread.Synchronize(nil, procedure
            begin
              ShowMessage('Display paired successfully!');
              edtPairingToken.Text := '';
              edtDisplayTitle.Text := '';
              LoadDashboardData; // Refresh stats
            end);
        end
        else
        begin
           // If ID is 0, it failed, but ClaimDisplay might not return error message easily in the record.
           // We might need to check TApiClient.LastResponseBody or similar if we want details.
           TThread.Synchronize(nil, procedure
            begin
              ShowMessage('Failed to pair display. Please check the token and try again.');
            end);
        end;
      except
        on E: Exception do
        begin
          ErrorMsg := E.Message;
          TThread.Synchronize(nil, procedure
            begin
              ShowMessage('Error: ' + ErrorMsg);
            end);
        end;
      end;
      TThread.Synchronize(nil, procedure
        begin
          btnClaimDisplay.Enabled := True;
        end);
    end).Start;
end;

procedure TDashboardFrame.btnRefreshClick(Sender: TObject);
begin
  LoadDashboardData;
end;

procedure TDashboardFrame.btnQuickAddDisplayClick(Sender: TObject);
begin
  if Assigned(FOnNavigateToSection) then FOnNavigateToSection(3); // Displays
end;

procedure TDashboardFrame.btnQuickCreateCampaignClick(Sender: TObject);
begin
  if Assigned(FOnNavigateToSection) then FOnNavigateToSection(4); // Campaigns
end;

procedure TDashboardFrame.btnQuickUploadMediaClick(Sender: TObject);
begin
  if Assigned(FOnNavigateToSection) then FOnNavigateToSection(5); // Media
end;

end.
