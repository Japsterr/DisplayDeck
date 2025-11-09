unit AWSSigV4;

interface

uses
  System.SysUtils, System.Classes, System.DateUtils, System.NetEncoding, System.Hash, System.Net.URLClient,
  System.Generics.Collections;

type
  TS3PresignParams = record
    Endpoint: string;
    Region: string;
    Bucket: string;
    ObjectKey: string;
    AccessKey: string;
    SecretKey: string;
    Method: string;        // 'GET' or 'PUT'
    ExpiresSeconds: Integer; // up to 7 days
  end;

function BuildS3PresignedUrl(const P: TS3PresignParams; out Url: string): Boolean;

implementation

function DebugEnabled: Boolean;
begin
  Result := SameText(GetEnvironmentVariable('SIGV4_DEBUG'), 'true');
end;

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

function BuildS3PresignedUrl(const P: TS3PresignParams; out Url: string): Boolean;
var
  DateStamp, AmzDate, CredentialScope, Credential, Algorithm: string;
  CanonicalUri, Host, SignedHeaders, CanonicalHeaders, CanonicalQuery, CanonicalRequest, StringToSign: string;
  Signature: string;
  Service: string;
  ExpiresStr: string;
  Uri: TURI;
  QueryPairs: TArray<string>;
  i: Integer;
begin
  Result := False;
  Url := '';
  if (P.Endpoint = '') or (P.Region = '') or (P.Bucket = '') or (P.ObjectKey = '') or (P.AccessKey = '') or (P.SecretKey = '') then
    Exit;

  Service := 's3';
  // ISO8601 Basic UTC
  DateStamp := FormatDateTime('yyyymmdd', TTimeZone.Local.ToUniversalTime(Now));
  AmzDate := FormatDateTime('yyyymmdd"T"hhnnss"Z"', TTimeZone.Local.ToUniversalTime(Now));
  CredentialScope := DateStamp + '/' + P.Region + '/' + Service + '/aws4_request';
  Credential := P.AccessKey + '/' + CredentialScope;
  Algorithm := 'AWS4-HMAC-SHA256';
  ExpiresStr := IntToStr(P.ExpiresSeconds);

  // Host and path-style URI
  Uri := TURI.Create(P.Endpoint);
  if Uri.Host <> '' then
    Host := Uri.Host
  else
    Host := P.Endpoint;
  if (Uri.Port > 0) and (Uri.Port <> 80) and (Uri.Port <> 443) then
    Host := Host + ':' + Uri.Port.ToString;

  CanonicalUri := '/' + UriEncode(P.Bucket, False) + '/' + UriEncode(P.ObjectKey, False);
  SignedHeaders := 'host';
  CanonicalHeaders := 'host:' + Host.ToLower + #10;
  // Build sorted canonical query parameters per AWS SigV4 spec
  SetLength(QueryPairs, 5);
  QueryPairs[0] := 'X-Amz-Algorithm=' + UriEncode(Algorithm, True);
  QueryPairs[1] := 'X-Amz-Credential=' + UriEncode(Credential, True);
  QueryPairs[2] := 'X-Amz-Date=' + UriEncode(AmzDate, True);
  QueryPairs[3] := 'X-Amz-Expires=' + UriEncode(ExpiresStr, True);
  QueryPairs[4] := 'X-Amz-SignedHeaders=' + UriEncode(SignedHeaders, True);
  // Sort by parameter name
  TArray.Sort<string>(QueryPairs);
  CanonicalQuery := '';
  for i := 0 to High(QueryPairs) do
  begin
    if CanonicalQuery <> '' then
      CanonicalQuery := CanonicalQuery + '&';
    CanonicalQuery := CanonicalQuery + QueryPairs[i];
  end;

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

  // Derive signing key
  var KDate := HmacSHA256(TEncoding.UTF8.GetBytes('AWS4' + P.SecretKey), TEncoding.UTF8.GetBytes(DateStamp));
  var KRegion := HmacSHA256(KDate, TEncoding.UTF8.GetBytes(P.Region));
  var KService := HmacSHA256(KRegion, TEncoding.UTF8.GetBytes(Service));
  var KSigning := HmacSHA256(KService, TEncoding.UTF8.GetBytes('aws4_request'));
  var SigBytes := THashSHA2.GetHMACAsBytes(TEncoding.UTF8.GetBytes(StringToSign), KSigning);
  // Proper lowercase hex conversion avoiding Ansi/Unicode pointer issues
  var idx: Integer; var sb: TStringBuilder;
  sb := TStringBuilder.Create(Length(SigBytes)*2);
  try
    for idx := 0 to High(SigBytes) do
      sb.Append(LowerCase(IntToHex(SigBytes[idx], 2)));
    Signature := sb.ToString;
  finally
    sb.Free;
  end;

  // Ensure endpoint has no trailing slash, then append canonical path and query. Endpoint may already include scheme and host.
  Url := P.Endpoint.TrimRight(['/']) + CanonicalUri + '?' + CanonicalQuery + '&X-Amz-Signature=' + Signature;
  if DebugEnabled then
  begin
    WriteLn('SIGV4 CanonicalRequest>>');
    WriteLn(CanonicalRequest);
    WriteLn('SIGV4 StringToSign>>');
    WriteLn(StringToSign);
    WriteLn('SIGV4 URL>>');
    WriteLn(Url);
  end;
  Result := True;
end;

end.
