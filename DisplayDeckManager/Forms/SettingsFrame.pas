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
    procedure btnSaveSettingsClick(Sender: TObject);
    procedure btnResetDefaultsClick(Sender: TObject);
    procedure btnRefreshDebugClick(Sender: TObject);
  private
    procedure LoadSettings;
    procedure SaveSettings;
    procedure ResetToDefaults;
    procedure PopulateDebugInfo;
  public
    procedure Initialize;
  end;

implementation

{$R *.fmx}

uses
  System.JSON, FMX.DialogService, FMX.DialogService.Sync, System.IniFiles;

// Settings are stored locally in an INI file
// Future: Could sync to API for user preferences

procedure TFrame9.Initialize;
begin
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
      cmbLanguage.ItemIndex := IniFile.ReadInteger('General', 'Language', 0);
      edtRefreshInterval.Text := IniFile.ReadString('General', 'RefreshInterval', '30');
      chkEmailNotifications.IsChecked := IniFile.ReadBool('Notifications', 'Email', True);
      chkDisplayOfflineAlerts.IsChecked := IniFile.ReadBool('Notifications', 'DisplayOffline', True);
      chkCampaignEndAlerts.IsChecked := IniFile.ReadBool('Notifications', 'CampaignEnd', True);
      edtAPIEndpoint.Text := IniFile.ReadString('API', 'Endpoint', 'http://localhost:2001/tms/xdata');
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
  finally
    IniFile.Free;
  end;
end;

procedure TFrame9.ResetToDefaults;
begin
  cmbLanguage.ItemIndex := 0;
  edtRefreshInterval.Text := '30';
  chkEmailNotifications.IsChecked := True;
  chkDisplayOfflineAlerts.IsChecked := True;
  chkCampaignEndAlerts.IsChecked := True;
  edtAPIEndpoint.Text := 'http://localhost:2001/tms/xdata';
end;

procedure TFrame9.btnSaveSettingsClick(Sender: TObject);
begin
  SaveSettings;
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

procedure TFrame9.btnRefreshDebugClick(Sender: TObject);
begin
  PopulateDebugInfo;
end;

end.
