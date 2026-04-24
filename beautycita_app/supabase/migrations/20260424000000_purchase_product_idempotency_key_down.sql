-- Rollback to pre-idempotency-fix state: drop the unique index + column,
-- restore the legacy RPC that matched on (buyer, product, 5 min) only.
DROP INDEX IF EXISTS public.uq_orders_idempotency_key;
ALTER TABLE public.orders DROP COLUMN IF EXISTS idempotency_key;
-- The prior RPC body lived in older migrations — if you truly need to
-- revert, reapply the earlier purchase_product_with_saldo definition.
