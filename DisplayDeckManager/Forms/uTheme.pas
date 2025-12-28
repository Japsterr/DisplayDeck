unit uTheme;

interface

uses
  System.SysUtils, System.Classes, System.UITypes, System.Types, System.Math, FMX.Types, FMX.Objects, FMX.StdCtrls, FMX.Graphics,
  FMX.ListBox, FMX.Effects, FMX.Edit, FMX.Controls;

type
  TThemeMode = (tmLight, tmDark);
  TThemePreset = (
    tpLightBlue,
    tpDarkBlue,
    tpMidnight,
    tpSlate
  );

  TThemePalette = record
    Bg: TAlphaColor;
    NavBg: TAlphaColor;
    NavActive: TAlphaColor;
    NavHover: TAlphaColor;
    Card: TAlphaColor;
    CardBorder: TAlphaColor;
    Text: TAlphaColor;
    Muted: TAlphaColor;
    Primary: TAlphaColor;
    Accent2: TAlphaColor;
    Accent3: TAlphaColor;
    Success: TAlphaColor;
    Warning: TAlphaColor;
    Info: TAlphaColor;
    Danger: TAlphaColor;
  end;

var
  // Theme state
  CurrentThemeMode: TThemeMode = tmLight;
  CurrentThemePreset: TThemePreset = tpLightBlue;
  // Typography (scalable)
  FONT_SIZE_HEADER: Single = 24;
  FONT_SIZE_SUBHEADER: Single = 18;
  FONT_SIZE_BODY: Single = 14;
  FONT_SIZE_MUTED: Single = 12;
  FONT_SCALE: Single = 1.0;

// Shared spacing tokens (8px base rhythm)
const
  SPACE_XS: Single = 8;
  SPACE_SM: Single = 12;
  SPACE_MD: Single = 16;
  SPACE_LG: Single = 24;
  SPACE_XL: Single = 32;
  CARD_RADIUS: Single = 16;

// =============================================================================
// Modern 2025 Palette (Tailwind Slate + Indigo, Radix-inspired 12-step scale)
// Research: Material 3 tone-based surfaces, Radix accessible color scale,
//           Tailwind v4 Slate/Indigo, Fluent 2 high-contrast patterns.
// =============================================================================

// Light palette - "Premium SaaS" look
const
  // Tailwind Slate-50 for app canvas - slight cool tint, not pure white
  L_BG          = $FFF8FAFC; // slate-50: subtle cool canvas
  L_NAV_BG      = $FF0F172A; // slate-900: premium dark sidebar
  L_NAV_ACTIVE  = $FFFFFFFF; // white for active menu text
  L_NAV_HOVER   = $FF1E293B; // slate-800: subtle hover lift
  L_CARD        = $FFFFFFFF; // pure white cards
  L_CARD_BORDER = $FFE2E8F0; // slate-200: subtle separator
  L_TEXT        = $FF0F172A; // slate-900: high-contrast text
  L_MUTED       = $FF64748B; // slate-500: secondary text
  L_PRIMARY     = $FF4F46E5; // indigo-600: vibrant CTA
  L_DANGER      = $FFDC2626; // red-600: accessible red

// Dark palette - true dark mode
  D_BG          = $FF0F172A; // slate-900
  D_NAV_BG      = $FF020617; // slate-950
  D_NAV_ACTIVE  = $FFA5B4FC; // indigo-300
  D_NAV_HOVER   = $FF1E293B; // slate-800
  D_CARD        = $FF1E293B; // slate-800
  D_CARD_BORDER = $FF334155; // slate-700
  D_TEXT        = $FFF1F5F9; // slate-100
  D_MUTED       = $FF94A3B8; // slate-400
  D_PRIMARY     = $FF818CF8; // indigo-400
  D_DANGER      = $FFF87171; // red-400

