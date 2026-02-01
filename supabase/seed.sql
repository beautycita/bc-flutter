-- =============================================================================
-- BeautyCita Seed Data
-- 15 realistic Guadalajara beauty salons/spas with services
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Providers (15 salons across Guadalajara neighborhoods)
-- ---------------------------------------------------------------------------

insert into public.providers (id, name, phone, whatsapp, address, city, state, country, lat, lng, photo_url, rating, reviews_count, business_category, service_categories, hours, website, facebook_url, instagram_handle, is_verified, is_active)
values

-- 1. Chapultepec
(
  'a1000001-0000-4000-8000-000000000001',
  'Salón Bella Donna',
  '+523331234501',
  '+523331234501',
  'Av. Chapultepec Sur 120, Col. Americana, Guadalajara, Jalisco',
  'Guadalajara', 'Jalisco', 'MX',
  20.6736, -103.3627,
  null, 4.7, 234, 'beauty_salon',
  array['cabello', 'uñas', 'maquillaje'],
  '{"monday": {"open": "09:00", "close": "20:00"}, "tuesday": {"open": "09:00", "close": "20:00"}, "wednesday": {"open": "09:00", "close": "20:00"}, "thursday": {"open": "09:00", "close": "20:00"}, "friday": {"open": "09:00", "close": "21:00"}, "saturday": {"open": "09:00", "close": "18:00"}, "sunday": null}'::jsonb,
  null,
  'https://facebook.com/bellaDonnaGDL',
  '@belladonna.gdl',
  true, true
),

-- 2. Providencia
(
  'a1000001-0000-4000-8000-000000000002',
  'Estética Glamour Providencia',
  '+523331234502',
  '+523331234502',
  'Av. Providencia 2578, Col. Providencia, Guadalajara, Jalisco',
  'Guadalajara', 'Jalisco', 'MX',
  20.6883, -103.3916,
  null, 4.5, 187, 'beauty_salon',
  array['cabello', 'pestañas_cejas', 'maquillaje', 'uñas'],
  '{"monday": {"open": "10:00", "close": "20:00"}, "tuesday": {"open": "10:00", "close": "20:00"}, "wednesday": {"open": "10:00", "close": "20:00"}, "thursday": {"open": "10:00", "close": "20:00"}, "friday": {"open": "10:00", "close": "21:00"}, "saturday": {"open": "09:00", "close": "17:00"}, "sunday": null}'::jsonb,
  'https://glamourprovidencia.mx',
  'https://facebook.com/glamourProvidencia',
  '@glamour.providencia',
  true, true
),

-- 3. Americana
(
  'a1000001-0000-4000-8000-000000000003',
  'Nails & Co. Americana',
  '+523331234503',
  '+523331234503',
  'Av. La Paz 1845, Col. Americana, Guadalajara, Jalisco',
  'Guadalajara', 'Jalisco', 'MX',
  20.6712, -103.3601,
  null, 4.8, 312, 'nail_salon',
  array['uñas'],
  '{"monday": {"open": "10:00", "close": "19:00"}, "tuesday": {"open": "10:00", "close": "19:00"}, "wednesday": {"open": "10:00", "close": "19:00"}, "thursday": {"open": "10:00", "close": "19:00"}, "friday": {"open": "10:00", "close": "20:00"}, "saturday": {"open": "10:00", "close": "17:00"}, "sunday": null}'::jsonb,
  null,
  'https://facebook.com/nailscoamericana',
  '@nailsco.americana',
  true, true
),

