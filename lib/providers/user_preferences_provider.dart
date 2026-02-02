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

  const UserPrefsState({
    this.defaultTransport = 'car',
    this.notificationsEnabled = true,
    this.searchRadiusKm = 50,
  });

  UserPrefsState copyWith({
    String? defaultTransport,
    bool? notificationsEnabled,
    int? searchRadiusKm,
  }) {
    return UserPrefsState(
      defaultTransport: defaultTransport ?? this.defaultTransport,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      searchRadiusKm: searchRadiusKm ?? this.searchRadiusKm,
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
      state = UserPrefsState(
        defaultTransport: transport,
        notificationsEnabled: notifications,
        searchRadiusKm: radius,
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
