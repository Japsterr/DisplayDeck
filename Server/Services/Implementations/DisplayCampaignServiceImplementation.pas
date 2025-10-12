unit DisplayCampaignServiceImplementation;

interface

uses
  XData.Server.Module,
  XData.Service.Common,
  DisplayCampaignService;

type
  [ServiceImplementation]
  TDisplayCampaignService = class(TInterfacedObject, IDisplayCampaignService)
  end;

implementation


initialization
  RegisterServiceType(TDisplayCampaignService);

end.
