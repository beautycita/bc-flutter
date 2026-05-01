-- Phase 0: extend audit_log with column-delta columns + add trigger
-- infrastructure for automatic row-level mutation audit on 9 tables.
--
-- Existing audit_log keeps its admin-action shape (admin_id, action,
-- target_type, target_id, details). New columns let triggers record
-- before/after column deltas without disturbing the existing surface.
-- Auditoría tab unifies both: "human action" rows (details populated)
-- and "row mutation" rows (before/after_data populated).

ALTER TABLE public.audit_log
  ADD COLUMN IF NOT EXISTS actor_role text,
  ADD COLUMN IF NOT EXISTS before_data jsonb,
  ADD COLUMN IF NOT EXISTS after_data jsonb,
  ADD COLUMN IF NOT EXISTS regulatory_hold boolean NOT NULL DEFAULT true;

COMMENT ON COLUMN public.audit_log.regulatory_hold IS
  'True = retain 5y per CFF Art. 30 baseline. Default true for all rows (BC decision 2026-05-01).';

-- audit_log_failures: when a trigger insertion errors out, the failed
-- payload + error text land here instead of breaking the business mutation.
CREATE TABLE IF NOT EXISTS public.audit_log_failures (
  id bigserial PRIMARY KEY,
  attempted_payload jsonb NOT NULL,
  error_text text NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_log_failures_occurred
  ON public.audit_log_failures(occurred_at DESC);

ALTER TABLE public.audit_log_failures ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "audit_log_failures_admin_read" ON public.audit_log_failures;
CREATE POLICY "audit_log_failures_admin_read" ON public.audit_log_failures
  FOR SELECT USING (public.is_ops_admin());

-- audit_column_allowlist: per-table, which columns the trigger should
-- include in the before/after snapshot. Anything not listed is redacted
-- (PII protection: don't dump full_name / phone / address into audit rows).
CREATE TABLE IF NOT EXISTS public.audit_column_allowlist (
  table_name text NOT NULL,
  column_name text NOT NULL,
  PRIMARY KEY (table_name, column_name)
);

INSERT INTO public.audit_column_allowlist (table_name, column_name) VALUES
  -- profiles: only audit role/status/phone_verified/saldo (not full_name/phone/address/birthday)
  ('profiles', 'role'),
  ('profiles', 'status'),
  ('profiles', 'phone_verified'),
  ('profiles', 'saldo'),

  -- businesses: structural + verification state
  ('businesses', 'tier'),
  ('businesses', 'is_active'),
  ('businesses', 'is_verified'),
  ('businesses', 'onboarding_complete'),
  ('businesses', 'onboarding_step'),
  ('businesses', 'stripe_charges_enabled'),
  ('businesses', 'stripe_payouts_enabled'),
  ('businesses', 'rfc'),

  -- disputes: state machine
  ('disputes', 'status'),
  ('disputes', 'resolution'),
  ('disputes', 'resolution_amount'),

  -- appointments: status + payment
  ('appointments', 'status'),
  ('appointments', 'payment_status'),
  ('appointments', 'price'),

  -- discovered_salons: tier mgmt + RP assignment
  ('discovered_salons', 'tier_id'),
  ('discovered_salons', 'tier_locked'),
  ('discovered_salons', 'status'),
  ('discovered_salons', 'assigned_rp_id'),

  -- app_config: toggle flips
  ('app_config', 'value'),

  -- notification_templates: localized template content
  ('notification_templates', 'template_es'),
  ('notification_templates', 'template_en'),

  -- service_profiles: weight + radius tunables
  ('service_profiles', 'weight_proximity'),
  ('service_profiles', 'weight_availability'),
  ('service_profiles', 'weight_rating'),
  ('service_profiles', 'weight_price'),
  ('service_profiles', 'weight_portfolio'),
  ('service_profiles', 'search_radius_km'),

  -- engine_settings: any tuning
  ('engine_settings', 'value')
ON CONFLICT DO NOTHING;

-- redact_audit_payload: keep only allowlisted columns from a row JSON.
CREATE OR REPLACE FUNCTION public.redact_audit_payload(p_table text, p_payload jsonb)
  RETURNS jsonb
  LANGUAGE sql STABLE
  SET search_path TO 'public'
AS $$
  SELECT jsonb_object_agg(key, value)
  FROM jsonb_each(p_payload)
  WHERE key IN (
    SELECT column_name FROM public.audit_column_allowlist WHERE table_name = p_table
  );
$$;

-- audit_table_changes: generic AFTER-row trigger for INSERT/UPDATE/DELETE.
-- Writes a redacted column delta to audit_log; failures land in audit_log_failures
-- so a broken audit never blocks a business mutation.
--
-- For UPDATE we compute the before/after only over columns that actually
-- changed (LIMIT in the WHEN clause is on individual triggers; this is the
-- final filter for safety).
CREATE OR REPLACE FUNCTION public.audit_table_changes()
  RETURNS trigger
  LANGUAGE plpgsql SECURITY DEFINER
  SET search_path TO 'public'
AS $$
DECLARE
  v_actor uuid;
  v_role  text;
  v_before jsonb;
  v_after  jsonb;
  v_target_id text;
BEGIN
  v_actor := auth.uid();
  BEGIN
    v_role := current_setting('request.jwt.claims', true)::jsonb->>'role';
  EXCEPTION WHEN OTHERS THEN
    v_role := NULL;
  END;

  v_target_id := COALESCE(NEW.id::text, OLD.id::text);

  BEGIN
    IF TG_OP = 'INSERT' THEN
      v_after := public.redact_audit_payload(TG_TABLE_NAME, to_jsonb(NEW));
      v_before := NULL;
    ELSIF TG_OP = 'DELETE' THEN
      v_before := public.redact_audit_payload(TG_TABLE_NAME, to_jsonb(OLD));
      v_after := NULL;
    ELSE
      -- UPDATE: snapshot only columns that actually changed
      SELECT jsonb_object_agg(o.key, o.value), jsonb_object_agg(n.key, n.value)
        INTO v_before, v_after
      FROM jsonb_each(public.redact_audit_payload(TG_TABLE_NAME, to_jsonb(OLD))) o
      JOIN jsonb_each(public.redact_audit_payload(TG_TABLE_NAME, to_jsonb(NEW))) n
        ON o.key = n.key
      WHERE o.value IS DISTINCT FROM n.value;
    END IF;

    -- Skip writing if there's nothing to record (e.g. UPDATE that touched
    -- only non-allowlisted columns).
    IF (v_before IS NULL OR v_before = '{}'::jsonb)
       AND (v_after IS NULL OR v_after = '{}'::jsonb) THEN
      RETURN COALESCE(NEW, OLD);
    END IF;

    -- admin_id is NOT NULL in audit_log; for system mutations (no auth.uid)
    -- we coalesce to a sentinel UUID so the row still lands. The sentinel
    -- must exist as a profile row — created by the migration below.
    INSERT INTO public.audit_log
      (admin_id, action, target_type, target_id, details, actor_role, before_data, after_data, regulatory_hold)
    VALUES
      (COALESCE(v_actor, '00000000-0000-0000-0000-000000000001'::uuid),
       TG_OP,
       TG_TABLE_NAME,
       v_target_id,
       '{}'::jsonb,
       v_role,
       v_before,
       v_after,
       true);

  EXCEPTION WHEN OTHERS THEN
    INSERT INTO public.audit_log_failures (attempted_payload, error_text)
    VALUES (
      jsonb_build_object(
        'table', TG_TABLE_NAME,
        'op', TG_OP,
        'target_id', v_target_id,
        'actor', v_actor
      ),
      SQLERRM
    );
  END;

  RETURN COALESCE(NEW, OLD);
END;
$$;

-- System actor sentinel — used when triggers fire from a non-authenticated
-- context (cron jobs, service-role scripts, migrations). Created as a
-- profile row so the FK on audit_log.admin_id holds.
-- Extend profiles role CHECK to admit 'ops_admin' (Phase 0 tier) + 'system'
-- (sentinel actor used by trigger when auth.uid is null). Done in this
-- migration because both are needed for the trigger infrastructure to work.
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check
  CHECK (role = ANY (ARRAY['customer','stylist','rp','ops_admin','admin','superadmin','system']));

-- Sentinel actor for system-driven mutations (cron, service-role scripts)
-- so the FK on audit_log.admin_id holds. profiles.id → auth.users(id) FK
-- requires the auth.users row first.
INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
VALUES (
  '00000000-0000-0000-0000-000000000001'::uuid,
  '00000000-0000-0000-0000-000000000000'::uuid,
  'authenticated',
  'authenticated',
  'platform-actor@beautycita.local',
  now(),
  now()
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, username, role, full_name, status, created_at, updated_at)
VALUES ('00000000-0000-0000-0000-000000000001'::uuid, 'platformActor', 'system', 'Platform Actor', 'active', now(), now())
ON CONFLICT (id) DO NOTHING;

-- ─── Attach triggers (with explicit WHEN clauses so no-op updates skip) ──

-- profiles
DROP TRIGGER IF EXISTS trg_audit_profiles ON public.profiles;
CREATE TRIGGER trg_audit_profiles
  AFTER INSERT OR DELETE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.audit_table_changes();

DROP TRIGGER IF EXISTS trg_audit_profiles_upd ON public.profiles;
CREATE TRIGGER trg_audit_profiles_upd
  AFTER UPDATE ON public.profiles
  FOR EACH ROW
  WHEN (
    OLD.role IS DISTINCT FROM NEW.role
    OR OLD.status IS DISTINCT FROM NEW.status
    OR OLD.phone_verified IS DISTINCT FROM NEW.phone_verified
    OR OLD.saldo IS DISTINCT FROM NEW.saldo
  )
  EXECUTE FUNCTION public.audit_table_changes();

-- businesses
DROP TRIGGER IF EXISTS trg_audit_businesses ON public.businesses;
CREATE TRIGGER trg_audit_businesses
  AFTER INSERT OR DELETE ON public.businesses
  FOR EACH ROW EXECUTE FUNCTION public.audit_table_changes();

DROP TRIGGER IF EXISTS trg_audit_businesses_upd ON public.businesses;
CREATE TRIGGER trg_audit_businesses_upd
  AFTER UPDATE ON public.businesses
  FOR EACH ROW
  WHEN (
    OLD.tier IS DISTINCT FROM NEW.tier
    OR OLD.is_active IS DISTINCT FROM NEW.is_active
    OR OLD.is_verified IS DISTINCT FROM NEW.is_verified
    OR OLD.onboarding_complete IS DISTINCT FROM NEW.onboarding_complete
    OR OLD.onboarding_step IS DISTINCT FROM NEW.onboarding_step
    OR OLD.stripe_charges_enabled IS DISTINCT FROM NEW.stripe_charges_enabled
    OR OLD.stripe_payouts_enabled IS DISTINCT FROM NEW.stripe_payouts_enabled
    OR OLD.rfc IS DISTINCT FROM NEW.rfc
  )
  EXECUTE FUNCTION public.audit_table_changes();

-- disputes
DROP TRIGGER IF EXISTS trg_audit_disputes ON public.disputes;
CREATE TRIGGER trg_audit_disputes
  AFTER INSERT OR DELETE ON public.disputes
  FOR EACH ROW EXECUTE FUNCTION public.audit_table_changes();

DROP TRIGGER IF EXISTS trg_audit_disputes_upd ON public.disputes;
CREATE TRIGGER trg_audit_disputes_upd
  AFTER UPDATE ON public.disputes
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status OR OLD.resolution IS DISTINCT FROM NEW.resolution)
  EXECUTE FUNCTION public.audit_table_changes();

