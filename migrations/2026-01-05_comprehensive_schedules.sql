-- Comprehensive Scheduling System Migration
-- Supports time-based, day-of-week, date-based scheduling with priorities

-- Drop old simple schedules table if it exists and recreate with full features
DROP TABLE IF EXISTS DisplaySchedules CASCADE;
DROP TABLE IF EXISTS ScheduleRules CASCADE;

-- Content Schedules: Links content to time rules
CREATE TABLE IF NOT EXISTS ContentSchedules (
    ScheduleID SERIAL PRIMARY KEY,
    OrganizationID INT NOT NULL,
    Name VARCHAR(255) NOT NULL,
    Description TEXT,
    Priority INT NOT NULL DEFAULT 0, -- Higher priority takes precedence
    IsActive BOOLEAN NOT NULL DEFAULT TRUE,
    -- Content reference (one of these must be set)
    ContentType VARCHAR(20) NOT NULL, -- 'campaign', 'menu', 'infoboard'
    CampaignID INT,
    MenuID INT,
    InfoBoardID INT,
    -- Time constraints
    StartDate DATE, -- NULL = no start date constraint
    EndDate DATE, -- NULL = no end date constraint  
    StartTime TIME, -- NULL = all day
    EndTime TIME, -- NULL = all day
    -- Day of week (NULL = all days, comma-separated: 'mon,tue,wed,thu,fri,sat,sun')
    DaysOfWeek VARCHAR(50),
    -- Timezone for schedule evaluation
    Timezone VARCHAR(64) NOT NULL DEFAULT 'UTC',
    CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (OrganizationID) REFERENCES Organizations(OrganizationID) ON DELETE CASCADE,
    FOREIGN KEY (CampaignID) REFERENCES Campaigns(CampaignID) ON DELETE CASCADE,
    FOREIGN KEY (MenuID) REFERENCES Menus(MenuID) ON DELETE CASCADE,
    FOREIGN KEY (InfoBoardID) REFERENCES InfoBoards(InfoBoardID) ON DELETE CASCADE,
    CONSTRAINT ck_schedule_content CHECK (
        (ContentType = 'campaign' AND CampaignID IS NOT NULL AND MenuID IS NULL AND InfoBoardID IS NULL) OR
        (ContentType = 'menu' AND MenuID IS NOT NULL AND CampaignID IS NULL AND InfoBoardID IS NULL) OR
        (ContentType = 'infoboard' AND InfoBoardID IS NOT NULL AND CampaignID IS NULL AND MenuID IS NULL)
    )
);

-- Link schedules to displays
CREATE TABLE IF NOT EXISTS DisplaySchedules (
    DisplayScheduleID SERIAL PRIMARY KEY,
    DisplayID INT NOT NULL,
    ScheduleID INT NOT NULL,
    CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (DisplayID) REFERENCES Displays(DisplayID) ON DELETE CASCADE,
    FOREIGN KEY (ScheduleID) REFERENCES ContentSchedules(ScheduleID) ON DELETE CASCADE,
    UNIQUE (DisplayID, ScheduleID)
);

CREATE INDEX idx_contentschedules_org ON ContentSchedules(OrganizationID);
CREATE INDEX idx_contentschedules_active ON ContentSchedules(IsActive);
CREATE INDEX idx_displayschedules_display ON DisplaySchedules(DisplayID);


-- Multi-Zone Layout System

-- Layout templates
CREATE TABLE IF NOT EXISTS LayoutTemplates (
    LayoutTemplateID SERIAL PRIMARY KEY,
    OrganizationID INT, -- NULL = system template
    Name VARCHAR(255) NOT NULL,
    Description TEXT,
    IsSystemTemplate BOOLEAN NOT NULL DEFAULT FALSE,
    -- Zone configuration as JSON: [{id, name, x%, y%, width%, height%}]
    ZonesConfig JSONB NOT NULL DEFAULT '[]'::jsonb,
    Orientation VARCHAR(20) NOT NULL DEFAULT 'Landscape',
    PreviewImageUrl VARCHAR(1024),
    CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (OrganizationID) REFERENCES Organizations(OrganizationID) ON DELETE CASCADE
);

