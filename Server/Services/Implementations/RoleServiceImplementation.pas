unit RoleServiceImplementation;

interface

uses
  System.SysUtils,
  XData.Server.Module,
  XData.Service.Common,
  RoleService;

type
  [ServiceImplementation]
  TRoleService = class(TInterfacedObject, IRoleService)
  public
    function GetRoles: TArray<string>;
  end;

implementation


{ TRoleService }

function TRoleService.GetRoles: TArray<string>;
begin
  // Static role set for now; could be database-driven later
  SetLength(Result, 3);
  Result[0] := 'Owner';
  Result[1] := 'ContentManager';
  Result[2] := 'Viewer';
end;

initialization
  RegisterServiceType(TRoleService);

end.
