unit uAppSession;

interface

uses
  System.SysUtils;

type
  TAppSession = record
    Token: string;
    UserId: Integer;
    OrganizationId: Integer;
    UserName: string;
    UserEmail: string;
    OrganizationName: string;
    class function Empty: TAppSession; static;
    function IsAuthenticated: Boolean;
  end;

implementation

{ TAppSession }

class function TAppSession.Empty: TAppSession;
begin
  Result.Token := '';
  Result.UserId := 0;
  Result.OrganizationId := 0;
  Result.UserName := '';
  Result.UserEmail := '';
  Result.OrganizationName := '';
end;

function TAppSession.IsAuthenticated: Boolean;
begin
  Result := (Token.Trim <> '') and (UserId > 0) and (OrganizationId > 0);
end;

end.
