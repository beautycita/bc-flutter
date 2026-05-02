-- =============================================================================
-- 20260502000002 — admin user suspension RPCs (split user/salon + ToS nuke)
-- =============================================================================
-- Three new SECURITY DEFINER RPCs:
--   admin_set_user_status(p_user_id, p_status, p_reason, p_kind)
--     Suspend or reactivate a profile. p_kind = 'standard' | 'tos_violation'.
--     Suspending requires admin+ AND step-up + reason. Reactivating: ops_admin+.
--
--   admin_set_salon_active_v2(p_business_id, p_active, p_reason, p_kind)
--     Wraps admin_set_salon_active to capture suspension_kind. Notifications
--     are NOT sent here — handled by the existing suspend-salon edge fn or by
--     admin_suspend_for_tos_violation when called as the combined nuke.
--
--   admin_suspend_for_tos_violation(p_user_id, p_reason)
--     The "red button" — suspend user + their owned salon, cancel all future
--     appointments at that salon, queue notifications with the no-protection
--     wording. Atomic. Requires superadmin + step-up.
--
-- Schema additions:
--   profiles.suspended_at, suspended_by, suspended_reason, suspension_kind
--   businesses.suspension_kind (suspended_at/by/reason already added in
--   20260501020001_admin_salon_action_rpcs.sql)
-- =============================================================================

-- ─── Schema additions ─────────────────────────────────────────────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS suspended_at      TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS suspended_by      UUID REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS suspended_reason  TEXT,
  ADD COLUMN IF NOT EXISTS suspension_kind   TEXT
    CHECK (suspension_kind IN ('standard', 'tos_violation'));

ALTER TABLE public.businesses
  ADD COLUMN IF NOT EXISTS suspension_kind TEXT
    CHECK (suspension_kind IN ('standard', 'tos_violation'));

CREATE INDEX IF NOT EXISTS idx_profiles_suspended_at_partial
  ON public.profiles (suspended_at)
  WHERE suspended_at IS NOT NULL;

