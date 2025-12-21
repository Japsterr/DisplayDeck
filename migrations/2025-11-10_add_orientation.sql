-- Add Orientation column to MediaFiles (idempotent)
ALTER TABLE IF EXISTS "MediaFiles"
  ADD COLUMN IF NOT EXISTS "Orientation" VARCHAR(20) NOT NULL DEFAULT 'Landscape';

-- Backfill any existing rows missing or with empty Orientation
UPDATE "MediaFiles"
SET "Orientation" = 'Landscape'
WHERE "Orientation" IS NULL OR "Orientation" = '';
