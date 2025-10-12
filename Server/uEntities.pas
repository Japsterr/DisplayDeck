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
    FCreatedAt: TDateTime;
    FUpdatedAt: TDateTime;
  public
    property Id: Integer read FId write FId;
    property OrganizationId: Integer read FOrganizationId write FOrganizationId;
    property Email: string read FEmail write FEmail;
    property PasswordHash: string read FPasswordHash write FPasswordHash;
    property Role: string read FRole write FRole;
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
    FStorageURL: string;
    FCreatedAt: TDateTime;
    FUpdatedAt: TDateTime;
  public
    property Id: Integer read FId write FId;
    property OrganizationId: Integer read FOrganizationId write FOrganizationId;
    property FileName: string read FFileName write FFileName;
    property FileType: string read FFileType write FFileType;
    property StorageURL: string read FStorageURL write FStorageURL;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property UpdatedAt: TDateTime read FUpdatedAt write FUpdatedAt;
  end;

  TCampaign = class
  private
    FId: Integer;
    FOrganizationId: Integer;
    FName: string;
    FOrientation: string;
    FCreatedAt: TDateTime;
    FUpdatedAt: TDateTime;
  public
    property Id: Integer read FId write FId;
    property OrganizationId: Integer read FOrganizationId write FOrganizationId;
    property Name: string read FName write FName;
    property Orientation: string read FOrientation write FOrientation;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property UpdatedAt: TDateTime read FUpdatedAt write FUpdatedAt;
  end;

  TCampaignItem = class
  private
    FId: Integer;
    FCampaignId: Integer;
    FMediaFileId: Integer;
    FDisplayOrder: Integer;
    FDuration: Integer;
  public
    property Id: Integer read FId write FId;
    property CampaignId: Integer read FCampaignId write FCampaignId;
    property MediaFileId: Integer read FMediaFileId write FMediaFileId;
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

implementation

end.
