-- POS refund commission policy: keep 3%, return 7% to seller
-- Currently BC keeps 100% of 10% commission on product refund.
-- This migration adds the schema support for partial commission reversal.

-- 1. Unique constraint on (order_id, source) for commission dedup
--    Currently only (appointment_id, source) exists; NULLs bypass it for order-based commissions.
DO $$ BEGIN
  ALTER TABLE public.commission_records
    ADD CONSTRAINT commission_records_unique_order_source
    UNIQUE (order_id, source);
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- 2. Track how much commission was returned on refund
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS commission_refund_amount numeric(10,2) DEFAULT 0;

-- 3. Config key for the commission keep rate on product refunds
INSERT INTO public.app_config (key, value, data_type, group_name, description_es)
VALUES (
  'commission_keep_on_product_refund', '0.03', 'number', 'payments',
  'Comision que BC retiene al reembolsar un producto (3% costo de procesamiento)'
)
ON CONFLICT (key) DO NOTHING;
