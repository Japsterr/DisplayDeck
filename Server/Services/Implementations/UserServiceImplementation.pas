unit UserServiceImplementation;

interface

uses
  XData.Server.Module,
  XData.Service.Common,
  UserService;

type
  [ServiceImplementation]
  TUserService = class(TInterfacedObject, IUserService)
  end;

implementation


initialization
  RegisterServiceType(TUserService);

end.
