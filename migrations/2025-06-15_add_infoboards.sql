-- Information Boards: Non-menu content displays
-- Supports: Mall directories, Office building floors, HSEQ posters, Notices, etc.

-- Main InfoBoards table
CREATE TABLE IF NOT EXISTS InfoBoards (
    InfoBoardID SERIAL PRIMARY KEY,
    OrganizationID INT NOT NULL,
    Name VARCHAR(255) NOT NULL,
    BoardType VARCHAR(64) NOT NULL DEFAULT 'directory', -- directory, notice, hseq, custom
    Orientation VARCHAR(20) NOT NULL DEFAULT 'Landscape',
    TemplateKey VARCHAR(64) NOT NULL DEFAULT 'standard',
    ThemeConfig JSONB NOT NULL DEFAULT '{}'::jsonb,
    PublicToken VARCHAR(64) NOT NULL UNIQUE,
    CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (OrganizationID) REFERENCES Organizations(OrganizationID) ON DELETE CASCADE
);

-- Sections for grouping info items (e.g., "Floor 1", "Ground Floor", "Safety Reminders")
CREATE TABLE IF NOT EXISTS InfoBoardSections (
    InfoBoardSectionID SERIAL PRIMARY KEY,
    InfoBoardID INT NOT NULL,
    Name VARCHAR(255) NOT NULL,
    Subtitle VARCHAR(512),
    IconEmoji VARCHAR(16),
    IconUrl VARCHAR(1024),
    DisplayOrder INT NOT NULL DEFAULT 0,
    BackgroundColor VARCHAR(9),
    TitleColor VARCHAR(9),
    LayoutStyle VARCHAR(32) DEFAULT 'list', -- list, grid, cards, tiles
    CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (InfoBoardID) REFERENCES InfoBoards(InfoBoardID) ON DELETE CASCADE
);

-- Individual info items (e.g., "Unit 23 - Hair Salon", "Room 401 - Accounting")
CREATE TABLE IF NOT EXISTS InfoBoardItems (
    InfoBoardItemID SERIAL PRIMARY KEY,
    InfoBoardSectionID INT NOT NULL,
    ItemType VARCHAR(64) NOT NULL DEFAULT 'entry', -- entry, notice, poster, map, qr, contact
    Title VARCHAR(255) NOT NULL,
    Subtitle VARCHAR(512),
    Description TEXT,
    ImageUrl VARCHAR(1024),
    IconEmoji VARCHAR(16),
    Location VARCHAR(255), -- e.g., "Unit 23", "Room 401"
    ContactInfo VARCHAR(512), -- phone/email if applicable
    QrCodeUrl VARCHAR(1024), -- URL for QR code if applicable
    MapPosition JSONB, -- {x, y} for floor plans
    Tags JSONB DEFAULT '[]'::jsonb, -- for filtering/categorizing
    DisplayOrder INT NOT NULL DEFAULT 0,
    IsVisible BOOLEAN NOT NULL DEFAULT TRUE,
    HighlightColor VARCHAR(9),
    CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (InfoBoardSectionID) REFERENCES InfoBoardSections(InfoBoardSectionID) ON DELETE CASCADE
);

-- Link InfoBoards to Displays (similar to DisplayMenus)
CREATE TABLE IF NOT EXISTS DisplayInfoBoards (
    DisplayInfoBoardID SERIAL PRIMARY KEY,
    DisplayID INT NOT NULL,
    InfoBoardID INT NOT NULL,
    IsPrimary BOOLEAN NOT NULL DEFAULT TRUE,
    CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (DisplayID) REFERENCES Displays(DisplayID) ON DELETE CASCADE,
    FOREIGN KEY (InfoBoardID) REFERENCES InfoBoards(InfoBoardID) ON DELETE CASCADE
);

-- Avoid duplicates
ALTER TABLE DisplayInfoBoards
    ADD CONSTRAINT uq_displayinfoboards_display_infoboard UNIQUE (DisplayID, InfoBoardID);

-- Add InfoBoard support to CampaignItems
ALTER TABLE CampaignItems
    ADD COLUMN IF NOT EXISTS InfoBoardID INT;

ALTER TABLE CampaignItems
    ADD CONSTRAINT fk_campaignitems_infoboardid 
    FOREIGN KEY (InfoBoardID) REFERENCES InfoBoards(InfoBoardID) ON DELETE CASCADE;

-- Update the check constraint to allow infoboard type
ALTER TABLE CampaignItems DROP CONSTRAINT IF EXISTS ck_campaignitems_itemtype_target;
ALTER TABLE CampaignItems
    ADD CONSTRAINT ck_campaignitems_itemtype_target
    CHECK (
        (ItemType='media' AND MediaFileID IS NOT NULL AND MenuID IS NULL AND InfoBoardID IS NULL)
        OR
        (ItemType='menu' AND MenuID IS NOT NULL AND MediaFileID IS NULL AND InfoBoardID IS NULL)
        OR
        (ItemType='infoboard' AND InfoBoardID IS NOT NULL AND MediaFileID IS NULL AND MenuID IS NULL)
    );

-- Indexes
CREATE INDEX IF NOT EXISTS idx_infoboards_orgid ON InfoBoards(OrganizationID);
CREATE INDEX IF NOT EXISTS idx_infoboardsections_boardid ON InfoBoardSections(InfoBoardID);
CREATE INDEX IF NOT EXISTS idx_infoboarditems_sectionid ON InfoBoardItems(InfoBoardSectionID);
CREATE INDEX IF NOT EXISTS idx_displayinfoboards_displayid ON DisplayInfoBoards(DisplayID);
CREATE INDEX IF NOT EXISTS idx_displayinfoboards_boardid ON DisplayInfoBoards(InfoBoardID);
