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
  System.JSON, uApiClient, System.DateUtils, uTheme;

// API Base: http://localhost:2001/api
// Note: This frame currently derives simple stats by calling the existing list endpoints
// (displays/campaigns) rather than the dedicated analytics endpoints.

procedure TFrame8.Initialize(AOrganizationId: Integer);
begin
  FOrganizationId := AOrganizationId;
  LoadAnalytics;
  
  // Theme styling
  StyleBackground(RectBackground);
  StyleCard(RectStatCard1);
  StyleCard(RectStatCard2);
  StyleCard(RectStatCard3);
  StyleCard(RectChartCard);
  
  StyleHeaderLabel(lblTitle);
  StyleSubHeaderLabel(lblChartTitle);
  
  StyleMutedLabel(lblStat1Title);
  StyleMutedLabel(lblStat2Title);
  StyleMutedLabel(lblStat3Title);
  
  // Make values pop
  StyleHeaderLabel(lblStat1Value);
  StyleHeaderLabel(lblStat2Value);
  StyleHeaderLabel(lblStat3Value);
  lblStat1Value.TextSettings.FontColor := ColorPrimary;
  lblStat2Value.TextSettings.FontColor := ColorPrimary;
  lblStat3Value.TextSettings.FontColor := ColorPrimary;
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
