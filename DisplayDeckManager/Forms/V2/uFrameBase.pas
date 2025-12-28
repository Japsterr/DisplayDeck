unit uFrameBase;

interface

uses
  System.SysUtils, System.Classes, System.Types,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Layouts,
  FMX.Objects, FMX.StdCtrls, FMX.ScrollBox;

type
  TFrameBase = class(TFrame)
  private
    FRoot: TLayout;
    FBg: TRectangle;
    FHeaderTitle: TLabel;
    FHeaderRight: TLayout;
    FBodyHost: TLayout;
    FMainScroll: TVertScrollBox;
    FMainContent: TLayout;

    FInspectorCard: TRectangle;
    FInspectorHeader: TLayout;
    FInspectorTitle: TLabel;
    FInspectorScroll: TVertScrollBox;
    FInspectorContent: TLayout;

    FDrawerScrim: TRectangle;
    FInspectorAsDrawer: Boolean;

    FOverlay: TRectangle;
    FOverlayLabel: TLabel;
    procedure ApplyTheme;
    procedure DrawerScrimClick(Sender: TObject);
  protected
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure SetTitle(const ATitle: string);
    function HeaderRight: TLayout;
    function BodyContent: TLayout;
    function InspectorContent: TLayout;
    procedure SetInspectorAsDrawer(const ADrawer: Boolean);
    procedure SetInspectorVisible(const AVisible: Boolean; const ATitle: string = '');
    procedure SetInspectorWidth(const AWidth: Single);

    procedure ShowLoading(const AMessage: string = 'Loading...');
    procedure ShowError(const AMessage: string);
    procedure HideOverlay;
  end;

implementation

uses
  uTheme;

constructor TFrameBase.Create(AOwner: TComponent);
var
  Root: TLayout;
  Header: TLayout;
  HeaderLeft: TLayout;
  ThemeCb: TProc;
begin
  inherited;
  Align := TAlignLayout.Client;

  Root := TLayout.Create(Self);
  Root.Parent := Self;
  Root.Align := TAlignLayout.Client;
  FRoot := Root;

  // Background
  FBg := TRectangle.Create(Self);
  FBg.Parent := Root;
  FBg.Align := TAlignLayout.Contents;
  FBg.HitTest := False;
  StyleBackground(FBg);
  FBg.SendToBack;

  // Drawer scrim (used only when Inspector is acting as a drawer)
  FDrawerScrim := TRectangle.Create(Self);
  FDrawerScrim.Parent := Root;
  FDrawerScrim.Align := TAlignLayout.Contents;
  FDrawerScrim.Fill.Kind := TBrushKind.Solid;
  FDrawerScrim.Fill.Color := $66000000;
  FDrawerScrim.Stroke.Kind := TBrushKind.None;
  FDrawerScrim.Visible := False;
  FDrawerScrim.HitTest := True;
  FDrawerScrim.OnClick := DrawerScrimClick;

  // Header
  Header := TLayout.Create(Self);
  Header.Parent := Root;
  Header.Align := TAlignLayout.Top;
  Header.Height := 72;
  Header.Padding.Left := SPACE_LG;
  Header.Padding.Right := SPACE_LG;
  Header.Padding.Top := SPACE_MD;
  Header.Padding.Bottom := SPACE_SM;

  HeaderLeft := TLayout.Create(Self);
  HeaderLeft.Parent := Header;
  HeaderLeft.Align := TAlignLayout.Left;
  HeaderLeft.Width := 600;

  FHeaderTitle := TLabel.Create(Self);
  FHeaderTitle.Parent := HeaderLeft;
  FHeaderTitle.Align := TAlignLayout.Client;
  FHeaderTitle.Text := '';
  StyleHeaderLabel(FHeaderTitle);

  FHeaderRight := TLayout.Create(Self);
  FHeaderRight.Parent := Header;
  FHeaderRight.Align := TAlignLayout.Right;
  FHeaderRight.Width := 320;

  // Body host (standard two-column layout)
  FBodyHost := TLayout.Create(Self);
  FBodyHost.Parent := Root;
  FBodyHost.Align := TAlignLayout.Client;
  FBodyHost.Padding.Left := SPACE_LG;
  FBodyHost.Padding.Right := SPACE_LG;
  FBodyHost.Padding.Bottom := SPACE_LG;

  // Inspector (right)
  FInspectorCard := TRectangle.Create(Self);
  FInspectorCard.Parent := FBodyHost;
  FInspectorCard.Align := TAlignLayout.Right;
  FInspectorCard.Width := 360;
  FInspectorCard.Margins.Top := SPACE_SM;
  FInspectorCard.Margins.Left := SPACE_MD;
  FInspectorCard.Visible := False;
  StyleCard(FInspectorCard);

  FInspectorHeader := TLayout.Create(Self);
  FInspectorHeader.Parent := FInspectorCard;
  FInspectorHeader.Align := TAlignLayout.Top;
  FInspectorHeader.Height := 48;
  FInspectorHeader.Padding.Left := SPACE_MD;
  FInspectorHeader.Padding.Right := SPACE_MD;
  FInspectorHeader.Padding.Top := 14;

  FInspectorTitle := TLabel.Create(Self);
  FInspectorTitle.Parent := FInspectorHeader;
  FInspectorTitle.Align := TAlignLayout.Client;
  FInspectorTitle.Text := '';
  StyleSubHeaderLabel(FInspectorTitle);

  FInspectorScroll := TVertScrollBox.Create(Self);
  FInspectorScroll.Parent := FInspectorCard;
  FInspectorScroll.Align := TAlignLayout.Client;
  FInspectorScroll.Padding.Left := SPACE_MD;
  FInspectorScroll.Padding.Right := SPACE_MD;
  FInspectorScroll.Padding.Bottom := SPACE_MD;

  FInspectorContent := TLayout.Create(Self);
  FInspectorContent.Parent := FInspectorScroll;
  FInspectorContent.Align := TAlignLayout.Top;
  FInspectorContent.Height := 600;

  // Main content (left)
  FMainScroll := TVertScrollBox.Create(Self);
  FMainScroll.Parent := FBodyHost;
  FMainScroll.Align := TAlignLayout.Client;
  FMainScroll.Padding.Bottom := SPACE_LG;

  FMainContent := TLayout.Create(Self);
  FMainContent.Parent := FMainScroll;
  FMainContent.Align := TAlignLayout.Top;
  FMainContent.Height := 800; // grows as children are added

  // Overlay (loading/errors)
  FOverlay := TRectangle.Create(Self);
  FOverlay.Parent := Root;
  FOverlay.Align := TAlignLayout.Contents;
  FOverlay.Fill.Kind := TBrushKind.Solid;
  FOverlay.Fill.Color := $AA000000;
  FOverlay.Stroke.Kind := TBrushKind.None;
  FOverlay.Visible := False;

  FOverlayLabel := TLabel.Create(Self);
  FOverlayLabel.Parent := FOverlay;
  FOverlayLabel.Align := TAlignLayout.Center;
  FOverlayLabel.TextSettings.Font.Size := 16;
  FOverlayLabel.TextSettings.FontColor := $FFFFFFFF;
  FOverlayLabel.TextSettings.HorzAlign := TTextAlign.Center;
  FOverlayLabel.TextSettings.VertAlign := TTextAlign.Center;
  FOverlayLabel.Width := 520;
  FOverlayLabel.Height := 120;
  FOverlayLabel.WordWrap := True;

  ThemeCb :=
    procedure
    begin
      ApplyTheme;
    end;
  RegisterThemeChangedCallback(Self, ThemeCb);
