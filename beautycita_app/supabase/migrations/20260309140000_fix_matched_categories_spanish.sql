-- Fix matched_categories: use Spanish IDs to match service_profiles.category
-- The original migration (20260309100000) mapped to English IDs (hair, nails, etc.)
-- but service_profiles uses Spanish IDs (cabello, unas, etc.), causing zero matches
-- in curate_discovered_candidates().

UPDATE discovered_salons
SET matched_categories = (
  SELECT array_agg(DISTINCT mapped ORDER BY mapped)
  FROM unnest(matched_categories) AS c(val),
  LATERAL (
    SELECT CASE val
      WHEN 'hair' THEN 'cabello'
      WHEN 'nails' THEN 'unas'
      WHEN 'lashes_brows' THEN 'pestanas_cejas'
      WHEN 'makeup' THEN 'maquillaje'
      WHEN 'facial' THEN 'facial'
      WHEN 'body_spa' THEN 'cuerpo_spa'
      WHEN 'specialized' THEN 'cuidado_especializado'
      WHEN 'barberia' THEN 'barberia'
      ELSE val
    END AS mapped
  ) m
)
WHERE matched_categories IS NOT NULL AND array_length(matched_categories, 1) > 0;

-- Fix barberia services: use barberia category, not cuidado_especializado
UPDATE service_profiles
SET category = 'barberia'
WHERE service_type IN (
  'barberia_corte_barba',
  'barberia_afeitado_clasico',
  'barberia_diseno_barba',
  'barberia_tratamiento_barba'
);

-- Also update the original migration's mapping logic so future imports get
-- Spanish IDs directly. Replace curate_discovered_candidates to accept
-- both Spanish and English category IDs for safety.
CREATE OR REPLACE FUNCTION curate_discovered_candidates(
  p_category text,
  p_lat double precision,
  p_lng double precision,
  p_radius_meters double precision DEFAULT 25000
)
RETURNS TABLE(
  id uuid,
  business_name text,
  phone text,
  whatsapp text,
  whatsapp_verified boolean,
  location_address text,
  location_city text,
  location_state text,
  latitude double precision,
  longitude double precision,
  rating_average numeric,
  rating_count integer,
  feature_image_url text,
  bio text,
  website text,
  facebook_url text,
  instagram_url text,
  matched_categories text[],
  distance_m double precision
)
LANGUAGE sql STABLE
AS $$
  SELECT
    ds.id,
    ds.business_name,
    ds.phone,
    ds.whatsapp,
    ds.whatsapp_verified,
    ds.location_address,
    ds.location_city,
    ds.location_state,
    ds.latitude,
    ds.longitude,
    ds.rating_average,
    ds.rating_count,
    ds.feature_image_url,
    ds.bio,
    ds.website,
    ds.facebook_url,
    ds.instagram_url,
    ds.matched_categories,
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