-- Display zone assignments: what content goes in which zone
CREATE TABLE IF NOT EXISTS DisplayZones (
    DisplayZoneID SERIAL PRIMARY KEY,
    DisplayID INT NOT NULL,
    LayoutTemplateID INT NOT NULL,
    ZoneId VARCHAR(64) NOT NULL, -- Matches zone id in ZonesConfig
    ZoneName VARCHAR(255),
    -- Content for this zone (one of these)
    ContentType VARCHAR(20), -- 'campaign', 'menu', 'infoboard', 'widget', 'ticker'
    CampaignID INT,
    MenuID INT,
    InfoBoardID INT,
    WidgetType VARCHAR(64), -- 'clock', 'weather', 'rss', 'social'
    WidgetConfig JSONB DEFAULT '{}'::jsonb,
    -- For ticker zones
    TickerText TEXT,
    TickerSpeed INT DEFAULT 50, -- pixels per second
    CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (DisplayID) REFERENCES Displays(DisplayID) ON DELETE CASCADE,
    FOREIGN KEY (LayoutTemplateID) REFERENCES LayoutTemplates(LayoutTemplateID) ON DELETE CASCADE,
    FOREIGN KEY (CampaignID) REFERENCES Campaigns(CampaignID) ON DELETE SET NULL,
    FOREIGN KEY (MenuID) REFERENCES Menus(MenuID) ON DELETE SET NULL,
    FOREIGN KEY (InfoBoardID) REFERENCES InfoBoards(InfoBoardID) ON DELETE SET NULL,
    UNIQUE (DisplayID, ZoneId)
);

-- Add layout template reference to displays
ALTER TABLE Displays ADD COLUMN IF NOT EXISTS LayoutTemplateID INT REFERENCES LayoutTemplates(LayoutTemplateID) ON DELETE SET NULL;

CREATE INDEX idx_displayzones_display ON DisplayZones(DisplayID);


-- Remote Management System

-- Remote commands queue
CREATE TABLE IF NOT EXISTS DisplayCommands (
    CommandID SERIAL PRIMARY KEY,
    DisplayID INT NOT NULL,
    OrganizationID INT NOT NULL,
    CommandType VARCHAR(64) NOT NULL, -- 'reboot', 'screenshot', 'volume', 'brightness', 'refresh', 'clear_cache'
    CommandData JSONB DEFAULT '{}'::jsonb,
    Status VARCHAR(20) NOT NULL DEFAULT 'pending', -- 'pending', 'sent', 'acknowledged', 'completed', 'failed'
    SentAt TIMESTAMP WITH TIME ZONE,
    AcknowledgedAt TIMESTAMP WITH TIME ZONE,
    CompletedAt TIMESTAMP WITH TIME ZONE,
    Result JSONB,
    CreatedByUserID INT,
    CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ExpiresAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT (CURRENT_TIMESTAMP + INTERVAL '1 hour'),
    FOREIGN KEY (DisplayID) REFERENCES Displays(DisplayID) ON DELETE CASCADE,
    FOREIGN KEY (OrganizationID) REFERENCES Organizations(OrganizationID) ON DELETE CASCADE,
    FOREIGN KEY (CreatedByUserID) REFERENCES Users(UserID) ON DELETE SET NULL
);

-- Screenshots storage
CREATE TABLE IF NOT EXISTS DisplayScreenshots (
    ScreenshotID SERIAL PRIMARY KEY,
    DisplayID INT NOT NULL,
    OrganizationID INT NOT NULL,
    StorageUrl VARCHAR(1024) NOT NULL,
    ThumbnailUrl VARCHAR(1024),
    CapturedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FileSize INT,
    Width INT,
    Height INT,
    FOREIGN KEY (DisplayID) REFERENCES Displays(DisplayID) ON DELETE CASCADE,
    FOREIGN KEY (OrganizationID) REFERENCES Organizations(OrganizationID) ON DELETE CASCADE
);

CREATE INDEX idx_displaycommands_display_status ON DisplayCommands(DisplayID, Status);
CREATE INDEX idx_displaycommands_pending ON DisplayCommands(Status) WHERE Status = 'pending';
CREATE INDEX idx_displayscreenshots_display ON DisplayScreenshots(DisplayID);


-- Analytics Enhancements

-- Display uptime tracking
CREATE TABLE IF NOT EXISTS DisplayUptimeLogs (
    UptimeLogID BIGSERIAL PRIMARY KEY,
    DisplayID INT NOT NULL,
    Status VARCHAR(20) NOT NULL, -- 'online', 'offline'
    StartedAt TIMESTAMP WITH TIME ZONE NOT NULL,
    EndedAt TIMESTAMP WITH TIME ZONE,
    DurationSeconds INT,
    FOREIGN KEY (DisplayID) REFERENCES Displays(DisplayID) ON DELETE CASCADE
);

