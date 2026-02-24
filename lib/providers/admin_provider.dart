import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;
import 'package:beautycita/services/supabase_client.dart';

/// Stream of Supabase auth state changes — re-triggers role fetch on login/logout.
final _supabaseAuthStreamProvider = StreamProvider<AuthState>((ref) {
  if (!SupabaseClientService.isInitialized) return const Stream.empty();
  return SupabaseClientService.client.auth.onAuthStateChange;
});

/// Fetches the current user's role string. Re-evaluates on auth state changes.
final _userRoleProvider = FutureProvider<String?>((ref) async {
  // Watch auth stream so provider re-runs on sign-in, sign-out, token refresh
  ref.watch(_supabaseAuthStreamProvider);

  final userId = SupabaseClientService.currentUserId;
  if (userId == null) return null;

  try {
    final response = await SupabaseClientService.client
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .single();

    final role = response['role'] as String?;
    debugPrint('AdminProvider: userId=$userId, role=$role');
    return role;
  } catch (e) {
    debugPrint('AdminProvider: failed to fetch role for $userId: $e');
    return null;
  }
});

/// True for admin OR superadmin — can access admin panel.
final isAdminProvider = FutureProvider<bool>((ref) async {
  final role = await ref.watch(_userRoleProvider.future);
  return role == 'admin' || role == 'superadmin';
});

/// True ONLY for superadmin — can modify engine config, feature toggles,
/// category tree, time rules, notification templates.
/// Admin role gets read-only access to dashboards + user/dispute management.
final isSuperAdminProvider = FutureProvider<bool>((ref) async {
  final role = await ref.watch(_userRoleProvider.future);
  return role == 'superadmin';
});

