-- =============================================================================
-- Migration: 20260420000005_stripe_event_dedup.sql
-- Description: Stripe retries webhooks aggressively on 5xx (exponential backoff
-- up to 3 days). The current handler relies on per-row guards (status checks,
-- unique constraints on commission_records) for idempotency, but key paths are
-- unprotected:
--   - calculate_payout_with_debt() MUTATES salon_debts (FIFO deduction). On a
--     retry it deducts the same payment from debt again — debt double-counted
--     against salon, debt remaining understated.
--   - debt_payments INSERTs duplicate rows on retry (no unique constraint).
--   - charge.refunded debt insert has no unique check on (appointment_id,
--     source='chargeback').
--
-- Solution: a global processed-events table. The webhook handler tries to
-- INSERT event_id at the top; on unique conflict (PG 23505), short-circuits
-- with 200 OK so Stripe stops retrying. Single source of truth for "I have
-- already handled this event."
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.stripe_webhook_events (
  event_id    text PRIMARY KEY,
  event_type  text NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS stripe_webhook_events_received_idx
  ON public.stripe_webhook_events (received_at DESC);

ALTER TABLE public.stripe_webhook_events ENABLE ROW LEVEL SECURITY;

-- Service role only — the webhook handler uses the service role key.
DROP POLICY IF EXISTS stripe_webhook_events_service ON public.stripe_webhook_events;
CREATE POLICY stripe_webhook_events_service
  ON public.stripe_webhook_events
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

COMMENT ON TABLE public.stripe_webhook_events IS
  'Stripe webhook event_id deduplication. Webhook handler INSERTs at entry; '
  'duplicate event_id (PG 23505) means Stripe is retrying — short-circuit 200.';
