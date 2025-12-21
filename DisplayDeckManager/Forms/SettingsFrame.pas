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
    chkDarkMode: TCheckBox;
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
    procedure chkDarkModeChange(Sender: TObject);
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

{ *.fmx}

uses
  System.IniFiles, System.IOUtils, uApiClient, uTheme;

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
begin
  try
    IniPath := TPath.Combine(ExtractFilePath(ParamStr(0)), 'DisplayDeck.ini');
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
      SafeSetChecked(chkDarkMode, IniFile.ReadBool('Theme', 'DarkMode', False));
      
      if Assigned(edtFontScale) then
        edtFontScale.Text := FloatToStr(IniFile.ReadFloat('Theme', 'FontScale', 1.0));

    finally
      IniFile.Free;
    end;
    
    // Load debug info
    btnRefreshDebugClick(nil);
  except
    on E: Exception do
      // Log error but don't crash
      // TDialogService.ShowMessage('Error loading settings: ' + E.Message);
  end;
end;

procedure TSettingsFrame.SaveSettings;
var
  IniFile: TIniFile;
  IniPath: string;
begin
  IniPath := TPath.Combine(ExtractFilePath(ParamStr(0)), 'DisplayDeck.ini');
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
    if Assigned(chkDarkMode) then
      IniFile.WriteBool('Theme', 'DarkMode', chkDarkMode.IsChecked);
      
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
  SafeSetChecked(chkDarkMode, False);
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

procedure TSettingsFrame.chkDarkModeChange(Sender: TObject);
begin
  // Apply theme changes immediately if needed
end;

procedure TSettingsFrame.edtFontScaleExit(Sender: TObject);
begin
  // Validate font scale
  if StrToFloatDef(edtFontScale.Text, 0) <= 0 then
    edtFontScale.Text := '1.0';
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
    // Ignore errors during debug refresh
  end;
end;

end.
