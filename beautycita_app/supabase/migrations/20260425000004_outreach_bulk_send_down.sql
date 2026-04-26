-- =============================================================================
-- Down: outreach bulk send schema
-- =============================================================================
-- Drops in reverse FK-dependency order.

DROP TRIGGER IF EXISTS trg_update_bulk_job_counts ON bulk_outreach_recipients;
DROP FUNCTION IF EXISTS update_bulk_job_counts() CASCADE;

DROP TRIGGER IF EXISTS trg_sync_marketing_opt_out_denorm ON marketing_opt_outs;
DROP FUNCTION IF EXISTS sync_marketing_opt_out_denorm() CASCADE;

DROP TRIGGER IF EXISTS trg_discovered_salons_contact_status ON discovered_salons;
DROP FUNCTION IF EXISTS compute_discovered_contact_status() CASCADE;

DROP FUNCTION IF EXISTS is_marketing_opted_out(text, text, text);
DROP FUNCTION IF EXISTS is_invite_in_cooldown(uuid, int);
DROP FUNCTION IF EXISTS normalize_phone_last10(text);
DROP FUNCTION IF EXISTS normalize_email(text);

-- Recipients references jobs; drop first
DROP TABLE IF EXISTS bulk_outreach_recipients CASCADE;

-- salon_outreach_log FK to bulk_outreach_jobs
ALTER TABLE salon_outreach_log
  DROP CONSTRAINT IF EXISTS salon_outreach_log_bulk_job_id_fkey;

DROP TABLE IF EXISTS bulk_outreach_jobs CASCADE;

-- Restore narrower channel constraint (matches 20260228 set)
ALTER TABLE salon_outreach_log
  DROP CONSTRAINT IF EXISTS salon_outreach_log_channel_check;
ALTER TABLE salon_outreach_log
  ADD CONSTRAINT salon_outreach_log_channel_check
  CHECK (channel IN ('whatsapp','wa_message','sms','email','phone','wa_call'));

ALTER TABLE salon_outreach_log
  DROP COLUMN IF EXISTS bulk_job_id,
  DROP COLUMN IF EXISTS business_id,
  DROP COLUMN IF EXISTS recipient_email,
  DROP COLUMN IF EXISTS delivered,
  DROP COLUMN IF EXISTS error_text;

-- outreach_templates extras
ALTER TABLE outreach_templates
  DROP CONSTRAINT IF EXISTS outreach_templates_category_check;
ALTER TABLE outreach_templates
  ADD CONSTRAINT outreach_templates_category_check
  CHECK (category IN ('tax','competitive','exclusive','compliance','general'));

ALTER TABLE outreach_templates
  DROP COLUMN IF EXISTS recipient_table,
  DROP COLUMN IF EXISTS is_invite,
  DROP COLUMN IF EXISTS required_variables,
  DROP COLUMN IF EXISTS manual_variables,
  DROP COLUMN IF EXISTS gating_rule,
  DROP COLUMN IF EXISTS html_body;

-- profiles + businesses opt-out hints
ALTER TABLE profiles
  DROP COLUMN IF EXISTS opted_out_marketing,
  DROP COLUMN IF EXISTS opted_out_marketing_at;

ALTER TABLE businesses
  DROP COLUMN IF EXISTS opted_out_marketing,
  DROP COLUMN IF EXISTS opted_out_marketing_at;

-- discovered_salons additions
DROP INDEX IF EXISTS idx_discovered_salons_contact_status;
DROP INDEX IF EXISTS idx_discovered_salons_opted_out;

ALTER TABLE discovered_salons
  DROP COLUMN IF EXISTS contact_status,
  DROP COLUMN IF EXISTS opted_out,
  DROP COLUMN IF EXISTS opted_out_at;

-- canonical opt-out registry last
DROP INDEX IF EXISTS idx_marketing_opt_outs_phone;
DROP INDEX IF EXISTS idx_marketing_opt_outs_email;
DROP TABLE IF EXISTS marketing_opt_outs CASCADE;