procedure StyleCard(Rect: TRectangle);
procedure StylePrimaryButton(Btn: TButton);
procedure StyleSecondaryButton(Btn: TButton);
procedure StyleDangerButton(Btn: TButton);
procedure StyleSuccessButton(Btn: TButton);
procedure StyleHeaderLabel(Lbl: TLabel);
procedure StyleSubHeaderLabel(Lbl: TLabel);
procedure StyleMutedLabel(Lbl: TLabel);
procedure StyleInput(Edt: TEdit);
procedure StyleBackground(Rect: TRectangle);
procedure StyleGradientBackground(Rect: TRectangle);
procedure StyleNavBackground(Rect: TRectangle);
procedure StyleMenuItem(Item: TListBoxItem; Active: Boolean);
procedure WireButtonHover(Btn: TButton; const BaseColor: TAlphaColor = 0);
procedure AddShadow(Control: TControl);
procedure EnsureButtonsReadable(const Root: TFmxObject);
procedure SetThemeMode(const AMode: TThemeMode; const FireCallback: Boolean = True);
procedure SetThemePreset(const APreset: TThemePreset; const FireCallback: Boolean = True);
function  GetThemeMode: TThemeMode;
function  GetThemePreset: TThemePreset;
function  ThemePresetToString(const APreset: TThemePreset): string;
function  TryParseThemePreset(const S: string; out APreset: TThemePreset): Boolean;
procedure SetTypographyScale(const AScale: Single);
function  GetTypographyScale: Single;
function  ColorPrimary: TAlphaColor;
function  ColorAccent2: TAlphaColor;
function  ColorAccent3: TAlphaColor;
function  ColorSuccess: TAlphaColor;
function  ColorWarning: TAlphaColor;
function  ColorInfo: TAlphaColor;
function  ColorDanger: TAlphaColor;
function  ColorText: TAlphaColor;
function  ColorMuted: TAlphaColor;
function  ColorCard: TAlphaColor;
function  ColorCardBorder: TAlphaColor;
function  ColorBg: TAlphaColor;
function  ColorNavBg: TAlphaColor;
// Theme change callback registration
procedure RegisterThemeChangedCallback(const ACallback: TProc); overload;
procedure RegisterThemeChangedCallback(const AOwner: TComponent; const ACallback: TProc); overload;
procedure UnregisterThemeChangedCallbacks(const AOwner: TComponent);
procedure NotifyThemeChanged;
function  ColorNavHover: TAlphaColor; // exposed for menu hover styling

implementation

uses
  System.Generics.Collections,
  System.Rtti;

function IsDarkColor(const C: TAlphaColor): Boolean; forward;
procedure SetButtonBackground(const Btn: TButton; const AColor: TAlphaColor); forward;

function IsNearWhite(const C: TAlphaColor): Boolean;
begin
  Result := (TAlphaColorRec(C).R >= $F0) and (TAlphaColorRec(C).G >= $F0) and (TAlphaColorRec(C).B >= $F0);
end;

function IsNearBlack(const C: TAlphaColor): Boolean;
begin
  Result := (TAlphaColorRec(C).R <= $20) and (TAlphaColorRec(C).G <= $20) and (TAlphaColorRec(C).B <= $20);
end;

function TryGetButtonBackgroundColor(const Btn: TButton; out AColor: TAlphaColor): Boolean;
var
  V: TValue;
begin
  Result := False;
  AColor := 0;
  if Btn = nil then Exit;

  // Safest: read from FMX StylesData if present
  try
    V := Btn.StylesData['background'];
    if V.IsType<TAlphaColor> then
      AColor := V.AsType<TAlphaColor>
    else if V.Kind in [tkInteger, tkInt64] then
      AColor := TAlphaColor(V.AsOrdinal)
    else
      AColor := 0;

    Result := AColor <> 0;
  except
    Result := False;
  end;
end;

procedure EnsureButtonReadable(const Btn: TButton);
var
  BgKnown: Boolean;
  Bg, WantedBg, WantedText: TAlphaColor;
begin
  if Btn = nil then Exit;

  // Ensure style tree exists
  Btn.ApplyStyleLookup;

  // Determine what the button is currently painted with (best effort)
  Bg := TAlphaColor(0);
  BgKnown := TryGetButtonBackgroundColor(Btn, Bg);

  // Decide what background to use
  // If button already has a solid dark background, keep it. Otherwise force Primary.
  if BgKnown and IsDarkColor(Bg) and (not IsNearWhite(Bg)) then
    WantedBg := Bg
  else
    WantedBg := ColorPrimary;

  // Pick readable text: white on dark backgrounds, dark text on light
  if IsDarkColor(WantedBg) then
    WantedText := TAlphaColorRec.White
  else
    WantedText := ColorText;

  // Apply immediately
  Btn.TextSettings.FontColor := WantedText;
  Btn.StyledSettings := Btn.StyledSettings - [TStyledSetting.FontColor];
  Btn.Opacity := 1.0;
  SetButtonBackground(Btn, WantedBg);
