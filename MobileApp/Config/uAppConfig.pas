unit uAppConfig;

interface

uses System.SysUtils, System.IOUtils, System.JSON;

type
  TAppConfig = class
  public
    class function BaseUrl: string; static;
    class procedure SetBaseUrl(const AUrl: string); static;
    class procedure Save; static;
    class procedure Load; static;
  end;

implementation

var
  GBaseUrl: string = '';

function ConfigFilePath: string;
begin
  Result := TPath.Combine(TPath.GetDocumentsPath, 'displaydeck.config.json');
end;

class function TAppConfig.BaseUrl: string;
begin
  if GBaseUrl = '' then
  begin
    Load;
    if GBaseUrl = '' then
      GBaseUrl := 'http://10.0.2.2:2001';
  end;
  Result := GBaseUrl;
end;

class procedure TAppConfig.SetBaseUrl(const AUrl: string);
begin
  GBaseUrl := AUrl;
end;

class procedure TAppConfig.Save;
var Obj: TJSONObject; S: string;
begin
  Obj := TJSONObject.Create;
  try
    Obj.AddPair('BaseUrl', GBaseUrl);
    S := Obj.ToJSON;
  finally
    Obj.Free;
  end;
  TFile.WriteAllText(ConfigFilePath, S, TEncoding.UTF8);
end;

class procedure TAppConfig.Load;
var S: string; Obj: TJSONObject;
begin
  if not TFile.Exists(ConfigFilePath) then Exit;
  S := TFile.ReadAllText(ConfigFilePath, TEncoding.UTF8);
  Obj := TJSONObject.ParseJSONValue(S) as TJSONObject;
  try
    if Assigned(Obj) then
      GBaseUrl := Obj.GetValue<string>('BaseUrl', GBaseUrl);
  finally
    Obj.Free;
  end;
end;

end.
