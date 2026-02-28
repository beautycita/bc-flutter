import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';

// ── Registered salon (businesses table) ──────────────────────────────────────

@immutable
class RegisteredSalon {
  final String id;
  final String name;
  final String? city;
  final String? state;
  final double rating;
  final int totalReviews;
  final String stripeStatus; // 'not_started', 'pending', 'complete'
  final bool verified;
  final bool isActive;
  final String? phone;
  final int tier;
  final DateTime createdAt;
  final String? photoUrl;

  const RegisteredSalon({
    required this.id,
    required this.name,
    this.city,
    this.state,
    this.rating = 0,
    this.totalReviews = 0,
    this.stripeStatus = 'not_started',
    this.verified = false,
    this.isActive = true,
    this.phone,
    this.tier = 1,
    required this.createdAt,
    this.photoUrl,
  });

  factory RegisteredSalon.fromJson(Map<String, dynamic> json) {
    return RegisteredSalon(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Sin nombre',
      city: json['city'] as String?,
      state: json['state'] as String?,
      rating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      totalReviews: json['total_reviews'] as int? ?? 0,
      stripeStatus: json['stripe_onboarding_status'] as String? ?? 'not_started',
      verified: json['is_verified'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      phone: json['phone'] as String?,
      tier: json['tier'] as int? ?? 1,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      photoUrl: json['photo_url'] as String?,
    );
  }
}

// ── Discovered salon (discovered_salons table) ───────────────────────────────

@immutable
class DiscoveredSalon {
  final String id;
  final String name;
  final String? source; // 'google_maps', 'facebook', 'bing'
  final String? phone;
  final String? city;
  final String? country; // 'MX', 'US'
  final String waStatus; // 'valid', 'invalid', 'unknown'
  final DateTime? lastContactDate;
  final int interestSignals;
  final String? address;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;

  const DiscoveredSalon({
    required this.id,
    required this.name,
    this.source,
    this.phone,
    this.city,
    this.country,
    this.waStatus = 'unknown',
    this.lastContactDate,
    this.interestSignals = 0,
    this.address,
    this.latitude,
    this.longitude,
    required this.createdAt,
  });