/// Fetches all engine settings grouped by group_name.
final engineSettingsProvider =
    FutureProvider<List<EngineSetting>>((ref) async {
  final response = await SupabaseClientService.client
      .from('engine_settings')
      .select()
      .order('group_name')
      .order('sort_order');

  return (response as List)
      .map((e) => EngineSetting.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Fetches all service profiles for the editor.
final serviceProfilesProvider =
    FutureProvider<List<ServiceProfileAdmin>>((ref) async {
  final response = await SupabaseClientService.client
      .from('service_profiles')
      .select()
      .order('category')
      .order('service_type');

  return (response as List)
      .map((e) => ServiceProfileAdmin.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Fetches the full category tree for the admin editor.
final categoryTreeProvider =
    FutureProvider<List<CategoryNode>>((ref) async {
  final response = await SupabaseClientService.client
      .from('service_categories_tree')
      .select()
      .order('sort_order');

  return (response as List)
      .map((e) => CategoryNode.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Fetches all time inference rules.
final timeInferenceRulesProvider =
    FutureProvider<List<TimeInferenceRule>>((ref) async {
  final response = await SupabaseClientService.client
      .from('time_inference_rules')
      .select()
      .order('hour_start')
      .order('day_of_week_start');

  return (response as List)
      .map((e) => TimeInferenceRule.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Fetches all businesses for the salon management screen.
final adminBusinessesProvider =
    FutureProvider<List<AdminBusiness>>((ref) async {
  final response = await SupabaseClientService.client
      .from('businesses')
      .select('id, name, tier, is_active, average_rating, total_reviews')
      .order('name');

  return (response as List)
      .map((e) => AdminBusiness.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Fetches all notification templates.
final notificationTemplatesProvider =
    FutureProvider<List<NotificationTemplate>>((ref) async {
  final response = await SupabaseClientService.client
      .from('notification_templates')
      .select()
      .order('event_type')
      .order('channel');

  return (response as List)
      .map((e) => NotificationTemplate.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ---------------------------------------------------------------------------
// Dashboard & Management Providers
// ---------------------------------------------------------------------------

/// Dashboard stats aggregated from multiple tables.
final adminDashStatsProvider = FutureProvider<AdminStats>((ref) async {
  final client = SupabaseClientService.client;
  final today = DateTime.now().toIso8601String().split('T')[0];
  final firstOfMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1).toIso8601String();

  final results = await Future.wait([
    client.from('profiles').select('id'),
    client.from('profiles').select('id').eq('role', 'stylist'),
    client.from('appointments').select('id').gte('created_at', today),
    client
        .from('appointments')
        .select('price')
        .gte('created_at', firstOfMonth)
        .eq('status', 'completed'),
    client
        .from('stylist_applications')
        .select('id')
        .eq('status', 'pending'),
    client.from('disputes').select('id').eq('status', 'open'),
  ]);

  double revenue = 0;
  for (final row in (results[3] as List)) {
    revenue += ((row as Map)['price'] as num?)?.toDouble() ?? 0;
  }

  return AdminStats(
    totalUsers: (results[0] as List).length,
    activeStylists: (results[1] as List).length,
    bookingsToday: (results[2] as List).length,
    revenueMonth: revenue,
    pendingApplications: (results[4] as List).length,
    openDisputes: (results[5] as List).length,
  );
});

/// Recent activity feed — last bookings, disputes, new users.
final adminRecentActivityProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = SupabaseClientService.client;

  final results = await Future.wait([
    client
        .from('appointments')
        .select('id, created_at, status')
        .order('created_at', ascending: false)
        .limit(5),
    client
        .from('disputes')
        .select('id, created_at, status')
        .order('created_at', ascending: false)
        .limit(3),
    client
        .from('profiles')
        .select('id, full_name, created_at')
        .order('created_at', ascending: false)
        .limit(5),
  ]);

  final activities = <Map<String, dynamic>>[];

  for (final row in (results[0] as List)) {
    final m = row as Map<String, dynamic>;
    activities.add({
      'type': 'booking',
      'description': 'Nueva cita: ${m['status']}',
      'created_at': m['created_at'],
    });
  }
  for (final row in (results[1] as List)) {
    final m = row as Map<String, dynamic>;
    activities.add({
      'type': 'dispute',
      'description': 'Disputa abierta',
      'created_at': m['created_at'],
    });
  }
  for (final row in (results[2] as List)) {
    final m = row as Map<String, dynamic>;
    activities.add({
      'type': 'user',
      'description': 'Nuevo usuario: ${m['full_name'] ?? 'Sin nombre'}',
      'created_at': m['created_at'],
    });
  }

  activities.sort((a, b) =>
      (b['created_at'] as String).compareTo(a['created_at'] as String));
  return activities.take(10).toList();
});

/// Full recent activity feed for the dedicated screen (50 items).
final adminFullActivityProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = SupabaseClientService.client;

  final results = await Future.wait([
    client
        .from('appointments')
        .select('id, created_at, status, starts_at, price, business_id, businesses(name)')
        .order('created_at', ascending: false)
        .limit(25),
    client
        .from('disputes')
        .select('id, created_at, status, reason, resolution')
        .order('created_at', ascending: false)
        .limit(15),
    client
        .from('profiles')
        .select('id, full_name, username, phone, role, created_at')
        .order('created_at', ascending: false)
        .limit(15),
  ]);

  final activities = <Map<String, dynamic>>[];

  for (final row in (results[0] as List)) {
    final m = row as Map<String, dynamic>;
    final bizName = (m['businesses'] as Map?)?['name'] ?? 'Sin negocio';
    activities.add({
      'type': 'booking',
      'description': 'Cita: ${m['status']}',
      'detail': 'Negocio: $bizName\nEstatus: ${m['status']}\nPrecio: \$${m['price'] ?? 0}\nInicio: ${m['starts_at'] ?? '-'}',
      'created_at': m['created_at'],
      'raw': m,
    });
  }
  for (final row in (results[1] as List)) {
    final m = row as Map<String, dynamic>;
    activities.add({
      'type': 'dispute',
      'description': 'Disputa: ${m['status']}',
      'detail': 'Razon: ${m['reason'] ?? '-'}\nEstatus: ${m['status']}\nResolucion: ${m['resolution'] ?? 'Pendiente'}',
      'created_at': m['created_at'],
      'raw': m,
    });
  }
  for (final row in (results[2] as List)) {
    final m = row as Map<String, dynamic>;
    activities.add({
      'type': 'user',
      'description': 'Nuevo usuario: ${m['full_name'] ?? m['username'] ?? 'Sin nombre'}',
      'detail': 'Nombre: ${m['full_name'] ?? '-'}\nUsuario: ${m['username'] ?? '-'}\nTelefono: ${m['phone'] ?? '-'}\nRol: ${m['role'] ?? 'customer'}',
      'created_at': m['created_at'],
      'raw': m,
    });
  }

  activities.sort((a, b) =>
      (b['created_at'] as String).compareTo(a['created_at'] as String));
  return activities.take(50).toList();
});

/// All users from profiles table.
final adminUsersProvider = FutureProvider<List<AdminUser>>((ref) async {
  final response = await SupabaseClientService.client
      .from('profiles')
      .select('id, username, full_name, phone, role, status, created_at, last_seen, avatar_url, birthday, gender, home_address, uber_linked, updated_at, registration_source, phone_verified')
      .order('created_at', ascending: false);

  return (response as List)
      .map((e) => AdminUser.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// All disputes with appointment and business details.
final adminDisputesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await SupabaseClientService.client
      .from('disputes')
      .select('*, appointments(id, service_name, price, starts_at, status, user_id, businesses(name, owner_id, stripe_account_id))')
      .order('created_at', ascending: false);
  return (response as List).cast<Map<String, dynamic>>();
});

/// Salon applications (unverified businesses pending admin review).
final adminApplicationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await SupabaseClientService.client
      .from('businesses')
      .select()
      .eq('is_verified', false)
      .order('created_at', ascending: false);
  return (response as List).cast<Map<String, dynamic>>();
});

/// All appointments (bookings) with business name.
final adminBookingsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await SupabaseClientService.client
      .from('appointments')
      .select('*, businesses(name)')
      .order('created_at', ascending: false);
  return (response as List).cast<Map<String, dynamic>>();
});

/// All reviews (admin view).
final adminReviewsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await SupabaseClientService.client
      .from('reviews')
      .select('*, businesses(name)')
      .order('created_at', ascending: false)
      .limit(100);
  return (response as List).cast<Map<String, dynamic>>();
});

/// Discovered salons for outreach management.
final adminDiscoveredSalonsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await SupabaseClientService.client
      .from('discovered_salons')
      .select('id, business_name, phone, whatsapp, location_city, location_state, latitude, longitude, feature_image_url, rating_average, rating_count, interest_count, categories, status, outreach_count, last_outreach_at, outreach_channel, created_at')
      .order('interest_count', ascending: false)
      .limit(200);
  return (response as List).cast<Map<String, dynamic>>();
});

/// Outreach log for a specific salon.
final salonOutreachLogProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, salonId) async {
  final response = await SupabaseClientService.client
      .from('salon_outreach_log')
      .select()
      .eq('discovered_salon_id', salonId)
      .order('sent_at', ascending: false)
      .limit(20);
  return (response as List).cast<Map<String, dynamic>>();
});

/// Feature toggles from app_config (data_type == 'bool').
final adminFeatureTogglesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await SupabaseClientService.client
      .from('app_config')
      .select()
      .eq('data_type', 'bool')
      .order('group_name')
      .order('key');
  return (response as List).cast<Map<String, dynamic>>();
});

/// Inserts an entry into the audit_log table.
Future<void> adminLogAction({
  required String action,
  required String targetType,
  String? targetId,
  Map<String, dynamic>? details,
}) async {
  final userId = SupabaseClientService.currentUserId;
  if (userId == null) return;

  await SupabaseClientService.client.from('audit_log').insert({
    'admin_id': userId,
    'action': action,
    'target_type': targetType,
    'target_id': targetId,
    'details': details ?? {},
  });
}

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class AdminUser {
  final String id;
  final String username;
  final String? fullName;
  final String? phone;
  final String role;
  final String status;
  final String? createdAt;
  final String? updatedAt;
  final DateTime? lastSeen;
  final String? avatarUrl;
  final String? birthday;
  final String? gender;
  final String? homeAddress;
  final bool uberLinked;
  final String? registrationSource;
  final bool phoneVerified;

  const AdminUser({
    required this.id,
    required this.username,
    this.fullName,
    this.phone,
    required this.role,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
    this.lastSeen,
    this.avatarUrl,
    this.birthday,
    this.gender,
    this.homeAddress,
    this.uberLinked = false,
    this.registrationSource,
    this.phoneVerified = false,
  });

  /// Online if last_seen within last 5 minutes.
  bool get isOnline {
    if (lastSeen == null) return false;
    return DateTime.now().toUtc().difference(lastSeen!).inMinutes < 5;
  }

  /// Human-readable last seen text.
  String get lastSeenText {
    if (lastSeen == null) return 'Nunca';
    final diff = DateTime.now().toUtc().difference(lastSeen!);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    if (diff.inDays < 30) return 'Hace ${diff.inDays}d';
    return lastSeen!.toLocal().toString().split('.')[0];
  }

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as String,
      username: json['username'] as String? ?? '',
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
      role: json['role'] as String? ?? 'customer',
      status: json['status'] as String? ?? 'active',
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      lastSeen: json['last_seen'] != null
          ? DateTime.tryParse(json['last_seen'] as String)
          : null,
      avatarUrl: json['avatar_url'] as String?,
      birthday: json['birthday'] as String?,
      gender: json['gender'] as String?,
      homeAddress: json['home_address'] as String?,
      uberLinked: json['uber_linked'] as bool? ?? false,
      registrationSource: json['registration_source'] as String?,
      phoneVerified: json['phone_verified'] as bool? ?? false,
    );
  }
}

