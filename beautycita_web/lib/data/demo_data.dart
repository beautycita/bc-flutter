/// Hardcoded demo data for the read-only business portal preview.
/// Based on "Salon de Vallarta" (business 64d46f47-...).
library;

abstract final class DemoData {
  static const String businessId = '64d46f47-f161-4f3b-9935-6704cc6dfed1';

  static const Map<String, dynamic> business = {
    'id': businessId,
    'owner_id': 'eef1c030-c1ae-49ec-9352-684f018c0e56',
    'name': 'Salon de Vallarta',
    'phone': '(322) 380-0207',
    'whatsapp': '+523223800207',
    'address':
        'Priv. Politécnico Nacional, Los Portales, 48315 Puerto Vallarta, Jal., Mexico',
    'city': 'Puerto Vallarta',
    'state': 'Jalisco',
    'country': 'MX',
    'lat': 20.6645623744056,
    'lng': -105.230326730276,
    'photo_url': null,
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
    'hours': {
      'monday': {'open': '09:00', 'close': '20:00', 'breaks': []},
      'tuesday': {'open': '09:00', 'close': '20:00', 'breaks': []},
      'wednesday': {'open': '09:00', 'close': '20:00', 'breaks': []},
      'thursday': {'open': '09:00', 'close': '20:00', 'breaks': []},
      'friday': {'open': '09:00', 'close': '20:00', 'breaks': []},
      'saturday': {'open': '09:00', 'close': '20:00', 'breaks': []},
      'sunday': null,
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
  };

  // ── Staff ──────────────────────────────────────────────────────────────

  static const List<Map<String, dynamic>> staff = [
    {
      'id': '261a09a2-8e09-41da-abe6-00ce582a3607',
      'business_id': businessId,
      'first_name': 'Amber',
      'last_name': 'Elizabeth',
      'avatar_url': null,
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
      'avatar_url': null,
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
      'avatar_url': null,
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
      'avatar_url': null,
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
      'avatar_url': null,
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
      'avatar_url': null,
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
  static const Map<String, List<int>> _staffServicePool = {
    '261a09a2-8e09-41da-abe6-00ce582a3607': [0, 4, 5],       // Amber: Corte, Corte Caballero, Peinado Evento
    'd0000001-0000-4000-8000-000000000001': [1, 2, 3],        // Valentina: Balayage, Tinte Raiz, Keratina
    '98306b67-3d8c-44e3-9010-465e45afeb4d': [11, 12, 13, 14, 15], // Marcos: Maquillaje, Depilacion
    'fcd1e90a-9811-4ea6-b672-385b2c01c7c6': [3, 23, 24],      // Juan: Keratina, Tratamiento Capilar, Masaje, Facial
    'd0000001-0000-4000-8000-000000000002': [6, 7, 8, 9, 10], // Daniela: Pestanas, Cejas, Microblading
    'd0000001-0000-4000-8000-000000000003': [16, 17, 18, 19, 20, 21], // Andrea: Unas
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

    // Generate past 45 days + future 60 days
    for (var dayOffset = -45; dayOffset <= 60; dayOffset++) {
      final date = today.add(Duration(days: dayOffset));

      // Skip Sundays (salon closed)
      if (date.weekday == DateTime.sunday) continue;

      final isPast = dayOffset < 0;
      final isToday = dayOffset == 0;

      for (var si = 0; si < staffIds.length; si++) {
        final staffId = staffIds[si];
        final pool = _staffServicePool[staffId] ?? [0];

        for (var apptIdx = 0; apptIdx < 3; apptIdx++) {
          // Deterministic "random" based on day + staff + appt index
          final seed = (dayOffset + 100) * 1000 + si * 100 + apptIdx;
          final hash = (seed * 2654435761) & 0xFFFFFFFF;

          // Pick hour: spread 3 appointments across morning/midday/afternoon
          final hourSlot = apptIdx == 0
              ? startHours[hash % 3]            // morning: 9,10,11
              : apptIdx == 1
                  ? startHours[3 + (hash % 3)]  // midday: 12,13,14
                  : startHours[6 + (hash % 3)]; // afternoon: 15,16,17

          // Pick service from this staff's pool
          final svcIdx = pool[hash % pool.length];
          final svc = services[svcIdx];

          // Determine status
          String status;
          if (isPast || (isToday && hourSlot < now.hour)) {
            // 90% completed, 5% cancelled, 5% no-show
            final statusRoll = hash % 20;
            status = statusRoll == 0
                ? 'no_show'
                : statusRoll == 1
                    ? 'cancelled_customer'
                    : 'completed';
          } else {
            status = 'confirmed';
          }

          final id = 'demo-${dayOffset + 100}-$si-$apptIdx';
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
      'payment_amount_centavos': (price * 100).toInt(),
      'beautycita_fee_centavos': (price * 5).toInt(),
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

  static const List<Map<String, dynamic>> disputes = [
    {
      'id': '112b4bea-55f6-41e2-ba20-8b8f8e72752b',
      'appointment_id': 'f0000001-0001-4000-8000-000000000025',
      'business_id': businessId,
      'reason': 'El color del tinte no quedo como lo pedi.',
      'status': 'resolved',
      'resolution': 'favor_both',
      'resolution_notes': 'Cliente acepto correccion gratuita del tono.',
      'refund_amount': 0.0,
      'salon_offer': 'denied',
      'salon_offer_amount': 0.0,
      'salon_response': 'Ofrecemos correccion de tono sin costo.',
      'client_accepted': true,
      'created_at': '2026-03-01T16:07:21Z',
      'resolved_at': '2026-03-02T16:07:21Z',
    },
    {
      'id': 'abcb8de9-6e0e-4d13-9130-a233f6005608',
      'appointment_id': 'f0000001-0001-4000-8000-000000000019',
      'business_id': businessId,
      'reason': 'Me marcaron como no-show pero si llegue 20 min tarde.',
      'status': 'resolved',
      'resolution': 'favor_client',
      'resolution_notes': 'Reembolso parcial del deposito.',
      'refund_amount': 270.0,
      'refund_status': 'processed',
      'salon_offer': 'partial_refund',
      'salon_offer_amount': 270.0,
      'salon_response': 'Reembolso del 50% del deposito y reagendamos.',
      'client_accepted': true,
      'created_at': '2026-02-22T04:07:21Z',
      'resolved_at': '2026-02-23T16:07:21Z',
    },
    {
      'id': '8e747dd5-ea4a-469a-b964-64da6b889f21',
      'appointment_id': 'f0000001-0001-4000-8000-000000000014',
      'business_id': businessId,
      'reason': 'Cancele mi cita y no me devolvieron el deposito.',
      'status': 'resolved',
      'resolution': 'favor_client',
      'resolution_notes': 'Reembolso completo. Cancelacion dentro del plazo permitido.',
      'refund_amount': 150.0,
      'refund_status': 'processed',
      'salon_offer': 'full_refund',
      'salon_offer_amount': 150.0,
      'salon_response': 'Procesamos reembolso completo del deposito.',
      'client_accepted': true,
      'created_at': '2026-02-14T10:07:21Z',
      'resolved_at': '2026-02-15T16:07:21Z',
    },
  ];

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
