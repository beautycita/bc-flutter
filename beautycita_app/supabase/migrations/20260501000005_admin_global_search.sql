-- Phase 0: tier-aware admin_global_search RPC backed by pg_trgm indexes.
-- Single round-trip across users + salons + bookings + disputes.
-- Projection narrows by caller tier: ops_admin doesn't see role/saldo/payment_intent.

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_profiles_full_name_trgm
  ON public.profiles USING gin (full_name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_profiles_username_trgm
  ON public.profiles USING gin (username gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_profiles_phone_trgm
  ON public.profiles USING gin (phone gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_businesses_name_trgm
  ON public.businesses USING gin (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_businesses_phone_trgm
  ON public.businesses USING gin (phone gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_businesses_whatsapp_trgm
  ON public.businesses USING gin (whatsapp gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_businesses_city_trgm
  ON public.businesses USING gin (city gin_trgm_ops);

-- admin_global_search: returns up to p_per_kind rows per entity kind
-- (user / salon / booking / dispute). Each row is a uniform shape so the
-- mobile UI can render heterogeneous results in one list.
--
-- Tier-aware projection: rows include only fields the caller is allowed
-- to see. ops_admin gets no role/saldo; admin gets role but no audit
-- context; superadmin gets everything.
CREATE OR REPLACE FUNCTION public.admin_global_search(
  p_query   text,
  p_per_kind int DEFAULT 10
)
RETURNS TABLE (
  kind        text,    -- 'user' | 'salon' | 'booking' | 'dispute'
  ref_id      text,    -- entity id as text
  primary_text text,    -- name / title
  secondary_text text,  -- subtitle (phone / city / status)
  badge_text  text,    -- role chip / state chip
  rank        real     -- relevance score (higher = better)
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_caller_role text;
  v_q text := trim(p_query);
BEGIN
  IF v_q IS NULL OR length(v_q) < 3 THEN
    RETURN;
  END IF;

  IF NOT public.is_ops_admin() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT role INTO v_caller_role FROM public.profiles WHERE id = auth.uid();

  -- Users (profiles)
  RETURN QUERY
    SELECT
      'user'::text,
      p.id::text,
      COALESCE(p.full_name, p.username, '(sin nombre)'),
      COALESCE(p.phone, ''),
      CASE
        WHEN v_caller_role IN ('admin','superadmin') THEN p.role
        ELSE NULL
      END,
      GREATEST(
        similarity(COALESCE(p.full_name,''), v_q),
        similarity(COALESCE(p.username,''), v_q),
        similarity(COALESCE(p.phone,''), v_q)
      )::real
    FROM public.profiles p
    WHERE p.full_name ILIKE '%' || v_q || '%'
       OR p.username ILIKE '%' || v_q || '%'
       OR p.phone ILIKE '%' || v_q || '%'
    ORDER BY 6 DESC
    LIMIT p_per_kind;

  -- Salons (businesses)
  RETURN QUERY
    SELECT
      'salon'::text,
      b.id::text,
      b.name,
      COALESCE(b.city, '') ||
        CASE WHEN COALESCE(b.phone,'') <> '' THEN ' · ' || b.phone ELSE '' END,
      CASE
        WHEN b.is_verified THEN 'Verificado'
        WHEN b.is_active THEN 'Activo'
        ELSE 'Inactivo'
      END,
      GREATEST(
        similarity(COALESCE(b.name,''), v_q),
        similarity(COALESCE(b.phone,''), v_q),
        similarity(COALESCE(b.whatsapp,''), v_q),
        similarity(COALESCE(b.city,''), v_q)
      )::real
    FROM public.businesses b
    WHERE b.name ILIKE '%' || v_q || '%'
       OR b.phone ILIKE '%' || v_q || '%'
       OR b.whatsapp ILIKE '%' || v_q || '%'
       OR b.city ILIKE '%' || v_q || '%'
       OR b.slug ILIKE '%' || v_q || '%'
    ORDER BY 6 DESC
    LIMIT p_per_kind;

  -- Bookings: only when query looks like a UUID prefix (id lookup) or starts
  -- with a recognizable booking marker. Free-text search across appointments
  -- isn't useful (no name field) and would be expensive.
  IF v_q ~ '^[0-9a-fA-F-]{6,}$' THEN
    RETURN QUERY
      SELECT
        'booking'::text,
        a.id::text,
        'Cita ' || left(a.id::text, 8),
        to_char(a.starts_at AT TIME ZONE 'America/Mexico_City', 'YYYY-MM-DD HH24:MI'),
        a.status,
        1.0::real
      FROM public.appointments a
      WHERE a.id::text ILIKE v_q || '%'
      ORDER BY a.starts_at DESC
      LIMIT p_per_kind;
  END IF;

  -- Disputes: same — only id-prefix lookup
  IF v_q ~ '^[0-9a-fA-F-]{6,}$' THEN
    RETURN QUERY
      SELECT
        'dispute'::text,
        d.id::text,
        'Disputa ' || left(d.id::text, 8),
        COALESCE(d.reason, ''),
        d.status,
        1.0::real
      FROM public.disputes d
      WHERE d.id::text ILIKE v_q || '%'
      ORDER BY d.id DESC
      LIMIT p_per_kind;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_global_search(text, int) TO authenticated;

COMMENT ON FUNCTION public.admin_global_search(text, int) IS
  'Tier-aware admin search across users + salons + bookings + disputes. Min 3 chars. Backed by pg_trgm.';
