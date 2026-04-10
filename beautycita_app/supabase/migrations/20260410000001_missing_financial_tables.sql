-- Phase 1: Missing SQL Tables & RPCs (5 critical findings)
-- salon_debts, debt_payments, cfdi_records, platform_sat_declarations,
-- fix sat_monthly_reports, calculate_payout_with_debt RPC, missing indexes

-- 1.1 salon_debts
CREATE TABLE IF NOT EXISTS salon_debts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES businesses(id),
  amount numeric(10,2) NOT NULL CHECK (amount > 0),
  reason text NOT NULL,
  source text NOT NULL, -- 'cancellation_commission', 'chargeback', 'manual'
  appointment_id uuid REFERENCES appointments(id),
  remaining numeric(10,2) NOT NULL CHECK (remaining >= 0),
  created_at timestamptz DEFAULT now(),
  resolved_at timestamptz
);
CREATE INDEX IF NOT EXISTS idx_salon_debts_biz ON salon_debts(business_id) WHERE remaining > 0;
ALTER TABLE salon_debts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "service_role_only" ON salon_debts FOR ALL USING (auth.role() = 'service_role');

-- 1.2 debt_payments
CREATE TABLE IF NOT EXISTS debt_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  debt_id uuid NOT NULL REFERENCES salon_debts(id),
  amount numeric(10,2) NOT NULL CHECK (amount > 0),
  source text NOT NULL, -- 'payout_deduction', 'manual_payment'
  payout_reference text,
  created_at timestamptz DEFAULT now()
);
ALTER TABLE debt_payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "service_role_only" ON debt_payments FOR ALL USING (auth.role() = 'service_role');

-- 1.3 cfdi_records
CREATE TABLE IF NOT EXISTS cfdi_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  appointment_id uuid REFERENCES appointments(id),
  business_id uuid NOT NULL REFERENCES businesses(id),
  cfdi_uuid text, -- SAT UUID after stamping
  xml text,
  type text NOT NULL DEFAULT 'retencion', -- 'retencion', 'ingreso', 'pago'
  status text NOT NULL DEFAULT 'pending', -- 'pending', 'stamped', 'cancelled', 'error'
  gross_amount numeric(10,2),
  isr_withheld numeric(10,2),
  iva_withheld numeric(10,2),
  provider_net numeric(10,2),
  error_message text,
  created_at timestamptz DEFAULT now(),
  stamped_at timestamptz
);
CREATE INDEX IF NOT EXISTS idx_cfdi_biz_period ON cfdi_records(business_id, created_at);
ALTER TABLE cfdi_records ENABLE ROW LEVEL SECURITY;
CREATE POLICY "service_role_only" ON cfdi_records FOR ALL USING (auth.role() = 'service_role');

-- 1.4 platform_sat_declarations
CREATE TABLE IF NOT EXISTS platform_sat_declarations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_year int NOT NULL,
  period_month int NOT NULL,
  total_businesses int DEFAULT 0,
  total_transactions int DEFAULT 0,
  total_revenue numeric(12,2) DEFAULT 0,
  total_iva_collected numeric(12,2) DEFAULT 0,
  total_isr_collected numeric(12,2) DEFAULT 0,
  total_commissions numeric(12,2) DEFAULT 0,
  status text DEFAULT 'generated',
  generated_at timestamptz DEFAULT now(),
  UNIQUE (period_year, period_month)
);
ALTER TABLE platform_sat_declarations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "service_role_only" ON platform_sat_declarations FOR ALL USING (auth.role() = 'service_role');

-- 1.5 Fix sat_monthly_reports — add business_id to unique constraint
ALTER TABLE sat_monthly_reports ADD COLUMN IF NOT EXISTS business_id uuid REFERENCES businesses(id);
ALTER TABLE sat_monthly_reports DROP CONSTRAINT IF EXISTS sat_monthly_reports_period_year_period_month_key;
ALTER TABLE sat_monthly_reports ADD CONSTRAINT sat_monthly_reports_biz_period_key UNIQUE (business_id, period_year, period_month);

-- 1.6 calculate_payout_with_debt RPC
CREATE OR REPLACE FUNCTION calculate_payout_with_debt(
  p_business_id uuid,
  p_gross_payout numeric
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_debt RECORD;
  v_deducted numeric := 0;
  v_net numeric := p_gross_payout;
BEGIN
  FOR v_debt IN
    SELECT id, remaining FROM salon_debts
    WHERE business_id = p_business_id AND remaining > 0
    ORDER BY created_at ASC -- FIFO
    FOR UPDATE
  LOOP
    IF v_net <= 0 THEN EXIT; END IF;
    DECLARE v_pay numeric := LEAST(v_net, v_debt.remaining);
    BEGIN
      UPDATE salon_debts SET remaining = remaining - v_pay,
        resolved_at = CASE WHEN remaining - v_pay = 0 THEN now() ELSE NULL END
        WHERE id = v_debt.id;
      INSERT INTO debt_payments (debt_id, amount, source)
        VALUES (v_debt.id, v_pay, 'payout_deduction');
      v_deducted := v_deducted + v_pay;
      v_net := v_net - v_pay;
    END;
  END LOOP;
  RETURN jsonb_build_object(
    'gross', p_gross_payout,
    'debt_deducted', v_deducted,
    'net_payout', v_net
  );
END;
$$;

-- 1.7 Missing indexes
CREATE INDEX IF NOT EXISTS idx_appointments_payment_status ON appointments(payment_status);
CREATE INDEX IF NOT EXISTS idx_profiles_stripe_customer_id ON profiles(stripe_customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_stripe_pi ON orders(stripe_payment_intent_id);
