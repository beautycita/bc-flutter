-- =============================================================================
-- High-Value Target classifier for discovered_salons
-- =============================================================================
-- A salon scoring + tiering layer for recruitment posture. Not CRM. Not analytics.
-- The team uses tier to decide HOW to approach a lead BEFORE first contact:
-- a multi-location chain owner gets a senior call; a single mass-market salon
-- gets bulk WA. Mishandling a tier-1 ("Norma") costs us 4 salons; nailing it
-- cascades into 4+ free conversions.
--
-- Tiers (top → bottom):
--   t1 estrella     — multi-location chain, 10+ yr brand, social proof leader
--   t2 lider        — single high-volume, 5+ yr, ≥4.6 rating, ≥50 reviews
--   t3 establecido  — operating 2+ yr, healthy review count, no red flags
--   t4 estandar     — new (<2 yr) or modest footprint, normal rating
--   t5 volumen      — mass-market / discount / chain franchise, low-touch
--   t6 marginal     — inactive, dead phone, fake/duplicate, not yet ready
-- =============================================================================

-- 1. Tier definitions table (admin-editable labels/posture/colors).
CREATE TABLE IF NOT EXISTS public.discovered_salon_tiers (
  id           text         PRIMARY KEY,
  rank         smallint     UNIQUE NOT NULL,
  label        text         NOT NULL,
  description  text         NOT NULL,
  posture      text         NOT NULL,
  color_hex    text         NOT NULL DEFAULT '#777777',
  is_active    boolean      NOT NULL DEFAULT true,
  updated_at   timestamptz  NOT NULL DEFAULT now(),
  updated_by   uuid         REFERENCES auth.users(id)
);

INSERT INTO public.discovered_salon_tiers (id, rank, label, description, posture, color_hex)
VALUES
  ('t1','1','Estrella',
    'Cadena multi-sucursal, marca con 10+ años, líder en redes sociales o influencer del sector.',
    'Atención senior. Llamada personal o visita en persona. Sin plantillas. BC o Bertha contacta directamente. Una mala primera impresión cuesta 4+ salones.',
    '#FFD700'),
  ('t2','2','Lider',
    'Salón único de alto volumen, 5+ años, calificación ≥4.6 y ≥50 reseñas.',
    'WhatsApp curado a mano + llamada de seguimiento. RP acompañado de un senior.',
    '#C0C0C0'),
  ('t3','3','Establecido',
    'Operando 2+ años, reseñas saludables, sin banderas rojas.',
    'Outreach RP estándar con plantillas variantes "premium".',
    '#CD7F32'),
  ('t4','4','Estandar',
    'Salón nuevo (<2 años) o de huella modesta, calificación normal.',
    'Outreach masivo con plantillas. Estado por defecto.',
    '#A8A8A8'),
  ('t5','5','Volumen',
    'Mercado masivo / descuento / franquicia, onboarding de baja fricción esperado.',
    'WA masivo agresivo, link de registro sin fricción.',
    '#7FB069'),
  ('t6','6','Marginal',
    'Listings inactivos, teléfono muerto, falso o duplicado, operación unipersonal no lista.',
    'Saltar / archivar. No gastar presupuesto de outreach.',
    '#5C5C5C')
ON CONFLICT (id) DO NOTHING;

