-- =============================================================================
-- BeautyCita — Intelligent Booking Engine — COMPLETE SEED DATA
-- Generated: 2026-02-01
-- =============================================================================
-- INSERT ORDER (respects foreign key dependencies):
--   1. engine_settings          (no deps)
--   2. service_profiles         (no deps)
--   3. service_categories_tree  (self-referencing, parents first)
--   4. time_inference_rules     (no deps)
--   5. businesses               (no deps)
--   6. staff                    (refs businesses)
--   7. services                 (refs businesses, service_profiles)
--   8. staff_services           (refs staff, services)
--   9. staff_schedules          (refs staff)
--  10. notification_templates   (no deps)
-- =============================================================================

-- =============================================================================
-- 1. ENGINE SETTINGS (23 rows)
-- Global engine-wide configuration, key-value store.
-- =============================================================================

INSERT INTO engine_settings (key, value, data_type, min_value, max_value, description_es, description_en, group_name, sort_order) VALUES

-- Group: results
('results_count', '3', 'integer', 1, 10,
 'Cuántas tarjetas ve el usuario. 3 es el punto ideal: suficiente para comparar, poco para no abrumar.',
 'How many cards the user sees. 3 is the sweet spot: enough to compare, few enough to not overwhelm.',
 'results', 0),

('backup_results_count', '6', 'integer', 3, 20,
 'Pre-cargados para "¿Más opciones?" Sin espera extra.',
 'Pre-loaded for "More options?" No additional wait.',
 'results', 1),

('min_candidates_before_expand', '3', 'integer', 1, 10,
 'Si hay menos que este número, el radio se expande automáticamente.',
 'If fewer than this number, the search radius auto-expands.',
 'results', 2),

('response_time_target_ms', '400', 'integer', 200, 1000,
 'Presupuesto de tiempo para el motor. Afecta timeout de APIs externas (Google, Uber).',
 'Time budget for the engine. Affects external API timeouts (Google, Uber).',
 'results', 3),

-- Group: scoring
('bayesian_prior_mean', '4.3', 'number', 3.0, 5.0,
 'Rating promedio asumido para salones con pocas reseñas. "Inocente hasta demostrar lo contrario." 4.3 = ligeramente optimista.',
 'Assumed average rating for salons with few reviews. "Innocent until proven otherwise." 4.3 = slightly optimistic.',
 'scoring', 0),

('bayesian_prior_weight', '10', 'integer', 1, 50,
 'Cuántas reseñas equivalentes vale la prior. 10 = necesitas ~10 reseñas para que tu rating real domine. Más alto = más conservador con salones nuevos.',
 'How many equivalent reviews the prior is worth. 10 = you need ~10 reviews for your real rating to dominate. Higher = more conservative with new salons.',
 'scoring', 1),

('price_normalization_steepness', '1.4', 'number', 0.5, 3.0,
 'Qué tan fuerte penaliza precios por encima del promedio. 1.0 = lineal. 2.0+ = penaliza mucho los caros. 0.5 = tolera precios altos.',
 'How strongly it penalizes prices above average. 1.0 = linear. 2.0+ = heavily penalizes expensive. 0.5 = tolerates high prices.',
 'scoring', 2),

-- Group: uber_mode
('uber_proximity_reduction', '0.30', 'number', 0.0, 0.60,
 'Cuánto se reduce el peso de proximidad cuando el usuario elige Uber. 0.30 = se reduce 30%. La reducción se redistribuye a rating y disponibilidad.',
 'How much the proximity weight is reduced when the user chooses Uber. 0.30 = reduced by 30%. The reduction is redistributed to rating and availability.',
 'uber_mode', 0),

('uber_rating_redistribution', '0.60', 'number', 0.0, 1.0,
 'De la reducción de proximidad en modo Uber, qué porcentaje va al peso de rating.',
 'Of the proximity reduction in Uber mode, what percentage goes to the rating weight.',
 'uber_mode', 1),

('uber_availability_redistribution', '0.40', 'number', 0.0, 1.0,
 'De la reducción de proximidad en modo Uber, qué porcentaje va al peso de disponibilidad. (rating + disponibilidad deben sumar 1.0)',
 'Of the proximity reduction in Uber mode, what percentage goes to the availability weight. (rating + availability must sum to 1.0)',
 'uber_mode', 2),

-- Group: transport
('uber_pickup_buffer_min', '3', 'integer', 0, 15,
 'Minutos extra antes de la hora de cita para calcular recogida del Uber de ida. 3 = recoge 3 min antes de lo necesario.',
 'Extra minutes before appointment time to calculate outbound Uber pickup. 3 = picks up 3 min earlier than needed.',
 'transport', 0),

('uber_checkout_buffer_min', '5', 'integer', 0, 15,
 'Minutos extra después de la cita para el Uber de vuelta. 5 = programa recogida 5 min después de la hora estimada de finalización.',
 'Extra minutes after appointment for return Uber. 5 = schedules pickup 5 min after estimated end time.',
 'transport', 1),

-- Group: reviews
('review_recency_preferred_days', '30', 'integer', 7, 90,
 'Reseñas dentro de este rango tienen prioridad máxima para el snippet en la tarjeta.',
 'Reviews within this range have maximum priority for the card snippet.',
 'reviews', 0),

('review_recency_max_days', '90', 'integer', 30, 365,
 'Reseñas más antiguas que esto se ignoran para snippets. Solo se usan si no hay nada más reciente.',
 'Reviews older than this are ignored for snippets. Only used if nothing more recent exists.',
 'reviews', 1),

('review_min_word_count', '20', 'integer', 5, 50,
 'Filtra reseñas cortas tipo "Muy bien 5 estrellas". Solo reseñas con sustancia se usan como snippet.',
 'Filters short reviews like "Very good 5 stars". Only reviews with substance are used as snippets.',
 'reviews', 2),

-- Group: user_patterns
('user_pattern_blend_threshold', '0.60', 'number', 0.3, 0.9,
 'Confidence mínima para mezclar el patrón personal del usuario con la inferencia global. 0.6 = necesita ser bastante consistente.',
 'Minimum confidence to blend the user''s personal pattern with global inference. 0.6 = needs to be fairly consistent.',
 'user_patterns', 0),

('user_pattern_dominate_threshold', '0.85', 'number', 0.6, 1.0,
 'Confidence mínima para que el patrón personal reemplace completamente la inferencia. 0.85 = muy consistente.',
 'Minimum confidence for personal pattern to completely replace inference. 0.85 = very consistent.',
 'user_patterns', 1),

('correction_rate_alert_threshold', '0.30', 'number', 0.1, 0.6,
 'Si este porcentaje de usuarios cambian el horario sugerido, se muestra alerta al admin.',
 'If this percentage of users change the suggested time, an alert is shown to the admin.',
 'user_patterns', 2),

-- Group: card_thresholds
('card_price_comparison_threshold', '0.30', 'number', 0.1, 0.8,
 'Cuando price_variance del servicio supera este umbral, la tarjeta muestra "prom. zona: $X". Más bajo = más tarjetas muestran comparación.',
 'When service price_variance exceeds this threshold, the card shows "area avg: $X". Lower = more cards show comparison.',
 'card_thresholds', 0),

('card_portfolio_carousel_threshold', '0.50', 'number', 0.2, 0.9,
 'Cuando portfolio_importance del servicio supera este umbral, la tarjeta incluye fotos del trabajo. Más bajo = más servicios muestran fotos.',
 'When service portfolio_importance exceeds this threshold, the card includes work photos. Lower = more services show photos.',
 'card_thresholds', 1),

('card_experience_years_threshold', '0.50', 'number', 0.2, 0.9,
 'Cuando skill_criticality supera este umbral, la tarjeta muestra "X años de exp" del estilista.',
 'When skill_criticality exceeds this threshold, the card shows "X years exp" for the stylist.',
 'card_thresholds', 2),

('card_walkin_availability_threshold', '0.70', 'number', 0.3, 0.9,
 'Cuando availability_level del servicio supera este umbral Y el salón lo permite, muestra "Se aceptan sin cita".',
 'When service availability_level exceeds this threshold AND salon allows it, shows "Walk-ins accepted".',
 'card_thresholds', 3),

('card_new_salon_review_threshold', '5', 'integer', 1, 20,
 'Salones con menos de estas reseñas muestran badge "Nuevo en BeautyCita" en lugar de snippet de reseña.',
 'Salons with fewer than this many reviews show "New on BeautyCita" badge instead of review snippet.',
 'card_thresholds', 4);


-- =============================================================================
-- 2. SERVICE PROFILES (~105 rows)
-- One row per leaf node in the category tree.
-- All 5 weights MUST sum to 1.0 for every row.
-- =============================================================================

INSERT INTO service_profiles (
  service_type, category, subcategory,
  display_name_es, display_name_en, icon,
  availability_level, typical_duration_min, skill_criticality, price_variance, portfolio_importance,
  typical_lead_time, is_event_driven, search_radius_km, radius_auto_expand, radius_max_multiplier, max_follow_up_questions,
  weight_proximity, weight_availability, weight_rating, weight_price, weight_portfolio,
  show_price_comparison, show_portfolio_carousel, show_experience_years, show_certification_badge, show_walkin_indicator
) VALUES

-- ═══════════════════════════════════════════════════════════════════════════════
-- UÑAS > Manicure
-- ═══════════════════════════════════════════════════════════════════════════════
('manicure_clasico', 'unas', 'manicure',
 'Manicure Clásico/Básico', 'Classic Manicure', '💅',
 0.90, 30, 0.15, 0.15, 0.00,
 'same_day', false, 6.0, true, 3.0, 0,
 0.45, 0.25, 0.15, 0.15, 0.00,
 false, false, false, false, true),

('manicure_gel', 'unas', 'manicure',
 'Manicure Gel', 'Gel Manicure', '💅',
 0.75, 50, 0.30, 0.20, 0.10,
 'same_day', false, 8.0, true, 3.0, 0,
 0.40, 0.25, 0.20, 0.15, 0.00,
 false, false, false, false, true),

('manicure_frances', 'unas', 'manicure',
 'Manicure Francés', 'French Manicure', '💅',
 0.80, 40, 0.25, 0.15, 0.05,
 'same_day', false, 7.0, true, 3.0, 0,
 0.42, 0.25, 0.18, 0.15, 0.00,
 false, false, false, false, true),

('manicure_dip_powder', 'unas', 'manicure',
 'Manicure Dip Powder', 'Dip Powder Manicure', '💅',
 0.55, 55, 0.40, 0.25, 0.15,
 'same_day', false, 10.0, true, 3.0, 0,
 0.35, 0.25, 0.20, 0.15, 0.05,
 false, false, false, false, true),

('manicure_acrilico', 'unas', 'manicure',
 'Manicure Acrílico', 'Acrylic Manicure', '💅',
 0.70, 75, 0.40, 0.25, 0.10,
 'same_day', false, 8.0, true, 3.0, 0,
 0.38, 0.25, 0.20, 0.15, 0.02,
 false, false, false, false, true),

('manicure_spa_luxury', 'unas', 'manicure',
 'Manicure Spa/Luxury', 'Spa/Luxury Manicure', '💅',
 0.60, 60, 0.20, 0.30, 0.00,
 'same_day', false, 10.0, true, 3.0, 0,
 0.35, 0.25, 0.20, 0.20, 0.00,
 true, false, false, false, true),

('manicure_japones', 'unas', 'manicure',
 'Manicure Japonés', 'Japanese Manicure', '💅',
 0.35, 50, 0.50, 0.30, 0.00,
 'this_week', false, 15.0, true, 3.0, 0,
 0.25, 0.20, 0.30, 0.25, 0.00,
 true, false, false, true, false),

('manicure_parafina', 'unas', 'manicure',
 'Manicure Parafina', 'Paraffin Manicure', '💅',
 0.55, 50, 0.20, 0.25, 0.00,
 'same_day', false, 10.0, true, 3.0, 0,
 0.40, 0.25, 0.15, 0.20, 0.00,
 false, false, false, false, true),

('manicure_ruso', 'unas', 'manicure',
 'Manicure Ruso', 'Russian Manicure', '💅',
 0.40, 60, 0.60, 0.30, 0.10,
 'this_week', false, 12.0, true, 3.0, 0,
 0.25, 0.20, 0.30, 0.20, 0.05,
 true, false, true, true, false),

-- ═══════════════════════════════════════════════════════════════════════════════
-- UÑAS > Pedicure
-- ═══════════════════════════════════════════════════════════════════════════════
('pedicure_clasico', 'unas', 'pedicure',
 'Pedicure Clásico/Básico', 'Classic Pedicure', '🦶',
 0.88, 40, 0.15, 0.15, 0.00,
 'same_day', false, 6.0, true, 3.0, 0,
 0.45, 0.25, 0.15, 0.15, 0.00,
 false, false, false, false, true),

('pedicure_spa_luxury', 'unas', 'pedicure',
 'Pedicure Spa/Luxury', 'Spa/Luxury Pedicure', '🦶',
 0.60, 60, 0.20, 0.30, 0.00,
 'same_day', false, 10.0, true, 3.0, 0,
 0.35, 0.25, 0.20, 0.20, 0.00,
 true, false, false, false, true),

('pedicure_gel', 'unas', 'pedicure',
 'Pedicure Gel', 'Gel Pedicure', '🦶',
 0.65, 55, 0.30, 0.20, 0.05,
 'same_day', false, 8.0, true, 3.0, 0,
 0.40, 0.25, 0.20, 0.15, 0.00,
 false, false, false, false, true),

('pedicure_medico', 'unas', 'pedicure',
 'Pedicure Médico', 'Medical Pedicure', '🦶',
 0.30, 60, 0.80, 0.25, 0.00,
 'this_week', false, 15.0, true, 3.0, 0,
 0.20, 0.15, 0.35, 0.30, 0.00,
 true, false, true, true, false),

('pedicure_parafina', 'unas', 'pedicure',
 'Pedicure Parafina', 'Paraffin Pedicure', '🦶',
 0.55, 55, 0.20, 0.25, 0.00,
 'same_day', false, 10.0, true, 3.0, 0,
 0.40, 0.25, 0.15, 0.20, 0.00,
 false, false, false, false, true),

-- ═══════════════════════════════════════════════════════════════════════════════
-- UÑAS > Other (direct children)
-- ═══════════════════════════════════════════════════════════════════════════════
('nail_art', 'unas', null,
 'Nail Art', 'Nail Art', '🎨',
 0.40, 75, 0.70, 0.35, 0.80,
 'this_week', false, 15.0, true, 3.0, 0,
 0.15, 0.15, 0.25, 0.15, 0.30,
 true, true, true, false, false),

('cambio_esmalte', 'unas', null,
 'Cambio de Esmalte', 'Polish Change', '💅',
 0.95, 15, 0.05, 0.10, 0.00,
 'same_day', false, 5.0, true, 3.0, 0,
 0.50, 0.25, 0.10, 0.15, 0.00,
 false, false, false, false, true),

('reparacion_una', 'unas', null,
 'Reparación de Uña', 'Nail Repair', '🔧',
 0.70, 20, 0.30, 0.15, 0.00,
 'same_day', false, 8.0, true, 3.0, 0,
 0.45, 0.25, 0.15, 0.15, 0.00,
 false, false, false, false, true),

('relleno_acrilico_gel', 'unas', null,
 'Relleno (Acrílico/Gel)', 'Fill-In (Acrylic/Gel)', '💅',
 0.80, 45, 0.25, 0.20, 0.00,
 'same_day', false, 8.0, true, 3.0, 0,
 0.40, 0.25, 0.20, 0.15, 0.00,
 false, false, false, false, true),

('retiro_acrilico_gel_dip', 'unas', null,
 'Retiro (Acrílico/Gel/Dip)', 'Removal (Acrylic/Gel/Dip)', '💅',
 0.80, 30, 0.20, 0.15, 0.00,
 'same_day', false, 8.0, true, 3.0, 0,
 0.45, 0.25, 0.15, 0.15, 0.00,
 false, false, false, false, true),

-- ═══════════════════════════════════════════════════════════════════════════════
-- CABELLO > Corte
-- ═══════════════════════════════════════════════════════════════════════════════
('corte_mujer', 'cabello', 'corte',
 'Corte Mujer', 'Women''s Haircut', '✂️',
 0.85, 45, 0.35, 0.25, 0.10,
 'same_day', false, 8.0, true, 3.0, 0,
 0.40, 0.25, 0.20, 0.15, 0.00,
 false, false, false, false, true),

('corte_hombre', 'cabello', 'corte',
 'Corte Hombre', 'Men''s Haircut', '✂️',
 0.90, 30, 0.25, 0.20, 0.05,
 'same_day', false, 6.0, true, 3.0, 0,
 0.45, 0.25, 0.15, 0.15, 0.00,
 false, false, false, false, true),

('corte_nino', 'cabello', 'corte',
 'Corte Niño/a', 'Kids'' Haircut', '✂️',
 0.80, 25, 0.15, 0.15, 0.00,
 'same_day', false, 6.0, true, 3.0, 0,
 0.45, 0.25, 0.15, 0.15, 0.00,
 false, false, false, false, true),

-- ═══════════════════════════════════════════════════════════════════════════════
-- CABELLO > Color
-- ═══════════════════════════════════════════════════════════════════════════════
('tinte_completo', 'cabello', 'color',
 'Tinte Completo', 'Full Color', '🎨',
 0.60, 120, 0.55, 0.30, 0.30,
 'this_week', false, 12.0, true, 3.0, 0,
 0.20, 0.15, 0.30, 0.15, 0.20,
 true, true, true, false, false),

('retoque_raiz', 'cabello', 'color',
 'Retoque de Raíz', 'Root Touch-Up', '🎨',
 0.70, 75, 0.40, 0.25, 0.10,
 'same_day', false, 10.0, true, 3.0, 0,
 0.35, 0.25, 0.25, 0.15, 0.00,
 false, false, false, false, true),

('mechas_highlights', 'cabello', 'color',
 'Mechas/Highlights', 'Highlights', '🎨',
 0.45, 150, 0.75, 0.35, 0.70,
 'this_week', false, 15.0, true, 3.0, 0,
 0.12, 0.13, 0.30, 0.15, 0.30,
 true, true, true, false, false),

('balayage', 'cabello', 'color',
 'Balayage', 'Balayage', '🎨',
 0.35, 180, 0.85, 0.40, 0.90,
 'this_week', false, 20.0, true, 3.0, 0,
 0.10, 0.10, 0.30, 0.15, 0.35,
 true, true, true, false, false),

('ombre', 'cabello', 'color',
 'Ombré', 'Ombré', '🎨',
 0.35, 160, 0.80, 0.35, 0.85,
 'this_week', false, 18.0, true, 3.0, 0,
 0.10, 0.10, 0.30, 0.15, 0.35,
 true, true, true, false, false),

('correccion_color', 'cabello', 'color',
 'Corrección de Color', 'Color Correction', '🎨',
 0.20, 240, 0.95, 0.45, 0.90,
 'this_week', false, 25.0, true, 3.0, 1,
 0.05, 0.10, 0.30, 0.15, 0.40,
 true, true, true, true, false),

('decoloracion', 'cabello', 'color',
 'Decoloración', 'Bleaching', '🎨',
 0.40, 150, 0.80, 0.35, 0.50,
 'this_week', false, 15.0, true, 3.0, 0,
 0.15, 0.15, 0.30, 0.15, 0.25,
 true, true, true, false, false),

-- ═══════════════════════════════════════════════════════════════════════════════
-- CABELLO > Tratamiento
-- ═══════════════════════════════════════════════════════════════════════════════
('keratina_alisado', 'cabello', 'tratamiento',
 'Keratina/Alisado', 'Keratin/Straightening', '✨',
 0.45, 180, 0.75, 0.40, 0.50,
 'this_week', false, 15.0, true, 3.0, 0,
 0.15, 0.15, 0.30, 0.20, 0.20,
 true, true, true, false, false),

('botox_capilar', 'cabello', 'tratamiento',
 'Botox Capilar', 'Hair Botox', '✨',
 0.40, 120, 0.65, 0.35, 0.40,
 'this_week', false, 15.0, true, 3.0, 0,
 0.15, 0.15, 0.30, 0.20, 0.20,
 true, true, true, false, false),

('hidratacion_profunda', 'cabello', 'tratamiento',
 'Hidratación Profunda', 'Deep Conditioning', '✨',
 0.70, 60, 0.30, 0.25, 0.00,
 'same_day', false, 10.0, true, 3.0, 0,
 0.35, 0.25, 0.20, 0.20, 0.00,
 false, false, false, false, true),

('olaplex_reconstructor', 'cabello', 'tratamiento',
 'Olaplex/Reconstructor', 'Olaplex/Reconstruction', '✨',
 0.45, 90, 0.60, 0.35, 0.20,
 'this_week', false, 12.0, true, 3.0, 0,
 0.20, 0.20, 0.30, 0.20, 0.10,
 true, false, true, false, false),

