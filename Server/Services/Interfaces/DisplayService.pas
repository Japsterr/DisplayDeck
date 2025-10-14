unit DisplayService;

interface

uses
  XData.Service.Common,
  uEntities;

type
  [ServiceContract]
  [Route('')]
  IDisplayService = interface(IInvokable)
    ['{54EA2414-6554-4D81-98BE-2A9516EF1E56}']
    [HttpGet]
    [Route('organizations/{OrganizationId}/displays')]
    function GetDisplays(OrganizationId: Integer): TArray<TDisplay>;
    [HttpGet]
    [Route('displays/{Id}')]
    function GetDisplay(Id: Integer): TDisplay;
    [HttpPost]
    [Route('organizations/{OrganizationId}/displays')]
    function CreateDisplay(OrganizationId: Integer; const Name, Orientation, CurrentStatus, ProvisioningToken: string): TDisplay;
    [HttpPut]
    [Route('displays/{Id}')]
    function UpdateDisplay(Id: Integer; const Name, Orientation, CurrentStatus: string): TDisplay;
    [HttpDelete]
    [Route('displays/{Id}')]
    procedure DeleteDisplay(Id: Integer);
  end;

implementation

end.

