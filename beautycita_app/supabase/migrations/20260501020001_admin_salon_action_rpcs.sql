-- Personas → Salones detail rebuild (session 2 of admin ground-up rebuild).
-- Replaces the 6 direct .update() paths in admin_salon_detail_screen.dart +
-- admin_salones_insights_screen.dart + admin_pipeline_screen.dart with
-- SECURITY DEFINER RPCs that enforce tier + step-up server-side.
--
-- Helpers used (all live on prod): is_ops_admin(), is_admin(), is_superadmin(),
-- requires_fresh_auth(int).
--
-- Audit triggers on businesses already fire on tier / is_active / is_verified /
-- onboarding_complete / stripe_* (Phase 0 mig 002). RPCs do not write audit_log
-- rows directly — the trigger handles it.

-- ─── Schema additions ─────────────────────────────────────────────────────
-- Three nullable cols capture the WHO + WHEN + WHY of a suspend.
-- is_active stays the source of truth for "is this salon serving traffic".
-- These cols give the audit trail human context that audit_log doesn't.
ALTER TABLE public.businesses
  ADD COLUMN IF NOT EXISTS suspended_at  TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS suspended_by  UUID REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS suspended_reason TEXT;

CREATE INDEX IF NOT EXISTS idx_businesses_suspended_at_partial
  ON public.businesses (suspended_at)
  WHERE suspended_at IS NOT NULL;