-- 4. Zapopan Centro
(
  'a1000001-0000-4000-8000-000000000004',
  'Spa Raíces',
  '+523331234504',
  '+523331234504',
  'Av. Hidalgo 234, Centro, Zapopan, Jalisco',
  'Zapopan', 'Jalisco', 'MX',
  20.7230, -103.3915,
  null, 4.6, 156, 'spa',
  array['facial', 'cuerpo_spa', 'cuidado_especializado'],
  '{"monday": {"open": "09:00", "close": "19:00"}, "tuesday": {"open": "09:00", "close": "19:00"}, "wednesday": {"open": "09:00", "close": "19:00"}, "thursday": {"open": "09:00", "close": "19:00"}, "friday": {"open": "09:00", "close": "19:00"}, "saturday": {"open": "09:00", "close": "15:00"}, "sunday": null}'::jsonb,
  'https://sparaices.mx',
  'https://facebook.com/sparaices',
  '@spa.raices',
  true, true
),

-- 5. Chapalita
(
  'a1000001-0000-4000-8000-000000000005',
  'Studio 33 Hair Design',
  '+523331234505',
  '+523331234505',
  'Av. Guadalupe 1020, Chapalita, Zapopan, Jalisco',
  'Zapopan', 'Jalisco', 'MX',
  20.6820, -103.4020,
  null, 4.4, 98, 'hair_salon',
  array['cabello', 'maquillaje'],
  '{"monday": null, "tuesday": {"open": "10:00", "close": "20:00"}, "wednesday": {"open": "10:00", "close": "20:00"}, "thursday": {"open": "10:00", "close": "20:00"}, "friday": {"open": "10:00", "close": "21:00"}, "saturday": {"open": "09:00", "close": "18:00"}, "sunday": null}'::jsonb,
  null,
  null,
  '@studio33.gdl',
  false, true
),

-- 6. Colinas de San Javier
(
  'a1000001-0000-4000-8000-000000000006',
  'Dermika Centro de Belleza',
  '+523331234506',
  '+523331234506',
  'Av. Royal Country 4567, Colinas de San Javier, Zapopan, Jalisco',
  'Zapopan', 'Jalisco', 'MX',
  20.6940, -103.4145,
  null, 4.9, 421, 'beauty_salon',
  array['facial', 'cuidado_especializado', 'cuerpo_spa', 'maquillaje'],
  '{"monday": {"open": "08:00", "close": "20:00"}, "tuesday": {"open": "08:00", "close": "20:00"}, "wednesday": {"open": "08:00", "close": "20:00"}, "thursday": {"open": "08:00", "close": "20:00"}, "friday": {"open": "08:00", "close": "20:00"}, "saturday": {"open": "09:00", "close": "16:00"}, "sunday": null}'::jsonb,
  'https://dermika.mx',
  'https://facebook.com/dermikagdl',
  '@dermika.gdl',
  true, true
),

-- 7. Ladrón de Guevara
(
  'a1000001-0000-4000-8000-000000000007',
  'Las Tijeras de Oro',
  '+523331234507',
  '+523331234507',
  'Calle Marsella 450, Col. Ladrón de Guevara, Guadalajara, Jalisco',
  'Guadalajara', 'Jalisco', 'MX',
  20.6780, -103.3730,
  null, 4.3, 145, 'hair_salon',
  array['cabello', 'pestañas_cejas'],
  '{"monday": {"open": "09:00", "close": "19:00"}, "tuesday": {"open": "09:00", "close": "19:00"}, "wednesday": {"open": "09:00", "close": "19:00"}, "thursday": {"open": "09:00", "close": "19:00"}, "friday": {"open": "09:00", "close": "20:00"}, "saturday": {"open": "09:00", "close": "16:00"}, "sunday": null}'::jsonb,
  null,
  'https://facebook.com/lastijerasdeoro',
  '@tijeras.de.oro',
  false, true
),

