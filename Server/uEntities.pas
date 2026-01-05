unit uEntities;

interface

type
  // Core SaaS Entities
  TOrganization = class
  private
    FId: Integer;
    FName: string;
    FCreatedAt: TDateTime;
    FUpdatedAt: TDateTime;
  public
    property Id: Integer read FId write FId;
    property Name: string read FName write FName;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property UpdatedAt: TDateTime read FUpdatedAt write FUpdatedAt;
  end;

  TUser = class
  private
    FId: Integer;
    FOrganizationId: Integer;
    FEmail: string;
    FPasswordHash: string;
    FRole: string;
    FEmailVerifiedAt: TDateTime;
    FHasEmailVerifiedAt: Boolean;
    FCreatedAt: TDateTime;
    FUpdatedAt: TDateTime;
  public
    property Id: Integer read FId write FId;
    property OrganizationId: Integer read FOrganizationId write FOrganizationId;
    property Email: string read FEmail write FEmail;
    property PasswordHash: string read FPasswordHash write FPasswordHash;
    property Role: string read FRole write FRole;
    property EmailVerifiedAt: TDateTime read FEmailVerifiedAt write FEmailVerifiedAt;
    property HasEmailVerifiedAt: Boolean read FHasEmailVerifiedAt write FHasEmailVerifiedAt;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property UpdatedAt: TDateTime read FUpdatedAt write FUpdatedAt;
  end;

  // Subscription Management Entities
  TPlan = class
  private
    FId: Integer;
    FName: string;
    FPrice: Double;
    FMaxDisplays: Integer;
    FMaxCampaigns: Integer;
    FMaxMediaStorageGB: Integer;
    FIsActive: Boolean;
  public
    property Id: Integer read FId write FId;
    property Name: string read FName write FName;
    property Price: Double read FPrice write FPrice;
    property MaxDisplays: Integer read FMaxDisplays write FMaxDisplays;
    property MaxCampaigns: Integer read FMaxCampaigns write FMaxCampaigns;
    property MaxMediaStorageGB: Integer read FMaxMediaStorageGB write FMaxMediaStorageGB;
    property IsActive: Boolean read FIsActive write FIsActive;
  end;

  TSubscription = class
  private
    FId: Integer;
    FOrganizationId: Integer;
    FPlanId: Integer;
    FStatus: string;
    FCurrentPeriodEnd: TDateTime;
    FTrialEndDate: TDateTime;
    FCreatedAt: TDateTime;
    FUpdatedAt: TDateTime;
  public
    property Id: Integer read FId write FId;
    property OrganizationId: Integer read FOrganizationId write FOrganizationId;
    property PlanId: Integer read FPlanId write FPlanId;
    property Status: string read FStatus write FStatus;
    property CurrentPeriodEnd: TDateTime read FCurrentPeriodEnd write FCurrentPeriodEnd;
    property TrialEndDate: TDateTime read FTrialEndDate write FTrialEndDate;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property UpdatedAt: TDateTime read FUpdatedAt write FUpdatedAt;
  end;

  // Content Management Entities
  TMediaFile = class
  private
    FId: Integer;
    FOrganizationId: Integer;
    FFileName: string;
    FFileType: string;
    FOrientation: string;
    FStorageURL: string;
    FProcessingStatus: string;
    FProcessingError: string;
    FValidatedAt: TDateTime;
    FHasValidatedAt: Boolean;
    FCreatedAt: TDateTime;
    FUpdatedAt: TDateTime;
  public
    property Id: Integer read FId write FId;
    property OrganizationId: Integer read FOrganizationId write FOrganizationId;
    property FileName: string read FFileName write FFileName;
    property FileType: string read FFileType write FFileType;
    property Orientation: string read FOrientation write FOrientation;
    property StorageURL: string read FStorageURL write FStorageURL;
    property ProcessingStatus: string read FProcessingStatus write FProcessingStatus;
    property ProcessingError: string read FProcessingError write FProcessingError;
    property ValidatedAt: TDateTime read FValidatedAt write FValidatedAt;
    property HasValidatedAt: Boolean read FHasValidatedAt write FHasValidatedAt;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property UpdatedAt: TDateTime read FUpdatedAt write FUpdatedAt;
  end;

  TCampaign = class
  private
    FId: Integer;
    FOrganizationId: Integer;
    FName: string;
    FOrientation: string;
    FTransitionType: string;
    FTransitionDuration: Integer;
    FCreatedAt: TDateTime;
    FUpdatedAt: TDateTime;
  public
    property Id: Integer read FId write FId;
    property OrganizationId: Integer read FOrganizationId write FOrganizationId;
    property Name: string read FName write FName;
    property Orientation: string read FOrientation write FOrientation;
    property TransitionType: string read FTransitionType write FTransitionType;
    property TransitionDuration: Integer read FTransitionDuration write FTransitionDuration;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property UpdatedAt: TDateTime read FUpdatedAt write FUpdatedAt;
  end;

  TCampaignItem = class
  private
    FId: Integer;
    FCampaignId: Integer;
    FMediaFileId: Integer;
    FItemType: string;
    FMenuId: Integer;
    FDisplayOrder: Integer;
    FDuration: Integer;
  public
    property Id: Integer read FId write FId;
    property CampaignId: Integer read FCampaignId write FCampaignId;
    property MediaFileId: Integer read FMediaFileId write FMediaFileId;
    property ItemType: string read FItemType write FItemType;
    property MenuId: Integer read FMenuId write FMenuId;
    property DisplayOrder: Integer read FDisplayOrder write FDisplayOrder;
    property Duration: Integer read FDuration write FDuration;
  end;

  // Display Management Entities
  TDisplay = class
  private
    FId: Integer;
    FOrganizationId: Integer;
    FName: string;
    FOrientation: string;
    FLastSeen: TDateTime;
    FCurrentStatus: string;
    FProvisioningToken: string;
    FLastHeartbeatAt: TDateTime;
    FAppVersion: string;
    FDeviceInfoJson: string;
    FLastIp: string;
    FCreatedAt: TDateTime;
    FUpdatedAt: TDateTime;
  public
    property Id: Integer read FId write FId;
    property OrganizationId: Integer read FOrganizationId write FOrganizationId;
    property Name: string read FName write FName;
    property Orientation: string read FOrientation write FOrientation;
    property LastSeen: TDateTime read FLastSeen write FLastSeen;
    property CurrentStatus: string read FCurrentStatus write FCurrentStatus;
    property ProvisioningToken: string read FProvisioningToken write FProvisioningToken;
    property LastHeartbeatAt: TDateTime read FLastHeartbeatAt write FLastHeartbeatAt;
    property AppVersion: string read FAppVersion write FAppVersion;
    property DeviceInfoJson: string read FDeviceInfoJson write FDeviceInfoJson;
    property LastIp: string read FLastIp write FLastIp;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property UpdatedAt: TDateTime read FUpdatedAt write FUpdatedAt;
  end;

  TSchedule = class
  private
    FId: Integer;
    FCampaignId: Integer;
    FStartTime: TDateTime;
    FEndTime: TDateTime;
    FRecurringPattern: string;
  public
    property Id: Integer read FId write FId;
    property CampaignId: Integer read FCampaignId write FCampaignId;
    property StartTime: TDateTime read FStartTime write FStartTime;
    property EndTime: TDateTime read FEndTime write FEndTime;
    property RecurringPattern: string read FRecurringPattern write FRecurringPattern;
  end;

  TDisplayCampaign = class
  private
    FId: Integer;
    FDisplayId: Integer;
    FCampaignId: Integer;
    FIsPrimary: Boolean;
  public
    property Id: Integer read FId write FId;
    property DisplayId: Integer read FDisplayId write FDisplayId;
    property CampaignId: Integer read FCampaignId write FCampaignId;
    property IsPrimary: Boolean read FIsPrimary write FIsPrimary;
  end;

  TDisplayMenu = class
  private
    FId: Integer;
    FDisplayId: Integer;
    FMenuId: Integer;
    FIsPrimary: Boolean;
  public
    property Id: Integer read FId write FId;
    property DisplayId: Integer read FDisplayId write FDisplayId;
    property MenuId: Integer read FMenuId write FMenuId;
    property IsPrimary: Boolean read FIsPrimary write FIsPrimary;
  end;

  // Analytics Entity
  TPlaybackLog = class
  private
    FId: Int64;
    FDisplayId: Integer;
    FMediaFileId: Integer;
    FCampaignId: Integer;
    FPlaybackTimestamp: TDateTime;
  public
    property Id: Int64 read FId write FId;
    property DisplayId: Integer read FDisplayId write FDisplayId;
    property MediaFileId: Integer read FMediaFileId write FMediaFileId;
    property CampaignId: Integer read FCampaignId write FCampaignId;
    property PlaybackTimestamp: TDateTime read FPlaybackTimestamp write FPlaybackTimestamp;
  end;

  // Content Scheduling Entity
  TContentSchedule = class
  private
    FId: Integer;
    FOrganizationId: Integer;
    FName: string;
    FDescription: string;
    FPriority: Integer;
    FIsActive: Boolean;
    FContentType: string;
    FContentId: Integer;
    FCampaignId: Integer;
    FMenuId: Integer;
    FInfoBoardId: Integer;
    FStartDate: TDateTime;
    FHasStartDate: Boolean;
    FEndDate: TDateTime;
    FHasEndDate: Boolean;
    FStartTimeVal: TDateTime;
    FHasStartTime: Boolean;
    FEndTimeVal: TDateTime;
    FHasEndTime: Boolean;
    FStartTimeStr: string;
    FEndTimeStr: string;
    FDaysOfWeek: string;
    FTimezone: string;
    FCreatedAt: TDateTime;
    FUpdatedAt: TDateTime;
  public
    property Id: Integer read FId write FId;
    property OrganizationId: Integer read FOrganizationId write FOrganizationId;
    property Name: string read FName write FName;
    property Description: string read FDescription write FDescription;
    property Priority: Integer read FPriority write FPriority;
    property IsActive: Boolean read FIsActive write FIsActive;
    property ContentType: string read FContentType write FContentType;
    property ContentId: Integer read FContentId write FContentId;
    property CampaignId: Integer read FCampaignId write FCampaignId;
    property MenuId: Integer read FMenuId write FMenuId;
    property InfoBoardId: Integer read FInfoBoardId write FInfoBoardId;
    property StartDate: TDateTime read FStartDate write FStartDate;
    property HasStartDate: Boolean read FHasStartDate write FHasStartDate;
    property EndDate: TDateTime read FEndDate write FEndDate;
    property HasEndDate: Boolean read FHasEndDate write FHasEndDate;
    property StartTimeVal: TDateTime read FStartTimeVal write FStartTimeVal;
    property HasStartTime: Boolean read FHasStartTime write FHasStartTime;
    property EndTimeVal: TDateTime read FEndTimeVal write FEndTimeVal;
    property HasEndTime: Boolean read FHasEndTime write FHasEndTime;
    property StartTime: string read FStartTimeStr write FStartTimeStr;
    property EndTime: string read FEndTimeStr write FEndTimeStr;
    property DaysOfWeek: string read FDaysOfWeek write FDaysOfWeek;
    property Timezone: string read FTimezone write FTimezone;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property UpdatedAt: TDateTime read FUpdatedAt write FUpdatedAt;
  end;

  // Layout Template Entity
  TLayoutTemplate = class
  private
    FId: Integer;
    FOrganizationId: Integer;
    FName: string;
    FDescription: string;
    FIsSystemTemplate: Boolean;
    FZoneCount: Integer;
    FZonesConfig: string;
    FOrientation: string;
    FPreviewImageUrl: string;
    FCreatedAt: TDateTime;
    FUpdatedAt: TDateTime;
  public
    property Id: Integer read FId write FId;
    property OrganizationId: Integer read FOrganizationId write FOrganizationId;
    property Name: string read FName write FName;
    property Description: string read FDescription write FDescription;
    property IsSystemTemplate: Boolean read FIsSystemTemplate write FIsSystemTemplate;
    property ZoneCount: Integer read FZoneCount write FZoneCount;
    property ZonesConfig: string read FZonesConfig write FZonesConfig;
    property ZoneConfig: string read FZonesConfig write FZonesConfig; // Alias
    property Orientation: string read FOrientation write FOrientation;
    property PreviewImageUrl: string read FPreviewImageUrl write FPreviewImageUrl;
    property PreviewImage: string read FPreviewImageUrl write FPreviewImageUrl; // Alias
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property UpdatedAt: TDateTime read FUpdatedAt write FUpdatedAt;
  end;

  // Display Zone Entity
  TDisplayZone = class
  private
    FId: Integer;
    FDisplayId: Integer;
    FLayoutTemplateId: Integer;
    FZoneId: string;
    FZoneName: string;
    FContentType: string;
    FContentId: Integer;
    FSettings: string;
    FCampaignId: Integer;
    FMenuId: Integer;
    FInfoBoardId: Integer;
    FWidgetType: string;
    FWidgetConfig: string;
    FTickerText: string;
    FTickerSpeed: Integer;
    FCreatedAt: TDateTime;
    FUpdatedAt: TDateTime;
  public
    property Id: Integer read FId write FId;
    property DisplayId: Integer read FDisplayId write FDisplayId;
    property LayoutTemplateId: Integer read FLayoutTemplateId write FLayoutTemplateId;
    property TemplateId: Integer read FLayoutTemplateId write FLayoutTemplateId; // Alias
    property ZoneId: string read FZoneId write FZoneId;
    property ZoneIdentifier: string read FZoneId write FZoneId; // Alias
    property ZoneName: string read FZoneName write FZoneName;
    property ContentType: string read FContentType write FContentType;
    property ContentId: Integer read FContentId write FContentId;
    property Settings: string read FSettings write FSettings;
    property CampaignId: Integer read FCampaignId write FCampaignId;
    property MenuId: Integer read FMenuId write FMenuId;
    property InfoBoardId: Integer read FInfoBoardId write FInfoBoardId;
    property WidgetType: string read FWidgetType write FWidgetType;
    property WidgetConfig: string read FWidgetConfig write FWidgetConfig;
    property TickerText: string read FTickerText write FTickerText;
    property TickerSpeed: Integer read FTickerSpeed write FTickerSpeed;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property UpdatedAt: TDateTime read FUpdatedAt write FUpdatedAt;
  end;

  // Display Command Entity
  TDisplayCommand = class
  private
    FId: Integer;
    FDisplayId: Integer;
    FOrganizationId: Integer;
    FCommandType: string;
    FCommandData: string;
    FStatus: string;
    FSentAt: TDateTime;
    FHasSentAt: Boolean;
    FAcknowledgedAt: TDateTime;
    FHasAcknowledgedAt: Boolean;
    FCompletedAt: TDateTime;
    FHasCompletedAt: Boolean;
    FResult: string;
    FCreatedByUserId: Integer;
    FCreatedAt: TDateTime;
    FExpiresAt: TDateTime;
  public
    property Id: Integer read FId write FId;
    property DisplayId: Integer read FDisplayId write FDisplayId;
    property OrganizationId: Integer read FOrganizationId write FOrganizationId;
    property CommandType: string read FCommandType write FCommandType;
    property CommandData: string read FCommandData write FCommandData;
    property Payload: string read FCommandData write FCommandData; // Alias
    property Status: string read FStatus write FStatus;
    property SentAt: TDateTime read FSentAt write FSentAt;
    property HasSentAt: Boolean read FHasSentAt write FHasSentAt;
    property AcknowledgedAt: TDateTime read FAcknowledgedAt write FAcknowledgedAt;
    property HasAcknowledgedAt: Boolean read FHasAcknowledgedAt write FHasAcknowledgedAt;
    property CompletedAt: TDateTime read FCompletedAt write FCompletedAt;
    property HasCompletedAt: Boolean read FHasCompletedAt write FHasCompletedAt;
    property Result: string read FResult write FResult;
    property CreatedByUserId: Integer read FCreatedByUserId write FCreatedByUserId;
    property IssuedByUserId: Integer read FCreatedByUserId write FCreatedByUserId; // Alias
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property ExpiresAt: TDateTime read FExpiresAt write FExpiresAt;
  end;

  // Display Screenshot Entity
  TDisplayScreenshot = class
  private
    FId: Integer;
    FDisplayId: Integer;
    FOrganizationId: Integer;
    FStorageUrl: string;
    FThumbnailUrl: string;
    FCapturedAt: TDateTime;
    FFileSize: Integer;
    FWidth: Integer;
    FHeight: Integer;
  public
    property Id: Integer read FId write FId;
    property DisplayId: Integer read FDisplayId write FDisplayId;
    property OrganizationId: Integer read FOrganizationId write FOrganizationId;
    property StorageUrl: string read FStorageUrl write FStorageUrl;
    property ThumbnailUrl: string read FThumbnailUrl write FThumbnailUrl;
    property CapturedAt: TDateTime read FCapturedAt write FCapturedAt;
    property FileSize: Integer read FFileSize write FFileSize;
    property Width: Integer read FWidth write FWidth;
    property Height: Integer read FHeight write FHeight;
  end;

  // Integration Connection Entity
  TIntegrationConnection = class
  private
    FId: Integer;
    FOrganizationId: Integer;
    FIntegrationType: string;
    FName: string;
    FConfig: string;
    FIsActive: Boolean;
    FLastSyncAt: TDateTime;
    FHasLastSyncAt: Boolean;
    FLastSyncStatus: string;
    FLastSyncError: string;
    FCreatedAt: TDateTime;
    FUpdatedAt: TDateTime;
  public
    property Id: Integer read FId write FId;
    property OrganizationId: Integer read FOrganizationId write FOrganizationId;
    property IntegrationType: string read FIntegrationType write FIntegrationType;
    property Name: string read FName write FName;
    property Config: string read FConfig write FConfig;
    property IsActive: Boolean read FIsActive write FIsActive;
    property LastSyncAt: TDateTime read FLastSyncAt write FLastSyncAt;
    property HasLastSyncAt: Boolean read FHasLastSyncAt write FHasLastSyncAt;
    property LastSyncStatus: string read FLastSyncStatus write FLastSyncStatus;
    property LastSyncError: string read FLastSyncError write FLastSyncError;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property UpdatedAt: TDateTime read FUpdatedAt write FUpdatedAt;
  end;

  // Content Template Entity
  TContentTemplate = class
  private
    FId: Integer;
    FOrganizationId: Integer;
    FName: string;
    FDescription: string;
    FCategory: string;
    FTemplateType: string;
    FThumbnailUrl: string;
    FTemplateData: string;
    FTags: string;
    FIsPublic: Boolean;
    FIsSystemTemplate: Boolean;
    FUsageCount: Integer;
    FRating: Double;
    FCreatedAt: TDateTime;
    FUpdatedAt: TDateTime;
  public
    property Id: Integer read FId write FId;
    property OrganizationId: Integer read FOrganizationId write FOrganizationId;
    property Name: string read FName write FName;
    property Description: string read FDescription write FDescription;
    property Category: string read FCategory write FCategory;
    property TemplateType: string read FTemplateType write FTemplateType;
    property ContentType: string read FTemplateType write FTemplateType; // Alias
    property ThumbnailUrl: string read FThumbnailUrl write FThumbnailUrl;
    property PreviewImage: string read FThumbnailUrl write FThumbnailUrl; // Alias
    property TemplateData: string read FTemplateData write FTemplateData;
    property Tags: string read FTags write FTags;
    property IsPublic: Boolean read FIsPublic write FIsPublic;
    property IsSystemTemplate: Boolean read FIsSystemTemplate write FIsSystemTemplate;
    property UsageCount: Integer read FUsageCount write FUsageCount;
    property Rating: Double read FRating write FRating;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property UpdatedAt: TDateTime read FUpdatedAt write FUpdatedAt;
  end;

  // Role Entity
  TRole = class
  private
    FId: Integer;
    FOrganizationId: Integer;
    FName: string;
    FDescription: string;
    FPermissions: string;
    FIsSystemRole: Boolean;
    FCreatedAt: TDateTime;
    FUpdatedAt: TDateTime;
  public
    property Id: Integer read FId write FId;
    property OrganizationId: Integer read FOrganizationId write FOrganizationId;
    property Name: string read FName write FName;
    property Description: string read FDescription write FDescription;
    property Permissions: string read FPermissions write FPermissions;
    property IsSystemRole: Boolean read FIsSystemRole write FIsSystemRole;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property UpdatedAt: TDateTime read FUpdatedAt write FUpdatedAt;
  end;

  // Team Invitation Entity
  TTeamInvitation = class
  private
    FId: Integer;
    FOrganizationId: Integer;
    FEmail: string;
    FRoleId: Integer;
    FInvitedByUserId: Integer;
    FTokenHash: string;
    FExpiresAt: TDateTime;
    FAcceptedAt: TDateTime;
    FHasAcceptedAt: Boolean;
    FCreatedAt: TDateTime;
  public
    property Id: Integer read FId write FId;
    property OrganizationId: Integer read FOrganizationId write FOrganizationId;
    property Email: string read FEmail write FEmail;
    property RoleId: Integer read FRoleId write FRoleId;
    property InvitedByUserId: Integer read FInvitedByUserId write FInvitedByUserId;
    property TokenHash: string read FTokenHash write FTokenHash;
    property ExpiresAt: TDateTime read FExpiresAt write FExpiresAt;
    property AcceptedAt: TDateTime read FAcceptedAt write FAcceptedAt;
    property HasAcceptedAt: Boolean read FHasAcceptedAt write FHasAcceptedAt;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
  end;

  // Location Entity
  TLocation = class
  private
    FId: Integer;
    FOrganizationId: Integer;
    FName: string;
    FAddress: string;
    FCity: string;
    FState: string;
    FCountry: string;
    FTimezone: string;
    FLatitude: Double;
    FLongitude: Double;
    FCreatedAt: TDateTime;
    FUpdatedAt: TDateTime;
  public
    property Id: Integer read FId write FId;
    property OrganizationId: Integer read FOrganizationId write FOrganizationId;
    property Name: string read FName write FName;
    property Address: string read FAddress write FAddress;
    property City: string read FCity write FCity;
    property State: string read FState write FState;
    property Country: string read FCountry write FCountry;
    property Timezone: string read FTimezone write FTimezone;
    property Latitude: Double read FLatitude write FLatitude;
    property Longitude: Double read FLongitude write FLongitude;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property UpdatedAt: TDateTime read FUpdatedAt write FUpdatedAt;
  end;

implementation

end.
