unit AuthService;

interface

uses
  XData.Service.Common,
  uEntities;

type
  TLoginRequest = class
  private
    FEmail: string;
    FPassword: string;
  public
    property Email: string read FEmail write FEmail;
    property Password: string read FPassword write FPassword;
  end;

  TRegisterRequest = class
  private
    FEmail: string;
    FPassword: string;
    FOrganizationName: string;
  public
    property Email: string read FEmail write FEmail;
    property Password: string read FPassword write FPassword;
    property OrganizationName: string read FOrganizationName write FOrganizationName;
  end;

  TAuthResponse = class
  private
    FToken: string;
    FUser: TUser;
    FSuccess: Boolean;
    FMessage: string;
  public
    constructor Create;
    destructor Destroy; override;
    property Token: string read FToken write FToken;
    property User: TUser read FUser write FUser;
    property Success: Boolean read FSuccess write FSuccess;
    property Message: string read FMessage write FMessage;
  end;

  [ServiceContract]
  [Route('')]
  IAuthService = interface(IInvokable)
    ['{12345678-1234-1234-1234-123456789ABC}']
    [HttpPost]
    [Route('auth/register')]
    function Register(const Request: TRegisterRequest): TAuthResponse;
    [HttpPost]
    [Route('auth/login')]
    function Login(const Request: TLoginRequest): TAuthResponse;
  end;

implementation

{ TAuthResponse }

constructor TAuthResponse.Create;
begin
  inherited;
  FUser := nil;
  FSuccess := False;
end;

destructor TAuthResponse.Destroy;
begin
  if Assigned(FUser) then
    FUser.Free;
  inherited;
end;

initialization
  RegisterServiceType(TypeInfo(IAuthService));

end.