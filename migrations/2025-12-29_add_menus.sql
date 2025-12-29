-- Adds menu builder Phase 1 tables and enables campaigns to reference menus

-- Menus (top-level)
CREATE TABLE IF NOT EXISTS Menus (
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

CREATE INDEX IF NOT EXISTS IX_Menus_OrganizationID ON Menus(OrganizationID);

-- MenuSections
CREATE TABLE IF NOT EXISTS MenuSections (
    MenuSectionID SERIAL PRIMARY KEY,
    MenuID INT NOT NULL,
    Name VARCHAR(255) NOT NULL,
    DisplayOrder INT NOT NULL DEFAULT 0,
    CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (MenuID) REFERENCES Menus(MenuID) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS IX_MenuSections_MenuID ON MenuSections(MenuID);

-- MenuItems
CREATE TABLE IF NOT EXISTS MenuItems (
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

CREATE INDEX IF NOT EXISTS IX_MenuItems_MenuSectionID ON MenuItems(MenuSectionID);

-- CampaignItems can now reference either a MediaFile (existing) or a Menu.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name='campaignitems' AND column_name='itemtype'
  ) THEN
    ALTER TABLE CampaignItems ADD COLUMN ItemType VARCHAR(20) NOT NULL DEFAULT 'media';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name='campaignitems' AND column_name='menuid'
  ) THEN
    ALTER TABLE CampaignItems ADD COLUMN MenuID INT;
  END IF;
END $$;

-- MediaFileID becomes optional (still FK)
DO $$
BEGIN
  BEGIN
    ALTER TABLE CampaignItems ALTER COLUMN MediaFileID DROP NOT NULL;
  EXCEPTION WHEN others THEN
    -- ignore if already nullable
  END;
END $$;

-- Foreign key for MenuID
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.table_constraints
    WHERE constraint_type='FOREIGN KEY'
      AND table_name='campaignitems'
      AND constraint_name='fk_campaignitems_menuid'
  ) THEN
    ALTER TABLE CampaignItems
      ADD CONSTRAINT fk_campaignitems_menuid
      FOREIGN KEY (MenuID) REFERENCES Menus(MenuID) ON DELETE CASCADE;
  END IF;
END $$;

-- Ensure exactly one target is set based on ItemType.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.table_constraints
    WHERE constraint_type='CHECK'
      AND table_name='campaignitems'
      AND constraint_name='ck_campaignitems_itemtype_target'
  ) THEN
    ALTER TABLE CampaignItems
      ADD CONSTRAINT ck_campaignitems_itemtype_target
      CHECK (
        (ItemType='media' AND MediaFileID IS NOT NULL AND MenuID IS NULL)
        OR
        (ItemType='menu' AND MenuID IS NOT NULL AND MediaFileID IS NULL)
      );
  END IF;
END $$;
