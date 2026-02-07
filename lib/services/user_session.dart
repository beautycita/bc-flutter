import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'supabase_client.dart';

/// Service for managing local user session with Supabase identity persistence
class UserSession {
  static const String _keyUserId = 'user_id';
  static const String _keyUsername = 'username';
  static const String _keyRegisteredAt = 'registered_at';
  static const String _keyLastLoginAt = 'last_login_at';
  static const String _keySupabaseUserId = 'supabase_user_id';

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

    // Store Supabase user ID if authenticated
    if (SupabaseClientService.isInitialized && SupabaseClientService.isAuthenticated) {
      final supaId = SupabaseClientService.client.auth.currentUser?.id;
      if (supaId != null) {
        await prefs.setString(_keySupabaseUserId, supaId);
      }
    }
  }

  /// Get the stored username
  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername);
  }

  /// Get the stored local user ID
  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  /// Get the stored Supabase user ID
  Future<String?> getSupabaseUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySupabaseUserId);
  }

  /// Save the current Supabase user ID to local storage
  Future<void> saveSupabaseUserId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySupabaseUserId, id);
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

  /// Ensure a valid Supabase session exists.
  /// Returns true if session is active, false if offline/failed.
  Future<bool> ensureSupabaseSession() async {
    if (!SupabaseClientService.isInitialized) return false;

    // SDK auto-restores session from local storage on init.
    // If already authenticated, we're good.
    if (SupabaseClientService.isAuthenticated) {
      // Sync stored ID if missing
      final prefs = await SharedPreferences.getInstance();
      final storedId = prefs.getString(_keySupabaseUserId);
      final currentId = SupabaseClientService.client.auth.currentUser?.id;
      if (storedId == null && currentId != null) {
        await prefs.setString(_keySupabaseUserId, currentId);
      }
      return true;
    }

    // Not authenticated — try to create anonymous session
    try {
      final response = await SupabaseClientService.client.auth.signInAnonymously();
      final userId = response.user?.id;
      if (userId != null) {
        await saveSupabaseUserId(userId);
        debugPrint('Supabase: New anonymous session $userId');
      }
      return SupabaseClientService.isAuthenticated;
    } catch (e) {
      debugPrint('Supabase: Session restore failed ($e)');
      return false;
    }
  }

  /// Clear all session data (logout)
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyRegisteredAt);
    await prefs.remove(_keyLastLoginAt);
    await prefs.remove(_keySupabaseUserId);
  }
}
