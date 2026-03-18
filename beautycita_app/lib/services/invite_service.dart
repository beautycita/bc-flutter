import 'package:flutter/foundation.dart';
import 'supabase_client.dart';
import '../screens/invite_salon_screen.dart' show DiscoveredSalon;

/// API layer for the salon invite experience.
/// Calls edge functions for discovering, searching, and inviting salons.
class InviteService {
  /// Fetch top nearby discovered salons, optionally filtered by service type.
  Future<List<DiscoveredSalon>> fetchNearbySalons({
    required double lat,
    required double lng,
    String? serviceType,
    int limit = 20,
  }) async {
    final client = SupabaseClientService.client;

    final body = <String, dynamic>{
      'action': 'list',
      'lat': lat,
      'lng': lng,
      'radius_km': 50,
      'limit': limit,
    };
    if (serviceType != null) {
      body['service_query'] = serviceType;
    }

    final response = await client.functions.invoke(
      'outreach-discovered-salon',
      body: body,
    );

    debugPrint('[INVITE-SVC] fetchNearbySalons status: ${response.status}');

    if (response.status != 200) {
      final error = response.data is Map ? response.data['error'] : 'Unknown error';
      throw InviteException(
        'fetchNearbySalons failed (${response.status}): $error',
        statusCode: response.status,
      );
    }

    final data = response.data as Map<String, dynamic>;
    final salons = (data['salons'] as List<dynamic>? ?? [])
        .map((json) => DiscoveredSalon.fromJson(json as Map<String, dynamic>))
        .toList();
    return salons;
  }

  /// Search discovered salons by name.
  /// Returns (salons, suggestScrape) — if empty + suggestScrape, prompt user to scrape.
  Future<({List<DiscoveredSalon> salons, bool suggestScrape})> searchSalons({
    required String query,
    required double lat,
    required double lng,
  }) async {
    final client = SupabaseClientService.client;

    final response = await client.functions.invoke(
      'outreach-discovered-salon',
      body: {
        'action': 'search',
        'query': query,
        'lat': lat,
        'lng': lng,
      },
    );

    debugPrint('[INVITE-SVC] searchSalons status: ${response.status}');

    if (response.status != 200) {
      final error = response.data is Map ? response.data['error'] : 'Unknown error';
      throw InviteException(
        'searchSalons failed (${response.status}): $error',
        statusCode: response.status,
      );
    }

    final data = response.data as Map<String, dynamic>;
    final salons = (data['salons'] as List<dynamic>? ?? [])
        .map((json) => DiscoveredSalon.fromJson(json as Map<String, dynamic>))
        .toList();
    final suggestScrape = data['suggest_scrape'] as bool? ?? false;

    return (salons: salons, suggestScrape: suggestScrape);
  }

  /// On-demand scrape: search Google Places, enrich, insert into DB, return.
  Future<DiscoveredSalon?> scrapeAndEnrich({
    required String query,
    required double lat,
    required double lng,
  }) async {
    final client = SupabaseClientService.client;

    final response = await client.functions.invoke(
      'on-demand-scrape',
      body: {
        'action': 'search_place',
        'query': query,
        'lat': lat,
        'lng': lng,
      },
    );

    debugPrint('[INVITE-SVC] scrapeAndEnrich status: ${response.status}');

    if (response.status != 200) {
      final error = response.data is Map ? response.data['error'] : 'Unknown error';
      throw InviteException(
        'scrapeAndEnrich failed (${response.status}): $error',
        statusCode: response.status,
      );
    }

    final data = response.data as Map<String, dynamic>;
    final salonJson = data['salon'] as Map<String, dynamic>?;
    if (salonJson == null) return null;

    return DiscoveredSalon.fromJson(salonJson);
  }

