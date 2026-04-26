-- =============================================================================
-- Template compliance: inline opt-out keyword in every active template body
-- =============================================================================
-- Compliance test (template_compliance_test.dart) scans body_template for opt-
-- out keywords (BAJA/STOP/unsubscribe/dejar de recibir/etc). The v1 templates
-- + several legacy templates relied on the auto-appended footer for opt-out
-- text, so the static body alone failed the check.
--
-- Fix: append a one-line opt-out hint to any body that doesn't already carry
-- one. The edge-fn footer still appends the fuller LFPDPPP+CAN-SPAM block on
-- top of this; the inline version is defense-in-depth for any code path that
-- bypasses the centralized send pipeline.
-- =============================================================================

UPDATE outreach_templates
SET body_template = body_template || E'\n\n_Responde BAJA para dejar de recibir._'
WHERE channel = 'whatsapp'
  AND is_active = true
  AND body_template !~* '(BAJA|STOP|unsubscribe|cancelar suscripci|dejar de recibir|no recibir|darse de baja|no deseas recibir|responde baja|opt out)';

UPDATE outreach_templates
SET body_template = body_template || E'\n\n---\nPara dejar de recibir estos correos: {unsubscribe_link}'
WHERE channel = 'email'
  AND is_active = true
  AND body_template !~* '(BAJA|STOP|unsubscribe|cancelar suscripci|dejar de recibir|no recibir|darse de baja|no deseas recibir|responde baja|opt out|unsubscribe_link)';
