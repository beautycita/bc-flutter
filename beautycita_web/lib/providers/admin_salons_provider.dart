import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';

/// Strip PostgREST filter metacharacters to prevent filter injection via .or().
String _sanitize(String input) =>
    input.replaceAll(RegExp(r'[.,()\\]'), '').trim();

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
  final bool onHold;
  final String? phone;
  final int tier;
  final DateTime createdAt;
  final String? photoUrl;
  final String? municipalLicenseUrl;
  final String municipalLicenseStatus; // 'none', 'pending', 'approved', 'rejected'

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
    this.onHold = false,
    this.phone,
    this.tier = 1,
    required this.createdAt,
    this.photoUrl,
    this.municipalLicenseUrl,
    this.municipalLicenseStatus = 'none',
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
      onHold: json['on_hold'] as bool? ?? false,
      phone: json['phone'] as String?,
      tier: json['tier'] as int? ?? 1,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      photoUrl: json['photo_url'] as String?,
      municipalLicenseUrl: json['municipal_license_url'] as String?,
      municipalLicenseStatus: json['municipal_license_status'] as String? ?? 'none',
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
  final String? state;
  final String? country; // 'MX', 'US'
  final String waStatus; // 'valid', 'invalid', 'unknown'
  final DateTime? lastContactDate;
  final int interestSignals;
  final String? address;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  // Enrichment fields
  final double? rating;
  final int? reviewCount;
  final String? photoUrl;
  final String? website;
  final String? instagramUrl;
  final String? igBio;
  final int? igFollowers;
  final List<String> categories;
  final List<String> specialties;
  final String? workingHours;
  final DateTime? igEnrichedAt;
  final DateTime? waCheckedAt;
  // Booking enrichment fields
  final String? bookingSystem;
  final String? bookingUrl;
  final String? calendarUrl;
  final DateTime? bookingEnrichedAt;
  final String? email;
  // Additional enrichment fields
  final List<String> portfolioImages;
  final String? igPostCaptions;
  final String? facebookUrl;
  final bool? whatsappVerified;
  final dynamic servicesDetected; // jsonb — list or map
  final String? bio; // Google scraped bio
  // Business intelligence estimates
  final int? estMonthlyClients;
  final double? estDailyClients;
  final double? estAvgServicePrice;
  final double? estMonthlyRevenue;
  final double? estAnnualRevenue;

  const DiscoveredSalon({
    required this.id,
    required this.name,
    this.source,
    this.phone,
    this.city,
    this.state,
    this.country,
    this.waStatus = 'unknown',
    this.lastContactDate,
    this.interestSignals = 0,
    this.address,
    this.latitude,
    this.longitude,
    required this.createdAt,
    this.rating,
    this.reviewCount,
    this.photoUrl,
    this.website,
    this.instagramUrl,
    this.igBio,
    this.igFollowers,
    this.categories = const [],
    this.specialties = const [],
    this.workingHours,
    this.igEnrichedAt,
    this.waCheckedAt,
    this.bookingSystem,
    this.bookingUrl,
    this.calendarUrl,
    this.bookingEnrichedAt,
    this.email,
    this.portfolioImages = const [],
    this.igPostCaptions,
    this.facebookUrl,
    this.whatsappVerified,
    this.servicesDetected,
    this.bio,
    this.estMonthlyClients,
    this.estDailyClients,
    this.estAvgServicePrice,
    this.estMonthlyRevenue,
    this.estAnnualRevenue,
  });

  bool get isIgEnriched => igEnrichedAt != null;
  bool get isWaChecked => waCheckedAt != null;

  factory DiscoveredSalon.fromJson(Map<String, dynamic> json) {
    return DiscoveredSalon(
      id: json['id']?.toString() ?? '',
      name: json['business_name'] as String? ?? 'Sin nombre',
      source: json['source'] as String?,
      phone: json['phone'] as String?,
      city: json['location_city'] as String?,
      state: json['location_state'] as String?,
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
      rating: (json['rating_average'] as num?)?.toDouble(),
      reviewCount: json['rating_count'] as int?,
      photoUrl: json['feature_image_url'] as String?,
      website: json['website'] as String?,
      instagramUrl: json['instagram_url'] as String?,
      igBio: json['ig_bio'] as String?,
      igFollowers: json['ig_followers'] as int?,
      categories: (json['matched_categories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      specialties: (json['specialties'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      workingHours: json['working_hours'] as String?,
      igEnrichedAt:
          DateTime.tryParse(json['ig_enriched_at'] as String? ?? ''),
      waCheckedAt:
          DateTime.tryParse(json['whatsapp_checked_at'] as String? ?? ''),
      bookingSystem: json['booking_system'] as String?,
      bookingUrl: json['booking_url'] as String?,
      calendarUrl: json['calendar_url'] as String?,
      bookingEnrichedAt:
          DateTime.tryParse(json['booking_enriched_at'] as String? ?? ''),
      email: json['email'] as String?,
      portfolioImages: (json['portfolio_images'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      igPostCaptions: json['ig_post_captions'] as String?,
      facebookUrl: json['facebook_url'] as String?,
      whatsappVerified: json['whatsapp_verified'] as bool?,
      servicesDetected: json['services_detected'],
      bio: json['bio'] as String?,
      estMonthlyClients: json['est_monthly_clients'] as int?,
      estDailyClients: (json['est_daily_clients'] as num?)?.toDouble(),
      estAvgServicePrice: (json['est_avg_service_price'] as num?)?.toDouble(),
      estMonthlyRevenue: (json['est_monthly_revenue'] as num?)?.toDouble(),
      estAnnualRevenue: (json['est_annual_revenue'] as num?)?.toDouble(),
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
  final String? enrichmentFilter; // 'ig_enriched', 'wa_verified', 'wa_checked', 'has_photo', 'has_website'
  final int page;
  final int pageSize;
  final String? sortColumn;
  final bool sortAscending;

  const SalonsFilter({
    this.city,
    this.country,
    this.searchText = '',
    this.verified,
    this.enrichmentFilter,
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
    String? Function()? enrichmentFilter,
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
      enrichmentFilter: enrichmentFilter != null ? enrichmentFilter() : this.enrichmentFilter,
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
      verified != null ||
      enrichmentFilter != null;
}

// ── Providers ─────────────────────────────────────────────────────────────────

final registeredSalonsFilterProvider = StateProvider<SalonsFilter>(
  (ref) => const SalonsFilter(),
);

final discoveredSalonsFilterProvider = StateProvider<SalonsFilter>(
  (ref) => const SalonsFilter(),
);

/// Debounced search text for registered salons.
final _registeredSearchDebounced = StateProvider<String>((ref) => '');

/// Debounced search text for discovered salons.
final _discoveredSearchDebounced = StateProvider<String>((ref) => '');

/// Timer handles for debounce — kept outside providers.
Timer? _registeredDebounceTimer;
Timer? _discoveredDebounceTimer;

/// Call this from UI instead of directly setting filter.searchText.
void setRegisteredSearch(WidgetRef ref, String text) {
  // Update filter immediately for UI (clear button visibility etc.)
  ref.read(registeredSalonsFilterProvider.notifier).state =
      ref.read(registeredSalonsFilterProvider).copyWith(searchText: text, page: 0);
  // Debounce the actual query trigger
  _registeredDebounceTimer?.cancel();
  _registeredDebounceTimer = Timer(const Duration(milliseconds: 400), () {
    ref.read(_registeredSearchDebounced.notifier).state = text;
  });
}

/// Call this from UI instead of directly setting filter.searchText.
void setDiscoveredSearch(WidgetRef ref, String text) {
  ref.read(discoveredSalonsFilterProvider.notifier).state =
      ref.read(discoveredSalonsFilterProvider).copyWith(searchText: text, page: 0);
  _discoveredDebounceTimer?.cancel();
  _discoveredDebounceTimer = Timer(const Duration(milliseconds: 400), () {
    ref.read(_discoveredSearchDebounced.notifier).state = text;
  });
}

final registeredSalonsProvider =
    FutureProvider<RegisteredSalonsData>((ref) async {
  final filter = ref.watch(registeredSalonsFilterProvider);
  // Watch the debounced search — provider only re-runs when debounce fires.
  final debouncedSearch = ref.watch(_registeredSearchDebounced);

  if (!BCSupabase.isInitialized) {
    debugPrint('[registeredSalons] BCSupabase not initialized');
    return RegisteredSalonsData.empty;
  }

  // Use the debounced value for the actual query
  final searchText = debouncedSearch;

  final client = BCSupabase.client;
  final sortCol = filter.sortColumn ?? 'created_at';
  final from = filter.page * filter.pageSize;
  final to = from + filter.pageSize - 1;

  // Build base query with equality filters
  var query = client.from(BCTables.businesses).select(
    'id, name, city, state, average_rating, total_reviews, '
    'stripe_onboarding_status, is_verified, is_active, on_hold, phone, tier, '
    'created_at, photo_url, municipal_license_url, municipal_license_status',
  );
  if (filter.city != null) {
    query = query.eq('city', filter.city!);
  }
  if (filter.verified != null) {
    query = query.eq('is_verified', filter.verified!);
  }

  final List<dynamic> data;
  if (searchText.isNotEmpty) {
    data = await query
        .or(
          'name.ilike.%${_sanitize(searchText)}%,'
          'city.ilike.%${_sanitize(searchText)}%,'
          'phone.ilike.%${_sanitize(searchText)}%',
        )
        .order(sortCol, ascending: filter.sortAscending)
        .range(from, to);
  } else {
    data = await query
        .order(sortCol, ascending: filter.sortAscending)
        .range(from, to);
  }

  // Count query — run in parallel with data query next time, but keep simple for now
  var countQuery = client.from(BCTables.businesses).select('id');
  if (filter.city != null) {
    countQuery = countQuery.eq('city', filter.city!);
  }
  if (filter.verified != null) {
    countQuery = countQuery.eq('is_verified', filter.verified!);
  }
  final int totalCount;
  if (searchText.isNotEmpty) {
    final r = await countQuery
        .or(
          'name.ilike.%${_sanitize(searchText)}%,'
          'city.ilike.%${_sanitize(searchText)}%,'
          'phone.ilike.%${_sanitize(searchText)}%',
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
});

final discoveredSalonsProvider =
    FutureProvider<DiscoveredSalonsData>((ref) async {
  final filter = ref.watch(discoveredSalonsFilterProvider);
  final debouncedSearch = ref.watch(_discoveredSearchDebounced);

  if (!BCSupabase.isInitialized) {
    debugPrint('[discoveredSalons] BCSupabase not initialized');
    return DiscoveredSalonsData.empty;
  }

  final searchText = debouncedSearch;

  final client = BCSupabase.client;
  final sortCol = filter.sortColumn ?? 'created_at';
  final from = filter.page * filter.pageSize;
  final to = from + filter.pageSize - 1;

  var query = client.from(BCTables.discoveredSalons).select(
    'id, business_name, source, phone, location_city, location_state, country, '
    'whatsapp_verified, last_outreach_at, interest_count, '
    'location_address, latitude, longitude, created_at, '
    'rating_average, rating_count, feature_image_url, website, '
    'instagram_url, ig_bio, ig_followers, matched_categories, specialties, '
    'working_hours, ig_enriched_at, whatsapp_checked_at, '
    'est_monthly_clients, est_daily_clients, est_avg_service_price, est_monthly_revenue, est_annual_revenue, '
    'booking_system, booking_url, calendar_url, booking_enriched_at, email, '
    'portfolio_images, ig_post_captions, facebook_url, services_detected, bio',
  );
  if (filter.city != null) {
    query = query.eq('location_city', filter.city!);
  }
  if (filter.country != null) {
    if (filter.country == 'MX') {
      query = query.or('country.eq.MX,country.eq.Mexico');
    } else {
      query = query.eq('country', filter.country!);
    }
  }
  // Enrichment filters
  switch (filter.enrichmentFilter) {
    case 'ig_enriched':
      query = query.not('ig_enriched_at', 'is', null);
      break;
    case 'wa_verified':
      query = query.eq('whatsapp_verified', true);
      break;
    case 'wa_checked':
      query = query.not('whatsapp_checked_at', 'is', null);
      break;
    case 'has_website':
      query = query.not('website', 'is', null).neq('website', '');
      break;
    case 'has_ig':
      query = query.not('instagram_url', 'is', null).neq('instagram_url', '');
      break;
    case 'not_enriched':
      query = query.isFilter('ig_enriched_at', null).isFilter('whatsapp_checked_at', null);
      break;
    case 'has_booking':
      query = query.not('booking_system', 'is', null);
      break;
  }

  final List<dynamic> data;
  if (searchText.isNotEmpty) {
    data = await query
        .or(
          'business_name.ilike.%${_sanitize(searchText)}%,'
          'location_city.ilike.%${_sanitize(searchText)}%,'
          'phone.ilike.%${_sanitize(searchText)}%',
        )
        .order(sortCol, ascending: filter.sortAscending)
        .range(from, to);
  } else {
    data = await query
        .order(sortCol, ascending: filter.sortAscending)
        .range(from, to);
  }

  var countQuery = client.from(BCTables.discoveredSalons).select('id');
  if (filter.city != null) {
    countQuery = countQuery.eq('location_city', filter.city!);
  }
  if (filter.country != null) {
    if (filter.country == 'MX') {
      countQuery = countQuery.or('country.eq.MX,country.eq.Mexico');
    } else {
      countQuery = countQuery.eq('country', filter.country!);
    }
  }
  switch (filter.enrichmentFilter) {
    case 'ig_enriched':
      countQuery = countQuery.not('ig_enriched_at', 'is', null);
      break;
    case 'wa_verified':
      countQuery = countQuery.eq('whatsapp_verified', true);
      break;
    case 'wa_checked':
      countQuery = countQuery.not('whatsapp_checked_at', 'is', null);
      break;
    case 'has_website':
      countQuery = countQuery.not('website', 'is', null).neq('website', '');
      break;
    case 'has_ig':
      countQuery = countQuery.not('instagram_url', 'is', null).neq('instagram_url', '');
      break;
    case 'not_enriched':
      countQuery = countQuery.isFilter('ig_enriched_at', null).isFilter('whatsapp_checked_at', null);
      break;
    case 'has_booking':
      countQuery = countQuery.not('booking_system', 'is', null);
      break;
  }
  final int totalCount;
  if (searchText.isNotEmpty) {
    final r = await countQuery
        .or(
          'business_name.ilike.%${_sanitize(searchText)}%,'
          'location_city.ilike.%${_sanitize(searchText)}%,'
          'phone.ilike.%${_sanitize(searchText)}%',
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
});
