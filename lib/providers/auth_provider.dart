import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  /// Register a new user with biometric authentication
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
      final username = UsernameGenerator.generateUsernameWithSuffix();

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

  /// Login with biometric authentication
  Future<bool> login() async {
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

  /// Update the username in local session and state
  Future<void> updateUsername(String username) async {
    final prefs = await _userSession.getUsername(); // verify session exists
    if (prefs == null) return;
    // Update SharedPreferences directly
    final sp = await SharedPreferences.getInstance();
    await sp.setString('username', username);
    state = state.copyWith(username: username);
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
