unit uTheme;

interface

uses
  System.SysUtils, System.UITypes, System.Types, System.Math, FMX.Types, FMX.Objects, FMX.StdCtrls, FMX.Graphics,
  FMX.ListBox, FMX.Effects, FMX.Edit, FMX.Controls;

type
  TThemeMode = (tmLight, tmDark);

var
  // Theme state
  CurrentThemeMode: TThemeMode = tmLight;
  // Typography (scalable)
  FONT_SIZE_HEADER: Single = 24;
  FONT_SIZE_SUBHEADER: Single = 18;
  FONT_SIZE_BODY: Single = 14;
  FONT_SIZE_MUTED: Single = 12;
  FONT_SCALE: Single = 1.0;

// Light palette - "Million Dollar" Modern SaaS Look
const
  L_BG          = $FFF0F4F8; // Cool Slate/Blue tint - not just white
  L_NAV_BG      = $FF0F172A; // Slate 900 (Rich Dark Blue/Black)
  L_NAV_ACTIVE  = $FFFFFFFF;
  L_NAV_HOVER   = $FF334155; // Slate 700
  L_CARD        = $FFFFFFFF;
  L_CARD_BORDER = $FFCBD5E1; // Slate 300 - more visible border
  L_TEXT        = $FF1E293B; // Slate 800
  L_MUTED       = $FF64748B; // Slate 500
  L_PRIMARY     = $FF2563EB; // Blue 600 - Stronger, more vibrant
  L_DANGER      = $FFEF4444; // Red 500

// Dark palette
  D_BG          = $FF18191A; // Dark mode bg
  D_NAV_BG      = $FF242526; // Dark mode nav
  D_NAV_ACTIVE  = $FF2D88FF; // Blue accent
  D_NAV_HOVER   = $FF3A3B3C; // Hover state
  D_CARD        = $FF242526; // Dark card
  D_CARD_BORDER = $FF3E4042; // Dark border
  D_TEXT        = $FFE4E6EB; // Light text
  D_MUTED       = $FFB0B3B8; // Muted text
  D_PRIMARY     = $FF2D88FF; // Blue accent
  D_DANGER      = $FFF02849; // Red accent

procedure StyleCard(Rect: TRectangle);
procedure StylePrimaryButton(Btn: TButton);
procedure StyleDangerButton(Btn: TButton);
procedure StyleHeaderLabel(Lbl: TLabel);
procedure StyleSubHeaderLabel(Lbl: TLabel);
procedure StyleMutedLabel(Lbl: TLabel);
procedure StyleInput(Edt: TEdit);
procedure StyleBackground(Rect: TRectangle);
procedure StyleNavBackground(Rect: TRectangle);
procedure StyleMenuItem(Item: TListBoxItem; Active: Boolean);
procedure WireButtonHover(Btn: TButton; const BaseColor: TAlphaColor = 0);
procedure AddShadow(Control: TControl);
procedure SetThemeMode(const AMode: TThemeMode);
function  GetThemeMode: TThemeMode;
procedure SetTypographyScale(const AScale: Single);
function  GetTypographyScale: Single;
function  ColorPrimary: TAlphaColor;
function  ColorText: TAlphaColor;
function  ColorMuted: TAlphaColor;
function  ColorCard: TAlphaColor;
function  ColorCardBorder: TAlphaColor;
function  ColorBg: TAlphaColor;
// Theme change callback registration
procedure RegisterThemeChangedCallback(const ACallback: TProc);
function  ColorNavHover: TAlphaColor; // exposed for menu hover styling

implementation

var
  ThemeChangedCallback: TProc;

function ColorBg: TAlphaColor;
begin
  if CurrentThemeMode = tmDark then Result := D_BG else Result := L_BG;
end;

function ColorCard: TAlphaColor;
begin
  if CurrentThemeMode = tmDark then Result := D_CARD else Result := L_CARD;
end;

function ColorCardBorder: TAlphaColor;
begin
  if CurrentThemeMode = tmDark then Result := D_CARD_BORDER else Result := L_CARD_BORDER;
end;

function ColorText: TAlphaColor;
begin
  if CurrentThemeMode = tmDark then Result := D_TEXT else Result := L_TEXT;
end;

function ColorMuted: TAlphaColor;
begin
  if CurrentThemeMode = tmDark then Result := D_MUTED else Result := L_MUTED;
end;

function ColorPrimary: TAlphaColor;
begin
  if CurrentThemeMode = tmDark then Result := D_PRIMARY else Result := L_PRIMARY;
