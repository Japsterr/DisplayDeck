unit MediaFileServiceImplementation;

interface

uses
  System.SysUtils,
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
const
  MINIO_ENDPOINT = 'http://localhost:9000';
  MINIO_ACCESS_KEY = 'minioadmin';
  MINIO_SECRET_KEY = 'minioadmin';
var
  Expires: string;
  DateStr: string;
begin
  // Simplified implementation - in production, use a proper MinIO SDK
  // For now, return a basic URL that the client can use
  Expires := IntToStr(ExpiresInSeconds);
  DateStr := FormatDateTime('yyyymmdd', Now) + 'T' + FormatDateTime('hhnnss', Now) + 'Z';

  Result := Format('%s/%s/%s?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=%s/%s/us-east-1/s3/aws4_request&X-Amz-Date=%s&X-Amz-Expires=%s&X-Amz-SignedHeaders=host',
    [MINIO_ENDPOINT, Bucket, Key, MINIO_ACCESS_KEY, DateStr, DateStr, Expires]);
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

    // Create media file record in database
    CreateMediaFile(Request.OrganizationId, Request.FileName, Request.FileType, StorageKey);

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
