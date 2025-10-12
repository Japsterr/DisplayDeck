unit CampaignItemService;

interface

uses
  XData.Service.Common,
  uEntities;

type
  [ServiceContract]
  ICampaignItemService = interface(IInvokable)
    ['{D72DD672-E77B-435D-88D1-0528BD575C32}']
    function GetCampaignItems(CampaignId: Integer): TArray<TCampaignItem>;
    function GetCampaignItem(Id: Integer): TCampaignItem;
    function CreateCampaignItem(CampaignId, MediaFileId, DisplayOrder, Duration: Integer): TCampaignItem;
    function UpdateCampaignItem(Id, MediaFileId, DisplayOrder, Duration: Integer): TCampaignItem;
    procedure DeleteCampaignItem(Id: Integer);
  end;

implementation

end.

