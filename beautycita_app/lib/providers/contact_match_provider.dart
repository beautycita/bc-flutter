import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/contact_match_service.dart';
import 'package:beautycita_core/supabase.dart';
import '../services/supabase_client.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum ContactMatchStep { idle, requesting, scanning, loaded, denied, error }

class EnrichedMatch {
  final String contactName;
  final Map<String, dynamic> salon;
  final String salonType; // 'd' = discovered, 'r' = registered
  final String matchedPhone;

  const EnrichedMatch({
    required this.contactName,
    required this.salon,
    required this.salonType,
    required this.matchedPhone,
  });

  String get salonId => salon['id']?.toString() ?? '';

  String get salonName {
    if (salonType == 'r') return salon['name'] as String? ?? '';
    return salon['business_name'] as String? ?? '';
  }

  String? get salonCity {
    if (salonType == 'r') return salon['city'] as String?;
    return salon['location_city'] as String?;
  }

  String? get salonPhoto {
    if (salonType == 'r') return salon['photo_url'] as String?;
    return salon['feature_image_url'] as String?;
  }

  double? get salonRating {
    if (salonType == 'r') {
      final v = salon['average_rating'];
      return v is num ? v.toDouble() : null;
    }
    final v = salon['rating_average'];
    return v is num ? v.toDouble() : null;
  }
}

class ContactMatchState {
  final ContactMatchStep step;
  final List<EnrichedMatch> matches;
  final String? error;

  const ContactMatchState({
    this.step = ContactMatchStep.idle,
    this.matches = const [],
    this.error,
  });

  ContactMatchState copyWith({
    ContactMatchStep? step,
    List<EnrichedMatch>? matches,
    String? error,
    bool clearError = false,
  }) {
    return ContactMatchState(
      step: step ?? this.step,
      matches: matches ?? this.matches,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class ContactMatchNotifier extends StateNotifier<ContactMatchState> {
  final ContactMatchService _service;

  ContactMatchNotifier(this._service) : super(const ContactMatchState());

  /// Check if permission is already granted and load cached matches.
  Future<void> checkPermission() async {
    try {
      final granted = await _service.hasPermission();
      if (!granted) {
        // Permission not granted yet — stay idle so CTA shows.
        return;
      }

      // Permission granted — try cached matches for instant display.
      final cached = await _service.getCachedMatches();
      if (cached.isNotEmpty) {
        final enriched = await _enrich(cached);
        state = state.copyWith(
          step: ContactMatchStep.loaded,
          matches: enriched,
        );
      } else {
        // Granted but no cache — trigger a scan.
        await _scan(forceRefresh: false);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[CONTACT-MATCH] checkPermission error: $e');
      // Non-fatal on startup — stay idle.
    }
  }

  /// Request permission and scan if granted.
  Future<void> requestAndScan() async {
    state = state.copyWith(step: ContactMatchStep.requesting, clearError: true);

    try {
      final granted = await _service.hasPermission();
      if (!granted) {
        state = state.copyWith(step: ContactMatchStep.denied);
        return;
      }

      await _scan(forceRefresh: false);
    } catch (e) {
      if (kDebugMode) debugPrint('[CONTACT-MATCH] requestAndScan error: $e');
      state = state.copyWith(
        step: ContactMatchStep.error,
        error: e.toString(),
      );
    }
  }

  /// Force re-scan (pull-to-refresh, etc.).
  Future<void> refresh() async {
    state = state.copyWith(step: ContactMatchStep.scanning, clearError: true);

    try {
      await _scan(forceRefresh: true);
    } catch (e) {
      if (kDebugMode) debugPrint('[CONTACT-MATCH] refresh error: $e');
      state = state.copyWith(
        step: ContactMatchStep.error,
        error: e.toString(),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  Future<void> _scan({required bool forceRefresh}) async {
    state = state.copyWith(step: ContactMatchStep.scanning);

    final rawMatches = await _service.scanAndMatch(forceRefresh: forceRefresh);
    if (rawMatches.isEmpty) {
      state = state.copyWith(
        step: ContactMatchStep.loaded,
        matches: [],
      );
      return;
    }

    final enriched = await _enrich(rawMatches);
    state = state.copyWith(
      step: ContactMatchStep.loaded,
      matches: enriched,
    );

    // Fire-and-forget: generate bios for discovered salons without one.
    for (final match in enriched) {
      if (match.salonType == 'd' && match.salon['generated_bio'] == null) {
        _generateBioBackground(match.salon);
      }
    }
  }

  Future<List<EnrichedMatch>> _enrich(List<ContactMatch> rawMatches) async {
    final client = SupabaseClientService.client;

    // Separate by type.
    final dIds = rawMatches
        .where((m) => m.salonType == 'd')
        .map((m) => m.salonId)
        .toSet()
        .toList();
    final rIds = rawMatches
        .where((m) => m.salonType == 'r')
        .map((m) => m.salonId)
        .toSet()
        .toList();

    // Fetch discovered salons.
    final dMap = <String, Map<String, dynamic>>{};
    if (dIds.isNotEmpty) {
      final res = await client
          .from(BCTables.discoveredSalons)
          .select(
            'id, business_name, phone, location_city, feature_image_url, '
            'rating_average, rating_count, matched_categories, generated_bio',
          )
          .inFilter('id', dIds);
      for (final row in (res as List)) {
        dMap[row['id'].toString()] = Map<String, dynamic>.from(row as Map);
      }
    }

    // Fetch registered businesses.
    final rMap = <String, Map<String, dynamic>>{};
    if (rIds.isNotEmpty) {
      final res = await client
          .from(BCTables.businesses)
          .select(
            'id, name, phone, city, photo_url, average_rating, '
            'total_reviews, service_categories',
          )
          .inFilter('id', rIds);
      for (final row in (res as List)) {
        rMap[row['id'].toString()] = Map<String, dynamic>.from(row as Map);
      }
    }

    // Build enriched list, dropping matches without salon data.
    final enriched = <EnrichedMatch>[];
    for (final m in rawMatches) {
      final salonData =
          m.salonType == 'd' ? dMap[m.salonId] : rMap[m.salonId];
      if (salonData == null) continue;

      enriched.add(EnrichedMatch(
        contactName: m.contactName,
        salon: salonData,
        salonType: m.salonType,
        matchedPhone: m.matchedPhone,
      ));
    }

    return enriched;
  }

  /// Fire-and-forget Aphrodite bio generation for a discovered salon.
  void _generateBioBackground(Map<String, dynamic> salon) {
    Future(() async {
      try {
        await SupabaseClientService.client.functions.invoke(
          'aphrodite-chat',
          body: {
            'action': 'generate_bio',
            'salon_id': salon['id']?.toString(),
            'salon_name': salon['business_name'],
            'salon_city': salon['location_city'],
            'salon_categories': salon['matched_categories'],
            'salon_rating': salon['rating_average'],
            'salon_reviews_count': salon['rating_count'],
          },
        );
      } catch (e) {
        if (kDebugMode) debugPrint('[CONTACT-MATCH] background bio error: $e');
      }
    });
  }
}

// ---------------------------------------------------------------------------
// Provider Registration
// ---------------------------------------------------------------------------

final contactMatchProvider =
    StateNotifierProvider<ContactMatchNotifier, ContactMatchState>(
  (ref) => ContactMatchNotifier(ContactMatchService()),
);