-- 8. Monraz
(
  'a1000001-0000-4000-8000-000000000008',
  'Lashes & Brows Studio GDL',
  '+523331234508',
  '+523331234508',
  'Calle José Guadalupe Zuno 2089, Col. Monraz, Guadalajara, Jalisco',
  'Guadalajara', 'Jalisco', 'MX',
  20.6850, -103.3810,
  null, 4.7, 267, 'beauty_salon',
  array['pestañas_cejas', 'maquillaje'],
  '{"monday": {"open": "10:00", "close": "19:00"}, "tuesday": {"open": "10:00", "close": "19:00"}, "wednesday": {"open": "10:00", "close": "19:00"}, "thursday": {"open": "10:00", "close": "19:00"}, "friday": {"open": "10:00", "close": "20:00"}, "saturday": {"open": "10:00", "close": "17:00"}, "sunday": null}'::jsonb,
  null,
  'https://facebook.com/lashesbrowsgdl',
  '@lashesbrows.gdl',
  true, true
),

-- 9. Puerta de Hierro
(
  'a1000001-0000-4000-8000-000000000009',
  'Zen Spa & Wellness',
  '+523331234509',
  '+523331234509',
  'Av. Empresarios 180, Puerta de Hierro, Zapopan, Jalisco',
  'Zapopan', 'Jalisco', 'MX',
  20.7055, -103.4280,
  null, 4.8, 389, 'spa',
  array['cuerpo_spa', 'facial', 'cuidado_especializado'],
  '{"monday": {"open": "08:00", "close": "21:00"}, "tuesday": {"open": "08:00", "close": "21:00"}, "wednesday": {"open": "08:00", "close": "21:00"}, "thursday": {"open": "08:00", "close": "21:00"}, "friday": {"open": "08:00", "close": "21:00"}, "saturday": {"open": "09:00", "close": "18:00"}, "sunday": {"open": "10:00", "close": "15:00"}}'::jsonb,
  'https://zenspagdl.mx',
  'https://facebook.com/zenspagdl',
  '@zenspa.gdl',
  true, true
),

-- 10. Centro Histórico
(
  'a1000001-0000-4000-8000-000000000010',
  'Estética La Catrina',
  '+523331234510',
  '+523331234510',
  'Calle Morelos 678, Centro Histórico, Guadalajara, Jalisco',
  'Guadalajara', 'Jalisco', 'MX',
  20.6738, -103.3444,
  null, 4.1, 89, 'beauty_salon',
  array['cabello', 'uñas', 'maquillaje', 'pestañas_cejas'],
  '{"monday": {"open": "09:00", "close": "18:00"}, "tuesday": {"open": "09:00", "close": "18:00"}, "wednesday": {"open": "09:00", "close": "18:00"}, "thursday": {"open": "09:00", "close": "18:00"}, "friday": {"open": "09:00", "close": "19:00"}, "saturday": {"open": "09:00", "close": "16:00"}, "sunday": null}'::jsonb,
  null,
  'https://facebook.com/lacatrinaGDL',
  '@lacatrina.estetica',
  false, true
),

-- 11. Italia Providencia
(
  'a1000001-0000-4000-8000-000000000011',
  'Maison de Beauté',
  '+523331234511',
  '+523331234511',
  'Av. Italia 1550, Col. Italia Providencia, Guadalajara, Jalisco',
  'Guadalajara', 'Jalisco', 'MX',
  20.6900, -103.3850,
  null, 4.6, 203, 'beauty_salon',
  array['cabello', 'maquillaje', 'uñas', 'pestañas_cejas', 'facial'],
  '{"monday": {"open": "09:00", "close": "20:00"}, "tuesday": {"open": "09:00", "close": "20:00"}, "wednesday": {"open": "09:00", "close": "20:00"}, "thursday": {"open": "09:00", "close": "20:00"}, "friday": {"open": "09:00", "close": "21:00"}, "saturday": {"open": "09:00", "close": "18:00"}, "sunday": null}'::jsonb,
  'https://maisonbeaute.mx',
  'https://facebook.com/maisonbeautegdl',
  '@maison.beaute.gdl',
  true, true
),

