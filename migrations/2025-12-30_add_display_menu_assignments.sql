-- 2025-12-30: Assign menus directly to displays (bulk activation)

CREATE TABLE IF NOT EXISTS DisplayMenus (
  DisplayMenuID SERIAL PRIMARY KEY,
  DisplayID INT NOT NULL,
  MenuID INT NOT NULL,
  IsPrimary BOOLEAN NOT NULL DEFAULT TRUE,
  CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (DisplayID) REFERENCES Displays(DisplayID) ON DELETE CASCADE,
  FOREIGN KEY (MenuID) REFERENCES Menus(MenuID) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS IX_DisplayMenus_DisplayID ON DisplayMenus(DisplayID);
CREATE INDEX IF NOT EXISTS IX_DisplayMenus_MenuID ON DisplayMenus(MenuID);

-- Avoid duplicates
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.table_constraints
    WHERE constraint_type='UNIQUE'
      AND table_name='displaymenus'
      AND constraint_name='uq_displaymenus_display_menu'
  ) THEN
    ALTER TABLE DisplayMenus ADD CONSTRAINT uq_displaymenus_display_menu UNIQUE (DisplayID, MenuID);
  END IF;
END $$;
