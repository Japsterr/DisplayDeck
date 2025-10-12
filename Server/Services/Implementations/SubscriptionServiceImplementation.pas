unit SubscriptionServiceImplementation;

interface

uses
  XData.Server.Module,
  XData.Service.Common,
  SubscriptionService;

type
  [ServiceImplementation]
  TSubscriptionService = class(TInterfacedObject, ISubscriptionService)
  end;

implementation


initialization
  RegisterServiceType(TSubscriptionService);

end.
