-- =============================================================================
-- Outreach bulk send: opt-out registry, bulk job queue, contact status, logging
-- =============================================================================
-- Ships the schema for admin/superadmin bulk-send to discovered_salons
-- (invite templates, 14d cooldown) and businesses (registered, no cooldown).
--
-- Anti-spam compliance: marketing_opt_outs is the canonical registry. Inbound
-- BAJA via wa-incoming, public unsubscribe page hits, and admin-manual
-- opt-outs all write here. Edge fn checks here before every send.
-- =============================================================================

-- ── 1. marketing_opt_outs: canonical registry ────────────────────────────────
CREATE TABLE IF NOT EXISTS marketing_opt_outs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  -- One of these must be set
  phone text,                    -- normalized last-10 digits
  email text,                    -- lowercased + trimmed
  source text NOT NULL CHECK (source IN ('wa_baja','unsubscribe_link','manual_admin','inbound_email_unsub')),
  channel_blocked text NOT NULL DEFAULT 'all' CHECK (channel_blocked IN ('all','wa','email')),
  unsubscribe_token text,        -- HMAC token if from /baja link
  ip text,
  user_agent text,
  notes text,
  opted_out_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT marketing_opt_outs_contact_required CHECK (phone IS NOT NULL OR email IS NOT NULL)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_marketing_opt_outs_phone
  ON marketing_opt_outs (phone) WHERE phone IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_marketing_opt_outs_email
  ON marketing_opt_outs (email) WHERE email IS NOT NULL;

ALTER TABLE marketing_opt_outs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admin can read opt-outs"
  ON marketing_opt_outs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role IN ('admin','superadmin')
    )
  );

-- service_role bypasses RLS for INSERT/UPDATE.

-- ── 2. discovered_salons: ensure denorm columns + contact_status ────────────
ALTER TABLE discovered_salons
  ADD COLUMN IF NOT EXISTS opted_out boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS opted_out_at timestamptz,
  ADD COLUMN IF NOT EXISTS contact_status text;

-- Trigger function: keep contact_status in sync with channel availability
CREATE OR REPLACE FUNCTION compute_discovered_contact_status()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  has_wa boolean;
  has_email boolean;
  has_phone boolean;
BEGIN
  has_wa := (NEW.whatsapp IS NOT NULL AND NEW.whatsapp <> '' AND COALESCE(NEW.whatsapp_verified, false) = true);
  has_email := (NEW.email IS NOT NULL AND NEW.email <> '' AND NEW.email LIKE '%@%.%');
  has_phone := (NEW.phone IS NOT NULL AND NEW.phone <> '');

  IF has_wa AND has_email THEN
    NEW.contact_status := 'has_both';
  ELSIF has_wa THEN
    NEW.contact_status := 'has_wa';
  ELSIF has_email THEN
    NEW.contact_status := 'has_email';
  ELSIF has_phone THEN
    NEW.contact_status := 'phone_only';
  ELSE
    NEW.contact_status := 'no_contact';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_discovered_salons_contact_status ON discovered_salons;
CREATE TRIGGER trg_discovered_salons_contact_status
  BEFORE INSERT OR UPDATE OF phone, whatsapp, email, whatsapp_verified
  ON discovered_salons
  FOR EACH ROW
  EXECUTE FUNCTION compute_discovered_contact_status();

CREATE INDEX IF NOT EXISTS idx_discovered_salons_contact_status
  ON discovered_salons (contact_status) WHERE NOT COALESCE(opted_out, false);

CREATE INDEX IF NOT EXISTS idx_discovered_salons_opted_out
  ON discovered_salons (opted_out) WHERE opted_out = true;

-- ── 3. profiles + businesses: marketing opt-out hint columns ────────────────
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS opted_out_marketing boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS opted_out_marketing_at timestamptz;

ALTER TABLE businesses
  ADD COLUMN IF NOT EXISTS opted_out_marketing boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS opted_out_marketing_at timestamptz;

-- ── 4. salon_outreach_log: extend for email + bulk + delivery state ─────────
ALTER TABLE salon_outreach_log
  ADD COLUMN IF NOT EXISTS bulk_job_id uuid,
  ADD COLUMN IF NOT EXISTS business_id uuid REFERENCES businesses(id),
  ADD COLUMN IF NOT EXISTS recipient_email text,
  ADD COLUMN IF NOT EXISTS delivered boolean,
  ADD COLUMN IF NOT EXISTS error_text text;

-- Channel constraint: ensure 'email' and 'wa_message' are accepted (older
-- migrations widened this to phone/wa_call/etc; we re-assert the inclusive list)
ALTER TABLE salon_outreach_log
  DROP CONSTRAINT IF EXISTS salon_outreach_log_channel_check;
