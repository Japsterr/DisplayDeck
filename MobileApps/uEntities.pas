unit uEntities;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections;

type
  // Base response types
  TApiResponse = class
  public
    Success: Boolean;
    Message: string;
    constructor Create;
  end;

  // Authentication entities
  TUser = class
  public
    Id: Integer;
    Email: string;
    OrganizationName: string;
    CreatedAt: TDateTime;
    constructor Create;
  end;

  TRegisterRequest = class
  public
    Email: string;
    Password: string;
    OrganizationName: string;
  end;

  TLoginRequest = class
  public
    Email: string;
    Password: string;
  end;

  TAuthResponse = class(TApiResponse)
  public
    Token: string;
    User: TUser;
    constructor Create;
    destructor Destroy; override;
  end;

  // Campaign entities
  TCampaignItem = class
  public
    Id: Integer;
    MediaFileId: string;
    DisplayOrder: Integer;
    DurationSeconds: Integer;
    TransitionType: string;
    constructor Create;
  end;

  TCampaign = class
  public
    Id: Integer;
    Name: string;
    Description: string;
    Items: TObjectList<TCampaignItem>;
    CreatedAt: TDateTime;
    UpdatedAt: TDateTime;
    constructor Create;
    destructor Destroy; override;
  end;

  TCreateCampaignRequest = class
  public
    Name: string;
    Description: string;
    Items: TObjectList<TCampaignItem>;
    constructor Create;
    destructor Destroy; override;
  end;

  TUpdateCampaignRequest = class
  public
    Name: string;
    Description: string;
    Items: TObjectList<TCampaignItem>;
    constructor Create;
    destructor Destroy; override;
  end;

  TCampaignResponse = class(TApiResponse)
  public
    Campaign: TCampaign;
    constructor Create;
    destructor Destroy; override;
  end;

  TCampaignListResponse = class(TApiResponse)
  public
    Campaigns: TObjectList<TCampaign>;
    constructor Create;
    destructor Destroy; override;
  end;

  // Media file entities
  TMediaFile = class
  public
    Id: string;
    FileName: string;
    ContentType: string;
    Size: Int64;
    UploadUrl: string;
    DownloadUrl: string;
    UploadedAt: TDateTime;
    constructor Create;
  end;

  TMediaFileResponse = class(TApiResponse)
  public
    MediaFile: TMediaFile;
    constructor Create;
    destructor Destroy; override;
  end;

  TMediaFileListResponse = class(TApiResponse)
  public
    MediaFiles: TObjectList<TMediaFile>;
    constructor Create;
    destructor Destroy; override;
  end;

  // Display entities
  TDisplay = class
  public
    Id: Integer;
    Name: string;
    Location: string;
    ProvisioningToken: string;
    IsOnline: Boolean;
    LastSeen: TDateTime;
    CreatedAt: TDateTime;
    constructor Create;
  end;

  TRegisterDisplayRequest = class
  public
    Name: string;
    Location: string;
    ProvisioningToken: string;
  end;

  TUpdateDisplayRequest = class
  public
    Name: string;
    Location: string;
  end;

  TDisplayResponse = class(TApiResponse)
  public
    Display: TDisplay;
    constructor Create;
    destructor Destroy; override;
  end;

  TDisplayListResponse = class(TApiResponse)
  public
    Displays: TObjectList<TDisplay>;
    constructor Create;
    destructor Destroy; override;
  end;

  // Display Campaign entities (assignments)
  TDisplayCampaign = class
  public
    Id: Integer;
    DisplayId: Integer;
    CampaignId: Integer;
    StartDate: TDateTime;
    EndDate: TDateTime;
    IsActive: Boolean;
    Priority: Integer;
    constructor Create;
  end;

  TAssignCampaignRequest = class
  public
    DisplayId: Integer;
    CampaignId: Integer;
    StartDate: TDateTime;
    EndDate: TDateTime;
    Priority: Integer;
  end;

  TDisplayCampaignResponse = class(TApiResponse)
  public
    DisplayCampaign: TDisplayCampaign;
    constructor Create;
    destructor Destroy; override;
  end;

  TDisplayCampaignListResponse = class(TApiResponse)
  public
    DisplayCampaigns: TObjectList<TDisplayCampaign>;
    constructor Create;
    destructor Destroy; override;
  end;

implementation

{ TApiResponse }

constructor TApiResponse.Create;
begin
  inherited;
  Success := False;
  Message := '';
end;

{ TUser }

