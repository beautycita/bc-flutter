import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:beautycita_core/supabase.dart';

import '../services/webauthn_service.dart';

// ── Auth state model ──────────────────────────────────────────────────────────

@immutable
class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final User? user;

  const AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.user,
  });

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    User? user,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      user: clearUser ? null : (user ?? this.user),
    );
  }
}

// ── Auth notifier ─────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    // Seed with current user if Supabase is initialized
    if (BCSupabase.isInitialized) {
      final currentUser = BCSupabase.client.auth.currentUser;
      if (currentUser != null) {
        state = state.copyWith(user: currentUser);
        _startSessionPing();
        // Pre-existing authenticated session (e.g. tab reopen): subscribe
        // to user-scoped revocation broadcasts so a mobile-issued kick
        // arrives even though we didn't go through the registerWebSession
        // path on this load.
        _subscribeToRevocations();
      }
    }
  }

  /// Cached role to avoid repeated DB queries during navigation.
  String? _cachedRole;
  DateTime? _cachedRoleAt;
  static const Duration _roleCacheTtl = Duration(minutes: 5);

  /// Periodic timer that validates the session is still active.
  Timer? _sessionPingTimer;

  /// Sign in with email + password.
  Future<bool> signInWithEmail(String email, String password) async {
    if (!BCSupabase.isInitialized) {
      state = state.copyWith(
        errorMessage: 'Servicio no disponible. Intenta mas tarde.',
      );
      return false;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await BCSupabase.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      state = state.copyWith(isLoading: false, user: response.user);
      if (response.user != null) {
        _startSessionPing();
        registerWebSession(); // fire-and-forget
      }
      return response.user != null;
    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _translateAuthError(e.message),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error inesperado. Intenta de nuevo.',
      );
      return false;
    }
  }

  /// Sign up with email + password + display name.
  Future<bool> signUpWithEmail(
      String email, String password, String name) async {
    if (!BCSupabase.isInitialized) {
      state = state.copyWith(
        errorMessage: 'Servicio no disponible. Intenta mas tarde.',
      );
      return false;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await BCSupabase.client.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': name},
      );
      state = state.copyWith(isLoading: false, user: response.user);
      if (response.user != null) {
        _startSessionPing();
        registerWebSession(); // fire-and-forget
      }
      return response.user != null;
    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _translateAuthError(e.message),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error inesperado. Intenta de nuevo.',
      );
      return false;
    }
  }

  /// OAuth with Google.
  Future<bool> signInWithGoogle() async {
    if (!BCSupabase.isInitialized) {
      state = state.copyWith(
        errorMessage: 'Servicio no disponible. Intenta mas tarde.',
      );
      return false;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await BCSupabase.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _redirectUrl,
      );
      // OAuth redirects the browser — state updates via onAuthStateChange
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No se pudo iniciar con Google.',
      );
      return false;
    }
  }

  /// OAuth with Apple.
  Future<bool> signInWithApple() async {
    if (!BCSupabase.isInitialized) {
      state = state.copyWith(
        errorMessage: 'Servicio no disponible. Intenta mas tarde.',
      );
      return false;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await BCSupabase.client.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: _redirectUrl,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No se pudo iniciar con Apple.',
      );
      return false;
    }
  }

  /// Send password reset email.
  Future<bool> resetPassword(String email) async {
    if (!BCSupabase.isInitialized) {
      state = state.copyWith(
        errorMessage: 'Servicio no disponible. Intenta mas tarde.',
      );
      return false;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await BCSupabase.client.auth.resetPasswordForEmail(email);
      state = state.copyWith(isLoading: false);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _translateAuthError(e.message),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error inesperado. Intenta de nuevo.',
      );
      return false;
    }
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    if (!BCSupabase.isInitialized) return;
    _cachedRole = null;
    _cachedRoleAt = null;
    _stopSessionPing();
    if (_revokeChannel != null) {
      try {
        BCSupabase.client.removeChannel(_revokeChannel!);
      } catch (_) {/* best effort */}
      _revokeChannel = null;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await BCSupabase.client.auth.signOut();
      state = const AuthState();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error al cerrar sesion.',
      );
    }
  }

  /// Query the profiles table for the user's role.
  /// Caches the result so subsequent calls (router redirects) are instant.
  /// Pass [forceRefresh] = true from admin/business contexts to re-fetch.
  Future<String?> getUserRole({bool forceRefresh = false}) async {
    final cacheStillFresh = _cachedRoleAt != null &&
        DateTime.now().difference(_cachedRoleAt!) < _roleCacheTtl;
    if (!forceRefresh &&
        _cachedRole != null &&
        cacheStillFresh &&
        state.user != null) {
      return _cachedRole;
    }
    if (!BCSupabase.isInitialized || state.user == null) return null;
    try {
      final data = await BCSupabase.client
          .from(BCTables.profiles)
          .select('role')
          .eq('id', state.user!.id)
          .maybeSingle();
      _cachedRole = data?['role'] as String?;
      _cachedRoleAt = DateTime.now();
      return _cachedRole;
    } catch (e) {
      debugPrint('getUserRole error: $e');
      return null;
    }
  }

  /// Set the authenticated user (e.g., after QR login).
  void setUser(User user) {
    state = state.copyWith(user: user, isLoading: false, clearError: true);
    _startSessionPing();
  }

  /// Register this web session so the mobile device manager can see it.
  /// Returns the session_id for revocation listening.
  Future<String?> registerWebSession() async {
    if (!BCSupabase.isInitialized || state.user == null) return null;
    try {
      final response = await BCSupabase.client.functions.invoke(
        'qr-auth',
        body: {'action': 'register_session'},
      );
      final sessionId = response.data?['session_id'] as String?;
      _subscribeToRevocations();
      return sessionId;
    } catch (e) {
      debugPrint('registerWebSession error: $e');
      // Even if register_session failed, still subscribe — a revoke can
      // arrive on this user's channel from any path that captured the
      // auth_session_id (e.g. a prior QR consumption).
      _subscribeToRevocations();
      return null;
    }
  }

  RealtimeChannel? _revokeChannel;

  /// Subscribe to the user-scoped revocation channel and sign out only when
  /// the broadcast targets this client's specific auth.sessions.id.
  ///
  /// The mobile device manager publishes on `auth_revoke:<user_id>` with a
  /// payload of `{ qr_session_id, auth_session_id }`. We compare the
  /// payload's auth_session_id against this client's own access_token
  /// session_id claim — if they match, this is the device being revoked.
  /// If they don't match, the revocation was for a different web session
  /// belonging to the same user (e.g. a different browser).
  void _subscribeToRevocations() {
    if (!BCSupabase.isInitialized) return;
    final userId = state.user?.id;
    if (userId == null) return;

    // Re-subscribing? Tear down the old channel first.
    if (_revokeChannel != null) {
      try {
        BCSupabase.client.removeChannel(_revokeChannel!);
      } catch (_) {/* best effort */}
      _revokeChannel = null;
    }

    _revokeChannel = BCSupabase.client.channel('auth_revoke:$userId').onBroadcast(
      event: 'session_revoked',
      callback: (payload) {
        final targetAuthSessionId = payload['auth_session_id'] as String?;
        final selfAuthSessionId = _selfAuthSessionId();
        // If the broadcast carries a specific target and it doesn't match
        // this client, ignore — a different device on the same account.
        if (targetAuthSessionId != null &&
            selfAuthSessionId != null &&
            targetAuthSessionId != selfAuthSessionId) {
          debugPrint('auth_revoke broadcast targeted another session — ignoring');
          return;
        }
        debugPrint('Session revoked by mobile device — signing out');
        signOut();
      },
    ).subscribe();
  }

  /// Decode the `session_id` claim from this client's current access_token
  /// JWT. Returns null if no session or token shape is unexpected.
  String? _selfAuthSessionId() {
    final accessToken = BCSupabase.client.auth.currentSession?.accessToken;
    if (accessToken == null) return null;
    try {
      final parts = accessToken.split('.');
      if (parts.length != 3) return null;
      var b64 = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      // base64 padding
      while (b64.length % 4 != 0) {
        b64 += '=';
      }
      final decoded = utf8.decode(base64.decode(b64));
      final claims = jsonDecode(decoded) as Map<String, dynamic>;
      final sid = claims['session_id'];
      return sid is String && sid.isNotEmpty ? sid : null;
    } catch (_) {
      return null;
    }
  }

  /// Login with a passkey (WebAuthn assertion).
  /// Full flow: request challenge → browser assertion → verify → sign in.
  Future<bool> loginWithPasskey() async {
    if (!BCSupabase.isInitialized) {
      state = state.copyWith(
        errorMessage: 'Servicio no disponible. Intenta mas tarde.',
      );
      return false;
    }
    if (!WebAuthnService.isSupported()) {
      state = state.copyWith(
        errorMessage: 'Tu navegador no soporta autenticacion biometrica.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // 1. Get challenge from server
      final chalResponse = await BCSupabase.client.functions.invoke(
        'webauthn',
        body: {'action': 'login-challenge'},
      );

      final chalData = chalResponse.data as Map<String, dynamic>?;
      if (chalData == null || chalData['challenge'] == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Error al obtener desafio de autenticacion.',
        );
        return false;
      }

      final challenge = chalData['challenge'] as String;
      final rpId = chalData['rpId'] as String? ?? 'beautycita.com';

      // 2. Browser assertion (user touches fingerprint / Windows Hello)
      final assertion = await WebAuthnService.login(
        challenge: challenge,
        rpId: rpId,
      );

      // 3. Verify with server
      final verifyResponse = await BCSupabase.client.functions.invoke(
        'webauthn',
        body: {
          'action': 'login-verify',
          'credential_id': assertion.credentialId,
          'authenticator_data': assertion.authenticatorData,
          'client_data_json': assertion.clientDataJSON,
          'signature': assertion.signature,
        },
      );

      final verifyData = verifyResponse.data as Map<String, dynamic>?;
      if (verifyData == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Error al verificar autenticacion.',
        );
        return false;
      }

      if (verifyData['error'] != null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: verifyData['error'] as String,
        );
        return false;
      }

      // 4. Use the magic link OTP to sign in
      final email = verifyData['email'] as String?;
      final emailOtp = verifyData['email_otp'] as String?;

      if (email == null || emailOtp == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Error al generar sesion.',
        );
        return false;
      }

      final authResponse = await BCSupabase.client.auth.verifyOTP(
        email: email,
        token: emailOtp,
        type: OtpType.magiclink,
      );

      state = state.copyWith(isLoading: false, user: authResponse.user);
      if (authResponse.user != null) {
        _startSessionPing();
        registerWebSession(); // fire-and-forget
      }
      return authResponse.user != null;
    } catch (e) {
      debugPrint('loginWithPasskey error: $e');
      final msg = e.toString();
      if (msg.contains('cancelled') || msg.contains('AbortError')) {
        state = state.copyWith(isLoading: false, clearError: true);
        return false;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No se pudo autenticar con biometrico.',
      );
      return false;
    }
  }

  /// Register a passkey for the currently authenticated user.
  /// Call after email/password sign-up to add a passkey.
  Future<bool> registerPasskey({String? deviceName}) async {
    if (!BCSupabase.isInitialized || state.user == null) {
      state = state.copyWith(
        errorMessage: 'Debes iniciar sesion primero.',
      );
      return false;
    }
    if (!WebAuthnService.isSupported()) {
      state = state.copyWith(
        errorMessage: 'Tu navegador no soporta autenticacion biometrica.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // 1. Get challenge from server
      final chalResponse = await BCSupabase.client.functions.invoke(
        'webauthn',
        body: {'action': 'register-challenge'},
      );

      final chalData = chalResponse.data as Map<String, dynamic>?;
      if (chalData == null || chalData['challenge'] == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Error al obtener desafio de registro.',
        );
        return false;
      }

      final challenge = chalData['challenge'] as String;
      final rp = chalData['rp'] as Map<String, dynamic>;
      final user = chalData['user'] as Map<String, dynamic>;

      // 2. Browser attestation (user creates credential)
      final registration = await WebAuthnService.register(
        challenge: challenge,
        rpId: rp['id'] as String,
        rpName: rp['name'] as String,
        userId: user['id'] as String,
        userName: user['name'] as String,
        userDisplayName: user['displayName'] as String,
      );

      // 3. Verify with server
      final verifyResponse = await BCSupabase.client.functions.invoke(
        'webauthn',
        body: {
          'action': 'register-verify',
          'credential_id': registration.credentialId,
          'attestation_object': registration.attestationObject,
          'client_data_json': registration.clientDataJSON,
          'device_name': deviceName,
        },
      );

      final verifyData = verifyResponse.data as Map<String, dynamic>?;
      if (verifyData?['error'] != null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: verifyData!['error'] as String,
        );
        return false;
      }

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      debugPrint('registerPasskey error: $e');
      final msg = e.toString();
      if (msg.contains('cancelled') || msg.contains('AbortError')) {
        state = state.copyWith(isLoading: false, clearError: true);
        return false;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No se pudo registrar la llave de acceso.',
      );
      return false;
    }
  }

  /// Start a 60-second periodic ping to verify the session is still valid.
  /// If the server has revoked the session, signs the user out.
  void _startSessionPing() {
    _sessionPingTimer?.cancel();
    _sessionPingTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _checkSessionValidity(),
    );
  }

  /// Stop the session validity timer.
  void _stopSessionPing() {
    _sessionPingTimer?.cancel();
    _sessionPingTimer = null;
  }

  int _sessionPingFailures = 0;

  Future<void> _checkSessionValidity() async {
    if (!BCSupabase.isInitialized || state.user == null) {
      _stopSessionPing();
      return;
    }
    try {
      final response = await BCSupabase.client.auth.getUser();
      if (response.user == null) {
        debugPrint('Session ping: user null — signing out');
        await signOut();
        return;
      }
      _sessionPingFailures = 0;
    } on AuthException catch (e) {
      // Explicit auth failure = session actually revoked/expired. Sign out.
      debugPrint('Session ping: auth error — signing out (${e.message})');
      await signOut();
    } catch (e) {
      // Network hiccup (offline, timeout, DNS, 5xx). Do NOT sign out —
      // keep the local session and retry on the next tick. After several
      // consecutive failures, stop checking to avoid log noise; the next
      // user action will re-trigger auth if the session is truly gone.
      _sessionPingFailures++;
      debugPrint('Session ping: transient failure $_sessionPingFailures ($e)');
      if (_sessionPingFailures >= 5) {
        debugPrint('Session ping: 5 transient failures — pausing pings');
        _stopSessionPing();
      }
    }
  }

  @override
  void dispose() {
    _stopSessionPing();
    super.dispose();
  }

  /// Clear any error message.
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get _redirectUrl {
    // Web app: redirect back to the callback page
    if (kIsWeb) {
      final uri = Uri.base;
      return '${uri.scheme}://${uri.host}${uri.port != 80 && uri.port != 443 ? ':${uri.port}' : ''}/auth/callback';
    }
    return 'io.beautycita.web://auth/callback';
  }

  String _translateAuthError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid_credentials')) {
      return 'Email o contrasena incorrectos.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Confirma tu email antes de iniciar sesion.';
    }
    if (lower.contains('user already registered') ||
        lower.contains('already exists')) {
      return 'Ya existe una cuenta con ese email.';
    }
    if (lower.contains('password') && lower.contains('weak')) {
      return 'La contrasena es muy debil. Usa al menos 8 caracteres.';
    }
    if (lower.contains('rate limit') || lower.contains('too many')) {
      return 'Demasiados intentos. Espera un momento.';
    }
    return message;
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// Main auth state provider (loading, error, user).
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

/// Stream of Supabase auth state changes.
/// Also registers the web session when a user signs in (catches OAuth + refresh).
final authStateStreamProvider = StreamProvider<AuthState>((ref) {
  if (!BCSupabase.isInitialized) {
    return Stream.value(const AuthState());
  }
  return BCSupabase.client.auth.onAuthStateChange.map((data) {
    final user = data.session?.user;
    // Register web session + session ping on sign-in events (OAuth, page refresh)
    if (user != null && data.event.name == 'signedIn') {
      final notifier = ref.read(authProvider.notifier);
      notifier.setUser(user); // also starts session ping
      notifier.registerWebSession();
    }
    return AuthState(user: user);
  });
});