-- Content performance metrics (aggregated)
CREATE TABLE IF NOT EXISTS ContentMetrics (
    MetricID BIGSERIAL PRIMARY KEY,
    OrganizationID INT NOT NULL,
    ContentType VARCHAR(20) NOT NULL, -- 'campaign', 'menu', 'infoboard', 'media'
    ContentID INT NOT NULL,
    MetricDate DATE NOT NULL,
    TotalPlays INT NOT NULL DEFAULT 0,
    TotalDurationSeconds INT NOT NULL DEFAULT 0,
    UniqueDisplays INT NOT NULL DEFAULT 0,
    FOREIGN KEY (OrganizationID) REFERENCES Organizations(OrganizationID) ON DELETE CASCADE,
    UNIQUE (OrganizationID, ContentType, ContentID, MetricDate)
);

CREATE INDEX idx_displayuptimelogs_display ON DisplayUptimeLogs(DisplayID);
CREATE INDEX idx_contentmetrics_org_date ON ContentMetrics(OrganizationID, MetricDate);


-- Transitions & Effects

-- Add transition settings to campaigns
ALTER TABLE Campaigns ADD COLUMN IF NOT EXISTS TransitionType VARCHAR(32) DEFAULT 'fade';
ALTER TABLE Campaigns ADD COLUMN IF NOT EXISTS TransitionDuration INT DEFAULT 500; -- milliseconds

-- Add transition override to campaign items
ALTER TABLE CampaignItems ADD COLUMN IF NOT EXISTS TransitionType VARCHAR(32);
ALTER TABLE CampaignItems ADD COLUMN IF NOT EXISTS TransitionDuration INT;
ALTER TABLE CampaignItems ADD COLUMN IF NOT EXISTS AnimationEffect VARCHAR(32); -- 'kenburns', 'zoom', 'pan'


-- Touch/Interactive Features

-- Touch interaction logs
CREATE TABLE IF NOT EXISTS TouchInteractions (
    InteractionID BIGSERIAL PRIMARY KEY,
    DisplayID INT NOT NULL,
    OrganizationID INT NOT NULL,
    ContentType VARCHAR(20) NOT NULL,
    ContentID INT NOT NULL,
    InteractionType VARCHAR(32) NOT NULL, -- 'tap', 'swipe', 'hold'
    InteractionData JSONB,
    CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (DisplayID) REFERENCES Displays(DisplayID) ON DELETE CASCADE,
    FOREIGN KEY (OrganizationID) REFERENCES Organizations(OrganizationID) ON DELETE CASCADE
);

-- Touch-enabled menu items (links to external URLs, actions)
ALTER TABLE MenuItems ADD COLUMN IF NOT EXISTS TouchEnabled BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE MenuItems ADD COLUMN IF NOT EXISTS TouchAction VARCHAR(32); -- 'link', 'qrcode', 'expand'
ALTER TABLE MenuItems ADD COLUMN IF NOT EXISTS TouchActionData JSONB;

CREATE INDEX idx_touchinteractions_display ON TouchInteractions(DisplayID);


-- External Integrations

CREATE TABLE IF NOT EXISTS IntegrationConnections (
    ConnectionID SERIAL PRIMARY KEY,
    OrganizationID INT NOT NULL,
    IntegrationType VARCHAR(64) NOT NULL, -- 'weather', 'rss', 'social_twitter', 'social_instagram', 'google_sheets', 'pos'
    Name VARCHAR(255) NOT NULL,
    Config JSONB NOT NULL DEFAULT '{}'::jsonb, -- API keys, endpoints, etc (encrypted sensitive fields)
    IsActive BOOLEAN NOT NULL DEFAULT TRUE,
    LastSyncAt TIMESTAMP WITH TIME ZONE,
    LastSyncStatus VARCHAR(20), -- 'success', 'failed'
    LastSyncError TEXT,
    CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (OrganizationID) REFERENCES Organizations(OrganizationID) ON DELETE CASCADE
);

-- Cached integration data
CREATE TABLE IF NOT EXISTS IntegrationData (
    DataID SERIAL PRIMARY KEY,
    ConnectionID INT NOT NULL,
    DataKey VARCHAR(255) NOT NULL,
    DataValue JSONB NOT NULL,
    ExpiresAt TIMESTAMP WITH TIME ZONE,
    CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (ConnectionID) REFERENCES IntegrationConnections(ConnectionID) ON DELETE CASCADE,
    UNIQUE (ConnectionID, DataKey)
);