('tratamiento_anticaida', 'cabello', 'tratamiento',
 'Tratamiento Anticaída', 'Hair Loss Treatment', '✨',
 0.30, 60, 0.70, 0.30, 0.10,
 'this_week', false, 15.0, true, 3.0, 0,
 0.20, 0.15, 0.35, 0.25, 0.05,
 true, false, true, true, false),

-- ═══════════════════════════════════════════════════════════════════════════════
-- CABELLO > Peinado
-- ═══════════════════════════════════════════════════════════════════════════════
('blowout_secado', 'cabello', 'peinado',
 'Blowout/Secado', 'Blowout', '💇',
 0.80, 35, 0.25, 0.20, 0.05,
 'same_day', false, 8.0, true, 3.0, 0,
 0.40, 0.25, 0.20, 0.15, 0.00,
 false, false, false, false, true),

('planchado', 'cabello', 'peinado',
 'Planchado', 'Flat Iron Styling', '💇',
 0.80, 30, 0.20, 0.15, 0.00,
 'same_day', false, 8.0, true, 3.0, 0,
 0.45, 0.25, 0.15, 0.15, 0.00,
 false, false, false, false, true),

('ondas_rizos', 'cabello', 'peinado',
 'Ondas/Rizos', 'Waves/Curls', '💇',
 0.70, 40, 0.35, 0.20, 0.15,
 'same_day', false, 10.0, true, 3.0, 0,
 0.35, 0.25, 0.20, 0.15, 0.05,
 false, false, false, false, true),

('recogido_evento', 'cabello', 'peinado',
 'Recogido (Evento)', 'Updo (Event)', '💇',
 0.45, 60, 0.65, 0.30, 0.60,
 'next_week', true, 15.0, true, 3.0, 1,
 0.10, 0.15, 0.30, 0.15, 0.30,
 true, true, true, false, false),

('trenzas', 'cabello', 'peinado',
 'Trenzas', 'Braids', '💇',
 0.55, 50, 0.45, 0.20, 0.30,
 'same_day', false, 10.0, true, 3.0, 0,
 0.30, 0.25, 0.20, 0.15, 0.10,
 false, false, false, false, true),

-- ═══════════════════════════════════════════════════════════════════════════════
-- CABELLO > Extensiones
-- ═══════════════════════════════════════════════════════════════════════════════
('ext_clip_in', 'cabello', 'extensiones',
 'Extensiones Clip-In', 'Clip-In Extensions', '💇',
 0.45, 60, 0.40, 0.35, 0.30,
 'this_week', false, 15.0, true, 3.0, 0,
 0.20, 0.20, 0.25, 0.20, 0.15,
 true, true, false, false, false),

('ext_cosidas', 'cabello', 'extensiones',
 'Extensiones Cosidas', 'Sew-In Extensions', '💇',
 0.30, 180, 0.75, 0.40, 0.50,
 'this_week', false, 20.0, true, 3.0, 0,
 0.10, 0.15, 0.30, 0.20, 0.25,
 true, true, true, false, false),

('ext_fusion_keratina', 'cabello', 'extensiones',
 'Extensiones Fusión/Keratina', 'Fusion/Keratin Extensions', '💇',
 0.25, 210, 0.85, 0.45, 0.60,
 'next_week', false, 25.0, true, 3.0, 0,
 0.05, 0.10, 0.30, 0.20, 0.35,
 true, true, true, true, false),

('ext_cinta_tape_in', 'cabello', 'extensiones',
 'Extensiones Cinta/Tape-In', 'Tape-In Extensions', '💇',
 0.30, 120, 0.70, 0.40, 0.45,
 'this_week', false, 20.0, true, 3.0, 0,
 0.10, 0.15, 0.30, 0.20, 0.25,
 true, true, true, false, false),

-- ═══════════════════════════════════════════════════════════════════════════════
-- PESTAÑAS Y CEJAS > Pestañas
-- ═══════════════════════════════════════════════════════════════════════════════
('ext_pestanas_clasicas', 'pestanas_cejas', 'pestanas',
 'Extensiones Clásicas', 'Classic Lash Extensions', '👁️',
 0.30, 150, 0.80, 0.30, 0.85,
 'this_week', false, 20.0, true, 3.0, 1,
 0.10, 0.10, 0.35, 0.15, 0.30,
 true, true, true, true, false),

('ext_pestanas_hibridas', 'pestanas_cejas', 'pestanas',
 'Extensiones Híbridas', 'Hybrid Lash Extensions', '👁️',
 0.25, 165, 0.85, 0.35, 0.88,
 'this_week', false, 22.0, true, 3.0, 1,
 0.10, 0.10, 0.30, 0.15, 0.35,
 true, true, true, true, false),

('ext_pestanas_volumen', 'pestanas_cejas', 'pestanas',
 'Extensiones Volumen', 'Volume Lash Extensions', '👁️',
 0.20, 180, 0.90, 0.35, 0.90,
 'this_week', false, 25.0, true, 3.0, 1,
 0.10, 0.10, 0.30, 0.15, 0.35,
 true, true, true, true, false),

('ext_pestanas_mega_volumen', 'pestanas_cejas', 'pestanas',
 'Mega Volumen', 'Mega Volume Lash Extensions', '👁️',
 0.15, 210, 0.95, 0.40, 0.92,
 'this_week', false, 25.0, true, 3.0, 1,
 0.05, 0.10, 0.30, 0.15, 0.40,
 true, true, true, true, false),

('lifting_pestanas', 'pestanas_cejas', 'pestanas',
 'Lifting de Pestañas', 'Lash Lift', '👁️',
 0.45, 60, 0.55, 0.25, 0.40,
 'this_week', false, 12.0, true, 3.0, 0,
 0.20, 0.20, 0.30, 0.15, 0.15,
 false, true, true, false, false),

('tinte_pestanas', 'pestanas_cejas', 'pestanas',
 'Tinte de Pestañas', 'Lash Tint', '👁️',
 0.55, 30, 0.35, 0.15, 0.10,
 'same_day', false, 10.0, true, 3.0, 0,
 0.40, 0.25, 0.20, 0.15, 0.00,
 false, false, false, false, true),

('relleno_pestanas', 'pestanas_cejas', 'pestanas',
 'Relleno (2-3 semanas)', 'Lash Fill (2-3 weeks)', '👁️',
 0.35, 90, 0.70, 0.25, 0.60,
 'this_week', false, 15.0, true, 3.0, 0,
 0.15, 0.15, 0.30, 0.15, 0.25,
 false, true, true, false, false),

('retiro_pestanas', 'pestanas_cejas', 'pestanas',
 'Retiro de Pestañas', 'Lash Removal', '👁️',
 0.50, 30, 0.40, 0.15, 0.00,
 'same_day', false, 12.0, true, 3.0, 0,
 0.40, 0.25, 0.20, 0.15, 0.00,
 false, false, false, false, true),

-- ═══════════════════════════════════════════════════════════════════════════════
-- PESTAÑAS Y CEJAS > Cejas
-- ═══════════════════════════════════════════════════════════════════════════════
('diseno_depilacion_cejas', 'pestanas_cejas', 'cejas',
 'Diseño/Depilación de Cejas', 'Brow Shaping/Waxing', '🪒',
 0.80, 20, 0.30, 0.15, 0.10,
 'same_day', false, 8.0, true, 3.0, 0,
 0.40, 0.25, 0.20, 0.15, 0.00,
 false, false, false, false, true),

('microblading', 'pestanas_cejas', 'cejas',
 'Microblading', 'Microblading', '🪒',
 0.25, 120, 0.95, 0.40, 0.95,
 'next_week', false, 30.0, true, 3.0, 1,
 0.05, 0.10, 0.25, 0.15, 0.45,
 true, true, true, true, false),

('micropigmentacion_cejas', 'pestanas_cejas', 'cejas',
 'Micropigmentación de Cejas', 'Brow Micropigmentation', '🪒',
 0.20, 120, 0.95, 0.40, 0.95,
 'next_week', false, 30.0, true, 3.0, 1,
 0.05, 0.10, 0.25, 0.15, 0.45,
 true, true, true, true, false),

('laminado_cejas', 'pestanas_cejas', 'cejas',
 'Laminado de Cejas', 'Brow Lamination', '🪒',
 0.45, 45, 0.55, 0.25, 0.50,
 'this_week', false, 12.0, true, 3.0, 0,
 0.20, 0.20, 0.25, 0.15, 0.20,
 false, true, true, false, false),

('tinte_cejas', 'pestanas_cejas', 'cejas',
 'Tinte de Cejas', 'Brow Tint', '🪒',
 0.65, 20, 0.25, 0.15, 0.05,
 'same_day', false, 8.0, true, 3.0, 0,
 0.42, 0.25, 0.18, 0.15, 0.00,
 false, false, false, false, true),

('henna_cejas', 'pestanas_cejas', 'cejas',
 'Henna de Cejas', 'Brow Henna', '🪒',
 0.45, 30, 0.45, 0.20, 0.30,
 'this_week', false, 12.0, true, 3.0, 0,
 0.25, 0.20, 0.25, 0.15, 0.15,
 false, true, false, false, false),

-- ═══════════════════════════════════════════════════════════════════════════════
-- PESTAÑAS Y CEJAS > Combo
-- ═══════════════════════════════════════════════════════════════════════════════
('combo_pestanas_cejas', 'pestanas_cejas', null,
 'Combo Pestañas + Cejas', 'Lash + Brow Combo', '👁️',
 0.30, 120, 0.70, 0.30, 0.70,
 'this_week', false, 15.0, true, 3.0, 1,
 0.10, 0.15, 0.30, 0.15, 0.30,
 true, true, true, false, false),

-- ═══════════════════════════════════════════════════════════════════════════════
-- MAQUILLAJE
-- ═══════════════════════════════════════════════════════════════════════════════
('maquillaje_social', 'maquillaje', null,
 'Maquillaje Social/Casual', 'Social/Casual Makeup', '💄',
 0.65, 45, 0.40, 0.25, 0.40,
 'next_day', false, 10.0, true, 3.0, 0,
 0.30, 0.25, 0.20, 0.15, 0.10,
 false, true, false, false, false),

('maquillaje_evento', 'maquillaje', null,
 'Maquillaje Evento/Fiesta', 'Event/Party Makeup', '💄',
 0.50, 60, 0.55, 0.30, 0.55,
 'next_week', true, 15.0, true, 3.0, 1,
 0.15, 0.15, 0.30, 0.15, 0.25,
 true, true, true, false, false),

('maquillaje_novia', 'maquillaje', null,
 'Maquillaje Novia', 'Bridal Makeup', '💄',
 0.30, 120, 0.90, 0.40, 0.85,
 'months', true, 30.0, true, 3.0, 3,
 0.05, 0.10, 0.30, 0.15, 0.40,
 true, true, true, true, false),

('maquillaje_xv', 'maquillaje', null,
 'Maquillaje XV Años', 'Quinceañera Makeup', '💄',
 0.35, 90, 0.80, 0.35, 0.80,
 'next_week', true, 25.0, true, 3.0, 2,
 0.10, 0.10, 0.30, 0.15, 0.35,
 true, true, true, false, false),

('maquillaje_editorial', 'maquillaje', null,
 'Maquillaje Editorial/Fotográfico', 'Editorial/Photographic Makeup', '💄',
 0.20, 90, 0.90, 0.45, 0.90,
 'next_week', true, 30.0, true, 3.0, 2,
 0.05, 0.10, 0.25, 0.15, 0.45,
 true, true, true, true, false),

('clase_automaquillaje', 'maquillaje', null,
 'Clase de Automaquillaje', 'Self-Makeup Class', '💄',
 0.25, 120, 0.70, 0.35, 0.30,
 'next_week', false, 20.0, true, 3.0, 0,
 0.15, 0.15, 0.30, 0.25, 0.15,
 true, false, true, false, false),

('prueba_maquillaje', 'maquillaje', null,
 'Prueba de Maquillaje', 'Makeup Trial', '💄',
 0.35, 60, 0.75, 0.30, 0.70,
 'next_week', true, 20.0, true, 3.0, 1,
 0.10, 0.15, 0.25, 0.15, 0.35,
 true, true, true, false, false),

-- ═══════════════════════════════════════════════════════════════════════════════
-- FACIAL > Limpieza
-- ═══════════════════════════════════════════════════════════════════════════════
('limpieza_facial_basica', 'facial', 'limpieza',
 'Limpieza Facial Básica', 'Basic Facial Cleansing', '💆',
 0.75, 45, 0.25, 0.20, 0.00,
 'next_day', false, 8.0, true, 3.0, 0,
 0.40, 0.25, 0.20, 0.15, 0.00,
 false, false, false, false, true),

('limpieza_facial_profunda', 'facial', 'limpieza',
 'Limpieza Facial Profunda', 'Deep Facial Cleansing', '💆',
 0.65, 60, 0.40, 0.25, 0.00,
 'next_day', false, 10.0, true, 3.0, 0,
 0.35, 0.25, 0.25, 0.15, 0.00,
 false, false, false, false, true),

('hidrafacial', 'facial', 'limpieza',
 'Hidrafacial', 'Hydrafacial', '💆',
 0.45, 60, 0.55, 0.35, 0.10,
 'this_week', false, 15.0, true, 3.0, 0,
 0.25, 0.20, 0.25, 0.20, 0.10,
 true, false, true, true, false),

-- ═══════════════════════════════════════════════════════════════════════════════
-- FACIAL > Direct children
-- ═══════════════════════════════════════════════════════════════════════════════
('anti_edad', 'facial', null,
 'Tratamiento Anti-Edad', 'Anti-Aging Treatment', '💆',
 0.40, 75, 0.65, 0.35, 0.10,
 'this_week', false, 15.0, true, 3.0, 0,
 0.20, 0.15, 0.30, 0.25, 0.10,
 true, false, true, true, false),

('anti_acne', 'facial', null,
 'Tratamiento Anti-Acné', 'Anti-Acne Treatment', '💆',
 0.45, 60, 0.60, 0.30, 0.05,
 'this_week', false, 15.0, true, 3.0, 0,
 0.25, 0.20, 0.30, 0.20, 0.05,
 true, false, true, true, false),

('microdermoabrasion', 'facial', null,
 'Microdermoabrasión', 'Microdermabrasion', '💆',
 0.40, 50, 0.60, 0.30, 0.10,
 'this_week', false, 15.0, true, 3.0, 0,
 0.20, 0.20, 0.30, 0.20, 0.10,
 true, false, true, true, false),

('dermapen_microneedling', 'facial', null,
 'Dermapen/Microneedling', 'Dermapen/Microneedling', '💆',
 0.30, 60, 0.80, 0.35, 0.30,
 'this_week', false, 20.0, true, 3.0, 0,
 0.15, 0.15, 0.30, 0.20, 0.20,
 true, true, true, true, false),

('peeling_quimico', 'facial', null,
 'Peeling Químico', 'Chemical Peel', '💆',
 0.35, 45, 0.75, 0.30, 0.20,
 'this_week', false, 18.0, true, 3.0, 0,
 0.15, 0.15, 0.30, 0.20, 0.20,
 true, false, true, true, false),

('radiofrecuencia_facial', 'facial', null,
 'Radiofrecuencia Facial', 'Facial Radiofrequency', '💆',
 0.35, 50, 0.65, 0.35, 0.10,
 'this_week', false, 15.0, true, 3.0, 0,
 0.20, 0.15, 0.30, 0.25, 0.10,
 true, false, true, true, false),

('led_terapia', 'facial', null,
 'LED Terapia', 'LED Therapy', '💆',
 0.40, 30, 0.45, 0.25, 0.00,
 'this_week', false, 12.0, true, 3.0, 0,
 0.30, 0.25, 0.25, 0.20, 0.00,
 true, false, false, true, false),

('mascarilla_especializada', 'facial', null,
 'Mascarilla Especializada', 'Specialized Mask', '💆',
 0.55, 45, 0.35, 0.25, 0.00,
 'next_day', false, 10.0, true, 3.0, 0,
 0.35, 0.25, 0.20, 0.20, 0.00,
 false, false, false, false, true),

-- ═══════════════════════════════════════════════════════════════════════════════
-- CUERPO Y SPA > Masaje
-- ═══════════════════════════════════════════════════════════════════════════════
('masaje_relajante', 'cuerpo_spa', 'masaje',
 'Masaje Relajante', 'Relaxation Massage', '🧖',
 0.70, 60, 0.30, 0.25, 0.00,
 'next_day', false, 10.0, true, 3.0, 0,
 0.35, 0.30, 0.20, 0.15, 0.00,
 false, false, false, false, true),

('masaje_descontracturante', 'cuerpo_spa', 'masaje',
 'Masaje Descontracturante/Deportivo', 'Deep Tissue/Sports Massage', '🧖',
 0.55, 60, 0.50, 0.25, 0.00,
 'next_day', false, 12.0, true, 3.0, 0,
 0.30, 0.25, 0.25, 0.20, 0.00,
 false, false, true, true, false),

('masaje_piedras_calientes', 'cuerpo_spa', 'masaje',
 'Masaje Piedras Calientes', 'Hot Stone Massage', '🧖',
 0.45, 75, 0.40, 0.30, 0.00,
 'next_day', false, 12.0, true, 3.0, 0,
 0.30, 0.25, 0.25, 0.20, 0.00,
 true, false, false, false, false),

('masaje_prenatal', 'cuerpo_spa', 'masaje',
 'Masaje Prenatal', 'Prenatal Massage', '🧖',
 0.35, 60, 0.70, 0.25, 0.00,
 'this_week', false, 15.0, true, 3.0, 0,
 0.25, 0.20, 0.35, 0.20, 0.00,
 true, false, true, true, false),

('reflexologia', 'cuerpo_spa', 'masaje',
 'Reflexología', 'Reflexology', '🧖',
 0.40, 50, 0.50, 0.25, 0.00,
 'next_day', false, 12.0, true, 3.0, 0,
 0.30, 0.25, 0.25, 0.20, 0.00,
 false, false, true, true, false),

('drenaje_linfatico', 'cuerpo_spa', 'masaje',
 'Drenaje Linfático', 'Lymphatic Drainage', '🧖',
 0.40, 60, 0.60, 0.30, 0.00,
 'this_week', false, 15.0, true, 3.0, 0,
 0.25, 0.20, 0.30, 0.25, 0.00,
 true, false, true, true, false),

-- ═══════════════════════════════════════════════════════════════════════════════
-- CUERPO Y SPA > Depilación
-- ═══════════════════════════════════════════════════════════════════════════════
('depilacion_cera', 'cuerpo_spa', 'depilacion',
 'Depilación con Cera', 'Waxing', '🧖',
 0.75, 30, 0.25, 0.20, 0.00,
 'same_day', false, 8.0, true, 3.0, 1,
 0.40, 0.25, 0.20, 0.15, 0.00,
 false, false, false, false, true),

('depilacion_laser', 'cuerpo_spa', 'depilacion',
 'Depilación Láser', 'Laser Hair Removal', '🧖',
 0.40, 45, 0.60, 0.35, 0.10,
 'this_week', false, 15.0, true, 3.0, 1,
 0.25, 0.20, 0.25, 0.20, 0.10,
 true, false, true, true, false),

('depilacion_hilo', 'cuerpo_spa', 'depilacion',
 'Depilación con Hilo/Threading', 'Threading', '🧖',
 0.55, 20, 0.35, 0.15, 0.00,
 'same_day', false, 10.0, true, 3.0, 0,
 0.40, 0.25, 0.20, 0.15, 0.00,
 false, false, false, false, true),

('depilacion_sugaring', 'cuerpo_spa', 'depilacion',
 'Sugaring', 'Sugaring', '🧖',
 0.40, 35, 0.35, 0.20, 0.00,
 'same_day', false, 12.0, true, 3.0, 1,
 0.35, 0.25, 0.25, 0.15, 0.00,
 false, false, false, false, true),

-- ═══════════════════════════════════════════════════════════════════════════════
-- CUERPO Y SPA > Tratamiento Corporal
-- ═══════════════════════════════════════════════════════════════════════════════
('exfoliacion_corporal', 'cuerpo_spa', 'tratamiento_corporal',
 'Exfoliación Corporal', 'Body Exfoliation', '🧖',
 0.55, 50, 0.25, 0.25, 0.00,
 'next_day', false, 10.0, true, 3.0, 0,
 0.35, 0.25, 0.20, 0.20, 0.00,
 false, false, false, false, true),

('envolvimiento_corporal', 'cuerpo_spa', 'tratamiento_corporal',
 'Envolvimiento Corporal', 'Body Wrap', '🧖',
 0.40, 75, 0.30, 0.30, 0.00,
 'next_day', false, 12.0, true, 3.0, 0,
 0.30, 0.25, 0.20, 0.25, 0.00,
 true, false, false, false, false),

