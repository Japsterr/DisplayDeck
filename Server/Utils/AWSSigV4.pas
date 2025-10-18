unit AWSSigV4;

interface

uses
  System.SysUtils, System.Classes, System.DateUtils, System.NetEncoding, System.Hash;

type
  TS3PresignParams = record
    Endpoint: string;      // e.g., http://minio:9000
    Region: string;        // e.g., us-east-1
    Bucket: string;        // e.g., displaydeck
    ObjectKey: string;     // e.g., media/123/file.png
    AccessKey: string;
    SecretKey: string;
    Method: string;        // 'GET' or 'PUT'
    ExpiresSeconds: Integer; // up to 7 days
    ContentType: string;   // optional, for PUT signing
  end;

function BuildS3PresignedUrl(const P: TS3PresignParams; out Url: string): Boolean;

implementation

function UriEncode(const S: string; const EncodeSlash: Boolean): string;
var
  I: Integer;
  Ch: Char;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    Ch := S[I];
    case Ch of
      'A'..'Z','a'..'z','0'..'9','-','_','.','~': Result := Result + Ch;
      '/': if EncodeSlash then Result := Result + '%2F' else Result := Result + Ch;
    else
      Result := Result + '%' + IntToHex(Ord(Ch), 2).ToUpper;
    end;
  end;
end;

function HmacSHA256(const Key, Data: TBytes): TBytes;
begin
  Result := THashSHA2.GetHMACAsBytes(Data, Key);
end;

function SHA256Hex(const S: string): string;
begin
  Result := THashSHA2.GetHashString(S);
end;

function DeriveSigningKey(const Secret, DateStamp, Region, Service: string): TBytes;
var
  KDate, KRegion, KService, KSigning: TBytes;
begin
  KDate := HmacSHA256(TEncoding.UTF8.GetBytes('AWS4' + Secret), TEncoding.UTF8.GetBytes(DateStamp));
  KRegion := HmacSHA256(KDate, TEncoding.UTF8.GetBytes(Region));
  KService := HmacSHA256(KRegion, TEncoding.UTF8.GetBytes(Service));
  KSigning := HmacSHA256(KService, TEncoding.UTF8.GetBytes('aws4_request'));
  Result := KSigning;
end;

function ISO8601BasicUTCNow(out DateStamp, AmzDate: string): TDateTime;
var
  U: TDateTime;
begin
  U := Now;
  DateStamp := FormatDateTime('yyyymmdd', TTimeZone.Local.ToUniversalTime(U));
  AmzDate := FormatDateTime('yyyymmdd"T"hhnnss"Z"', TTimeZone.Local.ToUniversalTime(U));
  Result := U;
end;

function BuildS3PresignedUrl(const P: TS3PresignParams; out Url: string): Boolean;
var
  DateStamp, AmzDate, CredentialScope, Credential, Algorithm: string;
  CanonicalUri, Host, SignedHeaders, CanonicalHeaders, CanonicalQuery, CanonicalRequest, StringToSign: string;
  DerivedKey: TBytes;
  Signature: string;
  Service: string;
  ExpiresStr: string;
  Uri: TURI;
begin
  Result := False;
  Url := '';
  if (P.Endpoint = '') or (P.Region = '') or (P.Bucket = '') or (P.ObjectKey = '') or (P.AccessKey = '') or (P.SecretKey = '') then
    Exit;

  Service := 's3';
  ISO8601BasicUTCNow(DateStamp, AmzDate);
  CredentialScope := DateStamp + '/' + P.Region + '/' + Service + '/aws4_request';
  Credential := P.AccessKey + '/' + CredentialScope;
  Algorithm := 'AWS4-HMAC-SHA256';
  ExpiresStr := IntToStr(P.ExpiresSeconds);

  // Build host and canonical URI (path-style)
  // Endpoint may include protocol and port; extract host:port
  Uri := TURI.Create(P.Endpoint);
  if Uri.Host <> '' then
    Host := Uri.Host
  else
    Host := P.Endpoint; // naive fallback
  if (Uri.Port > 0) and (Uri.Port <> 80) and (Uri.Port <> 443) then
    Host := Host + ':' + Uri.Port.ToString;

  CanonicalUri := '/' + UriEncode(P.Bucket, True) + '/' + UriEncode(P.ObjectKey, True);

  SignedHeaders := 'host';
  CanonicalHeaders := 'host:' + Host.ToLower + #10;

  // Canonical query string (sorted by key)
  CanonicalQuery :=
    'X-Amz-Algorithm=' + Algorithm + '&' +
    'X-Amz-Credential=' + UriEncode(Credential, True) + '&' +
    'X-Amz-Date=' + AmzDate + '&' +
    'X-Amz-Expires=' + ExpiresStr + '&' +
    'X-Amz-SignedHeaders=' + SignedHeaders;

  // For unsigned payload
  CanonicalRequest := P.Method + #10 +
                      CanonicalUri + #10 +
                      CanonicalQuery + #10 +
                      CanonicalHeaders + #10 +
                      SignedHeaders + #10 +
                      'UNSIGNED-PAYLOAD';

  StringToSign := Algorithm + #10 +
                  AmzDate + #10 +
                  CredentialScope + #10 +
                  THashSHA2.GetHashString(CanonicalRequest).ToLower;

  DerivedKey := DeriveSigningKey(P.SecretKey, DateStamp, P.Region, Service);
  Signature := THash.DigestAsString(THashSHA2.GetHMACAsBytes(TEncoding.UTF8.GetBytes(StringToSign), DerivedKey)).ToLower;

  Url := P.Endpoint.TrimRight(['/']) + CanonicalUri + '?' + CanonicalQuery + '&X-Amz-Signature=' + Signature;
  Result := True;
end;

end.