CREATE INDEX idx_integrationconnections_org ON IntegrationConnections(OrganizationID);


-- Content Templates Library

CREATE TABLE IF NOT EXISTS ContentTemplates (
    TemplateID SERIAL PRIMARY KEY,
    OrganizationID INT, -- NULL = system/marketplace template
    Name VARCHAR(255) NOT NULL,
    Description TEXT,
    Category VARCHAR(64) NOT NULL, -- 'restaurant', 'retail', 'corporate', 'healthcare', 'education'
    TemplateType VARCHAR(32) NOT NULL, -- 'menu', 'infoboard', 'campaign', 'layout'
    ThumbnailUrl VARCHAR(1024),
    TemplateData JSONB NOT NULL, -- Full template configuration
    Tags JSONB DEFAULT '[]'::jsonb,
    IsPublic BOOLEAN NOT NULL DEFAULT FALSE,
    IsSystemTemplate BOOLEAN NOT NULL DEFAULT FALSE,
    UsageCount INT NOT NULL DEFAULT 0,
    Rating DECIMAL(3,2),
    CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (OrganizationID) REFERENCES Organizations(OrganizationID) ON DELETE CASCADE
);

CREATE INDEX idx_contenttemplates_category ON ContentTemplates(Category);
CREATE INDEX idx_contenttemplates_type ON ContentTemplates(TemplateType);
CREATE INDEX idx_contenttemplates_public ON ContentTemplates(IsPublic) WHERE IsPublic = TRUE;


-- Team Management & Roles

-- Roles table
CREATE TABLE IF NOT EXISTS Roles (
    RoleID SERIAL PRIMARY KEY,
    OrganizationID INT, -- NULL = system role
    Name VARCHAR(64) NOT NULL,
    Description TEXT,
    Permissions JSONB NOT NULL DEFAULT '[]'::jsonb, -- Array of permission strings
    IsSystemRole BOOLEAN NOT NULL DEFAULT FALSE,
    CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (OrganizationID) REFERENCES Organizations(OrganizationID) ON DELETE CASCADE
);

-- Team invitations
CREATE TABLE IF NOT EXISTS TeamInvitations (
    InvitationID SERIAL PRIMARY KEY,
    OrganizationID INT NOT NULL,
    Email VARCHAR(255) NOT NULL,
    RoleID INT NOT NULL,
    InvitedByUserID INT NOT NULL,
    TokenHash VARCHAR(128) NOT NULL UNIQUE,
    ExpiresAt TIMESTAMP WITH TIME ZONE NOT NULL,
    AcceptedAt TIMESTAMP WITH TIME ZONE,
    CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (OrganizationID) REFERENCES Organizations(OrganizationID) ON DELETE CASCADE,
    FOREIGN KEY (RoleID) REFERENCES Roles(RoleID) ON DELETE CASCADE,
    FOREIGN KEY (InvitedByUserID) REFERENCES Users(UserID) ON DELETE CASCADE
);

-- Add role reference to users
ALTER TABLE Users ADD COLUMN IF NOT EXISTS RoleID INT REFERENCES Roles(RoleID) ON DELETE SET NULL;

-- Location/venue grouping for multi-location support
CREATE TABLE IF NOT EXISTS Locations (
    LocationID SERIAL PRIMARY KEY,
    OrganizationID INT NOT NULL,
    Name VARCHAR(255) NOT NULL,
    Address TEXT,
    City VARCHAR(128),
    State VARCHAR(64),
    Country VARCHAR(64),
    Timezone VARCHAR(64) DEFAULT 'UTC',
    Latitude DECIMAL(10,7),
    Longitude DECIMAL(10,7),
    CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (OrganizationID) REFERENCES Organizations(OrganizationID) ON DELETE CASCADE
);

-- Add location to displays
ALTER TABLE Displays ADD COLUMN IF NOT EXISTS LocationID INT REFERENCES Locations(LocationID) ON DELETE SET NULL;

CREATE INDEX idx_roles_org ON Roles(OrganizationID);
CREATE INDEX idx_teaminvitations_org ON TeamInvitations(OrganizationID);
CREATE INDEX idx_teaminvitations_email ON TeamInvitations(Email);
CREATE INDEX idx_locations_org ON Locations(OrganizationID);