('radiofrecuencia_corporal', 'cuerpo_spa', 'tratamiento_corporal',
 'Radiofrecuencia Corporal', 'Body Radiofrequency', '🧖',
 0.35, 50, 0.55, 0.35, 0.10,
 'this_week', false, 15.0, true, 3.0, 0,
 0.20, 0.20, 0.25, 0.25, 0.10,
 true, false, true, true, false),

('cavitacion', 'cuerpo_spa', 'tratamiento_corporal',
 'Cavitación', 'Cavitation', '🧖',
 0.35, 50, 0.50, 0.30, 0.10,
 'this_week', false, 15.0, true, 3.0, 0,
 0.20, 0.20, 0.25, 0.25, 0.10,
 true, false, true, true, false),

('mesoterapia', 'cuerpo_spa', 'tratamiento_corporal',
 'Mesoterapia', 'Mesotherapy', '🧖',
 0.30, 45, 0.65, 0.35, 0.10,
 'this_week', false, 18.0, true, 3.0, 0,
 0.15, 0.15, 0.30, 0.25, 0.15,
 true, false, true, true, false),

-- ═══════════════════════════════════════════════════════════════════════════════
-- CUERPO Y SPA > Bronceado
-- ═══════════════════════════════════════════════════════════════════════════════
('spray_tan', 'cuerpo_spa', 'bronceado',
 'Spray Tan', 'Spray Tan', '🧖',
 0.30, 30, 0.40, 0.25, 0.30,
 'this_week', false, 15.0, true, 3.0, 0,
 0.20, 0.20, 0.25, 0.20, 0.15,
 true, true, false, false, false),

('cama_bronceado', 'cuerpo_spa', 'bronceado',
 'Cama de Bronceado', 'Tanning Bed', '🧖',
 0.35, 20, 0.20, 0.20, 0.00,
 'same_day', false, 12.0, true, 3.0, 0,
 0.35, 0.30, 0.15, 0.20, 0.00,
 false, false, false, false, true),

-- ═══════════════════════════════════════════════════════════════════════════════
-- CUIDADO ESPECIALIZADO
-- ═══════════════════════════════════════════════════════════════════════════════
('micropigmentacion_labios', 'cuidado_especializado', null,
 'Micropigmentación de Labios', 'Lip Micropigmentation', '💋',
 0.20, 120, 0.95, 0.40, 0.95,
 'next_week', false, 30.0, true, 3.0, 1,
 0.05, 0.10, 0.25, 0.15, 0.45,
 true, true, true, true, false),

('remocion_tatuajes', 'cuidado_especializado', null,
 'Remoción de Tatuajes', 'Tattoo Removal', '🧴',
 0.20, 45, 0.85, 0.40, 0.30,
 'next_week', false, 30.0, true, 3.0, 0,
 0.10, 0.10, 0.30, 0.20, 0.30,
 true, true, true, true, false),

('blanqueamiento_dental', 'cuidado_especializado', null,
 'Blanqueamiento Dental', 'Teeth Whitening', '🦷',
 0.35, 60, 0.55, 0.30, 0.20,
 'this_week', false, 15.0, true, 3.0, 0,
 0.20, 0.20, 0.25, 0.20, 0.15,
 true, false, true, true, false),

-- Barbería Premium
('barberia_corte_barba', 'cuidado_especializado', 'barberia_premium',
 'Corte + Barba', 'Haircut + Beard', '🧔',
 0.70, 50, 0.40, 0.25, 0.10,
 'same_day', false, 8.0, true, 3.0, 0,
 0.35, 0.25, 0.25, 0.15, 0.00,
 false, false, false, false, true),

('barberia_afeitado_clasico', 'cuidado_especializado', 'barberia_premium',
 'Afeitado Clásico', 'Classic Shave', '🧔',
 0.60, 30, 0.35, 0.20, 0.00,
 'same_day', false, 8.0, true, 3.0, 0,
 0.40, 0.25, 0.20, 0.15, 0.00,
 false, false, false, false, true),

('barberia_diseno_barba', 'cuidado_especializado', 'barberia_premium',
 'Diseño de Barba', 'Beard Design', '🧔',
 0.55, 35, 0.50, 0.25, 0.20,
 'same_day', false, 10.0, true, 3.0, 0,
 0.30, 0.25, 0.25, 0.15, 0.05,
 false, false, true, false, true),

('barberia_tratamiento_barba', 'cuidado_especializado', 'barberia_premium',
 'Tratamiento de Barba', 'Beard Treatment', '🧔',
 0.45, 40, 0.40, 0.25, 0.00,
 'next_day', false, 10.0, true, 3.0, 0,
 0.35, 0.25, 0.25, 0.15, 0.00,
 false, false, false, false, true),

-- Consulta Virtual
('consulta_virtual', 'cuidado_especializado', null,
 'Consulta Virtual', 'Virtual Consultation', '💻',
 0.50, 30, 0.50, 0.20, 0.00,
 'next_day', false, 999.0, false, 1.0, 0,
 0.00, 0.30, 0.35, 0.35, 0.00,
 true, false, true, false, false);


-- =============================================================================
-- 3. SERVICE CATEGORIES TREE (~130 rows)
-- Complete category tree matching Section 3 of the design document.
-- Uses deterministic UUIDs: 00000000-0000-4000-8000-0000000000XX
-- Depth 0 = top-level, Depth 1 = subcategory, Depth 2 = leaf service
-- Leaf nodes link to service_profiles via service_type
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- Depth 0: Top-level categories
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO service_categories_tree (id, parent_id, slug, display_name_es, display_name_en, icon, sort_order, depth, is_leaf, service_type, is_active) VALUES
('00000000-0000-4000-8000-000000000001', null, 'unas', 'Uñas', 'Nails', '💅', 0, 0, false, null, true),
('00000000-0000-4000-8000-000000000002', null, 'cabello', 'Cabello', 'Hair', '✂️', 1, 0, false, null, true),
('00000000-0000-4000-8000-000000000003', null, 'pestanas_cejas', 'Pestañas y Cejas', 'Lashes & Brows', '👁️', 2, 0, false, null, true),
('00000000-0000-4000-8000-000000000004', null, 'maquillaje', 'Maquillaje', 'Makeup', '💄', 3, 0, false, null, true),
('00000000-0000-4000-8000-000000000005', null, 'facial', 'Facial', 'Facial', '💆', 4, 0, false, null, true),
('00000000-0000-4000-8000-000000000006', null, 'cuerpo_spa', 'Cuerpo y Spa', 'Body & Spa', '🧖', 5, 0, false, null, true),
('00000000-0000-4000-8000-000000000007', null, 'cuidado_especializado', 'Cuidado Especializado', 'Specialized Care', '🧴', 6, 0, false, null, true);

-- ─────────────────────────────────────────────────────────────────────────────
-- Depth 1: Subcategories
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO service_categories_tree (id, parent_id, slug, display_name_es, display_name_en, icon, sort_order, depth, is_leaf, service_type, is_active) VALUES
-- Uñas subcategories
('00000000-0000-4000-8000-000000000010', '00000000-0000-4000-8000-000000000001', 'manicure', 'Manicure', 'Manicure', '💅', 0, 1, false, null, true),
('00000000-0000-4000-8000-000000000011', '00000000-0000-4000-8000-000000000001', 'pedicure', 'Pedicure', 'Pedicure', '🦶', 1, 1, false, null, true),
-- Cabello subcategories
('00000000-0000-4000-8000-000000000012', '00000000-0000-4000-8000-000000000002', 'corte', 'Corte', 'Haircut', '✂️', 0, 1, false, null, true),
('00000000-0000-4000-8000-000000000013', '00000000-0000-4000-8000-000000000002', 'color', 'Color', 'Color', '🎨', 1, 1, false, null, true),
('00000000-0000-4000-8000-000000000014', '00000000-0000-4000-8000-000000000002', 'tratamiento_cabello', 'Tratamiento', 'Treatment', '✨', 2, 1, false, null, true),
('00000000-0000-4000-8000-000000000015', '00000000-0000-4000-8000-000000000002', 'peinado', 'Peinado', 'Hairstyle', '💇', 3, 1, false, null, true),
('00000000-0000-4000-8000-000000000016', '00000000-0000-4000-8000-000000000002', 'extensiones_cabello', 'Extensiones', 'Extensions', '💇', 4, 1, false, null, true),
-- Pestañas y Cejas subcategories
('00000000-0000-4000-8000-000000000017', '00000000-0000-4000-8000-000000000003', 'pestanas', 'Pestañas', 'Lashes', '👁️', 0, 1, false, null, true),
('00000000-0000-4000-8000-000000000018', '00000000-0000-4000-8000-000000000003', 'cejas', 'Cejas', 'Brows', '🪒', 1, 1, false, null, true),
-- Facial subcategories
('00000000-0000-4000-8000-000000000019', '00000000-0000-4000-8000-000000000005', 'limpieza_facial', 'Limpieza Facial', 'Facial Cleansing', '💆', 0, 1, false, null, true),
-- Cuerpo y Spa subcategories
('00000000-0000-4000-8000-000000000020', '00000000-0000-4000-8000-000000000006', 'masaje', 'Masaje', 'Massage', '🧖', 0, 1, false, null, true),
('00000000-0000-4000-8000-000000000021', '00000000-0000-4000-8000-000000000006', 'depilacion', 'Depilación', 'Hair Removal', '🧖', 1, 1, false, null, true),
('00000000-0000-4000-8000-000000000022', '00000000-0000-4000-8000-000000000006', 'tratamiento_corporal', 'Tratamiento Corporal', 'Body Treatment', '🧖', 2, 1, false, null, true),
('00000000-0000-4000-8000-000000000023', '00000000-0000-4000-8000-000000000006', 'bronceado', 'Bronceado', 'Tanning', '☀️', 3, 1, false, null, true),
-- Cuidado Especializado subcategories
('00000000-0000-4000-8000-000000000024', '00000000-0000-4000-8000-000000000007', 'barberia_premium', 'Barbería Premium', 'Premium Barber', '🧔', 0, 1, false, null, true);

-- ─────────────────────────────────────────────────────────────────────────────
-- Depth 2: Leaf nodes (Uñas > Manicure)
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO service_categories_tree (id, parent_id, slug, display_name_es, display_name_en, icon, sort_order, depth, is_leaf, service_type, is_active) VALUES
('00000000-0000-4000-8000-000000000100', '00000000-0000-4000-8000-000000000010', 'manicure_clasico', 'Clásico/Básico', 'Classic', '💅', 0, 2, true, 'manicure_clasico', true),
('00000000-0000-4000-8000-000000000101', '00000000-0000-4000-8000-000000000010', 'manicure_gel', 'Gel', 'Gel', '💅', 1, 2, true, 'manicure_gel', true),
('00000000-0000-4000-8000-000000000102', '00000000-0000-4000-8000-000000000010', 'manicure_frances', 'Francés', 'French', '💅', 2, 2, true, 'manicure_frances', true),
('00000000-0000-4000-8000-000000000103', '00000000-0000-4000-8000-000000000010', 'manicure_dip_powder', 'Dip Powder', 'Dip Powder', '💅', 3, 2, true, 'manicure_dip_powder', true),
('00000000-0000-4000-8000-000000000104', '00000000-0000-4000-8000-000000000010', 'manicure_acrilico', 'Acrílico', 'Acrylic', '💅', 4, 2, true, 'manicure_acrilico', true),
('00000000-0000-4000-8000-000000000105', '00000000-0000-4000-8000-000000000010', 'manicure_spa_luxury', 'Spa/Luxury', 'Spa/Luxury', '💅', 5, 2, true, 'manicure_spa_luxury', true),
('00000000-0000-4000-8000-000000000106', '00000000-0000-4000-8000-000000000010', 'manicure_japones', 'Japonés', 'Japanese', '💅', 6, 2, true, 'manicure_japones', true),
('00000000-0000-4000-8000-000000000107', '00000000-0000-4000-8000-000000000010', 'manicure_parafina', 'Parafina', 'Paraffin', '💅', 7, 2, true, 'manicure_parafina', true),
('00000000-0000-4000-8000-000000000108', '00000000-0000-4000-8000-000000000010', 'manicure_ruso', 'Ruso', 'Russian', '💅', 8, 2, true, 'manicure_ruso', true);

-- Depth 2: Leaf nodes (Uñas > Pedicure)
INSERT INTO service_categories_tree (id, parent_id, slug, display_name_es, display_name_en, icon, sort_order, depth, is_leaf, service_type, is_active) VALUES
('00000000-0000-4000-8000-000000000110', '00000000-0000-4000-8000-000000000011', 'pedicure_clasico', 'Clásico/Básico', 'Classic', '🦶', 0, 2, true, 'pedicure_clasico', true),
('00000000-0000-4000-8000-000000000111', '00000000-0000-4000-8000-000000000011', 'pedicure_spa_luxury', 'Spa/Luxury', 'Spa/Luxury', '🦶', 1, 2, true, 'pedicure_spa_luxury', true),
('00000000-0000-4000-8000-000000000112', '00000000-0000-4000-8000-000000000011', 'pedicure_gel', 'Gel', 'Gel', '🦶', 2, 2, true, 'pedicure_gel', true),
('00000000-0000-4000-8000-000000000113', '00000000-0000-4000-8000-000000000011', 'pedicure_medico', 'Médico', 'Medical', '🦶', 3, 2, true, 'pedicure_medico', true),
('00000000-0000-4000-8000-000000000114', '00000000-0000-4000-8000-000000000011', 'pedicure_parafina', 'Parafina', 'Paraffin', '🦶', 4, 2, true, 'pedicure_parafina', true);

-- Depth 2: Leaf nodes (Uñas > direct children, no subcategory)
INSERT INTO service_categories_tree (id, parent_id, slug, display_name_es, display_name_en, icon, sort_order, depth, is_leaf, service_type, is_active) VALUES
('00000000-0000-4000-8000-000000000120', '00000000-0000-4000-8000-000000000001', 'nail_art', 'Nail Art', 'Nail Art', '🎨', 2, 1, true, 'nail_art', true),
('00000000-0000-4000-8000-000000000121', '00000000-0000-4000-8000-000000000001', 'cambio_esmalte', 'Cambio de Esmalte', 'Polish Change', '💅', 3, 1, true, 'cambio_esmalte', true),
('00000000-0000-4000-8000-000000000122', '00000000-0000-4000-8000-000000000001', 'reparacion_una', 'Reparación de Uña', 'Nail Repair', '🔧', 4, 1, true, 'reparacion_una', true),
('00000000-0000-4000-8000-000000000123', '00000000-0000-4000-8000-000000000001', 'relleno_acrilico_gel', 'Relleno (Acrílico/Gel)', 'Fill-In (Acrylic/Gel)', '💅', 5, 1, true, 'relleno_acrilico_gel', true),
('00000000-0000-4000-8000-000000000124', '00000000-0000-4000-8000-000000000001', 'retiro_acrilico_gel_dip', 'Retiro (Acrílico/Gel/Dip)', 'Removal (Acrylic/Gel/Dip)', '💅', 6, 1, true, 'retiro_acrilico_gel_dip', true);

-- Depth 2: Leaf nodes (Cabello > Corte)
INSERT INTO service_categories_tree (id, parent_id, slug, display_name_es, display_name_en, icon, sort_order, depth, is_leaf, service_type, is_active) VALUES
('00000000-0000-4000-8000-000000000130', '00000000-0000-4000-8000-000000000012', 'corte_mujer', 'Mujer', 'Women''s', '✂️', 0, 2, true, 'corte_mujer', true),
('00000000-0000-4000-8000-000000000131', '00000000-0000-4000-8000-000000000012', 'corte_hombre', 'Hombre', 'Men''s', '✂️', 1, 2, true, 'corte_hombre', true),
('00000000-0000-4000-8000-000000000132', '00000000-0000-4000-8000-000000000012', 'corte_nino', 'Niño/a', 'Kids', '✂️', 2, 2, true, 'corte_nino', true);

-- Depth 2: Leaf nodes (Cabello > Color)
INSERT INTO service_categories_tree (id, parent_id, slug, display_name_es, display_name_en, icon, sort_order, depth, is_leaf, service_type, is_active) VALUES
('00000000-0000-4000-8000-000000000140', '00000000-0000-4000-8000-000000000013', 'tinte_completo', 'Tinte Completo', 'Full Color', '🎨', 0, 2, true, 'tinte_completo', true),
('00000000-0000-4000-8000-000000000141', '00000000-0000-4000-8000-000000000013', 'retoque_raiz', 'Retoque de Raíz', 'Root Touch-Up', '🎨', 1, 2, true, 'retoque_raiz', true),
('00000000-0000-4000-8000-000000000142', '00000000-0000-4000-8000-000000000013', 'mechas_highlights', 'Mechas/Highlights', 'Highlights', '🎨', 2, 2, true, 'mechas_highlights', true),
('00000000-0000-4000-8000-000000000143', '00000000-0000-4000-8000-000000000013', 'balayage', 'Balayage', 'Balayage', '🎨', 3, 2, true, 'balayage', true),
('00000000-0000-4000-8000-000000000144', '00000000-0000-4000-8000-000000000013', 'ombre', 'Ombré', 'Ombré', '🎨', 4, 2, true, 'ombre', true),
('00000000-0000-4000-8000-000000000145', '00000000-0000-4000-8000-000000000013', 'correccion_color', 'Corrección de Color', 'Color Correction', '🎨', 5, 2, true, 'correccion_color', true),
('00000000-0000-4000-8000-000000000146', '00000000-0000-4000-8000-000000000013', 'decoloracion', 'Decoloración', 'Bleaching', '🎨', 6, 2, true, 'decoloracion', true);

-- Depth 2: Leaf nodes (Cabello > Tratamiento)
INSERT INTO service_categories_tree (id, parent_id, slug, display_name_es, display_name_en, icon, sort_order, depth, is_leaf, service_type, is_active) VALUES
('00000000-0000-4000-8000-000000000150', '00000000-0000-4000-8000-000000000014', 'keratina_alisado', 'Keratina/Alisado', 'Keratin/Straightening', '✨', 0, 2, true, 'keratina_alisado', true),
('00000000-0000-4000-8000-000000000151', '00000000-0000-4000-8000-000000000014', 'botox_capilar', 'Botox Capilar', 'Hair Botox', '✨', 1, 2, true, 'botox_capilar', true),
('00000000-0000-4000-8000-000000000152', '00000000-0000-4000-8000-000000000014', 'hidratacion_profunda', 'Hidratación Profunda', 'Deep Conditioning', '✨', 2, 2, true, 'hidratacion_profunda', true),
('00000000-0000-4000-8000-000000000153', '00000000-0000-4000-8000-000000000014', 'olaplex_reconstructor', 'Olaplex/Reconstructor', 'Olaplex/Reconstruction', '✨', 3, 2, true, 'olaplex_reconstructor', true),
('00000000-0000-4000-8000-000000000154', '00000000-0000-4000-8000-000000000014', 'tratamiento_anticaida', 'Tratamiento Anticaída', 'Hair Loss Treatment', '✨', 4, 2, true, 'tratamiento_anticaida', true);

-- Depth 2: Leaf nodes (Cabello > Peinado)
INSERT INTO service_categories_tree (id, parent_id, slug, display_name_es, display_name_en, icon, sort_order, depth, is_leaf, service_type, is_active) VALUES
('00000000-0000-4000-8000-000000000160', '00000000-0000-4000-8000-000000000015', 'blowout_secado', 'Blowout/Secado', 'Blowout', '💇', 0, 2, true, 'blowout_secado', true),
('00000000-0000-4000-8000-000000000161', '00000000-0000-4000-8000-000000000015', 'planchado', 'Planchado', 'Flat Iron', '💇', 1, 2, true, 'planchado', true),
('00000000-0000-4000-8000-000000000162', '00000000-0000-4000-8000-000000000015', 'ondas_rizos', 'Ondas/Rizos', 'Waves/Curls', '💇', 2, 2, true, 'ondas_rizos', true),
('00000000-0000-4000-8000-000000000163', '00000000-0000-4000-8000-000000000015', 'recogido_evento', 'Recogido (Evento)', 'Updo (Event)', '💇', 3, 2, true, 'recogido_evento', true),
('00000000-0000-4000-8000-000000000164', '00000000-0000-4000-8000-000000000015', 'trenzas', 'Trenzas', 'Braids', '💇', 4, 2, true, 'trenzas', true);

