-- =============================================================================
-- Drop legacy purchase_product_with_saldo overload (8-arg)
-- =============================================================================
-- Migration 20260427000002 added the 9-arg version with p_fulfillment_method
-- but didn't drop the prior 8-arg version. PostgreSQL couldn't resolve
-- callers that omit the 9th arg ("function not unique") — caught by BC
-- Monitor's product_purchase tests post-rollout.
-- =============================================================================

DROP FUNCTION IF EXISTS public.purchase_product_with_saldo(
  uuid, uuid, uuid, text, integer, numeric, jsonb, text
);
