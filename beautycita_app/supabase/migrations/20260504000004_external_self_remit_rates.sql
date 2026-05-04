-- =============================================================================
-- 20260504000004 — external_free appointment SAT self-remit rates
-- =============================================================================
-- Free-QR (and manual walk-in) appointments use payment_method='external_free'.
-- BeautyCita does NOT withhold ISR/IVA on these — they're off-platform income
-- collected by the salon directly. The salon's own SAT obligation applies.
--
-- The business panel dashboard surfaces this gap. Two rates are read here so
-- the displayed remittance owed can be tuned per regime / bracket without a
-- redeploy. Defaults are flat and conservative; salons in higher PF brackets
-- should consult their contador.
-- =============================================================================

INSERT INTO public.app_config (key, value)
VALUES
  ('external_self_remit_isr_rate', '0.05'),
  ('external_self_remit_iva_rate', '0.16')
ON CONFLICT (key) DO NOTHING;

COMMENT ON COLUMN public.app_config.value IS
  'String form. external_self_remit_isr_rate / external_self_remit_iva_rate are read by business_provider for the QR free-tier dashboard breakdown — they reflect the salon''s OWN SAT remittance, not a BeautyCita retention.';