-- Depth 2: Leaf nodes (Cabello > Extensiones)
INSERT INTO service_categories_tree (id, parent_id, slug, display_name_es, display_name_en, icon, sort_order, depth, is_leaf, service_type, is_active) VALUES
('00000000-0000-4000-8000-000000000170', '00000000-0000-4000-8000-000000000016', 'ext_clip_in', 'Clip-In', 'Clip-In', '💇', 0, 2, true, 'ext_clip_in', true),
('00000000-0000-4000-8000-000000000171', '00000000-0000-4000-8000-000000000016', 'ext_cosidas', 'Cosidas', 'Sew-In', '💇', 1, 2, true, 'ext_cosidas', true),
('00000000-0000-4000-8000-000000000172', '00000000-0000-4000-8000-000000000016', 'ext_fusion_keratina', 'Fusión/Keratina', 'Fusion/Keratin', '💇', 2, 2, true, 'ext_fusion_keratina', true),
('00000000-0000-4000-8000-000000000173', '00000000-0000-4000-8000-000000000016', 'ext_cinta_tape_in', 'Cinta/Tape-In', 'Tape-In', '💇', 3, 2, true, 'ext_cinta_tape_in', true);

-- Depth 2: Leaf nodes (Pestañas y Cejas > Pestañas)
INSERT INTO service_categories_tree (id, parent_id, slug, display_name_es, display_name_en, icon, sort_order, depth, is_leaf, service_type, is_active) VALUES
('00000000-0000-4000-8000-000000000180', '00000000-0000-4000-8000-000000000017', 'ext_pestanas_clasicas', 'Extensiones Clásicas', 'Classic Extensions', '👁️', 0, 2, true, 'ext_pestanas_clasicas', true),
('00000000-0000-4000-8000-000000000181', '00000000-0000-4000-8000-000000000017', 'ext_pestanas_hibridas', 'Extensiones Híbridas', 'Hybrid Extensions', '👁️', 1, 2, true, 'ext_pestanas_hibridas', true),
('00000000-0000-4000-8000-000000000182', '00000000-0000-4000-8000-000000000017', 'ext_pestanas_volumen', 'Extensiones Volumen', 'Volume Extensions', '👁️', 2, 2, true, 'ext_pestanas_volumen', true),
('00000000-0000-4000-8000-000000000183', '00000000-0000-4000-8000-000000000017', 'ext_pestanas_mega_volumen', 'Mega Volumen', 'Mega Volume', '👁️', 3, 2, true, 'ext_pestanas_mega_volumen', true),
('00000000-0000-4000-8000-000000000184', '00000000-0000-4000-8000-000000000017', 'lifting_pestanas', 'Lifting de Pestañas', 'Lash Lift', '👁️', 4, 2, true, 'lifting_pestanas', true),
('00000000-0000-4000-8000-000000000185', '00000000-0000-4000-8000-000000000017', 'tinte_pestanas', 'Tinte de Pestañas', 'Lash Tint', '👁️', 5, 2, true, 'tinte_pestanas', true),
('00000000-0000-4000-8000-000000000186', '00000000-0000-4000-8000-000000000017', 'relleno_pestanas', 'Relleno (2-3 semanas)', 'Fill (2-3 weeks)', '👁️', 6, 2, true, 'relleno_pestanas', true),
('00000000-0000-4000-8000-000000000187', '00000000-0000-4000-8000-000000000017', 'retiro_pestanas', 'Retiro', 'Removal', '👁️', 7, 2, true, 'retiro_pestanas', true);

-- Depth 2: Leaf nodes (Pestañas y Cejas > Cejas)
INSERT INTO service_categories_tree (id, parent_id, slug, display_name_es, display_name_en, icon, sort_order, depth, is_leaf, service_type, is_active) VALUES
('00000000-0000-4000-8000-000000000190', '00000000-0000-4000-8000-000000000018', 'diseno_depilacion_cejas', 'Diseño/Depilación', 'Shaping/Waxing', '🪒', 0, 2, true, 'diseno_depilacion_cejas', true),
('00000000-0000-4000-8000-000000000191', '00000000-0000-4000-8000-000000000018', 'microblading', 'Microblading', 'Microblading', '🪒', 1, 2, true, 'microblading', true),
('00000000-0000-4000-8000-000000000192', '00000000-0000-4000-8000-000000000018', 'micropigmentacion_cejas', 'Micropigmentación', 'Micropigmentation', '🪒', 2, 2, true, 'micropigmentacion_cejas', true),
('00000000-0000-4000-8000-000000000193', '00000000-0000-4000-8000-000000000018', 'laminado_cejas', 'Laminado de Cejas', 'Brow Lamination', '🪒', 3, 2, true, 'laminado_cejas', true),
('00000000-0000-4000-8000-000000000194', '00000000-0000-4000-8000-000000000018', 'tinte_cejas', 'Tinte de Cejas', 'Brow Tint', '🪒', 4, 2, true, 'tinte_cejas', true),
('00000000-0000-4000-8000-000000000195', '00000000-0000-4000-8000-000000000018', 'henna_cejas', 'Henna', 'Henna', '🪒', 5, 2, true, 'henna_cejas', true);

-- Depth 1: Leaf node (Pestañas y Cejas > Combo, direct child)
INSERT INTO service_categories_tree (id, parent_id, slug, display_name_es, display_name_en, icon, sort_order, depth, is_leaf, service_type, is_active) VALUES
('00000000-0000-4000-8000-000000000196', '00000000-0000-4000-8000-000000000003', 'combo_pestanas_cejas', 'Combo Pestañas + Cejas', 'Lash + Brow Combo', '👁️', 2, 1, true, 'combo_pestanas_cejas', true);

-- Depth 1: Leaf nodes (Maquillaje, direct children — no subcategories)
INSERT INTO service_categories_tree (id, parent_id, slug, display_name_es, display_name_en, icon, sort_order, depth, is_leaf, service_type, is_active) VALUES
('00000000-0000-4000-8000-000000000200', '00000000-0000-4000-8000-000000000004', 'maquillaje_social', 'Social/Casual', 'Social/Casual', '💄', 0, 1, true, 'maquillaje_social', true),
('00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000004', 'maquillaje_evento', 'Evento/Fiesta', 'Event/Party', '💄', 1, 1, true, 'maquillaje_evento', true),
('00000000-0000-4000-8000-000000000202', '00000000-0000-4000-8000-000000000004', 'maquillaje_novia', 'Novia', 'Bridal', '💄', 2, 1, true, 'maquillaje_novia', true),
('00000000-0000-4000-8000-000000000203', '00000000-0000-4000-8000-000000000004', 'maquillaje_xv', 'XV Años', 'Quinceañera', '💄', 3, 1, true, 'maquillaje_xv', true),
('00000000-0000-4000-8000-000000000204', '00000000-0000-4000-8000-000000000004', 'maquillaje_editorial', 'Editorial/Fotográfico', 'Editorial/Photographic', '💄', 4, 1, true, 'maquillaje_editorial', true),
('00000000-0000-4000-8000-000000000205', '00000000-0000-4000-8000-000000000004', 'clase_automaquillaje', 'Clase de Automaquillaje', 'Self-Makeup Class', '💄', 5, 1, true, 'clase_automaquillaje', true),
('00000000-0000-4000-8000-000000000206', '00000000-0000-4000-8000-000000000004', 'prueba_maquillaje', 'Prueba de Maquillaje', 'Makeup Trial', '💄', 6, 1, true, 'prueba_maquillaje', true);

-- Depth 2: Leaf nodes (Facial > Limpieza)
INSERT INTO service_categories_tree (id, parent_id, slug, display_name_es, display_name_en, icon, sort_order, depth, is_leaf, service_type, is_active) VALUES
('00000000-0000-4000-8000-000000000210', '00000000-0000-4000-8000-000000000019', 'limpieza_facial_basica', 'Básica', 'Basic', '💆', 0, 2, true, 'limpieza_facial_basica', true),
('00000000-0000-4000-8000-000000000211', '00000000-0000-4000-8000-000000000019', 'limpieza_facial_profunda', 'Profunda', 'Deep', '💆', 1, 2, true, 'limpieza_facial_profunda', true),
('00000000-0000-4000-8000-000000000212', '00000000-0000-4000-8000-000000000019', 'hidrafacial', 'Hidrafacial', 'Hydrafacial', '💆', 2, 2, true, 'hidrafacial', true);

-- Depth 1: Leaf nodes (Facial, direct children — no subcategory)
INSERT INTO service_categories_tree (id, parent_id, slug, display_name_es, display_name_en, icon, sort_order, depth, is_leaf, service_type, is_active) VALUES
('00000000-0000-4000-8000-000000000220', '00000000-0000-4000-8000-000000000005', 'anti_edad', 'Tratamiento Anti-Edad', 'Anti-Aging Treatment', '💆', 1, 1, true, 'anti_edad', true),
('00000000-0000-4000-8000-000000000221', '00000000-0000-4000-8000-000000000005', 'anti_acne', 'Tratamiento Anti-Acné', 'Anti-Acne Treatment', '💆', 2, 1, true, 'anti_acne', true),
('00000000-0000-4000-8000-000000000222', '00000000-0000-4000-8000-000000000005', 'microdermoabrasion', 'Microdermoabrasión', 'Microdermabrasion', '💆', 3, 1, true, 'microdermoabrasion', true),
('00000000-0000-4000-8000-000000000223', '00000000-0000-4000-8000-000000000005', 'dermapen_microneedling', 'Dermapen/Microneedling', 'Dermapen/Microneedling', '💆', 4, 1, true, 'dermapen_microneedling', true),
('00000000-0000-4000-8000-000000000224', '00000000-0000-4000-8000-000000000005', 'peeling_quimico', 'Peeling Químico', 'Chemical Peel', '💆', 5, 1, true, 'peeling_quimico', true),
('00000000-0000-4000-8000-000000000225', '00000000-0000-4000-8000-000000000005', 'radiofrecuencia_facial', 'Radiofrecuencia Facial', 'Facial Radiofrequency', '💆', 6, 1, true, 'radiofrecuencia_facial', true),
('00000000-0000-4000-8000-000000000226', '00000000-0000-4000-8000-000000000005', 'led_terapia', 'LED Terapia', 'LED Therapy', '💆', 7, 1, true, 'led_terapia', true),
('00000000-0000-4000-8000-000000000227', '00000000-0000-4000-8000-000000000005', 'mascarilla_especializada', 'Mascarilla Especializada', 'Specialized Mask', '💆', 8, 1, true, 'mascarilla_especializada', true);

-- Depth 2: Leaf nodes (Cuerpo y Spa > Masaje)
INSERT INTO service_categories_tree (id, parent_id, slug, display_name_es, display_name_en, icon, sort_order, depth, is_leaf, service_type, is_active) VALUES
('00000000-0000-4000-8000-000000000230', '00000000-0000-4000-8000-000000000020', 'masaje_relajante', 'Relajante', 'Relaxation', '🧖', 0, 2, true, 'masaje_relajante', true),
('00000000-0000-4000-8000-000000000231', '00000000-0000-4000-8000-000000000020', 'masaje_descontracturante', 'Descontracturante/Deportivo', 'Deep Tissue/Sports', '🧖', 1, 2, true, 'masaje_descontracturante', true),
('00000000-0000-4000-8000-000000000232', '00000000-0000-4000-8000-000000000020', 'masaje_piedras_calientes', 'Piedras Calientes', 'Hot Stones', '🧖', 2, 2, true, 'masaje_piedras_calientes', true),
('00000000-0000-4000-8000-000000000233', '00000000-0000-4000-8000-000000000020', 'masaje_prenatal', 'Prenatal', 'Prenatal', '🧖', 3, 2, true, 'masaje_prenatal', true),
('00000000-0000-4000-8000-000000000234', '00000000-0000-4000-8000-000000000020', 'reflexologia', 'Reflexología', 'Reflexology', '🧖', 4, 2, true, 'reflexologia', true),
('00000000-0000-4000-8000-000000000235', '00000000-0000-4000-8000-000000000020', 'drenaje_linfatico', 'Drenaje Linfático', 'Lymphatic Drainage', '🧖', 5, 2, true, 'drenaje_linfatico', true);

-- Depth 2: Leaf nodes (Cuerpo y Spa > Depilación)
INSERT INTO service_categories_tree (id, parent_id, slug, display_name_es, display_name_en, icon, sort_order, depth, is_leaf, service_type, is_active) VALUES
('00000000-0000-4000-8000-000000000240', '00000000-0000-4000-8000-000000000021', 'depilacion_cera', 'Cera', 'Waxing', '🧖', 0, 2, true, 'depilacion_cera', true),
('00000000-0000-4000-8000-000000000241', '00000000-0000-4000-8000-000000000021', 'depilacion_laser', 'Láser', 'Laser', '🧖', 1, 2, true, 'depilacion_laser', true),
('00000000-0000-4000-8000-000000000242', '00000000-0000-4000-8000-000000000021', 'depilacion_hilo', 'Hilo/Threading', 'Threading', '🧖', 2, 2, true, 'depilacion_hilo', true),
('00000000-0000-4000-8000-000000000243', '00000000-0000-4000-8000-000000000021', 'depilacion_sugaring', 'Sugaring', 'Sugaring', '🧖', 3, 2, true, 'depilacion_sugaring', true);

-- Depth 2: Leaf nodes (Cuerpo y Spa > Tratamiento Corporal)
INSERT INTO service_categories_tree (id, parent_id, slug, display_name_es, display_name_en, icon, sort_order, depth, is_leaf, service_type, is_active) VALUES
('00000000-0000-4000-8000-000000000250', '00000000-0000-4000-8000-000000000022', 'exfoliacion_corporal', 'Exfoliación', 'Exfoliation', '🧖', 0, 2, true, 'exfoliacion_corporal', true),
('00000000-0000-4000-8000-000000000251', '00000000-0000-4000-8000-000000000022', 'envolvimiento_corporal', 'Envolvimiento', 'Wrap', '🧖', 1, 2, true, 'envolvimiento_corporal', true),
('00000000-0000-4000-8000-000000000252', '00000000-0000-4000-8000-000000000022', 'radiofrecuencia_corporal', 'Radiofrecuencia Corporal', 'Body Radiofrequency', '🧖', 2, 2, true, 'radiofrecuencia_corporal', true),
('00000000-0000-4000-8000-000000000253', '00000000-0000-4000-8000-000000000022', 'cavitacion', 'Cavitación', 'Cavitation', '🧖', 3, 2, true, 'cavitacion', true),
('00000000-0000-4000-8000-000000000254', '00000000-0000-4000-8000-000000000022', 'mesoterapia', 'Mesoterapia', 'Mesotherapy', '🧖', 4, 2, true, 'mesoterapia', true);

-- Depth 2: Leaf nodes (Cuerpo y Spa > Bronceado)
INSERT INTO service_categories_tree (id, parent_id, slug, display_name_es, display_name_en, icon, sort_order, depth, is_leaf, service_type, is_active) VALUES
('00000000-0000-4000-8000-000000000260', '00000000-0000-4000-8000-000000000023', 'spray_tan', 'Spray Tan', 'Spray Tan', '☀️', 0, 2, true, 'spray_tan', true),
('00000000-0000-4000-8000-000000000261', '00000000-0000-4000-8000-000000000023', 'cama_bronceado', 'Cama de Bronceado', 'Tanning Bed', '☀️', 1, 2, true, 'cama_bronceado', true);

-- Depth 1: Leaf nodes (Cuidado Especializado, direct children)
INSERT INTO service_categories_tree (id, parent_id, slug, display_name_es, display_name_en, icon, sort_order, depth, is_leaf, service_type, is_active) VALUES
('00000000-0000-4000-8000-000000000270', '00000000-0000-4000-8000-000000000007', 'micropigmentacion_labios', 'Micropigmentación de Labios', 'Lip Micropigmentation', '💋', 1, 1, true, 'micropigmentacion_labios', true),
('00000000-0000-4000-8000-000000000271', '00000000-0000-4000-8000-000000000007', 'remocion_tatuajes', 'Remoción de Tatuajes', 'Tattoo Removal', '🧴', 2, 1, true, 'remocion_tatuajes', true),
('00000000-0000-4000-8000-000000000272', '00000000-0000-4000-8000-000000000007', 'blanqueamiento_dental', 'Blanqueamiento Dental', 'Teeth Whitening', '🦷', 3, 1, true, 'blanqueamiento_dental', true),
('00000000-0000-4000-8000-000000000279', '00000000-0000-4000-8000-000000000007', 'consulta_virtual', 'Consulta Virtual', 'Virtual Consultation', '💻', 5, 1, true, 'consulta_virtual', true);

-- Depth 2: Leaf nodes (Cuidado Especializado > Barbería Premium)
INSERT INTO service_categories_tree (id, parent_id, slug, display_name_es, display_name_en, icon, sort_order, depth, is_leaf, service_type, is_active) VALUES
('00000000-0000-4000-8000-000000000280', '00000000-0000-4000-8000-000000000024', 'barberia_corte_barba', 'Corte + Barba', 'Haircut + Beard', '🧔', 0, 2, true, 'barberia_corte_barba', true),
('00000000-0000-4000-8000-000000000281', '00000000-0000-4000-8000-000000000024', 'barberia_afeitado_clasico', 'Afeitado Clásico', 'Classic Shave', '🧔', 1, 2, true, 'barberia_afeitado_clasico', true),
('00000000-0000-4000-8000-000000000282', '00000000-0000-4000-8000-000000000024', 'barberia_diseno_barba', 'Diseño de Barba', 'Beard Design', '🧔', 2, 2, true, 'barberia_diseno_barba', true),
('00000000-0000-4000-8000-000000000283', '00000000-0000-4000-8000-000000000024', 'barberia_tratamiento_barba', 'Tratamiento de Barba', 'Beard Treatment', '🧔', 3, 2, true, 'barberia_tratamiento_barba', true);


-- =============================================================================
-- 4. TIME INFERENCE RULES (14 rows)
-- From design Section 5 "Default rules" table.
-- day_of_week: 0=Sunday, 1=Monday, ..., 6=Saturday
-- =============================================================================

INSERT INTO time_inference_rules (
  id, hour_start, hour_end, day_of_week_start, day_of_week_end,
  window_description, window_offset_days_min, window_offset_days_max,
  preferred_hour_start, preferred_hour_end, preference_peak_hour, is_active
) VALUES

-- 6-9 AM / Any day → Today 10-17, peak 10
('f1000001-0000-4000-8000-000000000001', 6, 9, 0, 6,
 'Madrugadores planificando, lo quieren hoy', 0, 0, 10, 17, 10, true),

-- 9-13 / Mon-Thu → Today-tomorrow 10-17, peak 11
('f1000001-0000-4000-8000-000000000002', 9, 13, 1, 4,
 'Hoy si hay, sino mañana', 0, 1, 10, 17, 11, true),

-- 9-13 / Fri → Today 13-19, peak 14
('f1000001-0000-4000-8000-000000000003', 9, 13, 5, 5,
 'Urgencia pre-fin de semana, lo quieren hoy', 0, 0, 13, 19, 14, true),

-- 9-13 / Sat → Today next 3h, peak earliest
('f1000001-0000-4000-8000-000000000004', 9, 13, 6, 6,
 'Ya están fuera, lo quieren ya', 0, 0, 9, 16, 9, true),

-- 13-17 / Mon-Thu → Tomorrow 10-16, peak 11
('f1000001-0000-4000-8000-000000000005', 13, 17, 1, 4,
 'Planificando para mañana', 1, 1, 10, 16, 11, true),

-- 13-17 / Fri → Today 16-19 or Sat 10-14
('f1000001-0000-4000-8000-000000000006', 13, 17, 5, 5,
 'Hoy por la tarde o mañana sábado', 0, 1, 10, 19, 16, true),

-- 13-17 / Sat → Today next 2-4h
('f1000001-0000-4000-8000-000000000007', 13, 17, 6, 6,
 'Todavía hay tiempo hoy', 0, 0, 13, 19, 15, true),

-- 17-21 / Mon-Wed → Thu-Fri 10-17, peak 14
('f1000001-0000-4000-8000-000000000008', 17, 21, 1, 3,
 'Navegación nocturna = preparación del fin de semana', 2, 4, 10, 17, 14, true),

-- 17-21 / Thu → Fri-Sat 10-17
('f1000001-0000-4000-8000-000000000009', 17, 21, 4, 4,
 'El fin de semana es inminente', 1, 2, 10, 17, 14, true),

-- 17-21 / Fri → Sat 10-14, peak 10
('f1000001-0000-4000-8000-000000000010', 17, 21, 5, 5,
 'Muy tarde para hoy', 1, 1, 10, 14, 10, true),

-- 17-21 / Sat → Mon-Fri next week 10-17
('f1000001-0000-4000-8000-000000000011', 17, 21, 6, 6,
 'Se acabó el fin de semana, planificando la próxima semana', 2, 6, 10, 17, 11, true),

-- 21-6 / Sun-Wed → Thu-Fri this week 10-16, peak 14
('f1000001-0000-4000-8000-000000000012', 21, 6, 0, 3,
 'Noche tarde = planificación del fin de semana', 2, 5, 10, 16, 14, true),

