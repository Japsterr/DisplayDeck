-- Migration: Enhance MenuItems for professional QSR-style menu boards
-- Date: 2026-01-04
-- 
-- Adds:
--   - Badges (NEW, HOT, SPICY, BESTSELLER, etc.)
--   - Calorie/nutrition info
--   - Variant pricing (sizes/options)
--   - Combo/meal items support
--   - Section panel assignment (for multi-screen displays)
--   - Promotional highlight flag

-- 1. Add new columns to MenuItems
ALTER TABLE MenuItems
    ADD COLUMN IF NOT EXISTS Badges JSONB DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS Calories INT,
    ADD COLUMN IF NOT EXISTS Variants JSONB DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS ComboItems JSONB DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS IsPromo BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS PromoLabel VARCHAR(64),
    ADD COLUMN IF NOT EXISTS OriginalPriceCents INT;

-- Badges: Array of badge objects, e.g. [{"type": "new", "label": "NEW"}, {"type": "spicy", "level": 2}]
-- Variants: Array of variant options, e.g. [{"name": "Small", "priceCents": 2999}, {"name": "Large", "priceCents": 4999}]
-- ComboItems: Array of included items, e.g. [{"name": "Fries"}, {"name": "Drink"}]
-- IsPromo: When true, item is highlighted as a promotion
-- PromoLabel: e.g. "Limited Time", "Special Offer"
-- OriginalPriceCents: For showing crossed-out "was" price

-- 2. Add panel assignment to MenuSections for multi-screen displays
ALTER TABLE MenuSections
    ADD COLUMN IF NOT EXISTS PanelIndex INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS BackgroundColor VARCHAR(9),
    ADD COLUMN IF NOT EXISTS TitleColor VARCHAR(9),
    ADD COLUMN IF NOT EXISTS LayoutStyle VARCHAR(32);

-- PanelIndex: 0 = first screen, 1 = second screen, etc. for multi-display setups
-- BackgroundColor: Optional per-section background override
-- TitleColor: Optional per-section title color
-- LayoutStyle: 'grid', 'list', 'hero', 'combo' - controls how items are rendered

-- 3. Add promotional/hero sections table for featured deals
CREATE TABLE IF NOT EXISTS MenuPromos (
    MenuPromoID SERIAL PRIMARY KEY,
    MenuID INT NOT NULL,
    Title VARCHAR(255) NOT NULL,
    Subtitle VARCHAR(512),
    ImageUrl VARCHAR(1024),
    BackgroundColor VARCHAR(9),
    TextColor VARCHAR(9),
    PriceCents INT,
    PromoLabel VARCHAR(64),
    ValidUntil TIMESTAMP WITH TIME ZONE,
    DisplayOrder INT NOT NULL DEFAULT 0,
    IsActive BOOLEAN NOT NULL DEFAULT TRUE,
    PanelIndex INT DEFAULT 0,
    LayoutPosition VARCHAR(32) DEFAULT 'top',
    CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (MenuID) REFERENCES Menus(MenuID) ON DELETE CASCADE
);

-- LayoutPosition: 'top', 'bottom', 'left', 'right', 'overlay' - where promo appears on screen

-- 4. Add combo/meal sets table for grouping items together
CREATE TABLE IF NOT EXISTS MenuCombos (
    MenuComboID SERIAL PRIMARY KEY,
    MenuID INT NOT NULL,
    MenuSectionID INT,
    Name VARCHAR(255) NOT NULL,
    Description TEXT,
    ImageUrl VARCHAR(1024),
    PriceCents INT,
    OriginalPriceCents INT,
    Badges JSONB DEFAULT '[]'::jsonb,
    IncludedItems JSONB NOT NULL DEFAULT '[]'::jsonb,
    DisplayOrder INT NOT NULL DEFAULT 0,
    IsAvailable BOOLEAN NOT NULL DEFAULT TRUE,
    CreatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (MenuID) REFERENCES Menus(MenuID) ON DELETE CASCADE,
    FOREIGN KEY (MenuSectionID) REFERENCES MenuSections(MenuSectionID) ON DELETE SET NULL
);

-- IncludedItems: e.g. [{"name": "Burger", "imageUrl": "..."}, {"name": "Fries"}, {"name": "Drink", "size": "Medium"}]

-- 5. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_menupromos_menuid ON MenuPromos(MenuID);
CREATE INDEX IF NOT EXISTS idx_menucombos_menuid ON MenuCombos(MenuID);
CREATE INDEX IF NOT EXISTS idx_menucombos_sectionid ON MenuCombos(MenuSectionID);

COMMENT ON TABLE MenuPromos IS 'Promotional banners and featured deals for menu displays';
COMMENT ON TABLE MenuCombos IS 'Combo/meal sets that group multiple items together';
COMMENT ON COLUMN MenuItems.Badges IS 'JSON array of badges like NEW, HOT, SPICY, BESTSELLER';
COMMENT ON COLUMN MenuItems.Variants IS 'JSON array of size/option variants with different prices';
COMMENT ON COLUMN MenuItems.ComboItems IS 'For combo items, lists what is included';
COMMENT ON COLUMN MenuSections.PanelIndex IS 'For multi-screen displays, which panel this section appears on';
