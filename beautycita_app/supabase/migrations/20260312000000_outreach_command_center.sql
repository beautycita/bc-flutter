-- Outreach Command Center: templates, recording, booking detection
-- 2026-03-12

-- ── Outreach templates table ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS outreach_templates (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    channel text NOT NULL CHECK (channel IN ('email', 'whatsapp', 'sms')),
    subject text,
    body_template text NOT NULL,
    category text CHECK (category IN ('tax', 'competitive', 'exclusive', 'compliance', 'general')),
    sort_order int DEFAULT 0,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- ── Extend salon_outreach_log ────────────────────────────────────────────────
ALTER TABLE salon_outreach_log
    ADD COLUMN IF NOT EXISTS recording_url text,
    ADD COLUMN IF NOT EXISTS transcript text,
    ADD COLUMN IF NOT EXISTS template_id uuid REFERENCES outreach_templates(id),
    ADD COLUMN IF NOT EXISTS rp_user_id uuid REFERENCES auth.users(id),
    ADD COLUMN IF NOT EXISTS call_duration_seconds int,
    ADD COLUMN IF NOT EXISTS subject text;

-- ── Extend discovered_salons ─────────────────────────────────────────────────
ALTER TABLE discovered_salons
    ADD COLUMN IF NOT EXISTS booking_system text,
    ADD COLUMN IF NOT EXISTS booking_url text,
    ADD COLUMN IF NOT EXISTS calendar_url text,
    ADD COLUMN IF NOT EXISTS booking_enriched_at timestamptz,
    ADD COLUMN IF NOT EXISTS email text;

-- ── Indexes ──────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_discovered_salons_booking_system
    ON discovered_salons (booking_system) WHERE booking_system IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_discovered_salons_booking_enrichment
    ON discovered_salons (booking_enriched_at) WHERE website IS NOT NULL AND booking_enriched_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_outreach_log_salon
    ON salon_outreach_log (discovered_salon_id, sent_at DESC);

-- ── RLS for outreach_templates ───────────────────────────────────────────────
ALTER TABLE outreach_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read active templates"
    ON outreach_templates FOR SELECT
    USING (is_active = true);

CREATE POLICY "Superadmin can manage templates"
    ON outreach_templates FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role = 'superadmin'
        )
    );

