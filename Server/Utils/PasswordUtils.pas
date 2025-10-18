unit PasswordUtils;

interface

uses System.SysUtils, System.Hash;

function GenerateSalt: string;
function HashPassword(const Password, Salt: string; Iterations: Integer = 100000): string;
function VerifyPassword(const Password, Salt, StoredHash: string; Iterations: Integer = 100000): Boolean;

implementation

function GenerateSalt: string;
var
  G: TGUID;
begin
  CreateGUID(G);
  Result := GUIDToString(G);
end;

function HashPassword(const Password, Salt: string; Iterations: Integer): string;
var
  I: Integer;
  Data: string;
begin
  Data := Password + '|' + Salt;
  Result := THashSHA2.GetHashString(Data);
  for I := 2 to Iterations do
    Result := THashSHA2.GetHashString(Result + Salt);
end;

function VerifyPassword(const Password, Salt, StoredHash: string; Iterations: Integer): Boolean;
begin
  Result := SameText(HashPassword(Password, Salt, Iterations), StoredHash);
end;

end.
