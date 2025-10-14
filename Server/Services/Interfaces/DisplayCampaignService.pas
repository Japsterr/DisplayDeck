unit DisplayCampaignService;

interface

uses
  XData.Service.Common,
  uEntities;

type
  [ServiceContract]
  [Route('')]
  IDisplayCampaignService = interface(IInvokable)
    ['{4D123058-3BB5-4CF2-B040-E8C18D85811D}']
    [HttpGet]
    [Route('displays/{DisplayId}/campaign-assignments')]
    function GetDisplayCampaigns(DisplayId: Integer): TArray<TDisplayCampaign>;
    [HttpGet]
    [Route('campaign-assignments/{Id}')]
    function GetDisplayCampaign(Id: Integer): TDisplayCampaign;
    [HttpPost]
    [Route('displays/{DisplayId}/campaign-assignments')]
    function CreateDisplayCampaign(DisplayId, CampaignId: Integer; IsPrimary: Boolean): TDisplayCampaign;
    [HttpPut]
    [Route('campaign-assignments/{Id}')]
    function UpdateDisplayCampaign(Id: Integer; IsPrimary: Boolean): TDisplayCampaign;
    [HttpDelete]
    [Route('campaign-assignments/{Id}')]
    procedure DeleteDisplayCampaign(Id: Integer);
  end;

implementation

end.

