-- 2025-12-30: Fix display assignment upserts
-- Ensure the UNIQUE constraints required by ON CONFLICT exist.

-- DisplayMenus: avoid duplicates (DisplayID, MenuID)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.table_constraints
    WHERE constraint_type='UNIQUE'
      AND table_name='displaymenus'
      AND constraint_name='uq_displaymenus_display_menu'
  ) THEN
    ALTER TABLE DisplayMenus
      ADD CONSTRAINT uq_displaymenus_display_menu UNIQUE (DisplayID, MenuID);
  END IF;
END $$;

-- DisplayCampaigns: avoid duplicates (DisplayID, CampaignID)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.table_constraints
    WHERE constraint_type='UNIQUE'
      AND table_name='displaycampaigns'
      AND constraint_name='uq_displaycampaigns_display_campaign'
  ) THEN
    ALTER TABLE DisplayCampaigns
      ADD CONSTRAINT uq_displaycampaigns_display_campaign UNIQUE (DisplayID, CampaignID);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS IX_DisplayCampaigns_DisplayID ON DisplayCampaigns(DisplayID);
CREATE INDEX IF NOT EXISTS IX_DisplayCampaigns_CampaignID ON DisplayCampaigns(CampaignID);
