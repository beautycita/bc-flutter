-- Rename discovered_salons columns to match salon_leads CSV naming conventions.
-- The CSV column names are better identifiers than the original shorthand.
-- Also adds new columns from the CSV dataset and updates source constraint.

BEGIN;

-- -------------------------------------------------------------------------
-- 1. Rename columns
-- -------------------------------------------------------------------------
ALTER TABLE public.discovered_salons RENAME COLUMN name TO business_name;
ALTER TABLE public.discovered_salons RENAME COLUMN address TO location_address;
ALTER TABLE public.discovered_salons RENAME COLUMN city TO location_city;
ALTER TABLE public.discovered_salons RENAME COLUMN state TO location_state;
ALTER TABLE public.discovered_salons RENAME COLUMN lat TO latitude;
ALTER TABLE public.discovered_salons RENAME COLUMN lng TO longitude;
ALTER TABLE public.discovered_salons RENAME COLUMN photo_url TO feature_image_url;
ALTER TABLE public.discovered_salons RENAME COLUMN rating TO rating_average;
ALTER TABLE public.discovered_salons RENAME COLUMN reviews_count TO rating_count;
ALTER TABLE public.discovered_salons RENAME COLUMN business_category TO categories;
ALTER TABLE public.discovered_salons RENAME COLUMN service_categories TO specialties;
ALTER TABLE public.discovered_salons RENAME COLUMN hours TO working_hours;
ALTER TABLE public.discovered_salons RENAME COLUMN instagram_handle TO instagram_url;

-- -------------------------------------------------------------------------
-- 2. Add new columns from CSV dataset
-- -------------------------------------------------------------------------
ALTER TABLE public.discovered_salons ADD COLUMN IF NOT EXISTS slug text;
ALTER TABLE public.discovered_salons ADD COLUMN IF NOT EXISTS bio text;
ALTER TABLE public.discovered_salons ADD COLUMN IF NOT EXISTS email text;
ALTER TABLE public.discovered_salons ADD COLUMN IF NOT EXISTS phone_raw text;
ALTER TABLE public.discovered_salons ADD COLUMN IF NOT EXISTS location_zip text;
ALTER TABLE public.discovered_salons ADD COLUMN IF NOT EXISTS portfolio_images text[];

-- -------------------------------------------------------------------------
-- 3. Migrate existing source values, then update constraint
-- -------------------------------------------------------------------------
UPDATE public.discovered_salons SET source = 'scraper' WHERE source = 'google_maps';

ALTER TABLE public.discovered_salons DROP CONSTRAINT discovered_salons_source_check;
ALTER TABLE public.discovered_salons ADD CONSTRAINT discovered_salons_source_check CHECK (
  source IN ('facebook', 'bing', 'foursquare', 'seccion_amarilla', 'manual', 'scraper')
);

-- -------------------------------------------------------------------------
-- 4. Recreate generated dedup_key column with new column names
-- -------------------------------------------------------------------------
ALTER TABLE public.discovered_salons DROP COLUMN dedup_key;
ALTER TABLE public.discovered_salons ADD COLUMN dedup_key text GENERATED ALWAYS AS (
  coalesce(phone, '') || ':' ||
  round(coalesce(latitude, 0)::numeric, 4)::text || ',' ||
  round(coalesce(longitude, 0)::numeric, 4)::text
) STORED;

-- -------------------------------------------------------------------------
-- 5. Recreate indexes with new column names
-- -------------------------------------------------------------------------
DROP INDEX IF EXISTS idx_discovered_salons_city_status;
CREATE INDEX idx_discovered_salons_city_status
  ON public.discovered_salons (location_city, status);

DROP INDEX IF EXISTS idx_discovered_salons_dedup;
CREATE INDEX idx_discovered_salons_dedup
  ON public.discovered_salons (dedup_key);

-- location GiST index stays — it references the geography column not lat/lng
-- interest index stays — it references interest_count which didn't change

-- -------------------------------------------------------------------------
-- 6. Recreate location trigger with new column names
-- -------------------------------------------------------------------------
DROP TRIGGER IF EXISTS discovered_salons_set_location ON public.discovered_salons;

CREATE OR REPLACE FUNCTION public.handle_discovered_salon_location()
  RETURNS trigger AS $$
BEGIN
  IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
    NEW.location := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER discovered_salons_set_location
  BEFORE INSERT OR UPDATE OF latitude, longitude ON public.discovered_salons
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_discovered_salon_location();

-- -------------------------------------------------------------------------
-- 7. Add slug index for lookups
-- -------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_discovered_salons_slug
  ON public.discovered_salons (slug) WHERE slug IS NOT NULL;

COMMIT;
