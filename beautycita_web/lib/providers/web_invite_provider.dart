import 'dart:convert';

import 'package:beautycita_core/supabase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Step enum ────────────────────────────────────────────────────────────────

enum WebInviteStep {
  loading,
  browsing,
  searching,
  scraping,
  salonDetail,
  generating,
  readyToSend,
  sending,
  sent,
  error,
}

// ── State ────────────────────────────────────────────────────────────────────

@immutable
class WebInviteState {
  final WebInviteStep step;
  final List<Map<String, dynamic>> salons;
  final Map<String, dynamic>? selectedSalon;
  final String? generatedBio;
  final String? inviteMessage;
  final String? serviceFilter;
  final String? searchQuery;
  final bool suggestScrape;
  final double? lat;
  final double? lng;
  final String? error;
  final String? waUrl;

  const WebInviteState({
    this.step = WebInviteStep.loading,
    this.salons = const [],
    this.selectedSalon,
    this.generatedBio,
    this.inviteMessage,
    this.serviceFilter,
    this.searchQuery,
    this.suggestScrape = false,
    this.lat,
    this.lng,
    this.error,
    this.waUrl,
  });

  WebInviteState copyWith({
    WebInviteStep? step,
    List<Map<String, dynamic>>? salons,
    Map<String, dynamic>? selectedSalon,
    String? generatedBio,
    String? inviteMessage,
    String? serviceFilter,
    String? searchQuery,
    bool? suggestScrape,
    double? lat,
    double? lng,
    String? error,
    String? waUrl,
    // Explicit clear flags for nullable fields
    bool clearSelectedSalon = false,
    bool clearGeneratedBio = false,
    bool clearInviteMessage = false,
    bool clearServiceFilter = false,
    bool clearSearchQuery = false,
    bool clearError = false,
    bool clearWaUrl = false,
  }) {
    return WebInviteState(
      step: step ?? this.step,
      salons: salons ?? this.salons,
      selectedSalon:
          clearSelectedSalon ? null : (selectedSalon ?? this.selectedSalon),
      generatedBio:
          clearGeneratedBio ? null : (generatedBio ?? this.generatedBio),
      inviteMessage:
          clearInviteMessage ? null : (inviteMessage ?? this.inviteMessage),
      serviceFilter:
          clearServiceFilter ? null : (serviceFilter ?? this.serviceFilter),
      searchQuery:
          clearSearchQuery ? null : (searchQuery ?? this.searchQuery),
      suggestScrape: suggestScrape ?? this.suggestScrape,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      error: clearError ? null : (error ?? this.error),
      waUrl: clearWaUrl ? null : (waUrl ?? this.waUrl),
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class WebInviteNotifier extends StateNotifier<WebInviteState> {
  WebInviteNotifier() : super(const WebInviteState());

  /// Bootstrap: load nearby salons from discovered_salons via edge function.
  /// [lat]/[lng] come from browser geolocation (page resolves them).
  Future<void> initialize({
    double? lat,
    double? lng,
    String? serviceType,
  }) async {
    state = WebInviteState(
      step: WebInviteStep.loading,
      lat: lat,
      lng: lng,
      serviceFilter: serviceType,
    );

    try {
      final body = <String, dynamic>{
        'action': 'list',
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (serviceType != null) 'service_type': serviceType,
      };

      final response = await BCSupabase.client.functions.invoke(
        'outreach-discovered-salon',
        body: body,
      );

      final data = _parseResponse(response.data);
      final salons = _extractSalons(data);

      state = state.copyWith(
        step: WebInviteStep.browsing,
        salons: salons,
        suggestScrape: salons.isEmpty,
      );
    } catch (e) {
      debugPrint('[WebInviteNotifier.initialize] Error: $e');
      state = state.copyWith(
        step: WebInviteStep.error,
        error: 'No se pudieron cargar los salones: $e',
      );
    }
  }

  /// Search discovered salons by name/query.
  Future<void> searchSalons(String query) async {
    if (query.trim().isEmpty) {
      clearSearch();
      return;
    }

    state = state.copyWith(
      step: WebInviteStep.searching,
      searchQuery: query,
      clearError: true,
    );

    try {
      final body = <String, dynamic>{
        'action': 'search',
        'query': query.trim(),
        if (state.lat != null) 'lat': state.lat,
        if (state.lng != null) 'lng': state.lng,
      };

      final response = await BCSupabase.client.functions.invoke(
        'outreach-discovered-salon',
        body: body,
      );

      final data = _parseResponse(response.data);
      final salons = _extractSalons(data);

      state = state.copyWith(
        step: WebInviteStep.browsing,
        salons: salons,
        suggestScrape: salons.isEmpty,
      );
    } catch (e) {
      debugPrint('[WebInviteNotifier.searchSalons] Error: $e');
      state = state.copyWith(
        step: WebInviteStep.error,
        error: 'Error al buscar salones: $e',
      );
    }
  }

  /// Scrape Google Places for a salon not yet in discovered_salons.
  Future<void> scrapeAndShow(String query) async {
    if (query.trim().isEmpty) return;

    state = state.copyWith(
      step: WebInviteStep.scraping,
      searchQuery: query,
      clearError: true,
    );

    try {
      final body = <String, dynamic>{
        'action': 'search_place',
        'query': query.trim(),
        if (state.lat != null) 'lat': state.lat,
        if (state.lng != null) 'lng': state.lng,
      };

      final response = await BCSupabase.client.functions.invoke(
        'on-demand-scrape',
        body: body,
      );

      final data = _parseResponse(response.data);
      final salons = _extractSalons(data);

      state = state.copyWith(
        step: WebInviteStep.browsing,
        salons: salons,
        suggestScrape: false,
      );
    } catch (e) {
      debugPrint('[WebInviteNotifier.scrapeAndShow] Error: $e');
      state = state.copyWith(
        step: WebInviteStep.error,
        error: 'Error al buscar en Google Places: $e',
      );
    }
  }

  /// Select a salon to view details and prepare invite.
  void selectSalon(Map<String, dynamic> salon) {
    state = state.copyWith(
      step: WebInviteStep.salonDetail,
      selectedSalon: salon,
      clearGeneratedBio: true,
      clearInviteMessage: true,
      clearWaUrl: true,
      clearError: true,
    );
  }

  /// Generate bio + invite message for the selected salon via Aphrodite AI.
  Future<void> generateMessage() async {
    final salon = state.selectedSalon;
    if (salon == null) return;

    state = state.copyWith(
      step: WebInviteStep.generating,
      clearError: true,
    );

    try {
      // Generate bio and invite message in parallel.
      final results = await Future.wait([
        BCSupabase.client.functions.invoke(
          'aphrodite-chat',
          body: {
            'action': 'generate_salon_bio',
            'salon': salon,
          },
        ),
        BCSupabase.client.functions.invoke(
          'aphrodite-chat',
          body: {
            'action': 'generate_invite_message',
            'salon': salon,
          },
        ),
      ]);

      final bioData = _parseResponse(results[0].data);
      final inviteData = _parseResponse(results[1].data);

      final bio = bioData is Map ? (bioData['bio'] as String?) : null;
      final message =
          inviteData is Map ? (inviteData['message'] as String?) : null;

      state = state.copyWith(
        step: WebInviteStep.readyToSend,
        generatedBio: bio,
        inviteMessage: message,
      );
    } catch (e) {
      debugPrint('[WebInviteNotifier.generateMessage] Error: $e');
      state = state.copyWith(
        step: WebInviteStep.salonDetail,
        error: 'Error al generar mensaje: $e',
      );
    }
  }

  /// Record the invite and get the WhatsApp URL for the salon.
  Future<void> sendInvite() async {
    final salon = state.selectedSalon;
    if (salon == null) return;

    state = state.copyWith(
      step: WebInviteStep.sending,
      clearError: true,
    );

    try {
      final salonId = salon['id']?.toString();

      final response = await BCSupabase.client.functions.invoke(
        'outreach-discovered-salon',
        body: {
          'action': 'invite',
          'discovered_salon_id': salonId,
          if (state.inviteMessage != null) 'message': state.inviteMessage,
          'platform': 'wa',
        },
      );

      final data = _parseResponse(response.data);
      final waUrl = data is Map ? (data['wa_url'] as String?) : null;

      state = state.copyWith(
        step: WebInviteStep.sent,
        waUrl: waUrl,
      );
    } catch (e) {
      debugPrint('[WebInviteNotifier.sendInvite] Error: $e');
      state = state.copyWith(
        step: WebInviteStep.readyToSend,
        error: 'Error al enviar invitación: $e',
      );
    }
  }

  /// Return to the salon list, preserving search state.
  void backToList() {
    state = state.copyWith(
      step: WebInviteStep.browsing,
      clearSelectedSalon: true,
      clearGeneratedBio: true,
      clearInviteMessage: true,
      clearWaUrl: true,
      clearError: true,
    );
  }

  /// Clear search and reload nearby salons.
  void clearSearch() {
    state = state.copyWith(
      clearSearchQuery: true,
      suggestScrape: false,
    );
    initialize(
      lat: state.lat,
      lng: state.lng,
      serviceType: state.serviceFilter,
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Parse edge function response (may be raw JSON string or decoded map).
  dynamic _parseResponse(dynamic data) {
    if (data == null) return null;
    if (data is String) {
      try {
        return jsonDecode(data);
      } catch (_) {
        return data;
      }
    }
    return data;
  }

  /// Extract salon list from various response shapes.
  List<Map<String, dynamic>> _extractSalons(dynamic data) {
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    if (data is Map) {
      // Try common keys: salons, results, data
      for (final key in ['salons', 'results', 'data']) {
        final list = data[key];
        if (list is List) {
          return list.cast<Map<String, dynamic>>();
        }
      }
    }
    return [];
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final webInviteProvider =
    StateNotifierProvider<WebInviteNotifier, WebInviteState>(
  (ref) => WebInviteNotifier(),
);
