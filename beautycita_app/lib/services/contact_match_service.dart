import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_client.dart';

class SalonPhoneEntry {
  final String id;
  final String phone;
  final String type; // 'd' = discovered, 'r' = registered

  const SalonPhoneEntry({
    required this.id,
    required this.phone,
    required this.type,
  });
}

class ContactEntry {
  final String displayName;
  final List<String> phones; // normalized

  const ContactEntry({required this.displayName, required this.phones});
}

class ContactMatch {
  final String contactName;
  final String salonId;
  final String salonType;
  final String matchedPhone;

  const ContactMatch({
    required this.contactName,
    required this.salonId,
    required this.salonType,
    required this.matchedPhone,
  });

  Map<String, dynamic> toJson() => {
    'contactName': contactName,
    'salonId': salonId,
    'salonType': salonType,
    'matchedPhone': matchedPhone,
  };

  factory ContactMatch.fromJson(Map<String, dynamic> json) => ContactMatch(
    contactName: json['contactName'] as String,
    salonId: json['salonId'] as String,
    salonType: json['salonType'] as String,
    matchedPhone: json['matchedPhone'] as String,
  );
}

class ContactMatchService {
  static const _phoneCacheKey = 'contact_match_phone_cache';
  static const _cacheTimestampKey = 'contact_match_cache_ts';
  static const _matchesCacheKey = 'contact_match_results';
  static const _syncMatchesKey = 'contact_sync_matches';
  static const _cacheDuration = Duration(hours: 24);
  static const _syncChannel = MethodChannel('com.beautycita/contact_sync');

  /// Normalize a phone number for comparison.
  /// Strips all non-digit chars except leading +, ensures +52 prefix for MX
  /// numbers.
  @visibleForTesting
  static String normalizePhone(String phone) {
    // Strip everything except digits and leading +
    var digits = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // Remove leading + for processing
    final hasPlus = digits.startsWith('+');
    if (hasPlus) digits = digits.substring(1);

    // 10 digits = MX local number, add 52 prefix
    if (digits.length == 10 && !digits.startsWith('1')) {
      digits = '52$digits';
    }

    // 12 digits starting with 52 = MX with country code
    // 11 digits starting with 1 = US number
    // Keep as-is for other formats

    return '+$digits';
  }

  /// Check if contacts permission is granted.
  Future<bool> hasPermission() async {
    return FlutterContacts.requestPermission(readonly: true);
  }

  /// Download MX salon phone list from edge function. Cache for 24h.
  Future<Map<String, SalonPhoneEntry>> fetchPhoneList({
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Check cache
    if (!forceRefresh) {
      final cachedTs = prefs.getString(_cacheTimestampKey);
      if (cachedTs != null) {
        final cacheTime = DateTime.tryParse(cachedTs);
        if (cacheTime != null &&
            DateTime.now().difference(cacheTime) < _cacheDuration) {
          final cached = prefs.getString(_phoneCacheKey);
          if (cached != null) {
            return _parsePhoneList(jsonDecode(cached) as List<dynamic>);
          }
        }
      }
    }

    // Fetch from edge function
    final response = await SupabaseClientService.client.functions.invoke(
      'outreach-discovered-salon',
      body: {'action': 'phone_list'},
    );

    if (response.status != 200) {
      throw Exception('Failed to fetch phone list: ${response.status}');
    }

    final data = response.data as Map<String, dynamic>;
    final phones = data['phones'] as List<dynamic>;

    // Cache
    await prefs.setString(_phoneCacheKey, jsonEncode(phones));
    await prefs.setString(
      _cacheTimestampKey,
      DateTime.now().toIso8601String(),
    );

    return _parsePhoneList(phones);
  }

  Map<String, SalonPhoneEntry> _parsePhoneList(List<dynamic> phones) {
    final map = <String, SalonPhoneEntry>{};
    for (final entry in phones) {
      final raw = entry as Map<String, dynamic>;
      final phone = normalizePhone(raw['p'] as String? ?? '');
      if (phone.length >= 10) {
        map[phone] = SalonPhoneEntry(
          id: raw['id'] as String,
          phone: phone,
          type: raw['t'] as String? ?? 'd',
        );
      }
    }
    return map;
  }

  /// Read device contacts and extract normalized phone numbers.
  Future<List<ContactEntry>> readContacts() async {
    final contacts = await FlutterContacts.getContacts(withProperties: true);
    return contacts
        .where((c) => c.phones.isNotEmpty)
        .map(
          (c) => ContactEntry(
            displayName: c.displayName,
            phones:
                c.phones
                    .map((p) => normalizePhone(p.number))
                    .where((p) => p.length >= 10)
                    .toList(),
          ),
        )
        .where((c) => c.phones.isNotEmpty)
        .toList();
  }

  /// Match contacts against salon phone list.
  @visibleForTesting
  static List<ContactMatch> matchContacts(
    List<ContactEntry> contacts,
    Map<String, SalonPhoneEntry> salonPhones,
  ) {
    final matches = <ContactMatch>[];
    final seenSalonIds = <String>{};

    for (final contact in contacts) {
      for (final phone in contact.phones) {
        final salon = salonPhones[phone];
        if (salon != null && !seenSalonIds.contains(salon.id)) {
          seenSalonIds.add(salon.id);
          matches.add(
            ContactMatch(
              contactName: contact.displayName,
              salonId: salon.id,
              salonType: salon.type,
              matchedPhone: phone,
            ),
          );
          break; // One match per contact
        }
      }
    }

    return matches;
  }

  /// Full flow: fetch list, read contacts, match, cache results.
  Future<List<ContactMatch>> scanAndMatch({
    bool forceRefresh = false,
  }) async {
    final salonPhones = await fetchPhoneList(forceRefresh: forceRefresh);
    final contacts = await readContacts();
    final matches = matchContacts(contacts, salonPhones);

    // Cache matches
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _matchesCacheKey,
      jsonEncode(matches.map((m) => m.toJson()).toList()),
    );

    return matches;
  }

  /// Load cached matches (for instant display on app start).
  Future<List<ContactMatch>> getCachedMatches() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_matchesCacheKey);
    if (cached == null) return [];
    final list = jsonDecode(cached) as List<dynamic>;
    return list
        .map((j) => ContactMatch.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Trigger Android SyncAdapter to write "Reservar en BeautyCita" actions
  /// to matched contacts in the native Contacts app.
  /// No-op on iOS.
  Future<void> syncContactActions(List<ContactMatch> matches) async {
    if (!Platform.isAndroid) return;
    try {
      // Write matches in the format SyncAdapter expects
      final syncData = matches
          .map((m) => {
                'phone': m.matchedPhone,
                'salon_name': m.contactName,
                'salon_id': m.salonId,
                'salon_type': m.salonType,
              })
          .toList();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_syncMatchesKey, jsonEncode(syncData));
      await _syncChannel.invokeMethod('syncContacts');
    } catch (e) {
      debugPrint('[ContactMatch] Android sync failed: $e');
    }
  }
}
