-- This script will be executed automatically by the PostgreSQL container on its first run.

-- 1. Core SaaS Tables
CREATE TABLE Organizations (
    OrganizationID SERIAL PRIMARY KEY,
    Name VARCHAR(255) NOT NULL,
    CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE Users (
    UserID SERIAL PRIMARY KEY,
    OrganizationID INT NOT NULL,
    Email VARCHAR(255) NOT NULL UNIQUE,
    PasswordHash VARCHAR(255) NOT NULL,
    Role VARCHAR(50) NOT NULL, -- e.g., 'Owner', 'ContentManager', 'Viewer'
    CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (OrganizationID) REFERENCES Organizations(OrganizationID) ON DELETE CASCADE
);

-- 2. Subscription Management Tables
CREATE TABLE Plans (
    PlanID SERIAL PRIMARY KEY,
    Name VARCHAR(100) NOT NULL UNIQUE,
    Price DECIMAL(10, 2) NOT NULL,
    MaxDisplays INT NOT NULL,
    MaxCampaigns INT NOT NULL,
    MaxMediaStorageGB INT NOT NULL,
    IsActive BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE Subscriptions (
    SubscriptionID SERIAL PRIMARY KEY,
    OrganizationID INT NOT NULL UNIQUE, -- An organization can only have one subscription
    PlanID INT NOT NULL,
    Status VARCHAR(50) NOT NULL, -- e.g., 'Trialing', 'Active', 'PastDue', 'Canceled'
    CurrentPeriodEnd TIMESTAMP WITH TIME ZONE,
    TrialEndDate TIMESTAMP WITH TIME ZONE,
    CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (OrganizationID) REFERENCES Organizations(OrganizationID) ON DELETE CASCADE,
    FOREIGN KEY (PlanID) REFERENCES Plans(PlanID)
);

-- 3. Content Management Tables
CREATE TABLE MediaFiles (
    MediaFileID SERIAL PRIMARY KEY,
    OrganizationID INT NOT NULL,
    FileName VARCHAR(255) NOT NULL,
    FileType VARCHAR(100) NOT NULL,
    Orientation VARCHAR(20) NOT NULL DEFAULT 'Landscape',
    ProcessingStatus VARCHAR(20) NOT NULL DEFAULT 'uploaded', -- uploaded|validating|ready|failed
    ProcessingError TEXT,
    ValidatedAt TIMESTAMP WITH TIME ZONE,
    StorageURL VARCHAR(1024) NOT NULL,
    CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (OrganizationID) REFERENCES Organizations(OrganizationID) ON DELETE CASCADE
);

CREATE TABLE Campaigns (
    CampaignID SERIAL PRIMARY KEY,
    OrganizationID INT NOT NULL,
    Name VARCHAR(255) NOT NULL,
    Orientation VARCHAR(20) NOT NULL, -- 'Landscape' or 'Portrait'
    CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (OrganizationID) REFERENCES Organizations(OrganizationID) ON DELETE CASCADE
);

CREATE TABLE CampaignItems (
    CampaignItemID SERIAL PRIMARY KEY,
    CampaignID INT NOT NULL,
        -- Media items (legacy) reference MediaFileID
        MediaFileID INT,
        -- New: campaign items can also be menus
        ItemType VARCHAR(20) NOT NULL DEFAULT 'media',
        MenuID INT,
    DisplayOrder INT NOT NULL,
    Duration INT NOT NULL, -- in seconds
    FOREIGN KEY (CampaignID) REFERENCES Campaigns(CampaignID) ON DELETE CASCADE,
    FOREIGN KEY (MediaFileID) REFERENCES MediaFiles(MediaFileID) ON DELETE CASCADE
);

-- New: dynamic menu boards
CREATE TABLE Menus (
        MenuID SERIAL PRIMARY KEY,
        OrganizationID INT NOT NULL,
        Name VARCHAR(255) NOT NULL,
        Orientation VARCHAR(20) NOT NULL DEFAULT 'Landscape',
        TemplateKey VARCHAR(64) NOT NULL DEFAULT 'simple',
        ThemeConfig JSONB NOT NULL DEFAULT '{}'::jsonb,
        PublicToken VARCHAR(64) NOT NULL UNIQUE,
        CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UpdatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (OrganizationID) REFERENCES Organizations(OrganizationID) ON DELETE CASCADE
);

CREATE TABLE MenuSections (
        MenuSectionID SERIAL PRIMARY KEY,
        MenuID INT NOT NULL,
        Name VARCHAR(255) NOT NULL,
        DisplayOrder INT NOT NULL DEFAULT 0,
        CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UpdatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (MenuID) REFERENCES Menus(MenuID) ON DELETE CASCADE
);

CREATE TABLE MenuItems (
        MenuItemID SERIAL PRIMARY KEY,
        MenuSectionID INT NOT NULL,
        Name VARCHAR(255) NOT NULL,
        Description TEXT,
        PriceCents INT,
        IsAvailable BOOLEAN NOT NULL DEFAULT TRUE,
        DisplayOrder INT NOT NULL DEFAULT 0,
        CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UpdatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (MenuSectionID) REFERENCES MenuSections(MenuSectionID) ON DELETE CASCADE
);

ALTER TABLE CampaignItems
    ADD CONSTRAINT fk_campaignitems_menuid FOREIGN KEY (MenuID) REFERENCES Menus(MenuID) ON DELETE CASCADE;

ALTER TABLE CampaignItems
    ADD CONSTRAINT ck_campaignitems_itemtype_target
    CHECK (
        (ItemType='media' AND MediaFileID IS NOT NULL AND MenuID IS NULL)
        OR
        (ItemType='menu' AND MenuID IS NOT NULL AND MediaFileID IS NULL)
    );

-- 4. Scheduling and Display Tables
CREATE TABLE Schedules (
    ScheduleID SERIAL PRIMARY KEY,
    CampaignID INT NOT NULL,
    StartTime TIMESTAMP WITH TIME ZONE,
    EndTime TIMESTAMP WITH TIME ZONE,
    RecurringPattern TEXT, -- Can store JSON or a specific DSL for recurrence
    FOREIGN KEY (CampaignID) REFERENCES Campaigns(CampaignID) ON DELETE CASCADE
);

CREATE TABLE Displays (
    DisplayID SERIAL PRIMARY KEY,
    OrganizationID INT NOT NULL,
    Name VARCHAR(255) NOT NULL,
    Orientation VARCHAR(20) NOT NULL, -- 'Landscape' or 'Portrait'
    LastSeen TIMESTAMP WITH TIME ZONE,
    CurrentStatus VARCHAR(50), -- e.g., 'Online', 'Offline'
    ProvisioningToken VARCHAR(255),
    LastHeartbeatAt TIMESTAMP WITH TIME ZONE,
    AppVersion VARCHAR(50),
    DeviceInfo JSONB,
    LastIp VARCHAR(64),
    CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (OrganizationID) REFERENCES Organizations(OrganizationID) ON DELETE CASCADE
);

CREATE TABLE DisplayCampaigns (
    DisplayCampaignID SERIAL PRIMARY KEY,
    DisplayID INT NOT NULL,
    CampaignID INT NOT NULL,
    IsPrimary BOOLEAN NOT NULL DEFAULT TRUE,
    FOREIGN KEY (DisplayID) REFERENCES Displays(DisplayID) ON DELETE CASCADE,
    FOREIGN KEY (CampaignID) REFERENCES Campaigns(CampaignID) ON DELETE CASCADE
);

-- 5. Analytics Table
CREATE TABLE PlaybackLogs (
    LogID BIGSERIAL PRIMARY KEY,
    DisplayID INT NOT NULL,
    MediaFileID INT NOT NULL,
    CampaignID INT NOT NULL,
    PlaybackTimestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    FOREIGN KEY (DisplayID) REFERENCES Displays(DisplayID) ON DELETE CASCADE,
    FOREIGN KEY (MediaFileID) REFERENCES MediaFiles(MediaFileID) ON DELETE CASCADE,
    FOREIGN KEY (CampaignID) REFERENCES Campaigns(CampaignID) ON DELETE CASCADE
);

-- 6. Device Provisioning Tokens (for QR/Barcode onboarding)
CREATE TABLE IF NOT EXISTS ProvisioningTokens (
    Token VARCHAR(128) PRIMARY KEY,
    ExpiresAt TIMESTAMP WITH TIME ZONE NOT NULL,
    Claimed BOOLEAN NOT NULL DEFAULT FALSE,
    HardwareId VARCHAR(255),
    DisplayID INT,
    OrganizationID INT,
    FOREIGN KEY (DisplayID) REFERENCES Displays(DisplayID) ON DELETE SET NULL,
    FOREIGN KEY (OrganizationID) REFERENCES Organizations(OrganizationID) ON DELETE SET NULL
);

-- 7. Refresh tokens (rotating) for /auth/refresh
CREATE TABLE IF NOT EXISTS RefreshTokens (
    RefreshTokenID BIGSERIAL PRIMARY KEY,
    OrganizationID INT NOT NULL,
    UserID INT NOT NULL,
    TokenHash VARCHAR(128) NOT NULL UNIQUE,
    ExpiresAt TIMESTAMP WITH TIME ZONE NOT NULL,
    RevokedAt TIMESTAMP WITH TIME ZONE,
    LastUsedAt TIMESTAMP WITH TIME ZONE,
    CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (OrganizationID) REFERENCES Organizations(OrganizationID) ON DELETE CASCADE,
    FOREIGN KEY (UserID) REFERENCES Users(UserID) ON DELETE CASCADE
);

-- 8. Scoped API keys
CREATE TABLE IF NOT EXISTS ApiKeys (
    ApiKeyID BIGSERIAL PRIMARY KEY,
    OrganizationID INT NOT NULL,
    Name VARCHAR(255) NOT NULL,
    KeyHash VARCHAR(128) NOT NULL UNIQUE,
    Scopes TEXT NOT NULL,
    CreatedByUserID INT,
    ExpiresAt TIMESTAMP WITH TIME ZONE,
    RevokedAt TIMESTAMP WITH TIME ZONE,
    LastUsedAt TIMESTAMP WITH TIME ZONE,
    CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (OrganizationID) REFERENCES Organizations(OrganizationID) ON DELETE CASCADE,
    FOREIGN KEY (CreatedByUserID) REFERENCES Users(UserID) ON DELETE SET NULL
);

-- 9. Webhook subscriptions
CREATE TABLE IF NOT EXISTS Webhooks (
    WebhookID BIGSERIAL PRIMARY KEY,
    OrganizationID INT NOT NULL,
    Url VARCHAR(1024) NOT NULL,
    Secret VARCHAR(255),
    Events TEXT NOT NULL DEFAULT '*',
    IsActive BOOLEAN NOT NULL DEFAULT TRUE,
    CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (OrganizationID) REFERENCES Organizations(OrganizationID) ON DELETE CASCADE
);

-- 10. Idempotency keys (request replay)
CREATE TABLE IF NOT EXISTS IdempotencyKeys (
    IdempotencyKey VARCHAR(128) PRIMARY KEY,
    OrganizationID INT,
    Method VARCHAR(16) NOT NULL,
    Path VARCHAR(255) NOT NULL,
    ResponseStatus INT NOT NULL,
    ResponseBody TEXT NOT NULL,
    ExpiresAt TIMESTAMP WITH TIME ZONE NOT NULL,
    CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 11. Audit logs
CREATE TABLE IF NOT EXISTS AuditLogs (
    AuditLogID BIGSERIAL PRIMARY KEY,
    OrganizationID INT NOT NULL,
    UserID INT,
    Action VARCHAR(128) NOT NULL,
    ObjectType VARCHAR(64),
    ObjectId VARCHAR(64),
    Details JSONB,
    RequestId VARCHAR(64),
    IpAddress VARCHAR(64),
    UserAgent VARCHAR(255),
    CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (OrganizationID) REFERENCES Organizations(OrganizationID) ON DELETE CASCADE,
    FOREIGN KEY (UserID) REFERENCES Users(UserID) ON DELETE SET NULL
);

-- Insert some default data for testing
INSERT INTO Plans (Name, Price, MaxDisplays, MaxCampaigns, MaxMediaStorageGB, IsActive) VALUES
('Free', 0.00, 1, 2, 1, TRUE),
('Starter', 9.99, 5, 10, 10, TRUE),
('Business', 29.99, 20, 50, 50, TRUE);
