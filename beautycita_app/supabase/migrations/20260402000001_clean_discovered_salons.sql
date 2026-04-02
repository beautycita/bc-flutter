-- =============================================================================
-- Clean discovered_salons: add country flag, normalize Mexican city/state names,
-- create missing nearby RPC, add geo indexes
-- =============================================================================

-- ── Step 1: Add country column to tag Mexico vs US ───────────────────────────
-- Keep ALL data. US salons prove scraper scale. Filter by country in queries.

ALTER TABLE discovered_salons
  ADD COLUMN IF NOT EXISTS country text NOT NULL DEFAULT 'MX';

-- Tag US salons by state name
UPDATE discovered_salons SET country = 'US'
WHERE location_state IN (
  'California', 'Texas', 'Florida', 'Arizona', 'New York', 'Pennsylvania',
  'NC', 'OH', 'CO', 'NV', 'MO', 'TN', 'MN', 'KY', 'NE', 'GA', 'IL',
  'WA', 'OR', 'MA', 'CT', 'NJ', 'VA', 'MD', 'WI', 'IN', 'MI', 'SC',
  'AL', 'LA', 'OK', 'UT', 'IA', 'AR', 'MS', 'KS', 'ID', 'HI', 'NM',
  'SD', 'ND', 'WV', 'MT', 'WY', 'VT', 'NH', 'ME', 'RI', 'DE', 'DC',
  'AK', 'PR'
);

-- Also tag by coordinates outside Mexico bounding box
-- Mexico: lat 14.5-32.7, lng -118.5 to -86.7
UPDATE discovered_salons SET country = 'US'
WHERE country = 'MX'
  AND (latitude < 14.5 OR latitude > 32.7
    OR longitude < -118.5 OR longitude > -86.7);

ALTER TABLE discovered_salons
  ADD COLUMN IF NOT EXISTS enriched_at timestamptz,
  ADD COLUMN IF NOT EXISTS duplicate_of uuid REFERENCES discovered_salons(id);

CREATE INDEX IF NOT EXISTS idx_discovered_salons_country ON discovered_salons (country);
CREATE INDEX IF NOT EXISTS idx_discovered_salons_enriched ON discovered_salons (enriched_at) WHERE enriched_at IS NULL;

-- ── Step 2: Normalize Mexican city names ─────────────────────────────────────

-- Nuevo Leon
UPDATE discovered_salons SET location_city = 'Apodaca'
WHERE location_state = 'Nuevo Leon' AND country = 'MX'
  AND location_city IN ('Cdad. Apodaca', 'Ciudad Apodaca', 'Apodeca');

UPDATE discovered_salons SET location_city = 'San Nicolás de los Garza'
WHERE location_state = 'Nuevo Leon' AND country = 'MX'
  AND lower(location_city) LIKE 'san nicol%';

UPDATE discovered_salons SET location_city = 'San Pedro Garza García'
WHERE location_state = 'Nuevo Leon' AND country = 'MX'
  AND lower(location_city) IN ('san pedro', 'san pedro garza garcia', 'san pedro garza garcía');

UPDATE discovered_salons SET location_city = 'General Escobedo'
WHERE location_state = 'Nuevo Leon' AND country = 'MX'
  AND location_city LIKE '%Escobedo%';

UPDATE discovered_salons SET location_city = 'Benito Juárez'
WHERE location_state = 'Nuevo Leon' AND country = 'MX'
  AND location_city LIKE '%Benito Ju%';

-- Strip "Cdad." / "Ciudad " / "Cd." prefix globally (except "Ciudad de Mexico")
UPDATE discovered_salons
SET location_city = regexp_replace(location_city, '^(Cdad\.\s*|Ciudad\s+|Cd\.\s*)', '', 'i')
WHERE country = 'MX'
  AND location_city ~ '^(Cdad\.|Ciudad |Cd\.)'
  AND location_city NOT LIKE 'Ciudad de Mexico%';

-- Neighborhoods mistaken as cities → parent city (Nuevo Leon)
UPDATE discovered_salons SET location_city = 'Monterrey'
WHERE location_state = 'Nuevo Leon' AND country = 'MX'
  AND location_city IN (
    'Ex-Hacienda Santa Rosa', 'Jardines de la Silla', 'Los Pilares',
    'Real del Sol', 'Roberto Espinoza', 'Santa Rosa', 'Triana',
    'Valle de Juárez', 'Salinas Victoria', 'Nuevo Leon'
  );

-- Title case cleanup
UPDATE discovered_salons
SET location_city = initcap(location_city)
WHERE country = 'MX'
  AND location_city != initcap(location_city)
  AND location_city IS NOT NULL;

-- ── Step 3: Normalize Mexican state names (add accents) ─────────────────────

UPDATE discovered_salons SET location_state = 'Ciudad de México'
WHERE location_state IN ('Ciudad de Mexico', 'CDMX', 'Distrito Federal', 'DF')
  AND country = 'MX';

UPDATE discovered_salons SET location_state = 'Estado de México'
WHERE location_state IN ('Estado de Mexico', 'Edomex', 'Mexico')
  AND country = 'MX';

UPDATE discovered_salons SET location_state = 'Querétaro'
WHERE location_state = 'Queretaro' AND country = 'MX';

UPDATE discovered_salons SET location_state = 'Michoacán'
WHERE location_state = 'Michoacan' AND country = 'MX';

UPDATE discovered_salons SET location_state = 'Yucatán'
WHERE location_state = 'Yucatan' AND country = 'MX';

UPDATE discovered_salons SET location_state = 'San Luis Potosí'
WHERE location_state = 'San Luis Potosi' AND country = 'MX';

UPDATE discovered_salons SET location_state = 'Nuevo León'
WHERE location_state = 'Nuevo Leon' AND country = 'MX';

-- ── Step 4: Create the missing nearby_discovered_salons RPC ──────────────────

CREATE OR REPLACE FUNCTION nearby_discovered_salons(
  p_lat double precision,
  p_lng double precision,
  p_radius_km double precision DEFAULT 25,
  p_limit integer DEFAULT 200
)
RETURNS SETOF discovered_salons
LANGUAGE sql STABLE
AS $$
  SELECT *
  FROM discovered_salons
  WHERE country = 'MX'
    AND status IN ('new', 'contacted', 'interested')
    AND location IS NOT NULL
    AND ST_DWithin(
      location,
      ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
      p_radius_km * 1000
    )
  ORDER BY location <-> ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
  LIMIT p_limit;
$$;

-- ── Step 5: Indexes for geo + country queries ────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_discovered_salons_location_geo
  ON discovered_salons USING gist (location);

CREATE INDEX IF NOT EXISTS idx_discovered_salons_state_city
  ON discovered_salons (location_state, location_city);
