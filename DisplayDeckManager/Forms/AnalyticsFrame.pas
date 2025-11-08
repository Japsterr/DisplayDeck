unit AnalyticsFrame;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants, 
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.Objects, FMX.Layouts;

type
  TFrame8 = class(TFrame)
    LayoutBackground: TLayout;
    RectBackground: TRectangle;
    LayoutMain: TLayout;
    LayoutHeader: TLayout;
    lblTitle: TLabel;
    LayoutContent: TLayout;
    LayoutStats: TLayout;
    RectStatCard1: TRectangle;
    LayoutStatContent1: TLayout;
    lblStat1Title: TLabel;
    lblStat1Value: TLabel;
    RectStatCard2: TRectangle;
    LayoutStatContent2: TLayout;
    lblStat2Title: TLabel;
    lblStat2Value: TLabel;
    RectStatCard3: TRectangle;
    LayoutStatContent3: TLayout;
    lblStat3Title: TLabel;
    lblStat3Value: TLabel;
    LayoutCharts: TLayout;
    RectChartCard: TRectangle;
    LayoutChartContent: TLayout;
    lblChartTitle: TLabel;
    lblChartPlaceholder: TLabel;
  private
    FOrganizationId: Integer;
    procedure LoadAnalytics;
  public
    procedure Initialize(AOrganizationId: Integer);
  end;

implementation

{$R *.fmx}

uses
  System.JSON, uApiClient, System.DateUtils;

// API Base: http://localhost:2001/tms/xdata
// Endpoints:
//   GET /organizations/{OrgId}/analytics/summary - Get overall statistics
//   GET /organizations/{OrgId}/analytics/campaigns - Get campaign performance data
//   GET /organizations/{OrgId}/analytics/displays - Get display usage statistics
//   GET /organizations/{OrgId}/analytics/media - Get media file analytics

procedure TFrame8.Initialize(AOrganizationId: Integer);
begin
  FOrganizationId := AOrganizationId;
  LoadAnalytics;
end;

procedure TFrame8.LoadAnalytics;
var
  displaysArr: TArray<uApiClient.TDisplayData>;
  campaignsArr: TArray<uApiClient.TCampaignData>;
  land, port: Integer;
  i: Integer;
begin
  try
    // Retrieve displays and campaigns
    displaysArr := TApiClient.Instance.GetDisplays(FOrganizationId);
    campaignsArr := TApiClient.Instance.GetCampaigns(FOrganizationId);
    // Basic summary
    lblStat1Value.Text := IntToStr(Length(displaysArr)); // Total displays
    lblStat1Title.Text := 'Displays';
    lblStat2Value.Text := IntToStr(Length(campaignsArr)); // Active campaigns
    lblStat2Title.Text := 'Active Campaigns';
    lblStat3Value.Text := '—';
    lblStat3Title.Text := 'Avg Play Time';
    lblChartTitle.Text := 'Campaign Performance (count by orientation)';
    // Simple text placeholder using counts
    land := 0; port := 0;
    for i := 0 to Length(campaignsArr) - 1 do
      if SameText(campaignsArr[i].Orientation,'landscape') then Inc(land) else Inc(port);
    lblChartPlaceholder.Text := Format('Landscape: %d   Portrait: %d',[land,port]);
  except
    on E: Exception do
    begin
      lblStat1Value.Text := '0';
      lblStat2Value.Text := '0';
      lblStat3Value.Text := '—';
      lblChartPlaceholder.Text := 'Failed to load analytics: ' + E.Message;
    end;
  end;
end;

end.
