/// Hardcoded demo data for the read-only business portal preview.
/// Based on "Salon de Vallarta" (business 64d46f47-...).
library;

abstract final class DemoData {
  static const String businessId = '64d46f47-f161-4f3b-9935-6704cc6dfed1';

  static const Map<String, dynamic> business = {
    'id': businessId,
    'owner_id': 'eef1c030-c1ae-49ec-9352-684f018c0e56',
    'name': 'Ejemplo Salon',
    'slug': 'ejemplo-salon',
    'description':
        'Belleza profesional en el corazon de Puerto Vallarta. Reserva en segundos.',
    'phone': '(322) 380-0207',
    'whatsapp': '+523223800207',
    'address': 'Calle Ejemplo 123, Colonia Ejemplo',
    'city': 'Ciudad Ejemplo',
    'state': 'Estado Ejemplo',
    'country': 'MX',
    'lat': 20.6645623744056,
    'lng': -105.230326730276,
    'photo_url': 'https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/web/img/demo-staff/salon.jpg',
    'cover_photo_url':
        'https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/web/img/demo-staff/salon.jpg',
    'average_rating': 4.75,
    'total_reviews': 16,
    'service_categories': [
      'Cabello',
      'Uñas',
      'Pestañas y Cejas',
      'Maquillaje',
      'Servicios Especiales',
      'Depilación',
    ],
    // Shape matches biz_settings_page.dart: per-day {open: bool, start/end
     // strings, breaks[{start,end}]}. The earlier {'open': '09:00'} format
     // read as time strings crashed parseBusinessHours with a bool cast.
    'hours': {
      'monday':    {'open': true,  'start': '09:00', 'end': '20:00', 'breaks': []},
      'tuesday':   {'open': true,  'start': '09:00', 'end': '20:00', 'breaks': []},
      'wednesday': {'open': true,  'start': '09:00', 'end': '20:00', 'breaks': []},
      'thursday':  {'open': true,  'start': '09:00', 'end': '20:00', 'breaks': []},
      'friday':    {'open': true,  'start': '09:00', 'end': '20:00', 'breaks': []},
      'saturday':  {'open': true,  'start': '09:00', 'end': '20:00', 'breaks': []},
      'sunday':    {'open': false, 'start': '09:00', 'end': '18:00', 'breaks': []},
    },
    'website': 'https://beautycita.com',
    'instagram': null,
    'facebook': null,
    'is_verified': true,
    'is_active': true,
    'tier': 1,
    'cancellation_hours': 24,
    'deposit_required': true,
    'deposit_percentage': 30.0,
    'auto_confirm': true,
    'accept_walkins': true,
    'stripe_account_id': 'acct_demo_salondevallarta',
    'stripe_onboarding_status': 'complete',
    'stripe_charges_enabled': true,
    'stripe_payouts_enabled': true,
    'onboarding_complete': true,
    'onboarding_step': 'complete',
    'has_services': true,
    'has_schedule': true,
    'no_show_policy': 'forfeit_deposit',
    'pos_enabled': true,
    // Salon-owned QR program (free tier) — pre-activated so the demo
    // shows the "active" state with both internal and external QRs
    // visible. Stamp is a fixed ISO string so the cache-key for the
    // const map stays stable across rebuilds.
    'free_tier_agreements_accepted_at': '2026-03-15T17:00:00Z',
    'internal_qr_slug': 'ejs-mt7q',
  };

  // ── Staff ──────────────────────────────────────────────────────────────

  static const List<Map<String, dynamic>> staff = [
    {
      'id': '261a09a2-8e09-41da-abe6-00ce582a3607',
      'business_id': businessId,
      'first_name': 'Amber',
      'last_name': 'Elizabeth',
      'avatar_url': 'https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/web/img/demo-staff/amber.jpg',
      'phone': '+523223800207',
      'experience_years': 12,
      'average_rating': 4.8,
      'total_reviews': 15,
      'is_active': true,
      'accept_online_booking': true,
      'sort_order': -1,
      'bio':
          'Fundadora y directora creativa. Maestra en corte y estilo.',
    },
    {
      'id': 'd0000001-0000-4000-8000-000000000001',
      'business_id': businessId,
      'first_name': 'Valentina',
      'last_name': 'Rios',
      'avatar_url': 'https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/web/img/demo-staff/valentina.jpg',
      'phone': null,
      'experience_years': 8,
      'average_rating': 4.9,
      'total_reviews': 12,
      'is_active': true,
      'accept_online_booking': true,
      'sort_order': 4,
      'bio':
          'Especialista en colorimetria y balayage. Certificada en Wella y Schwarzkopf.',
    },
    {
      'id': '98306b67-3d8c-44e3-9010-465e45afeb4d',
      'business_id': businessId,
      'first_name': 'Marcos',
      'last_name': 'Garcia',
      'avatar_url': 'https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/web/img/demo-staff/marcos.jpg',
      'phone': '3221215552',
      'experience_years': 4,
      'average_rating': 4.7,
      'total_reviews': 10,
      'is_active': true,
      'accept_online_booking': true,
      'sort_order': 0,
      'bio': 'Maquillista profesional y experto en depilacion.',
    },
    {
      'id': 'fcd1e90a-9811-4ea6-b672-385b2c01c7c6',
      'business_id': businessId,
      'first_name': 'Juan',
      'last_name': 'Carlos',
      'avatar_url': 'https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/web/img/demo-staff/juan.jpg',
      'phone': '+523222780020',
      'experience_years': 6,
      'average_rating': 4.5,
      'total_reviews': 11,
      'is_active': true,
      'accept_online_booking': true,
      'sort_order': 0,
      'bio': 'Especialista en tratamientos capilares y keratina.',
    },
    {
      'id': 'd0000001-0000-4000-8000-000000000002',
      'business_id': businessId,
      'first_name': 'Daniela',
      'last_name': 'Herrera',
      'avatar_url': 'https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/web/img/demo-staff/daniela.jpg',
      'phone': null,
      'experience_years': 5,
      'average_rating': 4.6,
      'total_reviews': 9,
      'is_active': true,
      'accept_online_booking': true,
      'sort_order': 5,
      'bio':
          'Experta en extensiones de pestanas, lash lift y diseno de cejas.',
    },
    {
      'id': 'd0000001-0000-4000-8000-000000000003',
      'business_id': businessId,
      'first_name': 'Andrea',
      'last_name': 'Munoz',
      'avatar_url': 'https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/web/img/demo-staff/andrea.jpg',
      'phone': null,
      'experience_years': 3,
      'average_rating': 4.8,
      'total_reviews': 8,
      'is_active': true,
      'accept_online_booking': true,
      'sort_order': 6,
      'bio':
          'Nail artist especializada en acrilicas, gel y nail art de diseno.',
    },
    {
      'id': 'd0000001-0000-4000-8000-000000000004',
      'business_id': businessId,
      'first_name': 'Sofia',
      'last_name': 'Ramirez',
      'avatar_url': 'https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/web/img/demo-staff/sofia.jpg',
      'phone': null,
      'experience_years': 7,
      'average_rating': 4.9,
      'total_reviews': 14,
      'is_active': true,
      'accept_online_booking': true,
      'sort_order': 7,
      'bio':
          'Colorista certificada L\'Oreal Professionnel. Especialista en mechas y color fantasia.',
    },
    {
      'id': 'd0000001-0000-4000-8000-000000000005',
      'business_id': businessId,
      'first_name': 'Ricardo',
      'last_name': 'Vega',
      'avatar_url': 'https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/web/img/demo-staff/ricardo.jpg',
      'phone': null,
      'experience_years': 10,
      'average_rating': 4.7,
      'total_reviews': 18,
      'is_active': true,
      'accept_online_booking': true,
      'sort_order': 8,
      'bio':
          'Barbero y estilista masculino. Cortes clasicos, fades y grooming completo.',
    },
  ];

  // ── Services ───────────────────────────────────────────────────────────