  /// Generate Aphrodite bio for a salon. Returns bio text.
  Future<String> generateBio(DiscoveredSalon salon) async {
    final client = SupabaseClientService.client;

    final response = await client.functions.invoke(
      'aphrodite-chat',
      body: {
        'action': 'generate_salon_bio',
        'salon_name': salon.name,
        'salon_city': salon.city,
        'salon_address': salon.address,
        'salon_rating': salon.rating,
        'salon_reviews_count': salon.reviewsCount,
      },
    ).timeout(const Duration(seconds: 20));

    debugPrint('[INVITE-SVC] generateBio status: ${response.status}');

    if (response.status != 200) {
      final error = response.data is Map ? response.data['error'] : 'Unknown error';
      throw InviteException(
        'generateBio failed (${response.status}): $error',
        statusCode: response.status,
      );
    }

    final data = response.data as Map<String, dynamic>;
    return data['text'] as String? ?? '';
  }

  /// Generate personalized invite message. Returns message text.
  Future<String> generateInviteMessage({
    required String userName,
    required DiscoveredSalon salon,
    String? serviceSearched,
  }) async {
    final client = SupabaseClientService.client;

    final response = await client.functions.invoke(
      'aphrodite-chat',
      body: {
        'action': 'generate_invite_message',
        'user_name': userName,
        'salon_name': salon.name,
        'salon_city': salon.city,
        // ignore: use_null_aware_elements
        if (serviceSearched != null) 'service_searched': serviceSearched,
      },
    ).timeout(const Duration(seconds: 20));

    debugPrint('[INVITE-SVC] generateInviteMessage status: ${response.status}');

    if (response.status != 200) {
      final error = response.data is Map ? response.data['error'] : 'Unknown error';
      throw InviteException(
        'generateInviteMessage failed (${response.status}): $error',
        statusCode: response.status,
      );
    }

    final data = response.data as Map<String, dynamic>;
    return data['text'] as String? ?? '';
  }

  /// Send invite: record interest signal in DB. Server sends via best channel
  /// (WA if available, email if not, SMS as fallback).
  /// Returns WA URL if server provides the phone for user-side WA opening.
  Future<String?> sendInvite({
    required String salonId,
    required String inviteMessage,
  }) async {
    final client = SupabaseClientService.client;

    final response = await client.functions.invoke(
      'outreach-discovered-salon',
      body: {
        'action': 'invite',
        'discovered_salon_id': salonId,
        'invite_message': inviteMessage,
      },
    ).timeout(const Duration(seconds: 30));

    debugPrint('[INVITE-SVC] sendInvite status: ${response.status}');

    if (response.status != 200) {
      final error = response.data is Map ? response.data['error'] : 'Unknown error';
      throw InviteException(
        'sendInvite failed (${response.status}): $error',
        statusCode: response.status,
      );
    }

    // Server may return a wa_url for user to open
    final data = response.data as Map<String, dynamic>;
    return data['wa_url'] as String?;
  }

  /// Cleans a phone number for use in a wa.me URL.
  /// Strips spaces, dashes, parentheses; ensures only digits remain.
  /// Returns null if no digits found.
  @visibleForTesting
  static String? cleanPhoneForWhatsApp(String? phone) {
    if (phone == null || phone.isEmpty) return null;

    // Strip everything except digits and leading +
    final stripped = phone.replaceAll(RegExp(r'[^\d+]'), '');
    // Remove + prefix — wa.me expects digits only
    final digits = stripped.replaceAll('+', '');

    if (digits.isEmpty) return null;
    return digits;
  }

  /// Parses a list of salon JSON objects into DiscoveredSalon instances.
  /// Used internally; exposed for testing.
  @visibleForTesting
  static List<DiscoveredSalon> parseSalonList(List<dynamic> jsonList) {
    return jsonList
        .map((json) => DiscoveredSalon.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}

class InviteException implements Exception {
  final String message;
  final int statusCode;

  InviteException(this.message, {this.statusCode = 0});

  @override
  String toString() => message;
}