end;

procedure EnsureButtonsReadable(const Root: TFmxObject);
begin
  if Root = nil then Exit;

  if Root is TButton then
    EnsureButtonReadable(TButton(Root));

  for var i := 0 to Root.ChildrenCount - 1 do
    EnsureButtonsReadable(Root.Children[i]);
end;

procedure SetButtonBackground(const Btn: TButton; const AColor: TAlphaColor);
var
  TextColor: TAlphaColor;
  TextObj: TFmxObject;
  LabelText: TText;
begin
  if Btn = nil then Exit;

  // Determine text color based on background luminance
  if IsDarkColor(AColor) then
    TextColor := TAlphaColorRec.White
  else
    TextColor := $FF0F172A; // slate-900

  // SAFE approach: use FMX StylesData to set button background (no extra controls, no reparenting)
  try
    Btn.StylesData['background'] := AColor;
  except
    // ignore
  end;

  // Set button text color via TextSettings
  Btn.TextSettings.FontColor := TextColor;
  Btn.StyledSettings := Btn.StyledSettings - [TStyledSetting.FontColor];

  // Some FMX styles also honor a 'fontcolor' StylesData key
  try
    Btn.StylesData['fontcolor'] := TextColor;
  except
    // ignore
  end;

  // CRITICAL: Apply style and find the actual TText in the style tree
  Btn.ApplyStyleLookup;

  // The button's text is in the style tree with resource name 'text'
  TextObj := Btn.FindStyleResource('text');
  if (TextObj <> nil) and (TextObj is TText) then
  begin
    LabelText := TText(TextObj);
    LabelText.Color := TextColor;
    LabelText.Font.Style := [TFontStyle.fsBold];
    LabelText.Font.Size := 13;
    LabelText.Visible := True;
    LabelText.Opacity := 1.0;
    LabelText.HitTest := False;
  end;

  // Also try 'glyphtext' for some button styles
  TextObj := Btn.FindStyleResource('glyphtext');
  if (TextObj <> nil) and (TextObj is TText) then
  begin
    var GT := TText(TextObj);
    GT.Color := TextColor;
    GT.Visible := True;
    GT.Opacity := 1.0;
    GT.HitTest := False;
  end;
end;

type
  TThemeCallbackEntry = record
    Owner: TComponent;
    Callback: TProc;
  end;

var
  ThemeChangedCallbacks: TList<TThemeCallbackEntry>;