  static const List<Map<String, dynamic>> services = [
    // Cabello
    {'id': '6ffe819e-73b5-490a-9f41-8d8a10bc506d', 'business_id': businessId, 'service_type': 'corte_mujer', 'name': 'Corte y Estilo', 'category': 'Cabello', 'subcategory': null, 'price': 500.0, 'duration_minutes': 45, 'buffer_minutes': 10, 'deposit_required': true, 'deposit_percentage': 50.0, 'description': 'Corte personalizado con lavado, acondicionamiento y secado con estilo.', 'is_active': true},
    {'id': 'e0000001-0000-4000-8000-000000000001', 'business_id': businessId, 'service_type': 'balayage', 'name': 'Balayage', 'category': 'Cabello', 'subcategory': 'Color', 'price': 1800.0, 'duration_minutes': 150, 'buffer_minutes': 0, 'deposit_required': true, 'deposit_percentage': 30.0, 'description': 'Tecnica de coloracion a mano alzada para efecto natural. Incluye matiz y tratamiento post-color.', 'is_active': true},
    {'id': 'e0000001-0000-4000-8000-000000000002', 'business_id': businessId, 'service_type': 'retoque_raiz', 'name': 'Tinte Raiz', 'category': 'Cabello', 'subcategory': 'Color', 'price': 800.0, 'duration_minutes': 90, 'buffer_minutes': 0, 'deposit_required': true, 'deposit_percentage': 30.0, 'description': 'Retoque de raiz con tinte profesional. Incluye lavado, matiz y secado.', 'is_active': true},
    {'id': 'e0000001-0000-4000-8000-000000000003', 'business_id': businessId, 'service_type': 'keratina_alisado', 'name': 'Alisado Keratina', 'category': 'Cabello', 'subcategory': 'Tratamiento', 'price': 2500.0, 'duration_minutes': 180, 'buffer_minutes': 0, 'deposit_required': true, 'deposit_percentage': 30.0, 'description': 'Keratina brasilena para alisar y sellar la cuticula. Elimina frizz por hasta 4 meses.', 'is_active': true},
    {'id': 'e0000001-0000-4000-8000-000000000004', 'business_id': businessId, 'service_type': 'corte_hombre', 'name': 'Corte Caballero', 'category': 'Cabello', 'subcategory': 'Corte', 'price': 300.0, 'duration_minutes': 30, 'buffer_minutes': 0, 'deposit_required': false, 'deposit_percentage': 0.0, 'description': 'Corte masculino con degradado o estilo clasico. Incluye lavado.', 'is_active': true},
    {'id': 'e0000001-0000-4000-8000-000000000005', 'business_id': businessId, 'service_type': 'recogido_evento', 'name': 'Peinado Evento', 'category': 'Cabello', 'subcategory': 'Peinado', 'price': 700.0, 'duration_minutes': 60, 'buffer_minutes': 0, 'deposit_required': true, 'deposit_percentage': 30.0, 'description': 'Peinado profesional para bodas, XV anos u ocasiones especiales.', 'is_active': true},
    // Pestañas y Cejas
    {'id': 'e0000001-0000-4000-8000-000000000010', 'business_id': businessId, 'service_type': 'ext_pestanas_clasicas', 'name': 'Extensiones Clasicas', 'category': 'Pestañas y Cejas', 'subcategory': 'Extensiones', 'price': 900.0, 'duration_minutes': 90, 'buffer_minutes': 0, 'deposit_required': true, 'deposit_percentage': 30.0, 'description': 'Aplicacion pelo a pelo. Look natural y elegante, dura 3-4 semanas.', 'is_active': true},
    {'id': 'e0000001-0000-4000-8000-000000000011', 'business_id': businessId, 'service_type': 'ext_pestanas_volumen', 'name': 'Extensiones Volumen', 'category': 'Pestañas y Cejas', 'subcategory': 'Extensiones', 'price': 1200.0, 'duration_minutes': 120, 'buffer_minutes': 0, 'deposit_required': true, 'deposit_percentage': 30.0, 'description': 'Volumen ruso con abanicos de 3-5 pestanas. Efecto dramatico y lleno.', 'is_active': true},
    {'id': 'e0000001-0000-4000-8000-000000000012', 'business_id': businessId, 'service_type': 'lifting_pestanas', 'name': 'Lash Lift + Tinte', 'category': 'Pestañas y Cejas', 'subcategory': 'Lifting', 'price': 650.0, 'duration_minutes': 60, 'buffer_minutes': 0, 'deposit_required': false, 'deposit_percentage': 0.0, 'description': 'Levantamiento y curvatura de pestanas naturales con tinte. Dura 6-8 semanas.', 'is_active': true},
    {'id': 'e0000001-0000-4000-8000-000000000013', 'business_id': businessId, 'service_type': 'diseno_depilacion_cejas', 'name': 'Diseno de Cejas', 'category': 'Pestañas y Cejas', 'subcategory': 'Cejas', 'price': 350.0, 'duration_minutes': 30, 'buffer_minutes': 0, 'deposit_required': false, 'deposit_percentage': 0.0, 'description': 'Perfilado y diseno con hilo, pinza y cera. Incluye tinte si se requiere.', 'is_active': true},
    {'id': 'e0000001-0000-4000-8000-000000000051', 'business_id': businessId, 'service_type': 'microblading', 'name': 'Microblading Cejas', 'category': 'Pestañas y Cejas', 'subcategory': 'Microblading', 'price': 3500.0, 'duration_minutes': 120, 'buffer_minutes': 0, 'deposit_required': true, 'deposit_percentage': 50.0, 'description': 'Micropigmentacion pelo a pelo para cejas naturales. Incluye retoque a los 30 dias.', 'is_active': true},
    // Maquillaje
    {'id': 'e0000001-0000-4000-8000-000000000020', 'business_id': businessId, 'service_type': 'maquillaje_social', 'name': 'Maquillaje Social', 'category': 'Maquillaje', 'subcategory': 'Social', 'price': 800.0, 'duration_minutes': 60, 'buffer_minutes': 0, 'deposit_required': true, 'deposit_percentage': 30.0, 'description': 'Maquillaje para eventos sociales. Productos de alta gama, duracion 12+ horas.', 'is_active': true},
    {'id': 'e0000001-0000-4000-8000-000000000021', 'business_id': businessId, 'service_type': 'maquillaje_novia', 'name': 'Maquillaje Novia', 'category': 'Maquillaje', 'subcategory': 'Novia', 'price': 2000.0, 'duration_minutes': 90, 'buffer_minutes': 0, 'deposit_required': true, 'deposit_percentage': 50.0, 'description': 'Paquete completo nupcial. Incluye prueba previa, productos waterproof y kit retoque.', 'is_active': true},
    {'id': 'e0000001-0000-4000-8000-000000000022', 'business_id': businessId, 'service_type': 'clase_automaquillaje', 'name': 'Clase de Automaquillaje', 'category': 'Maquillaje', 'subcategory': 'Clase', 'price': 600.0, 'duration_minutes': 75, 'buffer_minutes': 0, 'deposit_required': false, 'deposit_percentage': 0.0, 'description': 'Sesion personalizada de tecnicas de automaquillaje con tus productos.', 'is_active': true},
    // Depilación
    {'id': 'e0000001-0000-4000-8000-000000000030', 'business_id': businessId, 'service_type': 'depilacion_cera', 'name': 'Depilacion Pierna Completa', 'category': 'Depilación', 'subcategory': 'Cera', 'price': 450.0, 'duration_minutes': 45, 'buffer_minutes': 0, 'deposit_required': false, 'deposit_percentage': 0.0, 'description': 'Cera caliente ambas piernas completas. Incluye locion calmante.', 'is_active': true},
    {'id': 'e0000001-0000-4000-8000-000000000031', 'business_id': businessId, 'service_type': 'depilacion_cera', 'name': 'Depilacion Brasilena', 'category': 'Depilación', 'subcategory': 'Cera', 'price': 500.0, 'duration_minutes': 30, 'buffer_minutes': 0, 'deposit_required': false, 'deposit_percentage': 0.0, 'description': 'Zona bikini completa con cera caliente de baja temperatura.', 'is_active': true},
    {'id': 'e0000001-0000-4000-8000-000000000032', 'business_id': businessId, 'service_type': 'depilacion_cera', 'name': 'Depilacion Axilas', 'category': 'Depilación', 'subcategory': 'Cera', 'price': 200.0, 'duration_minutes': 15, 'buffer_minutes': 0, 'deposit_required': false, 'deposit_percentage': 0.0, 'description': 'Depilacion de axilas con cera. Rapido y efectivo.', 'is_active': true},
    // Uñas
    {'id': 'b8b0bbf5-8e37-40fa-80eb-010740ca5f3d', 'business_id': businessId, 'service_type': 'manicure_clasico', 'name': 'Uñas Clasico', 'category': 'Uñas', 'subcategory': 'Manicure', 'price': 350.0, 'duration_minutes': 45, 'buffer_minutes': 5, 'deposit_required': true, 'deposit_percentage': 50.0, 'description': 'Manicure clasico con limado, cuticula, hidratacion y barniz.', 'is_active': true},
    {'id': '32633a28-09d9-4831-8f99-f0e25f17a18f', 'business_id': businessId, 'service_type': 'pedicure_clasico', 'name': 'Pedicure Clasico', 'category': 'Uñas', 'subcategory': 'Pedicure', 'price': 350.0, 'duration_minutes': 35, 'buffer_minutes': 5, 'deposit_required': true, 'deposit_percentage': 50.0, 'description': 'Pedicure completo con exfoliacion, limpieza profunda e hidratacion.', 'is_active': true},
    {'id': '20eb9cc5-31f3-4826-a5c4-756430a4c242', 'business_id': businessId, 'service_type': 'pedicure_gel', 'name': 'Pedicure Gel', 'category': 'Uñas', 'subcategory': 'Pedicure', 'price': 350.0, 'duration_minutes': 35, 'buffer_minutes': 5, 'deposit_required': true, 'deposit_percentage': 50.0, 'description': 'Pedicure con gel semipermanente. Duracion hasta 3 semanas.', 'is_active': true},
    {'id': 'e0000001-0000-4000-8000-000000000040', 'business_id': businessId, 'service_type': 'manicure_acrilico', 'name': 'Unas Acrilicas', 'category': 'Uñas', 'subcategory': 'Acrilicas', 'price': 650.0, 'duration_minutes': 90, 'buffer_minutes': 0, 'deposit_required': true, 'deposit_percentage': 30.0, 'description': 'Juego completo con tip o molde. Incluye limado, diseno basico y acabado gel.', 'is_active': true},
    {'id': 'e0000001-0000-4000-8000-000000000041', 'business_id': businessId, 'service_type': 'manicure_gel', 'name': 'Gelish Manos', 'category': 'Uñas', 'subcategory': 'Manicure', 'price': 400.0, 'duration_minutes': 50, 'buffer_minutes': 0, 'deposit_required': false, 'deposit_percentage': 0.0, 'description': 'Esmaltado semipermanente gelish. Duracion 2-3 semanas.', 'is_active': true},
    {'id': 'e0000001-0000-4000-8000-000000000042', 'business_id': businessId, 'service_type': 'nail_art', 'name': 'Nail Art Premium', 'category': 'Uñas', 'subcategory': 'Nail Art', 'price': 900.0, 'duration_minutes': 120, 'buffer_minutes': 0, 'deposit_required': true, 'deposit_percentage': 30.0, 'description': 'Diseno artistico avanzado con encapsulado, piedras, foil o tecnicas mixtas.', 'is_active': true},
    // Servicios Especiales
    {'id': '658a999c-dc18-4fef-8e73-496b4d58d31a', 'business_id': businessId, 'service_type': 'hidratacion_profunda', 'name': 'Tratamiento Capilar', 'category': 'Servicios Especiales', 'subcategory': 'Tratamiento Capilar', 'price': 500.0, 'duration_minutes': 30, 'buffer_minutes': 5, 'deposit_required': true, 'deposit_percentage': 50.0, 'description': 'Hidratacion profunda con keratina y aceites esenciales para cabello danado.', 'is_active': true},
    {'id': 'bf0aefd1-a527-49c6-9615-f79453b4b324', 'business_id': businessId, 'service_type': 'drenaje_linfatico', 'name': 'Masaje Linfatico', 'category': 'Servicios Especiales', 'subcategory': 'Masaje Linfático', 'price': 1000.0, 'duration_minutes': 90, 'buffer_minutes': 20, 'deposit_required': true, 'deposit_percentage': 50.0, 'description': 'Masaje de drenaje linfatico corporal completo. Reduce retencion de liquidos.', 'is_active': true},
    // Facial
    {'id': 'e0000001-0000-4000-8000-000000000050', 'business_id': businessId, 'service_type': 'limpieza_facial_profunda', 'name': 'Facial Hidratante', 'category': 'Facial', 'subcategory': 'Facial', 'price': 700.0, 'duration_minutes': 60, 'buffer_minutes': 0, 'deposit_required': false, 'deposit_percentage': 0.0, 'description': 'Limpieza profunda con vapor, extraccion, mascarilla y serum de acido hialuronico.', 'is_active': true},
  ];

