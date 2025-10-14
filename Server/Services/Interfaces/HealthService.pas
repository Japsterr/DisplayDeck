unit HealthService;

interface

uses
  XData.Service.Common;

type
  [ServiceContract]
  [Route('')]
  IHealthService = interface(IInvokable)
    ['{B3B2F5B6-2F7F-4C62-8C09-5B9C6F9B0FAE}']
    [HttpGet]
    [Route('health')]
    function Health: string;
  end;

implementation

initialization
  RegisterServiceType(TypeInfo(IHealthService));

end.
