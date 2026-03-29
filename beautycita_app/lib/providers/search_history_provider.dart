import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kSearchHistory = 'search_history';
const _kMaxHistory = 5;

class SearchHistoryEntry {
  final String serviceType;
  final String serviceName;
  final String category;
  final DateTime timestamp;

  const SearchHistoryEntry({
    required this.serviceType,
    required this.serviceName,
    required this.category,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'service_type': serviceType,
        'service_name': serviceName,
        'category': category,
        'timestamp': timestamp.toIso8601String(),
      };

  factory SearchHistoryEntry.fromJson(Map<String, dynamic> json) {
    return SearchHistoryEntry(
      serviceType: json['service_type'] as String,
      serviceName: json['service_name'] as String,
      category: json['category'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class SearchHistoryNotifier extends StateNotifier<List<SearchHistoryEntry>> {
  SearchHistoryNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kSearchHistory);
      if (raw == null || raw.isEmpty) return;

      final list = jsonDecode(raw) as List;
      state = list
          .map((e) => SearchHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Ignore corrupt data
    }
  }

  Future<void> addEntry({
    required String serviceType,
    required String serviceName,
    required String category,
  }) async {
    // Remove duplicate if same serviceType already in history
    final filtered = state
        .where((e) => e.serviceType != serviceType)
        .toList();

    final entry = SearchHistoryEntry(
      serviceType: serviceType,
      serviceName: serviceName,
      category: category,
      timestamp: DateTime.now(),
    );

    // Prepend and cap at max
    final updated = [entry, ...filtered].take(_kMaxHistory).toList();
    state = updated;

    // Persist
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kSearchHistory,
      jsonEncode(updated.map((e) => e.toJson()).toList()),
    );
  }
}

final searchHistoryProvider =
    StateNotifierProvider<SearchHistoryNotifier, List<SearchHistoryEntry>>(
        (ref) => SearchHistoryNotifier());
