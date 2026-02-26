import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';

// ── Data classes ──────────────────────────────────────────────────────────────

/// Engine health metrics.
@immutable
class EngineHealth {
  final double avgResponseMs;
  final double cacheHitRate;
  final int curationsToday;

  const EngineHealth({
    required this.avgResponseMs,
    required this.cacheHitRate,
    required this.curationsToday,
  });

  static const placeholder = EngineHealth(
    avgResponseMs: 0,
    cacheHitRate: 0,
    curationsToday: 0,
  );
}

/// A service profile with tunable weights.
@immutable
class ServiceProfile {
  final String id;
  final String name;
  final String serviceType;
  final int qualityWeight;
  final int distanceWeight;
  final int priceWeight;
  final int availabilityWeight;
  final double searchRadiusKm;
  final int maxResults;

  const ServiceProfile({
    required this.id,
    required this.name,
    required this.serviceType,
    required this.qualityWeight,
    required this.distanceWeight,
    required this.priceWeight,
    required this.availabilityWeight,
    required this.searchRadiusKm,
    required this.maxResults,
  });

  ServiceProfile copyWith({
    int? qualityWeight,
    int? distanceWeight,
    int? priceWeight,
    int? availabilityWeight,
    double? searchRadiusKm,
    int? maxResults,
  }) {
    return ServiceProfile(
      id: id,
      name: name,
      serviceType: serviceType,
      qualityWeight: qualityWeight ?? this.qualityWeight,
      distanceWeight: distanceWeight ?? this.distanceWeight,
      priceWeight: priceWeight ?? this.priceWeight,
      availabilityWeight: availabilityWeight ?? this.availabilityWeight,
      searchRadiusKm: searchRadiusKm ?? this.searchRadiusKm,
      maxResults: maxResults ?? this.maxResults,
    );
  }

  static ServiceProfile fromMap(Map<String, dynamic> row) {
    return ServiceProfile(
      id: row['id'] as String? ?? '',
      name: row['name'] as String? ?? '',
      serviceType: row['service_type'] as String? ?? '',
      qualityWeight: (row['quality_weight'] as num?)?.toInt() ?? 50,
      distanceWeight: (row['distance_weight'] as num?)?.toInt() ?? 50,
      priceWeight: (row['price_weight'] as num?)?.toInt() ?? 50,
      availabilityWeight: (row['availability_weight'] as num?)?.toInt() ?? 50,
      searchRadiusKm: (row['search_radius_km'] as num?)?.toDouble() ?? 10,
      maxResults: (row['max_results'] as num?)?.toInt() ?? 3,
    );
  }
}

/// A node in the category tree.
@immutable
class CategoryNode {
  final String id;
  final String name;
  final String? parentId;
  final int sortOrder;
  final bool isActive;
  final List<CategoryNode> children;

  const CategoryNode({
    required this.id,
    required this.name,
    this.parentId,
    required this.sortOrder,
    required this.isActive,
    this.children = const [],
  });

  CategoryNode copyWith({
    String? name,
    int? sortOrder,
    bool? isActive,
    List<CategoryNode>? children,
  }) {
    return CategoryNode(
      id: id,
      name: name ?? this.name,
      parentId: parentId,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      children: children ?? this.children,
    );
  }

  static CategoryNode fromMap(Map<String, dynamic> row) {
    return CategoryNode(
      id: row['id'] as String? ?? '',
      name: row['name'] as String? ?? '',
      parentId: row['parent_id'] as String?,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      isActive: row['is_active'] as bool? ?? true,
    );
  }
}

/// A time inference rule for a service type + day of week.
@immutable
class TimeInferenceRule {
  final String id;
  final String serviceType;
  final int dayOfWeek; // 0=Mon, 6=Sun
  final int startHour;
  final int endHour;
  final int bufferMinutes;

  const TimeInferenceRule({
    required this.id,
    required this.serviceType,
    required this.dayOfWeek,
    required this.startHour,
    required this.endHour,
    required this.bufferMinutes,
  });

  TimeInferenceRule copyWith({
    int? startHour,
    int? endHour,
    int? bufferMinutes,
  }) {
    return TimeInferenceRule(
      id: id,
      serviceType: serviceType,
      dayOfWeek: dayOfWeek,
      startHour: startHour ?? this.startHour,
      endHour: endHour ?? this.endHour,
      bufferMinutes: bufferMinutes ?? this.bufferMinutes,
    );
  }

