import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:beautycita/services/supabase_client.dart';
import 'package:beautycita/services/toast_service.dart';

class SecurityState {
  final bool isGoogleLinked;
  final bool isEmailAdded;
  final bool isEmailConfirmed;
  final bool hasPassword;
  final String? email;
  final bool isLoading;
  final String? error;
  final String? successMessage;

  const SecurityState({
    this.isGoogleLinked = false,
    this.isEmailAdded = false,
    this.isEmailConfirmed = false,
    this.hasPassword = false,
    this.email,
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  SecurityState copyWith({
    bool? isGoogleLinked,
    bool? isEmailAdded,
    bool? isEmailConfirmed,
    bool? hasPassword,
    String? email,
    bool? isLoading,
    String? error,
    String? successMessage,
  }) {
    return SecurityState(
      isGoogleLinked: isGoogleLinked ?? this.isGoogleLinked,
      isEmailAdded: isEmailAdded ?? this.isEmailAdded,
      isEmailConfirmed: isEmailConfirmed ?? this.isEmailConfirmed,
      hasPassword: hasPassword ?? this.hasPassword,
      email: email ?? this.email,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      successMessage: successMessage,
    );
  }
}

class SecurityNotifier extends StateNotifier<SecurityState> {
  static const _googleClientId =
      '925456539297-48gjim6slsnke7e9lc5h4ca9dhhpqb1e.apps.googleusercontent.com';

  SecurityNotifier() : super(const SecurityState()) {
    checkIdentities();
  }

  Future<void> checkIdentities() async {
    if (!SupabaseClientService.isInitialized) return;
    state = state.copyWith(isLoading: true, error: null, successMessage: null);

    try {
      // Refresh session to get latest user data (email confirmation status, etc.)
      try {
        await SupabaseClientService.client.auth.refreshSession();
      } catch (_) {
        // Non-fatal: use cached user if refresh fails
      }

      final user = SupabaseClientService.client.auth.currentUser;
      if (user == null) {
        state = const SecurityState();
        return;
      }

      final identities = user.identities ?? [];
      final hasGoogle = identities.any((id) => id.provider == 'google');
      final hasEmail = user.email != null && user.email!.isNotEmpty;
      final emailConfirmed = user.emailConfirmedAt != null;
      final hasEmailIdentity = identities.any((id) => id.provider == 'email');
      // Also check user_metadata flag (set when password added via updateUser on Google-first accounts)
      final metadataHasPassword = user.userMetadata?['has_password'] == true;

      state = SecurityState(
        isGoogleLinked: hasGoogle,
        isEmailAdded: hasEmail,
        isEmailConfirmed: emailConfirmed,
        hasPassword: hasEmailIdentity || metadataHasPassword,
        email: user.email,
      );
    } catch (e) {
      debugPrint('SecurityNotifier.checkIdentities error: $e');
      final msg = ToastService.friendlyError(e);
      ToastService.showError(msg);
      state = state.copyWith(isLoading: false, error: msg);
    }
  }

  /// Link Google OAuth to the current anonymous/existing session.
  Future<void> linkGoogle() async {
    if (!SupabaseClientService.isInitialized) return;
    state = state.copyWith(isLoading: true, error: null, successMessage: null);

    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: _googleClientId,
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled
        state = state.copyWith(isLoading: false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        const msg = 'No se pudo obtener el token de Google';
        ToastService.showError(msg);
        state = state.copyWith(isLoading: false, error: msg);
        return;
      }

      // Try linking to current session (preserves user ID + data)
      try {
        await SupabaseClientService.client.auth.linkIdentityWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: googleAuth.accessToken,
        );
        state = state.copyWith(
          isGoogleLinked: true,
          isLoading: false,
          email: googleUser.email,
          isEmailAdded: true,
          successMessage: 'Google vinculado exitosamente',
        );
      } on AuthException catch (e) {
        debugPrint('linkIdentityWithIdToken failed: ${e.message}');
        // Identity already linked to another user — fall back to sign in
        // This recovers the existing account (e.g., after app reinstall)
        await SupabaseClientService.client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: googleAuth.accessToken,
        );
        state = state.copyWith(
          isGoogleLinked: true,
          isLoading: false,
          email: googleUser.email,
          isEmailAdded: true,
          successMessage: 'Sesion recuperada con Google',
        );
      }
    } catch (e) {
      debugPrint('SecurityNotifier.linkGoogle error: $e');
      final msg = ToastService.friendlyError(e);
      ToastService.showError(msg);
      state = state.copyWith(isLoading: false, error: msg);
    }
  }

  /// Add email to the current user account.
  Future<void> addEmail(String email) async {
    if (!SupabaseClientService.isInitialized) return;
    state = state.copyWith(isLoading: true, error: null, successMessage: null);

    try {
      await SupabaseClientService.client.auth.updateUser(
        UserAttributes(email: email),
      );
      state = state.copyWith(
        isLoading: false,
        email: email,
        isEmailAdded: true,
        successMessage: 'Se envio un correo de confirmacion a $email',
      );
    } catch (e) {
      debugPrint('SecurityNotifier.addEmail error: $e');
      final msg = ToastService.friendlyError(e);
      ToastService.showError(msg);
      state = state.copyWith(isLoading: false, error: msg);
    }
  }

  /// Add password (requires verified email first).
  Future<void> addPassword(String password) async {
    if (!SupabaseClientService.isInitialized) return;
    if (!state.isEmailAdded) {
      const msg = 'Primero agrega tu email';
      ToastService.showError(msg);
      state = state.copyWith(error: msg);
      return;
    }
    if (!state.isEmailConfirmed) {
      const msg = 'Confirma tu email primero (revisa tu bandeja de entrada)';
      ToastService.showError(msg);
      state = state.copyWith(error: msg);
      return;
    }

    state = state.copyWith(isLoading: true, error: null, successMessage: null);

    try {
      await SupabaseClientService.client.auth.updateUser(
        UserAttributes(
          password: password,
          data: {'has_password': true},
        ),
      );
      state = state.copyWith(
        isLoading: false,
        hasPassword: true,
        successMessage: 'Contrasena configurada exitosamente',
      );
    } catch (e) {
      debugPrint('SecurityNotifier.addPassword error: $e');
      final msg = ToastService.friendlyError(e);
      ToastService.showError(msg);
      state = state.copyWith(isLoading: false, error: msg);
    }
  }

  void clearMessages() {
    state = state.copyWith(error: null, successMessage: null);
  }
}

final securityProvider =
    StateNotifierProvider<SecurityNotifier, SecurityState>((ref) {
  return SecurityNotifier();
});
