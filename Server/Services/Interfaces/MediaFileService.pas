unit MediaFileService;

interface

uses
  XData.Service.Common,
  uEntities;

type
  TUploadUrlRequest = class
  private
    FOrganizationId: Integer;
    FFileName: string;
    FFileType: string;
    FContentLength: Int64;
  public
    property OrganizationId: Integer read FOrganizationId write FOrganizationId;
    property FileName: string read FFileName write FFileName;
    property FileType: string read FFileType write FFileType;
    property ContentLength: Int64 read FContentLength write FContentLength;
  end;

  TUploadUrlResponse = class
  private
    FMediaFileId: Integer;
    FUploadUrl: string;
    FStorageKey: string;
    FSuccess: Boolean;
    FMessage: string;
  public
    property MediaFileId: Integer read FMediaFileId write FMediaFileId;
    property UploadUrl: string read FUploadUrl write FUploadUrl;
    property StorageKey: string read FStorageKey write FStorageKey;
    property Success: Boolean read FSuccess write FSuccess;
    property Message: string read FMessage write FMessage;
  end;

  TDownloadUrlResponse = class
  private
    FDownloadUrl: string;
    FSuccess: Boolean;
    FMessage: string;
  public
    property DownloadUrl: string read FDownloadUrl write FDownloadUrl;
    property Success: Boolean read FSuccess write FSuccess;
    property Message: string read FMessage write FMessage;
  end;

  [ServiceContract]
  [Route('')]
  IMediaFileService = interface(IInvokable)
    ['{C39FDE92-4B8B-4B5A-9C16-4FCBBB98192A}']
    // List media files for organization
    [HttpGet]
    [Route('organizations/{OrganizationId}/media-files')]
    function GetMediaFiles(OrganizationId: Integer): TArray<TMediaFile>;
    // Get single media file
    [HttpGet]
    [Route('media-files/{Id}')]
    function GetMediaFile(Id: Integer): TMediaFile;
    // Create media file metadata directly (alternate to presign flow)
    [HttpPost]
    [Route('organizations/{OrganizationId}/media-files')]
    function CreateMediaFile(OrganizationId: Integer; const FileName, FileType, StorageURL: string): TMediaFile;
    // Update media file
    [HttpPut]
    [Route('media-files/{Id}')]
    function UpdateMediaFile(Id: Integer; const FileName, FileType, StorageURL: string): TMediaFile;
    // Delete media file
    [HttpDelete]
    [Route('media-files/{Id}')]
    procedure DeleteMediaFile(Id: Integer);
    // Get pre-signed upload URL
    [HttpPost]
    [Route('media-files/upload-url')]
    function GetUploadUrl(const Request: TUploadUrlRequest): TUploadUrlResponse;
    // Get pre-signed download URL
    [HttpGet]
    [Route('media-files/{MediaFileId}/download-url')]
    function GetDownloadUrl(MediaFileId: Integer): TDownloadUrlResponse;
  end;

implementation

initialization
  RegisterServiceType(TypeInfo(IMediaFileService));

end.

