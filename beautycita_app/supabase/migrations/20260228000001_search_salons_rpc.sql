-- Migration: search_salons RPC
-- Intelligent fuzzy search across registered businesses.
-- Tokenizes query, resolves city aliases, detects phone numbers,
-- matches remaining tokens via trigram similarity, returns ranked results.

CREATE OR REPLACE FUNCTION public.search_salons(
  query text,
  result_limit int DEFAULT 50,
  result_offset int DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  name text,
  phone text,
  whatsapp text,
  address text,
  city text,
  state text,
  country text,
  photo_url text,
  tier int,
  is_active boolean,
  average_rating numeric,
  total_reviews int,
  owner_id uuid,
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
  city_filter text := NULL;
  state_filter text := NULL;
  phone_filter text := NULL;
  name_tokens text[] := '{}';
  alias_row   record;
BEGIN
  -- Guard: empty or null query returns nothing
  IF query IS NULL OR trim(query) = '' THEN
    RETURN;
  END IF;

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
      city_filter := alias_row.city;
      state_filter := alias_row.state;
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
  IF city_filter IS NULL THEN
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
          city_filter := alias_row.city;
          state_filter := alias_row.state;
          name_tokens := '{}';  -- consumed into city filter
        END IF;
      END IF;
    END;
  END IF;

  RETURN QUERY
  SELECT
    b.id,
    b.name,
    b.phone,
    b.whatsapp,
    b.address,
    b.city,
    b.state,
    b.country,
    b.photo_url,
    b.tier,
    b.is_active,
    b.average_rating,
    b.total_reviews,
    b.owner_id,
    b.created_at,
    (
      -- Relevance scoring
      CASE WHEN city_filter IS NOT NULL AND lower(b.city) = lower(city_filter) THEN 10.0 ELSE 0.0 END
      + CASE WHEN state_filter IS NOT NULL AND lower(b.state) = lower(state_filter) THEN 5.0 ELSE 0.0 END
      + CASE WHEN phone_filter IS NOT NULL AND (
            regexp_replace(coalesce(b.phone,''), '[^0-9]', '', 'g') LIKE '%' || phone_filter || '%'
            OR regexp_replace(coalesce(b.whatsapp,''), '[^0-9]', '', 'g') LIKE '%' || phone_filter || '%'
          ) THEN 15.0 ELSE 0.0 END
      + (
          SELECT coalesce(sum(
            CASE
              WHEN lower(b.name) = nt THEN 20.0
              WHEN lower(b.name) LIKE nt || '%' THEN 10.0
              WHEN lower(b.name) LIKE '%' || nt || '%' THEN 5.0
              ELSE 0.0
            END
            + similarity(lower(b.name), nt) * 8.0
            + CASE WHEN lower(coalesce(b.address,'')) LIKE '%' || nt || '%' THEN 3.0 ELSE 0.0 END
          ), 0.0)
          FROM unnest(name_tokens) AS nt
        )
    )::float AS relevance
  FROM public.businesses b
  WHERE
    -- City filter
    (city_filter IS NULL OR lower(b.city) = lower(city_filter))
    -- State filter
    AND (state_filter IS NULL OR lower(b.state) = lower(state_filter))
    -- Phone filter
    AND (phone_filter IS NULL OR (
      regexp_replace(coalesce(b.phone,''), '[^0-9]', '', 'g') LIKE '%' || phone_filter || '%'
      OR regexp_replace(coalesce(b.whatsapp,''), '[^0-9]', '', 'g') LIKE '%' || phone_filter || '%'
    ))
    -- Name tokens: ALL must match somewhere
    AND (
      array_length(name_tokens, 1) IS NULL
      OR NOT EXISTS (
        SELECT 1
        FROM unnest(name_tokens) AS nt
        WHERE NOT (
          lower(b.name) LIKE '%' || nt || '%'
          OR lower(coalesce(b.address,'')) LIKE '%' || nt || '%'
          OR lower(b.city) LIKE '%' || nt || '%'
          OR lower(b.state) LIKE '%' || nt || '%'
          OR similarity(lower(b.name), nt) > 0.2
        )
      )
    )
  ORDER BY relevance DESC, b.name ASC
  LIMIT result_limit
  OFFSET result_offset;
END;
$$;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION public.search_salons(text, int, int) TO authenticated;
