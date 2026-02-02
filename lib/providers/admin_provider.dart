import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/services/supabase_client.dart';

/// Checks if the current user has admin role.
final isAdminProvider = FutureProvider<bool>((ref) async {
  final userId = SupabaseClientService.currentUserId;
  if (userId == null) return false;

  try {
    final response = await SupabaseClientService.client
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .single();

    return response['role'] == 'admin';
  } catch (_) {
    return false;
  }
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
      .order('day_start');

  return (response as List)
      .map((e) => TimeInferenceRule.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Fetches all businesses for the salon management screen.
final adminBusinessesProvider =
    FutureProvider<List<AdminBusiness>>((ref) async {
  final response = await SupabaseClientService.client
      .from('businesses')
      .select('id, name, tier, is_active, avg_rating, review_count')
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
// Models
// ---------------------------------------------------------------------------

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
      dayStart: json['day_start'] as int,
      dayEnd: json['day_end'] as int,
      description: json['description'] as String?,
      offsetDaysMin: json['offset_days_min'] as int? ?? 0,
      offsetDaysMax: json['offset_days_max'] as int? ?? 1,
      preferredHourStart: json['preferred_hour_start'] as int? ?? 10,
      preferredHourEnd: json['preferred_hour_end'] as int? ?? 17,
      peakHour: json['peak_hour'] as int?,
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
      avgRating: (json['avg_rating'] as num?)?.toDouble(),
      reviewCount: json['review_count'] as int?,
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