-- 12. Tlaquepaque
(
  'a1000001-0000-4000-8000-000000000012',
  'Salón Frida',
  '+523331234512',
  '+523331234512',
  'Calle Independencia 345, Centro, Tlaquepaque, Jalisco',
  'Tlaquepaque', 'Jalisco', 'MX',
  20.6400, -103.3120,
  null, 4.3, 112, 'beauty_salon',
  array['cabello', 'uñas', 'maquillaje'],
  '{"monday": {"open": "10:00", "close": "19:00"}, "tuesday": {"open": "10:00", "close": "19:00"}, "wednesday": {"open": "10:00", "close": "19:00"}, "thursday": {"open": "10:00", "close": "19:00"}, "friday": {"open": "10:00", "close": "20:00"}, "saturday": {"open": "09:00", "close": "17:00"}, "sunday": null}'::jsonb,
  null,
  'https://facebook.com/salonfrida.tlaq',
  '@salon.frida.tlaq',
  false, true
),

-- 13. Jardines del Bosque
(
  'a1000001-0000-4000-8000-000000000013',
  'Aura Nail Bar',
  '+523331234513',
  '+523331234513',
  'Av. López Mateos Sur 2345, Jardines del Bosque, Guadalajara, Jalisco',
  'Guadalajara', 'Jalisco', 'MX',
  20.6580, -103.3740,
  null, 4.5, 178, 'nail_salon',
  array['uñas', 'pestañas_cejas'],
  '{"monday": {"open": "10:00", "close": "20:00"}, "tuesday": {"open": "10:00", "close": "20:00"}, "wednesday": {"open": "10:00", "close": "20:00"}, "thursday": {"open": "10:00", "close": "20:00"}, "friday": {"open": "10:00", "close": "21:00"}, "saturday": {"open": "10:00", "close": "18:00"}, "sunday": null}'::jsonb,
  null,
  'https://facebook.com/auranailbar',
  '@aura.nailbar',
  true, true
),

-- 14. Andares / Patria
(
  'a1000001-0000-4000-8000-000000000014',
  'Pelo Perfecto Salón',
  '+523331234514',
  '+523331234514',
  'Av. Patria 1250, Jardines Universidad, Zapopan, Jalisco',
  'Zapopan', 'Jalisco', 'MX',
  20.7010, -103.4100,
  null, 4.4, 165, 'hair_salon',
  array['cabello', 'cuidado_especializado'],
  '{"monday": {"open": "09:00", "close": "19:00"}, "tuesday": {"open": "09:00", "close": "19:00"}, "wednesday": {"open": "09:00", "close": "19:00"}, "thursday": {"open": "09:00", "close": "19:00"}, "friday": {"open": "09:00", "close": "20:00"}, "saturday": {"open": "09:00", "close": "17:00"}, "sunday": null}'::jsonb,
  null,
  null,
  '@pelo.perfecto.gdl',
  false, true
),

-- 15. Santa Tere
(
  'a1000001-0000-4000-8000-000000000015',
  'Manos Mágicas Beauty',
  '+523331234515',
  '+523331234515',
  'Calle Jesús García 890, Col. Santa Teresita, Guadalajara, Jalisco',
  'Guadalajara', 'Jalisco', 'MX',
  20.6790, -103.3530,
  null, 4.2, 76, 'beauty_salon',
  array['uñas', 'cabello', 'pestañas_cejas', 'maquillaje'],
  '{"monday": {"open": "09:00", "close": "18:00"}, "tuesday": {"open": "09:00", "close": "18:00"}, "wednesday": {"open": "09:00", "close": "18:00"}, "thursday": {"open": "09:00", "close": "18:00"}, "friday": {"open": "09:00", "close": "19:00"}, "saturday": {"open": "09:00", "close": "15:00"}, "sunday": null}'::jsonb,
  null,
  'https://facebook.com/manosmagicasbeauty',
  '@manos.magicas.beauty',
  false, true
);


-- ---------------------------------------------------------------------------
-- Provider Services (3-5 services per provider, realistic MXN pricing)
-- ---------------------------------------------------------------------------

