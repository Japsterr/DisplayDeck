-- Migration: Fix legacy media file URLs that point to localhost
-- Date: 2026-01-05
-- Description: Updates storageurl for media files that were uploaded with localhost URLs
--              to use the correct MinIO endpoint format that can be resolved at runtime

-- Fix URLs pointing to http://localhost:9000/displaydeck-media/...
-- Convert to relative path format: /displaydeck-media/...
UPDATE mediafiles 
SET storageurl = REPLACE(storageurl, 'http://localhost:9000/', '/')
WHERE storageurl LIKE 'http://localhost:9000/%';

-- Fix URLs pointing to http://localhost:3000/minio/displaydeck-media/...
-- Convert to relative path format: /displaydeck-media/...
UPDATE mediafiles 
SET storageurl = REPLACE(storageurl, 'http://localhost:3000/minio/', '/')
WHERE storageurl LIKE 'http://localhost:3000/minio/%';

-- Log the migration
DO $$
DECLARE
    affected_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO affected_count 
    FROM mediafiles 
    WHERE storageurl LIKE '/%';
    
    RAISE NOTICE 'Migration complete. Files with relative paths: %', affected_count;
END $$;
