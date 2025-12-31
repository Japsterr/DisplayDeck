unit Main;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.IOUtils, System.JSON,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.StdCtrls, FMX.Layouts, FMX.TabControl, FMX.Edit, FMX.ScrollBox,
  FMX.WebBrowser;

type
  TAppSettings = record
    ApiUrl: string;
    DisplayUrl: string;
    DeviceName: string;
  end;

type
  TForm1 = class(TForm)
    ToolBar1: TToolBar;
    lblTitle: TLabel;
    btnReload: TButton;
    btnSettings: TButton;
    TabControl1: TTabControl;
    TabItemDisplay: TTabItem;
    TabItemSettings: TTabItem;
    WebBrowser1: TWebBrowser;
    LayoutOverlay: TLayout;
    lblStatus: TLabel;
    VertScrollBox1: TVertScrollBox;
    LayoutDeviceName: TLayout;
    LabelDeviceName: TLabel;
    EditDeviceName: TEdit;
    LayoutApiUrl: TLayout;
    LabelApiUrl: TLabel;
    EditApiUrl: TEdit;
    LayoutDisplayUrl: TLayout;
    LabelDisplayUrl: TLabel;
    EditDisplayUrl: TEdit;
    LayoutButtons: TLayout;
    btnSave: TButton;
    btnBackToDisplay: TButton;
    procedure FormCreate(Sender: TObject);
    procedure btnSettingsClick(Sender: TObject);
    procedure btnBackToDisplayClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure btnReloadClick(Sender: TObject);
  private
    FSettings: TAppSettings;
    function GetSettingsPath: string;
    procedure LoadSettings;
    procedure SaveSettings;
    procedure ApplySettingsToUi;
    procedure ApplyUiToSettings;
    procedure NavigateIfPossible;
    procedure ShowDisplay;
    procedure ShowSettings;
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.fmx}
{$R *.LgXhdpiTb.fmx ANDROID}

function TForm1.GetSettingsPath: string;
begin
  Result := TPath.Combine(TPath.GetDocumentsPath, 'displaydeck_settings.json');
end;

procedure TForm1.LoadSettings;
var
  jsonText: string;
  jsonValue: TJSONValue;
  obj: TJSONObject;

  function GetString(const Key: string; const DefaultValue: string): string;
  var
    v: TJSONValue;
  begin
    Result := DefaultValue;
    if (obj <> nil) and obj.TryGetValue<TJSONValue>(Key, v) and (v <> nil) then
      Result := v.Value;
  end;

begin
  FSettings.ApiUrl := 'https://api.displaydeck.co.za';
  FSettings.DisplayUrl := '';
  FSettings.DeviceName := GetEnvironmentVariable('COMPUTERNAME');
  if FSettings.DeviceName.Trim.IsEmpty then
    FSettings.DeviceName := 'Display';

  if not TFile.Exists(GetSettingsPath) then
    Exit;

  try
    jsonText := TFile.ReadAllText(GetSettingsPath, TEncoding.UTF8);
    jsonValue := TJSONObject.ParseJSONValue(jsonText);
    try
      if not (jsonValue is TJSONObject) then
        Exit;
      obj := TJSONObject(jsonValue);

      // Accept both casing styles.
      FSettings.ApiUrl := GetString('ApiUrl', GetString('apiUrl', FSettings.ApiUrl));
      FSettings.DisplayUrl := GetString('DisplayUrl', GetString('displayUrl', FSettings.DisplayUrl));
      FSettings.DeviceName := GetString('DeviceName', GetString('deviceName', FSettings.DeviceName));
    finally
      jsonValue.Free;
    end;
  except
    // Ignore parse errors; fall back to defaults.
  end;
end;

procedure TForm1.SaveSettings;
var
  obj: TJSONObject;
begin
  obj := TJSONObject.Create;
  try
    obj.AddPair('ApiUrl', FSettings.ApiUrl);
    obj.AddPair('DisplayUrl', FSettings.DisplayUrl);
    obj.AddPair('DeviceName', FSettings.DeviceName);
    TFile.WriteAllText(GetSettingsPath, obj.ToJSON, TEncoding.UTF8);
  finally
    obj.Free;
  end;
end;

procedure TForm1.ApplySettingsToUi;
begin
  EditApiUrl.Text := FSettings.ApiUrl;
  EditDisplayUrl.Text := FSettings.DisplayUrl;
  EditDeviceName.Text := FSettings.DeviceName;
end;

procedure TForm1.ApplyUiToSettings;
begin
  FSettings.ApiUrl := EditApiUrl.Text.Trim;
  FSettings.DisplayUrl := EditDisplayUrl.Text.Trim;
  FSettings.DeviceName := EditDeviceName.Text.Trim;

  if FSettings.ApiUrl.IsEmpty then
    FSettings.ApiUrl := 'https://api.displaydeck.co.za';
end;

procedure TForm1.NavigateIfPossible;
begin
  if FSettings.DisplayUrl.Trim.IsEmpty then
  begin
    lblStatus.Text := 'No Display URL configured. Open Settings to set it.';
    LayoutOverlay.Visible := True;
    Exit;
  end;

  try
    LayoutOverlay.Visible := False;
    WebBrowser1.Navigate(FSettings.DisplayUrl);
  except
    LayoutOverlay.Visible := True;
    lblStatus.Text := 'Failed to open Display URL.';
  end;
end;

procedure TForm1.ShowDisplay;
begin
  TabControl1.ActiveTab := TabItemDisplay;
end;

procedure TForm1.ShowSettings;
begin
  TabControl1.ActiveTab := TabItemSettings;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  LoadSettings;
  ApplySettingsToUi;
  ShowDisplay;
  NavigateIfPossible;
end;

procedure TForm1.btnSettingsClick(Sender: TObject);
begin
  ShowSettings;
end;

procedure TForm1.btnBackToDisplayClick(Sender: TObject);
begin
  ShowDisplay;
end;

procedure TForm1.btnSaveClick(Sender: TObject);
begin
  ApplyUiToSettings;
  SaveSettings;
  ShowDisplay;
  NavigateIfPossible;
end;

procedure TForm1.btnReloadClick(Sender: TObject);
begin
  NavigateIfPossible;
end;

end.