function GetPalette: TThemePalette;
begin
  case CurrentThemePreset of
    tpLightBlue:
      begin
        Result.Bg := L_BG;
        Result.NavBg := L_NAV_BG;
        Result.NavActive := L_NAV_ACTIVE;
        Result.NavHover := L_NAV_HOVER;
        Result.Card := L_CARD;
        Result.CardBorder := L_CARD_BORDER;
        Result.Text := L_TEXT;
        Result.Muted := L_MUTED;
        Result.Primary := L_PRIMARY;
        Result.Accent2 := $FF7C3AED; // violet-600: secondary accent
        Result.Accent3 := $FF0891B2; // cyan-600: tertiary
        Result.Success := $FF16A34A; // green-600
        Result.Warning := $FFD97706; // amber-600
        Result.Info := $FF0284C7;    // sky-600
        Result.Danger := L_DANGER;
      end;
    tpDarkBlue:
      begin
        Result.Bg := D_BG;
        Result.NavBg := D_NAV_BG;
        Result.NavActive := D_NAV_ACTIVE;
        Result.NavHover := D_NAV_HOVER;
        Result.Card := D_CARD;
        Result.CardBorder := D_CARD_BORDER;
        Result.Text := D_TEXT;
        Result.Muted := D_MUTED;
        Result.Primary := D_PRIMARY;
        Result.Accent2 := $FF818CF8; // indigo-400
        Result.Accent3 := $FF22D3EE; // cyan-400
        Result.Success := $FF34D399; // emerald-400
        Result.Warning := $FFFBBF24; // amber-400
        Result.Info := $FF7DD3FC;    // sky-300
        Result.Danger := D_DANGER;
      end;
    tpMidnight:
      begin
        // A darker, more "premium" navy theme
        Result.Bg := $FF0B1220;
        Result.NavBg := $FF0B1220;
        Result.NavActive := $FFFFFFFF;
        Result.NavHover := $FF1B2A45;
        Result.Card := $FF101A2D;
        Result.CardBorder := $FF223355;
        Result.Text := $FFE8EEF8;
        Result.Muted := $FFB6C2D9;
        Result.Primary := $FF4F8CFF;
        Result.Accent2 := $FF818CF8; // indigo-400
        Result.Accent3 := $FF22D3EE; // cyan-400
        Result.Success := $FF34D399; // emerald-400
        Result.Warning := $FFFBBF24; // amber-400
        Result.Info := $FF7DD3FC;    // sky-300
        Result.Danger := $FFF0435D;
      end;
    tpSlate:
      begin
        // Light slate theme with teal accent
        Result.Bg := $FFF1F5F9;
        Result.NavBg := $FF0F172A;
        Result.NavActive := $FFFFFFFF;
        Result.NavHover := $FF334155;
        Result.Card := $FFFFFFFF;
        Result.CardBorder := $FFCBD5E1;
        Result.Text := $FF0F172A;
        Result.Muted := $FF64748B;
        Result.Primary := $FF14B8A6; // teal
        Result.Accent2 := $FF4F46E5; // indigo-600
        Result.Accent3 := $FF0EA5E9; // sky-500
        Result.Success := $FF22C55E; // green-500
        Result.Warning := $FFF59E0B; // amber-500
        Result.Info := $FF38BDF8;    // sky-400
        Result.Danger := $FFEF4444;
      end;
  else
    // Default fallback
    Result.Bg := L_BG;
    Result.NavBg := L_NAV_BG;
    Result.NavActive := L_NAV_ACTIVE;
    Result.NavHover := L_NAV_HOVER;
    Result.Card := L_CARD;
    Result.CardBorder := L_CARD_BORDER;
    Result.Text := L_TEXT;
    Result.Muted := L_MUTED;
    Result.Primary := L_PRIMARY;
    Result.Accent2 := $FF4F46E5;
    Result.Accent3 := $FF06B6D4;
    Result.Success := $FF22C55E;
    Result.Warning := $FFF59E0B;
    Result.Info := $FF38BDF8;
    Result.Danger := L_DANGER;
  end;
end;

function ColorBg: TAlphaColor;
begin
  Result := GetPalette.Bg;
end;

function ColorCard: TAlphaColor;
begin
  Result := GetPalette.Card;
end;

function ColorCardBorder: TAlphaColor;
begin
  Result := GetPalette.CardBorder;
end;

function ColorText: TAlphaColor;
begin
  Result := GetPalette.Text;
end;

function ColorMuted: TAlphaColor;
begin
  Result := GetPalette.Muted;
end;

function ColorPrimary: TAlphaColor;
begin
  Result := GetPalette.Primary;
end;

function ColorAccent2: TAlphaColor;
begin
  Result := GetPalette.Accent2;
end;

function ColorAccent3: TAlphaColor;
begin
  Result := GetPalette.Accent3;
end;

function ColorSuccess: TAlphaColor;
begin
  Result := GetPalette.Success;
end;

function ColorWarning: TAlphaColor;
begin
  Result := GetPalette.Warning;
end;

function ColorInfo: TAlphaColor;
begin
  Result := GetPalette.Info;
end;

function ColorNavBg: TAlphaColor;
begin
  Result := GetPalette.NavBg;
end;

function ColorNavActive: TAlphaColor;
begin
  Result := GetPalette.NavActive;
end;

function ColorNavHover: TAlphaColor;
begin
  Result := GetPalette.NavHover;
end;

function ColorDanger: TAlphaColor;
begin
  Result := GetPalette.Danger;
end;

procedure SetThemeMode(const AMode: TThemeMode; const FireCallback: Boolean = True);
begin
  CurrentThemeMode := AMode;
  // Backward compatible mapping to presets.
  if CurrentThemeMode = tmDark then
    CurrentThemePreset := tpDarkBlue
  else
    CurrentThemePreset := tpLightBlue;
  if FireCallback then
    NotifyThemeChanged;
end;

