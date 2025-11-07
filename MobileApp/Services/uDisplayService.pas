unit uDisplayService;

interface

uses System.SysUtils, System.JSON, System.Generics.Collections, uApiClient, uAuthService, uModels;

type
  TDisplayService = class
  private
    class var FInstance: TDisplayService;
  public
    function ListDisplays(const OrgId: Integer): TArray<TDisplay>;
    procedure ClaimDisplay(const OrgId: Integer; const ProvisioningToken, Name, Orientation: string);
    class property Instance: TDisplayService read FInstance;
  end;

implementation

{ TDisplayService }

procedure TDisplayService.ClaimDisplay(const OrgId: Integer; const ProvisioningToken, Name, Orientation: string);
var Body: TJSONObject; Resp: string;
begin
  Body := TJSONObject.Create;
  try
    Body.AddPair('ProvisioningToken', ProvisioningToken);
    Body.AddPair('Name', Name);
    Body.AddPair('Orientation', Orientation);
    Resp := ApiClient.PostJson(Format('/organizations/%d/displays/claim', [OrgId]), Body);
  finally
    Body.Free;
  end;
end;

function TDisplayService.ListDisplays(const OrgId: Integer): TArray<TDisplay>;
var Resp: string; Obj: TJSONObject; Arr: TJSONArray; I: Integer; D: TDisplay;
begin
  SetLength(Result,0);
  Resp := ApiClient.Get(Format('/organizations/%d/displays', [OrgId]));
  Obj := TJSONObject.ParseJSONValue(Resp) as TJSONObject;
  try
    Arr := Obj.GetValue<TJSONArray>('value');
    if Arr <> nil then
    begin
      SetLength(Result, Arr.Count);
      for I := 0 to Arr.Count-1 do
      begin
        D.Id := Arr.Items[I].GetValue<Integer>('Id',0);
        D.Name := Arr.Items[I].GetValue<string>('Name','');
        D.Orientation := Arr.Items[I].GetValue<string>('Orientation','');
        Result[I] := D;
      end;
    end;
  finally
    Obj.Free;
  end;
end;

initialization
  TDisplayService.FInstance := TDisplayService.Create;

finalization
  TDisplayService.FInstance.Free;

end.
