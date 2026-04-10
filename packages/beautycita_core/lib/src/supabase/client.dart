import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shared Supabase client initialization.
/// Both mobile and web apps call this during startup.
class BCSupabase {
  static bool _initialized = false;
  static bool _initAttempted = false;
  static String? _initError;
  static Future<void>? _initFuture;

  static bool get isInitialized => _initialized;

  /// Whether initialization was attempted (successfully or not).
  static bool get initAttempted => _initAttempted;

  /// Whether initialization was attempted and failed.
  static bool get initFailed => _initAttempted && !_initialized;

  /// The error message from the last failed initialization attempt, if any.
  static String? get initError => _initError;

  static SupabaseClient get client {
    if (!_initialized) {
      throw StateError(
          'Supabase not initialized. Call BCSupabase.initialize() first.');
    }
    return Supabase.instance.client;
  }

  /// Initialize Supabase. Safe to call multiple times — returns the same
  /// cached future. Use [force] to reset and re-attempt after failure.
  /// Can be called without await to start init in the background.
  static Future<void> initialize({bool force = false}) {
    if (force) _initFuture = null;
    _initFuture ??= _doInitialize();
    return _initFuture!;
  }

  static Future<void> _doInitialize() async {
    if (_initialized) return;

    _initAttempted = true;
    _initError = null;

    try {
      debugPrint('Supabase: Loading .env...');
      await dotenv.load(fileName: '.env');
    } catch (e) {
      _initError = 'Failed to load .env: $e';
      debugPrint('Supabase: $_initError');
      return;
    }

    final url = dotenv.env['SUPABASE_URL'] ?? '';
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    debugPrint('Supabase: .env loaded. URL=$url, key=${anonKey.isNotEmpty ? "present" : "EMPTY"}');

    if (url.isEmpty || anonKey.isEmpty || url.contains('PLACEHOLDER')) {
      _initError = 'No credentials configured (url=${url.isEmpty ? "empty" : "ok"}, key=${anonKey.isEmpty ? "empty" : "ok"})';
      debugPrint('Supabase: $_initError');
      return;
    }

    // Exponential backoff: 3 attempts with 3s, 6s, 12s timeouts.
    const timeouts = [3, 6, 12];
    for (var attempt = 0; attempt < timeouts.length; attempt++) {
      try {
        debugPrint('Supabase: Init attempt ${attempt + 1}/${timeouts.length} '
            '(timeout ${timeouts[attempt]}s)...');
        await Supabase.initialize(url: url, anonKey: anonKey)
            .timeout(Duration(seconds: timeouts[attempt]));
        _initialized = true;
        _initError = null;
        debugPrint('Supabase: Connected to $url');
        return;
      } catch (e, st) {
        debugPrint('Supabase: Attempt ${attempt + 1} failed: $e');
        if (attempt == 0) {
          debugPrint('Supabase: Stack: ${st.toString().split('\n').take(5).join('\n')}');
        }
        // The SDK's _init() runs synchronously before the async auth init.
        // If timeout fires, the client may already exist and be usable.
        try {
          final _ = Supabase.instance.client;
          _initialized = true;
          _initError = null;
          debugPrint('Supabase: Recovered after exception, client usable.');
          return;
        } catch (_) {
          // Client not available yet — continue retrying
        }
        _initError = e.toString();
      }
    }
    debugPrint('Supabase: All ${timeouts.length} init attempts failed.');
  }

  static String? get currentUserId =>
      _initialized ? Supabase.instance.client.auth.currentUser?.id : null;

  static bool get isAuthenticated =>
      _initialized && Supabase.instance.client.auth.currentUser != null;
}
