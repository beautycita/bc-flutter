import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/curate_result.dart';
import '../screens/invite_salon_screen.dart' show DiscoveredSalon;
import '../services/invite_service.dart';
import '../services/location_service.dart';
import '../services/supabase_client.dart';

// ---------------------------------------------------------------------------
// Invite Flow State
// ---------------------------------------------------------------------------

enum InviteStep {
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

class InviteState {
  final InviteStep step;
  final List<DiscoveredSalon> salons;
  final DiscoveredSalon? selectedSalon;
  final String? generatedBio;
  final String? inviteMessage;
  final String? serviceFilter;
  final String? searchQuery;
  final bool suggestScrape;
  final LatLng? userLocation;
  final String? error;
  final String? waUrl;

  const InviteState({
    this.step = InviteStep.loading,
    this.salons = const [],
    this.selectedSalon,
    this.generatedBio,
    this.inviteMessage,
    this.serviceFilter,
    this.searchQuery,
    this.suggestScrape = false,
    this.userLocation,
    this.error,
    this.waUrl,
  });

  InviteState copyWith({
    InviteStep? step,
    List<DiscoveredSalon>? salons,
    DiscoveredSalon? selectedSalon,
    bool clearSelectedSalon = false,
    String? generatedBio,
    bool clearBio = false,
    String? inviteMessage,
    bool clearMessage = false,
    String? serviceFilter,
    String? searchQuery,
    bool clearSearchQuery = false,
    bool? suggestScrape,
    LatLng? userLocation,
    String? error,
    String? waUrl,
    bool clearWaUrl = false,
  }) {
    return InviteState(
      step: step ?? this.step,
      salons: salons ?? this.salons,
      selectedSalon:
          clearSelectedSalon ? null : (selectedSalon ?? this.selectedSalon),
      generatedBio: clearBio ? null : (generatedBio ?? this.generatedBio),
      inviteMessage:
          clearMessage ? null : (inviteMessage ?? this.inviteMessage),
      serviceFilter: serviceFilter ?? this.serviceFilter,
      searchQuery:
          clearSearchQuery ? null : (searchQuery ?? this.searchQuery),
      suggestScrape: suggestScrape ?? this.suggestScrape,
      userLocation: userLocation ?? this.userLocation,
      error: error,
      waUrl: clearWaUrl ? null : (waUrl ?? this.waUrl),
    );
  }
}

// ---------------------------------------------------------------------------
// Invite Notifier
// ---------------------------------------------------------------------------

class InviteNotifier extends StateNotifier<InviteState> {
  final InviteService _service;

  InviteNotifier(this._service) : super(const InviteState());

  /// Initialize: get location, fetch nearby salons.
  /// [serviceType] is passed from booking flow (null when opened from nav).
  Future<void> initialize({String? serviceType}) async {
    state = InviteState(
      step: InviteStep.loading,
      serviceFilter: serviceType,
    );

    try {
      final location = await LocationService.getCurrentLocation();
      if (location == null) {
        state = state.copyWith(
          step: InviteStep.error,
          error: 'No pudimos obtener tu ubicación. Activa el GPS.',
        );
        return;
      }

      state = state.copyWith(userLocation: location);

      final salons = await _service.fetchNearbySalons(
        lat: location.lat,
        lng: location.lng,
        serviceType: serviceType,
      );

      state = state.copyWith(
        step: InviteStep.browsing,
        salons: salons,
      );
    } catch (e) {
      debugPrint('[INVITE] initialize error: $e');
      state = state.copyWith(
        step: InviteStep.error,
        error: e.toString(),
      );
    }
  }

  /// Search salons by name in DB.
  Future<void> searchSalons(String query) async {
    if (state.userLocation == null) return;

    state = state.copyWith(
      step: InviteStep.searching,
      searchQuery: query,
    );

    try {
      final result = await _service.searchSalons(
        query: query,
        lat: state.userLocation!.lat,
        lng: state.userLocation!.lng,
      );

      state = state.copyWith(
        step: InviteStep.browsing,
        salons: result.salons,
        suggestScrape: result.suggestScrape,
      );
    } catch (e) {
      debugPrint('[INVITE] searchSalons error: $e');
      state = state.copyWith(
        step: InviteStep.error,
        error: e.toString(),
      );
    }
  }

