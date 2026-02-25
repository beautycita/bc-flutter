import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  // Sensitive IDs are stored in the OS keystore (Android Keystore / iOS Keychain)
  static const _secureStorage = FlutterSecureStorage();

  final Uuid _uuid = const Uuid();

  /// Check if user has completed biometric registration
  Future<bool> isRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = await _getSecureUserId();
    final username = prefs.getString(_keyUsername);
    return userId != null && username != null;
  }

  /// Register a new user with the given username
  Future<void> register(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toIso8601String();

    await _setSecureUserId(_uuid.v4());
    await prefs.setString(_keyUsername, username);
    await prefs.setString(_keyRegisteredAt, now);
    await prefs.setString(_keyLastLoginAt, now);

    // Store Supabase user ID if authenticated
    if (SupabaseClientService.isInitialized && SupabaseClientService.isAuthenticated) {
      final supaId = SupabaseClientService.client.auth.currentUser?.id;
      if (supaId != null) {
        await _setSecureSupabaseUserId(supaId);
      }
    }
  }

  /// Get the stored username (not sensitive — publicly displayed, stays in SharedPreferences)
  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername);
  }

  /// Get the stored local user ID from secure storage
  Future<String?> getUserId() async {
    return _getSecureUserId();
  }

  /// Get the stored Supabase user ID from secure storage
  Future<String?> getSupabaseUserId() async {
    return _getSecureSupabaseUserId();
  }

  /// Save the current Supabase user ID to secure storage
  Future<void> saveSupabaseUserId(String id) async {
    await _setSecureSupabaseUserId(id);
  }

  /// Get the registration timestamp (not sensitive — stays in SharedPreferences)
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
  ///
  /// IMPORTANT: Only creates a new anonymous user if we have NO stored
  /// Supabase user ID. This prevents duplicate accounts when the SDK
  /// fails to restore a previous anonymous session (app reinstall,
  /// cache clear, JWT expiry).
  Future<bool> ensureSupabaseSession() async {
    if (!SupabaseClientService.isInitialized) return false;

    // SDK auto-restores session from local storage on init.
    // If already authenticated, we're good.
    if (SupabaseClientService.isAuthenticated) {
      // Sync stored ID if missing
      final storedId = await _getSecureSupabaseUserId();
      final currentId = SupabaseClientService.client.auth.currentUser?.id;
      if (storedId == null && currentId != null) {
        await _setSecureSupabaseUserId(currentId);
      }
      return true;
    }

    // Check if we already have a stored Supabase user ID from a
    // previous session. If so, DON'T create a new anonymous user —
    // that would duplicate the account. The profile already exists
    // in the DB; we just lost the JWT. We can still read/write via
    // anon key + RLS policies.
    final storedSupabaseId = await _getSecureSupabaseUserId();
    if (storedSupabaseId != null) {
      debugPrint('[UserSession] Have stored user $storedSupabaseId but SDK session lost. '
          'Creating fresh anonymous session and migrating profile server-side.');
      try {
        final response =
            await SupabaseClientService.client.auth.signInAnonymously();
        final newId = response.user?.id;
        if (newId != null && newId != storedSupabaseId) {
          debugPrint('[UserSession] Migrating profile $storedSupabaseId -> $newId (server-side)');
          // Delegate profile migration to the edge function which validates
          // ownership server-side before touching any profile rows.
          try {
            await SupabaseClientService.client.functions.invoke('migrate-profile', body: {
              'old_user_id': storedSupabaseId,
            });
          } catch (e) {
            debugPrint('[UserSession] Profile migration failed: $e');
          }
          await _setSecureSupabaseUserId(newId);
        }
        return SupabaseClientService.isAuthenticated;
      } catch (e) {
        debugPrint('[UserSession] Re-auth failed ($e)');
        return false;
      }
    }

    // First time ever — create new anonymous session
    try {
      final response = await SupabaseClientService.client.auth.signInAnonymously();
      final userId = response.user?.id;
      if (userId != null) {
        await saveSupabaseUserId(userId);
        debugPrint('[UserSession] New anonymous session $userId');
        // Tag registration source as APK (Android build)
        try {
          await SupabaseClientService.client
              .from('profiles')
              .update({'registration_source': 'apk'})
              .eq('id', userId);
        } catch (_) {}
      }
      return SupabaseClientService.isAuthenticated;
    } catch (e) {
      debugPrint('[UserSession] Session creation failed ($e)');
      return false;
    }
  }

  /// Clear all session data (logout)
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyRegisteredAt);
    await prefs.remove(_keyLastLoginAt);
    // Remove legacy SharedPreferences keys in case they still exist
    await prefs.remove(_keyUserId);
    await prefs.remove(_keySupabaseUserId);
    // Clear secure storage keys
    await _secureStorage.delete(key: _keyUserId);
    await _secureStorage.delete(key: _keySupabaseUserId);
  }

  // ---------------------------------------------------------------------------
  // Private helpers — secure storage reads with SharedPreferences migration
  // ---------------------------------------------------------------------------

  /// Read user_id from secure storage, migrating from SharedPreferences if needed.
  Future<String?> _getSecureUserId() async {
    String? id = await _secureStorage.read(key: _keyUserId);
    if (id != null) return id;

    // One-time migration from plaintext SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    id = prefs.getString(_keyUserId);
    if (id != null) {
      await _secureStorage.write(key: _keyUserId, value: id);
      await prefs.remove(_keyUserId);
      debugPrint('[UserSession] Migrated user_id to secure storage');
    }
    return id;
  }

  /// Write user_id to secure storage.
  Future<void> _setSecureUserId(String id) async {
    await _secureStorage.write(key: _keyUserId, value: id);
  }

  /// Read supabase_user_id from secure storage, migrating from SharedPreferences if needed.
  Future<String?> _getSecureSupabaseUserId() async {
    String? id = await _secureStorage.read(key: _keySupabaseUserId);
    if (id != null) return id;

    // One-time migration from plaintext SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    id = prefs.getString(_keySupabaseUserId);
    if (id != null) {
      await _secureStorage.write(key: _keySupabaseUserId, value: id);
      await prefs.remove(_keySupabaseUserId);
      debugPrint('[UserSession] Migrated supabase_user_id to secure storage');
    }
    return id;
  }

  /// Write supabase_user_id to secure storage.
  Future<void> _setSecureSupabaseUserId(String id) async {
    await _secureStorage.write(key: _keySupabaseUserId, value: id);
  }
}
