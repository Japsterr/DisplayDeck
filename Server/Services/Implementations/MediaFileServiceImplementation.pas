unit MediaFileServiceImplementation;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Net.HttpClient,
  System.Net.URLClient,
  System.Hash,
  System.DateUtils,
  XData.Server.Module,
  XData.Service.Common,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  Data.DB,
  uEntities,
  MediaFileService;

type
  [ServiceImplementation]
  TMediaFileService = class(TInterfacedObject, IMediaFileService)
  private
    function GetConnection: TFDConnection;
    function GenerateMinIOPreSignedUrl(const Method, Bucket, Key: string; ExpiresInSeconds: Integer): string;
    function GenerateStorageKey(OrganizationId: Integer; const FileName: string): string;
    // SigV4 helpers (dev-quality; for production prefer official SDK)
  function HmacSHA256(const Key, Data: TBytes): TBytes;
    function Sha256Hex(const S: string): string;
    function ToHex(const Bytes: TBytes): string;
    function UrlEncodeRFC3986(const S: string): string;
  function UrlEncodeRFC3986Strict(const S: string): string;
  function EnvOrDefault(const Name, DefaultValue: string): string;
  public
    function GetMediaFiles(OrganizationId: Integer): TArray<TMediaFile>;
    function GetMediaFile(Id: Integer): TMediaFile;
    function CreateMediaFile(OrganizationId: Integer; const FileName, FileType, StorageURL: string): TMediaFile;
    function UpdateMediaFile(Id: Integer; const FileName, FileType, StorageURL: string): TMediaFile;
    procedure DeleteMediaFile(Id: Integer);
    function GetUploadUrl(const Request: TUploadUrlRequest): TUploadUrlResponse;
    function GetDownloadUrl(MediaFileId: Integer): TDownloadUrlResponse;
  end;

implementation

uses
  uServerContainer;

{ TMediaFileService }

function TMediaFileService.GetConnection: TFDConnection;
begin
  // Get the shared connection from the server container
  Result := ServerContainer.FDConnection;
end;

function TMediaFileService.GenerateStorageKey(OrganizationId: Integer; const FileName: string): string;
var
  Timestamp: string;
  Guid: TGUID;
begin
  CreateGUID(Guid);
  Timestamp := FormatDateTime('yyyymmddhhnnss', Now);
  Result := Format('org-%d/%s-%s-%s', [OrganizationId, Timestamp, GUIDToString(Guid), FileName]);
end;

function TMediaFileService.GenerateMinIOPreSignedUrl(const Method, Bucket, Key: string; ExpiresInSeconds: Integer): string;
var
  Region, Service, Algorithm: string;
  NowUtc: TDateTime;
  AmzDate, DateStamp: string;
  Host, CanonicalUri, CanonicalQuery, SignedHeaders, CanonicalHeaders, PayloadHash: string;
  CredentialScope, StringToSign: string;
  CanonicalRequest: string;
  KDate, KRegion, KService, KSigning, SignatureBytes: TBytes;
  Signature: string;
  EndpointUri: TURI;
  Q: TStringList;
  i: Integer;
  Name, Value: string;
  MINIO_ENDPOINT, MINIO_ACCESS_KEY, MINIO_SECRET_KEY: string;
