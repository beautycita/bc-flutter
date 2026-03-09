-- =============================================================================
-- Migration: 20260309100000_discovered_salons_category_mapping.sql
-- Description: Map discovered_salons specialties (Spanish) to app category IDs
--              (English) so the curate-results engine can query them.
--              Also maps Google Maps categories for salons missing specialties.
--              Creates curate_discovered_candidates RPC for fallback queries.
-- =============================================================================

-- 1. Add matched_categories column (stores English category IDs)
ALTER TABLE discovered_salons
  ADD COLUMN IF NOT EXISTS matched_categories text[] DEFAULT '{}';

-- 2. Populate matched_categories from existing specialties (Spanish → English)
--    Specialties use: uñas, cabello, pestañas_cejas, maquillaje, facial,
--                     cuerpo_spa, cuidado_especializado
--    App uses:        nails, hair, lashes_brows, makeup, facial,
--                     body_spa, specialized, barberia
UPDATE discovered_salons
SET matched_categories = (
  SELECT array_agg(DISTINCT mapped) FILTER (WHERE mapped IS NOT NULL)
  FROM unnest(specialties) AS s(val),
  LATERAL (
    SELECT CASE
      WHEN val = 'uñas' THEN 'nails'
      WHEN val = 'cabello' THEN 'hair'
      WHEN val = 'pestañas_cejas' THEN 'lashes_brows'
      WHEN val = 'maquillaje' THEN 'makeup'
      WHEN val = 'facial' THEN 'facial'
      WHEN val = 'cuerpo_spa' THEN 'body_spa'
      WHEN val = 'cuidado_especializado' THEN 'specialized'
      WHEN val = 'barbería' THEN 'barberia'
      WHEN val = 'barberia' THEN 'barberia'
      ELSE NULL
    END AS mapped
  ) m
)
WHERE specialties IS NOT NULL AND array_length(specialties, 1) > 0;

-- 3. Enrich matched_categories from Google Maps categories column
--    This catches barbershops and adds granularity
DO $$
DECLARE
  mapping RECORD;
BEGIN
  -- Define Google Maps category → BeautyCita category mapping
  FOR mapping IN
    SELECT unnest(ARRAY[
      'Barbería', 'Barbería', 'barberia',
      'Peluquería', 'Peluquería', 'hair',
      'Salón de manicura y pedicura', 'Salón de manicura y pedicura', 'nails',
      'Spa', 'Spa', 'body_spa',
      'Spa terapéutico', 'Spa terapéutico', 'body_spa',
      'Spa de día', 'Spa de día', 'body_spa',
      'Massage spa', 'Massage spa', 'body_spa',
      'Masajista', 'Masajista', 'body_spa',
      'Masajista tailandés', 'Masajista tailandés', 'body_spa',
      'Depilación con cera', 'Depilación con cera', 'body_spa',
      'Servicio de depilación', 'Servicio de depilación', 'body_spa',
      'Centro de depilación láser', 'Centro de depilación láser', 'body_spa',
      'Servicio de depilación por electrólisis', 'Servicio de depilación por electrólisis', 'body_spa',
      'Eyelash salon', 'Eyelash salon', 'lashes_brows',
      'Eyebrow bar', 'Eyebrow bar', 'lashes_brows',
      'Make-up artist', 'Make-up artist', 'makeup',
      'Permanent make-up clinic', 'Permanent make-up clinic', 'makeup',
      'Clínica dermatológica', 'Clínica dermatológica', 'facial',
      'Esteticista facial', 'Esteticista facial', 'facial',
      'Dermatólogo', 'Dermatólogo', 'facial',
      'Esteticista', 'Esteticista', 'facial',
      'Centro de bronceado', 'Centro de bronceado', 'body_spa',
      'Estilista', 'Estilista', 'hair',
      'Servicio de eliminación de tatuajes', 'Servicio de eliminación de tatuajes', 'specialized'
    ]) AS val
  LOOP
    -- Skip: we process in triples below
    NULL;
  END LOOP;

  -- Barbería → barberia
  UPDATE discovered_salons
  SET matched_categories = array_append(matched_categories, 'barberia')
  WHERE categories = 'Barbería'
    AND NOT ('barberia' = ANY(matched_categories));

  -- Peluquería → hair
  UPDATE discovered_salons
  SET matched_categories = array_append(matched_categories, 'hair')
  WHERE categories = 'Peluquería'
    AND NOT ('hair' = ANY(matched_categories));

  -- Salón de manicura y pedicura → nails
  UPDATE discovered_salons
  SET matched_categories = array_append(matched_categories, 'nails')
  WHERE categories = 'Salón de manicura y pedicura'
    AND NOT ('nails' = ANY(matched_categories));

  -- Spa variants → body_spa
  UPDATE discovered_salons
  SET matched_categories = array_append(matched_categories, 'body_spa')
  WHERE categories IN ('Spa', 'Spa terapéutico', 'Spa de día', 'Massage spa',
                        'Masajista', 'Masajista tailandés', 'Centro de bronceado')
    AND NOT ('body_spa' = ANY(matched_categories));

  -- Depilación → body_spa
  UPDATE discovered_salons
  SET matched_categories = array_append(matched_categories, 'body_spa')
  WHERE categories IN ('Depilación con cera', 'Servicio de depilación',
                        'Centro de depilación láser', 'Servicio de depilación por electrólisis')
    AND NOT ('body_spa' = ANY(matched_categories));

  -- Eyelash/Eyebrow → lashes_brows
  UPDATE discovered_salons
  SET matched_categories = array_append(matched_categories, 'lashes_brows')
  WHERE categories IN ('Eyelash salon', 'Eyebrow bar')
    AND NOT ('lashes_brows' = ANY(matched_categories));

  -- Makeup → makeup
  UPDATE discovered_salons
  SET matched_categories = array_append(matched_categories, 'makeup')
  WHERE categories IN ('Make-up artist', 'Permanent make-up clinic')
    AND NOT ('makeup' = ANY(matched_categories));

  -- Facial/Dermatology → facial
  UPDATE discovered_salons
  SET matched_categories = array_append(matched_categories, 'facial')
  WHERE categories IN ('Clínica dermatológica', 'Esteticista facial', 'Dermatólogo', 'Esteticista')
    AND NOT ('facial' = ANY(matched_categories));

  -- Estilista → hair
  UPDATE discovered_salons
  SET matched_categories = array_append(matched_categories, 'hair')
  WHERE categories = 'Estilista'
    AND NOT ('hair' = ANY(matched_categories));

  -- Specialized
  UPDATE discovered_salons
  SET matched_categories = array_append(matched_categories, 'specialized')
  WHERE categories = 'Servicio de eliminación de tatuajes'
    AND NOT ('specialized' = ANY(matched_categories));
