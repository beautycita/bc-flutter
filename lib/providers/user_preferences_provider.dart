import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/services/toast_service.dart';
import '../services/user_preferences.dart';

// ---------------------------------------------------------------------------
// User Preferences State
// ---------------------------------------------------------------------------

class UserPrefsState {
  final String defaultTransport; // 'car', 'uber', 'transit'
  final bool notificationsEnabled;
  final bool notifyBookingReminders;
  final bool notifyPromotions;
  final bool notifyMessages;
  final bool notifyAppointmentUpdates;
  final int searchRadiusKm;
  final String priceComfort; // 'budget', 'moderate', 'premium'
  final double qualitySpeed; // 0.0 (fastest) to 1.0 (best quality)
  final double exploreLoyalty; // 0.0 (explore new) to 1.0 (loyal to known)
  final bool onboardingComplete;

  const UserPrefsState({
    this.defaultTransport = 'car',
    this.notificationsEnabled = true,
    this.notifyBookingReminders = true,
    this.notifyPromotions = true,
    this.notifyMessages = true,
    this.notifyAppointmentUpdates = true,
    this.searchRadiusKm = 50,
    this.priceComfort = 'moderate',
    this.qualitySpeed = 0.7,
    this.exploreLoyalty = 0.3,
    this.onboardingComplete = false,
  });

  UserPrefsState copyWith({
    String? defaultTransport,
    bool? notificationsEnabled,
    bool? notifyBookingReminders,
    bool? notifyPromotions,
    bool? notifyMessages,
    bool? notifyAppointmentUpdates,
    int? searchRadiusKm,
    String? priceComfort,
    double? qualitySpeed,
    double? exploreLoyalty,
    bool? onboardingComplete,
  }) {
    return UserPrefsState(
      defaultTransport: defaultTransport ?? this.defaultTransport,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notifyBookingReminders: notifyBookingReminders ?? this.notifyBookingReminders,
      notifyPromotions: notifyPromotions ?? this.notifyPromotions,
      notifyMessages: notifyMessages ?? this.notifyMessages,
      notifyAppointmentUpdates: notifyAppointmentUpdates ?? this.notifyAppointmentUpdates,
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
      final notifyBookingReminders = await _prefs.getNotifyBookingReminders();
      final notifyPromotions = await _prefs.getNotifyPromotions();
      final notifyMessages = await _prefs.getNotifyMessages();
      final notifyAppointmentUpdates = await _prefs.getNotifyAppointmentUpdates();
      final radius = await _prefs.getSearchRadius();
      final priceComfort = await _prefs.getPriceComfort();
      final qualitySpeed = await _prefs.getQualitySpeed();
      final exploreLoyalty = await _prefs.getExploreLoyalty();
      final onboardingComplete = await _prefs.getOnboardingComplete();
      state = UserPrefsState(
        defaultTransport: transport,
        notificationsEnabled: notifications,
        notifyBookingReminders: notifyBookingReminders,
        notifyPromotions: notifyPromotions,
        notifyMessages: notifyMessages,
        notifyAppointmentUpdates: notifyAppointmentUpdates,
        searchRadiusKm: radius,
        priceComfort: priceComfort,
        qualitySpeed: qualitySpeed,
        exploreLoyalty: exploreLoyalty,
        onboardingComplete: onboardingComplete,
      );
    } catch (e) {
      debugPrint('Failed to load user prefs: $e');
      ToastService.showError(ToastService.friendlyError(e));
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

  Future<void> toggleBookingReminders() async {
    final newValue = !state.notifyBookingReminders;
    await _prefs.setBool('pref_notify_booking_reminders', newValue);
    state = state.copyWith(notifyBookingReminders: newValue);
  }

  Future<void> togglePromotions() async {
    final newValue = !state.notifyPromotions;
    await _prefs.setBool('pref_notify_promotions', newValue);
    state = state.copyWith(notifyPromotions: newValue);
  }

  Future<void> toggleMessages() async {
    final newValue = !state.notifyMessages;
    await _prefs.setBool('pref_notify_messages', newValue);
    state = state.copyWith(notifyMessages: newValue);
  }

  Future<void> toggleAppointmentUpdates() async {
    final newValue = !state.notifyAppointmentUpdates;
    await _prefs.setBool('pref_notify_appointment_updates', newValue);
    state = state.copyWith(notifyAppointmentUpdates: newValue);
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