/// Fetches auth info for a specific user (admin-only RPC).
final adminUserAuthInfoProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, userId) async {
  final response = await SupabaseClientService.client
      .rpc('admin_get_user_auth_info', params: {'p_user_id': userId});
  return response as Map<String, dynamic>? ?? {};
});

class AdminStats {
  final int totalUsers;
  final int activeStylists;
  final int bookingsToday;
  final double revenueMonth;
  final int pendingApplications;
  final int openDisputes;

  const AdminStats({
    required this.totalUsers,
    required this.activeStylists,
    required this.bookingsToday,
    required this.revenueMonth,
    required this.pendingApplications,
    required this.openDisputes,
  });
}

class EngineSetting {
  final String key;
  final String value;
  final String dataType;
  final double? minValue;
  final double? maxValue;
  final String? descriptionEs;
  final String groupName;
  final int sortOrder;

  const EngineSetting({
    required this.key,
    required this.value,
    required this.dataType,
    this.minValue,
    this.maxValue,
    this.descriptionEs,
    required this.groupName,
    required this.sortOrder,
  });

  factory EngineSetting.fromJson(Map<String, dynamic> json) {
    return EngineSetting(
      key: json['key'] as String,
      value: json['value'] as String,
      dataType: json['data_type'] as String? ?? 'number',
      minValue: (json['min_value'] as num?)?.toDouble(),
      maxValue: (json['max_value'] as num?)?.toDouble(),
      descriptionEs: json['description_es'] as String?,
      groupName: json['group_name'] as String,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}

class ServiceProfileAdmin {
  final String serviceType;
  final String? category;
  final String? subcategory;
  final bool isActive;
  final double availabilityLevel;
  final int typicalDuration;
  final double skillCriticality;
  final double priceVariance;
  final double portfolioImportance;
  final String typicalLeadTime;
  final bool isEventService;
  final double searchRadiusKm;
  final bool radiusAutoExpand;
  final double radiusMaxMultiplier;
  final double weightProximity;
  final double weightAvailability;
  final double weightRating;
  final double weightPrice;
  final double weightPortfolio;
  final bool showPriceComparison;
  final bool showPortfolioCarousel;
  final bool showExperienceYears;
  final bool showCertificationBadge;
  final bool showWalkinIndicator;

  const ServiceProfileAdmin({
    required this.serviceType,
    this.category,
    this.subcategory,
    required this.isActive,
    required this.availabilityLevel,
    required this.typicalDuration,
    required this.skillCriticality,
    required this.priceVariance,
    required this.portfolioImportance,
    required this.typicalLeadTime,
    required this.isEventService,
    required this.searchRadiusKm,
    required this.radiusAutoExpand,
    required this.radiusMaxMultiplier,
    required this.weightProximity,
    required this.weightAvailability,
    required this.weightRating,
    required this.weightPrice,
    required this.weightPortfolio,
    required this.showPriceComparison,
    required this.showPortfolioCarousel,
    required this.showExperienceYears,
    required this.showCertificationBadge,
    required this.showWalkinIndicator,
  });

  factory ServiceProfileAdmin.fromJson(Map<String, dynamic> json) {
    return ServiceProfileAdmin(
      serviceType: json['service_type'] as String,
      category: json['category'] as String?,
      subcategory: json['subcategory'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      availabilityLevel: (json['availability_level'] as num?)?.toDouble() ?? 0.5,
      typicalDuration: json['typical_duration'] as int? ?? 45,
      skillCriticality: (json['skill_criticality'] as num?)?.toDouble() ?? 0.3,
      priceVariance: (json['price_variance'] as num?)?.toDouble() ?? 0.2,
      portfolioImportance:
          (json['portfolio_importance'] as num?)?.toDouble() ?? 0.0,
      typicalLeadTime: json['typical_lead_time'] as String? ?? 'same_day',
      isEventService: json['is_event_service'] as bool? ?? false,
      searchRadiusKm: (json['search_radius_km'] as num?)?.toDouble() ?? 8.0,
      radiusAutoExpand: json['radius_auto_expand'] as bool? ?? true,
      radiusMaxMultiplier:
          (json['radius_max_multiplier'] as num?)?.toDouble() ?? 3.0,
      weightProximity: (json['weight_proximity'] as num?)?.toDouble() ?? 0.4,
      weightAvailability:
          (json['weight_availability'] as num?)?.toDouble() ?? 0.25,
      weightRating: (json['weight_rating'] as num?)?.toDouble() ?? 0.2,
      weightPrice: (json['weight_price'] as num?)?.toDouble() ?? 0.15,
      weightPortfolio: (json['weight_portfolio'] as num?)?.toDouble() ?? 0.0,
      showPriceComparison: json['show_price_comparison'] as bool? ?? false,
      showPortfolioCarousel: json['show_portfolio_carousel'] as bool? ?? false,
      showExperienceYears: json['show_experience_years'] as bool? ?? false,
      showCertificationBadge:
          json['show_certification_badge'] as bool? ?? false,
      showWalkinIndicator: json['show_walkin_indicator'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'availability_level': availabilityLevel,
      'typical_duration': typicalDuration,
      'skill_criticality': skillCriticality,
      'price_variance': priceVariance,
      'portfolio_importance': portfolioImportance,
      'typical_lead_time': typicalLeadTime,
      'is_event_service': isEventService,
      'search_radius_km': searchRadiusKm,
      'radius_auto_expand': radiusAutoExpand,
      'radius_max_multiplier': radiusMaxMultiplier,
      'weight_proximity': weightProximity,
      'weight_availability': weightAvailability,
      'weight_rating': weightRating,
      'weight_price': weightPrice,
      'weight_portfolio': weightPortfolio,
      'show_price_comparison': showPriceComparison,
      'show_portfolio_carousel': showPortfolioCarousel,
      'show_experience_years': showExperienceYears,
      'show_certification_badge': showCertificationBadge,
      'show_walkin_indicator': showWalkinIndicator,
    };
  }
}

class CategoryNode {
  final String id;
  final String? parentId;
  final String slug;
  final String displayNameEs;
  final String displayNameEn;
  final String? icon;
  final int sortOrder;
  final int depth;
  final bool isLeaf;
  final String? serviceType;
  final bool isActive;

  const CategoryNode({
    required this.id,
    this.parentId,
    required this.slug,
    required this.displayNameEs,
    required this.displayNameEn,
    this.icon,
    required this.sortOrder,
    required this.depth,
    required this.isLeaf,
    this.serviceType,
    required this.isActive,
  });

  factory CategoryNode.fromJson(Map<String, dynamic> json) {
    return CategoryNode(
      id: json['id'] as String,
      parentId: json['parent_id'] as String?,
      slug: json['slug'] as String,
      displayNameEs: json['display_name_es'] as String,
      displayNameEn: json['display_name_en'] as String,
      icon: json['icon'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      depth: json['depth'] as int,
      isLeaf: json['is_leaf'] as bool? ?? false,
      serviceType: json['service_type'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class TimeInferenceRule {
  final String id;
  final int hourStart;
  final int hourEnd;
  final int dayStart;
  final int dayEnd;
  final String? description;
  final int offsetDaysMin;
  final int offsetDaysMax;
  final int preferredHourStart;
  final int preferredHourEnd;
  final int? peakHour;
  final bool isActive;

  const TimeInferenceRule({
    required this.id,
    required this.hourStart,
    required this.hourEnd,
    required this.dayStart,
    required this.dayEnd,
    this.description,
    required this.offsetDaysMin,
    required this.offsetDaysMax,
    required this.preferredHourStart,
    required this.preferredHourEnd,
    this.peakHour,
    required this.isActive,
  });

  factory TimeInferenceRule.fromJson(Map<String, dynamic> json) {
    return TimeInferenceRule(
      id: json['id'] as String,
      hourStart: json['hour_start'] as int,
      hourEnd: json['hour_end'] as int,
      dayStart: json['day_of_week_start'] as int,
      dayEnd: json['day_of_week_end'] as int,
      description: json['window_description'] as String?,
      offsetDaysMin: json['window_offset_days_min'] as int? ?? 0,
      offsetDaysMax: json['window_offset_days_max'] as int? ?? 1,
      preferredHourStart: json['preferred_hour_start'] as int? ?? 10,
      preferredHourEnd: json['preferred_hour_end'] as int? ?? 16,
      peakHour: json['preference_peak_hour'] as int?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class AdminBusiness {
  final String id;
  final String name;
  final int? tier;
  final bool isActive;
  final double? avgRating;
  final int? reviewCount;

  const AdminBusiness({
    required this.id,
    required this.name,
    this.tier,
    required this.isActive,
    this.avgRating,
    this.reviewCount,
  });

  factory AdminBusiness.fromJson(Map<String, dynamic> json) {
    return AdminBusiness(
      id: json['id'] as String,
      name: json['name'] as String,
      tier: json['tier'] as int?,
      isActive: json['is_active'] as bool? ?? true,
      avgRating: (json['average_rating'] as num?)?.toDouble(),
      reviewCount: (json['total_reviews'] as num?)?.toInt(),
    );
  }
}

class NotificationTemplate {
  final String id;
  final String eventType;
  final String channel;
  final String? subjectEs;
  final String bodyEs;
  final bool isActive;

  const NotificationTemplate({
    required this.id,
    required this.eventType,
    required this.channel,
    this.subjectEs,
    required this.bodyEs,
    required this.isActive,
  });

  factory NotificationTemplate.fromJson(Map<String, dynamic> json) {
    return NotificationTemplate(
      id: json['id'] as String,
      eventType: json['event_type'] as String,
      channel: json['channel'] as String,
      subjectEs: json['subject_es'] as String?,
      bodyEs: json['body_es'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
