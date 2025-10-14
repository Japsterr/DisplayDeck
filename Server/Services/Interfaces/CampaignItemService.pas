unit CampaignItemService;

interface

uses
  XData.Service.Common,
  uEntities;

type
  [ServiceContract]
  [Route('')]
  ICampaignItemService = interface(IInvokable)
    ['{D72DD672-E77B-435D-88D1-0528BD575C32}']
    [HttpGet]
    [Route('campaigns/{CampaignId}/items')]
    function GetCampaignItems(CampaignId: Integer): TArray<TCampaignItem>;
    [HttpGet]
    [Route('campaign-items/{Id}')]
    function GetCampaignItem(Id: Integer): TCampaignItem;
    [HttpPost]
    [Route('campaigns/{CampaignId}/items')]
    function CreateCampaignItem(CampaignId, MediaFileId, DisplayOrder, Duration: Integer): TCampaignItem;
    [HttpPut]
    [Route('campaign-items/{Id}')]
    function UpdateCampaignItem(Id, MediaFileId, DisplayOrder, Duration: Integer): TCampaignItem;
    [HttpDelete]
    [Route('campaign-items/{Id}')]
    procedure DeleteCampaignItem(Id: Integer);
  end;

implementation

end.

