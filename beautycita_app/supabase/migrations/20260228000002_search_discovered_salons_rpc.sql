-- Migration: search_discovered_salons RPC
-- Intelligent fuzzy search across discovered_salons for the Pipeline screen.
-- Same tokenize-classify-score pattern as search_salons but with explicit
-- filter parameters (status, city, whatsapp, interest, source) for Pipeline UI.

CREATE OR REPLACE FUNCTION public.search_discovered_salons(
  query text DEFAULT '',
  status_filter text[] DEFAULT NULL,
  city_filter_param text DEFAULT NULL,
  has_whatsapp boolean DEFAULT NULL,
  has_interest boolean DEFAULT NULL,
  source_filter text DEFAULT NULL,
  result_limit int DEFAULT 50,
  result_offset int DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  business_name text,
  phone text,
  whatsapp text,
  location_address text,
  location_city text,
  location_state text,
  country text,
  feature_image_url text,
  rating_average numeric,
  rating_count int,
  categories text,
  source text,
  status text,
  interest_count int,
  outreach_count int,
  last_outreach_at timestamptz,
  outreach_channel text,
  whatsapp_verified boolean,
  created_at timestamptz,
  relevance float
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  raw_tokens  text[];
  tok         text;
  city_from_query text := NULL;
  state_from_query text := NULL;
  phone_filter text := NULL;
  name_tokens text[] := '{}';
  alias_row   record;
  has_search  boolean;
BEGIN
  -- Determine if there is a text query to process
  has_search := query IS NOT NULL AND trim(query) <> '';

  IF has_search THEN
    -- Tokenize: split on whitespace, lowercase
    raw_tokens := string_to_array(lower(trim(query)), ' ');

    -- Classify each token
    FOREACH tok IN ARRAY raw_tokens LOOP
      -- Skip empty tokens (double spaces)
      IF tok = '' THEN
        CONTINUE;
      END IF;

      -- 1. Check city_aliases table
      SELECT ca.city, ca.state INTO alias_row
        FROM public.city_aliases ca
       WHERE ca.alias = tok
       LIMIT 1;

      IF FOUND THEN
        city_from_query := alias_row.city;
        state_from_query := alias_row.state;
        CONTINUE;
      END IF;

      -- 2. Phone number detection: all digits and 3+ chars
      IF tok ~ '^\d{3,}$' THEN
        phone_filter := tok;
        CONTINUE;
      END IF;

      -- 3. Everything else is a name/text token
      name_tokens := array_append(name_tokens, tok);
    END LOOP;

    -- Also try multi-word alias (full query minus phone tokens)
    -- e.g. "puerto vallarta" or "san antonio"
    IF city_from_query IS NULL THEN
      DECLARE
        multi_alias text;
      BEGIN
        -- Rebuild non-phone tokens as a single string and check aliases
        multi_alias := array_to_string(name_tokens, ' ');
        IF multi_alias <> '' THEN
          SELECT ca.city, ca.state INTO alias_row
            FROM public.city_aliases ca
           WHERE ca.alias = multi_alias
           LIMIT 1;

          IF FOUND THEN
            city_from_query := alias_row.city;
            state_from_query := alias_row.state;
            name_tokens := '{}';  -- consumed into city filter
          END IF;
        END IF;
      END;
    END IF;
  END IF;

  RETURN QUERY
  SELECT
    d.id,
    d.business_name,
    d.phone,
    d.whatsapp,
    d.location_address,
    d.location_city,
    d.location_state,
    d.country,
    d.feature_image_url,
    d.rating_average,
    d.rating_count,
    d.categories,
    d.source,
    d.status,
    d.interest_count,
    d.outreach_count,
    d.last_outreach_at,
    d.outreach_channel,
    d.whatsapp_verified,
    d.created_at,
    (
      -- Relevance scoring (only when search query is present)
      CASE WHEN city_from_query IS NOT NULL AND lower(d.location_city) = lower(city_from_query) THEN 10.0 ELSE 0.0 END
      + CASE WHEN state_from_query IS NOT NULL AND lower(d.location_state) = lower(state_from_query) THEN 5.0 ELSE 0.0 END
      + CASE WHEN phone_filter IS NOT NULL AND (
            regexp_replace(coalesce(d.phone,''), '[^0-9]', '', 'g') LIKE '%' || phone_filter || '%'
            OR regexp_replace(coalesce(d.whatsapp,''), '[^0-9]', '', 'g') LIKE '%' || phone_filter || '%'
          ) THEN 15.0 ELSE 0.0 END
      + (
          SELECT coalesce(sum(
            CASE
              WHEN lower(d.business_name) = nt THEN 20.0
              WHEN lower(d.business_name) LIKE nt || '%' THEN 10.0
              WHEN lower(d.business_name) LIKE '%' || nt || '%' THEN 5.0
              ELSE 0.0
            END
            + similarity(lower(d.business_name), nt) * 8.0
            + CASE WHEN lower(coalesce(d.location_address,'')) LIKE '%' || nt || '%' THEN 3.0 ELSE 0.0 END
          ), 0.0)
          FROM unnest(name_tokens) AS nt
        )
    )::float AS relevance
  FROM public.discovered_salons d
  WHERE
    -- Explicit filters (from Pipeline UI dropdowns/toggles)
    (status_filter IS NULL OR d.status = ANY(status_filter))
    AND (city_filter_param IS NULL OR lower(d.location_city) = lower(city_filter_param))
    AND (has_whatsapp IS NULL OR (has_whatsapp = true AND d.whatsapp_verified = true) OR (has_whatsapp = false))
    AND (has_interest IS NULL OR (has_interest = true AND d.interest_count > 0) OR (has_interest = false))
    AND (source_filter IS NULL OR d.source = source_filter)
    -- Search token filters (from query text)
    AND (city_from_query IS NULL OR lower(d.location_city) = lower(city_from_query))
    AND (state_from_query IS NULL OR lower(d.location_state) = lower(state_from_query))
    AND (phone_filter IS NULL OR (
      regexp_replace(coalesce(d.phone,''), '[^0-9]', '', 'g') LIKE '%' || phone_filter || '%'
      OR regexp_replace(coalesce(d.whatsapp,''), '[^0-9]', '', 'g') LIKE '%' || phone_filter || '%'
    ))
    -- Name tokens: ALL must match somewhere
    AND (
      array_length(name_tokens, 1) IS NULL
      OR NOT EXISTS (
        SELECT 1
        FROM unnest(name_tokens) AS nt
        WHERE NOT (
          lower(d.business_name) LIKE '%' || nt || '%'
          OR lower(coalesce(d.location_address,'')) LIKE '%' || nt || '%'
          OR lower(d.location_city) LIKE '%' || nt || '%'
          OR lower(d.location_state) LIKE '%' || nt || '%'
          OR similarity(lower(d.business_name), nt) > 0.2
        )
      )
    )
  ORDER BY relevance DESC, d.interest_count DESC, d.business_name ASC
  LIMIT result_limit
  OFFSET result_offset;
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.search_discovered_salons(text, text[], text, boolean, boolean, text, int, int) TO authenticated;