end;

procedure TFrameBase.DrawerScrimClick(Sender: TObject);
begin
  // Click outside closes the drawer.
  if FInspectorAsDrawer then
    SetInspectorVisible(False);
end;

destructor TFrameBase.Destroy;
begin
  UnregisterThemeChangedCallbacks(Self);
  inherited;
end;

procedure TFrameBase.Loaded;
begin
  inherited;
  ApplyTheme;
end;

procedure TFrameBase.ApplyTheme;
begin
  // Title and any descendant controls created by derived frames should call Style* helpers.
  if Assigned(FBg) then
    StyleBackground(FBg);
  if Assigned(FHeaderTitle) then
    StyleHeaderLabel(FHeaderTitle);
  if Assigned(FInspectorCard) then
    StyleCard(FInspectorCard);
  if Assigned(FInspectorTitle) then
    StyleSubHeaderLabel(FInspectorTitle);
end;

procedure TFrameBase.SetTitle(const ATitle: string);
begin
  if Assigned(FHeaderTitle) then
    FHeaderTitle.Text := ATitle;
end;

function TFrameBase.HeaderRight: TLayout;
begin
  Result := FHeaderRight;
end;

function TFrameBase.BodyContent: TLayout;
begin
  Result := FMainContent;
end;

function TFrameBase.InspectorContent: TLayout;
begin
  Result := FInspectorContent;
end;

procedure TFrameBase.SetInspectorVisible(const AVisible: Boolean; const ATitle: string);
begin
  if not Assigned(FInspectorCard) then Exit;
  FInspectorCard.Visible := AVisible;
  if Assigned(FInspectorTitle) then
    FInspectorTitle.Text := ATitle;

  if Assigned(FDrawerScrim) then
  begin
    if FInspectorAsDrawer and AVisible then
    begin
      FDrawerScrim.Visible := True;
      FDrawerScrim.BringToFront;
      // Keep the drawer above the scrim.
      if Assigned(FInspectorCard) then
        FInspectorCard.BringToFront;
    end
    else
      FDrawerScrim.Visible := False;
  end;
end;

procedure TFrameBase.SetInspectorAsDrawer(const ADrawer: Boolean);
begin
  FInspectorAsDrawer := ADrawer;
  if not ADrawer then
  begin
    if Assigned(FDrawerScrim) then
      FDrawerScrim.Visible := False;
  end;
end;

procedure TFrameBase.SetInspectorWidth(const AWidth: Single);
begin
  if Assigned(FInspectorCard) then
    FInspectorCard.Width := AWidth;
end;

procedure TFrameBase.ShowLoading(const AMessage: string);
begin
  FOverlayLabel.Text := AMessage;
  FOverlay.Visible := True;
  FOverlay.BringToFront;
end;

procedure TFrameBase.ShowError(const AMessage: string);
begin
  FOverlayLabel.Text := AMessage;
  FOverlay.Visible := True;
  FOverlay.BringToFront;
end;

procedure TFrameBase.HideOverlay;
begin
  FOverlay.Visible := False;
end;

end.