ALTER TABLE salon_outreach_log
  ADD CONSTRAINT salon_outreach_log_channel_check
  CHECK (channel IN ('whatsapp','wa_message','sms','email','phone','wa_call'));

CREATE INDEX IF NOT EXISTS idx_outreach_log_bulk_job
  ON salon_outreach_log (bulk_job_id) WHERE bulk_job_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_outreach_log_business
  ON salon_outreach_log (business_id, sent_at DESC) WHERE business_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_outreach_log_recipient_email
  ON salon_outreach_log (recipient_email) WHERE recipient_email IS NOT NULL;

-- ── 5. bulk_outreach_jobs: queue header ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS bulk_outreach_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  channel text NOT NULL CHECK (channel IN ('wa','email')),
  template_id uuid NOT NULL REFERENCES outreach_templates(id),
  recipient_table text NOT NULL CHECK (recipient_table IN ('discovered_salons','businesses')),
  manual_vars jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'queued'
    CHECK (status IN ('queued','draining','completed','cancelled','failed')),
  total_count int NOT NULL,
  sent_count int NOT NULL DEFAULT 0,
  skipped_count int NOT NULL DEFAULT 0,
  cooldown_skipped_count int NOT NULL DEFAULT 0,
  optout_skipped_count int NOT NULL DEFAULT 0,
  invalid_skipped_count int NOT NULL DEFAULT 0,
  failed_count int NOT NULL DEFAULT 0,
  preview_first_message text,
  created_at timestamptz NOT NULL DEFAULT now(),
  started_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_bulk_outreach_jobs_status
  ON bulk_outreach_jobs (status, created_at) WHERE status IN ('queued','draining');
CREATE INDEX IF NOT EXISTS idx_bulk_outreach_jobs_admin
  ON bulk_outreach_jobs (admin_user_id, created_at DESC);

ALTER TABLE bulk_outreach_jobs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can read bulk jobs"
  ON bulk_outreach_jobs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role IN ('admin','superadmin')
    )
  );

CREATE POLICY "Admins can create their own bulk jobs"
  ON bulk_outreach_jobs FOR INSERT
  WITH CHECK (
    admin_user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role IN ('admin','superadmin')
    )
  );

CREATE POLICY "Admins can cancel their own bulk jobs"
  ON bulk_outreach_jobs FOR UPDATE
  USING (
    admin_user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role IN ('admin','superadmin')
    )
  )
  WITH CHECK (admin_user_id = auth.uid());

-- Now wire the FK from salon_outreach_log → bulk_outreach_jobs
ALTER TABLE salon_outreach_log
  DROP CONSTRAINT IF EXISTS salon_outreach_log_bulk_job_id_fkey;
ALTER TABLE salon_outreach_log
  ADD CONSTRAINT salon_outreach_log_bulk_job_id_fkey
  FOREIGN KEY (bulk_job_id) REFERENCES bulk_outreach_jobs(id) ON DELETE SET NULL;

-- ── 6. bulk_outreach_recipients: per-recipient queue + outcome ──────────────
CREATE TABLE IF NOT EXISTS bulk_outreach_recipients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id uuid NOT NULL REFERENCES bulk_outreach_jobs(id) ON DELETE CASCADE,
  recipient_table text NOT NULL CHECK (recipient_table IN ('discovered_salons','businesses')),
  recipient_id uuid NOT NULL,
  recipient_phone text,
  recipient_email text,
  status text NOT NULL DEFAULT 'queued'
    CHECK (status IN ('queued','sent','skipped_optout','skipped_cooldown','skipped_no_channel','skipped_cancelled','failed')),
  attempt_count int NOT NULL DEFAULT 0,
  log_id uuid REFERENCES salon_outreach_log(id) ON DELETE SET NULL,
  error_text text,
  queued_at timestamptz NOT NULL DEFAULT now(),
  sent_at timestamptz,
  UNIQUE (job_id, recipient_table, recipient_id)
);

CREATE INDEX IF NOT EXISTS idx_bulk_recipients_drain
  ON bulk_outreach_recipients (job_id, status, queued_at) WHERE status = 'queued';
CREATE INDEX IF NOT EXISTS idx_bulk_recipients_job
  ON bulk_outreach_recipients (job_id);

ALTER TABLE bulk_outreach_recipients ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can read bulk recipients"
  ON bulk_outreach_recipients FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role IN ('admin','superadmin')
    )
  );

