-- ---------------------------------------------------------------------------
-- Add salon offer columns to disputes + update constraints + client UPDATE policy
-- NOTE: Production was recreated from scratch (table was empty) on 2026-02-27.
-- This migration is the additive delta from 20260221000000_disputes_table.sql.
-- ---------------------------------------------------------------------------

-- New columns for salon-first dispute resolution
ALTER TABLE public.disputes
  ADD COLUMN IF NOT EXISTS salon_offer text,
  ADD COLUMN IF NOT EXISTS salon_offer_amount numeric(10,2),
  ADD COLUMN IF NOT EXISTS salon_response text,
  ADD COLUMN IF NOT EXISTS salon_offered_at timestamptz,
  ADD COLUMN IF NOT EXISTS client_accepted boolean,
  ADD COLUMN IF NOT EXISTS client_responded_at timestamptz,
  ADD COLUMN IF NOT EXISTS escalated_at timestamptz;

-- Drop old status check and recreate with new values
ALTER TABLE public.disputes DROP CONSTRAINT IF EXISTS disputes_status_check;
ALTER TABLE public.disputes ADD CONSTRAINT disputes_status_check CHECK (
  status IN ('open', 'salon_responded', 'escalated', 'resolved', 'rejected')
);

-- Salon offer type constraint
ALTER TABLE public.disputes ADD CONSTRAINT disputes_salon_offer_check CHECK (
  salon_offer IS NULL OR salon_offer IN ('full_refund', 'partial_refund', 'denied')
);

-- Clients can update their own disputes (accept/reject salon offer)
CREATE POLICY "Disputes: clients can respond to offers"
  ON public.disputes FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
