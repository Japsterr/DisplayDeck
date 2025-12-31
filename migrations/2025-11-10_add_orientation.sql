-- Add Orientation column to MediaFiles (idempotent)
-- NOTE: schema.sql creates tables without quoting identifiers, so Postgres stores them lowercased.
ALTER TABLE IF EXISTS mediafiles
  ADD COLUMN IF NOT EXISTS orientation VARCHAR(20) NOT NULL DEFAULT 'Landscape';

-- Backfill any existing rows missing or with empty Orientation
DO $$
BEGIN
  IF to_regclass('public.mediafiles') IS NOT NULL THEN
    UPDATE mediafiles
    SET orientation = 'Landscape'
    WHERE orientation IS NULL OR orientation = '';
  END IF;
END $$;