  // ── Staff → service pool mapping ──────────────────────────────────────
  // Each staff member has a pool of service indices they typically perform.
  /// Returns demo staff_services rows for a given staff ID, matching the shape
  /// returned by: `staff_services.select('*, services(name, price, duration_minutes)')`.
  static List<Map<String, dynamic>> staffServicesFor(String staffId) {
    final indices = _staffServicePool[staffId];
    if (indices == null) return [];
    return indices
        .where((i) => i < services.length)
        .map((i) {
          final svc = services[i];
          return {
            'id': '${staffId}_${svc['id']}',
            'staff_id': staffId,
            'service_id': svc['id'],
            'custom_price': null,
            'custom_duration': null,
            'services': {
              'name': svc['name'],
              'price': svc['price'],
              'duration_minutes': svc['duration_minutes'],
            },
          };
        })
        .toList();
  }

  static const Map<String, List<int>> _staffServicePool = {
    '261a09a2-8e09-41da-abe6-00ce582a3607': [0, 4, 5],       // Amber: Corte, Corte Caballero, Peinado Evento
    'd0000001-0000-4000-8000-000000000001': [1, 2, 3],        // Valentina: Balayage, Tinte Raiz, Keratina
    '98306b67-3d8c-44e3-9010-465e45afeb4d': [11, 12, 13, 14, 15], // Marcos: Maquillaje, Depilacion
    'fcd1e90a-9811-4ea6-b672-385b2c01c7c6': [3, 23, 24],      // Juan: Keratina, Tratamiento Capilar, Masaje, Facial
    'd0000001-0000-4000-8000-000000000002': [6, 7, 8, 9, 10], // Daniela: Pestanas, Cejas, Microblading
    'd0000001-0000-4000-8000-000000000003': [16, 17, 18, 19, 20, 21], // Andrea: Unas
    'd0000001-0000-4000-8000-000000000004': [1, 2, 5],                // Sofia: Balayage, Tinte, Peinado
    'd0000001-0000-4000-8000-000000000005': [0, 4],                   // Ricardo: Corte y Estilo, Corte Caballero
  };

  // ── Appointments ───────────────────────────────────────────────────────
  // Generates appointments relative to "today" for a fresh demo feel.
  // 3 appointments per staff member per working day (Mon-Sat) for 2 months.

  static List<Map<String, dynamic>>? _cachedAppointments;
  static int? _cachedDay;

  static List<Map<String, dynamic>> get appointments {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayKey = today.millisecondsSinceEpoch ~/ 86400000;

    // Cache so repeated access in same session doesn't regenerate
    if (_cachedAppointments != null && _cachedDay == dayKey) {
      return _cachedAppointments!;
    }

    final result = <Map<String, dynamic>>[];
    final staffIds = staff.map((s) => s['id'] as String).toList();

    // Possible start hours for appointments (9:00 to 17:00, spread out)
    const startHours = [9, 10, 11, 12, 13, 14, 15, 16, 17];

    // ── Past 180 days: variable per-weekday busyness ──────────────────
    // Rolling window — always 180 days of history so the dashboard
    // stats / analytics chart / revenue trend always look lived-in.
    for (var dayOffset = -180; dayOffset <= 0; dayOffset++) {
      final date = today.add(Duration(days: dayOffset));
      if (date.weekday == DateTime.sunday) continue; // salon closed

      final isToday = dayOffset == 0;

      for (var si = 0; si < staffIds.length; si++) {
        final staffId = staffIds[si];
        final pool = _staffServicePool[staffId] ?? [0];

        final daySeed =
            ((dayOffset + 1000) * 1000 + si * 100) * 2654435761 & 0xFFFFFFFF;
        final int apptCount;
        switch (date.weekday) {
          case DateTime.monday:
          case DateTime.tuesday:
            apptCount = 1 + (daySeed % 2);
          case DateTime.wednesday:
          case DateTime.thursday:
            apptCount = 3 + (daySeed % 2);
          case DateTime.friday:
          case DateTime.saturday:
            apptCount = 4 + (daySeed % 3);
          default:
            apptCount = 2;
        }

        for (var apptIdx = 0; apptIdx < apptCount; apptIdx++) {
          final seed = (dayOffset + 1000) * 1000 + si * 100 + apptIdx;
          final hash = (seed * 2654435761) & 0xFFFFFFFF;
          final hourSlot = startHours[(apptIdx * 3 + hash) % startHours.length];
          final svcIdx = pool[hash % pool.length];
          final svc = services[svcIdx];

          String status;
          if (isToday && hourSlot >= now.hour) {
            status = 'confirmed';
          } else {
            final statusRoll = hash % 20;
            status = statusRoll == 0
                ? 'no_show'
                : statusRoll == 1
                    ? 'cancelled_customer'
                    : 'completed';
          }

          final id = 'demo-past-${dayOffset + 1000}-$si-$apptIdx';
          result.add(_appt(
            id,
            staffId,
            svc['name'] as String,
            svc['service_type'] as String,
            (svc['price'] as num).toDouble(),
            date,
            svc['duration_minutes'] as int,
            status,
            hour: hourSlot,
          ));
        }
      }
    }

    // ── Future: EXACTLY 28 scheduled appointments ─────────────────────
    // Rolling window — always 28 future confirmed appointments so the
    // calendar, upcoming-bookings widget, reschedule demo, and WhatsApp
    // flow all have real-looking data to grab. Distributed across the
    // next ~30 days (excluding Sundays), spread across stylists and
    // hours so the calendar looks genuinely busy rather than clumpy.
    const futureTarget = 28;
    var futureGenerated = 0;
    var dayOffset = 1;
    var roundRobinStaff = 0;
    final usedSlots = <String>{}; // 'date-staff-hour' collision guard
    while (futureGenerated < futureTarget && dayOffset <= 45) {
      final date = today.add(Duration(days: dayOffset));
      if (date.weekday == DateTime.sunday) {
        dayOffset++;
        continue;
      }

      // 2-4 appointments per open day, cycling through stylists
      final dayHash = (dayOffset * 2654435761) & 0xFFFFFFFF;
      final perDay = 2 + (dayHash % 3);

      for (var i = 0; i < perDay && futureGenerated < futureTarget; i++) {
        final staffId = staffIds[roundRobinStaff % staffIds.length];
        roundRobinStaff++;

        final seed = (dayOffset * 1000 + i) * 2654435761 & 0xFFFFFFFF;
        final hourSlot = startHours[(i * 2 + (seed ~/ 7)) % startHours.length];
        final slotKey = '${date.toIso8601String().substring(0, 10)}-$staffId-$hourSlot';
        if (usedSlots.contains(slotKey)) continue;
        usedSlots.add(slotKey);

        final pool = _staffServicePool[staffId] ?? [0];
        final svcIdx = pool[seed % pool.length];
        final svc = services[svcIdx];

        result.add(_appt(
          'demo-future-$futureGenerated',
          staffId,
          svc['name'] as String,
          svc['service_type'] as String,
          (svc['price'] as num).toDouble(),
          date,
          svc['duration_minutes'] as int,
          'confirmed',
          hour: hourSlot,
        ));
        futureGenerated++;
      }
      dayOffset++;
    }

    _cachedAppointments = result;
    _cachedDay = dayKey;
    return result;
  }