-- appointments — tracking status/payment changes only (high churn table; trigger
-- guarded tightly to avoid audit explosion)
DROP TRIGGER IF EXISTS trg_audit_appointments ON public.appointments;
CREATE TRIGGER trg_audit_appointments
  AFTER UPDATE ON public.appointments
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status OR OLD.payment_status IS DISTINCT FROM NEW.payment_status)
  EXECUTE FUNCTION public.audit_table_changes();

-- discovered_salons
DROP TRIGGER IF EXISTS trg_audit_discovered_salons ON public.discovered_salons;
CREATE TRIGGER trg_audit_discovered_salons
  AFTER UPDATE ON public.discovered_salons
  FOR EACH ROW
  WHEN (
    OLD.tier_id IS DISTINCT FROM NEW.tier_id
    OR OLD.tier_locked IS DISTINCT FROM NEW.tier_locked
    OR OLD.status IS DISTINCT FROM NEW.status
    OR OLD.assigned_rp_id IS DISTINCT FROM NEW.assigned_rp_id
  )
  EXECUTE FUNCTION public.audit_table_changes();

-- app_config (toggle flips)
DROP TRIGGER IF EXISTS trg_audit_app_config ON public.app_config;
CREATE TRIGGER trg_audit_app_config
  AFTER UPDATE ON public.app_config
  FOR EACH ROW WHEN (OLD.value IS DISTINCT FROM NEW.value)
  EXECUTE FUNCTION public.audit_table_changes();