-- 21-6 / Thu-Sat → Tomorrow or next Sat 10-14
('f1000001-0000-4000-8000-000000000013', 21, 6, 4, 6,
 'Mañana o el próximo sábado', 1, 2, 10, 14, 10, true),

-- Any / Sunday → Mon-Fri coming week 10-17
('f1000001-0000-4000-8000-000000000014', 0, 23, 0, 0,
 'Modo planificación semanal', 1, 5, 10, 17, 11, true);


-- =============================================================================
-- 5. BUSINESSES (15 GDL salons — converted from old providers table)
-- Same UUIDs: a1000001-...-000000000001 through 015
-- Added: tier, cancellation_hours, auto_confirm, accept_walkins
-- =============================================================================

INSERT INTO businesses (
  id, name, phone, whatsapp, address, city, state, country,
  lat, lng, photo_url,
  average_rating, total_reviews, business_category,
  tier, cancellation_hours, auto_confirm, accept_walkins,
  website, facebook_url, instagram_handle,
  is_verified, is_active
) VALUES
-- 1. Salón Bella Donna — Chapultepec
('a1000001-0000-4000-8000-000000000001',
 'Salón Bella Donna', '+523331234501', '+523331234501',
 'Av. Chapultepec Sur 120, Col. Americana, Guadalajara, Jalisco',
 'Guadalajara', 'Jalisco', 'MX', 20.6736, -103.3627, null,
 4.7, 234, 'beauty_salon', 2, 24, true, true,
 null, 'https://facebook.com/bellaDonnaGDL', '@belladonna.gdl', true, true),

-- 2. Estética Glamour Providencia
('a1000001-0000-4000-8000-000000000002',
 'Estética Glamour Providencia', '+523331234502', '+523331234502',
 'Av. Providencia 2578, Col. Providencia, Guadalajara, Jalisco',
 'Guadalajara', 'Jalisco', 'MX', 20.6883, -103.3916, null,
 4.5, 187, 'beauty_salon', 2, 24, true, false,
 'https://glamourprovidencia.mx', 'https://facebook.com/glamourProvidencia', '@glamour.providencia', true, true),

-- 3. Nails & Co. Americana
('a1000001-0000-4000-8000-000000000003',
 'Nails & Co. Americana', '+523331234503', '+523331234503',
 'Av. La Paz 1845, Col. Americana, Guadalajara, Jalisco',
 'Guadalajara', 'Jalisco', 'MX', 20.6712, -103.3601, null,
 4.8, 312, 'nail_salon', 3, 24, true, true,
 null, 'https://facebook.com/nailscoamericana', '@nailsco.americana', true, true),

-- 4. Spa Raíces — Zapopan
('a1000001-0000-4000-8000-000000000004',
 'Spa Raíces', '+523331234504', '+523331234504',
 'Av. Hidalgo 234, Centro, Zapopan, Jalisco',
 'Zapopan', 'Jalisco', 'MX', 20.7230, -103.3915, null,
 4.6, 156, 'spa', 2, 24, true, false,
 'https://sparaices.mx', 'https://facebook.com/sparaices', '@spa.raices', true, true),

-- 5. Studio 33 Hair Design — Chapalita
('a1000001-0000-4000-8000-000000000005',
 'Studio 33 Hair Design', '+523331234505', '+523331234505',
 'Av. Guadalupe 1020, Chapalita, Zapopan, Jalisco',
 'Zapopan', 'Jalisco', 'MX', 20.6820, -103.4020, null,
 4.4, 98, 'hair_salon', 1, 24, true, false,
 null, null, '@studio33.gdl', false, true),

-- 6. Dermika Centro de Belleza — San Javier
('a1000001-0000-4000-8000-000000000006',
 'Dermika Centro de Belleza', '+523331234506', '+523331234506',
 'Av. Royal Country 4567, Colinas de San Javier, Zapopan, Jalisco',
 'Zapopan', 'Jalisco', 'MX', 20.6940, -103.4145, null,
 4.9, 421, 'beauty_salon', 3, 24, true, false,
 'https://dermika.mx', 'https://facebook.com/dermikagdl', '@dermika.gdl', true, true),

-- 7. Las Tijeras de Oro — Ladrón de Guevara
('a1000001-0000-4000-8000-000000000007',
 'Las Tijeras de Oro', '+523331234507', '+523331234507',
 'Calle Marsella 450, Col. Ladrón de Guevara, Guadalajara, Jalisco',
 'Guadalajara', 'Jalisco', 'MX', 20.6780, -103.3730, null,
 4.3, 145, 'hair_salon', 1, 24, true, true,
 null, 'https://facebook.com/lastijerasdeoro', '@tijeras.de.oro', false, true),

-- 8. Lashes & Brows Studio GDL — Monraz
('a1000001-0000-4000-8000-000000000008',
 'Lashes & Brows Studio GDL', '+523331234508', '+523331234508',
 'Calle José Guadalupe Zuno 2089, Col. Monraz, Guadalajara, Jalisco',
 'Guadalajara', 'Jalisco', 'MX', 20.6850, -103.3810, null,
 4.7, 267, 'beauty_salon', 2, 24, true, false,
 null, 'https://facebook.com/lashesbrowsgdl', '@lashesbrows.gdl', true, true),

-- 9. Zen Spa & Wellness — Puerta de Hierro
('a1000001-0000-4000-8000-000000000009',
 'Zen Spa & Wellness', '+523331234509', '+523331234509',
 'Av. Empresarios 180, Puerta de Hierro, Zapopan, Jalisco',
 'Zapopan', 'Jalisco', 'MX', 20.7055, -103.4280, null,
 4.8, 389, 'spa', 3, 24, true, false,
 'https://zenspagdl.mx', 'https://facebook.com/zenspagdl', '@zenspa.gdl', true, true),

-- 10. Estética La Catrina — Centro Histórico
('a1000001-0000-4000-8000-000000000010',
 'Estética La Catrina', '+523331234510', '+523331234510',
 'Calle Morelos 678, Centro Histórico, Guadalajara, Jalisco',
 'Guadalajara', 'Jalisco', 'MX', 20.6738, -103.3444, null,
 4.1, 89, 'beauty_salon', 1, 24, true, true,
 null, 'https://facebook.com/lacatrinaGDL', '@lacatrina.estetica', false, true),

-- 11. Maison de Beauté — Italia Providencia
('a1000001-0000-4000-8000-000000000011',
 'Maison de Beauté', '+523331234511', '+523331234511',
 'Av. Italia 1550, Col. Italia Providencia, Guadalajara, Jalisco',
 'Guadalajara', 'Jalisco', 'MX', 20.6900, -103.3850, null,
 4.6, 203, 'beauty_salon', 2, 24, true, false,
 'https://maisonbeaute.mx', 'https://facebook.com/maisonbeautegdl', '@maison.beaute.gdl', true, true),

-- 12. Salón Frida — Tlaquepaque
('a1000001-0000-4000-8000-000000000012',
 'Salón Frida', '+523331234512', '+523331234512',
 'Calle Independencia 345, Centro, Tlaquepaque, Jalisco',
 'Tlaquepaque', 'Jalisco', 'MX', 20.6400, -103.3120, null,
 4.3, 112, 'beauty_salon', 1, 24, true, true,
 null, 'https://facebook.com/salonfrida.tlaq', '@salon.frida.tlaq', false, true),

-- 13. Aura Nail Bar — Jardines del Bosque
('a1000001-0000-4000-8000-000000000013',
 'Aura Nail Bar', '+523331234513', '+523331234513',
 'Av. López Mateos Sur 2345, Jardines del Bosque, Guadalajara, Jalisco',
 'Guadalajara', 'Jalisco', 'MX', 20.6580, -103.3740, null,
 4.5, 178, 'nail_salon', 2, 24, true, true,
 null, 'https://facebook.com/auranailbar', '@aura.nailbar', true, true),

-- 14. Pelo Perfecto Salón — Andares / Patria
('a1000001-0000-4000-8000-000000000014',
 'Pelo Perfecto Salón', '+523331234514', '+523331234514',
 'Av. Patria 1250, Jardines Universidad, Zapopan, Jalisco',
 'Zapopan', 'Jalisco', 'MX', 20.7010, -103.4100, null,
 4.4, 165, 'hair_salon', 1, 24, true, false,
 null, null, '@pelo.perfecto.gdl', false, true),

-- 15. Manos Mágicas Beauty — Santa Tere
('a1000001-0000-4000-8000-000000000015',
 'Manos Mágicas Beauty', '+523331234515', '+523331234515',
 'Calle Jesús García 890, Col. Santa Teresita, Guadalajara, Jalisco',
 'Guadalajara', 'Jalisco', 'MX', 20.6790, -103.3530, null,
 4.2, 76, 'beauty_salon', 1, 24, true, true,
 null, 'https://facebook.com/manosmagicasbeauty', '@manos.magicas.beauty', false, true);


-- =============================================================================
-- 6. STAFF (2-4 per business, ~45 rows)
-- Deterministic UUIDs: c1000001-0000-4000-8000-000000000001 through ~045
-- =============================================================================

INSERT INTO staff (
  id, business_id, first_name, last_name, avatar_url,
  experience_years, average_rating, total_reviews,
  accept_online_booking, is_active
) VALUES
-- Business 1: Salón Bella Donna
('c1000001-0000-4000-8000-000000000001', 'a1000001-0000-4000-8000-000000000001', 'María', 'García', null, 12, 4.8, 98, true, true),
('c1000001-0000-4000-8000-000000000002', 'a1000001-0000-4000-8000-000000000001', 'Lupita', 'Hernández', null, 8, 4.6, 72, true, true),
('c1000001-0000-4000-8000-000000000003', 'a1000001-0000-4000-8000-000000000001', 'Andrea', 'Martínez', null, 4, 4.5, 34, true, true),

-- Business 2: Estética Glamour Providencia
('c1000001-0000-4000-8000-000000000004', 'a1000001-0000-4000-8000-000000000002', 'Sofía', 'López', null, 15, 4.7, 85, true, true),
('c1000001-0000-4000-8000-000000000005', 'a1000001-0000-4000-8000-000000000002', 'Daniela', 'Ramírez', null, 6, 4.4, 45, true, true),
('c1000001-0000-4000-8000-000000000006', 'a1000001-0000-4000-8000-000000000002', 'Valeria', 'Torres', null, 3, 4.3, 28, true, true),

-- Business 3: Nails & Co. Americana
('c1000001-0000-4000-8000-000000000007', 'a1000001-0000-4000-8000-000000000003', 'Karla', 'Sánchez', null, 10, 4.9, 120, true, true),
('c1000001-0000-4000-8000-000000000008', 'a1000001-0000-4000-8000-000000000003', 'Paola', 'Ríos', null, 7, 4.7, 88, true, true),
('c1000001-0000-4000-8000-000000000009', 'a1000001-0000-4000-8000-000000000003', 'Fernanda', 'Díaz', null, 5, 4.6, 54, true, true),
('c1000001-0000-4000-8000-000000000010', 'a1000001-0000-4000-8000-000000000003', 'Mariana', 'Vega', null, 3, 4.5, 30, true, true),

-- Business 4: Spa Raíces
('c1000001-0000-4000-8000-000000000011', 'a1000001-0000-4000-8000-000000000004', 'Rosa', 'Flores', null, 14, 4.7, 78, true, true),
('c1000001-0000-4000-8000-000000000012', 'a1000001-0000-4000-8000-000000000004', 'Carmen', 'Morales', null, 9, 4.5, 42, true, true),
('c1000001-0000-4000-8000-000000000013', 'a1000001-0000-4000-8000-000000000004', 'Elena', 'Cruz', null, 6, 4.4, 25, true, true),

-- Business 5: Studio 33 Hair Design
('c1000001-0000-4000-8000-000000000014', 'a1000001-0000-4000-8000-000000000005', 'Roberto', 'Jiménez', null, 18, 4.6, 55, true, true),
('c1000001-0000-4000-8000-000000000015', 'a1000001-0000-4000-8000-000000000005', 'Diana', 'Reyes', null, 7, 4.3, 28, true, true),

-- Business 6: Dermika Centro de Belleza
('c1000001-0000-4000-8000-000000000016', 'a1000001-0000-4000-8000-000000000006', 'Dra. Alejandra', 'Navarro', null, 20, 4.9, 180, true, true),
('c1000001-0000-4000-8000-000000000017', 'a1000001-0000-4000-8000-000000000006', 'Gabriela', 'Mendoza', null, 10, 4.8, 120, true, true),
('c1000001-0000-4000-8000-000000000018', 'a1000001-0000-4000-8000-000000000006', 'Isabel', 'Vargas', null, 5, 4.6, 65, true, true),

-- Business 7: Las Tijeras de Oro
('c1000001-0000-4000-8000-000000000019', 'a1000001-0000-4000-8000-000000000007', 'Jesús', 'Ortega', null, 25, 4.4, 70, true, true),
('c1000001-0000-4000-8000-000000000020', 'a1000001-0000-4000-8000-000000000007', 'Lucía', 'Castillo', null, 8, 4.2, 40, true, true),
('c1000001-0000-4000-8000-000000000021', 'a1000001-0000-4000-8000-000000000007', 'Miguel', 'Peña', null, 4, 4.1, 20, true, true),

-- Business 8: Lashes & Brows Studio GDL
('c1000001-0000-4000-8000-000000000022', 'a1000001-0000-4000-8000-000000000008', 'Natalia', 'Aguilar', null, 11, 4.8, 110, true, true),
('c1000001-0000-4000-8000-000000000023', 'a1000001-0000-4000-8000-000000000008', 'Jessica', 'Rojas', null, 6, 4.6, 70, true, true),
('c1000001-0000-4000-8000-000000000024', 'a1000001-0000-4000-8000-000000000008', 'Adriana', 'Guerrero', null, 4, 4.5, 45, true, true),

-- Business 9: Zen Spa & Wellness
('c1000001-0000-4000-8000-000000000025', 'a1000001-0000-4000-8000-000000000009', 'Patricia', 'Medina', null, 16, 4.9, 150, true, true),
('c1000001-0000-4000-8000-000000000026', 'a1000001-0000-4000-8000-000000000009', 'Laura', 'Guzmán', null, 10, 4.7, 95, true, true),
('c1000001-0000-4000-8000-000000000027', 'a1000001-0000-4000-8000-000000000009', 'Raquel', 'Salazar', null, 7, 4.6, 60, true, true),
('c1000001-0000-4000-8000-000000000028', 'a1000001-0000-4000-8000-000000000009', 'Eduardo', 'Domínguez', null, 5, 4.5, 40, true, true),

-- Business 10: Estética La Catrina
('c1000001-0000-4000-8000-000000000029', 'a1000001-0000-4000-8000-000000000010', 'Claudia', 'Ruiz', null, 9, 4.2, 35, true, true),
('c1000001-0000-4000-8000-000000000030', 'a1000001-0000-4000-8000-000000000010', 'Susana', 'Herrera', null, 5, 4.0, 22, true, true),

-- Business 11: Maison de Beauté
('c1000001-0000-4000-8000-000000000031', 'a1000001-0000-4000-8000-000000000011', 'Renata', 'Delgado', null, 13, 4.7, 90, true, true),
('c1000001-0000-4000-8000-000000000032', 'a1000001-0000-4000-8000-000000000011', 'Camila', 'Santos', null, 8, 4.5, 55, true, true),
('c1000001-0000-4000-8000-000000000033', 'a1000001-0000-4000-8000-000000000011', 'Victoria', 'Núñez', null, 5, 4.4, 30, true, true),

-- Business 12: Salón Frida
('c1000001-0000-4000-8000-000000000034', 'a1000001-0000-4000-8000-000000000012', 'Frida', 'Castro', null, 11, 4.4, 50, true, true),
('c1000001-0000-4000-8000-000000000035', 'a1000001-0000-4000-8000-000000000012', 'Beatriz', 'Ramos', null, 6, 4.2, 30, true, true),

-- Business 13: Aura Nail Bar
('c1000001-0000-4000-8000-000000000036', 'a1000001-0000-4000-8000-000000000013', 'Ximena', 'Campos', null, 9, 4.6, 80, true, true),
('c1000001-0000-4000-8000-000000000037', 'a1000001-0000-4000-8000-000000000013', 'Paulina', 'Fuentes', null, 5, 4.4, 45, true, true),
('c1000001-0000-4000-8000-000000000038', 'a1000001-0000-4000-8000-000000000013', 'Regina', 'Lara', null, 3, 4.3, 25, true, true),

-- Business 14: Pelo Perfecto Salón
('c1000001-0000-4000-8000-000000000039', 'a1000001-0000-4000-8000-000000000014', 'Carlos', 'Espinoza', null, 20, 4.5, 80, true, true),
('c1000001-0000-4000-8000-000000000040', 'a1000001-0000-4000-8000-000000000014', 'Alicia', 'Velázquez', null, 7, 4.3, 40, true, true),

-- Business 15: Manos Mágicas Beauty
('c1000001-0000-4000-8000-000000000041', 'a1000001-0000-4000-8000-000000000015', 'Teresa', 'Acosta', null, 8, 4.3, 30, true, true),
('c1000001-0000-4000-8000-000000000042', 'a1000001-0000-4000-8000-000000000015', 'Lorena', 'Ibarra', null, 5, 4.1, 20, true, true),
('c1000001-0000-4000-8000-000000000043', 'a1000001-0000-4000-8000-000000000015', 'Sandra', 'Montes', null, 3, 4.0, 12, true, true);


-- =============================================================================
-- 7. SERVICES (converted from old provider_services, same UUIDs b1000001-...)
-- Added: service_type, buffer_minutes
-- =============================================================================

INSERT INTO services (
  id, business_id, service_type, name, price, duration_minutes, buffer_minutes, is_active
) VALUES
-- Business 1: Salón Bella Donna
('b1000001-0000-4000-8000-000000000001', 'a1000001-0000-4000-8000-000000000001', 'corte_mujer', 'Corte de Cabello Dama', 350.00, 45, 10, true),
('b1000001-0000-4000-8000-000000000002', 'a1000001-0000-4000-8000-000000000001', 'tinte_completo', 'Tinte Completo', 1200.00, 120, 15, true),
('b1000001-0000-4000-8000-000000000003', 'a1000001-0000-4000-8000-000000000001', 'manicure_clasico', 'Manicure Tradicional', 300.00, 45, 5, true),
('b1000001-0000-4000-8000-000000000004', 'a1000001-0000-4000-8000-000000000001', 'maquillaje_evento', 'Maquillaje para Evento', 1000.00, 60, 10, true),

-- Business 2: Estética Glamour Providencia
('b1000001-0000-4000-8000-000000000005', 'a1000001-0000-4000-8000-000000000002', 'corte_mujer', 'Corte y Peinado', 400.00, 60, 10, true),
('b1000001-0000-4000-8000-000000000006', 'a1000001-0000-4000-8000-000000000002', 'keratina_alisado', 'Keratina Brasileña', 1800.00, 150, 15, true),
('b1000001-0000-4000-8000-000000000007', 'a1000001-0000-4000-8000-000000000002', 'ext_pestanas_clasicas', 'Extensiones de Pestañas Clásicas', 750.00, 90, 10, true),
('b1000001-0000-4000-8000-000000000008', 'a1000001-0000-4000-8000-000000000002', 'maquillaje_novia', 'Maquillaje de Novia', 2000.00, 90, 15, true),
('b1000001-0000-4000-8000-000000000009', 'a1000001-0000-4000-8000-000000000002', 'manicure_gel', 'Uñas Gelish', 400.00, 50, 5, true),

-- Business 3: Nails & Co. Americana
('b1000001-0000-4000-8000-000000000010', 'a1000001-0000-4000-8000-000000000003', 'manicure_clasico', 'Manicure Express', 240.00, 30, 5, true),
('b1000001-0000-4000-8000-000000000011', 'a1000001-0000-4000-8000-000000000003', 'manicure_acrilico', 'Uñas Acrílicas Set Completo', 580.00, 90, 10, true),
('b1000001-0000-4000-8000-000000000012', 'a1000001-0000-4000-8000-000000000003', 'manicure_gel', 'Gelish con Diseño', 440.00, 60, 5, true),
('b1000001-0000-4000-8000-000000000013', 'a1000001-0000-4000-8000-000000000003', 'pedicure_spa_luxury', 'Pedicure Spa', 350.00, 50, 5, true),
('b1000001-0000-4000-8000-000000000014', 'a1000001-0000-4000-8000-000000000003', 'relleno_acrilico_gel', 'Relleno de Acrílico', 350.00, 60, 5, true),

