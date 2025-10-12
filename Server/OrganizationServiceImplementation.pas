unit OrganizationServiceImplementation;

interface

uses
  XData.Server.Module,
  XData.Service.Common,
  OrganizationService,
  uEntities,
  System.Generics.Collections;

type
  [ServiceImplementation]
  TOrganizationService = class(TInterfacedObject, IOrganizationService)
  public
    function GetOrganizations: TList<TOrganization>;
    function GetOrganization(id: integer): TOrganization;
    function CreateOrganization(const organization: TOrganization): TOrganization;
  end;

implementation

uses
  System.SysUtils,
  OrganizationRepository;

function TOrganizationService.GetOrganizations: TList<TOrganization>;
begin
  Result := TOrganizationRepository.GetOrganizations;
end;

function TOrganizationService.GetOrganization(id: integer): TOrganization;
begin
  Result := TOrganizationRepository.GetOrganization(id);
end;

function TOrganizationService.CreateOrganization(const organization: TOrganization): TOrganization;
begin
  if organization = nil then
    raise EArgumentNilException.Create('Organization payload is required.');

  Result := TOrganizationRepository.CreateOrganization(organization);
end;

initialization
  RegisterServiceType(TOrganizationService);

end.
