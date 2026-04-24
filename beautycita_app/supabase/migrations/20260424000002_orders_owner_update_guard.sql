-- =============================================================================
-- Orders: owner-UPDATE guard
-- =============================================================================
-- Closes a POS money-path hole: the "Orders: business can update own" RLS
-- policy lets an authenticated owner write any column, so a malicious owner
-- could bypass salon-cancel-order entirely by flipping status→refunded (and
-- refunded_at) directly, or by zeroing commission_amount / rewriting
-- total_amount / payment_method before requesting a refund.
--
-- We keep the permissive RLS (required for tracking_number / shipped_at /
-- delivered_at writes) and add a BEFORE UPDATE trigger that runs only when
-- the caller is 'authenticated'. service_role and admin paths bypass by role.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.orders_owner_update_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  caller_role text := auth.role();
BEGIN
  -- service_role and anon paths (registration-style) bypass. The business
  -- owner is 'authenticated'; admin edge functions use service_role.
  IF caller_role IS DISTINCT FROM 'authenticated' THEN
    RETURN NEW;
  END IF;

  -- Immutable once the row exists: identity + money columns.
  IF NEW.buyer_id                 IS DISTINCT FROM OLD.buyer_id                 THEN RAISE EXCEPTION 'orders.buyer_id is immutable';                 END IF;
  IF NEW.business_id              IS DISTINCT FROM OLD.business_id              THEN RAISE EXCEPTION 'orders.business_id is immutable';              END IF;
  IF NEW.product_id               IS DISTINCT FROM OLD.product_id               THEN RAISE EXCEPTION 'orders.product_id is immutable';               END IF;
  IF NEW.product_name             IS DISTINCT FROM OLD.product_name             THEN RAISE EXCEPTION 'orders.product_name is immutable';             END IF;
  IF NEW.quantity                 IS DISTINCT FROM OLD.quantity                 THEN RAISE EXCEPTION 'orders.quantity is immutable';                 END IF;
  IF NEW.total_amount             IS DISTINCT FROM OLD.total_amount             THEN RAISE EXCEPTION 'orders.total_amount is immutable';             END IF;
  IF NEW.commission_amount        IS DISTINCT FROM OLD.commission_amount        THEN RAISE EXCEPTION 'orders.commission_amount is immutable';        END IF;
  IF NEW.stripe_payment_intent_id IS DISTINCT FROM OLD.stripe_payment_intent_id THEN RAISE EXCEPTION 'orders.stripe_payment_intent_id is immutable'; END IF;
  IF NEW.shipping_address         IS DISTINCT FROM OLD.shipping_address         THEN RAISE EXCEPTION 'orders.shipping_address is immutable';         END IF;
  IF NEW.payment_method           IS DISTINCT FROM OLD.payment_method           THEN RAISE EXCEPTION 'orders.payment_method is immutable';           END IF;
  IF NEW.refunded_at              IS DISTINCT FROM OLD.refunded_at              THEN RAISE EXCEPTION 'orders.refunded_at may only be set by the backend refund path'; END IF;
  IF NEW.commission_refund_amount IS DISTINCT FROM OLD.commission_refund_amount THEN RAISE EXCEPTION 'orders.commission_refund_amount is backend-only'; END IF;
  IF NEW.idempotency_key          IS DISTINCT FROM OLD.idempotency_key          THEN RAISE EXCEPTION 'orders.idempotency_key is immutable';          END IF;
  IF NEW.created_at               IS DISTINCT FROM OLD.created_at               THEN RAISE EXCEPTION 'orders.created_at is immutable';               END IF;

  -- Status transitions: only paid→shipped and shipped→delivered. Any move
  -- toward refunded/cancelled must go through the edge function path.
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF NOT (
      (OLD.status = 'paid'    AND NEW.status = 'shipped') OR
      (OLD.status = 'shipped' AND NEW.status = 'delivered')
    ) THEN
      RAISE EXCEPTION 'orders.status transition % -> % is not allowed from an owner session; use the backend cancel/refund path',
        OLD.status, NEW.status;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS orders_owner_update_guard_tg ON public.orders;
CREATE TRIGGER orders_owner_update_guard_tg
  BEFORE UPDATE ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.orders_owner_update_guard();

COMMENT ON FUNCTION public.orders_owner_update_guard() IS
  'Blocks authenticated (owner) callers from mutating money-path columns or jumping status directly to refunded/cancelled. service_role bypasses. Added 2026-04-24 per Tier 1 #4 POS money flow verification.';
