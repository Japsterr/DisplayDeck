unit DisplayService;

interface

uses
  XData.Service.Common,
  uEntities;

type
  [ServiceContract]
  IDisplayService = interface(IInvokable)
    ['{54EA2414-6554-4D81-98BE-2A9516EF1E56}']
    function GetDisplays(OrganizationId: Integer): TArray<TDisplay>;
    function GetDisplay(Id: Integer): TDisplay;
    function CreateDisplay(OrganizationId: Integer; const Name, Orientation, CurrentStatus, ProvisioningToken: string): TDisplay;
    function UpdateDisplay(Id: Integer; const Name, Orientation, CurrentStatus: string): TDisplay;
    procedure DeleteDisplay(Id: Integer);
  end;

implementation

end.