begin
  // Implement AWS SigV4 pre-signed URL (minimal)
  // Reference: https://docs.aws.amazon.com/AmazonS3/latest/API/sigv4-query-string-auth.html
  // Read configuration from environment, or fall back to sensible defaults
  MINIO_ENDPOINT := EnvOrDefault('MINIO_ENDPOINT', 'http://localhost:9000');
  MINIO_ACCESS_KEY := EnvOrDefault('MINIO_ACCESS_KEY', 'minioadmin');
  MINIO_SECRET_KEY := EnvOrDefault('MINIO_SECRET_KEY', 'minioadmin');
  Region := EnvOrDefault('MINIO_REGION', 'us-east-1');
  Service := 's3';
  Algorithm := 'AWS4-HMAC-SHA256';
  NowUtc := TTimeZone.Local.ToUniversalTime(Now);
  AmzDate := FormatDateTime('yyyymmdd"T"hhnnss"Z"', NowUtc);
  DateStamp := Copy(AmzDate, 1, 8);

  EndpointUri := TURI.Create(MINIO_ENDPOINT);
  Host := EndpointUri.Host;
  if EndpointUri.Port <> 0 then
    Host := Host + ':' + EndpointUri.Port.ToString;

  CanonicalUri := '/' + UrlEncodeRFC3986(Bucket) + '/' + UrlEncodeRFC3986(Key);

  Q := TStringList.Create;
  try
    Q.NameValueSeparator := '=';
    Q.Values['X-Amz-Algorithm'] := Algorithm;
    Q.Values['X-Amz-Credential'] := MINIO_ACCESS_KEY + '/' + DateStamp + '/' + Region + '/' + Service + '/aws4_request';
    Q.Values['X-Amz-Date'] := AmzDate;
    Q.Values['X-Amz-Expires'] := IntToStr(ExpiresInSeconds);
    Q.Values['X-Amz-SignedHeaders'] := 'host';
    // Build sorted canonical query string
    Q.Sort;
    CanonicalQuery := '';
    for i := 0 to Q.Count - 1 do
    begin
      Name := Q.Names[i];
      Value := Copy(Q[i], Length(Name) + 2, MaxInt);
      if CanonicalQuery <> '' then CanonicalQuery := CanonicalQuery + '&';
      CanonicalQuery := CanonicalQuery + UrlEncodeRFC3986(Name) + '=' + UrlEncodeRFC3986Strict(Value);
    end;
  finally
    Q.Free;
  end;

  SignedHeaders := 'host';
  CanonicalHeaders := 'host:' + Host + #10;
  PayloadHash := 'UNSIGNED-PAYLOAD';

  CanonicalRequest := Method + #10 +
                      CanonicalUri + #10 +
                      CanonicalQuery + #10 +
                      CanonicalHeaders + #10 +
                      SignedHeaders + #10 +
                      PayloadHash;

  CredentialScope := DateStamp + '/' + Region + '/' + Service + '/aws4_request';
  StringToSign := Algorithm + #10 +
                  AmzDate + #10 +
                  CredentialScope + #10 +
                  Sha256Hex(CanonicalRequest);

  // Derive signing key
  KDate := HmacSHA256(TEncoding.UTF8.GetBytes('AWS4' + MINIO_SECRET_KEY), TEncoding.UTF8.GetBytes(DateStamp));
  KRegion := HmacSHA256(KDate, TEncoding.UTF8.GetBytes(Region));
  KService := HmacSHA256(KRegion, TEncoding.UTF8.GetBytes(Service));
  KSigning := HmacSHA256(KService, TEncoding.UTF8.GetBytes('aws4_request'));
  SignatureBytes := HmacSHA256(KSigning, TEncoding.UTF8.GetBytes(StringToSign));
  Signature := ToHex(SignatureBytes).ToLower;

  // Final URL: endpoint + canonical uri + canonical query + signature
  Result := MINIO_ENDPOINT + CanonicalUri + '?' + CanonicalQuery + '&X-Amz-Signature=' + Signature;
end;

function TMediaFileService.GetUploadUrl(const Request: TUploadUrlRequest): TUploadUrlResponse;
var
  StorageKey: string;
  UploadUrl: string;
begin
  Result := TUploadUrlResponse.Create;
  try
    // Generate unique storage key
    StorageKey := GenerateStorageKey(Request.OrganizationId, Request.FileName);

    // Generate pre-signed upload URL
    UploadUrl := GenerateMinIOPreSignedUrl('PUT', 'displaydeck-media', StorageKey, 3600); // 1 hour expiry

    // Create media file record in database and return its id
    var Created := CreateMediaFile(Request.OrganizationId, Request.FileName, Request.FileType, StorageKey);
    try
      Result.MediaFileId := Created.Id;
    finally
      Created.Free;
    end;

    Result.Success := True;
    Result.UploadUrl := UploadUrl;
    Result.StorageKey := StorageKey;
    Result.Message := 'Upload URL generated successfully';
  except
    on E: Exception do
    begin
      Result.Success := False;
      Result.Message := 'Failed to generate upload URL: ' + E.Message;
    end;
  end;
