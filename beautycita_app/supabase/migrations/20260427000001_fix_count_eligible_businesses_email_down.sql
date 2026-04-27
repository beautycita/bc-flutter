-- Rollback to the previous (broken) businesses branch that joined profiles
-- for email. Keeps the rest of the function identical to the 04-25 version.

CREATE OR REPLACE FUNCTION count_eligible_recipients(
  p_recipient_table text,
  p_recipient_ids uuid[],
  p_channel text,
  p_is_invite boolean
)
RETURNS TABLE (
  eligible integer,
  opted_out integer,
  cooldown integer,
  no_channel integer,
  total integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_eligible   integer := 0;
  v_opted_out  integer := 0;
  v_cooldown   integer := 0;
  v_no_channel integer := 0;
  v_total      integer;
  v_phone      text;
  v_email      text;
  rec          record;
BEGIN
  IF p_recipient_table NOT IN ('discovered_salons','businesses') THEN
    RAISE EXCEPTION 'invalid recipient_table %', p_recipient_table;
  END IF;

  IF p_channel NOT IN ('wa','email') THEN
    RAISE EXCEPTION 'invalid channel %', p_channel;
  END IF;

  v_total := array_length(p_recipient_ids, 1);
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

GRANT EXECUTE ON FUNCTION count_eligible_recipients(text, uuid[], text, boolean)
  TO service_role, authenticated;