  static Map<String, dynamic> _appt(
    String id,
    String staffId,
    String serviceName,
    String serviceType,
    double price,
    DateTime date,
    int durationMin,
    String status, {
    int hour = 10,
  }) {
    final start = DateTime(date.year, date.month, date.day, hour);
    final end = start.add(Duration(minutes: durationMin));
    final serviceId = services.firstWhere(
      (s) => s['service_type'] == serviceType,
      orElse: () => services.first,
    )['id'] as String;
    final staffName = staff.firstWhere(
      (s) => s['id'] == staffId,
      orElse: () => staff.first,
    );
    // Tax calculations (LISR Art. 113-A / LIVA Art. 18-J)
    final taxBase = price / 1.16;
    final isrWithheld = taxBase * 0.025;
    final ivaWithheld = taxBase * 0.08;
    final commission = price * 0.03;
    final providerNet = price - isrWithheld - ivaWithheld;

    // Booking source: realistic mix
    // 35% walk-in (salon registers manually — no tax, no commission)
    // 25% salon_direct (client books via salon's link/QR — tax applies, commission applies)
    // 20% cita_express (client scans QR at salon — tax applies, commission applies)
    // 20% bc_marketplace (BC found the client — tax applies, commission applies)
    final sourceHash = id.hashCode.abs() % 20;
    final bookingSource = sourceHash < 7
        ? 'walk_in'
        : sourceHash < 12
            ? 'salon_direct'
            : sourceHash < 16
                ? 'cita_express'
                : 'bc_marketplace';
    final hasTax = bookingSource != 'walk_in';

    return {
      'id': id,
      'business_id': businessId,
      'user_id': 'c0000001-0000-4000-8000-000000000001',
      'staff_id': staffId,
      'service_id': serviceId,
      'service_name': serviceName,
      'service_type': serviceType,
      'status': status,
      'starts_at': start.toIso8601String(),
      'ends_at': end.toIso8601String(),
      'duration_minutes': durationMin,
      'price': price,
      'payment_status': status == 'completed' || status == 'no_show'
          ? 'paid'
          : status == 'cancelled_customer'
              ? 'refunded'
              : 'pending',
      'payment_method': bookingSource == 'walk_in'
          ? 'cash_direct'
          : (id.hashCode.abs() % 3 == 0 ? 'saldo' : 'card'),
      'payment_amount_centavos': (price * 100).toInt(),
      'beautycita_fee_centavos': hasTax ? (commission * 100).toInt() : 0,
      'booking_source': bookingSource,
      // Tax fields — only present for non-walk-in bookings
      if (hasTax) 'tax_base': double.parse(taxBase.toStringAsFixed(2)),
      if (hasTax) 'isr_withheld': double.parse(isrWithheld.toStringAsFixed(2)),
      if (hasTax) 'iva_withheld': double.parse(ivaWithheld.toStringAsFixed(2)),
      'provider_net': hasTax
          ? double.parse(providerNet.toStringAsFixed(2))
          : price, // walk-ins: salon keeps 100%
      'customer_name': _customerNames[id.hashCode.abs() % _customerNames.length],
      'customer_phone': '+5233${(1000000 + id.hashCode.abs() % 9000000)}',
      'notes': null,
      'created_at': date.subtract(const Duration(days: 2)).toIso8601String(),
      'staff': {
        'first_name': staffName['first_name'],
        'last_name': staffName['last_name'],
      },
    };
  }

  static const _customerNames = [
    'Maria Lopez',
    'Sofia Rodriguez',
    'Isabella Martinez',
    'Camila Hernandez',
    'Valeria Garcia',
    'Lucia Sanchez',
    'Renata Flores',
    'Ximena Torres',
    'Mariana Diaz',
    'Fernanda Ruiz',
    'Ana Rivera',
    'Daniela Cruz',
    'Alejandra Morales',
    'Gabriela Ortiz',
    'Natalia Ramos',
  ];

  // ── Reviews ────────────────────────────────────────────────────────────