insert into public.provider_services (id, provider_id, category, subcategory, service_name, price_min, price_max, duration_minutes, is_active)
values

-- Provider 1: Salón Bella Donna (cabello, uñas, maquillaje)
('b1000001-0000-4000-8000-000000000001', 'a1000001-0000-4000-8000-000000000001', 'cabello', 'corte', 'Corte de Cabello Dama', 250.00, 450.00, 45, true),
('b1000001-0000-4000-8000-000000000002', 'a1000001-0000-4000-8000-000000000001', 'cabello', 'color', 'Tinte Completo', 800.00, 1500.00, 120, true),
('b1000001-0000-4000-8000-000000000003', 'a1000001-0000-4000-8000-000000000001', 'uñas', 'manicure', 'Manicure Tradicional', 250.00, 350.00, 45, true),
('b1000001-0000-4000-8000-000000000004', 'a1000001-0000-4000-8000-000000000001', 'maquillaje', 'social', 'Maquillaje para Evento', 800.00, 1200.00, 60, true),

-- Provider 2: Estética Glamour Providencia (cabello, pestañas_cejas, maquillaje, uñas)
('b1000001-0000-4000-8000-000000000005', 'a1000001-0000-4000-8000-000000000002', 'cabello', 'corte', 'Corte y Peinado', 300.00, 500.00, 60, true),
('b1000001-0000-4000-8000-000000000006', 'a1000001-0000-4000-8000-000000000002', 'cabello', 'tratamiento', 'Keratina Brasileña', 1200.00, 2500.00, 150, true),
('b1000001-0000-4000-8000-000000000007', 'a1000001-0000-4000-8000-000000000002', 'pestañas_cejas', 'pestañas', 'Extensiones de Pestañas Clásicas', 600.00, 900.00, 90, true),
('b1000001-0000-4000-8000-000000000008', 'a1000001-0000-4000-8000-000000000002', 'maquillaje', 'novia', 'Maquillaje de Novia', 1500.00, 2500.00, 90, true),
('b1000001-0000-4000-8000-000000000009', 'a1000001-0000-4000-8000-000000000002', 'uñas', 'gelish', 'Uñas Gelish', 350.00, 450.00, 50, true),

-- Provider 3: Nails & Co. Americana (uñas)
('b1000001-0000-4000-8000-000000000010', 'a1000001-0000-4000-8000-000000000003', 'uñas', 'manicure', 'Manicure Express', 200.00, 280.00, 30, true),
('b1000001-0000-4000-8000-000000000011', 'a1000001-0000-4000-8000-000000000003', 'uñas', 'acrilicas', 'Uñas Acrílicas Set Completo', 450.00, 700.00, 90, true),
('b1000001-0000-4000-8000-000000000012', 'a1000001-0000-4000-8000-000000000003', 'uñas', 'gelish', 'Gelish con Diseño', 380.00, 500.00, 60, true),
('b1000001-0000-4000-8000-000000000013', 'a1000001-0000-4000-8000-000000000003', 'uñas', 'pedicure', 'Pedicure Spa', 300.00, 400.00, 50, true),
('b1000001-0000-4000-8000-000000000014', 'a1000001-0000-4000-8000-000000000003', 'uñas', 'acrilicas', 'Relleno de Acrílico', 300.00, 400.00, 60, true),

-- Provider 4: Spa Raíces (facial, cuerpo_spa, cuidado_especializado)
('b1000001-0000-4000-8000-000000000015', 'a1000001-0000-4000-8000-000000000004', 'facial', 'limpieza', 'Limpieza Facial Profunda', 600.00, 900.00, 60, true),
('b1000001-0000-4000-8000-000000000016', 'a1000001-0000-4000-8000-000000000004', 'cuerpo_spa', 'masaje', 'Masaje Relajante Cuerpo Completo', 700.00, 1000.00, 60, true),
('b1000001-0000-4000-8000-000000000017', 'a1000001-0000-4000-8000-000000000004', 'cuerpo_spa', 'masaje', 'Masaje Descontracturante', 800.00, 1100.00, 60, true),
('b1000001-0000-4000-8000-000000000018', 'a1000001-0000-4000-8000-000000000004', 'cuidado_especializado', 'exfoliacion', 'Exfoliación Corporal con Envolvimiento', 900.00, 1300.00, 90, true),

