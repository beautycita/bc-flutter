-- ==========================================================================
-- Migration: 20260201000002_seed_follow_up_questions
-- Purpose:   Seed service_follow_up_questions for all services that require
--            follow-up questions (Section 13 of design doc).
-- ==========================================================================

-- Prevent duplicate runs
DELETE FROM public.service_follow_up_questions
WHERE service_type IN (
  'correccion_color',
  'recogido_evento',
  'ext_pestanas_clasicas',
  'ext_pestanas_hibridas',
  'ext_pestanas_volumen',
  'ext_pestanas_mega_volumen',
  'microblading',
  'micropigmentacion_cejas',
  'combo_pestanas_cejas',
  'maquillaje_evento',
  'prueba_maquillaje',
  'depilacion_cera',
  'depilacion_laser',
  'depilacion_sugaring',
  'micropigmentacion_labios',
  'maquillaje_xv',
  'maquillaje_editorial',
  'maquillaje_novia'
);

-- ---------------------------------------------------------------------------
-- 1-question services
-- ---------------------------------------------------------------------------

INSERT INTO public.service_follow_up_questions
  (service_type, question_order, question_key, question_text_es, question_text_en, answer_type, options, is_required)
VALUES

-- correccion_color
('correccion_color', 1, 'correction_type',
 '¿Qué tipo de corrección necesitas?',
 'What type of correction do you need?',
 'visual_cards',
 '[
    {"label_es": "Cubrir canas",    "label_en": "Cover grays",       "value": "cubrir_canas"},
    {"label_es": "Corregir tono",   "label_en": "Fix tone",          "value": "corregir_tono"},
    {"label_es": "Cambio radical",  "label_en": "Radical change",    "value": "cambio_radical"}
  ]'::jsonb,
 true),

-- recogido_evento
('recogido_evento', 1, 'event_type',
 '¿Para qué tipo de evento?',
 'What type of event?',
 'visual_cards',
 '[
    {"label_es": "Boda",        "label_en": "Wedding",      "value": "boda"},
    {"label_es": "XV Años",     "label_en": "Quinceañera",  "value": "xv_anos"},
    {"label_es": "Graduación",  "label_en": "Graduation",   "value": "graduacion"},
    {"label_es": "Otro",        "label_en": "Other",        "value": "otro"}
  ]'::jsonb,
 true),

-- ext_pestanas_clasicas
('ext_pestanas_clasicas', 1, 'lash_style',
 '¿Qué estilo prefieres?',
 'What style do you prefer?',
 'visual_cards',
 '[
    {"label_es": "Natural",  "label_en": "Natural",   "value": "natural"},
    {"label_es": "Gatita",   "label_en": "Cat eye",   "value": "gatita"},
    {"label_es": "Muñeca",   "label_en": "Doll",      "value": "muneca"}
  ]'::jsonb,
 true),

-- ext_pestanas_hibridas
('ext_pestanas_hibridas', 1, 'lash_style',
 '¿Qué estilo prefieres?',
 'What style do you prefer?',
 'visual_cards',
 '[
    {"label_es": "Natural",  "label_en": "Natural",   "value": "natural"},
    {"label_es": "Gatita",   "label_en": "Cat eye",   "value": "gatita"},
    {"label_es": "Muñeca",   "label_en": "Doll",      "value": "muneca"}
  ]'::jsonb,
 true),

-- ext_pestanas_volumen
('ext_pestanas_volumen', 1, 'lash_style',
 '¿Qué estilo prefieres?',
 'What style do you prefer?',
 'visual_cards',
 '[
    {"label_es": "Natural",     "label_en": "Natural",    "value": "natural"},
    {"label_es": "Dramático",   "label_en": "Dramatic",   "value": "dramatico"},
    {"label_es": "Mega volumen","label_en": "Mega volume", "value": "mega_volumen"}
  ]'::jsonb,
 true),

