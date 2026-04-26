-- =============================================================================
-- Backfill marketing_opt_outs from existing denorm columns
-- =============================================================================
-- Pre-existing BAJA replies + admin-set opt-outs only flipped the denormalised
-- discovered_salons.opted_out flag. The new is_marketing_opted_out() reads
-- exclusively from marketing_opt_outs, so without this backfill all historical
-- opt-outs leak through the new bulk-send guard. Idempotent — safe to re-run.
-- =============================================================================

-- discovered_salons → marketing_opt_outs (phone variant)
INSERT INTO marketing_opt_outs (phone, source, opted_out_at, notes)
SELECT DISTINCT
  normalize_phone_last10(COALESCE(whatsapp, phone)) AS phone,
  'wa_baja' AS source,
  COALESCE(opted_out_at, now()) AS opted_out_at,
  'backfilled from discovered_salons.opted_out' AS notes
FROM discovered_salons
WHERE opted_out = true
  AND normalize_phone_last10(COALESCE(whatsapp, phone)) IS NOT NULL
ON CONFLICT (phone) WHERE phone IS NOT NULL DO NOTHING;

-- profiles.opted_out_marketing → marketing_opt_outs (phone + email via auth.users)
INSERT INTO marketing_opt_outs (phone, email, source, opted_out_at, notes)
SELECT DISTINCT
  normalize_phone_last10(p.phone) AS phone,
  normalize_email(u.email) AS email,
  'wa_baja' AS source,
  COALESCE(p.opted_out_marketing_at, now()) AS opted_out_at,
  'backfilled from profiles.opted_out_marketing' AS notes
FROM profiles p
LEFT JOIN auth.users u ON u.id = p.id
WHERE p.opted_out_marketing = true
  AND (
    normalize_phone_last10(p.phone) IS NOT NULL
    OR normalize_email(u.email) IS NOT NULL
  )
ON CONFLICT (phone) WHERE phone IS NOT NULL DO NOTHING;

-- Email-keyed half for profiles whose phone already collided
INSERT INTO marketing_opt_outs (email, source, opted_out_at, notes)
SELECT DISTINCT
  normalize_email(u.email) AS email,
  'wa_baja' AS source,
  COALESCE(p.opted_out_marketing_at, now()) AS opted_out_at,
  'backfilled from profiles.opted_out_marketing (email-only)' AS notes
FROM profiles p
JOIN auth.users u ON u.id = p.id
WHERE p.opted_out_marketing = true
  AND normalize_email(u.email) IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM marketing_opt_outs m
    WHERE m.email = normalize_email(u.email)
  )
ON CONFLICT (email) WHERE email IS NOT NULL DO NOTHING;

COMMENT ON TABLE marketing_opt_outs IS
  'Anti-spam canonical opt-out registry (LFPDPPP / CAN-SPAM). Sources: wa_baja, unsubscribe_link, manual_admin, inbound_email_unsub. Backfilled 2026-04-25 from pre-existing denorm columns.';