end;

function ColorNavBg: TAlphaColor;
begin
  if CurrentThemeMode = tmDark then Result := D_NAV_BG else Result := L_NAV_BG;
end;

function ColorNavActive: TAlphaColor;
begin
  if CurrentThemeMode = tmDark then Result := D_NAV_ACTIVE else Result := L_NAV_ACTIVE;
end;

function ColorNavHover: TAlphaColor;
begin
  if CurrentThemeMode = tmDark then Result := D_NAV_HOVER else Result := L_NAV_HOVER;
end;

function ColorDanger: TAlphaColor;
begin
  if CurrentThemeMode = tmDark then Result := D_DANGER else Result := L_DANGER;
end;

procedure SetThemeMode(const AMode: TThemeMode);
begin
  CurrentThemeMode := AMode;
  if Assigned(ThemeChangedCallback) then
    ThemeChangedCallback();
end;

function GetThemeMode: TThemeMode;
begin
  Result := CurrentThemeMode;
end;

procedure SetTypographyScale(const AScale: Single);
begin
  FONT_SCALE := EnsureRange(AScale, 0.85, 1.25);
  FONT_SIZE_HEADER := 24 * FONT_SCALE;
  FONT_SIZE_SUBHEADER := 18 * FONT_SCALE;
  FONT_SIZE_BODY := 14 * FONT_SCALE;
  FONT_SIZE_MUTED := 12 * FONT_SCALE;
end;

function GetTypographyScale: Single;
begin
  Result := FONT_SCALE;
end;

function AdjustColor(const C: TAlphaColor; const Factor: Single): TAlphaColor;
var
  r,g,b,a: Byte;
  rf,gf,bf: Integer;
  f: Single;
begin
  a := TAlphaColorRec(C).A;
  // Clamp factor to sane range to avoid overflow/underflow with range checking on
  f := EnsureRange(Factor, 0.0, 4.0);
  rf := Round(TAlphaColorRec(C).R * f);
  gf := Round(TAlphaColorRec(C).G * f);
  bf := Round(TAlphaColorRec(C).B * f);
  if rf < 0 then rf := 0 else if rf > 255 then rf := 255;
  if gf < 0 then gf := 0 else if gf > 255 then gf := 255;
  if bf < 0 then bf := 0 else if bf > 255 then bf := 255;
  r := Byte(rf);
  g := Byte(gf);
  b := Byte(bf);
  Result := (a shl 24) or (r shl 16) or (g shl 8) or b;
end;

procedure AddShadow(Control: TControl);
var
  Effect: TShadowEffect;
  I: Integer;
begin
  if Control = nil then Exit;
  Effect := nil;
  // Check if shadow already exists
  for I := 0 to Control.ChildrenCount - 1 do
    if Control.Children[I] is TShadowEffect then
    begin
      Effect := TShadowEffect(Control.Children[I]);
      Break;
    end;

  if Effect = nil then
  begin
    Effect := TShadowEffect.Create(Control);
    Effect.Parent := Control;
  end;

  // Apply theme properties - Stronger, softer shadow for "pop"
  Effect.Softness := 0.4; // Sharper shadow
  Effect.Opacity := 0.3;  // Darker shadow
  Effect.Distance := 8;   // More "lift"
  Effect.Direction := 90; // Straight down
end;

procedure StyleBackground(Rect: TRectangle);
begin
  if Rect = nil then Exit;
  Rect.Fill.Kind := TBrushKind.Solid;
  Rect.Fill.Color := ColorBg;
  Rect.Stroke.Kind := TBrushKind.None;
end;

procedure StyleNavBackground(Rect: TRectangle);
begin
  if Rect = nil then Exit;
  Rect.Fill.Kind := TBrushKind.Solid;
  Rect.Fill.Color := ColorNavBg;
  Rect.Stroke.Kind := TBrushKind.None;
end;

procedure StyleMenuItem(Item: TListBoxItem; Active: Boolean);
begin
  if Item = nil then Exit;
  if Active then
  begin
    Item.TextSettings.FontColor := ColorNavActive;
    Item.StyledSettings := Item.StyledSettings - [TStyledSetting.FontColor];
    Item.Opacity := 1.0;
    // Add a subtle indicator or background change if possible, but for now just text
  end
  else
  begin
    Item.TextSettings.FontColor := $FF9CA3AF; // Gray 400
    Item.StyledSettings := Item.StyledSettings - [TStyledSetting.FontColor];
    Item.Opacity := 1.0;
  end;
end;

