unit JWTUtils;

interface

uses System.SysUtils, System.JSON;

function Base64UrlEncode(const Bytes: TBytes): string;
function Base64UrlDecode(const S: string): TBytes;
function CreateJWT(const Header, Payload: TJSONObject; const Secret: string): string;
function VerifyJWT(const Token, Secret: string; out Payload: TJSONObject): Boolean;

implementation

uses System.NetEncoding, System.Hash, System.Classes;

function DebugEnabled: Boolean;
begin
  // Avoid depending on SysUtils here; environment variable check is enough
  Result := SameText(string(GetEnvironmentVariable('SERVER_DEBUG')), 'true');
end;

function Base64UrlEncode(const Bytes: TBytes): string;
var S: string;
begin
  S := TNetEncoding.Base64.EncodeBytesToString(Bytes);
  // Remove any line breaks that some encoders insert
  S := S.Replace(#13, '').Replace(#10, '');
  // Convert to base64url
  Result := S.Replace('+','-').Replace('/','_').TrimRight(['=']);
end;

function Base64UrlDecode(const S: string): TBytes;
var Padded: string;
begin
  // Remove any accidental line breaks/whitespace
  Padded := S.Replace(#13,'').Replace(#10,'').Replace(' ', '');
  while (Length(Padded) mod 4) <> 0 do Padded := Padded + '=';
  Padded := Padded.Replace('-','+').Replace('_','/');
  Result := TNetEncoding.Base64.DecodeStringToBytes(Padded);
end;

function CreateJWT(const Header, Payload: TJSONObject; const Secret: string): string;
var
  H, P, SigningInput: string;
  SigBytes: TBytes;
begin
  H := Base64UrlEncode(TEncoding.UTF8.GetBytes(Header.ToJSON));
  P := Base64UrlEncode(TEncoding.UTF8.GetBytes(Payload.ToJSON));
  SigningInput := H + '.' + P;
  // Explicitly use SHA-256 for HS256 JWT signatures
  SigBytes := THashSHA2.GetHMACAsBytes(
    TEncoding.UTF8.GetBytes(SigningInput),
    TEncoding.UTF8.GetBytes(Secret),
    THashSHA2.TSHA2Version.SHA256
  );
  Result := SigningInput + '.' + Base64UrlEncode(SigBytes);
end;

function VerifyJWT(const Token, Secret: string; out Payload: TJSONObject): Boolean;
var Parts: TArray<string>; SigningInput: string; ExpectedSig, ActualSig: TBytes; i: Integer; diff: Byte;
begin
  Result := False;
  Payload := nil;
  Parts := Token.Split(['.']);
  if Length(Parts) <> 3 then Exit;
  SigningInput := Parts[0] + '.' + Parts[1];
  ExpectedSig := THashSHA2.GetHMACAsBytes(
    TEncoding.UTF8.GetBytes(SigningInput),
    TEncoding.UTF8.GetBytes(Secret),
    THashSHA2.TSHA2Version.SHA256
  );
  ActualSig := Base64UrlDecode(Parts[2]);
  // DEBUG: print quick diagnostic of signature compare
  if DebugEnabled then
  try
    var ExpectedB64 := Base64UrlEncode(ExpectedSig);
    var ActualB64 := Parts[2].Replace(#13,'').Replace(#10,'');
    Writeln(Format('VerifyJWT secretLen=%d signingInputLen=%d expectedLen=%d actualLen=%d expectedB64=%s actualB64=%s',
      [Length(Secret), Length(SigningInput), Length(ExpectedSig), Length(ActualSig), ExpectedB64, ActualB64]));
  except
  end;
  if Length(ExpectedSig) <> Length(ActualSig) then Exit;
  diff := 0;
  for i := 0 to Length(ExpectedSig)-1 do
    diff := diff or (ExpectedSig[i] xor ActualSig[i]);
  if diff <> 0 then Exit;
  Payload := TJSONObject.ParseJSONValue(TEncoding.UTF8.GetString(Base64UrlDecode(Parts[1]))) as TJSONObject;
  Result := Payload <> nil;
end;

end.