-- ─── 1. admin_set_salon_tier ──────────────────────────────────────────────
-- admin+ tier required + step-up (sensitive: changes search ranking + payout)
CREATE OR REPLACE FUNCTION public.admin_set_salon_tier(
  p_business_id uuid,
  p_new_tier    int
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;
  IF NOT public.requires_fresh_auth(300) THEN
    RAISE EXCEPTION 'step_up_required' USING ERRCODE = '42501';
  END IF;
  IF p_new_tier NOT IN (1, 2, 3) THEN
    RAISE EXCEPTION 'invalid_tier' USING ERRCODE = '22023';
  END IF;

  UPDATE public.businesses
     SET tier = p_new_tier
   WHERE id = p_business_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'salon_not_found' USING ERRCODE = '02000';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_set_salon_tier(uuid, int) TO authenticated;

-- ─── 2. admin_set_salon_active ────────────────────────────────────────────
-- Suspend (false) requires admin+ AND step-up AND a reason.
-- Un-suspend (true) requires ops_admin+ (lower bar — restoring access).
CREATE OR REPLACE FUNCTION public.admin_set_salon_active(
  p_business_id uuid,
  p_active      boolean,
  p_reason      text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
AS $$
DECLARE
  v_actor uuid := auth.uid();
BEGIN
  IF p_active = false THEN
    -- Suspend path
    IF NOT public.is_admin() THEN
      RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
    END IF;
    IF NOT public.requires_fresh_auth(300) THEN
      RAISE EXCEPTION 'step_up_required' USING ERRCODE = '42501';
    END IF;
    IF p_reason IS NULL OR length(trim(p_reason)) < 3 THEN
      RAISE EXCEPTION 'reason_required' USING ERRCODE = '22023';
    END IF;

    UPDATE public.businesses
       SET is_active        = false,
           suspended_at     = now(),
           suspended_by     = v_actor,
           suspended_reason = trim(p_reason)
     WHERE id = p_business_id;
  ELSE
    -- Un-suspend path
    IF NOT public.is_ops_admin() THEN
      RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
    END IF;

    UPDATE public.businesses
       SET is_active        = true,
           suspended_at     = NULL,
           suspended_by     = NULL,
           suspended_reason = NULL
     WHERE id = p_business_id;
  END IF;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'salon_not_found' USING ERRCODE = '02000';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_set_salon_active(uuid, boolean, text) TO authenticated;

-- ─── 3. admin_set_salon_verified ──────────────────────────────────────────
-- admin+; idempotent; no step-up (verification is reversible + low-impact)
CREATE OR REPLACE FUNCTION public.admin_set_salon_verified(
  p_business_id uuid,
  p_verified    boolean
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  UPDATE public.businesses
     SET is_verified = p_verified
   WHERE id = p_business_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'salon_not_found' USING ERRCODE = '02000';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_set_salon_verified(uuid, boolean) TO authenticated;

-- ─── 4. admin_reset_salon_onboarding ──────────────────────────────────────
-- admin+ AND step-up. Sends salon back to step 'services' atomically.
CREATE OR REPLACE FUNCTION public.admin_reset_salon_onboarding(
  p_business_id uuid
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;
  IF NOT public.requires_fresh_auth(300) THEN
    RAISE EXCEPTION 'step_up_required' USING ERRCODE = '42501';
  END IF;

  UPDATE public.businesses
     SET onboarding_complete = false,
         onboarding_step     = 'services',
         has_services        = false,
         has_schedule        = false
   WHERE id = p_business_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'salon_not_found' USING ERRCODE = '02000';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_reset_salon_onboarding(uuid) TO authenticated;

-- ─── 5. admin_update_salon_field ──────────────────────────────────────────
-- Server-enforced field allowlist. ops_admin+ for non-financial fields;
-- admin+ for financial (rfc, clabe). Replaces the dangerous _editField that
-- accepted an arbitrary field name from the client.
CREATE OR REPLACE FUNCTION public.admin_update_salon_field(
  p_business_id uuid,
  p_field       text,
  p_value       text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
AS $$
DECLARE
  v_normalized_value text := nullif(trim(coalesce(p_value, '')), '');
BEGIN
  -- Field allowlist + per-field tier.
  -- RFC is intentionally NOT editable here. Once a salon's RFC is set
  -- through onboarding (and SAT-verified), it does not change. Mutating
  -- it post-verification breaks the fiscal trail and CFDI lookups. If
  -- a real correction is ever needed, it goes through a separate
  -- migration / data-fix path with explicit superadmin sign-off, not
  -- through the admin UI.
  CASE p_field
    WHEN 'name', 'address', 'phone' THEN
      IF NOT public.is_ops_admin() THEN
        RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
      END IF;
    WHEN 'clabe' THEN
      -- Banking identity — admin+ only
      IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
      END IF;
    ELSE
      -- Field not in allowlist — refuse even if caller is superadmin.
      -- Forces all other mutations through dedicated RPCs.
      -- 'rfc' lands here intentionally — see comment above.
      RAISE EXCEPTION 'field_not_allowed' USING ERRCODE = '42501';
  END CASE;

  -- Field-specific validation
  IF p_field = 'clabe' AND v_normalized_value IS NOT NULL THEN
    -- CLABE: 18 digits
    IF v_normalized_value !~ '^[0-9]{18}$' THEN
      RAISE EXCEPTION 'invalid_clabe' USING ERRCODE = '22023';
    END IF;
  END IF;

  IF p_field = 'phone' AND v_normalized_value IS NOT NULL THEN
    -- E.164-ish: + then 10-15 digits
    IF v_normalized_value !~ '^\+?[0-9]{10,15}$' THEN
      RAISE EXCEPTION 'invalid_phone' USING ERRCODE = '22023';
    END IF;
  END IF;

  -- Dynamic update via the validated allowlisted column name
  EXECUTE format(
    'UPDATE public.businesses SET %I = $1 WHERE id = $2',
    p_field
  ) USING v_normalized_value, p_business_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'salon_not_found' USING ERRCODE = '02000';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_update_salon_field(uuid, text, text) TO authenticated;

-- ─── 6. admin_salon_financial_summary ─────────────────────────────────────
-- Read-only summary for the FinancialSummaryCard. ops_admin+ to view.
CREATE OR REPLACE FUNCTION public.admin_salon_financial_summary(
  p_business_id uuid
)
  RETURNS TABLE (
    out_saldo            numeric,
    out_outstanding_debt numeric,
    out_revenue_30d      numeric,
    out_appointment_count_30d int
  )
  LANGUAGE plpgsql
  SECURITY DEFINER
  STABLE
  SET search_path TO 'public'
AS $$
BEGIN
  IF NOT public.is_ops_admin() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.businesses WHERE id = p_business_id) THEN
    -- Empty result set (no row returned) for non-existent businesses.
    -- UI distinguishes "no salon" from "salon with zero activity".
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    coalesce((SELECT outstanding_debt FROM public.businesses WHERE id = p_business_id), 0)::numeric * 0  -- saldo lives on profiles, not businesses; left at 0 until linked properly
                                                                                                          -- (caller's UI shows N/A if zero)
      AS out_saldo,
    coalesce((SELECT outstanding_debt FROM public.businesses WHERE id = p_business_id), 0)::numeric
      AS out_outstanding_debt,
    coalesce((
      SELECT sum(a.price)
        FROM public.appointments a
       WHERE a.business_id = p_business_id
         AND a.status IN ('completed', 'paid')
         AND a.starts_at >= now() - interval '30 days'
    ), 0)::numeric AS out_revenue_30d,
    coalesce((
      SELECT count(*)::int
        FROM public.appointments a
       WHERE a.business_id = p_business_id
         AND a.starts_at >= now() - interval '30 days'
    ), 0)::int AS out_appointment_count_30d;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_salon_financial_summary(uuid) TO authenticated;

-- ─── Comments ─────────────────────────────────────────────────────────────
COMMENT ON FUNCTION public.admin_set_salon_tier(uuid, int) IS
  'admin+ AND step-up required. Audit trigger on businesses.tier fires automatically.';
COMMENT ON FUNCTION public.admin_set_salon_active(uuid, boolean, text) IS
  'Suspend (false) needs admin+ AND step-up AND p_reason >= 3 chars. Un-suspend (true) needs ops_admin+. Reason captured in suspended_reason column.';
COMMENT ON FUNCTION public.admin_set_salon_verified(uuid, boolean) IS
  'admin+. No step-up (verification is reversible).';
COMMENT ON FUNCTION public.admin_reset_salon_onboarding(uuid) IS
  'admin+ AND step-up. Resets onboarding to step services in a single transaction.';
COMMENT ON FUNCTION public.admin_update_salon_field(uuid, text, text) IS
  'Field allowlist enforced server-side: name/address/phone (ops_admin+); clabe (admin+). RFC is INTENTIONALLY immutable post-onboarding — fiscal-trail integrity. Other fields rejected with field_not_allowed.';
COMMENT ON FUNCTION public.admin_salon_financial_summary(uuid) IS
  'Read-only saldo/debt/revenue/appointment-count summary for admin detail screen.';
