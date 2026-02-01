import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Service for managing local user session
class UserSession {
  static const String _keyUserId = 'user_id';
  static const String _keyUsername = 'username';
  static const String _keyRegisteredAt = 'registered_at';
  static const String _keyLastLoginAt = 'last_login_at';

  final Uuid _uuid = const Uuid();

  /// Check if user has completed biometric registration
  Future<bool> isRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_keyUserId);
    final username = prefs.getString(_keyUsername);
    return userId != null && username != null;
  }

  /// Register a new user with the given username
  Future<void> register(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toIso8601String();

    await prefs.setString(_keyUserId, _uuid.v4());
    await prefs.setString(_keyUsername, username);
    await prefs.setString(_keyRegisteredAt, now);
    await prefs.setString(_keyLastLoginAt, now);
  }

  /// Get the stored username
  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername);
  }

  /// Get the stored user ID
  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  /// Get the registration timestamp
  Future<String?> getRegisteredAt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRegisteredAt);
  }

  /// Update last login timestamp
  Future<void> updateLastLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toIso8601String();
    await prefs.setString(_keyLastLoginAt, now);
  }

  /// Get last login timestamp
  Future<String?> getLastLoginAt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastLoginAt);
  }

  /// Clear all session data (logout)
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyRegisteredAt);
    await prefs.remove(_keyLastLoginAt);
  }
}