-- notification_templates
DROP TRIGGER IF EXISTS trg_audit_notification_templates ON public.notification_templates;
CREATE TRIGGER trg_audit_notification_templates
  AFTER UPDATE ON public.notification_templates
  FOR EACH ROW
  WHEN (OLD.template_es IS DISTINCT FROM NEW.template_es OR OLD.template_en IS DISTINCT FROM NEW.template_en)
  EXECUTE FUNCTION public.audit_table_changes();

-- service_profiles
DROP TRIGGER IF EXISTS trg_audit_service_profiles ON public.service_profiles;
CREATE TRIGGER trg_audit_service_profiles
  AFTER UPDATE ON public.service_profiles
  FOR EACH ROW EXECUTE FUNCTION public.audit_table_changes();

-- engine_settings
DROP TRIGGER IF EXISTS trg_audit_engine_settings ON public.engine_settings;
CREATE TRIGGER trg_audit_engine_settings
  AFTER UPDATE ON public.engine_settings
  FOR EACH ROW WHEN (OLD.value IS DISTINCT FROM NEW.value)
  EXECUTE FUNCTION public.audit_table_changes();

GRANT EXECUTE ON FUNCTION public.audit_table_changes() TO postgres, service_role;
GRANT EXECUTE ON FUNCTION public.redact_audit_payload(text, jsonb) TO postgres, service_role, authenticated;

COMMENT ON FUNCTION public.audit_table_changes() IS
  'Generic audit trigger. PII-redacted (per audit_column_allowlist), failure-isolated (audit_log_failures).';