-- ── 7. outreach_templates: extend for tab-binding + manual-vars + signature ─
ALTER TABLE outreach_templates
  ADD COLUMN IF NOT EXISTS recipient_table text
    CHECK (recipient_table IS NULL OR recipient_table IN ('discovered_salons','businesses','both')),
  ADD COLUMN IF NOT EXISTS is_invite boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS required_variables text[],
  ADD COLUMN IF NOT EXISTS manual_variables text[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS gating_rule jsonb,
  ADD COLUMN IF NOT EXISTS html_body text;

-- Mark all existing templates as invite (they were all for discovered salons)
UPDATE outreach_templates
   SET is_invite = true,
       recipient_table = 'discovered_salons'
 WHERE is_invite IS NULL OR recipient_table IS NULL;

-- Widen category constraint (existing + new operational categories)
ALTER TABLE outreach_templates
  DROP CONSTRAINT IF EXISTS outreach_templates_category_check;
ALTER TABLE outreach_templates
  ADD CONSTRAINT outreach_templates_category_check
  CHECK (category IN (
    'tax','competitive','exclusive','compliance','general',
    'invite_cold','invite_demand','invite_followup','invite_final',
    'invite_exclusive','invite_tax_help',
    'registered_welcome','registered_inactive','registered_portfolio',
    'registered_rfc','registered_banking','registered_announce',
    'registered_policy','registered_seasonal'
  ));

-- ── 8. Helpers: phone/email normalization for opt-out lookups ───────────────
CREATE OR REPLACE FUNCTION normalize_phone_last10(p text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p IS NULL OR p = '' THEN NULL
    ELSE RIGHT(regexp_replace(p, '[^0-9]', '', 'g'), 10)
  END;
$$;

CREATE OR REPLACE FUNCTION normalize_email(e text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN e IS NULL OR e = '' THEN NULL
    ELSE lower(trim(e))
  END;
$$;

-- Centralised "is this contact opted out?" check, used by edge fn.
CREATE OR REPLACE FUNCTION is_marketing_opted_out(
  p_phone text DEFAULT NULL,
  p_email text DEFAULT NULL,
  p_channel text DEFAULT 'all'
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_phone text := normalize_phone_last10(p_phone);
  v_email text := normalize_email(p_email);
BEGIN
  IF v_phone IS NULL AND v_email IS NULL THEN
    RETURN false;
  END IF;
  -- Match only on non-NULL caller fields. Avoid IS NOT DISTINCT FROM NULL — would
  -- match every phone-only opt-out row when caller has no email, and vice versa.
  RETURN EXISTS (
    SELECT 1 FROM marketing_opt_outs
    WHERE (
        (v_phone IS NOT NULL AND phone = v_phone)
        OR
        (v_email IS NOT NULL AND email = v_email)
      )
      AND (channel_blocked = 'all' OR channel_blocked = p_channel)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION is_marketing_opted_out(text, text, text) TO service_role, authenticated;

-- 14-day invite cooldown check for discovered_salons
CREATE OR REPLACE FUNCTION is_invite_in_cooldown(
  p_discovered_salon_id uuid,
  p_days int DEFAULT 14
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM salon_outreach_log
    WHERE discovered_salon_id = p_discovered_salon_id
      AND sent_at > now() - make_interval(days => p_days)
      AND channel IN ('whatsapp','wa_message','email')
  );
$$;

GRANT EXECUTE ON FUNCTION is_invite_in_cooldown(uuid, int) TO service_role, authenticated;

-- ── 9. Sync trigger: marketing_opt_outs → denorm columns ────────────────────
CREATE OR REPLACE FUNCTION sync_marketing_opt_out_denorm()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.phone IS NOT NULL THEN
    UPDATE discovered_salons
       SET opted_out = true, opted_out_at = COALESCE(opted_out_at, NEW.opted_out_at)
     WHERE normalize_phone_last10(phone) = NEW.phone
        OR normalize_phone_last10(whatsapp) = NEW.phone;

    UPDATE businesses
       SET opted_out_marketing = true, opted_out_marketing_at = COALESCE(opted_out_marketing_at, NEW.opted_out_at)
     WHERE normalize_phone_last10(phone) = NEW.phone
        OR normalize_phone_last10(whatsapp) = NEW.phone;

    UPDATE profiles
       SET opted_out_marketing = true, opted_out_marketing_at = COALESCE(opted_out_marketing_at, NEW.opted_out_at)
     WHERE normalize_phone_last10(phone) = NEW.phone;
  END IF;

  IF NEW.email IS NOT NULL THEN
    UPDATE discovered_salons
       SET opted_out = true, opted_out_at = COALESCE(opted_out_at, NEW.opted_out_at)
     WHERE normalize_email(email) = NEW.email;

    UPDATE profiles
       SET opted_out_marketing = true, opted_out_marketing_at = COALESCE(opted_out_marketing_at, NEW.opted_out_at)
     WHERE normalize_email(email) = NEW.email;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_marketing_opt_out_denorm ON marketing_opt_outs;
CREATE TRIGGER trg_sync_marketing_opt_out_denorm
  AFTER INSERT ON marketing_opt_outs
  FOR EACH ROW
  EXECUTE FUNCTION sync_marketing_opt_out_denorm();

-- ── 10. Counter triggers: keep bulk_outreach_jobs aggregate counts in sync ──
CREATE OR REPLACE FUNCTION update_bulk_job_counts()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    -- Decrement old bucket
    IF OLD.status = 'sent' THEN
      UPDATE bulk_outreach_jobs SET sent_count = GREATEST(sent_count - 1, 0) WHERE id = NEW.job_id;
    ELSIF OLD.status = 'failed' THEN
      UPDATE bulk_outreach_jobs SET failed_count = GREATEST(failed_count - 1, 0) WHERE id = NEW.job_id;
    ELSIF OLD.status = 'skipped_optout' THEN
      UPDATE bulk_outreach_jobs SET optout_skipped_count = GREATEST(optout_skipped_count - 1, 0),
                                    skipped_count = GREATEST(skipped_count - 1, 0) WHERE id = NEW.job_id;
    ELSIF OLD.status = 'skipped_cooldown' THEN
      UPDATE bulk_outreach_jobs SET cooldown_skipped_count = GREATEST(cooldown_skipped_count - 1, 0),
                                    skipped_count = GREATEST(skipped_count - 1, 0) WHERE id = NEW.job_id;
    ELSIF OLD.status IN ('skipped_no_channel','skipped_cancelled') THEN
      UPDATE bulk_outreach_jobs SET invalid_skipped_count = GREATEST(invalid_skipped_count - 1, 0),
                                    skipped_count = GREATEST(skipped_count - 1, 0) WHERE id = NEW.job_id;
    END IF;

    -- Increment new bucket
    IF NEW.status = 'sent' THEN
      UPDATE bulk_outreach_jobs SET sent_count = sent_count + 1 WHERE id = NEW.job_id;
    ELSIF NEW.status = 'failed' THEN
      UPDATE bulk_outreach_jobs SET failed_count = failed_count + 1 WHERE id = NEW.job_id;
    ELSIF NEW.status = 'skipped_optout' THEN
      UPDATE bulk_outreach_jobs SET optout_skipped_count = optout_skipped_count + 1,
                                    skipped_count = skipped_count + 1 WHERE id = NEW.job_id;
    ELSIF NEW.status = 'skipped_cooldown' THEN
      UPDATE bulk_outreach_jobs SET cooldown_skipped_count = cooldown_skipped_count + 1,
                                    skipped_count = skipped_count + 1 WHERE id = NEW.job_id;
    ELSIF NEW.status IN ('skipped_no_channel','skipped_cancelled') THEN
      UPDATE bulk_outreach_jobs SET invalid_skipped_count = invalid_skipped_count + 1,
                                    skipped_count = skipped_count + 1 WHERE id = NEW.job_id;
    END IF;

    -- Auto-complete the job when no more queued recipients remain
    IF NOT EXISTS (
      SELECT 1 FROM bulk_outreach_recipients
      WHERE job_id = NEW.job_id AND status = 'queued'
    ) THEN
      UPDATE bulk_outreach_jobs
         SET status = 'completed', completed_at = COALESCE(completed_at, now())
       WHERE id = NEW.job_id AND status IN ('queued','draining');
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_bulk_job_counts ON bulk_outreach_recipients;
CREATE TRIGGER trg_update_bulk_job_counts
  AFTER UPDATE ON bulk_outreach_recipients
  FOR EACH ROW
  EXECUTE FUNCTION update_bulk_job_counts();

-- ── 11. Backfill: recompute contact_status for all existing rows ────────────
-- Touching `phone` re-fires the BEFORE UPDATE OF trigger. (`SET id = id` would
-- not — it only fires on the columns named in the trigger spec.)
UPDATE discovered_salons SET phone = phone WHERE contact_status IS NULL;

-- ── 12. count_eligible: pre-send sanity counts for bulk sheet UI ────────────
CREATE OR REPLACE FUNCTION count_eligible_recipients(
  p_recipient_table text,
  p_recipient_ids uuid[],
  p_channel text,
  p_is_invite boolean
)
RETURNS TABLE (
  eligible int,
  opted_out int,
  cooldown int,
  no_channel int,
  total int
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total int := array_length(p_recipient_ids, 1);
  v_opted_out int := 0;
  v_cooldown int := 0;
  v_no_channel int := 0;
  v_eligible int := 0;
  rec record;
  v_phone text;
  v_email text;
BEGIN
  IF v_total IS NULL THEN
    RETURN QUERY SELECT 0, 0, 0, 0, 0;
    RETURN;
  END IF;

  IF p_recipient_table = 'discovered_salons' THEN
    FOR rec IN
      SELECT id, phone, whatsapp, email, whatsapp_verified
        FROM discovered_salons
       WHERE id = ANY (p_recipient_ids)
    LOOP
      v_phone := normalize_phone_last10(COALESCE(rec.whatsapp, rec.phone));
      v_email := normalize_email(rec.email);

      IF p_channel = 'wa' AND (v_phone IS NULL OR NOT COALESCE(rec.whatsapp_verified, false)) THEN
        v_no_channel := v_no_channel + 1;
      ELSIF p_channel = 'email' AND v_email IS NULL THEN
        v_no_channel := v_no_channel + 1;
      ELSIF is_marketing_opted_out(v_phone, v_email, p_channel) THEN
        v_opted_out := v_opted_out + 1;
      ELSIF p_is_invite AND is_invite_in_cooldown(rec.id, 14) THEN
        v_cooldown := v_cooldown + 1;
      ELSE
        v_eligible := v_eligible + 1;
      END IF;
    END LOOP;
  ELSIF p_recipient_table = 'businesses' THEN
    FOR rec IN
      SELECT b.id,
             b.phone,
             b.whatsapp,
             p.email
        FROM businesses b
        LEFT JOIN profiles p ON p.id = b.owner_id
       WHERE b.id = ANY (p_recipient_ids)
    LOOP
      v_phone := normalize_phone_last10(COALESCE(rec.whatsapp, rec.phone));
      v_email := normalize_email(rec.email);

      IF p_channel = 'wa' AND v_phone IS NULL THEN
        v_no_channel := v_no_channel + 1;
      ELSIF p_channel = 'email' AND v_email IS NULL THEN
        v_no_channel := v_no_channel + 1;
      ELSIF is_marketing_opted_out(v_phone, v_email, p_channel) THEN
        v_opted_out := v_opted_out + 1;
      ELSE
        v_eligible := v_eligible + 1;
      END IF;
    END LOOP;
  END IF;

  RETURN QUERY SELECT v_eligible, v_opted_out, v_cooldown, v_no_channel, v_total;
END;
$$;

GRANT EXECUTE ON FUNCTION count_eligible_recipients(text, uuid[], text, boolean) TO service_role, authenticated;

-- ── 13. get_business_outreach_vars: computed fields for registered templates ─
CREATE OR REPLACE FUNCTION get_business_outreach_vars(p_business_id uuid)
RETURNS TABLE (
  services_count int,
  portfolio_count int,
  stylist_count int,
  last_booking_days int,
  owner_first_name text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_last_at timestamptz;
BEGIN
  SELECT MAX(starts_at) INTO v_last_at
    FROM appointments
   WHERE business_id = p_business_id
     AND status NOT IN ('cancelled');

  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM services WHERE business_id = p_business_id AND is_active),
    (SELECT COUNT(*)::int FROM portfolio_photos WHERE business_id = p_business_id AND is_visible),
    (SELECT COUNT(*)::int FROM staff WHERE business_id = p_business_id AND is_active),
    CASE
      WHEN v_last_at IS NULL THEN 999
      ELSE GREATEST(0, EXTRACT(DAY FROM (now() - v_last_at))::int)
    END,
    COALESCE(
      (SELECT split_part(COALESCE(p.full_name, p.username), ' ', 1)
         FROM businesses b
         JOIN profiles p ON p.id = b.owner_id
        WHERE b.id = p_business_id),
      'Hola'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION get_business_outreach_vars(uuid) TO service_role, authenticated;

COMMENT ON TABLE marketing_opt_outs IS 'Anti-spam canonical opt-out registry. LFPDPPP / CAN-SPAM compliance. Source = wa_baja, unsubscribe_link, manual_admin, inbound_email_unsub.';
COMMENT ON TABLE bulk_outreach_jobs IS 'Admin/superadmin bulk send job header. Drained by outreach-bulk-send worker.';
COMMENT ON TABLE bulk_outreach_recipients IS 'Per-recipient queue rows; one per addressee in a bulk job.';
