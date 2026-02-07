import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/services/supabase_client.dart';
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
      state = state.copyWith(
        isLoading: false,
        error: 'Error al verificar registro: ${e.toString()}',
      );
    }
  }

  /// Register a new user with biometric authentication
  Future<bool> register() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Check if biometric is available
      final isAvailable = await _biometricService.isBiometricAvailable();

      if (!isAvailable) {
        state = state.copyWith(
          isLoading: false,
          error: 'Tu dispositivo no tiene biometría disponible',
        );
        return false;
      }

      // Authenticate with biometric
      final authenticated = await _biometricService.authenticate();

      if (!authenticated) {
        state = state.copyWith(
          isLoading: false,
          error: 'Autenticación biométrica fallida',
        );
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
      state = state.copyWith(
        isLoading: false,
        error: 'Error al registrar: ${e.toString()}',
      );
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
        state = state.copyWith(
          isLoading: false,
          error: 'Usuario no registrado',
        );
        return false;
      }

      // Authenticate with biometric
      final authenticated = await _biometricService.authenticate();

      if (!authenticated) {
        state = state.copyWith(
          isLoading: false,
          error: 'Autenticación biométrica fallida',
        );
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
      state = state.copyWith(
        isLoading: false,
        error: 'Error al iniciar sesión: ${e.toString()}',
      );
      return false;
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
      state = state.copyWith(
        isLoading: false,
        error: 'Error al cerrar sesión: ${e.toString()}',
      );
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
