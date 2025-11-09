unit SettingsFrame;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants, 
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.Objects, FMX.Layouts, FMX.Edit, FMX.ListBox,
  System.IOUtils, uApiClient;

type
  TFrame9 = class(TFrame)
    LayoutBackground: TLayout;
    RectBackground: TRectangle;
    LayoutMain: TLayout;
    RectCard: TRectangle;
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
    lblSectionAPI: TLabel;
    lblAPIEndpoint: TLabel;
    edtAPIEndpoint: TEdit;
    LayoutButtons: TLayout;
    lblSectionDebug: TLabel;
    lblLastRequestUrl: TLabel;
    edtLastRequestUrl: TEdit;
    lblLastStatus: TLabel;
    edtLastStatus: TEdit;
    lblLastBody: TLabel;
    edtLastBody: TEdit;
    btnRefreshDebug: TButton;
    btnApplyApiEndpoint: TButton;
    btnClearToken: TButton;
    chkDarkMode: TCheckBox;
    lblFontScale: TLabel;
    edtFontScale: TEdit;
    procedure btnSaveSettingsClick(Sender: TObject);
    procedure btnResetDefaultsClick(Sender: TObject);
    procedure btnRefreshDebugClick(Sender: TObject);
    procedure btnApplyApiEndpointClick(Sender: TObject);
    procedure btnClearTokenClick(Sender: TObject);
    procedure chkDarkModeChange(Sender: TObject);
    procedure edtFontScaleExit(Sender: TObject);
  private
    procedure LoadSettings;
    procedure SaveSettings;
    procedure ResetToDefaults;
    procedure PopulateDebugInfo;
    procedure SafeSetChecked(const ABox: TCheckBox; const AValue: Boolean);
  public
    procedure Initialize;
  end;

implementation

{$R *.fmx}

uses
  System.JSON, FMX.DialogService, FMX.DialogService.Sync, System.IniFiles, uTheme;
procedure TFrame9.SafeSetChecked(const ABox: TCheckBox; const AValue: Boolean);
begin
  if ABox = nil then Exit;
  if ABox.Root = nil then
  begin
    TThread.Queue(nil,
      procedure
      begin
        if ABox <> nil then
        begin
          ABox.ApplyStyleLookup;
          ABox.IsChecked := AValue;
        end;
      end);
  end
  else
  begin
    ABox.ApplyStyleLookup;
    ABox.IsChecked := AValue;
  end;
end;


// Settings are stored locally in an INI file
// Future: Could sync to API for user preferences

procedure TFrame9.Initialize;
begin
  // Ensure language list is populated before we set ItemIndex
  if cmbLanguage.Items.Count = 0 then
  begin
    cmbLanguage.Items.Add('English');
    cmbLanguage.Items.Add('Dutch');
    cmbLanguage.Items.Add('French');
  end;
  LoadSettings;
  PopulateDebugInfo;
end;

procedure TFrame9.LoadSettings;
var
  IniFile: TIniFile;
  SettingsPath: string;
begin
  // Load settings from INI file
  SettingsPath := TPath.Combine(TPath.GetDocumentsPath, 'DisplayDeck.ini');
  
  if TFile.Exists(SettingsPath) then
  begin
    IniFile := TIniFile.Create(SettingsPath);
    try
      var LangIndex := IniFile.ReadInteger('General', 'Language', 0);
      if (cmbLanguage.Items.Count > 0) then
      begin
        if (LangIndex < 0) or (LangIndex >= cmbLanguage.Items.Count) then
          LangIndex := 0;
        cmbLanguage.ItemIndex := LangIndex;
      end;
      edtRefreshInterval.Text := IniFile.ReadString('General', 'RefreshInterval', '30');
      chkEmailNotifications.IsChecked := IniFile.ReadBool('Notifications', 'Email', True);
      chkDisplayOfflineAlerts.IsChecked := IniFile.ReadBool('Notifications', 'DisplayOffline', True);
      chkCampaignEndAlerts.IsChecked := IniFile.ReadBool('Notifications', 'CampaignEnd', True);
      edtAPIEndpoint.Text := IniFile.ReadString('API', 'Endpoint', 'http://localhost:2001/api');
      SafeSetChecked(chkDarkMode, IniFile.ReadBool('Theme', 'DarkMode', False));
      edtFontScale.Text := IniFile.ReadString('Theme', 'FontScale', '1.0');
      if chkDarkMode.IsChecked then SetThemeMode(tmDark) else SetThemeMode(tmLight);
      SetTypographyScale(StrToFloatDef(edtFontScale.Text,1.0));
    finally
      IniFile.Free;
    end;
  end
  else
    ResetToDefaults;