  factory DiscoveredSalon.fromJson(Map<String, dynamic> json) {
    return DiscoveredSalon(
      id: json['id']?.toString() ?? '',
      name: json['business_name'] as String? ?? 'Sin nombre',
      source: json['source'] as String?,
      phone: json['phone'] as String?,
      city: json['location_city'] as String?,
      country: json['country'] as String?,
      waStatus: json['whatsapp_verified'] == true
          ? 'valid'
          : json['whatsapp_verified'] == false
              ? 'invalid'
              : 'unknown',
      lastContactDate:
          DateTime.tryParse(json['last_outreach_at'] as String? ?? ''),
      interestSignals: json['interest_count'] as int? ?? 0,
      address: json['location_address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

// ── Page data ─────────────────────────────────────────────────────────────────

@immutable
class RegisteredSalonsData {
  final List<RegisteredSalon> salons;
  final int totalCount;
  const RegisteredSalonsData({required this.salons, required this.totalCount});
  static const empty = RegisteredSalonsData(salons: [], totalCount: 0);
}

@immutable
class DiscoveredSalonsData {
  final List<DiscoveredSalon> salons;
  final int totalCount;
  const DiscoveredSalonsData({required this.salons, required this.totalCount});
  static const empty = DiscoveredSalonsData(salons: [], totalCount: 0);
}

// ── Filters ───────────────────────────────────────────────────────────────────

@immutable
class SalonsFilter {
  final String? city;
  final String? country;
  final String searchText;
  final bool? verified;
  final int page;
  final int pageSize;
  final String? sortColumn;
  final bool sortAscending;

  const SalonsFilter({
    this.city,
    this.country,
    this.searchText = '',
    this.verified,
    this.page = 0,
    this.pageSize = 20,
    this.sortColumn,
    this.sortAscending = true,
  });

  SalonsFilter copyWith({
    String? Function()? city,
    String? Function()? country,
    String? searchText,
    bool? Function()? verified,
    int? page,
    int? pageSize,
    String? Function()? sortColumn,
    bool? sortAscending,
  }) {
    return SalonsFilter(
      city: city != null ? city() : this.city,
      country: country != null ? country() : this.country,
      searchText: searchText ?? this.searchText,
      verified: verified != null ? verified() : this.verified,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      sortColumn: sortColumn != null ? sortColumn() : this.sortColumn,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }

  bool get hasActiveFilters =>
      city != null ||
      country != null ||
      searchText.isNotEmpty ||
      verified != null;
}

// ── Providers ─────────────────────────────────────────────────────────────────

final registeredSalonsFilterProvider = StateProvider<SalonsFilter>(
  (ref) => const SalonsFilter(),
);

final discoveredSalonsFilterProvider = StateProvider<SalonsFilter>(
  (ref) => const SalonsFilter(),
);

final registeredSalonsProvider =
    FutureProvider<RegisteredSalonsData>((ref) async {
  final filter = ref.watch(registeredSalonsFilterProvider);

  if (!BCSupabase.isInitialized) return RegisteredSalonsData.empty;

  try {
    final client = BCSupabase.client;
    final sortCol = filter.sortColumn ?? 'created_at';
    final from = filter.page * filter.pageSize;
    final to = from + filter.pageSize - 1;

    // Build base query with equality filters
    var query = client.from(BCTables.businesses).select(
      'id, name, city, state, average_rating, total_reviews, '
      'stripe_onboarding_status, is_verified, is_active, phone, tier, '
      'created_at, photo_url',
    );
    if (filter.city != null) {
      query = query.eq('city', filter.city!);
    }
    if (filter.verified != null) {
      query = query.eq('is_verified', filter.verified!);
    }

    // .or() changes return type, so chain everything after it
    final List data;
    if (filter.searchText.isNotEmpty) {
      data = await query
          .or(
            'name.ilike.%${filter.searchText}%,'
            'city.ilike.%${filter.searchText}%,'
            'phone.ilike.%${filter.searchText}%',
          )
          .order(sortCol, ascending: filter.sortAscending)
          .range(from, to);
    } else {
      data = await query
          .order(sortCol, ascending: filter.sortAscending)
          .range(from, to);
    }

    // Count query
    var countQuery = client.from(BCTables.businesses).select('id');
    if (filter.city != null) {
      countQuery = countQuery.eq('city', filter.city!);
    }
    if (filter.verified != null) {
      countQuery = countQuery.eq('is_verified', filter.verified!);
    }
    final int totalCount;
    if (filter.searchText.isNotEmpty) {
      final r = await countQuery
          .or(
            'name.ilike.%${filter.searchText}%,'
            'city.ilike.%${filter.searchText}%,'
            'phone.ilike.%${filter.searchText}%',
          )
          .count();
      totalCount = r.count;
    } else {
      final r = await countQuery.count();
      totalCount = r.count;
    }

    final salons = data
        .map((row) => RegisteredSalon.fromJson(row as Map<String, dynamic>))
        .toList();

    return RegisteredSalonsData(salons: salons, totalCount: totalCount);
  } catch (e) {
    debugPrint('Registered salons error: $e');
    return RegisteredSalonsData.empty;
  }
});

final discoveredSalonsProvider =
    FutureProvider<DiscoveredSalonsData>((ref) async {
  final filter = ref.watch(discoveredSalonsFilterProvider);

  if (!BCSupabase.isInitialized) return DiscoveredSalonsData.empty;

  try {
    final client = BCSupabase.client;
    final sortCol = filter.sortColumn ?? 'created_at';
    final from = filter.page * filter.pageSize;
    final to = from + filter.pageSize - 1;

    // Build base query with equality filters
    var query = client.from(BCTables.discoveredSalons).select(
      'id, business_name, source, phone, location_city, country, '
      'whatsapp_verified, last_outreach_at, interest_count, '
      'location_address, latitude, longitude, created_at',
    );
    if (filter.city != null) {
      query = query.eq('location_city', filter.city!);
    }
    if (filter.country != null) {
      query = query.eq('country', filter.country!);
    }

    // .or() changes return type, so chain everything after it
    final List data;
    if (filter.searchText.isNotEmpty) {
      data = await query
          .or(
            'business_name.ilike.%${filter.searchText}%,'
            'location_city.ilike.%${filter.searchText}%,'
            'phone.ilike.%${filter.searchText}%',
          )
          .order(sortCol, ascending: filter.sortAscending)
          .range(from, to);
    } else {
      data = await query
          .order(sortCol, ascending: filter.sortAscending)
          .range(from, to);
    }

    // Count query
    var countQuery = client.from(BCTables.discoveredSalons).select('id');
    if (filter.city != null) {
      countQuery = countQuery.eq('location_city', filter.city!);
    }
    if (filter.country != null) {
      countQuery = countQuery.eq('country', filter.country!);
    }
    final int totalCount;
    if (filter.searchText.isNotEmpty) {
      final r = await countQuery
          .or(
            'business_name.ilike.%${filter.searchText}%,'
            'location_city.ilike.%${filter.searchText}%,'
            'phone.ilike.%${filter.searchText}%',
          )
          .count();
      totalCount = r.count;
    } else {
      final r = await countQuery.count();
      totalCount = r.count;
    }

    final salons = data
        .map((row) => DiscoveredSalon.fromJson(row as Map<String, dynamic>))
        .toList();

    return DiscoveredSalonsData(salons: salons, totalCount: totalCount);
  } catch (e) {
    debugPrint('Discovered salons error: $e');
    return DiscoveredSalonsData.empty;
  }
});
