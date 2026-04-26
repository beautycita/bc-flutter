DROP FUNCTION IF EXISTS public.mark_order_shipped(uuid, text);
-- purchase_product_with_saldo: caller must re-apply 20260426000010 to restore prior body.
SELECT 'noop: re-apply 20260426000010_saldo_writes_must_use_ledger.sql to restore purchase_product_with_saldo'::text;
