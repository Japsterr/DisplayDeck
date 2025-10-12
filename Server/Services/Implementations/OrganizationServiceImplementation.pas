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
  Aurelius.Engine.ObjectManager;

function TOrganizationService.GetOrganizations: TList<TOrganization>;
begin
  Result := TXDataOperationContext.Current.GetManager.Find<TOrganization>.List;
end;

function TOrganizationService.GetOrganization(id: integer): TOrganization;
begin
  Result := TXDataOperationContext.Current.GetManager.Find<TOrganization>(id);
end;

function TOrganizationService.CreateOrganization(const organization: TOrganization): TOrganization;
begin
  TXDataOperationContext.Current.GetManager.Save(organization);
  Result := organization;
end;

initialization
  RegisterServiceType(TOrganizationService);

end.
