unit CampaignService;

interface

uses
  XData.Service.Common,
  uEntities;

type
  [ServiceContract]
  [Route('')]
  ICampaignService = interface(IInvokable)
    ['{CC7D2682-B42B-4C49-B17F-FB4554D48DE7}']
    // List campaigns for an organization
    [HttpGet]
    [Route('organizations/{OrganizationId}/campaigns')]
    function GetCampaigns(OrganizationId: Integer): TArray<TCampaign>;
    // Get single campaign by id
    [HttpGet]
    [Route('campaigns/{Id}')]
    function GetCampaign(Id: Integer): TCampaign;
    // Create a campaign for an organization
    [HttpPost]
    [Route('organizations/{OrganizationId}/campaigns')]
    function CreateCampaign(OrganizationId: Integer; const Name, Orientation: string): TCampaign;
    // Update a campaign
    [HttpPut]
    [Route('campaigns/{Id}')]
    function UpdateCampaign(Id: Integer; const Name, Orientation: string): TCampaign;
    // Delete a campaign
    [HttpDelete]
    [Route('campaigns/{Id}')]
    procedure DeleteCampaign(Id: Integer);
  end;

implementation

end.

