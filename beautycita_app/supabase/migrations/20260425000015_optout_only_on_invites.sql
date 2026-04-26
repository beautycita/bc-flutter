-- =============================================================================
-- Opt-out text: only on INVITE/cold-outreach templates, not on registered ops
-- =============================================================================
-- LFPDPPP & CAN-SPAM require opt-out language only on unsolicited commercial
-- messages to non-consenting recipients. Registered salones consented at
-- onboarding (ToS) to receive operational platform messages — adding opt-out
-- to those is incorrect and confuses the recipient ("am I being marketed to?
-- I thought this was my account?").
--
-- Strip the inline opt-out hint added by 20260425000013 from any template that
-- is NOT an invite/cold-outreach. Specifically: any template where is_invite
-- = false OR recipient_table = 'businesses'.
-- =============================================================================

-- Strip WhatsApp opt-out line from registered/operational templates
UPDATE outreach_templates
SET body_template = regexp_replace(
  body_template,
  E'\\n\\n_Responde BAJA para dejar de recibir\\._\\s*$',
  '',
  'g'
)
WHERE channel = 'whatsapp'
  AND (is_invite = false OR recipient_table = 'businesses');

-- Strip email opt-out tail from registered/operational templates
UPDATE outreach_templates
SET body_template = regexp_replace(
  body_template,
  E'\\n\\n---\\nPara dejar de recibir estos correos: \\{unsubscribe_link\\}\\s*$',
  '',
  'g'
)
WHERE channel = 'email'
  AND (is_invite = false OR recipient_table = 'businesses');

-- Verify: invites should still have keyword; registered should NOT
COMMENT ON TABLE outreach_templates IS
  'Outreach + operational templates. is_invite=true → unsolicited cold outreach (LFPDPPP/CAN-SPAM opt-out required, edge fn appends full footer). is_invite=false → operational messages to consented account holders (no opt-out language, lighter identity-only footer).';
