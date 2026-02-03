import 'package:shared_preferences/shared_preferences.dart';

class UserPreferences {
  static const _keyDefaultTransport = 'pref_default_transport';
  static const _keyNotificationsEnabled = 'pref_notifications';
  static const _keySearchRadius = 'pref_search_radius';

  Future<String> getDefaultTransport() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDefaultTransport) ?? 'car';
  }

  Future<void> setDefaultTransport(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDefaultTransport, mode);
  }

  Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotificationsEnabled) ?? true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotificationsEnabled, enabled);
  }

  Future<int> getSearchRadius() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keySearchRadius) ?? 50;
  }

  Future<void> setSearchRadius(int km) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySearchRadius, km);
  }
}