end;

function TMediaFileService.GetDownloadUrl(MediaFileId: Integer): TDownloadUrlResponse;
var
  MediaFile: TMediaFile;
  DownloadUrl: string;
begin
  Result := TDownloadUrlResponse.Create;
  try
    // Get media file from database
    MediaFile := GetMediaFile(MediaFileId);
    if not Assigned(MediaFile) then
    begin
      Result.Success := False;
      Result.Message := 'Media file not found';
      Exit;
    end;

    try
      // Generate pre-signed download URL
      DownloadUrl := GenerateMinIOPreSignedUrl('GET', 'displaydeck-media', MediaFile.StorageURL, 3600); // 1 hour expiry

      Result.Success := True;
      Result.DownloadUrl := DownloadUrl;
      Result.Message := 'Download URL generated successfully';
    finally
      MediaFile.Free;
    end;
  except
    on E: Exception do
    begin
      Result.Success := False;
      Result.Message := 'Failed to generate download URL: ' + E.Message;
    end;
  end;
end;

function TMediaFileService.HmacSHA256(const Key, Data: TBytes): TBytes;
begin
  Result := THashSHA2.GetHMACAsBytes(Data, Key, THashSHA2.TSHA2Version.SHA256);
end;

function TMediaFileService.Sha256Hex(const S: string): string;
begin
  Result := THashSHA2.GetHashString(S, THashSHA2.TSHA2Version.SHA256).ToLower;
end;

function TMediaFileService.ToHex(const Bytes: TBytes): string;
const
  HexChars: array[0..15] of Char = ('0','1','2','3','4','5','6','7','8','9','a','b','c','d','e','f');
var
  I: Integer;
begin
  SetLength(Result, Length(Bytes) * 2);
  for I := 0 to High(Bytes) do
  begin
    Result[2*I+1] := HexChars[(Bytes[I] shr 4) and $F];
    Result[2*I+2] := HexChars[Bytes[I] and $F];
  end;
end;

function TMediaFileService.UrlEncodeRFC3986(const S: string): string;
var
  i: Integer;
  C: Char;
begin
  Result := '';
  for i := 1 to Length(S) do
  begin
    C := S[i];
    if (C in ['A'..'Z','a'..'z','0'..'9','-','_','.','~','/']) then
      Result := Result + C
    else
      Result := Result + '%' + IntToHex(Ord(C), 2);
  end;
end;

function TMediaFileService.UrlEncodeRFC3986Strict(const S: string): string;
var
  i: Integer;
  C: Char;
begin
  Result := '';
  for i := 1 to Length(S) do
  begin
    C := S[i];
    if (C in ['A'..'Z','a'..'z','0'..'9','-','_','.','~']) then
      Result := Result + C
    else
      Result := Result + '%' + IntToHex(Ord(C), 2);
  end;
end;

function TMediaFileService.EnvOrDefault(const Name, DefaultValue: string): string;
begin
  Result := GetEnvironmentVariable(Name);
  if Result = '' then
    Result := DefaultValue;
end;

function TMediaFileService.GetMediaFiles(OrganizationId: Integer): TArray<TMediaFile>;
var
  Query: TFDQuery;
  List: TArray<TMediaFile>;
  MediaFile: TMediaFile;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := GetConnection;
    Query.SQL.Text := 'SELECT MediaFileID, OrganizationID, FileName, FileType, StorageURL, CreatedAt, UpdatedAt ' +
                      'FROM MediaFiles WHERE OrganizationID = :OrgId ORDER BY FileName';
    Query.ParamByName('OrgId').AsInteger := OrganizationId;
    Query.Open;

    SetLength(List, 0);
    while not Query.Eof do
    begin
      MediaFile := TMediaFile.Create;
      MediaFile.Id := Query.FieldByName('MediaFileID').AsInteger;
      MediaFile.OrganizationId := Query.FieldByName('OrganizationID').AsInteger;
      MediaFile.FileName := Query.FieldByName('FileName').AsString;
      MediaFile.FileType := Query.FieldByName('FileType').AsString;
      MediaFile.StorageURL := Query.FieldByName('StorageURL').AsString;
      MediaFile.CreatedAt := Query.FieldByName('CreatedAt').AsDateTime;
      MediaFile.UpdatedAt := Query.FieldByName('UpdatedAt').AsDateTime;

      SetLength(List, Length(List) + 1);
      List[High(List)] := MediaFile;
      Query.Next;
    end;

    Result := List;
  finally
    Query.Free;
  end;
