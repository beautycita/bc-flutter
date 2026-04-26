-- Down: strip the appended opt-out hints. Pattern-bounded so it only removes
-- the exact strings this migration added.

UPDATE outreach_templates
SET body_template = regexp_replace(body_template, E'\n\n_Responde BAJA para dejar de recibir\\._\\s*$', '', 'g')
WHERE channel = 'whatsapp';

UPDATE outreach_templates
SET body_template = regexp_replace(body_template, E'\n\n---\nPara dejar de recibir estos correos: \\{unsubscribe_link\\}\\s*$', '', 'g')
WHERE channel = 'email';
