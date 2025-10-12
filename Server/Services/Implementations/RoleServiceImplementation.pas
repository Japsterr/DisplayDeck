unit RoleServiceImplementation;

interface

uses
  XData.Server.Module,
  XData.Service.Common,
  RoleService;

type
  [ServiceImplementation]
  TRoleService = class(TInterfacedObject, IRoleService)
  end;

implementation


initialization
  RegisterServiceType(TRoleService);

end.
