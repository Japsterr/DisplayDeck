unit DisplayServiceImplementation;

interface

uses
  XData.Server.Module,
  XData.Service.Common,
  DisplayService;

type
  [ServiceImplementation]
  TDisplayService = class(TInterfacedObject, IDisplayService)
  end;

implementation


initialization
  RegisterServiceType(TDisplayService);

end.
