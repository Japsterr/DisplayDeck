unit DashboardFrame;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants, 
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  FMX.Edit, FMX.Controls.Presentation, FMX.Objects, FMX.Layouts;

type
  // Event types for navigation
  TNavigateToSectionEvent = procedure(const SectionTag: Integer) of object;

  TFrame3 = class(TFrame)
    LayoutBackground: TLayout;
    LayoutMain: TLayout;
    VertScrollBox1: TVertScrollBox;
    LayoutHeader: TLayout;
    lblWelcome: TLabel;
    LayoutSpacer1: TLayout;
    LayoutStatsRow: TLayout;
    RectCardDisplays: TRectangle;
    LayoutCardContent1: TLayout;
    lblDisplaysTitle: TLabel;
    lblDisplaysCount: TLabel;
    lblDisplaysStatus: TLabel;
    RectCardCampaigns: TRectangle;
    LayoutCardContent2: TLayout;
    lblCampaignsTitle: TLabel;
    lblCampaignsCount: TLabel;
    lblCampaignsStatus: TLabel;
    RectCardMedia: TRectangle;
    LayoutCardContent3: TLayout;
    lblMediaTitle: TLabel;
    lblMediaCount: TLabel;
    lblMediaStatus: TLabel;
    LayoutSpacer2: TLayout;
    LayoutQuickActions: TLayout;
    RectQuickActions: TRectangle;
    LayoutActionsContent: TLayout;
    lblQuickActions: TLabel;
    LayoutButtons: TLayout;
    btnAddDisplay: TButton;
    btnCreateCampaign: TButton;
    btnUploadMedia: TButton;
    LayoutBottom: TLayout;
    RectBackground: TRectangle;
    procedure btnAddDisplayClick(Sender: TObject);
    procedure btnCreateCampaignClick(Sender: TObject);
    procedure btnUploadMediaClick(Sender: TObject);
  private
    FUserName: string;
    FOnNavigateToSection: TNavigateToSectionEvent;
    procedure LoadDashboardData;
    procedure UpdateDisplayStats(TotalCount, OnlineCount, OfflineCount: Integer);
    procedure UpdateCampaignStats(ActiveCount: Integer);
    procedure UpdateMediaStats(TotalFiles: Integer; TotalSizeMB: Double);
  public
    procedure Initialize(const UserName: string);
    property OnNavigateToSection: TNavigateToSectionEvent read FOnNavigateToSection write FOnNavigateToSection;
  end;

implementation

{$R *.fmx}

{ TFrame3 }

procedure TFrame3.Initialize(const UserName: string);
begin
  FUserName := UserName;
  lblWelcome.Text := 'Welcome back, ' + UserName + '!';
  LoadDashboardData;
end;

procedure TFrame3.LoadDashboardData;
begin
  // TODO: Replace with actual API calls when uApiClient is implemented
  // For now, show sample data
  UpdateDisplayStats(0, 0, 0);
  UpdateCampaignStats(0);
  UpdateMediaStats(0, 0);
end;

procedure TFrame3.UpdateDisplayStats(TotalCount, OnlineCount, OfflineCount: Integer);
begin
  lblDisplaysCount.Text := IntToStr(TotalCount);
  lblDisplaysStatus.Text := IntToStr(OnlineCount) + ' Online • ' + IntToStr(OfflineCount) + ' Offline';
end;

procedure TFrame3.UpdateCampaignStats(ActiveCount: Integer);
begin
  lblCampaignsCount.Text := IntToStr(ActiveCount);
  lblCampaignsStatus.Text := 'Total campaigns';
end;

procedure TFrame3.UpdateMediaStats(TotalFiles: Integer; TotalSizeMB: Double);
begin
  lblMediaCount.Text := IntToStr(TotalFiles);
  lblMediaStatus.Text := FormatFloat('0.0', TotalSizeMB) + ' MB used';
end;

procedure TFrame3.btnAddDisplayClick(Sender: TObject);
begin
  // Navigate to Displays section (Tag = 3)
  if Assigned(FOnNavigateToSection) then
    FOnNavigateToSection(3);
end;

procedure TFrame3.btnCreateCampaignClick(Sender: TObject);
begin
  // Navigate to Campaigns section (Tag = 4)
  if Assigned(FOnNavigateToSection) then
    FOnNavigateToSection(4);
end;

procedure TFrame3.btnUploadMediaClick(Sender: TObject);
begin
  // Navigate to Media Library section (Tag = 5)
  if Assigned(FOnNavigateToSection) then
    FOnNavigateToSection(5);
end;

end.