procedure SetThemePreset(const APreset: TThemePreset; const FireCallback: Boolean = True);
begin
  CurrentThemePreset := APreset;
  case CurrentThemePreset of
    tpDarkBlue, tpMidnight:
      CurrentThemeMode := tmDark;
  else
    CurrentThemeMode := tmLight;
  end;

  if FireCallback then
    NotifyThemeChanged;
end;

function GetThemeMode: TThemeMode;
begin
  Result := CurrentThemeMode;
end;

function GetThemePreset: TThemePreset;
begin
  Result := CurrentThemePreset;
end;

function ThemePresetToString(const APreset: TThemePreset): string;
begin
  case APreset of
    tpLightBlue: Result := 'light-blue';
    tpDarkBlue: Result := 'dark-blue';
    tpMidnight: Result := 'midnight';
    tpSlate: Result := 'slate';
  else
    Result := 'light-blue';
  end;
end;

function TryParseThemePreset(const S: string; out APreset: TThemePreset): Boolean;
var
  V: string;
begin
  V := LowerCase(Trim(S));
  Result := True;
  if (V = 'light') or (V = 'light-blue') or (V = 'blue') then APreset := tpLightBlue
  else if (V = 'dark') or (V = 'dark-blue') then APreset := tpDarkBlue
  else if (V = 'midnight') then APreset := tpMidnight
  else if (V = 'slate') then APreset := tpSlate
  else Result := False;
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

function IsDarkColor(const C: TAlphaColor): Boolean;
var
  R, G, B: Single;
  Luma: Single;
begin
  R := TAlphaColorRec(C).R / 255.0;
  G := TAlphaColorRec(C).G / 255.0;
  B := TAlphaColorRec(C).B / 255.0;
  // Relative luminance (sRGB approximation)
  Luma := (0.2126 * R) + (0.7152 * G) + (0.0722 * B);
  Result := Luma < 0.45;
end;

procedure AddShadow(Control: TControl);
var
  KeyShadow: TShadowEffect;
  AmbientShadow: TShadowEffect;
  I: Integer;
  DarkTheme: Boolean;
begin
  if Control = nil then Exit;
  KeyShadow := nil;
  AmbientShadow := nil;

  // Reuse up to two existing shadow effects (key + ambient).
  for I := 0 to Control.ChildrenCount - 1 do
    if Control.Children[I] is TShadowEffect then
    begin
      if KeyShadow = nil then
        KeyShadow := TShadowEffect(Control.Children[I])
      else if AmbientShadow = nil then
        AmbientShadow := TShadowEffect(Control.Children[I]);
    end;

  if KeyShadow = nil then
  begin
    KeyShadow := TShadowEffect.Create(Control);
    KeyShadow.Parent := Control;
  end;

  if AmbientShadow = nil then
  begin
    AmbientShadow := TShadowEffect.Create(Control);
    AmbientShadow.Parent := Control;
  end;

  DarkTheme := IsDarkColor(ColorBg);

  // Elevation approach (aligned with Fluent/Atlassian): keep borders for definition,
  // use a subtle dual-shadow ramp for depth where needed.
  // - Key shadow: crisper edge definition
  // - Ambient shadow: soft lift
  KeyShadow.Direction := 90;
  KeyShadow.Distance := 1;
  KeyShadow.Softness := 0.25;
  KeyShadow.ShadowColor := $FF000000;
  KeyShadow.Opacity := IfThen(DarkTheme, 0.18, 0.08);

  AmbientShadow.Direction := 90;
  AmbientShadow.Distance := IfThen(DarkTheme, 10, 8);
  AmbientShadow.Softness := 0.92;
  AmbientShadow.ShadowColor := $FF000000;
  AmbientShadow.Opacity := IfThen(DarkTheme, 0.22, 0.12);
end;

procedure StyleBackground(Rect: TRectangle);
begin
  if Rect = nil then Exit;
  Rect.Fill.Kind := TBrushKind.Solid;
  Rect.Fill.Color := ColorBg;
  Rect.Stroke.Kind := TBrushKind.None;
end;