-- Provider 5: Studio 33 Hair Design (cabello, maquillaje)
('b1000001-0000-4000-8000-000000000019', 'a1000001-0000-4000-8000-000000000005', 'cabello', 'corte', 'Corte Dama con Secado', 350.00, 500.00, 60, true),
('b1000001-0000-4000-8000-000000000020', 'a1000001-0000-4000-8000-000000000005', 'cabello', 'color', 'Mechas/Balayage', 1500.00, 3000.00, 180, true),
('b1000001-0000-4000-8000-000000000021', 'a1000001-0000-4000-8000-000000000005', 'cabello', 'peinado', 'Peinado para Evento', 500.00, 800.00, 60, true),
('b1000001-0000-4000-8000-000000000022', 'a1000001-0000-4000-8000-000000000005', 'maquillaje', 'social', 'Maquillaje Social', 700.00, 1000.00, 50, true),

-- Provider 6: Dermika Centro de Belleza (facial, cuidado_especializado, cuerpo_spa, maquillaje)
('b1000001-0000-4000-8000-000000000023', 'a1000001-0000-4000-8000-000000000006', 'facial', 'anti_edad', 'Tratamiento Anti-Edad con Radiofrecuencia', 1000.00, 1800.00, 75, true),
('b1000001-0000-4000-8000-000000000024', 'a1000001-0000-4000-8000-000000000006', 'facial', 'hidratacion', 'Hidrafacial', 900.00, 1400.00, 60, true),
('b1000001-0000-4000-8000-000000000025', 'a1000001-0000-4000-8000-000000000006', 'cuidado_especializado', 'depilacion', 'Depilación Láser Zona Pequeña', 500.00, 800.00, 30, true),
('b1000001-0000-4000-8000-000000000026', 'a1000001-0000-4000-8000-000000000006', 'cuerpo_spa', 'reductivo', 'Masaje Reductivo con Aparatología', 600.00, 900.00, 50, true),
('b1000001-0000-4000-8000-000000000027', 'a1000001-0000-4000-8000-000000000006', 'maquillaje', 'social', 'Maquillaje Profesional', 900.00, 1500.00, 60, true),

-- Provider 7: Las Tijeras de Oro (cabello, pestañas_cejas)
('b1000001-0000-4000-8000-000000000028', 'a1000001-0000-4000-8000-000000000007', 'cabello', 'corte', 'Corte Caballero', 150.00, 250.00, 30, true),
('b1000001-0000-4000-8000-000000000029', 'a1000001-0000-4000-8000-000000000007', 'cabello', 'corte', 'Corte Dama', 250.00, 400.00, 45, true),
('b1000001-0000-4000-8000-000000000030', 'a1000001-0000-4000-8000-000000000007', 'cabello', 'color', 'Tinte Raíz', 500.00, 800.00, 90, true),
('b1000001-0000-4000-8000-000000000031', 'a1000001-0000-4000-8000-000000000007', 'pestañas_cejas', 'cejas', 'Diseño de Cejas con Hilo', 150.00, 250.00, 20, true),