  static const List<Map<String, dynamic>> reviews = [
    {'id': 'r001', 'business_id': businessId, 'staff_id': '261a09a2-8e09-41da-abe6-00ce582a3607', 'service_type': 'corte_mujer', 'rating': 5, 'comment': 'Excelente corte, Amber siempre sabe exactamente lo que quiero!', 'customer_name': 'Maria Lopez', 'created_at': '2026-01-22T12:00:00Z'},
    {'id': 'r002', 'business_id': businessId, 'staff_id': 'd0000001-0000-4000-8000-000000000002', 'service_type': 'ext_pestanas_clasicas', 'rating': 5, 'comment': 'Mis extensiones quedaron hermosas! Daniela es una artista.', 'customer_name': 'Sofia Rodriguez', 'created_at': '2026-01-22T14:00:00Z'},
    {'id': 'r003', 'business_id': businessId, 'staff_id': 'd0000001-0000-4000-8000-000000000003', 'service_type': 'manicure_acrilico', 'rating': 4, 'comment': 'Las acrilicas quedaron bien, buen diseno.', 'customer_name': 'Isabella Martinez', 'created_at': '2026-01-22T16:00:00Z'},
    {'id': 'r004', 'business_id': businessId, 'staff_id': 'd0000001-0000-4000-8000-000000000001', 'service_type': 'balayage', 'rating': 5, 'comment': 'Mi balayage quedo INCREIBLE. Valentina es genia del color!', 'customer_name': 'Camila Hernandez', 'created_at': '2026-01-29T11:00:00Z'},
    {'id': 'r005', 'business_id': businessId, 'staff_id': '98306b67-3d8c-44e3-9010-465e45afeb4d', 'service_type': 'maquillaje_social', 'rating': 5, 'comment': 'Marcos es increible. Dure toda la noche sin retoques.', 'customer_name': 'Valeria Garcia', 'created_at': '2026-01-29T15:00:00Z'},
    {'id': 'r006', 'business_id': businessId, 'staff_id': 'd0000001-0000-4000-8000-000000000002', 'service_type': 'lifting_pestanas', 'rating': 4, 'comment': 'Buen lash lift, se noto la diferencia.', 'customer_name': 'Lucia Sanchez', 'created_at': '2026-01-30T10:00:00Z'},
    {'id': 'r007', 'business_id': businessId, 'staff_id': 'fcd1e90a-9811-4ea6-b672-385b2c01c7c6', 'service_type': 'keratina_alisado', 'rating': 5, 'comment': 'La keratina de Juan es la mejor. Mi cabello quedo como seda.', 'customer_name': 'Renata Flores', 'created_at': '2026-02-05T09:00:00Z'},
    {'id': 'r008', 'business_id': businessId, 'staff_id': '98306b67-3d8c-44e3-9010-465e45afeb4d', 'service_type': 'depilacion_cera', 'rating': 5, 'comment': 'Muy profesional y cuidadoso. Rapida y con minimo dolor.', 'customer_name': 'Ximena Torres', 'created_at': '2026-02-06T11:00:00Z'},
    {'id': 'r009', 'business_id': businessId, 'staff_id': 'd0000001-0000-4000-8000-000000000003', 'service_type': 'nail_art', 'rating': 5, 'comment': 'El nail art de Andrea es impresionante! Disenos unicos.', 'customer_name': 'Mariana Diaz', 'created_at': '2026-02-06T14:00:00Z'},
    {'id': 'r010', 'business_id': businessId, 'staff_id': '98306b67-3d8c-44e3-9010-465e45afeb4d', 'service_type': 'maquillaje_novia', 'rating': 5, 'comment': 'Mi maquillaje de novia quedo divino! Llore y no se corrio nada.', 'customer_name': 'Fernanda Ruiz', 'created_at': '2026-02-13T10:00:00Z'},
    {'id': 'r011', 'business_id': businessId, 'staff_id': 'fcd1e90a-9811-4ea6-b672-385b2c01c7c6', 'service_type': 'limpieza_facial_profunda', 'rating': 4, 'comment': 'Buen facial, piel renovada. Ambiente muy agradable.', 'customer_name': 'Ana Rivera', 'created_at': '2026-02-13T15:00:00Z'},
    {'id': 'r012', 'business_id': businessId, 'staff_id': 'd0000001-0000-4000-8000-000000000002', 'service_type': 'ext_pestanas_volumen', 'rating': 5, 'comment': 'Las extensiones de volumen son perfeccion! Daniela es la mejor.', 'customer_name': 'Daniela Cruz', 'created_at': '2026-02-19T12:00:00Z'},
    {'id': 'r013', 'business_id': businessId, 'staff_id': '261a09a2-8e09-41da-abe6-00ce582a3607', 'service_type': 'recogido_evento', 'rating': 5, 'comment': 'Peinado espectacular para la boda de mi hermana.', 'customer_name': 'Alejandra Morales', 'created_at': '2026-02-21T11:00:00Z'},
    {'id': 'r014', 'business_id': businessId, 'staff_id': '98306b67-3d8c-44e3-9010-465e45afeb4d', 'service_type': 'depilacion_cera', 'rating': 4, 'comment': 'Buena depilacion, profesional como siempre.', 'customer_name': 'Gabriela Ortiz', 'created_at': '2026-02-21T14:00:00Z'},
    {'id': 'r015', 'business_id': businessId, 'staff_id': 'd0000001-0000-4000-8000-000000000001', 'service_type': 'balayage', 'rating': 5, 'comment': 'Valentina es la reina del balayage! Color increible.', 'customer_name': 'Natalia Ramos', 'created_at': '2026-02-26T10:00:00Z'},
    {'id': 'r016', 'business_id': businessId, 'staff_id': 'd0000001-0000-4000-8000-000000000002', 'service_type': 'microblading', 'rating': 5, 'comment': 'El microblading cambio mi vida! Cejas perfectas y naturales.', 'customer_name': 'Maria Lopez', 'created_at': '2026-03-04T16:00:00Z'},
  ];

  // ── Disputes ───────────────────────────────────────────────────────────

  // Field names mirror the real `disputes` table so the portal's detail
  // panel renders every card (resolution, refund, business response, etc).
  static List<Map<String, dynamic>> get disputes {
    final now = DateTime.now();
    String iso(DateTime d) => d.toUtc().toIso8601String();
    return [
      // One OPEN dispute so the "Responder" flow is visible in the demo
      // (CTA is still suppressed in demo mode, but the layout is shown).
      {
        'id': 'd0ffe0c1-0000-4000-8000-000000000001',
        'appointment_id': 'f0000001-0001-4000-8000-000000000026',
        'business_id': businessId,
        'reason': 'Servicio incompleto',
        'description':
            'La estilista no termino el peinado porque se acabo el tiempo. '
                'Pague completo y sali con medio estilo. Pido reembolso parcial.',
        'status': 'open',
        'amount': 700.0,
        'created_at': iso(now.subtract(const Duration(hours: 30))),
      },
      // One dispute awaiting client acceptance of salon's offer.
      {
        'id': 'd0ffe0c1-0000-4000-8000-000000000002',
        'appointment_id': 'f0000001-0001-4000-8000-000000000025',
        'business_id': businessId,
        'reason': 'Color de tinte incorrecto',
        'description':
            'Pedi un tono miel dorado y quedo naranja. Llevo fotos de referencia, '
                'pero el resultado no coincide.',
        'status': 'salon_responded',
        'amount': 1800.0,
        'salon_offer': 'partial_refund',
        'salon_offer_amount': 900.0,
        'business_response':
            'Ofrecemos correccion de tono sin costo + 50% del servicio de regreso.',
        'salon_responded_at': iso(now.subtract(const Duration(days: 2, hours: 1))),
        'created_at': iso(now.subtract(const Duration(days: 3))),
      },
      // Resolved in favor of client — full refund issued.
      {
        'id': 'd0ffe0c1-0000-4000-8000-000000000003',
        'appointment_id': 'f0000001-0001-4000-8000-000000000019',
        'business_id': businessId,
        'reason': 'No-show disputado',
        'description':
            'Me marcaron como no-show pero si llegue 20 min tarde y la estilista '
                'ya no me atendio. Pido que me devuelvan el deposito.',
        'status': 'resolved',
        'amount': 270.0,
        'resolution': 'favor_client',
        'admin_notes':
            'Politica del salon: 15 min de tolerancia. Cliente llego a los 20, '
                'pero el log muestra que la estilista estaba libre. Reembolso parcial.',
        'refund_amount': 270.0,
        'refund_status': 'processed',
        'salon_offer': 'partial_refund',
        'salon_offer_amount': 270.0,
        'business_response': 'Reembolso del 50% del deposito y reagendamos.',
        'salon_responded_at': iso(now.subtract(const Duration(days: 11))),
        'client_accepted': true,
        'client_responded_at': iso(now.subtract(const Duration(days: 10, hours: 4))),
        'created_at': iso(now.subtract(const Duration(days: 12))),
        'resolved_at': iso(now.subtract(const Duration(days: 10))),
      },
      // Resolved favor_both — cliente acepto servicio de correccion.
      {
        'id': 'd0ffe0c1-0000-4000-8000-000000000004',
        'appointment_id': 'f0000001-0001-4000-8000-000000000014',
        'business_id': businessId,
        'reason': 'Cancelacion y deposito no devuelto',
        'description':
            'Cancele mi cita con 48h de anticipacion y no me devolvieron el deposito. '
                'Segun la politica debia ser reembolsable.',
        'status': 'resolved',
        'amount': 150.0,
        'resolution': 'favor_client',
        'admin_notes':
            'Cancelacion dentro del plazo permitido (>24h). Reembolso completo aprobado.',
        'refund_amount': 150.0,
        'refund_status': 'processed',
        'salon_offer': 'full_refund',
        'salon_offer_amount': 150.0,
        'business_response': 'Procesamos reembolso completo del deposito.',
        'salon_responded_at': iso(now.subtract(const Duration(days: 20))),
        'client_accepted': true,
        'client_responded_at': iso(now.subtract(const Duration(days: 19, hours: 2))),
        'created_at': iso(now.subtract(const Duration(days: 21))),
        'resolved_at': iso(now.subtract(const Duration(days: 19))),
      },
    ];
  }

  // ── Clients (CRM) ──────────────────────────────────────────────────────
  // Derived from the repeat customers in DemoData.appointments so the CRM
  // reflects the calendar and a savvy BC can't spot drift. One-shot spent
  // totals are computed from completed appointments.

  static List<Map<String, dynamic>>? _cachedClients;
  static int? _cachedClientsDay;

