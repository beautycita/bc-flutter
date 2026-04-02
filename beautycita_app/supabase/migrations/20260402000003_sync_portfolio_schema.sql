-- =============================================================================
-- Sync portfolio_photos schema with what the code actually uses
-- =============================================================================

-- Drop NOT NULL constraints that code violates (before/after uploaded separately)
ALTER TABLE portfolio_photos ALTER COLUMN before_url DROP NOT NULL;
ALTER TABLE portfolio_photos ALTER COLUMN after_url DROP NOT NULL;

-- Add columns the edge function expects but migration never created
ALTER TABLE portfolio_photos
  ADD COLUMN IF NOT EXISTS is_complete boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS completed_at timestamptz,
  ADD COLUMN IF NOT EXISTS publish_to_feed boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS service_name text,
  ADD COLUMN IF NOT EXISTS client_name text;

-- Add PIN security columns to staff table
ALTER TABLE staff
  ADD COLUMN IF NOT EXISTS upload_pin text,
  ADD COLUMN IF NOT EXISTS upload_qr_token text;

-- Add portfolio template to businesses
ALTER TABLE businesses
  ADD COLUMN IF NOT EXISTS portfolio_template text NOT NULL DEFAULT 'portfolio'
    CHECK (portfolio_template IN ('portfolio', 'teamBuilder', 'storefront', 'gallery', 'local'));

-- Index for storefront queries
CREATE INDEX IF NOT EXISTS idx_portfolio_photos_business
  ON portfolio_photos (business_id, is_complete, publish_to_feed);
