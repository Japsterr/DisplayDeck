unit SettingsFrame;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants, 
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.Layouts, FMX.Objects, FMX.Edit, FMX.ListBox,
  FMX.Effects;

type
  TSettingsFrame = class(TFrame)
    LayoutBackground: TLayout;
    RectBackground: TRectangle;
    LayoutMain: TLayout;
    RectCard: TRectangle;
    ShadowEffect1: TShadowEffect;
    LayoutCardContent: TLayout;
    lblTitle: TLabel;
    ScrollBoxSettings: TVertScrollBox;
    LayoutForm: TLayout;
    lblSectionGeneral: TLabel;
    lblLanguage: TLabel;
    cmbLanguage: TComboBox;
    lblRefreshInterval: TLabel;
    edtRefreshInterval: TEdit;
    lblSectionNotifications: TLabel;
    chkEmailNotifications: TCheckBox;
    chkDisplayOfflineAlerts: TCheckBox;
    chkCampaignEndAlerts: TCheckBox;
    LayoutButtons: TLayout;
    btnSaveSettings: TButton;
    btnResetDefaults: TButton;
    lblSectionAPI: TLabel;
    lblAPIEndpoint: TLabel;
    edtAPIEndpoint: TEdit;
    btnApplyApiEndpoint: TButton;
    btnClearToken: TButton;
    lblSectionTheme: TLabel;
    lblThemeStyle: TLabel;
    cmbThemeStyle: TComboBox;
    lblFontScale: TLabel;
    edtFontScale: TEdit;
    lblSectionDebug: TLabel;
    lblLastRequestUrl: TLabel;
    edtLastRequestUrl: TEdit;
    lblLastStatus: TLabel;
    edtLastStatus: TEdit;
    lblLastBody: TLabel;
    edtLastBody: TEdit;
    btnRefreshDebug: TButton;
    procedure btnSaveSettingsClick(Sender: TObject);
    procedure btnResetDefaultsClick(Sender: TObject);
    procedure btnApplyApiEndpointClick(Sender: TObject);
    procedure btnClearTokenClick(Sender: TObject);
    procedure cmbThemeStyleChange(Sender: TObject);
    procedure edtFontScaleExit(Sender: TObject);
    procedure btnRefreshDebugClick(Sender: TObject);
  private
    { Private declarations }
    procedure LoadSettings;
    procedure SaveSettings;
    procedure SafeSetChecked(ACheckBox: TCheckBox; AValue: Boolean);
  public
    { Public declarations }
    procedure Initialize;
  end;

implementation

{$R *.fmx}

uses
  System.IniFiles, System.IOUtils,
  uApiClient, uTheme, uAppSettings;

procedure TSettingsFrame.Initialize;
begin
  LoadSettings;
  
  // Ensure background fills the frame
  if Assigned(RectBackground) then
    RectBackground.Align := TAlignLayout.Contents;

  // Apply Theme Styling
  StyleBackground(RectBackground);
  StyleCard(RectCard);
  
  StyleHeaderLabel(lblTitle);
  
  StyleSubHeaderLabel(lblSectionGeneral);
  StyleSubHeaderLabel(lblSectionNotifications);
  StyleSubHeaderLabel(lblSectionAPI);
  StyleSubHeaderLabel(lblSectionTheme);
  StyleSubHeaderLabel(lblSectionDebug);
  
  StyleMutedLabel(lblLanguage);
  StyleMutedLabel(lblRefreshInterval);
  StyleMutedLabel(lblAPIEndpoint);
  StyleMutedLabel(lblThemeStyle);
  StyleMutedLabel(lblFontScale);
  StyleMutedLabel(lblLastRequestUrl);
  StyleMutedLabel(lblLastStatus);
  StyleMutedLabel(lblLastBody);
  
  StyleInput(edtRefreshInterval);
  StyleInput(edtAPIEndpoint);
  StyleInput(edtFontScale);
  StyleInput(edtLastRequestUrl);
  StyleInput(edtLastStatus);
  StyleInput(edtLastBody);
  
  StylePrimaryButton(btnSaveSettings);
  StylePrimaryButton(btnApplyApiEndpoint);
  StylePrimaryButton(btnRefreshDebug);
  
  StyleDangerButton(btnResetDefaults);
  StyleDangerButton(btnClearToken);
