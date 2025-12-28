unit uAppSettings;

interface

function GetSettingsIniPath: string;

implementation

uses
  System.IOUtils, System.SysUtils;

function GetSettingsIniPath: string;
var
  SettingsDir: string;
begin
  // Per-user, per-machine settings (Windows-only app, but path is cross-platform safe)
  SettingsDir := TPath.Combine(TPath.GetHomePath, 'DisplayDeckManager');
  if not TDirectory.Exists(SettingsDir) then
    TDirectory.CreateDirectory(SettingsDir);

  Result := TPath.Combine(SettingsDir, 'DisplayDeck.ini');
end;

end.
