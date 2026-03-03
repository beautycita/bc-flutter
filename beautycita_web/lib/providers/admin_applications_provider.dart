import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';

/// Strip PostgREST filter metacharacters to prevent filter injection.
String _sanitize(String input) =>
    input.replaceAll(RegExp(r'[.,()\\]'), '').trim();

// ── Application business model ───────────────────────────────────────────────

@immutable
class ApplicationBusiness {
  final String id;
  final String name;
  final String? city;
  final String? phone;
  final String? photoUrl;
  final String? ownerId;
  final String municipalLicenseStatus;
  final String? municipalLicenseUrl;
  final int onboardingStep;
  final String stripeOnboardingStatus;
  final DateTime createdAt;
  // Owner verification status (from auth.users via RPC)
  final bool ownerEmailVerified;
  final bool ownerPhoneVerified;

  const ApplicationBusiness({
    required this.id,
    required this.name,
    this.city,
    this.phone,
    this.photoUrl,
    this.ownerId,
    this.municipalLicenseStatus = 'none',
    this.municipalLicenseUrl,
    this.onboardingStep = 0,
    this.stripeOnboardingStatus = 'not_started',
    required this.createdAt,
    this.ownerEmailVerified = false,
    this.ownerPhoneVerified = false,
  });

  factory ApplicationBusiness.fromJson(Map<String, dynamic> json) {
    return ApplicationBusiness(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Sin nombre',
      city: json['city'] as String?,
      phone: json['phone'] as String?,
      photoUrl: json['photo_url'] as String?,
      ownerId: json['owner_id'] as String?,
      municipalLicenseStatus:
          json['municipal_license_status'] as String? ?? 'none',
      municipalLicenseUrl: json['municipal_license_url'] as String?,
      onboardingStep: json['onboarding_step'] as int? ?? 0,
      stripeOnboardingStatus:
          json['stripe_onboarding_status'] as String? ?? 'not_started',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Returns a copy with owner verification fields populated.
  ApplicationBusiness withVerification({
    required bool emailVerified,
    required bool phoneVerified,
  }) {
    return ApplicationBusiness(
      id: id,
      name: name,
      city: city,
      phone: phone,
      photoUrl: photoUrl,
      ownerId: ownerId,
      municipalLicenseStatus: municipalLicenseStatus,
      municipalLicenseUrl: municipalLicenseUrl,
      onboardingStep: onboardingStep,
      stripeOnboardingStatus: stripeOnboardingStatus,
      createdAt: createdAt,
      ownerEmailVerified: emailVerified,
      ownerPhoneVerified: phoneVerified,
    );
  }

  /// True when both email and phone are verified — trigger will auto-approve.
  bool get readyForAutoApproval => ownerEmailVerified && ownerPhoneVerified;
}

// ── Page data ────────────────────────────────────────────────────────────────

@immutable
class ApplicationsData {
  final List<ApplicationBusiness> applications;
  final int totalCount;
  const ApplicationsData({required this.applications, required this.totalCount});
  static const empty = ApplicationsData(applications: [], totalCount: 0);
}

// ── Filter ───────────────────────────────────────────────────────────────────

@immutable
class ApplicationsFilter {
  final String searchText;
  final int page;
  final int pageSize;
  final String? sortColumn;
  final bool sortAscending;

  const ApplicationsFilter({
    this.searchText = '',
    this.page = 0,
    this.pageSize = 20,
    this.sortColumn,
    this.sortAscending = false,
  });

  ApplicationsFilter copyWith({
    String? searchText,
    int? page,
    int? pageSize,
    String? Function()? sortColumn,
    bool? sortAscending,
  }) {
    return ApplicationsFilter(
      searchText: searchText ?? this.searchText,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      sortColumn: sortColumn != null ? sortColumn() : this.sortColumn,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }
}

// ── Providers ────────────────────────────────────────────────────────────────

final applicationsFilterProvider = StateProvider<ApplicationsFilter>(
  (ref) => const ApplicationsFilter(),
);

final _applicationsSearchDebounced = StateProvider<String>((ref) => '');

Timer? _applicationsDebounceTimer;

void setApplicationsSearch(WidgetRef ref, String text) {
  ref.read(applicationsFilterProvider.notifier).state =
      ref.read(applicationsFilterProvider).copyWith(searchText: text, page: 0);
  _applicationsDebounceTimer?.cancel();
  _applicationsDebounceTimer = Timer(const Duration(milliseconds: 400), () {
    ref.read(_applicationsSearchDebounced.notifier).state = text;
  });
}

final applicationsProvider = FutureProvider<ApplicationsData>((ref) async {
  final filter = ref.watch(applicationsFilterProvider);
  final debouncedSearch = ref.watch(_applicationsSearchDebounced);

  if (!BCSupabase.isInitialized) {
    debugPrint('[applications] BCSupabase not initialized');
    return ApplicationsData.empty;
  }

  final searchText = debouncedSearch;
  final client = BCSupabase.client;
  final sortCol = filter.sortColumn ?? 'created_at';
  final from = filter.page * filter.pageSize;
  final to = from + filter.pageSize - 1;

  var query = client.from(BCTables.businesses).select(
    'id, name, city, phone, photo_url, owner_id, '
    'municipal_license_status, municipal_license_url, '
    'onboarding_step, stripe_onboarding_status, created_at',
  ).eq('is_verified', false);

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

  // Count query
  var countQuery = client
      .from(BCTables.businesses)
      .select('id')
      .eq('is_verified', false);
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

  // Parse base models
  var applications = data
      .map((row) => ApplicationBusiness.fromJson(row as Map<String, dynamic>))
      .toList();

  // Enrich with owner verification status via RPC
  final enriched = <ApplicationBusiness>[];
  for (final app in applications) {
    if (app.ownerId != null) {
      try {
        final result = await client.rpc('get_owner_verification', params: {
          'p_owner_id': app.ownerId,
        }).single();
        enriched.add(app.withVerification(
          emailVerified: result['email_verified'] as bool? ?? false,
          phoneVerified: result['phone_verified'] as bool? ?? false,
        ));
      } catch (_) {
        enriched.add(app);
      }
    } else {
      enriched.add(app);
    }
  }

  return ApplicationsData(applications: enriched, totalCount: totalCount);
});

// ── Actions ──────────────────────────────────────────────────────────────────

// NOTE: Application approval is automatic via DB trigger (trg_auto_approve_business).
// When the owner verifies both phone + email, the trigger sets is_verified=true
// and promotes the owner role to 'stylist'. No manual approval needed.

/// Reject application: deactivate business, mark as verified so it doesn't
/// show up in pending list.
Future<void> rejectApplication(WidgetRef ref, String businessId) async {
  await BCSupabase.client
      .from(BCTables.businesses)
      .update({'is_active': false, 'is_verified': true})
      .eq('id', businessId);

  ref.invalidate(applicationsProvider);
}

/// Approve a municipal license.
Future<void> approveLicense(WidgetRef ref, String businessId) async {
  final userId = BCSupabase.currentUserId;
  await BCSupabase.client.from(BCTables.businesses).update({
    'municipal_license_status': 'approved',
    'municipal_license_reviewed_at': DateTime.now().toUtc().toIso8601String(),
    'municipal_license_reviewed_by': userId,
  }).eq('id', businessId);

  ref.invalidate(applicationsProvider);
}

/// Reject a municipal license.
Future<void> rejectLicense(WidgetRef ref, String businessId) async {
  final userId = BCSupabase.currentUserId;
  await BCSupabase.client.from(BCTables.businesses).update({
    'municipal_license_status': 'rejected',
    'municipal_license_reviewed_at': DateTime.now().toUtc().toIso8601String(),
    'municipal_license_reviewed_by': userId,
  }).eq('id', businessId);

  ref.invalidate(applicationsProvider);
}
