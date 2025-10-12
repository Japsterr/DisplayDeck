unit OrganizationService;

interface

uses
  uEntities,
  XData.Service.Common,
  System.Generics.Collections;

type
  [ServiceContract]
  IOrganizationService = interface(IInvokable)
    ['{2611F906-12DC-48A5-A982-9B3107B0166B}']

  [HttpGet]
  [Route('organizations')]
    function GetOrganizations: TList<TOrganization>;

  [HttpGet]
  [Route('organizations/{id}')]
    function GetOrganization(id: integer): TOrganization;

  [HttpPost]
  [Route('organizations')]
    function CreateOrganization(const organization: TOrganization): TOrganization;
  end;

implementation

initialization
  RegisterServiceType(TypeInfo(IOrganizationService));

end.