constructor TUser.Create;
begin
  inherited;
  Id := 0;
  Email := '';
  OrganizationName := '';
  CreatedAt := 0;
end;

{ TAuthResponse }

constructor TAuthResponse.Create;
begin
  inherited;
  Token := '';
  User := nil;
end;

destructor TAuthResponse.Destroy;
begin
  User.Free;
  inherited;
end;

{ TCampaignItem }

constructor TCampaignItem.Create;
begin
  inherited;
  Id := 0;
  MediaFileId := '';
  DisplayOrder := 0;
  DurationSeconds := 10;
  TransitionType := 'fade';
end;

{ TCampaign }

constructor TCampaign.Create;
begin
  inherited;
  Id := 0;
  Name := '';
  Description := '';
  Items := TObjectList<TCampaignItem>.Create;
  CreatedAt := 0;
  UpdatedAt := 0;
end;

destructor TCampaign.Destroy;
begin
  Items.Free;
  inherited;
end;

{ TCreateCampaignRequest }

constructor TCreateCampaignRequest.Create;
begin
  inherited;
  Name := '';
  Description := '';
  Items := TObjectList<TCampaignItem>.Create;
end;

destructor TCreateCampaignRequest.Destroy;
begin
  Items.Free;
  inherited;
end;

{ TUpdateCampaignRequest }

constructor TUpdateCampaignRequest.Create;
begin
  inherited;
  Name := '';
  Description := '';
  Items := TObjectList<TCampaignItem>.Create;
end;

destructor TUpdateCampaignRequest.Destroy;
begin
  Items.Free;
  inherited;
end;

{ TCampaignResponse }

constructor TCampaignResponse.Create;
begin
  inherited;
  Campaign := nil;
end;

destructor TCampaignResponse.Destroy;
begin
  Campaign.Free;
  inherited;
end;

{ TCampaignListResponse }

constructor TCampaignListResponse.Create;
begin
  inherited;
  Campaigns := TObjectList<TCampaign>.Create;
end;

destructor TCampaignListResponse.Destroy;
begin
  Campaigns.Free;
  inherited;
end;

{ TMediaFile }

constructor TMediaFile.Create;
begin
  inherited;
  Id := '';
  FileName := '';
  ContentType := '';
  Size := 0;
  UploadUrl := '';
  DownloadUrl := '';
  UploadedAt := 0;
end;

{ TMediaFileResponse }

constructor TMediaFileResponse.Create;
begin
  inherited;
  MediaFile := nil;
end;

destructor TMediaFileResponse.Destroy;
begin
  MediaFile.Free;
  inherited;
end;

{ TMediaFileListResponse }

constructor TMediaFileListResponse.Create;
begin
  inherited;
  MediaFiles := TObjectList<TMediaFile>.Create;
end;

destructor TMediaFileListResponse.Destroy;
begin
  MediaFiles.Free;
  inherited;
end;

{ TDisplay }

constructor TDisplay.Create;
begin
  inherited;
  Id := 0;
  Name := '';
  Location := '';
  ProvisioningToken := '';
  IsOnline := False;
  LastSeen := 0;
  CreatedAt := 0;
end;

{ TDisplayResponse }

constructor TDisplayResponse.Create;
begin
  inherited;
  Display := nil;
end;

destructor TDisplayResponse.Destroy;
begin
  Display.Free;
  inherited;
end;

{ TDisplayListResponse }

constructor TDisplayListResponse.Create;
begin
  inherited;
  Displays := TObjectList<TDisplay>.Create;
end;

destructor TDisplayListResponse.Destroy;
begin
  Displays.Free;
  inherited;
end;

{ TDisplayCampaign }

constructor TDisplayCampaign.Create;
begin
  inherited;
  Id := 0;
  DisplayId := 0;
  CampaignId := 0;
  StartDate := 0;
  EndDate := 0;
  IsActive := False;
  Priority := 0;
end;

{ TDisplayCampaignResponse }

constructor TDisplayCampaignResponse.Create;
begin
  inherited;
  DisplayCampaign := nil;
end;

destructor TDisplayCampaignResponse.Destroy;
begin
  DisplayCampaign.Free;
  inherited;
end;

{ TDisplayCampaignListResponse }

constructor TDisplayCampaignListResponse.Create;
begin
  inherited;
  DisplayCampaigns := TObjectList<TDisplayCampaign>.Create;
end;

destructor TDisplayCampaignListResponse.Destroy;
begin
  DisplayCampaigns.Free;
  inherited;
end;

end.