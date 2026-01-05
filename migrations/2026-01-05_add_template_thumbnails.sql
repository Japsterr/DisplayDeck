-- Migration: Add thumbnail images to system templates
-- Date: 2026-01-05
-- Description: Updates system templates with placeholder thumbnail images

-- Restaurant Menu - Classic
UPDATE contenttemplates 
SET thumbnailurl = '/templates/restaurant-menu.svg',
    updatedat = CURRENT_TIMESTAMP
WHERE templateid = 1 AND issystemtemplate = TRUE;

-- Coffee Shop Menu
UPDATE contenttemplates 
SET thumbnailurl = '/templates/coffee-shop.svg',
    updatedat = CURRENT_TIMESTAMP
WHERE templateid = 2 AND issystemtemplate = TRUE;

-- Retail Promo Board
UPDATE contenttemplates 
SET thumbnailurl = '/templates/retail-promo.svg',
    updatedat = CURRENT_TIMESTAMP
WHERE templateid = 3 AND issystemtemplate = TRUE;

-- Corporate Announcement
UPDATE contenttemplates 
SET thumbnailurl = '/templates/corporate-announcement.svg',
    updatedat = CURRENT_TIMESTAMP
WHERE templateid = 4 AND issystemtemplate = TRUE;

-- Healthcare Waiting Room
UPDATE contenttemplates 
SET thumbnailurl = '/templates/healthcare-waiting.svg',
    updatedat = CURRENT_TIMESTAMP
WHERE templateid = 5 AND issystemtemplate = TRUE;

-- Verify
SELECT templateid, name, thumbnailurl FROM contenttemplates WHERE issystemtemplate = TRUE;