end;

function TMediaFileService.GetMediaFile(Id: Integer): TMediaFile;
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := GetConnection;
    Query.SQL.Text := 'SELECT MediaFileID, OrganizationID, FileName, FileType, StorageURL, CreatedAt, UpdatedAt ' +
                      'FROM MediaFiles WHERE MediaFileID = :Id';
    Query.ParamByName('Id').AsInteger := Id;
    Query.Open;

    if Query.IsEmpty then
      raise Exception.CreateFmt('Media file with ID %d not found', [Id]);

    Result := TMediaFile.Create;
    Result.Id := Query.FieldByName('MediaFileID').AsInteger;
    Result.OrganizationId := Query.FieldByName('OrganizationID').AsInteger;
    Result.FileName := Query.FieldByName('FileName').AsString;
    Result.FileType := Query.FieldByName('FileType').AsString;
    Result.StorageURL := Query.FieldByName('StorageURL').AsString;
    Result.CreatedAt := Query.FieldByName('CreatedAt').AsDateTime;
    Result.UpdatedAt := Query.FieldByName('UpdatedAt').AsDateTime;
  finally
    Query.Free;
  end;
end;

function TMediaFileService.CreateMediaFile(OrganizationId: Integer; const FileName, FileType, StorageURL: string): TMediaFile;
var
  Query: TFDQuery;
  NewId: Integer;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := GetConnection;
    Query.SQL.Text := 'INSERT INTO MediaFiles (OrganizationID, FileName, FileType, StorageURL, CreatedAt, UpdatedAt) ' +
                      'VALUES (:OrgId, :FileName, :FileType, :StorageURL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) ' +
                      'RETURNING MediaFileID';
    Query.ParamByName('OrgId').AsInteger := OrganizationId;
    Query.ParamByName('FileName').AsString := FileName;
    Query.ParamByName('FileType').AsString := FileType;
    Query.ParamByName('StorageURL').AsString := StorageURL;
    Query.Open;

    NewId := Query.Fields[0].AsInteger;
    Result := GetMediaFile(NewId);
  finally
    Query.Free;
  end;
end;

function TMediaFileService.UpdateMediaFile(Id: Integer; const FileName, FileType, StorageURL: string): TMediaFile;
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := GetConnection;
    Query.SQL.Text := 'UPDATE MediaFiles SET FileName = :FileName, FileType = :FileType, StorageURL = :StorageURL, ' +
                      'UpdatedAt = CURRENT_TIMESTAMP WHERE MediaFileID = :Id';
    Query.ParamByName('Id').AsInteger := Id;
    Query.ParamByName('FileName').AsString := FileName;
    Query.ParamByName('FileType').AsString := FileType;
    Query.ParamByName('StorageURL').AsString := StorageURL;
    Query.ExecSQL;

    if Query.RowsAffected = 0 then
      raise Exception.CreateFmt('Media file with ID %d not found', [Id]);

    Result := GetMediaFile(Id);
  finally
    Query.Free;
  end;
end;

procedure TMediaFileService.DeleteMediaFile(Id: Integer);
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := GetConnection;
    Query.SQL.Text := 'DELETE FROM MediaFiles WHERE MediaFileID = :Id';
    Query.ParamByName('Id').AsInteger := Id;
    Query.ExecSQL;

    if Query.RowsAffected = 0 then
      raise Exception.CreateFmt('Media file with ID %d not found', [Id]);
  finally
    Query.Free;
  end;
end;

initialization
  RegisterServiceType(TMediaFileService);

end.
