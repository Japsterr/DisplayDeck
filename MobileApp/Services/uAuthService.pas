unit uAuthService;

interface

uses System.SysUtils, System.JSON, uApiClient, uModels;

type
  TAuthService = class
  private
    FCurrentUser: TUser;
    FToken: string;
    class var FInstance: TAuthService;
  public
    function Login(const Email, Password: string): Boolean;
    function Register(const Email, Password, OrganizationName: string): Boolean;
    property CurrentUser: TUser read FCurrentUser;
    property Token: string read FToken;
    class property Instance: TAuthService read FInstance;
  end;

implementation

function ParseUser(const Obj: TJSONObject): TUser;
begin
  Result.Id := Obj.GetValue<Integer>('Id',0);
  Result.OrganizationId := Obj.GetValue<Integer>('OrganizationId',0);
  Result.Email := Obj.GetValue<string>('Email','');
  Result.Role := Obj.GetValue<string>('Role','');
end;

{ TAuthService }

function TAuthService.Login(const Email, Password: string): Boolean;
var Body: TJSONObject; Resp: string; Obj, U: TJSONObject;
begin
  Result := False;
  Body := TJSONObject.Create;
  try
    Body.AddPair('Email', Email);
    Body.AddPair('Password', Password);
    Resp := ApiClient.PostJson('/auth/login', Body);
    Obj := TJSONObject.ParseJSONValue(Resp) as TJSONObject;
    try
      FToken := Obj.GetValue<string>('Token','');
      U := Obj.GetValue<TJSONObject>('User');
      if FToken <> '' then
      begin
        ApiClient.SetToken(FToken);
        FCurrentUser := ParseUser(U);
        Result := True;
      end;
    finally
      Obj.Free;
    end;
  finally
    Body.Free;
  end;
end;

function TAuthService.Register(const Email, Password, OrganizationName: string): Boolean;
var Body: TJSONObject; Resp: string; Obj, U: TJSONObject;
begin
  Result := False;
  Body := TJSONObject.Create;
  try
    Body.AddPair('Email', Email);
    Body.AddPair('Password', Password);
    Body.AddPair('OrganizationName', OrganizationName);
    Resp := ApiClient.PostJson('/auth/register', Body);
    Obj := TJSONObject.ParseJSONValue(Resp) as TJSONObject;
    try
      FToken := Obj.GetValue<string>('Token','');
      U := Obj.GetValue<TJSONObject>('User');
      if FToken <> '' then
      begin
        ApiClient.SetToken(FToken);
        FCurrentUser := ParseUser(U);
        Result := True;
      end;
    finally
      Obj.Free;
    end;
  finally
    Body.Free;
  end;
end;

initialization
  TAuthService.FInstance := TAuthService.Create;

finalization
  TAuthService.FInstance.Free;

end.
