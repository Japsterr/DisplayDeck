unit CampaignService;

interface

uses
  XData.Service.Common,
  uEntities;

type
  [ServiceContract]
  ICampaignService = interface(IInvokable)
    ['{CC7D2682-B42B-4C49-B17F-FB4554D48DE7}']
    
    function GetCampaigns(OrganizationId: Integer): TArray<TCampaign>;
    function GetCampaign(Id: Integer): TCampaign;
    function CreateCampaign(OrganizationId: Integer; const Name, Orientation: string): TCampaign;
    function UpdateCampaign(Id: Integer; const Name, Orientation: string): TCampaign;
    procedure DeleteCampaign(Id: Integer);
  end;

implementation

end.

