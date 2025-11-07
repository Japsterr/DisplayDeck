unit DashboardFrame;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants, 
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  FMX.Edit, FMX.Controls.Presentation, FMX.Objects, FMX.Layouts;

type
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
  private
    { Private declarations }
  public
    { Public declarations }
  end;

implementation

{$R *.fmx}

end.