procedure StyleGradientBackground(Rect: TRectangle);
begin
  if Rect = nil then Exit;
  Rect.Fill.Kind := TBrushKind.Gradient;
  Rect.Fill.Gradient.StartPosition.Point := TPointF.Create(0, 0);
  Rect.Fill.Gradient.StopPosition.Point := TPointF.Create(1, 1);
  Rect.Fill.Gradient.Color := ColorNavBg;
  Rect.Fill.Gradient.Color1 := ColorPrimary;
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
    // Keep nav inactive text theme-driven for consistent contrast across presets.
    Item.TextSettings.FontColor := ColorMuted;
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
  Rect.XRadius := CARD_RADIUS;
  Rect.YRadius := CARD_RADIUS;
  Rect.Opacity := 1;
  AddShadow(Rect);
end;

procedure StylePrimaryButton(Btn: TButton);
begin
  if Btn = nil then Exit;
  Btn.TextSettings.FontColor := TAlphaColorRec.White;
  Btn.StyledSettings := Btn.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size];
  Btn.TextSettings.Font.Size := FONT_SIZE_BODY;
  Btn.TextSettings.Font.Style := [TFontStyle.fsBold];
  Btn.Opacity := 1.0;
  SetButtonBackground(Btn, ColorPrimary);
  Btn.Tag := Integer(ColorPrimary);
  // Try to make it rounded if style supports it, otherwise rely on stylebook
  WireButtonHover(Btn);
end;

procedure StyleSecondaryButton(Btn: TButton);
var
  SecondaryBg: TAlphaColor;
begin
  if Btn = nil then Exit;
  // Secondary buttons use a slate-600 background in light mode (visible but less prominent)
  SecondaryBg := $FF475569; // slate-600
  Btn.TextSettings.FontColor := TAlphaColorRec.White;
  Btn.StyledSettings := Btn.StyledSettings - [TStyledSetting.FontColor, TStyledSetting.Size];
  Btn.TextSettings.Font.Size := FONT_SIZE_BODY;
  Btn.TextSettings.Font.Style := [TFontStyle.fsBold];
  Btn.Opacity := 1.0;
  SetButtonBackground(Btn, SecondaryBg);
  Btn.Tag := Integer(SecondaryBg);
  WireButtonHover(Btn);
end;

procedure StyleDangerButton(Btn: TButton);
begin
  if Btn = nil then Exit;
  Btn.TextSettings.FontColor := TAlphaColorRec.White;
  Btn.StyledSettings := Btn.StyledSettings - [TStyledSetting.FontColor];
  Btn.TextSettings.Font.Style := [TFontStyle.fsBold];
  Btn.Opacity := 1.0;
  SetButtonBackground(Btn, ColorDanger);
  Btn.Tag := Integer(ColorDanger);
  WireButtonHover(Btn);
end;

procedure StyleSuccessButton(Btn: TButton);
begin
  if Btn = nil then Exit;
  Btn.TextSettings.FontColor := TAlphaColorRec.White;
  Btn.StyledSettings := Btn.StyledSettings - [TStyledSetting.FontColor];
  Btn.TextSettings.Font.Style := [TFontStyle.fsBold];
  Btn.Opacity := 1.0;
  SetButtonBackground(Btn, ColorSuccess);
  Btn.Tag := Integer(ColorSuccess);
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
  SetButtonBackground(Btn, AdjustColor(Base, 1.1));
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
  SetButtonBackground(Btn, Base);
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
  RegisterThemeChangedCallback(nil, ACallback);
end;

procedure RegisterThemeChangedCallback(const AOwner: TComponent; const ACallback: TProc);
var
  E: TThemeCallbackEntry;
begin
  if not Assigned(ThemeChangedCallbacks) then
    ThemeChangedCallbacks := TList<TThemeCallbackEntry>.Create;
  E.Owner := AOwner;
  E.Callback := ACallback;
  ThemeChangedCallbacks.Add(E);
end;

procedure UnregisterThemeChangedCallbacks(const AOwner: TComponent);
begin
  if (AOwner = nil) or (not Assigned(ThemeChangedCallbacks)) then Exit;
  for var i := ThemeChangedCallbacks.Count - 1 downto 0 do
    if ThemeChangedCallbacks[i].Owner = AOwner then
      ThemeChangedCallbacks.Delete(i);
end;

procedure NotifyThemeChanged;
begin
  if not Assigned(ThemeChangedCallbacks) then Exit;
  for var E in ThemeChangedCallbacks do
  begin
    if Assigned(E.Callback) then
      E.Callback();
  end;
end;

initialization

finalization
  ThemeChangedCallbacks.Free;

end.
