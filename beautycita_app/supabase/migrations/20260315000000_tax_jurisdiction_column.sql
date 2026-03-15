-- Add jurisdiction column to tax_withholdings for multi-country extensibility.
-- Default 'MX' since all existing records are Mexican withholdings.
ALTER TABLE tax_withholdings
  ADD COLUMN IF NOT EXISTS jurisdiction text NOT NULL DEFAULT 'MX';

-- Index for filtering by jurisdiction (useful when multiple countries exist)
CREATE INDEX IF NOT EXISTS idx_tax_withholdings_jurisdiction
  ON tax_withholdings (jurisdiction);

COMMENT ON COLUMN tax_withholdings.jurisdiction IS 'ISO 3166-1 alpha-2 country code for the tax jurisdiction (MX, CO, etc.)';