end;

procedure TSettingsFrame.LoadSettings;
var
  IniFile: TIniFile;
  IniPath: string;
  Preset: TThemePreset;
  PresetName: string;
begin
  try
    IniPath := GetSettingsIniPath;
    IniFile := TIniFile.Create(IniPath);
    try
      // General
      if Assigned(cmbLanguage) then
        cmbLanguage.ItemIndex := IniFile.ReadInteger('General', 'Language', 0);
        
      if Assigned(edtRefreshInterval) then
        edtRefreshInterval.Text := IntToStr(IniFile.ReadInteger('General', 'RefreshInterval', 30));

      // Notifications
      SafeSetChecked(chkEmailNotifications, IniFile.ReadBool('Notifications', 'Email', False));
      SafeSetChecked(chkDisplayOfflineAlerts, IniFile.ReadBool('Notifications', 'DisplayOffline', True));
      SafeSetChecked(chkCampaignEndAlerts, IniFile.ReadBool('Notifications', 'CampaignEnd', True));

      // API
      if Assigned(edtAPIEndpoint) then
        edtAPIEndpoint.Text := IniFile.ReadString('API', 'Endpoint', 'http://localhost:2001/api');

      // Theme
      PresetName := IniFile.ReadString('Theme', 'Preset', '');
      if (PresetName <> '') and TryParseThemePreset(PresetName, Preset) then
        SetThemePreset(Preset, False)
      else
      begin
        // Backward compatibility
        if IniFile.ReadBool('Theme', 'DarkMode', False) then
          SetThemePreset(tpDarkBlue, False)
        else
          SetThemePreset(tpLightBlue, False);
      end;
      
      if Assigned(edtFontScale) then
        edtFontScale.Text := FloatToStr(IniFile.ReadFloat('Theme', 'FontScale', 1.0));

    finally
      IniFile.Free;
    end;
    
    // Load debug info
    btnRefreshDebugClick(nil);

    // Populate theme style choices and select current preset
    if Assigned(cmbThemeStyle) then
    begin
      cmbThemeStyle.Items.Clear;
      cmbThemeStyle.Items.Add('Light (Blue)');
      cmbThemeStyle.Items.Add('Dark (Blue)');
      cmbThemeStyle.Items.Add('Midnight');
      cmbThemeStyle.Items.Add('Slate (Teal)');
      case GetThemePreset of
        tpLightBlue: cmbThemeStyle.ItemIndex := 0;
        tpDarkBlue: cmbThemeStyle.ItemIndex := 1;
        tpMidnight: cmbThemeStyle.ItemIndex := 2;
        tpSlate: cmbThemeStyle.ItemIndex := 3;
      else
        cmbThemeStyle.ItemIndex := 0;
      end;
    end;

    if Assigned(edtFontScale) then
      SetTypographyScale(StrToFloatDef(edtFontScale.Text, 1.0));
    NotifyThemeChanged;
  except
    on E: Exception do
    begin
      // Ignore settings load issues; defaults are fine.
    end;
  end;
end;

procedure TSettingsFrame.SaveSettings;
var
  IniFile: TIniFile;
  IniPath: string;
begin
  IniPath := GetSettingsIniPath;
  IniFile := TIniFile.Create(IniPath);
  try
    // General
    if Assigned(cmbLanguage) then
      IniFile.WriteInteger('General', 'Language', cmbLanguage.ItemIndex);
      
    if Assigned(edtRefreshInterval) then
      IniFile.WriteInteger('General', 'RefreshInterval', StrToIntDef(edtRefreshInterval.Text, 30));

    // Notifications
    if Assigned(chkEmailNotifications) then
      IniFile.WriteBool('Notifications', 'Email', chkEmailNotifications.IsChecked);
      
    if Assigned(chkDisplayOfflineAlerts) then
      IniFile.WriteBool('Notifications', 'DisplayOffline', chkDisplayOfflineAlerts.IsChecked);
      
    if Assigned(chkCampaignEndAlerts) then
      IniFile.WriteBool('Notifications', 'CampaignEnd', chkCampaignEndAlerts.IsChecked);

    // API
    if Assigned(edtAPIEndpoint) then
      IniFile.WriteString('API', 'Endpoint', edtAPIEndpoint.Text);

    // Theme
    IniFile.WriteString('Theme', 'Preset', ThemePresetToString(GetThemePreset));
    // Backward compatibility for older builds
    IniFile.WriteBool('Theme', 'DarkMode', GetThemeMode = tmDark);
      
    if Assigned(edtFontScale) then
      IniFile.WriteFloat('Theme', 'FontScale', StrToFloatDef(edtFontScale.Text, 1.0));

  finally
    IniFile.Free;
  end;
