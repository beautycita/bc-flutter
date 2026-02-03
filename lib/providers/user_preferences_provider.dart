import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/user_preferences.dart';

// ---------------------------------------------------------------------------
// User Preferences State
// ---------------------------------------------------------------------------

class UserPrefsState {
  final String defaultTransport; // 'car', 'uber', 'transit'
  final bool notificationsEnabled;
  final int searchRadiusKm;
  final String priceComfort; // 'budget', 'moderate', 'premium'
  final double qualitySpeed; // 0.0 (fastest) to 1.0 (best quality)
  final double exploreLoyalty; // 0.0 (explore new) to 1.0 (loyal to known)
  final bool onboardingComplete;

  const UserPrefsState({
    this.defaultTransport = 'car',
    this.notificationsEnabled = true,
    this.searchRadiusKm = 50,
    this.priceComfort = 'moderate',
    this.qualitySpeed = 0.7,
    this.exploreLoyalty = 0.3,
    this.onboardingComplete = false,
  });

  UserPrefsState copyWith({
    String? defaultTransport,
    bool? notificationsEnabled,
    int? searchRadiusKm,
    String? priceComfort,
    double? qualitySpeed,
    double? exploreLoyalty,
    bool? onboardingComplete,
  }) {
    return UserPrefsState(
      defaultTransport: defaultTransport ?? this.defaultTransport,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      searchRadiusKm: searchRadiusKm ?? this.searchRadiusKm,
      priceComfort: priceComfort ?? this.priceComfort,
      qualitySpeed: qualitySpeed ?? this.qualitySpeed,
      exploreLoyalty: exploreLoyalty ?? this.exploreLoyalty,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    );
  }
}

// ---------------------------------------------------------------------------
// User Preferences Notifier
// ---------------------------------------------------------------------------

class UserPrefsNotifier extends StateNotifier<UserPrefsState> {
  final UserPreferences _prefs;

  UserPrefsNotifier(this._prefs) : super(const UserPrefsState()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final transport = await _prefs.getDefaultTransport();
      final notifications = await _prefs.getNotificationsEnabled();
      final radius = await _prefs.getSearchRadius();
      final priceComfort = await _prefs.getPriceComfort();
      final qualitySpeed = await _prefs.getQualitySpeed();
      final exploreLoyalty = await _prefs.getExploreLoyalty();
      final onboardingComplete = await _prefs.getOnboardingComplete();
      state = UserPrefsState(
        defaultTransport: transport,
        notificationsEnabled: notifications,
        searchRadiusKm: radius,
        priceComfort: priceComfort,
        qualitySpeed: qualitySpeed,
        exploreLoyalty: exploreLoyalty,
        onboardingComplete: onboardingComplete,
      );
    } catch (e) {
      debugPrint('Failed to load user prefs: $e');
    }
  }

  Future<void> setDefaultTransport(String mode) async {
    await _prefs.setDefaultTransport(mode);
    state = state.copyWith(defaultTransport: mode);
  }

  Future<void> toggleNotifications() async {
    final newValue = !state.notificationsEnabled;
    await _prefs.setNotificationsEnabled(newValue);
    state = state.copyWith(notificationsEnabled: newValue);
  }

  Future<void> setSearchRadius(int km) async {
    await _prefs.setSearchRadius(km);
    state = state.copyWith(searchRadiusKm: km);
  }

  Future<void> setPriceComfort(String value) async {
    await _prefs.setPriceComfort(value);
    state = state.copyWith(priceComfort: value);
  }

  Future<void> setQualitySpeed(double value) async {
    await _prefs.setQualitySpeed(value);
    state = state.copyWith(qualitySpeed: value);
  }

  Future<void> setExploreLoyalty(double value) async {
    await _prefs.setExploreLoyalty(value);
    state = state.copyWith(exploreLoyalty: value);
  }

  Future<void> setOnboardingComplete(bool value) async {
    await _prefs.setOnboardingComplete(value);
    state = state.copyWith(onboardingComplete: value);
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final userPreferencesProvider = Provider((ref) => UserPreferences());

final userPrefsProvider =
    StateNotifierProvider<UserPrefsNotifier, UserPrefsState>((ref) {
  final prefs = ref.watch(userPreferencesProvider);
  return UserPrefsNotifier(prefs);
});
