unit PlanServiceImplementation;

interface

uses
  XData.Server.Module,
  XData.Service.Common,
  PlanService;

type
  [ServiceImplementation]
  TPlanService = class(TInterfacedObject, IPlanService)
  end;

implementation


initialization
  RegisterServiceType(TPlanService);

end.
