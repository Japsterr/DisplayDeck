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
    MediaFileID INT NOT NULL,
    DisplayOrder INT NOT NULL,
    Duration INT NOT NULL, -- in seconds
    FOREIGN KEY (CampaignID) REFERENCES Campaigns(CampaignID) ON DELETE CASCADE,
    FOREIGN KEY (MediaFileID) REFERENCES MediaFiles(MediaFileID) ON DELETE CASCADE
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

-- Insert some default data for testing
INSERT INTO Plans (Name, Price, MaxDisplays, MaxCampaigns, MaxMediaStorageGB, IsActive) VALUES
('Free', 0.00, 1, 2, 1, TRUE),
('Starter', 9.99, 5, 10, 10, TRUE),
('Business', 29.99, 20, 50, 50, TRUE);
