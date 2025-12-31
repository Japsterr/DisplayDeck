-- Phase 2: add SKU + optional image URL for menu items

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name='menuitems' AND column_name='sku'
  ) THEN
    ALTER TABLE MenuItems ADD COLUMN Sku VARCHAR(128);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name='menuitems' AND column_name='imageurl'
  ) THEN
    ALTER TABLE MenuItems ADD COLUMN ImageUrl VARCHAR(1024);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS IX_MenuItems_Sku ON MenuItems(Sku);