-- Provider 8: Lashes & Brows Studio GDL (pestañas_cejas, maquillaje)
('b1000001-0000-4000-8000-000000000032', 'a1000001-0000-4000-8000-000000000008', 'pestañas_cejas', 'pestañas', 'Extensiones Volumen Ruso', 900.00, 1400.00, 120, true),
('b1000001-0000-4000-8000-000000000033', 'a1000001-0000-4000-8000-000000000008', 'pestañas_cejas', 'pestañas', 'Lifting de Pestañas', 500.00, 700.00, 60, true),
('b1000001-0000-4000-8000-000000000034', 'a1000001-0000-4000-8000-000000000008', 'pestañas_cejas', 'cejas', 'Microblading de Cejas', 2500.00, 4000.00, 120, true),
('b1000001-0000-4000-8000-000000000035', 'a1000001-0000-4000-8000-000000000008', 'pestañas_cejas', 'cejas', 'Laminado de Cejas', 400.00, 600.00, 45, true),
('b1000001-0000-4000-8000-000000000036', 'a1000001-0000-4000-8000-000000000008', 'maquillaje', 'social', 'Maquillaje + Peinado Combo', 1200.00, 1800.00, 90, true),

-- Provider 9: Zen Spa & Wellness (cuerpo_spa, facial, cuidado_especializado)
('b1000001-0000-4000-8000-000000000037', 'a1000001-0000-4000-8000-000000000009', 'cuerpo_spa', 'masaje', 'Masaje con Piedras Calientes', 900.00, 1300.00, 75, true),
('b1000001-0000-4000-8000-000000000038', 'a1000001-0000-4000-8000-000000000009', 'cuerpo_spa', 'masaje', 'Masaje de Parejas', 1600.00, 2200.00, 75, true),
('b1000001-0000-4000-8000-000000000039', 'a1000001-0000-4000-8000-000000000009', 'facial', 'limpieza', 'Facial Detox con Oxígeno', 800.00, 1200.00, 60, true),
('b1000001-0000-4000-8000-000000000040', 'a1000001-0000-4000-8000-000000000009', 'cuidado_especializado', 'drenaje', 'Drenaje Linfático Manual', 700.00, 1000.00, 60, true),
('b1000001-0000-4000-8000-000000000041', 'a1000001-0000-4000-8000-000000000009', 'cuerpo_spa', 'circuito', 'Circuito Spa (Sauna + Vapor + Jacuzzi + Masaje)', 1500.00, 2000.00, 150, true),

-- Provider 10: Estética La Catrina (cabello, uñas, maquillaje, pestañas_cejas)
('b1000001-0000-4000-8000-000000000042', 'a1000001-0000-4000-8000-000000000010', 'cabello', 'corte', 'Corte Dama Básico', 200.00, 350.00, 40, true),
('b1000001-0000-4000-8000-000000000043', 'a1000001-0000-4000-8000-000000000010', 'uñas', 'manicure', 'Manicure Semipermanente', 280.00, 380.00, 45, true),
('b1000001-0000-4000-8000-000000000044', 'a1000001-0000-4000-8000-000000000010', 'maquillaje', 'social', 'Maquillaje XV Años', 1000.00, 1600.00, 75, true),

-- Provider 11: Maison de Beauté (cabello, maquillaje, uñas, pestañas_cejas, facial)
('b1000001-0000-4000-8000-000000000045', 'a1000001-0000-4000-8000-000000000011', 'cabello', 'corte', 'Corte + Brushing', 400.00, 600.00, 60, true),
('b1000001-0000-4000-8000-000000000046', 'a1000001-0000-4000-8000-000000000011', 'cabello', 'color', 'Balayage Premium', 2000.00, 3500.00, 180, true),
('b1000001-0000-4000-8000-000000000047', 'a1000001-0000-4000-8000-000000000011', 'uñas', 'acrilicas', 'Uñas Esculpidas Acrílico', 500.00, 750.00, 90, true),
('b1000001-0000-4000-8000-000000000048', 'a1000001-0000-4000-8000-000000000011', 'pestañas_cejas', 'pestañas', 'Extensiones Pelo a Pelo', 700.00, 1000.00, 90, true),
('b1000001-0000-4000-8000-000000000049', 'a1000001-0000-4000-8000-000000000011', 'facial', 'hidratacion', 'Facial Vitamina C', 700.00, 1000.00, 50, true),

