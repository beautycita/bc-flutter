-- =============================================================================
-- Financial Foundation: missing tables, saldo column, rate config, increment_saldo
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Add saldo column to profiles (referenced by book_with_saldo but never created)
-- ---------------------------------------------------------------------------
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS saldo numeric(10,2) NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.profiles.saldo IS 'User credit balance in MXN. Deducted atomically via RPCs.';

-- ---------------------------------------------------------------------------
-- 2. Commission records ledger (referenced in code, constraint added in
--    20260405000002, but CREATE TABLE was never written)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.commission_records (
  id              uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id     uuid          NOT NULL REFERENCES public.businesses(id),
  appointment_id  uuid          REFERENCES public.appointments(id),
  order_id        uuid          REFERENCES public.orders(id),
  amount          numeric(10,2) NOT NULL,
  rate            numeric(5,4)  NOT NULL,
  source          text          NOT NULL,
  period_month    int           NOT NULL,
  period_year     int           NOT NULL,
  status          text          NOT NULL DEFAULT 'collected',
  created_at      timestamptz   NOT NULL DEFAULT now(),

  CONSTRAINT commission_records_source_check CHECK (
    source IN ('appointment', 'cancellation', 'salon_cancellation', 'product_sale', 'gift_card', 'debt_collection')
  )
);

COMMENT ON TABLE public.commission_records IS 'Immutable ledger of BC platform commissions per transaction.';

ALTER TABLE public.commission_records ENABLE ROW LEVEL SECURITY;

-- Service-role only (financial ledger, no client writes after RPCs are deployed)
CREATE POLICY "commission_records: service_role only"
  ON public.commission_records FOR ALL
  TO service_role
  USING (true) WITH CHECK (true);

-- Re-apply the dedup constraint (idempotent — may already exist from 20260405000002)
DO $$ BEGIN
  ALTER TABLE public.commission_records
    ADD CONSTRAINT commission_records_unique_appt_source
    UNIQUE (appointment_id, source);
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_commission_records_business
  ON public.commission_records(business_id, period_year, period_month);

-- ---------------------------------------------------------------------------
-- 3. Financial rate config in app_config (single source of truth)
-- ---------------------------------------------------------------------------
INSERT INTO public.app_config (key, value, data_type, group_name, description_es)
VALUES
  ('commission_rate_marketplace', '0.03', 'number', 'payments', 'Comision BC para reservas marketplace (3%)'),
  ('commission_rate_salon_direct', '0.00', 'number', 'payments', 'Comision BC para reservas directas del salon (0%)'),
  ('commission_rate_product', '0.10', 'number', 'payments', 'Comision BC para ventas de productos (10%)'),
  ('isr_rate', '0.025', 'number', 'tax', 'Tasa de retencion ISR (2.5% sobre monto bruto)'),
  ('iva_rate', '0.08', 'number', 'tax', 'Tasa de retencion IVA (8% sobre porcion IVA)'),
  ('iva_inclusive_rate', '1.16', 'number', 'tax', 'Factor IVA incluido (1.16 = 16% IVA)')
ON CONFLICT (key) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 4. increment_saldo RPC (called by cancellation refunds but never defined)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.increment_saldo(
  p_user_id uuid,
  p_amount  numeric
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.profiles
  SET saldo = COALESCE(saldo, 0) + p_amount,
      updated_at = now()
  WHERE id = p_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Usuario no encontrado: %', p_user_id;
  END IF;
END;
$$;

COMMENT ON FUNCTION public.increment_saldo IS 'Atomically adjust user saldo. Positive = credit, negative = debit. SECURITY DEFINER bypasses RLS.';

-- ---------------------------------------------------------------------------
-- 5. Helper: read a numeric rate from app_config with fallback
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_config_rate(p_key text, p_default numeric DEFAULT 0)
RETURNS numeric
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT COALESCE(
    (SELECT value::numeric FROM public.app_config WHERE key = p_key LIMIT 1),
    p_default
  );
$$;

-- ---------------------------------------------------------------------------
-- 6. Add payment_method to orders if missing (used by product checkout)
-- ---------------------------------------------------------------------------
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS payment_method text;
