-- Atomic OTP-slot claim for phone-verify, plus channel-check expansion.
--
-- Why: phone-verify had a TOCTOU race — three rapid send-code calls all
-- passed the 60s dedup SELECT before any one of them INSERTed the row,
-- so all three enqueued a WhatsApp message and the user received the OTP
-- three times. The new RPC takes a per-(user,phone) advisory lock and
-- does the dedup-check + INSERT in one transaction, so concurrent calls
-- are serialized and only one wins.
--
-- The channel check needed to allow 'infobip-wa' (Infobip whitelist path
-- — gated today but coded for already) and 'pending' (placeholder for
-- the new claim flow; updated to the real channel after WA send returns).

ALTER TABLE public.phone_verification_codes
  DROP CONSTRAINT IF EXISTS phone_verification_codes_channel_check;

ALTER TABLE public.phone_verification_codes
  ADD CONSTRAINT phone_verification_codes_channel_check
  CHECK (channel = ANY (ARRAY['whatsapp'::text, 'sms'::text, 'infobip-wa'::text, 'pending'::text]));

CREATE OR REPLACE FUNCTION public.phone_verify_claim_slot(
  p_user_id uuid,
  p_phone text,
  p_code_hash text,
  p_expires_at timestamptz
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_existing record;
  v_slot_id uuid;
  v_lock_key bigint;
BEGIN
  v_lock_key := hashtextextended(p_user_id::text || '|' || p_phone, 0);
  PERFORM pg_advisory_xact_lock(v_lock_key);

  SELECT id, channel, created_at
    INTO v_existing
    FROM phone_verification_codes
   WHERE user_id = p_user_id
     AND phone = p_phone
     AND verified = false
     AND created_at > now() - interval '60 seconds'
   ORDER BY created_at DESC
   LIMIT 1;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'claimed', false,
      'reason', 'deduplicated',
      'existing_id', v_existing.id,
      'existing_channel', v_existing.channel,
      'created_at', v_existing.created_at
    );
  END IF;

  IF (
    SELECT count(*) FROM phone_verification_codes
     WHERE user_id = p_user_id
       AND phone = p_phone
       AND verified = false
       AND created_at > now() - interval '15 minutes'
  ) >= 3 THEN
    RETURN jsonb_build_object('claimed', false, 'reason', 'rate_limited');
  END IF;

  INSERT INTO phone_verification_codes
    (user_id, phone, code, channel, expires_at, attempts)
  VALUES
    (p_user_id, p_phone, p_code_hash, 'pending', p_expires_at, 0)
  RETURNING id INTO v_slot_id;

  RETURN jsonb_build_object('claimed', true, 'id', v_slot_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.phone_verify_claim_slot(uuid, text, text, timestamptz)
  TO service_role;