-- ext_pestanas_mega_volumen
('ext_pestanas_mega_volumen', 1, 'lash_style',
 '¿Qué estilo prefieres?',
 'What style do you prefer?',
 'visual_cards',
 '[
    {"label_es": "Dramático",   "label_en": "Dramatic",    "value": "dramatico"},
    {"label_es": "Hollywood",   "label_en": "Hollywood",   "value": "hollywood"},
    {"label_es": "Extremo",     "label_en": "Extreme",     "value": "extremo"}
  ]'::jsonb,
 true),

-- microblading
('microblading', 1, 'previous_work',
 '¿Tienes trabajo previo en cejas?',
 'Do you have previous brow work?',
 'yes_no',
 null,
 true),

-- micropigmentacion_cejas
('micropigmentacion_cejas', 1, 'previous_work',
 '¿Tienes trabajo previo en cejas?',
 'Do you have previous brow work?',
 'yes_no',
 null,
 true),

-- combo_pestanas_cejas
('combo_pestanas_cejas', 1, 'lash_style',
 '¿Qué estilo de pestañas prefieres?',
 'What lash style do you prefer?',
 'visual_cards',
 '[
    {"label_es": "Natural",     "label_en": "Natural",    "value": "natural"},
    {"label_es": "Gatita",      "label_en": "Cat eye",    "value": "gatita"},
    {"label_es": "Dramático",   "label_en": "Dramatic",   "value": "dramatico"}
  ]'::jsonb,
 true),

-- maquillaje_evento
('maquillaje_evento', 1, 'event_type',
 '¿Para qué tipo de evento?',
 'What type of event?',
 'visual_cards',
 '[
    {"label_es": "Boda",        "label_en": "Wedding",      "value": "boda"},
    {"label_es": "XV Años",     "label_en": "Quinceañera",  "value": "xv_anos"},
    {"label_es": "Graduación",  "label_en": "Graduation",   "value": "graduacion"},
    {"label_es": "Cena",        "label_en": "Dinner",       "value": "cena"},
    {"label_es": "Otro",        "label_en": "Other",        "value": "otro"}
  ]'::jsonb,
 true),

-- prueba_maquillaje
('prueba_maquillaje', 1, 'event_type',
 '¿Para qué tipo de evento es la prueba?',
 'What type of event is the trial for?',
 'visual_cards',
 '[
    {"label_es": "Boda",     "label_en": "Wedding",      "value": "boda"},
    {"label_es": "XV Años",  "label_en": "Quinceañera",  "value": "xv_anos"},
    {"label_es": "Otro",     "label_en": "Other",        "value": "otro"}
  ]'::jsonb,
 true),

-- depilacion_cera
('depilacion_cera', 1, 'body_zone',
 '¿Qué zona?',
 'Which area?',
 'visual_cards',
 '[
    {"label_es": "Piernas completas", "label_en": "Full legs",   "value": "piernas_completas"},
    {"label_es": "Media pierna",      "label_en": "Half leg",    "value": "media_pierna"},
    {"label_es": "Bikini",            "label_en": "Bikini",      "value": "bikini"},
    {"label_es": "Axilas",            "label_en": "Underarms",   "value": "axilas"},
    {"label_es": "Brazos",            "label_en": "Arms",        "value": "brazos"},
    {"label_es": "Facial",            "label_en": "Facial",      "value": "facial"}
  ]'::jsonb,
 true),

-- depilacion_laser
('depilacion_laser', 1, 'body_zone',
 '¿Qué zona?',
 'Which area?',
 'visual_cards',
 '[
    {"label_es": "Piernas completas", "label_en": "Full legs",    "value": "piernas_completas"},
    {"label_es": "Bikini",            "label_en": "Bikini",       "value": "bikini"},
    {"label_es": "Axilas",            "label_en": "Underarms",    "value": "axilas"},
    {"label_es": "Facial",            "label_en": "Facial",       "value": "facial"},
    {"label_es": "Espalda",           "label_en": "Back",         "value": "espalda"},
    {"label_es": "Cuerpo completo",   "label_en": "Full body",    "value": "cuerpo_completo"}
  ]'::jsonb,
 true),

