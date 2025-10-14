unit RoleService;

interface

uses
  XData.Service.Common;

type
  [ServiceContract]
  [Route('')]
  IRoleService = interface(IInvokable)
    ['{CAAA4BB4-066C-4BE1-A52A-AED0B5B67E17}']
    [HttpGet]
    [Route('roles')]
    function GetRoles: TArray<string>; // Could be static list for now
  end;

implementation

end.