procedure StyleCard(Rect: TRectangle);
begin
  if Rect = nil then Exit;
  Rect.Fill.Kind := TBrushKind.Solid;
  Rect.Fill.Color := ColorCard;
  Rect.Stroke.Kind := TBrushKind.Solid;
  Rect.Stroke.Color := ColorCardBorder;
  Rect.Stroke.Thickness := 1;
  Rect.XRadius := 16; // More rounded
  Rect.YRadius := 16;
  Rect.Opacity := 1;
  AddShadow(Rect);
end;

procedure StylePrimaryButton(Btn: TButton);
begin
  if Btn = nil then Exit;
  Btn.TextSettings.FontColor := TAlphaColorRec.White;
  Btn.StyledSettings := Btn.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size];
  Btn.TextSettings.Font.Size := FONT_SIZE_BODY;
  Btn.StylesData['background'] := ColorPrimary;
  Btn.Tag := Integer(ColorPrimary);
  // Try to make it rounded if style supports it, otherwise rely on stylebook
  WireButtonHover(Btn);
end;

procedure StyleDangerButton(Btn: TButton);
begin
  if Btn = nil then Exit;
  Btn.TextSettings.FontColor := TAlphaColorRec.White;
  Btn.StyledSettings := Btn.StyledSettings - [TStyledSetting.FontColor];
  Btn.StylesData['background'] := ColorDanger;
  Btn.Tag := Integer(ColorDanger);
  WireButtonHover(Btn);
end;

procedure StyleHeaderLabel(Lbl: TLabel);
begin
  if Lbl = nil then Exit;
  Lbl.TextSettings.Font.Size := FONT_SIZE_HEADER;
  Lbl.TextSettings.FontColor := ColorText;
  Lbl.StyledSettings := Lbl.StyledSettings - [TStyledSetting.Size, TStyledSetting.FontColor];
  Lbl.TextSettings.Font.Style := [TFontStyle.fsBold];
end;

procedure StyleSubHeaderLabel(Lbl: TLabel);
begin
  if Lbl = nil then Exit;
  Lbl.TextSettings.Font.Size := FONT_SIZE_SUBHEADER;
  Lbl.TextSettings.FontColor := ColorText;
  Lbl.StyledSettings := Lbl.StyledSettings - [TStyledSetting.Size, TStyledSetting.FontColor];
end;

procedure StyleMutedLabel(Lbl: TLabel);
begin
  if Lbl = nil then Exit;
  Lbl.TextSettings.Font.Size := FONT_SIZE_MUTED;
  Lbl.TextSettings.FontColor := ColorMuted;
  Lbl.StyledSettings := Lbl.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size];
end;

procedure StyleInput(Edt: TEdit);
begin
  if Edt = nil then Exit;
  Edt.TextSettings.FontColor := ColorText;
  Edt.TextSettings.Font.Size := FONT_SIZE_BODY;
  Edt.StyledSettings := Edt.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size];
end;

type
  THoverManager = class
  public
    procedure BtnMouseEnter(Sender: TObject);
    procedure BtnMouseLeave(Sender: TObject);
  end;

var
  HoverMgr: THoverManager;

{ THoverManager }

procedure THoverManager.BtnMouseEnter(Sender: TObject);
var
  Btn: TButton;
  Base: TAlphaColor;
begin
  if not (Sender is TButton) then Exit;
  Btn := TButton(Sender);
  Base := TAlphaColor(Btn.Tag);
  if Base = 0 then Base := ColorPrimary;
  Btn.StylesData['background'] := AdjustColor(Base, 1.1);
end;

procedure THoverManager.BtnMouseLeave(Sender: TObject);
var
  Btn: TButton;
  Base: TAlphaColor;
begin
  if not (Sender is TButton) then Exit;
  Btn := TButton(Sender);
  Base := TAlphaColor(Btn.Tag);
  if Base = 0 then Base := ColorPrimary;
  Btn.StylesData['background'] := Base;
end;


procedure WireButtonHover(Btn: TButton; const BaseColor: TAlphaColor = 0);
begin
  if Btn = nil then Exit;
  if BaseColor <> 0 then Btn.Tag := Integer(BaseColor);
  if HoverMgr = nil then HoverMgr := THoverManager.Create;
  Btn.OnMouseEnter := HoverMgr.BtnMouseEnter;
  Btn.OnMouseLeave := HoverMgr.BtnMouseLeave;
end;

procedure RegisterThemeChangedCallback(const ACallback: TProc);
begin
  ThemeChangedCallback := ACallback;
end;

end.
