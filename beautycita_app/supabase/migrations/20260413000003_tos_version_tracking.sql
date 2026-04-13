-- ToS version tracking — force re-acceptance when terms change
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS tos_version integer DEFAULT 0;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS tos_accepted_at timestamptz;

COMMENT ON COLUMN businesses.tos_version IS 'Service agreement version accepted. Current: 2. Force re-accept when less than current.';
