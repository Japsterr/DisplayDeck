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
  System.JSON;

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
begin
  // TODO: API call to GET /organizations/{FOrganizationId}/analytics/summary
  // For now, display sample data (already in the FMX)
  
  // Future: Load chart data and render using TChart or custom drawing
  // GET /organizations/{FOrganizationId}/analytics/campaigns
end;

end.
