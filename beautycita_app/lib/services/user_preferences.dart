import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beautycita/services/supabase_client.dart';

class UserPreferences {
  static const _keyDefaultTransport = 'pref_default_transport';
  static const _keyNotificationsEnabled = 'pref_notifications';
  static const _keySearchRadius = 'pref_search_radius';
  static const _keyPriceComfort = 'pref_price_comfort';
  static const _keyQualitySpeed = 'pref_quality_speed';
  static const _keyExploreLoyalty = 'pref_explore_loyal';
  static const _keyOnboardingComplete = 'pref_onboarding_complete';
  static const _keyNotifyBookingReminders = 'pref_notify_booking_reminders';
  static const _keyNotifyPromotions = 'pref_notify_promotions';
  static const _keyNotifyMessages = 'pref_notify_messages';
  static const _keyNotifyAppointmentUpdates = 'pref_notify_appointment_updates';

  bool _serverLoaded = false;

  /// Load preferences from server and merge into local SharedPreferences.
  /// Server values take priority over local defaults (but not over local values
  /// that differ from defaults, indicating user has set them locally).
  Future<void> loadFromServer() async {
    if (_serverLoaded) return;
    if (!SupabaseClientService.isInitialized) return;
    final userId = SupabaseClientService.currentUserId;
    if (userId == null) return;

    try {
      final data = await SupabaseClientService.client
          .from('profiles')
          .select('preferences')
          .eq('id', userId)
          .maybeSingle();

      final serverPrefs = data?['preferences'] as Map<String, dynamic>?;
      if (serverPrefs == null || serverPrefs.isEmpty) {
        _serverLoaded = true;
        // No server prefs yet — push current local prefs to server
        await _syncToServer();
        return;
      }

      // Apply server values to local SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      for (final entry in serverPrefs.entries) {
        final key = entry.key;
        final value = entry.value;
        if (value is String) {
          await prefs.setString(key, value);
        } else if (value is bool) {
          await prefs.setBool(key, value);
        } else if (value is int) {
          await prefs.setInt(key, value);
        } else if (value is double) {
          await prefs.setDouble(key, value);
        }
      }
      _serverLoaded = true;
    } catch (e) {
      debugPrint('UserPreferences.loadFromServer error: $e');
      _serverLoaded = true; // Don't retry on every call
    }
  }

  /// Push all current local preferences to the server.
  Future<void> _syncToServer() async {
    if (!SupabaseClientService.isInitialized) return;
    final userId = SupabaseClientService.currentUserId;
    if (userId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final map = <String, dynamic>{
        _keyDefaultTransport: prefs.getString(_keyDefaultTransport) ?? 'car',
        _keyNotificationsEnabled: prefs.getBool(_keyNotificationsEnabled) ?? true,
        _keyNotifyBookingReminders: prefs.getBool(_keyNotifyBookingReminders) ?? true,
        _keyNotifyPromotions: prefs.getBool(_keyNotifyPromotions) ?? true,
        _keyNotifyMessages: prefs.getBool(_keyNotifyMessages) ?? true,
        _keyNotifyAppointmentUpdates: prefs.getBool(_keyNotifyAppointmentUpdates) ?? true,
        _keySearchRadius: prefs.getInt(_keySearchRadius) ?? 50,
        _keyPriceComfort: prefs.getString(_keyPriceComfort) ?? 'moderate',
        _keyQualitySpeed: prefs.getDouble(_keyQualitySpeed) ?? 0.7,
        _keyExploreLoyalty: prefs.getDouble(_keyExploreLoyalty) ?? 0.3,
        _keyOnboardingComplete: prefs.getBool(_keyOnboardingComplete) ?? false,
      };

      await SupabaseClientService.client
          .from('profiles')
          .update({'preferences': map})
          .eq('id', userId);
    } catch (e) {
      debugPrint('UserPreferences._syncToServer error: $e');
    }
  }

  /// Save a single preference both locally and to server.
  Future<void> _saveAndSync(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    }
    // Fire-and-forget server sync
    _syncToServer();
  }

  // Generic bool getter/setter for flexibility
  Future<bool> getBool(String key, {bool defaultValue = true}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? defaultValue;
  }

  Future<void> setBool(String key, bool value) async {
    await _saveAndSync(key, value);
  }

  Future<String> getDefaultTransport() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDefaultTransport) ?? 'car';
  }

  Future<void> setDefaultTransport(String mode) async {
    await _saveAndSync(_keyDefaultTransport, mode);
  }

  Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotificationsEnabled) ?? true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _saveAndSync(_keyNotificationsEnabled, enabled);
  }

  Future<int> getSearchRadius() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keySearchRadius) ?? 50;
  }

  Future<void> setSearchRadius(int km) async {
    await _saveAndSync(_keySearchRadius, km);
  }

  Future<String> getPriceComfort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPriceComfort) ?? 'moderate';
  }

  Future<void> setPriceComfort(String value) async {
    await _saveAndSync(_keyPriceComfort, value);
  }

  Future<double> getQualitySpeed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyQualitySpeed) ?? 0.7;
  }

  Future<void> setQualitySpeed(double value) async {
    await _saveAndSync(_keyQualitySpeed, value);
  }

  Future<double> getExploreLoyalty() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyExploreLoyalty) ?? 0.3;
  }

  Future<void> setExploreLoyalty(double value) async {
    await _saveAndSync(_keyExploreLoyalty, value);
  }

  Future<bool> getOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboardingComplete) ?? false;
  }

  Future<void> setOnboardingComplete(bool value) async {
    await _saveAndSync(_keyOnboardingComplete, value);
  }

  // Notification type getters
  Future<bool> getNotifyBookingReminders() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotifyBookingReminders) ?? true;
  }

  Future<bool> getNotifyPromotions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotifyPromotions) ?? true;
  }

  Future<bool> getNotifyMessages() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotifyMessages) ?? true;
  }

  Future<bool> getNotifyAppointmentUpdates() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotifyAppointmentUpdates) ?? true;
  }
}