-- ── Seed email templates ─────────────────────────────────────────────────────
INSERT INTO outreach_templates (name, channel, subject, body_template, category, sort_order) VALUES
(
    'BeautyCita te hace tus impuestos',
    'email',
    'Tu salon ya cumple con el SAT? BeautyCita lo hace por ti',
    E'Hola {salon_name},\n\nA partir de 2026, el gobierno federal exige que todas las plataformas digitales retengan impuestos automaticamente:\n\n- 8% IVA sobre cada transaccion\n- 2.5% ISR sobre cada transaccion\n\nEsto aplica a TODOS los salones que reciban pagos a traves de plataformas digitales, incluyendo Stripe, MercadoPago, y cualquier sistema de pago electronico.\n\nLa buena noticia: BeautyCita maneja todo esto automaticamente.\n\n- Generamos tus CFDIs cada mes\n- Reportamos al SAT por ti\n- Tu contador recibe todo organizado\n- Zero trabajo adicional de tu parte\n\nTus competidores que ignoren esto enfrentan multas del SAT. No esperes a que te llegue la notificacion.\n\nRegistrate en 60 segundos: beautycita.com\n\nSaludos,\n{rp_name}\nBeautyCita - Relaciones Publicas\n{rp_phone}',
    'tax',
    1
),
(
    'Sello de Empresa Socialmente Responsable',
    'email',
    'Destaca tu salon: Sello SAT de Empresa Fiscalmente Responsable',
    E'Hola {salon_name},\n\nSabias que los clientes confian mas en negocios verificados?\n\nBeautyCita ofrece el sello de "Empresa Fiscalmente Responsable" a los salones que completan sus obligaciones fiscales a traves de nuestra plataforma.\n\nEste sello aparece en tu perfil publico y demuestra a tus clientes que:\n- Emites facturas electronicas (CFDIs)\n- Cumples con tus retenciones de ISR e IVA\n- Tu negocio opera en total transparencia fiscal\n\nEn un mercado donde la mayoria opera en la informalidad, este sello te diferencia. Los clientes que buscan servicios de calidad valoran la profesionalidad.\n\nAdemas, el gobierno ofrece incentivos fiscales para empresas socialmente responsables que pueden reducir tu carga tributaria.\n\nQuieres saber mas? Responde a este correo o registrate en beautycita.com\n\nSaludos,\n{rp_name}\nBeautyCita',
    'compliance',
    2
),
(
    'Lo que la competencia no te dice',
    'email',
    'Por que salones en {city} estan dejando Vagaro y Fresha',
    E'Hola {salon_name},\n\nSi usas Vagaro, Fresha, o Booksy, hay algo que no te han dicho:\n\nA partir de 2026, TODAS las plataformas digitales en Mexico deben retener impuestos. Eso incluye la plataforma que uses actualmente. La diferencia es que ellos no estan preparados para hacerlo.\n\nBeautyCita vs la competencia:\n\n- Idioma: Espanol nativo (no traduccion)\n- Reservas por WhatsApp: Si (ellos no)\n- Pagos SPEI: Si al 1% (ellos no)\n- Retenciones SAT: Automatico (ellos no)\n- CFDIs mensuales: Incluido (ellos no)\n- Costo de setup: $0 (ellos $25-49 USD/mes)\n- Soporte: WhatsApp directo (ellos email en ingles)\n\nNo esperes a que tu plataforma actual te deje colgado con el SAT.\n\n60 segundos para registrarte: beautycita.com\n\n{rp_name}\nBeautyCita',
    'competitive',
    3
),
(
    'El SAT viene por ti',
    'email',
    'Atencion {salon_name}: nuevas obligaciones fiscales para plataformas digitales',
    E'Hola {salon_name},\n\nEsto no es alarmismo — es la ley.\n\nLos articulos 113-A, 113-B, 113-C y 113-D de la Ley del ISR, reformados para 2026, establecen que:\n\n1. TODAS las plataformas digitales deben retener ISR (2.5%) e IVA (8%) de cada transaccion\n2. Las plataformas deben emitir CFDI por retenciones cada mes\n3. Los establecimientos que no esten dados de alta seran reportados al SAT\n4. El SAT puede solicitar informacion de CUALQUIER plataforma sobre sus proveedores de servicios\n\nQue significa para tu salon?\n\nSi recibes pagos electronicos (tarjeta, transferencia, app) a traves de cualquier plataforma, estas obligado a cumplir. Las multas por incumplimiento van desde $1,000 hasta $30,000 MXN por infraccion.\n\nBeautyCita es la UNICA plataforma de belleza en Mexico que ya tiene esto implementado:\n- Retenciones automaticas\n- CFDIs generados cada mes\n- Reportes al SAT en tu nombre\n- Dashboard fiscal en tiempo real\n\nNo te arriesgues. Registrate hoy: beautycita.com\n\n{rp_name}\nBeautyCita',
    'compliance',
    4
),
(
    'Invitacion exclusiva',
    'email',
    'Invitacion especial para {salon_name} - {review_count} resenas no mienten',
    E'Hola {salon_name},\n\nNotamos que tu salon tiene {rating} estrellas con {review_count} resenas en Google Maps. Eso habla de la calidad de tu trabajo.\n\nPor eso queremos invitarte personalmente a BeautyCita, la plataforma de belleza #1 en Mexico.\n\nComo salon destacado, te ofrecemos:\n\n- Onboarding gratuito con soporte dedicado\n- Posicionamiento prioritario en resultados de busqueda\n- Perfil verificado con sello de calidad\n- Sistema de reservas inteligente (tus clientes reservan en 30 segundos)\n- Portal web profesional para tu salon (beautycita.com/p/tu-salon)\n\nYa tenemos salones en {city} usando BeautyCita. No te quedes atras.\n\nResponde a este correo o registrate en 60 segundos: beautycita.com\n\nEs un placer,\n{rp_name}\nBeautyCita - Relaciones Publicas\n{rp_phone}',
    'exclusive',
    5
),
(
    'Mensaje WA inicial',
    'whatsapp',
    NULL,
    E'Hola! Soy {rp_name} de BeautyCita, la plataforma de reservas de belleza en Mexico.\n\nVimos {salon_name} en Google Maps y nos encanto. Queremos invitarlos a unirse — el registro toma 60 segundos y es gratis.\n\nbeautycita.com\n\nTienen alguna pregunta?',
    'general',
    1
),
(
    'Seguimiento WA',
    'whatsapp',
    NULL,
    E'Hola de nuevo! Soy {rp_name} de BeautyCita.\n\nLes escribi hace unos dias sobre unirse a nuestra plataforma. {interest_count} clientes ya han buscado {salon_name} en BeautyCita.\n\nEl registro es gratis y toma 60 segundos: beautycita.com\n\nQuedo al pendiente!',
    'general',
    2
);
