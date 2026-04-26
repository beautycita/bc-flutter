-- Down: outreach templates v1 seed
-- Removes the v1 templates and reactivates the prior seed

DELETE FROM outreach_templates
 WHERE name IN (
   'invite_cold_wa','invite_cold_email','invite_demand_wa','invite_reputation_email',
   'invite_tax_email','invite_followup_wa','invite_final_wa','invite_final_email',
   'reg_welcome_wa','reg_welcome_email','reg_inactive_wa','reg_portfolio_email',
   'reg_rfc_email','reg_clabe_wa','reg_feature_announce_wa','reg_feature_announce_email',
   'reg_policy_update_email','reg_seasonal_wa'
 );

UPDATE outreach_templates
   SET is_active = true
 WHERE name IN (
   'BeautyCita te hace tus impuestos',
   'Sello de Empresa Socialmente Responsable',
   'Lo que la competencia no te dice',
   'El SAT viene por ti',
   'Invitacion exclusiva',
   'Mensaje WA inicial',
   'Seguimiento WA'
 );