  static TimeInferenceRule fromMap(Map<String, dynamic> row) {
    return TimeInferenceRule(
      id: row['id'] as String? ?? '',
      serviceType: row['service_type'] as String? ?? '',
      dayOfWeek: (row['day_of_week'] as num?)?.toInt() ?? 0,
      startHour: (row['start_hour'] as num?)?.toInt() ?? 9,
      endHour: (row['end_hour'] as num?)?.toInt() ?? 18,
      bufferMinutes: (row['buffer_minutes'] as num?)?.toInt() ?? 30,
    );
  }
}

// ── Providers ────────────────────────────────────────────────────────────────

/// Engine health KPIs.
final engineHealthProvider = FutureProvider<EngineHealth>((ref) async {
  if (!BCSupabase.isInitialized) return EngineHealth.placeholder;

  try {
    final client = BCSupabase.client;
    final now = DateTime.now();
    final startOfDay =
        DateTime(now.year, now.month, now.day).toIso8601String();

    // Get engine settings for avg response time and cache hit rate
    final settingsRows = await client
        .from('engine_settings')
        .select('key, value')
        .inFilter('key', ['avg_response_ms', 'cache_hit_rate']);

    double avgMs = 0;
    double cacheRate = 0;
    for (final row in settingsRows) {
      final key = row['key'] as String? ?? '';
      final val = double.tryParse(row['value']?.toString() ?? '') ?? 0;
      if (key == 'avg_response_ms') avgMs = val;
      if (key == 'cache_hit_rate') cacheRate = val;
    }

    // Count curations today (appointments created via engine)
    final curResult = await client
        .from('appointments')
        .select('id')
        .gte('created_at', startOfDay)
        .count();

    return EngineHealth(
      avgResponseMs: avgMs,
      cacheHitRate: cacheRate,
      curationsToday: curResult.count,
    );
  } catch (e) {
    debugPrint('Engine health error: $e');
    return EngineHealth.placeholder;
  }
});

/// Service profiles list.
final serviceProfilesProvider =
    FutureProvider<List<ServiceProfile>>((ref) async {
  if (!BCSupabase.isInitialized) return [];

  try {
    final data = await BCSupabase.client
        .from('service_profiles')
        .select()
        .order('name');

    return data.map((row) => ServiceProfile.fromMap(row)).toList();
  } catch (e) {
    debugPrint('Service profiles error: $e');
    return [];
  }
});

/// Category tree.
final categoryTreeProvider =
    FutureProvider<List<CategoryNode>>((ref) async {
  if (!BCSupabase.isInitialized) return [];

  try {
    final data = await BCSupabase.client
        .from('service_categories_tree')
        .select()
        .order('sort_order');

    final allNodes =
        data.map((row) => CategoryNode.fromMap(row)).toList();

    // Build tree
    return _buildTree(allNodes);
  } catch (e) {
    debugPrint('Category tree error: $e');
    return [];
  }
});

List<CategoryNode> _buildTree(List<CategoryNode> flatList) {
  final Map<String, List<CategoryNode>> childrenMap = {};
  final List<CategoryNode> roots = [];

  for (final node in flatList) {
    if (node.parentId != null && node.parentId!.isNotEmpty) {
      childrenMap.putIfAbsent(node.parentId!, () => []).add(node);
    }
  }

  CategoryNode attachChildren(CategoryNode node) {
    final children = childrenMap[node.id] ?? [];
    return node.copyWith(
      children: children.map(attachChildren).toList(),
    );
  }

  for (final node in flatList) {
    if (node.parentId == null || node.parentId!.isEmpty) {
      roots.add(attachChildren(node));
    }
  }

  return roots;
}

/// Time inference rules.
final timeInferenceRulesProvider =
    FutureProvider<List<TimeInferenceRule>>((ref) async {
  if (!BCSupabase.isInitialized) return [];

  try {
    final data = await BCSupabase.client
        .from('time_inference_rules')
        .select()
        .order('service_type')
        .order('day_of_week');

    return data.map((row) => TimeInferenceRule.fromMap(row)).toList();
  } catch (e) {
    debugPrint('Time inference rules error: $e');
    return [];
  }
});