-- depilacion_sugaring
('depilacion_sugaring', 1, 'body_zone',
 '¿Qué zona?',
 'Which area?',
 'visual_cards',
 '[
    {"label_es": "Piernas completas", "label_en": "Full legs",   "value": "piernas_completas"},
    {"label_es": "Media pierna",      "label_en": "Half leg",    "value": "media_pierna"},
    {"label_es": "Bikini",            "label_en": "Bikini",      "value": "bikini"},
    {"label_es": "Axilas",            "label_en": "Underarms",   "value": "axilas"},
    {"label_es": "Brazos",            "label_en": "Arms",        "value": "brazos"},
    {"label_es": "Facial",            "label_en": "Facial",      "value": "facial"}
  ]'::jsonb,
 true),

-- micropigmentacion_labios
('micropigmentacion_labios', 1, 'lip_effect',
 '¿Qué efecto buscas?',
 'What effect are you looking for?',
 'visual_cards',
 '[
    {"label_es": "Natural",   "label_en": "Natural",   "value": "natural"},
    {"label_es": "Definido",  "label_en": "Defined",   "value": "definido"},
    {"label_es": "Rubor",     "label_en": "Blush",     "value": "rubor"}
  ]'::jsonb,
 true),

-- ---------------------------------------------------------------------------
-- 2-question services
-- ---------------------------------------------------------------------------

-- maquillaje_xv (Q1: date_picker, Q2: yes_no)
('maquillaje_xv', 1, 'event_date',
 '¿Cuándo son los XV Años?',
 'When is the Quinceañera?',
 'date_picker',
 null,
 true),

('maquillaje_xv', 2, 'needs_trial',
 '¿Necesitas prueba previa?',
 'Do you need a prior trial?',
 'yes_no',
 null,
 true),

-- maquillaje_editorial (Q1: visual_cards, Q2: visual_cards)
('maquillaje_editorial', 1, 'editorial_type',
 '¿Qué tipo de editorial?',
 'What type of editorial?',
 'visual_cards',
 '[
    {"label_es": "Moda",       "label_en": "Fashion",    "value": "moda"},
    {"label_es": "Beauty",     "label_en": "Beauty",     "value": "beauty"},
    {"label_es": "Artístico",  "label_en": "Artistic",   "value": "artistico"}
  ]'::jsonb,
 true),

('maquillaje_editorial', 2, 'model_count',
 '¿Cuántas modelos?',
 'How many models?',
 'visual_cards',
 '[
    {"label_es": "1",    "label_en": "1",    "value": "1"},
    {"label_es": "2-3",  "label_en": "2-3",  "value": "2_3"},
    {"label_es": "4+",   "label_en": "4+",   "value": "4_plus"}
  ]'::jsonb,
 true),

-- ---------------------------------------------------------------------------
-- 3-question service
-- ---------------------------------------------------------------------------

-- maquillaje_novia (Q1: date_picker, Q2: visual_cards, Q3: yes_no)
('maquillaje_novia', 1, 'wedding_date',
 '¿Cuándo es tu boda?',
 'When is your wedding?',
 'date_picker',
 null,
 true),

('maquillaje_novia', 2, 'location_preference',
 '¿En salón o a domicilio?',
 'At salon or home service?',
 'visual_cards',
 '[
    {"label_es": "En salón",     "label_en": "At salon",      "value": "en_salon"},
    {"label_es": "A domicilio",  "label_en": "Home service",  "value": "a_domicilio"}
  ]'::jsonb,
 true),

('maquillaje_novia', 3, 'needs_trial',
 '¿Necesitas prueba previa?',
 'Do you need a prior trial?',
 'yes_no',
 null,
 true);