-- 2. Tier-assignment audit-history table. Append-only; one is_current=true per salon.
CREATE TABLE IF NOT EXISTS public.discovered_salon_tier_assignments (
  id                   uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
  discovered_salon_id  uuid         NOT NULL REFERENCES public.discovered_salons(id) ON DELETE CASCADE,
  tier_id              text         NOT NULL REFERENCES public.discovered_salon_tiers(id),
  assigned_by          uuid         REFERENCES auth.users(id),
  source               text         NOT NULL CHECK (source IN ('auto','manual','override')),
  reason               text,
  signal_snapshot      jsonb,
  is_current           boolean      NOT NULL DEFAULT true,
  created_at           timestamptz  NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_tier_assignment_one_current_per_salon
  ON public.discovered_salon_tier_assignments (discovered_salon_id)
  WHERE is_current = true;

CREATE INDEX IF NOT EXISTS idx_tier_assignment_history
  ON public.discovered_salon_tier_assignments (discovered_salon_id, created_at DESC);

-- 3. Signal columns + cached tier on discovered_salons.
ALTER TABLE public.discovered_salons
  ADD COLUMN IF NOT EXISTS tier_id                  text REFERENCES public.discovered_salon_tiers(id),
  ADD COLUMN IF NOT EXISTS hvt_score                numeric(5,2),
  ADD COLUMN IF NOT EXISTS owner_chain_size         smallint DEFAULT 1,
  ADD COLUMN IF NOT EXISTS years_in_business        smallint,
  ADD COLUMN IF NOT EXISTS reputation_signal_count  integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS reputation_score         numeric(3,2),
  ADD COLUMN IF NOT EXISTS social_followers         integer,
  ADD COLUMN IF NOT EXISTS press_mentions           integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS tier_locked              boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS tier_classified_at       timestamptz;

CREATE INDEX IF NOT EXISTS idx_discovered_salons_tier
  ON public.discovered_salons (tier_id) WHERE tier_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_discovered_salons_hvt_score
  ON public.discovered_salons (hvt_score DESC NULLS LAST);

-- 4. Trigger: when a tier_assignment row is marked is_current=true, sync the
--    cached column on discovered_salons AND demote any prior current row.
CREATE OR REPLACE FUNCTION public.sync_current_tier_assignment()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.is_current = true THEN
    UPDATE public.discovered_salon_tier_assignments
       SET is_current = false
     WHERE discovered_salon_id = NEW.discovered_salon_id
       AND id <> NEW.id
       AND is_current = true;

    UPDATE public.discovered_salons
       SET tier_id = NEW.tier_id,
           tier_classified_at = NEW.created_at
     WHERE id = NEW.discovered_salon_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tier_assignment_sync ON public.discovered_salon_tier_assignments;
CREATE TRIGGER tier_assignment_sync
  AFTER INSERT OR UPDATE OF is_current ON public.discovered_salon_tier_assignments
  FOR EACH ROW EXECUTE FUNCTION public.sync_current_tier_assignment();

-- 5. RLS: admin/superadmin only on tiers + assignments. Read-only on tier defs
--    for any authed user (so the Pipeline screen can show tier badges).
ALTER TABLE public.discovered_salon_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.discovered_salon_tier_assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tiers: read by anyone authed"
  ON public.discovered_salon_tiers FOR SELECT
  TO authenticated USING (is_active = true);

CREATE POLICY "tiers: superadmin all"
  ON public.discovered_salon_tiers FOR ALL
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles
                   WHERE id = auth.uid() AND role = 'superadmin'))
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles
                        WHERE id = auth.uid() AND role = 'superadmin'));

CREATE POLICY "tier_assignments: admin read"
  ON public.discovered_salon_tier_assignments FOR SELECT
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles
                   WHERE id = auth.uid() AND role IN ('admin','superadmin')));

CREATE POLICY "tier_assignments: admin write"
  ON public.discovered_salon_tier_assignments FOR INSERT
  TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles
                        WHERE id = auth.uid() AND role IN ('admin','superadmin')));

