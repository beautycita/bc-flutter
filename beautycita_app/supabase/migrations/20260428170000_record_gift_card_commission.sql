-- beautycita_app/supabase/migrations/20260428170000_record_gift_card_commission.sql
-- Wraps gift_cards INSERT + commission_records INSERT in a single transaction.
-- Replaces the non-atomic client-side two-write pattern in
-- business_gift_cards_screen.dart. No tax_withholdings row — gift-card
-- commission is platform revenue (BC's own corporate income), not a LISR
-- Art. 113-A withholding event since there is no platform→provider
-- disbursement in this flow.

CREATE OR REPLACE FUNCTION record_gift_card_commission(
  p_business_id uuid,
  p_code        text,
  p_amount      numeric,
  p_buyer_name  text,
  p_recipient_name text,
  p_message     text,
  p_expires_at  timestamptz
)
RETURNS TABLE (
  out_gift_card_id  uuid,
  out_commission_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_gift_card_id  uuid;
  v_commission_id uuid;
  v_commission_amount numeric := round(p_amount * 0.03, 2);
BEGIN
  -- Authz: caller must own this business
  IF NOT EXISTS (
    SELECT 1 FROM businesses
    WHERE id = p_business_id AND owner_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'forbidden: caller does not own business %', p_business_id;
  END IF;

  -- 1. Insert gift card
  INSERT INTO gift_cards (
    business_id, code, amount, remaining_amount,
    buyer_name, recipient_name, message,
    expires_at, is_active
  ) VALUES (
    p_business_id, p_code, p_amount, p_amount,
    p_buyer_name, p_recipient_name, p_message,
    p_expires_at, true
  )
  RETURNING id INTO v_gift_card_id;

  -- 2. Insert commission record (BC platform revenue — not a withholding)
  INSERT INTO commission_records (
    business_id, amount, rate, source,
    period_month, period_year, status
  ) VALUES (
    p_business_id, v_commission_amount, 0.03, 'gift_card',
    EXTRACT(MONTH FROM now())::int,
    EXTRACT(YEAR FROM now())::int,
    'collected'
  )
  RETURNING id INTO v_commission_id;

  RETURN QUERY SELECT v_gift_card_id, v_commission_id;
END;
$$;

GRANT EXECUTE ON FUNCTION record_gift_card_commission(uuid, text, numeric, text, text, text, timestamptz) TO authenticated;
