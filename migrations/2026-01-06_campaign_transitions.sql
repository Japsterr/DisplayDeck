-- Add transition effect support to campaigns
-- Migration: 2026-01-06_campaign_transitions.sql

-- Add transition columns to campaigns table
ALTER TABLE Campaigns 
ADD COLUMN IF NOT EXISTS TransitionType VARCHAR(50) DEFAULT 'fade',
ADD COLUMN IF NOT EXISTS TransitionDuration INTEGER DEFAULT 500;

-- Add transition column to campaign items for per-item transition overrides
ALTER TABLE CampaignItems
ADD COLUMN IF NOT EXISTS TransitionType VARCHAR(50);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_campaigns_transition ON Campaigns(TransitionType);

COMMENT ON COLUMN Campaigns.TransitionType IS 'Transition effect type: none, fade, slide_left, slide_right, slide_up, slide_down, zoom_in, zoom_out';
COMMENT ON COLUMN Campaigns.TransitionDuration IS 'Transition duration in milliseconds (100-2000)';
COMMENT ON COLUMN CampaignItems.TransitionType IS 'Per-item transition override (null = use campaign default)';