-- 6. Same-owner chain detection. Phone last-7 + name-token overlap + within 5km.
--    Returns IDs of sibling salons (excluding self). Used by the classifier
--    to compute owner_chain_size for tier-1 detection (the "Norma has 4 nail
--    salons" case).
CREATE OR REPLACE FUNCTION public.detect_same_owner_siblings(p_salon_id uuid)
RETURNS TABLE (sibling_id uuid, match_score numeric)
LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_phone7   text;
  v_lat      double precision;
  v_lng      double precision;
  v_tokens   text[];
BEGIN
  SELECT
    NULLIF(regexp_replace(COALESCE(phone, whatsapp, ''), '[^0-9]', '', 'g'), ''),
    latitude, longitude,
    string_to_array(lower(regexp_replace(business_name, '[^a-záéíóúñ ]', '', 'g')), ' ')
  INTO v_phone7, v_lat, v_lng, v_tokens
  FROM public.discovered_salons
  WHERE id = p_salon_id;

  IF v_phone7 IS NOT NULL AND length(v_phone7) >= 7 THEN
    v_phone7 := right(v_phone7, 7);
  ELSE
    v_phone7 := NULL;
  END IF;

  RETURN QUERY
  SELECT
    s.id,
    -- score components: phone match 0.5, name token overlap 0..0.3, geo proximity 0..0.2
    LEAST(1.0,
      (CASE WHEN v_phone7 IS NOT NULL
              AND length(regexp_replace(COALESCE(s.phone, s.whatsapp, ''), '[^0-9]', '', 'g')) >= 7
              AND right(regexp_replace(COALESCE(s.phone, s.whatsapp, ''), '[^0-9]', '', 'g'), 7) = v_phone7
            THEN 0.5 ELSE 0 END)
      +
      (CASE WHEN v_tokens IS NOT NULL THEN
        LEAST(0.3,
          0.1 * cardinality(
            ARRAY(
              SELECT unnest(v_tokens)
              INTERSECT
              SELECT unnest(string_to_array(lower(regexp_replace(s.business_name, '[^a-záéíóúñ ]', '', 'g')), ' '))
            )::text[]
          )
        )
      ELSE 0 END)
      +
      (CASE WHEN v_lat IS NOT NULL AND s.latitude IS NOT NULL
              AND public.haversine_km(v_lat, v_lng, s.latitude, s.longitude) < 5
            THEN 0.2 * (1 - LEAST(1, public.haversine_km(v_lat, v_lng, s.latitude, s.longitude) / 5.0))
            ELSE 0 END)
    ) AS match_score
  FROM public.discovered_salons s
  WHERE s.id <> p_salon_id
    AND (
      (v_phone7 IS NOT NULL
        AND length(regexp_replace(COALESCE(s.phone, s.whatsapp, ''), '[^0-9]', '', 'g')) >= 7
        AND right(regexp_replace(COALESCE(s.phone, s.whatsapp, ''), '[^0-9]', '', 'g'), 7) = v_phone7)
      OR (
        v_tokens IS NOT NULL
        AND v_lat IS NOT NULL AND s.latitude IS NOT NULL
        AND public.haversine_km(v_lat, v_lng, s.latitude, s.longitude) < 5
        AND cardinality(
          ARRAY(
            SELECT unnest(v_tokens)
            INTERSECT
            SELECT unnest(string_to_array(lower(regexp_replace(s.business_name, '[^a-záéíóúñ ]', '', 'g')), ' '))
          )::text[]
        ) >= 2
      )
    );
END;
$$;

-- haversine helper if it doesn't already exist
CREATE OR REPLACE FUNCTION public.haversine_km(
  lat1 double precision, lng1 double precision,
  lat2 double precision, lng2 double precision
) RETURNS double precision LANGUAGE sql IMMUTABLE AS $$
  SELECT 6371 * 2 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2)
    + cos(radians(lat1)) * cos(radians(lat2))
    * power(sin(radians(lng2 - lng1) / 2), 2)
  ));
$$;

GRANT EXECUTE ON FUNCTION public.detect_same_owner_siblings(uuid) TO authenticated;

-- Cheap aggregate-counts RPC for the Insights board (avoids COUNT(*) over
-- 100K+ rows from the client).
CREATE OR REPLACE FUNCTION public.count_salons_per_tier()
RETURNS TABLE (tier_id text, n integer)
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT tier_id, COUNT(*)::int
  FROM public.discovered_salons
  WHERE tier_id IS NOT NULL
  GROUP BY tier_id;
$$;
GRANT EXECUTE ON FUNCTION public.count_salons_per_tier() TO authenticated;

-- 7. App-config defaults: weights + thresholds, tunable from the Tier Editor.
INSERT INTO public.app_config (key, value)
VALUES
  ('hvt_weight_chain',       '0.30'),
  ('hvt_weight_years',       '0.20'),
  ('hvt_weight_reputation',  '0.25'),
  ('hvt_weight_social',      '0.15'),
  ('hvt_weight_press',       '0.10'),
  ('hvt_threshold_t1',       '85'),
  ('hvt_threshold_t2',       '70'),
  ('hvt_threshold_t3',       '55'),
  ('hvt_threshold_t4',       '35'),
  ('hvt_threshold_t5',       '15'),
  ('hvt_autolock_top_tiers', 'true')
ON CONFLICT (key) DO NOTHING;