-- Provider 12: Salón Frida (cabello, uñas, maquillaje)
('b1000001-0000-4000-8000-000000000050', 'a1000001-0000-4000-8000-000000000012', 'cabello', 'corte', 'Corte y Lavado', 200.00, 350.00, 45, true),
('b1000001-0000-4000-8000-000000000051', 'a1000001-0000-4000-8000-000000000012', 'cabello', 'color', 'Mechas Tradicionales', 800.00, 1400.00, 120, true),
('b1000001-0000-4000-8000-000000000052', 'a1000001-0000-4000-8000-000000000012', 'uñas', 'gelish', 'Gelish Manos', 300.00, 400.00, 45, true),
('b1000001-0000-4000-8000-000000000053', 'a1000001-0000-4000-8000-000000000012', 'maquillaje', 'social', 'Maquillaje Natural', 500.00, 800.00, 45, true),

-- Provider 13: Aura Nail Bar (uñas, pestañas_cejas)
('b1000001-0000-4000-8000-000000000054', 'a1000001-0000-4000-8000-000000000013', 'uñas', 'manicure', 'Manicure Rusa', 350.00, 450.00, 60, true),
('b1000001-0000-4000-8000-000000000055', 'a1000001-0000-4000-8000-000000000013', 'uñas', 'acrilicas', 'Acrílico con Diseño de Autor', 600.00, 900.00, 100, true),
('b1000001-0000-4000-8000-000000000056', 'a1000001-0000-4000-8000-000000000013', 'uñas', 'pedicure', 'Pedicure con Gelish', 350.00, 450.00, 55, true),
('b1000001-0000-4000-8000-000000000057', 'a1000001-0000-4000-8000-000000000013', 'pestañas_cejas', 'cejas', 'Tinte y Diseño de Cejas', 200.00, 300.00, 25, true),

-- Provider 14: Pelo Perfecto Salón (cabello, cuidado_especializado)
('b1000001-0000-4000-8000-000000000058', 'a1000001-0000-4000-8000-000000000014', 'cabello', 'corte', 'Corte Caballero Premium', 200.00, 350.00, 35, true),
('b1000001-0000-4000-8000-000000000059', 'a1000001-0000-4000-8000-000000000014', 'cabello', 'tratamiento', 'Tratamiento de Botox Capilar', 1000.00, 1800.00, 120, true),
('b1000001-0000-4000-8000-000000000060', 'a1000001-0000-4000-8000-000000000014', 'cabello', 'color', 'Decoloración + Fantasía', 1200.00, 2200.00, 150, true),
('b1000001-0000-4000-8000-000000000061', 'a1000001-0000-4000-8000-000000000014', 'cuidado_especializado', 'tricologia', 'Diagnóstico Capilar con Microscopio', 500.00, 800.00, 45, true),

-- Provider 15: Manos Mágicas Beauty (uñas, cabello, pestañas_cejas, maquillaje)
('b1000001-0000-4000-8000-000000000062', 'a1000001-0000-4000-8000-000000000015', 'uñas', 'manicure', 'Manicure con Gelish', 280.00, 380.00, 45, true),
('b1000001-0000-4000-8000-000000000063', 'a1000001-0000-4000-8000-000000000015', 'uñas', 'acrilicas', 'Uñas Acrílicas Francesas', 400.00, 550.00, 75, true),
('b1000001-0000-4000-8000-000000000064', 'a1000001-0000-4000-8000-000000000015', 'cabello', 'corte', 'Corte Dama + Secado', 280.00, 400.00, 50, true),
('b1000001-0000-4000-8000-000000000065', 'a1000001-0000-4000-8000-000000000015', 'pestañas_cejas', 'pestañas', 'Pestañas Clásicas', 500.00, 700.00, 75, true),
('b1000001-0000-4000-8000-000000000066', 'a1000001-0000-4000-8000-000000000015', 'maquillaje', 'social', 'Maquillaje Casual', 400.00, 600.00, 40, true);
