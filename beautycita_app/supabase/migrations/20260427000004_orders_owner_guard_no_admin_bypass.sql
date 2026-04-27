-- =============================================================================
-- orders_owner_update_guard: drop the admin bypass
-- =============================================================================
-- Bug found via bughunter salon-cancel-order-full flow: my new trigger version
-- (000001) added `IF v_is_admin THEN RETURN NEW; END IF;` which let admin
-- sessions UPDATE any field, including status='cancelled' via direct UPDATE.
-- The test correctly expected the trigger to BLOCK that path; admin must use
-- the salon-cancel-order edge fn (which runs as service_role).
--
-- Fix: only service_role bypasses. Admins are subject to the same whitelist
-- as owners.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.orders_owner_update_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_owner boolean;
  v_is_service boolean := (auth.role() = 'service_role');
BEGIN
  IF v_is_service THEN
    RETURN NEW;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM businesses
    WHERE id = NEW.business_id AND owner_id = auth.uid()
  ) INTO v_is_owner;

  IF NOT v_is_owner THEN
    RAISE EXCEPTION 'orders_owner_update_guard: not owner of business %', NEW.business_id;
  END IF;

  -- Immutable from owner sessions (admins included).
  IF NEW.payment_method IS DISTINCT FROM OLD.payment_method THEN
    RAISE EXCEPTION 'payment_method is immutable from non-service-role sessions';
  END IF;
  IF NEW.fulfillment_method IS DISTINCT FROM OLD.fulfillment_method THEN
    RAISE EXCEPTION 'fulfillment_method is immutable from non-service-role sessions';
  END IF;
  IF NEW.pickup_qr_token_hash IS DISTINCT FROM OLD.pickup_qr_token_hash
     OR NEW.pickup_qr_expires_at IS DISTINCT FROM OLD.pickup_qr_expires_at
     OR NEW.pickup_qr_issued_at IS DISTINCT FROM OLD.pickup_qr_issued_at
     OR NEW.pickup_qr_revoked_at IS DISTINCT FROM OLD.pickup_qr_revoked_at
     OR NEW.picked_up_at IS DISTINCT FROM OLD.picked_up_at
     OR NEW.picked_up_by_staff_id IS DISTINCT FROM OLD.picked_up_by_staff_id
     OR NEW.claim_window_ends_at IS DISTINCT FROM OLD.claim_window_ends_at
     OR NEW.completed_at IS DISTINCT FROM OLD.completed_at
     OR NEW.refund_reason IS DISTINCT FROM OLD.refund_reason THEN
    RAISE EXCEPTION 'POS-completion fields are service-role only';
  END IF;
  IF NEW.stripe_payment_intent_id IS DISTINCT FROM OLD.stripe_payment_intent_id
     OR NEW.total_amount IS DISTINCT FROM OLD.total_amount
     OR NEW.commission_amount IS DISTINCT FROM OLD.commission_amount
     OR NEW.business_id IS DISTINCT FROM OLD.business_id
     OR NEW.buyer_id IS DISTINCT FROM OLD.buyer_id
     OR NEW.idempotency_key IS DISTINCT FROM OLD.idempotency_key THEN
    RAISE EXCEPTION 'identity / money fields are immutable';
  END IF;

  -- Status transitions: only paid → shipped, shipped → delivered.
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF NOT (
      (OLD.status = 'paid'    AND NEW.status = 'shipped') OR
      (OLD.status = 'shipped' AND NEW.status = 'delivered')
    ) THEN
      RAISE EXCEPTION 'owner cannot transition status % → %', OLD.status, NEW.status;
    END IF;
  END IF;

  -- tracking_number: settable on paid; editable while status='shipped' AND
  -- now() - shipped_at < 24h (typo correction window). Otherwise immutable.
  IF NEW.tracking_number IS DISTINCT FROM OLD.tracking_number THEN
    IF OLD.status = 'paid' THEN
      NULL;
    ELSIF OLD.status = 'shipped'
       AND OLD.shipped_at IS NOT NULL
       AND now() - OLD.shipped_at < interval '24 hours' THEN
      NULL;
    ELSE
      RAISE EXCEPTION 'tracking_number immutable after 24h post-ship';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;