END $$;

-- 4. Index for fast geo + category queries
CREATE INDEX IF NOT EXISTS idx_discovered_salons_matched_categories
  ON discovered_salons USING gin (matched_categories);

CREATE INDEX IF NOT EXISTS idx_discovered_salons_geo_active
  ON discovered_salons USING gist (location)
  WHERE status NOT IN ('declined', 'unreachable');

-- 5. Create RPC for curate-results fallback
CREATE OR REPLACE FUNCTION public.curate_discovered_candidates(
  p_category text,
  p_lat double precision,
  p_lng double precision,
  p_radius_meters integer
)
RETURNS TABLE (
  salon_id          uuid,
  business_name     text,
  feature_image_url text,
  location_address  text,
  latitude          double precision,
  longitude         double precision,
  phone             text,
  whatsapp          text,
  rating_average    numeric,
  rating_count      integer,
  categories        text,
  working_hours     text,
  website           text,
  instagram_url     text,
  distance_m        double precision
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    ds.id             AS salon_id,
    ds.business_name,
    ds.feature_image_url,
    ds.location_address,
    ds.latitude,
    ds.longitude,
    ds.phone,
    ds.whatsapp,
    ds.rating_average,
    ds.rating_count,
    ds.categories,
    ds.working_hours,
    ds.website,
    ds.instagram_url,
    ST_Distance(
      ds.location,
      ST_MakePoint(p_lng, p_lat)::geography
    ) AS distance_m
  FROM discovered_salons ds
  WHERE p_category = ANY(ds.matched_categories)
    AND ds.status NOT IN ('declined', 'unreachable')
    AND ds.latitude IS NOT NULL
    AND ds.longitude IS NOT NULL
    AND ST_DWithin(
      ds.location,
      ST_MakePoint(p_lng, p_lat)::geography,
      p_radius_meters
    )
  ORDER BY distance_m ASC
  LIMIT 20;
$$;

COMMENT ON FUNCTION public.curate_discovered_candidates IS
  'Finds discovered salons matching a service category within a geographic radius. '
  'Used as fallback by curate-results when registered businesses return < 3 results.';