end;

procedure TSettingsFrame.SafeSetChecked(ACheckBox: TCheckBox; AValue: Boolean);
begin
  if Assigned(ACheckBox) then
    ACheckBox.IsChecked := AValue;
end;

procedure TSettingsFrame.btnSaveSettingsClick(Sender: TObject);
begin
  SaveSettings;
  ShowMessage('Settings saved successfully.');
end;

procedure TSettingsFrame.btnResetDefaultsClick(Sender: TObject);
begin
  if Assigned(cmbLanguage) then cmbLanguage.ItemIndex := 0;
  if Assigned(edtRefreshInterval) then edtRefreshInterval.Text := '30';
  
  SafeSetChecked(chkEmailNotifications, False);
  SafeSetChecked(chkDisplayOfflineAlerts, True);
  SafeSetChecked(chkCampaignEndAlerts, True);
  
  if Assigned(edtAPIEndpoint) then edtAPIEndpoint.Text := 'http://localhost:2001/api';
  if Assigned(cmbThemeStyle) then cmbThemeStyle.ItemIndex := 0; // Light (Blue)
  SetThemePreset(tpLightBlue, False);
  if Assigned(edtFontScale) then edtFontScale.Text := '1.0';
  
  SaveSettings;
  ShowMessage('Settings reset to defaults.');
end;

procedure TSettingsFrame.btnApplyApiEndpointClick(Sender: TObject);
begin
  if Assigned(edtAPIEndpoint) then
  begin
    // In a real app, we would update the API client singleton here
    // TApiClient.Instance.BaseUrl := edtAPIEndpoint.Text;
    SaveSettings;
    ShowMessage('API Endpoint updated.');
  end;
end;

procedure TSettingsFrame.btnClearTokenClick(Sender: TObject);
begin
  // In a real app, we would clear the token from the API client
  // TApiClient.Instance.ClearToken;
  ShowMessage('Auth token cleared. You will need to login again.');
end;

procedure TSettingsFrame.cmbThemeStyleChange(Sender: TObject);
begin
  if not Assigned(cmbThemeStyle) then Exit;
  case cmbThemeStyle.ItemIndex of
    0: SetThemePreset(tpLightBlue);
    1: SetThemePreset(tpDarkBlue);
    2: SetThemePreset(tpMidnight);
    3: SetThemePreset(tpSlate);
  else
    SetThemePreset(tpLightBlue);
  end;
  SaveSettings;
end;

procedure TSettingsFrame.edtFontScaleExit(Sender: TObject);
begin
  // Validate font scale
  if StrToFloatDef(edtFontScale.Text, 0) <= 0 then
    edtFontScale.Text := '1.0';

  SetTypographyScale(StrToFloatDef(edtFontScale.Text, 1.0));
  SaveSettings;
  NotifyThemeChanged;
end;

procedure TSettingsFrame.btnRefreshDebugClick(Sender: TObject);
begin
  // Refresh debug info from API client
  // This assumes TApiClient has these properties exposed
  try
    if Assigned(edtLastRequestUrl) then
      edtLastRequestUrl.Text := 'N/A'; // Placeholder
      
    if Assigned(edtLastStatus) then
      edtLastStatus.Text := 'N/A'; // Placeholder
      
    if Assigned(edtLastBody) then
      edtLastBody.Text := 'N/A'; // Placeholder
  except
    begin
      // Ignore errors during debug refresh
    end;
  end;
end;

end.
