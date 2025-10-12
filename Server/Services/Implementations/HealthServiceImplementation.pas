unit HealthServiceImplementation;

interface

uses
  XData.Server.Module,
  XData.Service.Common,
  HealthService;

type
  [ServiceImplementation]
  THealthService = class(TInterfacedObject, IHealthService)
  public
    function Health: string;
  end;

implementation

function THealthService.Health: string;
begin
  Result := 'OK';
end;

initialization
  RegisterServiceType(THealthService);

end.
