import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException, OAuthProvider, UserAttributes;
import 'package:beautycita/services/supabase_client.dart';
import 'package:beautycita/services/toast_service.dart';
import '../services/biometric_service.dart';
import '../services/user_session.dart';
import '../services/username_generator.dart';

/// Authentication state model
class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? username;
  final String? error;

  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.username,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? username,
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      username: username ?? this.username,
      error: error,
    );
  }
}

/// Authentication state notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final BiometricService _biometricService;
  final UserSession _userSession;
  final UsernameGenerator _usernameGenerator;

  DateTime? _lastLoginAttempt;
  int _loginAttempts = 0;

  AuthNotifier({
    required BiometricService biometricService,
    required UserSession userSession,
    required UsernameGenerator usernameGenerator,
  })  : _biometricService = biometricService,
        _userSession = userSession,
        _usernameGenerator = usernameGenerator,
        super(const AuthState());

  /// Check if user is already registered
  Future<void> checkRegistration() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final isRegistered = await _userSession.isRegistered();

      if (isRegistered) {
        final username = await _userSession.getUsername();
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          username: username,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: false,
        );
      }
    } catch (e) {
      final msg = 'Error al verificar registro';
      ToastService.showError(msg);
      state = state.copyWith(isLoading: false, error: msg);
    }
  }

  /// Register a new user with biometric authentication.
  /// [fullName] and [phone] are collected before biometric in the auth screen.
  Future<bool> register() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Check if biometric is available
      final isAvailable = await _biometricService.isBiometricAvailable();

      if (!isAvailable) {
        const msg = 'Tu dispositivo no tiene biometria disponible';
        ToastService.showError(msg);
        state = state.copyWith(isLoading: false, error: msg);
        return false;
      }

      // Authenticate with biometric
      final authenticated = await _biometricService.authenticate();

      if (!authenticated) {
        const msg = 'Autenticacion biometrica fallida';
        ToastService.showError(msg);
        state = state.copyWith(isLoading: false, error: msg);
        return false;
      }

      // Generate username
      final username = UsernameGenerator.generateUsername();

      // Create anonymous Supabase session
      await _userSession.ensureSupabaseSession();

      // Save to local session (also stores Supabase user ID)
      await _userSession.register(username);

      // Update state
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        username: username,
      );

      return true;
    } catch (e) {
      final msg = ToastService.friendlyError(e);
      ToastService.showError(msg);
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    }
  }

  /// Google One Tap — link Google identity + store discovered_email.
  /// Returns true if user selected an account and linked, false if dismissed.
  /// Same outcome as "Vincular Google" in Settings > Security.
  Future<bool> captureGoogleEmail() async {
    try {
      if (!SupabaseClientService.isInitialized) return false;

      final clientId = dotenv.env['GOOGLE_OAUTH_CLIENT_ID'];
      if (clientId == null || clientId.isEmpty) return false;

      final googleSignIn = GoogleSignIn(
        serverClientId: clientId,
      );

      final account = await googleSignIn.signIn();
      if (account == null) {
        debugPrint('[Auth] Google One Tap dismissed');
        return false;
      }

      final email = account.email;
      final googleAuth = await account.authentication;
      final idToken = googleAuth.idToken;

      // Store email as discovered_email metadata (always, even if link fails)
      await SupabaseClientService.client.auth.updateUser(
        UserAttributes(data: {'discovered_email': email}),
      );

      // Link Google identity to this account (same as Settings > Security)
      if (idToken != null) {
        try {
          await SupabaseClientService.client.auth.linkIdentityWithIdToken(
            provider: OAuthProvider.google,
            idToken: idToken,
            accessToken: googleAuth.accessToken,
          );
          debugPrint('[Auth] Google identity linked + email stored: $email');
        } on AuthException catch (e) {
          // Identity may already be linked to another user — still have the email
          debugPrint('[Auth] linkIdentity failed (email still stored): ${e.message}');
        }
      }

      await googleSignIn.disconnect();
      return true;
    } catch (e) {
      debugPrint('[Auth] Google capture failed (non-fatal): $e');
      return false;
    }
  }

  /// Login with biometric authentication
  Future<bool> login() async {
    // Rate limit: 3 second cooldown between attempts
    final now = DateTime.now();
    if (_lastLoginAttempt != null && now.difference(_lastLoginAttempt!) < const Duration(seconds: 3)) {
      state = state.copyWith(error: 'Espera un momento antes de intentar de nuevo');
      return false;
    }
    _lastLoginAttempt = now;

    // Exponential backoff after 5 failed attempts
    _loginAttempts++;
    if (_loginAttempts > 5) {
      final backoffSeconds = _loginAttempts * 5;
      state = state.copyWith(error: 'Demasiados intentos. Espera $backoffSeconds segundos.');
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Check if user is registered
      final isRegistered = await _userSession.isRegistered();

      if (!isRegistered) {
        const msg = 'Usuario no registrado';
        ToastService.showError(msg);
        state = state.copyWith(isLoading: false, error: msg);
        return false;
      }

      // Authenticate with biometric
      final authenticated = await _biometricService.authenticate();

      if (!authenticated) {
        const msg = 'Autenticacion biometrica fallida';
        ToastService.showError(msg);
        state = state.copyWith(isLoading: false, error: msg);
        return false;
      }

      // Load session
      final username = await _userSession.getUsername();
      await _userSession.updateLastLogin();

      // Restore or create Supabase session
      await _userSession.ensureSupabaseSession();

      // Update state
      _loginAttempts = 0;
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        username: username,
      );

      return true;
    } catch (e) {
      final msg = ToastService.friendlyError(e);
      ToastService.showError(msg);
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    }
  }

  /// Sign in with email and password (hidden dev/test login)
  Future<bool> signInWithEmail(String email, String password) async {
    // Rate limit: 3 second cooldown between attempts
    final now = DateTime.now();
    if (_lastLoginAttempt != null && now.difference(_lastLoginAttempt!) < const Duration(seconds: 3)) {
      state = state.copyWith(error: 'Espera un momento antes de intentar de nuevo');
      return false;
    }
    _lastLoginAttempt = now;

    // Exponential backoff after 5 failed attempts
    _loginAttempts++;
    if (_loginAttempts > 5) {
      final backoffSeconds = _loginAttempts * 5;
      state = state.copyWith(error: 'Demasiados intentos. Espera $backoffSeconds segundos.');
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await SupabaseClientService.client.auth
          .signInWithPassword(email: email, password: password);
      if (response.user == null) {
        const msg = 'Credenciales incorrectas';
        ToastService.showError(msg);
        state = state.copyWith(isLoading: false, error: msg);
        return false;
      }
      final displayName =
          response.user!.userMetadata?['full_name'] as String? ??
              response.user!.email?.split('@')[0] ??
              'user';
      await _userSession.saveSupabaseUserId(response.user!.id);
      if (!await _userSession.isRegistered()) {
        await _userSession.register(displayName);
      }
      await _userSession.updateLastLogin();
      final username = await _userSession.getUsername();
      _loginAttempts = 0;
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        username: username,
      );
      return true;
    } catch (e) {
      final msg = ToastService.friendlyError(e);
      ToastService.showError(msg);
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    }
  }

  /// Register with email and password (hidden alternative auth)
  Future<bool> signUpWithEmail(String email, String password) async {
    // Rate limit: 3 second cooldown between attempts
    final now = DateTime.now();
    if (_lastLoginAttempt != null &&
        now.difference(_lastLoginAttempt!) < const Duration(seconds: 3)) {
      state = state.copyWith(
          error: 'Espera un momento antes de intentar de nuevo');
      return false;
    }
    _lastLoginAttempt = now;

    _loginAttempts++;
    if (_loginAttempts > 5) {
      final backoffSeconds = _loginAttempts * 5;
      state = state.copyWith(
          error: 'Demasiados intentos. Espera $backoffSeconds segundos.');
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await SupabaseClientService.client.auth
          .signUp(email: email, password: password);
      if (response.user == null) {
        const msg = 'No se pudo crear la cuenta';
        state = state.copyWith(isLoading: false, error: msg);
        return false;
      }
      final displayName = response.user!.email?.split('@')[0] ?? 'user';
      await _userSession.saveSupabaseUserId(response.user!.id);
      await _userSession.register(displayName);
      await _userSession.updateLastLogin();
      final username = await _userSession.getUsername();
      _loginAttempts = 0;
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        username: username,
      );
      return true;
    } catch (e) {
      final msg = ToastService.friendlyError(e);
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    }
  }

  /// Update the username in local session, state, and Supabase profiles
  Future<void> updateUsername(String username) async {
    final prefs = await _userSession.getUsername(); // verify session exists
    if (prefs == null) return;
    // Update SharedPreferences directly
    final sp = await SharedPreferences.getInstance();
    await sp.setString('username', username);
    state = state.copyWith(username: username);
    // Sync to Supabase profiles table
    if (SupabaseClientService.isInitialized && SupabaseClientService.isAuthenticated) {
      final supaId = SupabaseClientService.client.auth.currentUser?.id;
      if (supaId != null) {
        try {
          await SupabaseClientService.client
              .from('profiles')
              .update({'username': username})
              .eq('id', supaId);
        } catch (_) {}
      }
    }
  }

  /// Logout and clear session
  Future<void> logout() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _userSession.clear();

      state = const AuthState(
        isLoading: false,
        isAuthenticated: false,
      );
    } catch (e) {
      final msg = ToastService.friendlyError(e);
      ToastService.showError(msg);
      state = state.copyWith(isLoading: false, error: msg);
    }
  }
}

/// Provider for BiometricService
final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

/// Provider for UserSession
final userSessionProvider = Provider<UserSession>((ref) {
  return UserSession();
});

/// Provider for UsernameGenerator
final usernameGeneratorProvider = Provider<UsernameGenerator>((ref) {
  return UsernameGenerator();
});

/// Provider for auth state
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    biometricService: ref.watch(biometricServiceProvider),
    userSession: ref.watch(userSessionProvider),
    usernameGenerator: ref.watch(usernameGeneratorProvider),
  );
});
