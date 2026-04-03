import 'dart:async';

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
      }
    }
  }

  /// Cached role to avoid repeated DB queries during navigation.
  String? _cachedRole;

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
  Future<String?> getUserRole() async {
    if (_cachedRole != null && state.user != null) return _cachedRole;
    if (!BCSupabase.isInitialized || state.user == null) return null;
    try {
      final data = await BCSupabase.client
          .from('profiles')
          .select('role')
          .eq('id', state.user!.id)
          .maybeSingle();
      _cachedRole = data?['role'] as String?;
      return _cachedRole;
    } catch (e) {
      debugPrint('getUserRole error: $e');
      return null;
    }
  }

  /// Set the authenticated user (e.g., after QR login).
  void setUser(User user) {
    state = state.copyWith(user: user, isLoading: false, clearError: true);
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
      if (sessionId != null) {
        _listenForRevocation(sessionId);
      }
      return sessionId;
    } catch (e) {
      debugPrint('registerWebSession error: $e');
      return null;
    }
  }

  /// Listen for session revocation from mobile device manager.
  void _listenForRevocation(String sessionId) {
    if (!BCSupabase.isInitialized) return;
    BCSupabase.client.channel('qr_revoke_$sessionId').onBroadcast(
      event: 'session_revoked',
      callback: (payload) {
        debugPrint('Session revoked by mobile device');
        signOut();
      },
    ).subscribe();
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
    // Register web session on sign-in events (OAuth, page refresh with session)
    if (user != null && data.event.name == 'signedIn') {
      ref.read(authProvider.notifier).registerWebSession();
    }
    return AuthState(user: user);
  });
});