-- Insert default system roles
INSERT INTO Roles (Name, Description, Permissions, IsSystemRole) VALUES
('Owner', 'Full access to all features', '["*"]', TRUE),
('Admin', 'Administrative access, can manage users and settings', '["displays.*", "content.*", "analytics.*", "settings.*", "users.manage"]', TRUE),
('Editor', 'Can create and edit content', '["displays.view", "content.*", "analytics.view"]', TRUE),
('Viewer', 'Read-only access', '["displays.view", "content.view", "analytics.view"]', TRUE)
ON CONFLICT DO NOTHING;

-- Insert default layout templates
INSERT INTO LayoutTemplates (Name, Description, IsSystemTemplate, ZonesConfig, Orientation) VALUES
('Full Screen', 'Single zone covering the entire display', TRUE, 
 '[{"id": "main", "name": "Main", "x": 0, "y": 0, "width": 100, "height": 100}]', 'Landscape'),
('Split Horizontal', 'Two zones side by side (50/50)', TRUE,
 '[{"id": "left", "name": "Left", "x": 0, "y": 0, "width": 50, "height": 100}, {"id": "right", "name": "Right", "x": 50, "y": 0, "width": 50, "height": 100}]', 'Landscape'),
('Split Vertical', 'Two zones stacked (50/50)', TRUE,
 '[{"id": "top", "name": "Top", "x": 0, "y": 0, "width": 100, "height": 50}, {"id": "bottom", "name": "Bottom", "x": 0, "y": 50, "width": 100, "height": 50}]', 'Landscape'),
('Main with Ticker', 'Main content area with ticker at bottom', TRUE,
 '[{"id": "main", "name": "Main", "x": 0, "y": 0, "width": 100, "height": 90}, {"id": "ticker", "name": "Ticker", "x": 0, "y": 90, "width": 100, "height": 10}]', 'Landscape'),
('Main with Sidebar', 'Large main area with sidebar for widgets', TRUE,
 '[{"id": "main", "name": "Main", "x": 0, "y": 0, "width": 75, "height": 100}, {"id": "sidebar", "name": "Sidebar", "x": 75, "y": 0, "width": 25, "height": 100}]', 'Landscape'),
('Three Column', 'Three equal columns', TRUE,
 '[{"id": "left", "name": "Left", "x": 0, "y": 0, "width": 33.33, "height": 100}, {"id": "center", "name": "Center", "x": 33.33, "y": 0, "width": 33.34, "height": 100}, {"id": "right", "name": "Right", "x": 66.67, "y": 0, "width": 33.33, "height": 100}]', 'Landscape'),
('L-Shape', 'Large main with corner widgets', TRUE,
 '[{"id": "main", "name": "Main", "x": 0, "y": 0, "width": 75, "height": 75}, {"id": "topright", "name": "Top Right", "x": 75, "y": 0, "width": 25, "height": 50}, {"id": "bottomright", "name": "Bottom Right", "x": 75, "y": 50, "width": 25, "height": 25}, {"id": "bottom", "name": "Bottom", "x": 0, "y": 75, "width": 75, "height": 25}]', 'Landscape')
ON CONFLICT DO NOTHING;

-- Insert sample content templates
INSERT INTO ContentTemplates (Name, Description, Category, TemplateType, IsSystemTemplate, IsPublic, TemplateData) VALUES
('Restaurant Menu - Classic', 'Traditional menu layout with sections', 'restaurant', 'menu', TRUE, TRUE, 
 '{"templateKey": "classic", "themeConfig": {"backgroundColor": "#1a1a2e", "textColor": "#ffffff", "accentColor": "#e94560"}}'),
('Coffee Shop Menu', 'Modern coffee shop style menu', 'restaurant', 'menu', TRUE, TRUE,
 '{"templateKey": "modern", "themeConfig": {"backgroundColor": "#2d2d2d", "textColor": "#f5f5f5", "accentColor": "#c9a227"}}'),
('Retail Promo Board', 'Eye-catching promotional display', 'retail', 'infoboard', TRUE, TRUE,
 '{"layout": "promo", "animations": true}'),
('Corporate Announcement', 'Clean corporate communication board', 'corporate', 'infoboard', TRUE, TRUE,
 '{"layout": "announcement", "showDateTime": true}'),
('Healthcare Waiting Room', 'Patient information display', 'healthcare', 'infoboard', TRUE, TRUE,
 '{"layout": "info", "showQueue": true}')
ON CONFLICT DO NOTHING;