-- ─── 1. admin_set_user_status ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_set_user_status(
  p_user_id uuid,
  p_status  text,
  p_reason  text DEFAULT NULL,
  p_kind    text DEFAULT 'standard'
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
AS $$
DECLARE
  v_actor uuid := auth.uid();
BEGIN
  IF p_status NOT IN ('active', 'suspended', 'archived') THEN
    RAISE EXCEPTION 'invalid_status' USING ERRCODE = '22023';
  END IF;
  IF p_kind NOT IN ('standard', 'tos_violation') THEN
    RAISE EXCEPTION 'invalid_kind' USING ERRCODE = '22023';
  END IF;

  IF p_status = 'suspended' THEN
    IF NOT public.is_admin() THEN
      RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
    END IF;
    IF NOT public.requires_fresh_auth(300) THEN
      RAISE EXCEPTION 'step_up_required' USING ERRCODE = '42501';
    END IF;
    IF p_reason IS NULL OR length(trim(p_reason)) < 3 THEN
      RAISE EXCEPTION 'reason_required' USING ERRCODE = '22023';
    END IF;

    UPDATE public.profiles
       SET status            = 'suspended',
           suspended_at      = now(),
           suspended_by      = v_actor,
           suspended_reason  = trim(p_reason),
           suspension_kind   = p_kind
     WHERE id = p_user_id;
  ELSE
    -- Reactivate / archive
    IF NOT public.is_ops_admin() THEN
      RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
    END IF;

    UPDATE public.profiles
       SET status            = p_status,
           suspended_at      = NULL,
           suspended_by      = NULL,
           suspended_reason  = NULL,
           suspension_kind   = NULL
     WHERE id = p_user_id;
  END IF;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'user_not_found' USING ERRCODE = '02000';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_set_user_status(uuid, text, text, text) TO authenticated;

-- ─── 2. admin_set_salon_kind ──────────────────────────────────────────────
-- Companion to admin_set_salon_active that also stamps suspension_kind.
-- The caller can keep using admin_set_salon_active for the simple path; this
-- one is for explicit ToS-violation suspends from the user-detail screen.
CREATE OR REPLACE FUNCTION public.admin_set_salon_active_v2(
  p_business_id uuid,
  p_active      boolean,
  p_reason      text,
  p_kind        text DEFAULT 'standard'
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
AS $$
DECLARE
  v_actor uuid := auth.uid();
BEGIN
  IF p_kind NOT IN ('standard', 'tos_violation') THEN
    RAISE EXCEPTION 'invalid_kind' USING ERRCODE = '22023';
  END IF;

  IF p_active = false THEN
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
           suspended_reason = trim(p_reason),
           suspension_kind  = p_kind
     WHERE id = p_business_id;
  ELSE
    IF NOT public.is_ops_admin() THEN
      RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
    END IF;

    UPDATE public.businesses
       SET is_active        = true,
           suspended_at     = NULL,
           suspended_by     = NULL,
           suspended_reason = NULL,
           suspension_kind  = NULL
     WHERE id = p_business_id;
  END IF;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'salon_not_found' USING ERRCODE = '02000';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_set_salon_active_v2(uuid, boolean, text, text) TO authenticated;

-- ─── 3. admin_suspend_for_tos_violation ───────────────────────────────────
-- The combined nuke: user + their owned salon + future appointments + push.
CREATE OR REPLACE FUNCTION public.admin_suspend_for_tos_violation(
  p_user_id uuid,
  p_reason  text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
AS $$
DECLARE
  v_actor      uuid := auth.uid();
  v_business   public.businesses%ROWTYPE;
  v_appt_count int  := 0;
  v_msg_body   text;
BEGIN
  -- Top-tier action: superadmin only, step-up, reason mandatory.
  IF NOT public.is_superadmin() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;
  IF NOT public.requires_fresh_auth(300) THEN
    RAISE EXCEPTION 'step_up_required' USING ERRCODE = '42501';
  END IF;
  IF p_reason IS NULL OR length(trim(p_reason)) < 10 THEN
    RAISE EXCEPTION 'reason_required_min_10' USING ERRCODE = '22023';
  END IF;

  -- Suspend user
  UPDATE public.profiles
     SET status           = 'suspended',
         suspended_at     = now(),
         suspended_by     = v_actor,
         suspended_reason = trim(p_reason),
         suspension_kind  = 'tos_violation'
   WHERE id = p_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'user_not_found' USING ERRCODE = '02000';
  END IF;

  -- Find owned business (one-business-per-owner today)
  SELECT * INTO v_business
    FROM public.businesses
   WHERE owner_id = p_user_id
   LIMIT 1;

  IF FOUND THEN
    -- Suspend the salon
    UPDATE public.businesses
       SET is_active        = false,
           suspended_at     = now(),
           suspended_by     = v_actor,
           suspended_reason = trim(p_reason),
           suspension_kind  = 'tos_violation'
     WHERE id = v_business.id;

    -- Cancel all future pending/confirmed appointments
    -- and queue notifications with the no-protection wording.
    WITH cancelled AS (
      UPDATE public.appointments
         SET status              = 'cancelled_business',
             cancel_notified_at  = now(),
             updated_at          = now()
       WHERE business_id = v_business.id
         AND status IN ('pending', 'confirmed')
         AND starts_at >= now()
       RETURNING id, user_id, starts_at, service_name
    )
    INSERT INTO public.notifications (user_id, title, body, channel, metadata)
    SELECT
      c.user_id,
      'Cita cancelada — salón suspendido',
      'Por violación a nuestros términos, ' || v_business.name ||
        ' ya no opera en BeautyCita. Tu cita del ' ||
        to_char(c.starts_at AT TIME ZONE 'America/Mexico_City',
                'DD "de" TMMonth "a las" HH24:MI') ||
        ' fue cancelada. Para tu servicio, contacta al salón directamente. ' ||
        'IMPORTANTE: ya no aplicamos protección al comprador en disputas relacionadas con este caso.',
      'in_app',
      jsonb_build_object(
        'type',          'salon_tos_suspended',
        'booking_id',    c.id,
        'business_id',   v_business.id,
        'business_name', v_business.name,
        'service_name',  c.service_name,
        'starts_at',     c.starts_at,
        'no_buyer_protection', true
      )
    FROM cancelled c;

    GET DIAGNOSTICS v_appt_count = ROW_COUNT;
  END IF;

  -- Audit: write a synthetic row so the operation appears in the audit log
  -- with the full context (the per-table triggers also fire and write
  -- their own rows, but those don't capture the cross-entity action).
  INSERT INTO public.audit_log (admin_id, action, target_type, target_id, details)
  VALUES (
    v_actor,
    'tos_violation_suspend',
    'profile',
    p_user_id::text,
    jsonb_build_object(
      'reason',                trim(p_reason),
      'business_id',           v_business.id,
      'business_name',         v_business.name,
      'cancelled_appointments', v_appt_count
    )
  );

  RETURN jsonb_build_object(
    'success',                true,
    'business_id',            v_business.id,
    'business_name',          v_business.name,
    'cancelled_appointments', v_appt_count
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_suspend_for_tos_violation(uuid, text) TO authenticated;

COMMENT ON FUNCTION public.admin_set_user_status(uuid, text, text, text) IS
  'Suspend (admin + step-up + reason) or reactivate (ops_admin) a profile. Kind = standard | tos_violation.';
COMMENT ON FUNCTION public.admin_set_salon_active_v2(uuid, boolean, text, text) IS
  'Same as admin_set_salon_active but also captures suspension_kind.';
COMMENT ON FUNCTION public.admin_suspend_for_tos_violation(uuid, text) IS
  'Nukes user + owned salon for ToS violation. Cancels future appointments. Notifies clients that buyer protection no longer applies. Superadmin + step-up + reason >= 10 chars.';