end;

procedure TFrame9.SaveSettings;
var
  IniFile: TIniFile;
  SettingsPath: string;
begin
  SettingsPath := TPath.Combine(TPath.GetDocumentsPath, 'DisplayDeck.ini');
  
  IniFile := TIniFile.Create(SettingsPath);
  try
    IniFile.WriteInteger('General', 'Language', cmbLanguage.ItemIndex);
    IniFile.WriteString('General', 'RefreshInterval', edtRefreshInterval.Text);
    IniFile.WriteBool('Notifications', 'Email', chkEmailNotifications.IsChecked);
    IniFile.WriteBool('Notifications', 'DisplayOffline', chkDisplayOfflineAlerts.IsChecked);
    IniFile.WriteBool('Notifications', 'CampaignEnd', chkCampaignEndAlerts.IsChecked);
    IniFile.WriteString('API', 'Endpoint', edtAPIEndpoint.Text);
    IniFile.WriteBool('Theme', 'DarkMode', chkDarkMode.IsChecked);
    IniFile.WriteString('Theme', 'FontScale', edtFontScale.Text);
  finally
    IniFile.Free;
  end;
end;

procedure TFrame9.ResetToDefaults;
begin
  if cmbLanguage.Items.Count = 0 then
  begin
    cmbLanguage.Items.Add('English');
    cmbLanguage.Items.Add('Dutch');
    cmbLanguage.Items.Add('French');
  end;
  if cmbLanguage.Items.Count > 0 then
    cmbLanguage.ItemIndex := 0;
  edtRefreshInterval.Text := '30';
  chkEmailNotifications.IsChecked := True;
  chkDisplayOfflineAlerts.IsChecked := True;
  chkCampaignEndAlerts.IsChecked := True;
  edtAPIEndpoint.Text := 'http://localhost:2001/api';
  SafeSetChecked(chkDarkMode, False);
  edtFontScale.Text := '1.0';
  SetThemeMode(tmLight);
  SetTypographyScale(1.0);
end;

procedure TFrame9.btnSaveSettingsClick(Sender: TObject);
begin
  SaveSettings;
  // Apply API endpoint to client as well
  if Trim(edtAPIEndpoint.Text) <> '' then
    TApiClient.Instance.UpdateBaseURL(Trim(edtAPIEndpoint.Text));
  if chkDarkMode.IsChecked then SetThemeMode(tmDark) else SetThemeMode(tmLight);
  SetTypographyScale(StrToFloatDef(edtFontScale.Text,1.0));
  ShowMessage('Settings saved successfully');
end;

procedure TFrame9.btnResetDefaultsClick(Sender: TObject);
begin
  if TDialogServiceSync.MessageDialog('Are you sure you want to reset all settings to defaults?',
     TMsgDlgType.mtConfirmation, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], TMsgDlgBtn.mbNo, 0) = mrYes then
  begin
    ResetToDefaults;
    ShowMessage('Settings reset to defaults');
  end;
end;

procedure TFrame9.PopulateDebugInfo;
begin
  if TApiClient.Instance <> nil then
  begin
    edtLastRequestUrl.Text := TApiClient.Instance.LastURL;
    edtLastStatus.Text := IntToStr(TApiClient.Instance.LastResponseCode);
    edtLastBody.Text := Copy(TApiClient.Instance.LastResponseBody, 1, 4000); // truncate for UI
  end;
end;

procedure TFrame9.btnApplyApiEndpointClick(Sender: TObject);
var
  NewUrl: string;
begin
  NewUrl := Trim(edtAPIEndpoint.Text);
  if NewUrl = '' then
  begin
    ShowMessage('API endpoint cannot be empty');
    Exit;
  end;
  TApiClient.Instance.UpdateBaseURL(NewUrl);
  SaveSettings;
  ShowMessage('API endpoint updated');
end;

procedure TFrame9.btnClearTokenClick(Sender: TObject);
begin
  if TApiClient.Instance.GetAuthToken <> '' then
  begin
    TApiClient.Instance.ClearAuthToken;
    ShowMessage('Auth token cleared');
  end
  else
    ShowMessage('No token stored');
end;

procedure TFrame9.chkDarkModeChange(Sender: TObject);
begin
  if chkDarkMode.IsChecked then SetThemeMode(tmDark) else SetThemeMode(tmLight);
end;

procedure TFrame9.edtFontScaleExit(Sender: TObject);
var
  FS: Single;
begin
  FS := StrToFloatDef(edtFontScale.Text,1.0);
  SetTypographyScale(FS);
end;

procedure TFrame9.btnRefreshDebugClick(Sender: TObject);
begin
  PopulateDebugInfo;
end;

end.
