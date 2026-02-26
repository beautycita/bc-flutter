import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:beautycita_core/supabase.dart';

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
  Future<String?> getUserRole() async {
    if (!BCSupabase.isInitialized || state.user == null) return null;
    try {
      final data = await BCSupabase.client
          .from('profiles')
          .select('role')
          .eq('id', state.user!.id)
          .maybeSingle();
      return data?['role'] as String?;
    } catch (e) {
      debugPrint('getUserRole error: $e');
      return null;
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
final authStateStreamProvider = StreamProvider<AuthState>((ref) {
  if (!BCSupabase.isInitialized) {
    return Stream.value(const AuthState());
  }
  return BCSupabase.client.auth.onAuthStateChange.map((data) {
    return AuthState(user: data.session?.user);
  });
});
