unit CampaignItemServiceImplementation;

interface

uses
  XData.Server.Module,
  XData.Service.Common,
  CampaignItemService;

type
  [ServiceImplementation]
  TCampaignItemService = class(TInterfacedObject, ICampaignItemService)
  end;

implementation


initialization
  RegisterServiceType(TCampaignItemService);

end.
