import 'package:shared_preferences/shared_preferences.dart';

class UserPreferences {
  static const _keyDefaultTransport = 'pref_default_transport';
  static const _keyNotificationsEnabled = 'pref_notifications';
  static const _keySearchRadius = 'pref_search_radius';
  static const _keyPriceComfort = 'pref_price_comfort';
  static const _keyQualitySpeed = 'pref_quality_speed';
  static const _keyExploreLoyalty = 'pref_explore_loyal';
  static const _keyOnboardingComplete = 'pref_onboarding_complete';

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

  Future<String> getPriceComfort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPriceComfort) ?? 'moderate';
  }

  Future<void> setPriceComfort(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPriceComfort, value);
  }

  Future<double> getQualitySpeed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyQualitySpeed) ?? 0.7;
  }

  Future<void> setQualitySpeed(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyQualitySpeed, value);
  }

  Future<double> getExploreLoyalty() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyExploreLoyalty) ?? 0.3;
  }

  Future<void> setExploreLoyalty(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyExploreLoyalty, value);
  }

  Future<bool> getOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboardingComplete) ?? false;
  }

  Future<void> setOnboardingComplete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingComplete, value);
  }
}