-- Business 4: Spa Raíces
('b1000001-0000-4000-8000-000000000015', 'a1000001-0000-4000-8000-000000000004', 'limpieza_facial_profunda', 'Limpieza Facial Profunda', 750.00, 60, 10, true),
('b1000001-0000-4000-8000-000000000016', 'a1000001-0000-4000-8000-000000000004', 'masaje_relajante', 'Masaje Relajante Cuerpo Completo', 850.00, 60, 10, true),
('b1000001-0000-4000-8000-000000000017', 'a1000001-0000-4000-8000-000000000004', 'masaje_descontracturante', 'Masaje Descontracturante', 950.00, 60, 10, true),
('b1000001-0000-4000-8000-000000000018', 'a1000001-0000-4000-8000-000000000004', 'exfoliacion_corporal', 'Exfoliación Corporal con Envolvimiento', 1100.00, 90, 15, true),

-- Business 5: Studio 33 Hair Design
('b1000001-0000-4000-8000-000000000019', 'a1000001-0000-4000-8000-000000000005', 'corte_mujer', 'Corte Dama con Secado', 425.00, 60, 10, true),
('b1000001-0000-4000-8000-000000000020', 'a1000001-0000-4000-8000-000000000005', 'balayage', 'Mechas/Balayage', 2250.00, 180, 15, true),
('b1000001-0000-4000-8000-000000000021', 'a1000001-0000-4000-8000-000000000005', 'recogido_evento', 'Peinado para Evento', 650.00, 60, 10, true),
('b1000001-0000-4000-8000-000000000022', 'a1000001-0000-4000-8000-000000000005', 'maquillaje_social', 'Maquillaje Social', 850.00, 50, 10, true),

-- Business 6: Dermika Centro de Belleza
('b1000001-0000-4000-8000-000000000023', 'a1000001-0000-4000-8000-000000000006', 'anti_edad', 'Tratamiento Anti-Edad con Radiofrecuencia', 1400.00, 75, 15, true),
('b1000001-0000-4000-8000-000000000024', 'a1000001-0000-4000-8000-000000000006', 'hidrafacial', 'Hidrafacial', 1150.00, 60, 10, true),
('b1000001-0000-4000-8000-000000000025', 'a1000001-0000-4000-8000-000000000006', 'depilacion_laser', 'Depilación Láser Zona Pequeña', 650.00, 30, 10, true),
('b1000001-0000-4000-8000-000000000026', 'a1000001-0000-4000-8000-000000000006', 'drenaje_linfatico', 'Masaje Reductivo con Aparatología', 750.00, 50, 10, true),
('b1000001-0000-4000-8000-000000000027', 'a1000001-0000-4000-8000-000000000006', 'maquillaje_social', 'Maquillaje Profesional', 1200.00, 60, 10, true),

-- Business 7: Las Tijeras de Oro
('b1000001-0000-4000-8000-000000000028', 'a1000001-0000-4000-8000-000000000007', 'corte_hombre', 'Corte Caballero', 200.00, 30, 5, true),
('b1000001-0000-4000-8000-000000000029', 'a1000001-0000-4000-8000-000000000007', 'corte_mujer', 'Corte Dama', 325.00, 45, 10, true),
('b1000001-0000-4000-8000-000000000030', 'a1000001-0000-4000-8000-000000000007', 'retoque_raiz', 'Tinte Raíz', 650.00, 90, 10, true),
('b1000001-0000-4000-8000-000000000031', 'a1000001-0000-4000-8000-000000000007', 'diseno_depilacion_cejas', 'Diseño de Cejas con Hilo', 200.00, 20, 5, true),

-- Business 8: Lashes & Brows Studio GDL
('b1000001-0000-4000-8000-000000000032', 'a1000001-0000-4000-8000-000000000008', 'ext_pestanas_volumen', 'Extensiones Volumen Ruso', 1150.00, 120, 10, true),
('b1000001-0000-4000-8000-000000000033', 'a1000001-0000-4000-8000-000000000008', 'lifting_pestanas', 'Lifting de Pestañas', 600.00, 60, 10, true),
('b1000001-0000-4000-8000-000000000034', 'a1000001-0000-4000-8000-000000000008', 'microblading', 'Microblading de Cejas', 3250.00, 120, 15, true),
('b1000001-0000-4000-8000-000000000035', 'a1000001-0000-4000-8000-000000000008', 'laminado_cejas', 'Laminado de Cejas', 500.00, 45, 5, true),
('b1000001-0000-4000-8000-000000000036', 'a1000001-0000-4000-8000-000000000008', 'maquillaje_social', 'Maquillaje + Peinado Combo', 1500.00, 90, 10, true),

-- Business 9: Zen Spa & Wellness
('b1000001-0000-4000-8000-000000000037', 'a1000001-0000-4000-8000-000000000009', 'masaje_piedras_calientes', 'Masaje con Piedras Calientes', 1100.00, 75, 15, true),
('b1000001-0000-4000-8000-000000000038', 'a1000001-0000-4000-8000-000000000009', 'masaje_relajante', 'Masaje de Parejas', 1900.00, 75, 15, true),
('b1000001-0000-4000-8000-000000000039', 'a1000001-0000-4000-8000-000000000009', 'limpieza_facial_profunda', 'Facial Detox con Oxígeno', 1000.00, 60, 10, true),
('b1000001-0000-4000-8000-000000000040', 'a1000001-0000-4000-8000-000000000009', 'drenaje_linfatico', 'Drenaje Linfático Manual', 850.00, 60, 10, true),
('b1000001-0000-4000-8000-000000000041', 'a1000001-0000-4000-8000-000000000009', 'masaje_relajante', 'Circuito Spa Completo', 1750.00, 150, 15, true),

-- Business 10: Estética La Catrina
('b1000001-0000-4000-8000-000000000042', 'a1000001-0000-4000-8000-000000000010', 'corte_mujer', 'Corte Dama Básico', 275.00, 40, 10, true),
('b1000001-0000-4000-8000-000000000043', 'a1000001-0000-4000-8000-000000000010', 'manicure_gel', 'Manicure Semipermanente', 330.00, 45, 5, true),
('b1000001-0000-4000-8000-000000000044', 'a1000001-0000-4000-8000-000000000010', 'maquillaje_xv', 'Maquillaje XV Años', 1300.00, 75, 10, true),

-- Business 11: Maison de Beauté
('b1000001-0000-4000-8000-000000000045', 'a1000001-0000-4000-8000-000000000011', 'corte_mujer', 'Corte + Brushing', 500.00, 60, 10, true),
('b1000001-0000-4000-8000-000000000046', 'a1000001-0000-4000-8000-000000000011', 'balayage', 'Balayage Premium', 2750.00, 180, 15, true),
('b1000001-0000-4000-8000-000000000047', 'a1000001-0000-4000-8000-000000000011', 'manicure_acrilico', 'Uñas Esculpidas Acrílico', 625.00, 90, 10, true),
('b1000001-0000-4000-8000-000000000048', 'a1000001-0000-4000-8000-000000000011', 'ext_pestanas_clasicas', 'Extensiones Pelo a Pelo', 850.00, 90, 10, true),
('b1000001-0000-4000-8000-000000000049', 'a1000001-0000-4000-8000-000000000011', 'hidrafacial', 'Facial Vitamina C', 850.00, 50, 10, true),

-- Business 12: Salón Frida
('b1000001-0000-4000-8000-000000000050', 'a1000001-0000-4000-8000-000000000012', 'corte_mujer', 'Corte y Lavado', 275.00, 45, 10, true),
('b1000001-0000-4000-8000-000000000051', 'a1000001-0000-4000-8000-000000000012', 'mechas_highlights', 'Mechas Tradicionales', 1100.00, 120, 15, true),
('b1000001-0000-4000-8000-000000000052', 'a1000001-0000-4000-8000-000000000012', 'manicure_gel', 'Gelish Manos', 350.00, 45, 5, true),
('b1000001-0000-4000-8000-000000000053', 'a1000001-0000-4000-8000-000000000012', 'maquillaje_social', 'Maquillaje Natural', 650.00, 45, 10, true),

-- Business 13: Aura Nail Bar
('b1000001-0000-4000-8000-000000000054', 'a1000001-0000-4000-8000-000000000013', 'manicure_ruso', 'Manicure Rusa', 400.00, 60, 5, true),
('b1000001-0000-4000-8000-000000000055', 'a1000001-0000-4000-8000-000000000013', 'nail_art', 'Acrílico con Diseño de Autor', 750.00, 100, 10, true),
('b1000001-0000-4000-8000-000000000056', 'a1000001-0000-4000-8000-000000000013', 'pedicure_gel', 'Pedicure con Gelish', 400.00, 55, 5, true),
('b1000001-0000-4000-8000-000000000057', 'a1000001-0000-4000-8000-000000000013', 'tinte_cejas', 'Tinte y Diseño de Cejas', 250.00, 25, 5, true),

-- Business 14: Pelo Perfecto Salón
('b1000001-0000-4000-8000-000000000058', 'a1000001-0000-4000-8000-000000000014', 'corte_hombre', 'Corte Caballero Premium', 275.00, 35, 5, true),
('b1000001-0000-4000-8000-000000000059', 'a1000001-0000-4000-8000-000000000014', 'botox_capilar', 'Tratamiento de Botox Capilar', 1400.00, 120, 15, true),
('b1000001-0000-4000-8000-000000000060', 'a1000001-0000-4000-8000-000000000014', 'decoloracion', 'Decoloración + Fantasía', 1700.00, 150, 15, true),
('b1000001-0000-4000-8000-000000000061', 'a1000001-0000-4000-8000-000000000014', 'tratamiento_anticaida', 'Diagnóstico Capilar con Microscopio', 650.00, 45, 10, true),

-- Business 15: Manos Mágicas Beauty
('b1000001-0000-4000-8000-000000000062', 'a1000001-0000-4000-8000-000000000015', 'manicure_gel', 'Manicure con Gelish', 330.00, 45, 5, true),
('b1000001-0000-4000-8000-000000000063', 'a1000001-0000-4000-8000-000000000015', 'manicure_acrilico', 'Uñas Acrílicas Francesas', 475.00, 75, 10, true),
('b1000001-0000-4000-8000-000000000064', 'a1000001-0000-4000-8000-000000000015', 'corte_mujer', 'Corte Dama + Secado', 340.00, 50, 10, true),
('b1000001-0000-4000-8000-000000000065', 'a1000001-0000-4000-8000-000000000015', 'ext_pestanas_clasicas', 'Pestañas Clásicas', 600.00, 75, 10, true),
('b1000001-0000-4000-8000-000000000066', 'a1000001-0000-4000-8000-000000000015', 'maquillaje_social', 'Maquillaje Casual', 500.00, 40, 10, true);


-- =============================================================================
-- 8. STAFF_SERVICES (link staff to services, ~100 rows)
-- UUIDs: d1000001-0000-4000-8000-000000000001+
-- Some staff have custom_price/custom_duration overrides
-- =============================================================================

INSERT INTO staff_services (id, staff_id, service_id, custom_price, custom_duration) VALUES
-- Business 1: Salón Bella Donna (staff 001-003, services 001-004)
('d1000001-0000-4000-8000-000000000001', 'c1000001-0000-4000-8000-000000000001', 'b1000001-0000-4000-8000-000000000001', null, null),
('d1000001-0000-4000-8000-000000000002', 'c1000001-0000-4000-8000-000000000001', 'b1000001-0000-4000-8000-000000000002', null, null),
('d1000001-0000-4000-8000-000000000003', 'c1000001-0000-4000-8000-000000000001', 'b1000001-0000-4000-8000-000000000004', null, null),
('d1000001-0000-4000-8000-000000000004', 'c1000001-0000-4000-8000-000000000002', 'b1000001-0000-4000-8000-000000000001', 300.00, null),
('d1000001-0000-4000-8000-000000000005', 'c1000001-0000-4000-8000-000000000002', 'b1000001-0000-4000-8000-000000000003', null, null),
('d1000001-0000-4000-8000-000000000006', 'c1000001-0000-4000-8000-000000000003', 'b1000001-0000-4000-8000-000000000003', null, null),
('d1000001-0000-4000-8000-000000000007', 'c1000001-0000-4000-8000-000000000003', 'b1000001-0000-4000-8000-000000000004', 900.00, null),

-- Business 2: Estética Glamour (staff 004-006, services 005-009)
('d1000001-0000-4000-8000-000000000008', 'c1000001-0000-4000-8000-000000000004', 'b1000001-0000-4000-8000-000000000005', null, null),
('d1000001-0000-4000-8000-000000000009', 'c1000001-0000-4000-8000-000000000004', 'b1000001-0000-4000-8000-000000000006', null, null),
('d1000001-0000-4000-8000-000000000010', 'c1000001-0000-4000-8000-000000000004', 'b1000001-0000-4000-8000-000000000008', null, null),
('d1000001-0000-4000-8000-000000000011', 'c1000001-0000-4000-8000-000000000005', 'b1000001-0000-4000-8000-000000000005', 350.00, null),
('d1000001-0000-4000-8000-000000000012', 'c1000001-0000-4000-8000-000000000005', 'b1000001-0000-4000-8000-000000000007', null, null),
('d1000001-0000-4000-8000-000000000013', 'c1000001-0000-4000-8000-000000000005', 'b1000001-0000-4000-8000-000000000009', null, null),
('d1000001-0000-4000-8000-000000000014', 'c1000001-0000-4000-8000-000000000006', 'b1000001-0000-4000-8000-000000000007', null, null),
('d1000001-0000-4000-8000-000000000015', 'c1000001-0000-4000-8000-000000000006', 'b1000001-0000-4000-8000-000000000009', null, null),

-- Business 3: Nails & Co. (staff 007-010, services 010-014)
('d1000001-0000-4000-8000-000000000016', 'c1000001-0000-4000-8000-000000000007', 'b1000001-0000-4000-8000-000000000010', null, null),
('d1000001-0000-4000-8000-000000000017', 'c1000001-0000-4000-8000-000000000007', 'b1000001-0000-4000-8000-000000000011', null, null),
('d1000001-0000-4000-8000-000000000018', 'c1000001-0000-4000-8000-000000000007', 'b1000001-0000-4000-8000-000000000014', null, null),
('d1000001-0000-4000-8000-000000000019', 'c1000001-0000-4000-8000-000000000008', 'b1000001-0000-4000-8000-000000000010', null, null),
('d1000001-0000-4000-8000-000000000020', 'c1000001-0000-4000-8000-000000000008', 'b1000001-0000-4000-8000-000000000012', null, null),
('d1000001-0000-4000-8000-000000000021', 'c1000001-0000-4000-8000-000000000008', 'b1000001-0000-4000-8000-000000000013', null, null),
('d1000001-0000-4000-8000-000000000022', 'c1000001-0000-4000-8000-000000000009', 'b1000001-0000-4000-8000-000000000011', null, null),
('d1000001-0000-4000-8000-000000000023', 'c1000001-0000-4000-8000-000000000009', 'b1000001-0000-4000-8000-000000000012', null, null),
('d1000001-0000-4000-8000-000000000024', 'c1000001-0000-4000-8000-000000000010', 'b1000001-0000-4000-8000-000000000010', null, null),
('d1000001-0000-4000-8000-000000000025', 'c1000001-0000-4000-8000-000000000010', 'b1000001-0000-4000-8000-000000000013', null, null),

-- Business 4: Spa Raíces (staff 011-013, services 015-018)
('d1000001-0000-4000-8000-000000000026', 'c1000001-0000-4000-8000-000000000011', 'b1000001-0000-4000-8000-000000000015', null, null),
('d1000001-0000-4000-8000-000000000027', 'c1000001-0000-4000-8000-000000000011', 'b1000001-0000-4000-8000-000000000016', null, null),
('d1000001-0000-4000-8000-000000000028', 'c1000001-0000-4000-8000-000000000012', 'b1000001-0000-4000-8000-000000000016', null, null),
('d1000001-0000-4000-8000-000000000029', 'c1000001-0000-4000-8000-000000000012', 'b1000001-0000-4000-8000-000000000017', null, null),
('d1000001-0000-4000-8000-000000000030', 'c1000001-0000-4000-8000-000000000013', 'b1000001-0000-4000-8000-000000000017', null, null),
('d1000001-0000-4000-8000-000000000031', 'c1000001-0000-4000-8000-000000000013', 'b1000001-0000-4000-8000-000000000018', null, null),

-- Business 5: Studio 33 (staff 014-015, services 019-022)
('d1000001-0000-4000-8000-000000000032', 'c1000001-0000-4000-8000-000000000014', 'b1000001-0000-4000-8000-000000000019', null, null),
('d1000001-0000-4000-8000-000000000033', 'c1000001-0000-4000-8000-000000000014', 'b1000001-0000-4000-8000-000000000020', null, null),
('d1000001-0000-4000-8000-000000000034', 'c1000001-0000-4000-8000-000000000014', 'b1000001-0000-4000-8000-000000000021', null, null),
('d1000001-0000-4000-8000-000000000035', 'c1000001-0000-4000-8000-000000000015', 'b1000001-0000-4000-8000-000000000019', 380.00, null),
('d1000001-0000-4000-8000-000000000036', 'c1000001-0000-4000-8000-000000000015', 'b1000001-0000-4000-8000-000000000022', null, null),

-- Business 6: Dermika (staff 016-018, services 023-027)
('d1000001-0000-4000-8000-000000000037', 'c1000001-0000-4000-8000-000000000016', 'b1000001-0000-4000-8000-000000000023', null, null),
('d1000001-0000-4000-8000-000000000038', 'c1000001-0000-4000-8000-000000000016', 'b1000001-0000-4000-8000-000000000024', null, null),
('d1000001-0000-4000-8000-000000000039', 'c1000001-0000-4000-8000-000000000017', 'b1000001-0000-4000-8000-000000000024', null, null),
('d1000001-0000-4000-8000-000000000040', 'c1000001-0000-4000-8000-000000000017', 'b1000001-0000-4000-8000-000000000025', null, null),
('d1000001-0000-4000-8000-000000000041', 'c1000001-0000-4000-8000-000000000017', 'b1000001-0000-4000-8000-000000000026', null, null),
('d1000001-0000-4000-8000-000000000042', 'c1000001-0000-4000-8000-000000000018', 'b1000001-0000-4000-8000-000000000025', null, null),
('d1000001-0000-4000-8000-000000000043', 'c1000001-0000-4000-8000-000000000018', 'b1000001-0000-4000-8000-000000000027', null, null),

-- Business 7: Las Tijeras (staff 019-021, services 028-031)
('d1000001-0000-4000-8000-000000000044', 'c1000001-0000-4000-8000-000000000019', 'b1000001-0000-4000-8000-000000000028', null, null),
('d1000001-0000-4000-8000-000000000045', 'c1000001-0000-4000-8000-000000000019', 'b1000001-0000-4000-8000-000000000029', null, null),
('d1000001-0000-4000-8000-000000000046', 'c1000001-0000-4000-8000-000000000019', 'b1000001-0000-4000-8000-000000000030', null, null),
('d1000001-0000-4000-8000-000000000047', 'c1000001-0000-4000-8000-000000000020', 'b1000001-0000-4000-8000-000000000029', null, null),
('d1000001-0000-4000-8000-000000000048', 'c1000001-0000-4000-8000-000000000020', 'b1000001-0000-4000-8000-000000000031', null, null),
('d1000001-0000-4000-8000-000000000049', 'c1000001-0000-4000-8000-000000000021', 'b1000001-0000-4000-8000-000000000028', 180.00, null),
('d1000001-0000-4000-8000-000000000050', 'c1000001-0000-4000-8000-000000000021', 'b1000001-0000-4000-8000-000000000031', null, null),

-- Business 8: Lashes & Brows (staff 022-024, services 032-036)
('d1000001-0000-4000-8000-000000000051', 'c1000001-0000-4000-8000-000000000022', 'b1000001-0000-4000-8000-000000000032', null, null),
('d1000001-0000-4000-8000-000000000052', 'c1000001-0000-4000-8000-000000000022', 'b1000001-0000-4000-8000-000000000034', null, null),
('d1000001-0000-4000-8000-000000000053', 'c1000001-0000-4000-8000-000000000023', 'b1000001-0000-4000-8000-000000000032', null, null),
('d1000001-0000-4000-8000-000000000054', 'c1000001-0000-4000-8000-000000000023', 'b1000001-0000-4000-8000-000000000033', null, null),
('d1000001-0000-4000-8000-000000000055', 'c1000001-0000-4000-8000-000000000023', 'b1000001-0000-4000-8000-000000000035', null, null),
('d1000001-0000-4000-8000-000000000056', 'c1000001-0000-4000-8000-000000000024', 'b1000001-0000-4000-8000-000000000033', null, null),
('d1000001-0000-4000-8000-000000000057', 'c1000001-0000-4000-8000-000000000024', 'b1000001-0000-4000-8000-000000000036', null, null),

