unit uAssignmentService;

interface

uses System.SysUtils, System.JSON, uApiClient;

type
  TAssignmentService = class
  private
    class var FInstance: TAssignmentService;
  public
    procedure AssignCampaignToDisplay(const OrgId, DisplayId, CampaignId: Integer);
    class property Instance: TAssignmentService read FInstance;
  end;

implementation

procedure TAssignmentService.AssignCampaignToDisplay(const OrgId, DisplayId, CampaignId: Integer);
var Body: TJSONObject; Path: string;
begin
  Body := TJSONObject.Create;
  try
    Body.AddPair('CampaignId', TJSONNumber.Create(CampaignId));
    Body.AddPair('IsPrimary', TJSONBool.Create(True));
    Path := Format('/displays/%d/campaign-assignments', [DisplayId]);
    ApiClient.PostJson(Path, Body);
  finally
    Body.Free;
  end;
end;

initialization
  TAssignmentService.FInstance := TAssignmentService.Create;

finalization
  TAssignmentService.FInstance.Free;

end.
