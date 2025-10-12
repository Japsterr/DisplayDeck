unit DisplayCampaignService;

interface

uses
  XData.Service.Common,
  uEntities;

type
  [ServiceContract]
  IDisplayCampaignService = interface(IInvokable)
    ['{4D123058-3BB5-4CF2-B040-E8C18D85811D}']
    function GetDisplayCampaigns(DisplayId: Integer): TArray<TDisplayCampaign>;
    function GetDisplayCampaign(Id: Integer): TDisplayCampaign;
    function CreateDisplayCampaign(DisplayId, CampaignId: Integer; IsPrimary: Boolean): TDisplayCampaign;
    function UpdateDisplayCampaign(Id: Integer; IsPrimary: Boolean): TDisplayCampaign;
    procedure DeleteDisplayCampaign(Id: Integer);
  end;

implementation

end.

