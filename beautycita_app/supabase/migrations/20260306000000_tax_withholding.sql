-- =============================================================================
-- Tax Withholding Infrastructure for Mexican ISR/IVA compliance
-- =============================================================================
-- BeautyCita as a digital intermediation platform must withhold ISR and IVA
-- from provider payments per Mexican tax law (LISR Art. 113-A, LIVA Art. 18-J).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Add tax fields to businesses
-- ---------------------------------------------------------------------------
ALTER TABLE public.businesses
  ADD COLUMN IF NOT EXISTS rfc text,
  ADD COLUMN IF NOT EXISTS tax_regime text,
  ADD COLUMN IF NOT EXISTS tax_residency text NOT NULL DEFAULT 'MX';

COMMENT ON COLUMN public.businesses.rfc IS 'RFC (Registro Federal de Contribuyentes) — 12 chars for companies, 13 for individuals';
COMMENT ON COLUMN public.businesses.tax_regime IS 'Tax regime: RIF, general, RESICO, etc.';
COMMENT ON COLUMN public.businesses.tax_residency IS 'Tax residency: MX = Mexican fiscal resident, foreign = non-resident';

-- ---------------------------------------------------------------------------
-- 2. Add withholding fields to appointments
-- ---------------------------------------------------------------------------
ALTER TABLE public.appointments
  ADD COLUMN IF NOT EXISTS isr_withheld numeric(10,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS iva_withheld numeric(10,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS tax_base numeric(10,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS provider_net numeric(10,2) NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.appointments.isr_withheld IS 'ISR (income tax) withheld from this payment in MXN';
COMMENT ON COLUMN public.appointments.iva_withheld IS 'IVA (value-added tax) withheld from this payment in MXN';
COMMENT ON COLUMN public.appointments.tax_base IS 'Pre-IVA base amount (gross / 1.16) in MXN';
COMMENT ON COLUMN public.appointments.provider_net IS 'Net amount provider receives after all deductions in MXN';

-- ---------------------------------------------------------------------------
-- 3. Tax withholdings ledger (immutable audit trail)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.tax_withholdings (
  id                    uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  appointment_id        uuid          REFERENCES public.appointments(id),
  business_id           uuid          NOT NULL REFERENCES public.businesses(id),
  payment_intent_id     text,
  payment_type          text          NOT NULL DEFAULT 'stripe', -- 'stripe', 'btcpay'

  -- Amounts (all in MXN)
  gross_amount          numeric(10,2) NOT NULL,
  tax_base              numeric(10,2) NOT NULL,
  iva_portion           numeric(10,2) NOT NULL,
  platform_fee          numeric(10,2) NOT NULL,

  -- Rates applied (snapshot at transaction time)
  isr_rate              numeric(5,4)  NOT NULL,
  iva_rate              numeric(5,4)  NOT NULL,

  -- Withheld amounts
  isr_withheld          numeric(10,2) NOT NULL,
  iva_withheld          numeric(10,2) NOT NULL,
  provider_net          numeric(10,2) NOT NULL,

  -- Provider tax status snapshot
  provider_rfc          text,
  provider_tax_regime   text,
  provider_tax_residency text         NOT NULL DEFAULT 'MX',

  currency              text          NOT NULL DEFAULT 'MXN',
  period_year           int           NOT NULL,
  period_month          int           NOT NULL,
  created_at            timestamptz   NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.tax_withholdings IS 'Immutable ledger of ISR/IVA withholdings per transaction. Snapshots rates and RFC at time of payment.';

-- Indexes for monthly reporting and lookups
CREATE INDEX IF NOT EXISTS idx_tax_withholdings_period
  ON public.tax_withholdings (period_year, period_month);
CREATE INDEX IF NOT EXISTS idx_tax_withholdings_business
  ON public.tax_withholdings (business_id);
CREATE INDEX IF NOT EXISTS idx_tax_withholdings_appointment
  ON public.tax_withholdings (appointment_id);

-- RLS: service_role only (no client access to tax ledger)
ALTER TABLE public.tax_withholdings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tax_withholdings: service_role only"
  ON public.tax_withholdings
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ---------------------------------------------------------------------------
-- 4. SAT monthly reports
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sat_monthly_reports (
  id                  uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  period_year         int           NOT NULL,
  period_month        int           NOT NULL,
  total_transactions  int           NOT NULL DEFAULT 0,
  total_gross         numeric(12,2) NOT NULL DEFAULT 0,
  total_isr_withheld  numeric(12,2) NOT NULL DEFAULT 0,
  total_iva_withheld  numeric(12,2) NOT NULL DEFAULT 0,
  total_platform_fees numeric(12,2) NOT NULL DEFAULT 0,
  status              text          NOT NULL DEFAULT 'pending',
  report_data         jsonb,
  generated_at        timestamptz,
  submitted_at        timestamptz,
  due_date            date,
  created_at          timestamptz   NOT NULL DEFAULT now(),

  CONSTRAINT sat_monthly_reports_unique_period UNIQUE (period_year, period_month)
);

COMMENT ON TABLE public.sat_monthly_reports IS 'Monthly tax withholding reports for SAT informative returns.';

ALTER TABLE public.sat_monthly_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "sat_monthly_reports: service_role only"
  ON public.sat_monthly_reports
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ---------------------------------------------------------------------------
-- 5. SAT access audit log
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sat_access_log (
  id              uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  endpoint        text          NOT NULL,
  query_params    jsonb,
  response_status int,
  ip_address      inet,
  api_key_hash    text,
  created_at      timestamptz   NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.sat_access_log IS 'Audit log of SAT real-time data access requests. 5-year retention.';

CREATE INDEX IF NOT EXISTS idx_sat_access_log_created
  ON public.sat_access_log (created_at);

ALTER TABLE public.sat_access_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "sat_access_log: service_role only"
  ON public.sat_access_log
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ---------------------------------------------------------------------------
-- 6. Feature flag (OFF by default)
-- ---------------------------------------------------------------------------
INSERT INTO public.app_config (key, value, data_type, group_name, description_es)
VALUES ('tax_withholding_enabled', 'false', 'bool', 'payments', 'Retención ISR/IVA en pagos a proveedores')
ON CONFLICT (key) DO NOTHING;