-- Business 9: Zen Spa (staff 025-028, services 037-041)
('d1000001-0000-4000-8000-000000000058', 'c1000001-0000-4000-8000-000000000025', 'b1000001-0000-4000-8000-000000000037', null, null),
('d1000001-0000-4000-8000-000000000059', 'c1000001-0000-4000-8000-000000000025', 'b1000001-0000-4000-8000-000000000039', null, null),
('d1000001-0000-4000-8000-000000000060', 'c1000001-0000-4000-8000-000000000026', 'b1000001-0000-4000-8000-000000000037', null, null),
('d1000001-0000-4000-8000-000000000061', 'c1000001-0000-4000-8000-000000000026', 'b1000001-0000-4000-8000-000000000038', null, null),
('d1000001-0000-4000-8000-000000000062', 'c1000001-0000-4000-8000-000000000026', 'b1000001-0000-4000-8000-000000000040', null, null),
('d1000001-0000-4000-8000-000000000063', 'c1000001-0000-4000-8000-000000000027', 'b1000001-0000-4000-8000-000000000038', null, null),
('d1000001-0000-4000-8000-000000000064', 'c1000001-0000-4000-8000-000000000027', 'b1000001-0000-4000-8000-000000000040', null, null),
('d1000001-0000-4000-8000-000000000065', 'c1000001-0000-4000-8000-000000000028', 'b1000001-0000-4000-8000-000000000041', null, null),
('d1000001-0000-4000-8000-000000000066', 'c1000001-0000-4000-8000-000000000028', 'b1000001-0000-4000-8000-000000000039', null, null),

-- Business 10: La Catrina (staff 029-030, services 042-044)
('d1000001-0000-4000-8000-000000000067', 'c1000001-0000-4000-8000-000000000029', 'b1000001-0000-4000-8000-000000000042', null, null),
('d1000001-0000-4000-8000-000000000068', 'c1000001-0000-4000-8000-000000000029', 'b1000001-0000-4000-8000-000000000044', null, null),
('d1000001-0000-4000-8000-000000000069', 'c1000001-0000-4000-8000-000000000030', 'b1000001-0000-4000-8000-000000000042', null, null),
('d1000001-0000-4000-8000-000000000070', 'c1000001-0000-4000-8000-000000000030', 'b1000001-0000-4000-8000-000000000043', null, null),

-- Business 11: Maison de Beauté (staff 031-033, services 045-049)
('d1000001-0000-4000-8000-000000000071', 'c1000001-0000-4000-8000-000000000031', 'b1000001-0000-4000-8000-000000000045', null, null),
('d1000001-0000-4000-8000-000000000072', 'c1000001-0000-4000-8000-000000000031', 'b1000001-0000-4000-8000-000000000046', null, null),
('d1000001-0000-4000-8000-000000000073', 'c1000001-0000-4000-8000-000000000031', 'b1000001-0000-4000-8000-000000000048', null, null),
('d1000001-0000-4000-8000-000000000074', 'c1000001-0000-4000-8000-000000000032', 'b1000001-0000-4000-8000-000000000045', 450.00, null),
('d1000001-0000-4000-8000-000000000075', 'c1000001-0000-4000-8000-000000000032', 'b1000001-0000-4000-8000-000000000047', null, null),
('d1000001-0000-4000-8000-000000000076', 'c1000001-0000-4000-8000-000000000032', 'b1000001-0000-4000-8000-000000000049', null, null),
('d1000001-0000-4000-8000-000000000077', 'c1000001-0000-4000-8000-000000000033', 'b1000001-0000-4000-8000-000000000047', null, null),
('d1000001-0000-4000-8000-000000000078', 'c1000001-0000-4000-8000-000000000033', 'b1000001-0000-4000-8000-000000000048', null, null),

-- Business 12: Salón Frida (staff 034-035, services 050-053)
('d1000001-0000-4000-8000-000000000079', 'c1000001-0000-4000-8000-000000000034', 'b1000001-0000-4000-8000-000000000050', null, null),
('d1000001-0000-4000-8000-000000000080', 'c1000001-0000-4000-8000-000000000034', 'b1000001-0000-4000-8000-000000000051', null, null),
('d1000001-0000-4000-8000-000000000081', 'c1000001-0000-4000-8000-000000000034', 'b1000001-0000-4000-8000-000000000053', null, null),
('d1000001-0000-4000-8000-000000000082', 'c1000001-0000-4000-8000-000000000035', 'b1000001-0000-4000-8000-000000000050', null, null),
('d1000001-0000-4000-8000-000000000083', 'c1000001-0000-4000-8000-000000000035', 'b1000001-0000-4000-8000-000000000052', null, null),

-- Business 13: Aura Nail Bar (staff 036-038, services 054-057)
('d1000001-0000-4000-8000-000000000084', 'c1000001-0000-4000-8000-000000000036', 'b1000001-0000-4000-8000-000000000054', null, null),
('d1000001-0000-4000-8000-000000000085', 'c1000001-0000-4000-8000-000000000036', 'b1000001-0000-4000-8000-000000000055', null, null),
('d1000001-0000-4000-8000-000000000086', 'c1000001-0000-4000-8000-000000000037', 'b1000001-0000-4000-8000-000000000054', null, null),
('d1000001-0000-4000-8000-000000000087', 'c1000001-0000-4000-8000-000000000037', 'b1000001-0000-4000-8000-000000000056', null, null),
('d1000001-0000-4000-8000-000000000088', 'c1000001-0000-4000-8000-000000000037', 'b1000001-0000-4000-8000-000000000057', null, null),
('d1000001-0000-4000-8000-000000000089', 'c1000001-0000-4000-8000-000000000038', 'b1000001-0000-4000-8000-000000000054', null, null),
('d1000001-0000-4000-8000-000000000090', 'c1000001-0000-4000-8000-000000000038', 'b1000001-0000-4000-8000-000000000056', null, null),

-- Business 14: Pelo Perfecto (staff 039-040, services 058-061)
('d1000001-0000-4000-8000-000000000091', 'c1000001-0000-4000-8000-000000000039', 'b1000001-0000-4000-8000-000000000058', null, null),
('d1000001-0000-4000-8000-000000000092', 'c1000001-0000-4000-8000-000000000039', 'b1000001-0000-4000-8000-000000000059', null, null),
('d1000001-0000-4000-8000-000000000093', 'c1000001-0000-4000-8000-000000000039', 'b1000001-0000-4000-8000-000000000060', null, null),
('d1000001-0000-4000-8000-000000000094', 'c1000001-0000-4000-8000-000000000040', 'b1000001-0000-4000-8000-000000000058', 250.00, null),
('d1000001-0000-4000-8000-000000000095', 'c1000001-0000-4000-8000-000000000040', 'b1000001-0000-4000-8000-000000000061', null, null),

-- Business 15: Manos Mágicas (staff 041-043, services 062-066)
('d1000001-0000-4000-8000-000000000096', 'c1000001-0000-4000-8000-000000000041', 'b1000001-0000-4000-8000-000000000062', null, null),
('d1000001-0000-4000-8000-000000000097', 'c1000001-0000-4000-8000-000000000041', 'b1000001-0000-4000-8000-000000000064', null, null),
('d1000001-0000-4000-8000-000000000098', 'c1000001-0000-4000-8000-000000000041', 'b1000001-0000-4000-8000-000000000065', null, null),
('d1000001-0000-4000-8000-000000000099', 'c1000001-0000-4000-8000-000000000042', 'b1000001-0000-4000-8000-000000000062', null, null),
('d1000001-0000-4000-8000-000000000100', 'c1000001-0000-4000-8000-000000000042', 'b1000001-0000-4000-8000-000000000063', null, null),
('d1000001-0000-4000-8000-000000000101', 'c1000001-0000-4000-8000-000000000042', 'b1000001-0000-4000-8000-000000000066', null, null),
('d1000001-0000-4000-8000-000000000102', 'c1000001-0000-4000-8000-000000000043', 'b1000001-0000-4000-8000-000000000063', null, null),
('d1000001-0000-4000-8000-000000000103', 'c1000001-0000-4000-8000-000000000043', 'b1000001-0000-4000-8000-000000000066', null, null);


-- =============================================================================
-- 9. STAFF_SCHEDULES (Mon-Sat for each staff, some with mid-week off)
-- UUIDs: e1000001-0000-4000-8000-XXXXXXXXXXXX
-- day_of_week: 0=Sunday, 1=Monday, ..., 6=Saturday
-- Typical Mexican salon hours: Mon-Fri 9/10-19/20, Sat 9/10-15/17
-- =============================================================================

INSERT INTO staff_schedules (id, staff_id, day_of_week, start_time, end_time, is_available) VALUES
-- Staff 001: María García (Mon-Sat, off Sunday)
('e1000001-0000-4000-8000-000000000001', 'c1000001-0000-4000-8000-000000000001', 1, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000002', 'c1000001-0000-4000-8000-000000000001', 2, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000003', 'c1000001-0000-4000-8000-000000000001', 3, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000004', 'c1000001-0000-4000-8000-000000000001', 4, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000005', 'c1000001-0000-4000-8000-000000000001', 5, '09:00', '21:00', true),
('e1000001-0000-4000-8000-000000000006', 'c1000001-0000-4000-8000-000000000001', 6, '09:00', '18:00', true),