  /// On-demand scrape for a salon not found.
  Future<void> scrapeAndShow(String query) async {
    if (state.userLocation == null) return;

    state = state.copyWith(step: InviteStep.scraping);

    try {
      final salon = await _service.scrapeAndEnrich(
        query: query,
        lat: state.userLocation!.lat,
        lng: state.userLocation!.lng,
      );

      if (salon == null) {
        state = state.copyWith(
          step: InviteStep.error,
          error: 'No encontramos ese salón. Intenta con otro nombre.',
        );
        return;
      }

      // Add scraped salon to the list and select it
      final updatedSalons = [salon, ...state.salons];
      state = state.copyWith(
        step: InviteStep.salonDetail,
        salons: updatedSalons,
        selectedSalon: salon,
        suggestScrape: false,
      );

      // Auto-generate bio for the scraped salon
      await _loadBio(salon);
    } catch (e) {
      debugPrint('[INVITE] scrapeAndShow error: $e');
      state = state.copyWith(
        step: InviteStep.error,
        error: e.toString(),
      );
    }
  }

  /// User selected a salon — load bio (cached or generate).
  Future<void> selectSalon(DiscoveredSalon salon) async {
    state = state.copyWith(
      step: InviteStep.salonDetail,
      selectedSalon: salon,
      clearBio: true,
      clearMessage: true,
      clearWaUrl: true,
    );

    await _loadBio(salon);
  }

  /// Generate (or regenerate) the personalized invite message.
  Future<void> generateMessage() async {
    final salon = state.selectedSalon;
    if (salon == null) return;

    state = state.copyWith(step: InviteStep.generating);

    try {
      final userName = _getCurrentUserName();

      final message = await _service.generateInviteMessage(
        userName: userName,
        salon: salon,
        serviceSearched: state.serviceFilter,
      );

      state = state.copyWith(
        step: InviteStep.readyToSend,
        inviteMessage: message,
      );
    } catch (e) {
      debugPrint('[INVITE] generateMessage error: $e');
      state = state.copyWith(
        step: InviteStep.error,
        error: e.toString(),
      );
    }
  }

  /// Send the invite: record in DB + platform WA. Returns WA URL.
  Future<void> sendInvite() async {
    final salon = state.selectedSalon;
    final message = state.inviteMessage;
    if (salon == null || message == null) return;

    final phone = salon.whatsapp ?? salon.phone;
    if (phone == null || phone.isEmpty) {
      state = state.copyWith(
        step: InviteStep.error,
        error: 'Este salón no tiene número de teléfono registrado.',
      );
      return;
    }

    state = state.copyWith(step: InviteStep.sending);

    try {
      final waUrl = await _service.sendInvite(
        salonId: salon.id,
        salonPhone: phone,
        inviteMessage: message,
      );

      state = state.copyWith(
        step: InviteStep.sent,
        waUrl: waUrl,
      );
    } catch (e) {
      debugPrint('[INVITE] sendInvite error: $e');
      state = state.copyWith(
        step: InviteStep.error,
        error: e.toString(),
      );
    }
  }

  /// Go back from detail to browsing.
  void backToList() {
    state = state.copyWith(
      step: InviteStep.browsing,
      clearSelectedSalon: true,
      clearBio: true,
      clearMessage: true,
      clearWaUrl: true,
    );
  }

  /// Clear search and show original list.
  void clearSearch() {
    state = state.copyWith(
      clearSearchQuery: true,
      suggestScrape: false,
    );
    // Re-fetch the original nearby list
    initialize(serviceType: state.serviceFilter);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _loadBio(DiscoveredSalon salon) async {
    try {
      final bio = await _service.generateBio(salon);
      // Only update if still viewing this salon
      if (state.selectedSalon?.id == salon.id) {
        state = state.copyWith(generatedBio: bio);
      }
    } catch (e) {
      debugPrint('[INVITE] generateBio error: $e');
      // Bio failure is non-fatal — salon detail still shows without bio
    }
  }

  String _getCurrentUserName() {
    try {
      final user = SupabaseClientService.client.auth.currentUser;
      final username =
          user?.userMetadata?['username'] as String? ?? 'Usuaria';
      return username;
    } catch (_) {
      return 'Usuaria';
    }
  }
}

// ---------------------------------------------------------------------------
// Provider Registration
// ---------------------------------------------------------------------------

final inviteServiceProvider = Provider<InviteService>((ref) => InviteService());

final inviteProvider =
    StateNotifierProvider.autoDispose<InviteNotifier, InviteState>(
  (ref) => InviteNotifier(ref.watch(inviteServiceProvider)),
);
