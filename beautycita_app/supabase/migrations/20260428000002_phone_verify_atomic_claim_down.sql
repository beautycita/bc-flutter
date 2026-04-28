DROP FUNCTION IF EXISTS public.phone_verify_claim_slot(uuid, text, text, timestamptz);

-- Leave the expanded channel CHECK in place — narrowing it back to the
-- original ('whatsapp','sms') would fail if any rows now reference the
-- new values. The expanded set is a forward-only improvement.