  static List<Map<String, dynamic>> get clients {
    final now = DateTime.now();
    final dayKey = DateTime(now.year, now.month, now.day)
            .millisecondsSinceEpoch ~/
        86400000;
    if (_cachedClients != null && _cachedClientsDay == dayKey) {
      return _cachedClients!;
    }

    // Pool of "clients" — 12 realistic Mexican names.
    const names = [
      'Maria Lopez',
      'Sofia Rodriguez',
      'Isabella Martinez',
      'Camila Hernandez',
      'Valeria Garcia',
      'Lucia Sanchez',
      'Renata Flores',
      'Ximena Torres',
      'Mariana Diaz',
      'Fernanda Ruiz',
      'Ana Rivera',
      'Daniela Cruz',
    ];

    // Aggregate appointment data per client name. The generator in
    // appointments assigns customer_name from the same name pool, so
    // joining by name is deterministic enough for the demo.
    final Map<String, Map<String, dynamic>> agg = {};
    for (final a in appointments) {
      final name = a['customer_name'] as String?;
      if (name == null) continue;
      agg.putIfAbsent(
        name,
        () => {
          'total_visits': 0,
          'total_spent': 0.0,
          'no_show_count': 0,
          'last_visit_at': null as String?,
          'phone': a['customer_phone'] as String?,
        },
      );
      final status = a['status'] as String?;
      if (status == 'completed') {
        agg[name]!['total_visits'] = (agg[name]!['total_visits'] as int) + 1;
        agg[name]!['total_spent'] = (agg[name]!['total_spent'] as double) +
            ((a['price'] as num?)?.toDouble() ?? 0);
        final starts = a['starts_at'] as String;
        final cur = agg[name]!['last_visit_at'] as String?;
        if (cur == null || starts.compareTo(cur) > 0) {
          agg[name]!['last_visit_at'] = starts;
        }
      } else if (status == 'no_show') {
        agg[name]!['no_show_count'] =
            (agg[name]!['no_show_count'] as int) + 1;
      }
    }

    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < names.length; i++) {
      final name = names[i];
      final a = agg[name];
      if (a == null) continue;
      // Loyalty points: 1pt per $10 spent (business rule from policies.md).
      final spent = a['total_spent'] as double;
      final loyalty = (spent / 10).floor();
      // A couple of tags so the CRM badges render.
      final tags = switch (i % 4) {
        0 => ['VIP'],
        1 => ['Nuevo'],
        2 => <String>[],
        _ => ['Frecuente'],
      };
      result.add({
        'id': 'demo-client-$i',
        'business_id': businessId,
        'client_name': name,
        'phone': a['phone'] ??
            '+5233${(1000000 + name.hashCode.abs() % 9000000)}',
        'total_visits': a['total_visits'],
        'total_spent': spent,
        'last_visit_at': a['last_visit_at'],
        'no_show_count': a['no_show_count'],
        'loyalty_points': loyalty,
        'tags': tags,
        'notes': i == 0
            ? 'Prefiere citas matutinas. Alergia al amoniaco.'
            : null,
        'created_at': DateTime.now()
            .subtract(Duration(days: 60 + i * 5))
            .toIso8601String(),
      });
    }

    // Sort by last_visit desc (matches the real query's default).
    result.sort((a, b) {
      final av = a['last_visit_at'] as String? ?? '';
      final bv = b['last_visit_at'] as String? ?? '';
      return bv.compareTo(av);
    });

