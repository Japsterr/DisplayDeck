unit uTheme;

interface

uses
  System.UITypes, FMX.Types, FMX.Objects, FMX.StdCtrls, FMX.Graphics;

const
  COLOR_BG       = $FFF3F4F6; // light gray background
  COLOR_TEXT     = $FF111827; // near-black text
  COLOR_MUTED    = $FF6B7280; // muted label
  COLOR_PRIMARY  = $FF2563EB; // blue
  COLOR_DANGER   = $FFEF4444; // red

procedure StyleCard(Rect: TRectangle);
procedure StylePrimaryButton(Btn: TButton);
procedure StyleDangerButton(Btn: TButton);
procedure StyleHeaderLabel(Lbl: TLabel);
procedure StyleMutedLabel(Lbl: TLabel);
procedure StyleBackground(Rect: TRectangle);

implementation

procedure StyleBackground(Rect: TRectangle);
begin
  if Rect = nil then Exit;
  Rect.Fill.Kind := TBrushKind.Solid;
  Rect.Fill.Color := COLOR_BG;
  Rect.Stroke.Kind := TBrushKind.None;
end;

procedure StyleCard(Rect: TRectangle);
begin
  if Rect = nil then Exit;
  Rect.Fill.Kind := TBrushKind.Solid;
  Rect.Fill.Color := TAlphaColorRec.White;
  Rect.Stroke.Kind := TBrushKind.None;
  Rect.XRadius := 12;
  Rect.YRadius := 12;
  Rect.Opacity := 1;
end;

procedure StylePrimaryButton(Btn: TButton);
begin
  if Btn = nil then Exit;
  Btn.TextSettings.FontColor := TAlphaColorRec.White;
  Btn.StyledSettings := Btn.StyledSettings - [TStyledSetting.FontColor];
  Btn.TextSettings.Font.Size := 14;
  Btn.StyledSettings := Btn.StyledSettings - [TStyledSetting.Size];
  Btn.StylesData['background'] := COLOR_PRIMARY;
end;

procedure StyleDangerButton(Btn: TButton);
begin
  if Btn = nil then Exit;
  Btn.TextSettings.FontColor := TAlphaColorRec.White;
  Btn.StyledSettings := Btn.StyledSettings - [TStyledSetting.FontColor];
  Btn.StylesData['background'] := COLOR_DANGER;
end;

procedure StyleHeaderLabel(Lbl: TLabel);
begin
  if Lbl = nil then Exit;
  Lbl.TextSettings.Font.Size := 20;
  Lbl.TextSettings.FontColor := COLOR_TEXT;
  Lbl.StyledSettings := Lbl.StyledSettings - [TStyledSetting.Size, TStyledSetting.FontColor];
end;

procedure StyleMutedLabel(Lbl: TLabel);
begin
  if Lbl = nil then Exit;
  Lbl.TextSettings.FontColor := COLOR_MUTED;
  Lbl.StyledSettings := Lbl.StyledSettings - [TStyledSetting.FontColor];
end;

end.