-- Staff 002: Lupita Hernández (Tue-Sat, off Mon/Sun)
('e1000001-0000-4000-8000-000000000007', 'c1000001-0000-4000-8000-000000000002', 2, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000008', 'c1000001-0000-4000-8000-000000000002', 3, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000009', 'c1000001-0000-4000-8000-000000000002', 4, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000010', 'c1000001-0000-4000-8000-000000000002', 5, '09:00', '21:00', true),
('e1000001-0000-4000-8000-000000000011', 'c1000001-0000-4000-8000-000000000002', 6, '09:00', '18:00', true),

-- Staff 003: Andrea Martínez (Mon-Fri, off Sat/Sun)
('e1000001-0000-4000-8000-000000000012', 'c1000001-0000-4000-8000-000000000003', 1, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000013', 'c1000001-0000-4000-8000-000000000003', 2, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000014', 'c1000001-0000-4000-8000-000000000003', 3, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000015', 'c1000001-0000-4000-8000-000000000003', 4, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000016', 'c1000001-0000-4000-8000-000000000003', 5, '10:00', '20:00', true),

-- Staff 004-006: Glamour Providencia (Mon-Sat typical)
('e1000001-0000-4000-8000-000000000017', 'c1000001-0000-4000-8000-000000000004', 1, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000018', 'c1000001-0000-4000-8000-000000000004', 2, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000019', 'c1000001-0000-4000-8000-000000000004', 3, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000020', 'c1000001-0000-4000-8000-000000000004', 4, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000021', 'c1000001-0000-4000-8000-000000000004', 5, '10:00', '21:00', true),
('e1000001-0000-4000-8000-000000000022', 'c1000001-0000-4000-8000-000000000004', 6, '09:00', '17:00', true),

('e1000001-0000-4000-8000-000000000023', 'c1000001-0000-4000-8000-000000000005', 1, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000024', 'c1000001-0000-4000-8000-000000000005', 2, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000025', 'c1000001-0000-4000-8000-000000000005', 3, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000026', 'c1000001-0000-4000-8000-000000000005', 4, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000027', 'c1000001-0000-4000-8000-000000000005', 5, '10:00', '21:00', true),
('e1000001-0000-4000-8000-000000000028', 'c1000001-0000-4000-8000-000000000005', 6, '09:00', '17:00', true),

('e1000001-0000-4000-8000-000000000029', 'c1000001-0000-4000-8000-000000000006', 2, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000030', 'c1000001-0000-4000-8000-000000000006', 3, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000031', 'c1000001-0000-4000-8000-000000000006', 4, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000032', 'c1000001-0000-4000-8000-000000000006', 5, '10:00', '21:00', true),
('e1000001-0000-4000-8000-000000000033', 'c1000001-0000-4000-8000-000000000006', 6, '09:00', '17:00', true),

-- Staff 007-010: Nails & Co (Mon-Sat, staggered offs)
('e1000001-0000-4000-8000-000000000034', 'c1000001-0000-4000-8000-000000000007', 1, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000035', 'c1000001-0000-4000-8000-000000000007', 2, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000036', 'c1000001-0000-4000-8000-000000000007', 3, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000037', 'c1000001-0000-4000-8000-000000000007', 4, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000038', 'c1000001-0000-4000-8000-000000000007', 5, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000039', 'c1000001-0000-4000-8000-000000000007', 6, '10:00', '17:00', true),

('e1000001-0000-4000-8000-000000000040', 'c1000001-0000-4000-8000-000000000008', 1, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000041', 'c1000001-0000-4000-8000-000000000008', 2, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000042', 'c1000001-0000-4000-8000-000000000008', 3, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000043', 'c1000001-0000-4000-8000-000000000008', 4, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000044', 'c1000001-0000-4000-8000-000000000008', 5, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000045', 'c1000001-0000-4000-8000-000000000008', 6, '10:00', '17:00', true),

-- Staff 009: Fernanda Díaz (Mon-Sat, Nails & Co)
('e1000001-0000-4000-8000-000000000046', 'c1000001-0000-4000-8000-000000000009', 1, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000047', 'c1000001-0000-4000-8000-000000000009', 2, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000048', 'c1000001-0000-4000-8000-000000000009', 3, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000049', 'c1000001-0000-4000-8000-000000000009', 4, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000050', 'c1000001-0000-4000-8000-000000000009', 5, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000051', 'c1000001-0000-4000-8000-000000000009', 6, '10:00', '17:00', true),

-- Staff 010: Mariana Vega (Tue-Sat, off Mon, Nails & Co)
('e1000001-0000-4000-8000-000000000052', 'c1000001-0000-4000-8000-000000000010', 2, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000053', 'c1000001-0000-4000-8000-000000000010', 3, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000054', 'c1000001-0000-4000-8000-000000000010', 4, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000055', 'c1000001-0000-4000-8000-000000000010', 5, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000056', 'c1000001-0000-4000-8000-000000000010', 6, '10:00', '17:00', true),

-- Staff 011: Rosa Flores (Mon-Sat, Spa Raíces 9-19 / Sat 9-15)
('e1000001-0000-4000-8000-000000000057', 'c1000001-0000-4000-8000-000000000011', 1, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000058', 'c1000001-0000-4000-8000-000000000011', 2, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000059', 'c1000001-0000-4000-8000-000000000011', 3, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000060', 'c1000001-0000-4000-8000-000000000011', 4, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000061', 'c1000001-0000-4000-8000-000000000011', 5, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000062', 'c1000001-0000-4000-8000-000000000011', 6, '09:00', '15:00', true),

-- Staff 012: Carmen Morales (Mon-Sat, Spa Raíces)
('e1000001-0000-4000-8000-000000000063', 'c1000001-0000-4000-8000-000000000012', 1, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000064', 'c1000001-0000-4000-8000-000000000012', 2, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000065', 'c1000001-0000-4000-8000-000000000012', 3, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000066', 'c1000001-0000-4000-8000-000000000012', 4, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000067', 'c1000001-0000-4000-8000-000000000012', 5, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000068', 'c1000001-0000-4000-8000-000000000012', 6, '09:00', '15:00', true),

-- Staff 013: Elena Cruz (Tue-Sat, off Mon, Spa Raíces)
('e1000001-0000-4000-8000-000000000069', 'c1000001-0000-4000-8000-000000000013', 2, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000070', 'c1000001-0000-4000-8000-000000000013', 3, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000071', 'c1000001-0000-4000-8000-000000000013', 4, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000072', 'c1000001-0000-4000-8000-000000000013', 5, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000073', 'c1000001-0000-4000-8000-000000000013', 6, '09:00', '15:00', true),

-- Staff 014: Roberto Jiménez (Mon-Sat, Studio 33 Hair Design 10-20 / Sat 10-16)
('e1000001-0000-4000-8000-000000000074', 'c1000001-0000-4000-8000-000000000014', 1, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000075', 'c1000001-0000-4000-8000-000000000014', 2, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000076', 'c1000001-0000-4000-8000-000000000014', 3, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000077', 'c1000001-0000-4000-8000-000000000014', 4, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000078', 'c1000001-0000-4000-8000-000000000014', 5, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000079', 'c1000001-0000-4000-8000-000000000014', 6, '10:00', '16:00', true),

-- Staff 015: Diana Reyes (Mon-Fri, off Sat/Sun, Studio 33)
('e1000001-0000-4000-8000-000000000080', 'c1000001-0000-4000-8000-000000000015', 1, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000081', 'c1000001-0000-4000-8000-000000000015', 2, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000082', 'c1000001-0000-4000-8000-000000000015', 3, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000083', 'c1000001-0000-4000-8000-000000000015', 4, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000084', 'c1000001-0000-4000-8000-000000000015', 5, '10:00', '20:00', true),

-- Staff 016: Dra. Alejandra Navarro (Mon-Sat, Dermika 9-20 / Sat 9-15)
('e1000001-0000-4000-8000-000000000085', 'c1000001-0000-4000-8000-000000000016', 1, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000086', 'c1000001-0000-4000-8000-000000000016', 2, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000087', 'c1000001-0000-4000-8000-000000000016', 3, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000088', 'c1000001-0000-4000-8000-000000000016', 4, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000089', 'c1000001-0000-4000-8000-000000000016', 5, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000090', 'c1000001-0000-4000-8000-000000000016', 6, '09:00', '15:00', true),

-- Staff 017: Gabriela Mendoza (Mon-Sat, Dermika)
('e1000001-0000-4000-8000-000000000091', 'c1000001-0000-4000-8000-000000000017', 1, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000092', 'c1000001-0000-4000-8000-000000000017', 2, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000093', 'c1000001-0000-4000-8000-000000000017', 3, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000094', 'c1000001-0000-4000-8000-000000000017', 4, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000095', 'c1000001-0000-4000-8000-000000000017', 5, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000096', 'c1000001-0000-4000-8000-000000000017', 6, '09:00', '15:00', true),

-- Staff 018: Isabel Vargas (Tue-Sat, off Mon, Dermika)
('e1000001-0000-4000-8000-000000000097', 'c1000001-0000-4000-8000-000000000018', 2, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000098', 'c1000001-0000-4000-8000-000000000018', 3, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000099', 'c1000001-0000-4000-8000-000000000018', 4, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000100', 'c1000001-0000-4000-8000-000000000018', 5, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000101', 'c1000001-0000-4000-8000-000000000018', 6, '09:00', '15:00', true),

-- Staff 019: Jesús Ortega (Mon-Sat, Las Tijeras de Oro 9-19 / Sat 9-16)
('e1000001-0000-4000-8000-000000000102', 'c1000001-0000-4000-8000-000000000019', 1, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000103', 'c1000001-0000-4000-8000-000000000019', 2, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000104', 'c1000001-0000-4000-8000-000000000019', 3, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000105', 'c1000001-0000-4000-8000-000000000019', 4, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000106', 'c1000001-0000-4000-8000-000000000019', 5, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000107', 'c1000001-0000-4000-8000-000000000019', 6, '09:00', '16:00', true),

-- Staff 020: Lucía Castillo (Mon-Sat, Las Tijeras de Oro)
('e1000001-0000-4000-8000-000000000108', 'c1000001-0000-4000-8000-000000000020', 1, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000109', 'c1000001-0000-4000-8000-000000000020', 2, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000110', 'c1000001-0000-4000-8000-000000000020', 3, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000111', 'c1000001-0000-4000-8000-000000000020', 4, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000112', 'c1000001-0000-4000-8000-000000000020', 5, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000113', 'c1000001-0000-4000-8000-000000000020', 6, '09:00', '16:00', true),

-- Staff 021: Miguel Peña (Tue-Sat, off Mon, Las Tijeras de Oro)
('e1000001-0000-4000-8000-000000000114', 'c1000001-0000-4000-8000-000000000021', 2, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000115', 'c1000001-0000-4000-8000-000000000021', 3, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000116', 'c1000001-0000-4000-8000-000000000021', 4, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000117', 'c1000001-0000-4000-8000-000000000021', 5, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000118', 'c1000001-0000-4000-8000-000000000021', 6, '09:00', '16:00', true),

-- Staff 022: Natalia Aguilar (Mon-Sat, Lashes & Brows 10-19 / Sat 10-16)
('e1000001-0000-4000-8000-000000000119', 'c1000001-0000-4000-8000-000000000022', 1, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000120', 'c1000001-0000-4000-8000-000000000022', 2, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000121', 'c1000001-0000-4000-8000-000000000022', 3, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000122', 'c1000001-0000-4000-8000-000000000022', 4, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000123', 'c1000001-0000-4000-8000-000000000022', 5, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000124', 'c1000001-0000-4000-8000-000000000022', 6, '10:00', '16:00', true),

-- Staff 023: Jessica Rojas (Mon-Sat, Lashes & Brows)
('e1000001-0000-4000-8000-000000000125', 'c1000001-0000-4000-8000-000000000023', 1, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000126', 'c1000001-0000-4000-8000-000000000023', 2, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000127', 'c1000001-0000-4000-8000-000000000023', 3, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000128', 'c1000001-0000-4000-8000-000000000023', 4, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000129', 'c1000001-0000-4000-8000-000000000023', 5, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000130', 'c1000001-0000-4000-8000-000000000023', 6, '10:00', '16:00', true),

-- Staff 024: Adriana Guerrero (Tue-Sat, off Mon, Lashes & Brows)
('e1000001-0000-4000-8000-000000000131', 'c1000001-0000-4000-8000-000000000024', 2, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000132', 'c1000001-0000-4000-8000-000000000024', 3, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000133', 'c1000001-0000-4000-8000-000000000024', 4, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000134', 'c1000001-0000-4000-8000-000000000024', 5, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000135', 'c1000001-0000-4000-8000-000000000024', 6, '10:00', '16:00', true),

-- Staff 025: Patricia Medina (Mon-Sat, Zen Spa 9-20 / Sat 9-15)
('e1000001-0000-4000-8000-000000000136', 'c1000001-0000-4000-8000-000000000025', 1, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000137', 'c1000001-0000-4000-8000-000000000025', 2, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000138', 'c1000001-0000-4000-8000-000000000025', 3, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000139', 'c1000001-0000-4000-8000-000000000025', 4, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000140', 'c1000001-0000-4000-8000-000000000025', 5, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000141', 'c1000001-0000-4000-8000-000000000025', 6, '09:00', '15:00', true),

-- Staff 026: Laura Guzmán (Mon-Sat, Zen Spa)
('e1000001-0000-4000-8000-000000000142', 'c1000001-0000-4000-8000-000000000026', 1, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000143', 'c1000001-0000-4000-8000-000000000026', 2, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000144', 'c1000001-0000-4000-8000-000000000026', 3, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000145', 'c1000001-0000-4000-8000-000000000026', 4, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000146', 'c1000001-0000-4000-8000-000000000026', 5, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000147', 'c1000001-0000-4000-8000-000000000026', 6, '09:00', '15:00', true),

-- Staff 027: Raquel Salazar (Mon-Fri, off Sat/Sun, Zen Spa)
('e1000001-0000-4000-8000-000000000148', 'c1000001-0000-4000-8000-000000000027', 1, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000149', 'c1000001-0000-4000-8000-000000000027', 2, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000150', 'c1000001-0000-4000-8000-000000000027', 3, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000151', 'c1000001-0000-4000-8000-000000000027', 4, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000152', 'c1000001-0000-4000-8000-000000000027', 5, '09:00', '20:00', true),

-- Staff 028: Eduardo Domínguez (Tue-Sat, off Mon, Zen Spa)
('e1000001-0000-4000-8000-000000000153', 'c1000001-0000-4000-8000-000000000028', 2, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000154', 'c1000001-0000-4000-8000-000000000028', 3, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000155', 'c1000001-0000-4000-8000-000000000028', 4, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000156', 'c1000001-0000-4000-8000-000000000028', 5, '09:00', '20:00', true),
('e1000001-0000-4000-8000-000000000157', 'c1000001-0000-4000-8000-000000000028', 6, '09:00', '15:00', true),

-- Staff 029: Claudia Ruiz (Mon-Sat, Estética La Catrina 9-18 / Sat 9-15)
('e1000001-0000-4000-8000-000000000158', 'c1000001-0000-4000-8000-000000000029', 1, '09:00', '18:00', true),
('e1000001-0000-4000-8000-000000000159', 'c1000001-0000-4000-8000-000000000029', 2, '09:00', '18:00', true),
('e1000001-0000-4000-8000-000000000160', 'c1000001-0000-4000-8000-000000000029', 3, '09:00', '18:00', true),
('e1000001-0000-4000-8000-000000000161', 'c1000001-0000-4000-8000-000000000029', 4, '09:00', '18:00', true),
('e1000001-0000-4000-8000-000000000162', 'c1000001-0000-4000-8000-000000000029', 5, '09:00', '18:00', true),
('e1000001-0000-4000-8000-000000000163', 'c1000001-0000-4000-8000-000000000029', 6, '09:00', '15:00', true),

-- Staff 030: Susana Herrera (Mon-Fri, off Sat/Sun, La Catrina)
('e1000001-0000-4000-8000-000000000164', 'c1000001-0000-4000-8000-000000000030', 1, '09:00', '18:00', true),
('e1000001-0000-4000-8000-000000000165', 'c1000001-0000-4000-8000-000000000030', 2, '09:00', '18:00', true),
('e1000001-0000-4000-8000-000000000166', 'c1000001-0000-4000-8000-000000000030', 3, '09:00', '18:00', true),
('e1000001-0000-4000-8000-000000000167', 'c1000001-0000-4000-8000-000000000030', 4, '09:00', '18:00', true),
('e1000001-0000-4000-8000-000000000168', 'c1000001-0000-4000-8000-000000000030', 5, '09:00', '18:00', true),

-- Staff 031: Renata Delgado (Mon-Sat, Maison de Beauté 10-20 / Sat 10-17)
('e1000001-0000-4000-8000-000000000169', 'c1000001-0000-4000-8000-000000000031', 1, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000170', 'c1000001-0000-4000-8000-000000000031', 2, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000171', 'c1000001-0000-4000-8000-000000000031', 3, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000172', 'c1000001-0000-4000-8000-000000000031', 4, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000173', 'c1000001-0000-4000-8000-000000000031', 5, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000174', 'c1000001-0000-4000-8000-000000000031', 6, '10:00', '17:00', true),

-- Staff 032: Camila Santos (Mon-Sat, Maison de Beauté)
('e1000001-0000-4000-8000-000000000175', 'c1000001-0000-4000-8000-000000000032', 1, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000176', 'c1000001-0000-4000-8000-000000000032', 2, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000177', 'c1000001-0000-4000-8000-000000000032', 3, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000178', 'c1000001-0000-4000-8000-000000000032', 4, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000179', 'c1000001-0000-4000-8000-000000000032', 5, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000180', 'c1000001-0000-4000-8000-000000000032', 6, '10:00', '17:00', true),

-- Staff 033: Victoria Núñez (Tue-Sat, off Mon, Maison de Beauté)
('e1000001-0000-4000-8000-000000000181', 'c1000001-0000-4000-8000-000000000033', 2, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000182', 'c1000001-0000-4000-8000-000000000033', 3, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000183', 'c1000001-0000-4000-8000-000000000033', 4, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000184', 'c1000001-0000-4000-8000-000000000033', 5, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000185', 'c1000001-0000-4000-8000-000000000033', 6, '10:00', '17:00', true),

-- Staff 034: Frida Castro (Mon-Sat, Salón Frida 9-19 / Sat 9-15)
('e1000001-0000-4000-8000-000000000186', 'c1000001-0000-4000-8000-000000000034', 1, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000187', 'c1000001-0000-4000-8000-000000000034', 2, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000188', 'c1000001-0000-4000-8000-000000000034', 3, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000189', 'c1000001-0000-4000-8000-000000000034', 4, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000190', 'c1000001-0000-4000-8000-000000000034', 5, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000191', 'c1000001-0000-4000-8000-000000000034', 6, '09:00', '15:00', true),

-- Staff 035: Beatriz Ramos (Mon-Fri, off Sat/Sun, Salón Frida)
('e1000001-0000-4000-8000-000000000192', 'c1000001-0000-4000-8000-000000000035', 1, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000193', 'c1000001-0000-4000-8000-000000000035', 2, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000194', 'c1000001-0000-4000-8000-000000000035', 3, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000195', 'c1000001-0000-4000-8000-000000000035', 4, '09:00', '19:00', true),
('e1000001-0000-4000-8000-000000000196', 'c1000001-0000-4000-8000-000000000035', 5, '09:00', '19:00', true),

-- Staff 036: Ximena Campos (Mon-Sat, Aura Nail Bar 10-19 / Sat 10-16)
('e1000001-0000-4000-8000-000000000197', 'c1000001-0000-4000-8000-000000000036', 1, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000198', 'c1000001-0000-4000-8000-000000000036', 2, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000199', 'c1000001-0000-4000-8000-000000000036', 3, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000200', 'c1000001-0000-4000-8000-000000000036', 4, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000201', 'c1000001-0000-4000-8000-000000000036', 5, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000202', 'c1000001-0000-4000-8000-000000000036', 6, '10:00', '16:00', true),

-- Staff 037: Paulina Fuentes (Mon-Sat, Aura Nail Bar)
('e1000001-0000-4000-8000-000000000203', 'c1000001-0000-4000-8000-000000000037', 1, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000204', 'c1000001-0000-4000-8000-000000000037', 2, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000205', 'c1000001-0000-4000-8000-000000000037', 3, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000206', 'c1000001-0000-4000-8000-000000000037', 4, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000207', 'c1000001-0000-4000-8000-000000000037', 5, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000208', 'c1000001-0000-4000-8000-000000000037', 6, '10:00', '16:00', true),

-- Staff 038: Regina Lara (Tue-Sat, off Mon, Aura Nail Bar)
('e1000001-0000-4000-8000-000000000209', 'c1000001-0000-4000-8000-000000000038', 2, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000210', 'c1000001-0000-4000-8000-000000000038', 3, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000211', 'c1000001-0000-4000-8000-000000000038', 4, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000212', 'c1000001-0000-4000-8000-000000000038', 5, '10:00', '19:00', true),
('e1000001-0000-4000-8000-000000000213', 'c1000001-0000-4000-8000-000000000038', 6, '10:00', '16:00', true),

-- Staff 039: Carlos Espinoza (Mon-Sat, Pelo Perfecto 10-20 / Sat 10-16)
('e1000001-0000-4000-8000-000000000214', 'c1000001-0000-4000-8000-000000000039', 1, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000215', 'c1000001-0000-4000-8000-000000000039', 2, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000216', 'c1000001-0000-4000-8000-000000000039', 3, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000217', 'c1000001-0000-4000-8000-000000000039', 4, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000218', 'c1000001-0000-4000-8000-000000000039', 5, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000219', 'c1000001-0000-4000-8000-000000000039', 6, '10:00', '16:00', true),

-- Staff 040: Alicia Velázquez (Mon-Fri, off Sat/Sun, Pelo Perfecto)
('e1000001-0000-4000-8000-000000000220', 'c1000001-0000-4000-8000-000000000040', 1, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000221', 'c1000001-0000-4000-8000-000000000040', 2, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000222', 'c1000001-0000-4000-8000-000000000040', 3, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000223', 'c1000001-0000-4000-8000-000000000040', 4, '10:00', '20:00', true),
('e1000001-0000-4000-8000-000000000224', 'c1000001-0000-4000-8000-000000000040', 5, '10:00', '20:00', true),

-- Staff 041: Teresa Acosta (Mon-Sat, Manos Mágicas 9-18 / Sat 9-15)
('e1000001-0000-4000-8000-000000000225', 'c1000001-0000-4000-8000-000000000041', 1, '09:00', '18:00', true),
('e1000001-0000-4000-8000-000000000226', 'c1000001-0000-4000-8000-000000000041', 2, '09:00', '18:00', true),
('e1000001-0000-4000-8000-000000000227', 'c1000001-0000-4000-8000-000000000041', 3, '09:00', '18:00', true),
('e1000001-0000-4000-8000-000000000228', 'c1000001-0000-4000-8000-000000000041', 4, '09:00', '18:00', true),
('e1000001-0000-4000-8000-000000000229', 'c1000001-0000-4000-8000-000000000041', 5, '09:00', '18:00', true),
('e1000001-0000-4000-8000-000000000230', 'c1000001-0000-4000-8000-000000000041', 6, '09:00', '15:00', true),

-- Staff 042: Lorena Ibarra (Mon-Sat, Manos Mágicas)
('e1000001-0000-4000-8000-000000000231', 'c1000001-0000-4000-8000-000000000042', 1, '09:00', '18:00', true),
('e1000001-0000-4000-8000-000000000232', 'c1000001-0000-4000-8000-000000000042', 2, '09:00', '18:00', true),
('e1000001-0000-4000-8000-000000000233', 'c1000001-0000-4000-8000-000000000042', 3, '09:00', '18:00', true),
('e1000001-0000-4000-8000-000000000234', 'c1000001-0000-4000-8000-000000000042', 4, '09:00', '18:00', true),
('e1000001-0000-4000-8000-000000000235', 'c1000001-0000-4000-8000-000000000042', 5, '09:00', '18:00', true),
('e1000001-0000-4000-8000-000000000236', 'c1000001-0000-4000-8000-000000000042', 6, '09:00', '15:00', true),

-- Staff 043: Sandra Montes (Tue-Sat, off Mon, Manos Mágicas)
('e1000001-0000-4000-8000-000000000237', 'c1000001-0000-4000-8000-000000000043', 2, '09:00', '18:00', true),
('e1000001-0000-4000-8000-000000000238', 'c1000001-0000-4000-8000-000000000043', 3, '09:00', '18:00', true),
('e1000001-0000-4000-8000-000000000239', 'c1000001-0000-4000-8000-000000000043', 4, '09:00', '18:00', true),
('e1000001-0000-4000-8000-000000000240', 'c1000001-0000-4000-8000-000000000043', 5, '09:00', '18:00', true),
('e1000001-0000-4000-8000-000000000241', 'c1000001-0000-4000-8000-000000000043', 6, '09:00', '15:00', true);


-- =============================================================================
-- 10. NOTIFICATION TEMPLATES
-- Templates for key booking lifecycle events.
-- Channels: whatsapp, push. Both customer and salon variants.
-- Variables: {service}, {stylist}, {salon}, {date}, {time}, {client},
--            {price}, {uber_time}, {link}, {rating_stars}
-- =============================================================================

INSERT INTO notification_templates (
  id, event_type, channel, recipient_type,
  template_es, template_en,
  required_variables, is_active
) VALUES

-- BOOKING CONFIRMED
('11000001-0000-4000-8000-000000000001', 'booking_confirmed', 'whatsapp', 'customer',
 'Tu cita está confirmada: {service} con {stylist} el {date} a las {time} en {salon}. Nos vemos pronto.',
 'Your appointment is confirmed: {service} with {stylist} on {date} at {time} at {salon}. See you soon.',
 ARRAY['service','stylist','date','time','salon'], true),

('11000001-0000-4000-8000-000000000002', 'booking_confirmed', 'push', 'customer',
 'Cita confirmada: {service} con {stylist}, {date} {time}',
 'Booking confirmed: {service} with {stylist}, {date} {time}',
 ARRAY['service','stylist','date','time'], true),

('11000001-0000-4000-8000-000000000003', 'booking_confirmed', 'whatsapp', 'salon',
 'Nueva reserva: {client} para {service} el {date} a las {time} con {stylist}.',
 'New booking: {client} for {service} on {date} at {time} with {stylist}.',
 ARRAY['client','service','date','time','stylist'], true),

('11000001-0000-4000-8000-000000000004', 'booking_confirmed', 'push', 'salon',
 'Nueva reserva: {client} · {service} · {date} {time}',
 'New booking: {client} · {service} · {date} {time}',
 ARRAY['client','service','date','time'], true),

-- REMINDER 24H
('11000001-0000-4000-8000-000000000005', 'reminder_24h', 'whatsapp', 'customer',
 'Recordatorio: {service} mañana a las {time} en {salon} con {stylist}.',
 'Reminder: {service} tomorrow at {time} at {salon} with {stylist}.',
 ARRAY['service','time','salon','stylist'], true),

('11000001-0000-4000-8000-000000000006', 'reminder_24h', 'push', 'customer',
 'Recordatorio: {service} mañana a las {time} en {salon}',
 'Reminder: {service} tomorrow at {time} at {salon}',
 ARRAY['service','time','salon'], true),

('11000001-0000-4000-8000-000000000007', 'reminder_24h', 'whatsapp', 'salon',
 'Recordatorio: {client} mañana a las {time} para {service} con {stylist}.',
 'Reminder: {client} tomorrow at {time} for {service} with {stylist}.',
 ARRAY['client','time','service','stylist'], true),

-- UBER EN ROUTE
('11000001-0000-4000-8000-000000000008', 'uber_en_route', 'push', 'customer',
 'Tu Uber está en camino. Llega en ~{uber_time} min.',
 'Your Uber is on the way. Arrives in ~{uber_time} min.',
 ARRAY['uber_time'], true),

('11000001-0000-4000-8000-000000000009', 'uber_en_route', 'whatsapp', 'salon',
 'Tu clienta {client} está en camino. Llega en ~{uber_time} min para su {service} con {stylist}.',
 'Your client {client} is on the way. Arrives in ~{uber_time} min for {service} with {stylist}.',
 ARRAY['client','uber_time','service','stylist'], true),

-- UBER REMINDER 2H
('11000001-0000-4000-8000-000000000010', 'uber_reminder_2h', 'push', 'customer',
 'Recordatorio: {service} hoy a las {time}. Tu Uber te recoge a las {uber_time}.',
 'Reminder: {service} today at {time}. Your Uber picks you up at {uber_time}.',
 ARRAY['service','time','uber_time'], true),

('11000001-0000-4000-8000-000000000011', 'uber_reminder_2h', 'whatsapp', 'customer',
 'Recordatorio: {service} hoy a las {time} en {salon}. Tu Uber te recoge a las {uber_time}. ¡Nos vemos!',
 'Reminder: {service} today at {time} at {salon}. Your Uber picks you up at {uber_time}. See you!',
 ARRAY['service','time','salon','uber_time'], true),

-- APPOINTMENT COMPLETING
('11000001-0000-4000-8000-000000000012', 'appointment_completing', 'push', 'customer',
 'Tu servicio está por terminar. Tu Uber de regreso llega pronto.',
 'Your service is about to finish. Your return Uber arrives soon.',
 ARRAY[]::text[], true),

-- APPOINTMENT COMPLETED
('11000001-0000-4000-8000-000000000013', 'appointment_completed', 'whatsapp', 'customer',
 '¿Cómo estuvo tu {service}? Deja una reseña para {stylist} en {salon}: {link}',
 'How was your {service}? Leave a review for {stylist} at {salon}: {link}',
 ARRAY['service','stylist','salon','link'], true),

('11000001-0000-4000-8000-000000000014', 'appointment_completed', 'push', 'customer',
 '¿Cómo estuvo tu {service}? Deja una reseña',
 'How was your {service}? Leave a review',
 ARRAY['service'], true),

('11000001-0000-4000-8000-000000000015', 'appointment_completed', 'push', 'salon',
 'Cita completada: {client} · {service}',
 'Appointment completed: {client} · {service}',
 ARRAY['client','service'], true),

-- CANCELLATION
('11000001-0000-4000-8000-000000000016', 'cancellation', 'whatsapp', 'customer',
 'Tu cita de {service} el {date} a las {time} en {salon} fue cancelada. Si se realizó un cargo, el reembolso se procesará en 3-5 días hábiles.',
 'Your {service} appointment on {date} at {time} at {salon} was cancelled. If a charge was made, the refund will be processed in 3-5 business days.',
 ARRAY['service','date','time','salon'], true),

('11000001-0000-4000-8000-000000000017', 'cancellation', 'push', 'customer',
 'Cita cancelada: {service} · {date} {time}',
 'Appointment cancelled: {service} · {date} {time}',
 ARRAY['service','date','time'], true),

('11000001-0000-4000-8000-000000000018', 'cancellation', 'whatsapp', 'salon',
 'Cita cancelada: {client} · {service} · {date} a las {time}.',
 'Appointment cancelled: {client} · {service} · {date} at {time}.',
 ARRAY['client','service','date','time'], true),

-- RESCHEDULE
('11000001-0000-4000-8000-000000000019', 'reschedule', 'whatsapp', 'customer',
 'Tu cita se movió a {date} a las {time}. {service} con {stylist} en {salon}. Tus Ubers se actualizaron automáticamente.',
 'Your appointment has been moved to {date} at {time}. {service} with {stylist} at {salon}. Your Ubers have been automatically updated.',
 ARRAY['date','time','service','stylist','salon'], true),

('11000001-0000-4000-8000-000000000020', 'reschedule', 'push', 'customer',
 'Cita reprogramada: {service} → {date} {time}',
 'Appointment rescheduled: {service} → {date} {time}',
 ARRAY['service','date','time'], true),

('11000001-0000-4000-8000-000000000021', 'reschedule', 'whatsapp', 'salon',
 'Cita reprogramada: {client} → {date} a las {time} para {service}.',
 'Appointment rescheduled: {client} → {date} at {time} for {service}.',
 ARRAY['client','date','time','service'], true),

-- SALON INVITED (outreach)
('11000001-0000-4000-8000-000000000022', 'salon_invited', 'whatsapp', 'salon',
 'Una clienta te recomendó en BeautyCita. Regístrate gratis en 60 segundos y recibe reservas: {link}',
 'A client recommended you on BeautyCita. Register for free in 60 seconds and receive bookings: {link}',
 ARRAY['link'], true);


-- =============================================================================
-- SEED COMPLETE
-- =============================================================================