    _cachedClients = result;
    _cachedClientsDay = dayKey;
    return result;
  }

  // ── Gift cards ─────────────────────────────────────────────────────────
  // Standard denomination mix so a BC pitching the salon can walk a
  // prospect through "active / redeemed / expired" states at a glance.
  static List<Map<String, dynamic>> get giftCards {
    final now = DateTime.now();
    String iso(DateTime d) => d.toUtc().toIso8601String();
    return [
      {
        'id': 'gc-demo-001',
        'business_id': businessId,
        'code': 'BC-250-MDNP',
        'amount': 250.0,
        'balance': 250.0,
        'status': 'active',
        'sender_name': 'Amber Elizabeth',
        'recipient_name': 'Maria Lopez',
        'recipient_phone': '+523223345678',
        'message': 'Feliz cumpleanos!',
        'expires_at': iso(now.add(const Duration(days: 330))),
        'created_at': iso(now.subtract(const Duration(days: 35))),
      },
      {
        'id': 'gc-demo-002',
        'business_id': businessId,
        'code': 'BC-500-QZXW',
        'amount': 500.0,
        'balance': 500.0,
        'status': 'active',
        'sender_name': 'Valentina Rios',
        'recipient_name': 'Sofia Rodriguez',
        'recipient_phone': '+523221112233',
        'message': 'Para tu proximo balayage — te lo mereces.',
        'expires_at': iso(now.add(const Duration(days: 350))),
        'created_at': iso(now.subtract(const Duration(days: 15))),
      },
      {
        'id': 'gc-demo-003',
        'business_id': businessId,
        'code': 'BC-1000-KPRT',
        'amount': 1000.0,
        'balance': 350.0,
        'status': 'active',
        'sender_name': 'Fernanda Ruiz',
        'recipient_name': 'Camila Hernandez',
        'recipient_phone': '+523227654321',
        'message': 'Regalo de graduacion.',
        'expires_at': iso(now.add(const Duration(days: 310))),
        'created_at': iso(now.subtract(const Duration(days: 55))),
      },
      {
        'id': 'gc-demo-004',
        'business_id': businessId,
        'code': 'BC-2000-VHBG',
        'amount': 2000.0,
        'balance': 0.0,
        'status': 'redeemed',
        'sender_name': 'Ricardo Vega',
        'recipient_name': 'Lucia Sanchez',
        'recipient_phone': '+523224445566',
        'message': 'Paquete completo — alisado + color.',
        'redeemed_at': iso(now.subtract(const Duration(days: 3))),
        'expires_at': iso(now.add(const Duration(days: 270))),
        'created_at': iso(now.subtract(const Duration(days: 40))),
      },
      {
        'id': 'gc-demo-005',
        'business_id': businessId,
        'code': 'BC-500-DEMO',
        'amount': 500.0,
        'balance': 500.0,
        'status': 'expired',
        'sender_name': 'Andrea Munoz',
        'recipient_name': 'Daniela Cruz',
        'recipient_phone': '+523228889900',
        'message': 'Gracias por la recomendacion!',
        'expires_at': iso(now.subtract(const Duration(days: 15))),
        'created_at': iso(now.subtract(const Duration(days: 400))),
      },
    ];
  }

  // ── Marketing automations ──────────────────────────────────────────────
  // Five automation triggers from policies.md (post-appointment, review
  // request, no-show followup, birthday, inactive client). Each has a
  // template, delay window, and is_active flag.

  static List<Map<String, dynamic>> get marketingAutomations {
    final now = DateTime.now();
    String iso(DateTime d) => d.toUtc().toIso8601String();
    return [
      {
        'id': 'ma-demo-001',
        'business_id': businessId,
        'trigger_type': 'post_appointment',
        'trigger_label': 'Despues de la cita',
        'channel': 'whatsapp',
        'delay_hours': 4,
        'is_active': true,
        'template_es': 'Hola {{nombre}}, gracias por visitarnos hoy! Esperamos que te haya encantado tu {{servicio}}. Cuentanos como te fue: {{link}}',
        'sent_count': 124,
        'created_at': iso(now.subtract(const Duration(days: 90))),
      },
      {
        'id': 'ma-demo-002',
        'business_id': businessId,
        'trigger_type': 'review_request',
        'trigger_label': 'Solicitar resena',
        'channel': 'whatsapp',
        'delay_hours': 24,
        'is_active': true,
        'template_es': 'Hola {{nombre}}, esperamos que estes disfrutando tu {{servicio}}. Nos ayudarias con una resena de 5 estrellas? {{link}}',
        'sent_count': 98,
        'created_at': iso(now.subtract(const Duration(days: 90))),
      },
      {
        'id': 'ma-demo-003',
        'business_id': businessId,
        'trigger_type': 'no_show_followup',
        'trigger_label': 'Seguimiento no-show',
        'channel': 'whatsapp',
        'delay_hours': 1,
        'is_active': true,
        'template_es': 'Hola {{nombre}}, vimos que no pudiste asistir a tu cita. Quieres reagendar? Tienes prioridad: {{link}}',
        'sent_count': 17,
        'created_at': iso(now.subtract(const Duration(days: 60))),
      },
      {
        'id': 'ma-demo-004',
        'business_id': businessId,
        'trigger_type': 'birthday',
        'trigger_label': 'Cumpleanos',
        'channel': 'whatsapp',
        'delay_hours': 0,
        'is_active': false,
        'template_es': 'Feliz cumpleanos {{nombre}}! Te regalamos un 15% de descuento este mes. Reserva: {{link}}',
        'sent_count': 0,
        'created_at': iso(now.subtract(const Duration(days: 30))),
      },
      {
        'id': 'ma-demo-005',
        'business_id': businessId,
        'trigger_type': 'inactive_client',
        'trigger_label': 'Cliente inactivo',
        'channel': 'whatsapp',
        'delay_hours': 1440, // 60 days
        'is_active': true,
        'template_es': 'Hola {{nombre}}, te extranamos! Han pasado mas de 60 dias desde tu ultima visita. Te esperamos: {{link}}',
        'sent_count': 31,
        'created_at': iso(now.subtract(const Duration(days: 80))),
      },
    ];
  }

  static List<Map<String, dynamic>> get marketingLog {
    final now = DateTime.now();
    String iso(DateTime d) => d.toUtc().toIso8601String();
    final names = ['Maria Lopez', 'Sofia Rodriguez', 'Camila Hernandez',
        'Valeria Garcia', 'Renata Flores', 'Mariana Diaz', 'Ana Rivera',
        'Daniela Cruz', 'Lucia Sanchez', 'Fernanda Ruiz'];
    final triggers = ['post_appointment', 'review_request', 'inactive_client',
        'no_show_followup', 'post_appointment', 'review_request'];
    return List.generate(20, (i) => {
      'id': 'mlog-$i',
      'business_id': businessId,
      'automation_id': 'ma-demo-00${(i % 5) + 1}',
      'recipient_name': names[i % names.length],
      'recipient_phone': '+5233${(1000000 + i * 7919)}',
      'trigger_type': triggers[i % triggers.length],
      'channel': 'whatsapp',
      'status': i % 11 == 0 ? 'failed' : 'sent',
      'created_at': iso(now.subtract(Duration(hours: i * 6))),
    });
  }

  // ── Orders (POS) ───────────────────────────────────────────────────────
  // 6 orders covering the full lifecycle: pending → shipped → delivered,
  // plus one disputed and one cancelled. Mix of products + prices.
  static List<Map<String, dynamic>> get orders {
    final now = DateTime.now();
    String iso(DateTime d) => d.toUtc().toIso8601String();
    return [
      {
        'id': 'ord-demo-001',
        'business_id': businessId,
        'buyer_id': 'c0000001-0000-4000-8000-000000000001',
        'product_name': 'Mascarilla Capilar Olaplex No.3',
        'product_id': 'prod-demo-001',
        'quantity': 1,
        'unit_price': 580.0,
        'total_amount': 580.0,
        'commission_amount': 58.0,
        'status': 'pending',
        'payment_method': 'card',
        'shipping_address': 'Calle Reforma 234, Col. Centro, Puerto Vallarta, Jal., 48300',
        'tracking_number': null,
        'buyer_name': 'Maria Lopez',
        'buyer_phone': '+523221112233',
        'created_at': iso(now.subtract(const Duration(hours: 6))),
      },
      {
        'id': 'ord-demo-002',
        'business_id': businessId,
        'buyer_id': 'c0000001-0000-4000-8000-000000000002',
        'product_name': 'Tinte Wella Koleston 7/0',
        'product_id': 'prod-demo-002',
        'quantity': 2,
        'unit_price': 240.0,
        'total_amount': 480.0,
        'commission_amount': 48.0,
        'status': 'shipped',
        'payment_method': 'saldo',
        'shipping_address': 'Av. Mexico 1502, Col. Versalles, Puerto Vallarta, Jal., 48310',
        'tracking_number': 'EST123456789MX',
        'buyer_name': 'Sofia Rodriguez',
        'buyer_phone': '+523224445566',
        'created_at': iso(now.subtract(const Duration(days: 2))),
      },
      {
        'id': 'ord-demo-003',
        'business_id': businessId,
        'buyer_id': 'c0000001-0000-4000-8000-000000000003',
        'product_name': 'Kit Manicure Profesional OPI',
        'product_id': 'prod-demo-003',
        'quantity': 1,
        'unit_price': 1250.0,
        'total_amount': 1250.0,
        'commission_amount': 125.0,
        'status': 'delivered',
        'payment_method': 'card',
        'shipping_address': 'Calle Constitucion 45, Col. Emiliano Zapata, Puerto Vallarta, Jal., 48380',
        'tracking_number': 'EST987654321MX',
        'buyer_name': 'Camila Hernandez',
        'buyer_phone': '+523227778899',
        'created_at': iso(now.subtract(const Duration(days: 8))),
        'delivered_at': iso(now.subtract(const Duration(days: 4))),
      },
      {
        'id': 'ord-demo-004',
        'business_id': businessId,
        'buyer_id': 'c0000001-0000-4000-8000-000000000004',
        'product_name': 'Plancha BaByliss Pro Nano Titanium',
        'product_id': 'prod-demo-004',
        'quantity': 1,
        'unit_price': 2400.0,
        'total_amount': 2400.0,
        'commission_amount': 240.0,
        'status': 'delivered',
        'payment_method': 'card',
        'shipping_address': 'Blvd. Francisco Medina Ascencio 2500, Hotel Zone, PV, Jal., 48330',
        'tracking_number': 'EST456789123MX',
        'buyer_name': 'Valeria Garcia',
        'buyer_phone': '+523221234567',
        'created_at': iso(now.subtract(const Duration(days: 14))),
        'delivered_at': iso(now.subtract(const Duration(days: 11))),
      },
      {
        'id': 'ord-demo-005',
        'business_id': businessId,
        'buyer_id': 'c0000001-0000-4000-8000-000000000005',
        'product_name': 'Champu Redken All Soft 1L',
        'product_id': 'prod-demo-005',
        'quantity': 1,
        'unit_price': 720.0,
        'total_amount': 720.0,
        'commission_amount': 72.0,
        'status': 'disputed',
        'payment_method': 'card',
        'shipping_address': 'Calle Hidalgo 88, Col. Centro, Puerto Vallarta, Jal., 48300',
        'tracking_number': 'EST111222333MX',
        'buyer_name': 'Renata Flores',
        'buyer_phone': '+523228889900',
        'created_at': iso(now.subtract(const Duration(days: 5))),
        'dispute_reason': 'Producto llego abierto y derramado',
      },
      {
        'id': 'ord-demo-006',
        'business_id': businessId,
        'buyer_id': 'c0000001-0000-4000-8000-000000000006',
        'product_name': 'Set Brochas de Maquillaje Real Techniques',
        'product_id': 'prod-demo-006',
        'quantity': 1,
        'unit_price': 890.0,
        'total_amount': 890.0,
        'commission_amount': 89.0,
        'status': 'cancelled',
        'payment_method': 'card',
        'shipping_address': 'Calle Aldama 12, Col. 5 de Diciembre, Puerto Vallarta, Jal., 48350',
        'tracking_number': null,
        'buyer_name': 'Mariana Diaz',
        'buyer_phone': '+523224567890',
        'created_at': iso(now.subtract(const Duration(days: 3))),
        'cancelled_at': iso(now.subtract(const Duration(days: 2))),
      },
    ];
  }

  // ── POS products ───────────────────────────────────────────────────────
  // Catalog the salon could resell. Schema mirrors `products` table fields
  // read by biz_pos_page (name, brand, price, photo_url, category, in_stock,
  // created_at, updated_at). Categories MUST match keys in Product.categories
  // — the POS form/edit row reads them as keys, not display labels.
  static List<Map<String, dynamic>> get products {
    const created = '2026-01-15T12:00:00Z';
    const updated = '2026-04-20T12:00:00Z';
    return const [
      {
        'id': 'prod-demo-001',
        'business_id': businessId,
        'name': 'Mascarilla Capilar Olaplex No.3',
        'brand': 'Olaplex',
        'price': 580.0,
        'photo_url':
            'https://placehold.co/400x400/F8F0E5/333?text=Olaplex+No.3',
        'category': 'moisturisers',
        'in_stock': true,
        'created_at': created,
        'updated_at': updated,
      },
      {
        'id': 'prod-demo-002',
        'business_id': businessId,
        'name': 'Tinte Wella Koleston 7/0',
        'brand': 'Wella',
        'price': 240.0,
        'photo_url':
            'https://placehold.co/400x400/EFE4DC/333?text=Wella+Koleston',
        'category': 'shampoo',
        'in_stock': true,
        'created_at': created,
        'updated_at': updated,
      },
      {
        'id': 'prod-demo-003',
        'business_id': businessId,
        'name': 'Kit Manicure Profesional OPI',
        'brand': 'OPI',
        'price': 1250.0,
        'photo_url':
            'https://placehold.co/400x400/F5DAE0/333?text=Kit+OPI',
        'category': 'nail_tools',
        'in_stock': true,
        'created_at': created,
        'updated_at': updated,
      },
      {
        'id': 'prod-demo-004',
        'business_id': businessId,
        'name': 'Plancha BaByliss Pro Nano Titanium',
        'brand': 'BaByliss',
        'price': 2400.0,
        'photo_url':
            'https://placehold.co/400x400/E0E0E0/333?text=BaByliss+Pro',
        'category': 'hair_tools',
        'in_stock': false,
        'created_at': created,
        'updated_at': updated,
      },
      {
        'id': 'prod-demo-005',
        'business_id': businessId,
        'name': 'Champu Redken All Soft 1L',
        'brand': 'Redken',
        'price': 720.0,
        'photo_url':
            'https://placehold.co/400x400/F2E4D7/333?text=Redken+All+Soft',
        'category': 'shampoo',
        'in_stock': true,
        'created_at': created,
        'updated_at': updated,
      },
      {
        'id': 'prod-demo-006',
        'business_id': businessId,
        'name': 'Set Brochas Real Techniques',
        'brand': 'Real Techniques',
        'price': 890.0,
        'photo_url':
            'https://placehold.co/400x400/F5E6C8/333?text=Real+Techniques',
        'category': 'foundation',
        'in_stock': true,
        'created_at': created,
        'updated_at': updated,
      },
      {
        'id': 'prod-demo-007',
        'business_id': businessId,
        'name': 'Labial Maybelline Sky High',
        'brand': 'Maybelline',
        'price': 320.0,
        'photo_url':
            'https://placehold.co/400x400/E8C9CD/333?text=Maybelline',
        'category': 'lipstick',
        'in_stock': true,
        'created_at': created,
        'updated_at': updated,
      },
      {
        'id': 'prod-demo-008',
        'business_id': businessId,
        'name': 'Locion Hidratante Cetaphil 500ml',
        'brand': 'Cetaphil',
        'price': 410.0,
        'photo_url':
            'https://placehold.co/400x400/E1ECF0/333?text=Cetaphil+500ml',
        'category': 'moisturisers',
        'in_stock': true,
        'created_at': created,
        'updated_at': updated,
      },
    ];
  }

  /// Showcase rows joined with their underlying product (the real query
  /// returns `*, products(name, photo_url, price)`).
  static List<Map<String, dynamic>> get productShowcases {
    final now = DateTime.now();
    String iso(DateTime d) => d.toUtc().toIso8601String();
    final items = [
      {
        'product_id': 'prod-demo-001',
        'caption': 'Mi favorito post-keratina. Pelo como seda en 8 minutos.',
        'days_ago': 1,
      },
      {
        'product_id': 'prod-demo-005',
        'caption': 'El champu que recomiendo despues de cada balayage.',
        'days_ago': 4,
      },
      {
        'product_id': 'prod-demo-007',
        'caption': 'Mascara que tenemos en kit de novia. No se corre, jamas.',
        'days_ago': 9,
      },
    ];
    return items.map((it) {
      final pid = it['product_id'] as String;
      final prod =
          products.firstWhere((p) => p['id'] == pid, orElse: () => products.first);
      return {
        'id': 'show-$pid',
        'business_id': businessId,
        'product_id': pid,
        'caption': it['caption'],
        'created_at':
            iso(now.subtract(Duration(days: it['days_ago'] as int))),
        'products': {
          'name': prod['name'],
          'photo_url': prod['photo_url'],
          'price': prod['price'],
        },
      };
    }).toList();
  }

  // ── Tax / payout / CFDI demo aggregates ────────────────────────────────
  // Computed from appointments so the dashboard "ingresos / retenciones /
  // pagos" cards drift in lock-step with the calendar mutations.

  /// YTD revenue + retenciones derived from completed appointments. Used by
  /// the businessTaxSummaryProvider override in demo mode.
  static ({double ytdRevenue, double ytdRetained}) taxYtdFromAppts(
      List<Map<String, dynamic>> appts) {
    final now = DateTime.now();
    final yearStr = '${now.year}-';
    double rev = 0;
    double retained = 0;
    for (final a in appts) {
      if (a['status'] != 'completed') continue;
      final starts = a['starts_at'] as String? ?? '';
      if (!starts.startsWith(yearStr)) continue;
      rev += (a['price'] as num? ?? 0).toDouble();
      retained += (a['isr_withheld'] as num? ?? 0).toDouble();
      retained += (a['iva_withheld'] as num? ?? 0).toDouble();
    }
    return (ytdRevenue: rev, ytdRetained: retained);
  }

  /// Synthetic CFDI rows so the dashboard CFDI card is non-empty. Five
  /// rows, mixed status (issued / pending / cancelled).
  static List<Map<String, dynamic>> get cfdiRecords {
    final now = DateTime.now();
    String iso(DateTime d) => d.toUtc().toIso8601String();
    return [
      {
        'id': 'cfdi-demo-001',
        'business_id': businessId,
        'uuid': 'A1B2C3D4-E5F6-7890-ABCD-EF1234567890',
        'folio': 'BC-2026-0042',
        'amount': 1800.0,
        'iva': 248.28,
        'isr': 77.59,
        'status': 'issued',
        'issued_at': iso(now.subtract(const Duration(days: 1))),
        'created_at': iso(now.subtract(const Duration(days: 1))),
      },
      {
        'id': 'cfdi-demo-002',
        'business_id': businessId,
        'uuid': 'B2C3D4E5-F6A7-8901-BCDE-F23456789012',
        'folio': 'BC-2026-0041',
        'amount': 700.0,
        'iva': 96.55,
        'isr': 30.17,
        'status': 'issued',
        'issued_at': iso(now.subtract(const Duration(days: 3))),
        'created_at': iso(now.subtract(const Duration(days: 3))),
      },
      {
        'id': 'cfdi-demo-003',
        'business_id': businessId,
        'uuid': 'C3D4E5F6-A7B8-9012-CDEF-345678901234',
        'folio': 'BC-2026-0040',
        'amount': 2500.0,
        'iva': 344.83,
        'isr': 107.76,
        'status': 'issued',
        'issued_at': iso(now.subtract(const Duration(days: 5))),
        'created_at': iso(now.subtract(const Duration(days: 5))),
      },
      {
        'id': 'cfdi-demo-004',
        'business_id': businessId,
        'uuid': null,
        'folio': 'BC-2026-0039',
        'amount': 500.0,
        'iva': 68.97,
        'isr': 21.55,
        'status': 'pending',
        'issued_at': null,
        'created_at': iso(now.subtract(const Duration(days: 6))),
      },
      {
        'id': 'cfdi-demo-005',
        'business_id': businessId,
        'uuid': 'E5F6A7B8-C9D0-1234-EFAB-567890123456',
        'folio': 'BC-2026-0038',
        'amount': 1200.0,
        'iva': 165.52,
        'isr': 51.72,
        'status': 'cancelled',
        'issued_at': iso(now.subtract(const Duration(days: 12))),
        'created_at': iso(now.subtract(const Duration(days: 12))),
      },
    ];
  }

  /// Synthetic payout history. Weekly disbursements over the last 6 weeks.
  static List<Map<String, dynamic>> get payoutRecords {
    final now = DateTime.now();
    String iso(DateTime d) => d.toUtc().toIso8601String();
    return List.generate(6, (i) {
      final weeksAgo = i + 1;
      final amount = 4500.0 + (i * 350) + (weeksAgo.isEven ? 220 : -140);
      return {
        'id': 'payout-demo-${100 - i}',
        'business_id': businessId,
        'amount': amount,
        'currency': 'MXN',
        'status': 'paid',
        'period_start':
            iso(now.subtract(Duration(days: weeksAgo * 7 + 7))),
        'period_end': iso(now.subtract(Duration(days: weeksAgo * 7))),
        'paid_at': iso(now.subtract(Duration(days: weeksAgo * 7 - 1))),
        'created_at': iso(now.subtract(Duration(days: weeksAgo * 7))),
      };
    });
  }

  /// Synthetic commission breakdown (last 30 days).
  static List<Map<String, dynamic>> get commissionRecords {
    final now = DateTime.now();
    String iso(DateTime d) => d.toUtc().toIso8601String();
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < 14; i++) {
      final daysAgo = i * 2 + 1;
      final base = 350.0 + (i * 27.5);
      out.add({
        'id': 'comm-demo-${500 - i}',
        'business_id': businessId,
        'appointment_id': 'demo-past-${1000 - daysAgo}-0-0',
        'amount': base * 0.03,
        'gross_amount': base,
        'rate': 0.03,
        'status': 'collected',
        'created_at': iso(now.subtract(Duration(days: daysAgo))),
      });
    }
    return out;
  }

  // ── Payments (derived from completed/no-show appointments) ─────────────

  static List<Map<String, dynamic>> get payments {
    return appointments
        .where((a) =>
            a['payment_status'] == 'paid' || a['payment_status'] == 'refunded')
        .map((a) => {
              'id': 'pay-${a['id']}',
              'appointment_id': a['id'],
              'amount_centavos': a['payment_amount_centavos'],
              'beautycita_fee_centavos': a['beautycita_fee_centavos'],
              'method': 'card',
              'status': a['payment_status'] == 'refunded' ? 'refunded' : 'completed',
              'created_at': a['starts_at'],
            })
        .toList();
  }
}
