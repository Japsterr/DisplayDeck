unit uCampaignService;

interface

uses System.SysUtils, System.JSON, System.Generics.Collections, uApiClient, uModels;

type
  TCampaignService = class
  private
    class var FInstance: TCampaignService;
  public
    function ListCampaigns(const OrgId: Integer): TArray<TCampaign>;
    class property Instance: TCampaignService read FInstance;
  end;

implementation

function TCampaignService.ListCampaigns(const OrgId: Integer): TArray<TCampaign>;
var Resp: string; Obj: TJSONObject; Arr: TJSONArray; I: Integer; C: TCampaign;
begin
  SetLength(Result,0);
  Resp := ApiClient.Get(Format('/organizations/%d/campaigns', [OrgId]));
  Obj := TJSONObject.ParseJSONValue(Resp) as TJSONObject;
  try
    Arr := Obj.GetValue<TJSONArray>('value');
    if Arr <> nil then
    begin
      SetLength(Result, Arr.Count);
      for I := 0 to Arr.Count-1 do
      begin
        C.Id := Arr.Items[I].GetValue<Integer>('Id',0);
        C.Name := Arr.Items[I].GetValue<string>('Name','');
        C.Orientation := Arr.Items[I].GetValue<string>('Orientation','');
        Result[I] := C;
      end;
    end;
  finally
    Obj.Free;
  end;
end;

initialization
  TCampaignService.FInstance := TCampaignService.Create;

finalization
  TCampaignService.FInstance.Free;

end.
