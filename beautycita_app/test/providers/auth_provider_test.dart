import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:beautycita/providers/auth_provider.dart';
import '../helpers/test_mocks.dart';
import '../helpers/test_helpers.dart';
import 'package:beautycita/services/username_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('AuthState', () {
    test('default is not loading, not authenticated', () {
      const state = AuthState();

      expect(state.isLoading, isFalse);
      expect(state.isAuthenticated, isFalse);
      expect(state.username, isNull);
      expect(state.error, isNull);
    });

    test('copyWith updates specified fields', () {
      const state = AuthState();
      final updated = state.copyWith(
        isLoading: true,
        isAuthenticated: true,
        username: 'velvetRose42',
      );

      expect(updated.isLoading, isTrue);
      expect(updated.isAuthenticated, isTrue);
      expect(updated.username, 'velvetRose42');
    });

    test('copyWith clears error when not passed', () {
      const state = AuthState(error: 'some error');
      final updated = state.copyWith(isLoading: true);

      // error parameter defaults to null in copyWith, which clears it
      expect(updated.error, isNull);
    });
  });

  group('AuthNotifier', () {
    late MockBiometricService mockBio;
    late MockUserSession mockSession;
    late AuthNotifier notifier;

    setUp(() {
      mockBio = MockBiometricService();
      mockSession = MockUserSession();
      setUpSupabaseTestClient();

      notifier = AuthNotifier(
        biometricService: mockBio,
        userSession: mockSession,
        usernameGenerator: UsernameGenerator(),
      );
    });

    tearDown(() {
      notifier.dispose();
      tearDownSupabase();
    });

    group('checkRegistration', () {
      test('sets authenticated when already registered', () async {
        when(() => mockSession.isRegistered()).thenAnswer((_) async => true);
        when(() => mockSession.ensureSupabaseSession()).thenAnswer((_) async => true);
        when(() => mockSession.getUsername()).thenAnswer((_) async => 'velvetRose42');

        await notifier.checkRegistration();

        expect(notifier.state.isAuthenticated, isTrue);
        expect(notifier.state.username, 'velvetRose42');
        expect(notifier.state.isLoading, isFalse);
      });

      test('sets not authenticated when not registered', () async {
        when(() => mockSession.isRegistered()).thenAnswer((_) async => false);

        await notifier.checkRegistration();

        expect(notifier.state.isAuthenticated, isFalse);
        expect(notifier.state.isLoading, isFalse);
      });

      test('handles errors', () async {
        when(() => mockSession.isRegistered()).thenThrow(Exception('DB error'));

        await notifier.checkRegistration();

        expect(notifier.state.isLoading, isFalse);
        expect(notifier.state.error, isNotNull);
      });
    });

    group('register', () {
      test('succeeds with biometric auth', () async {
        when(() => mockBio.isBiometricAvailable()).thenAnswer((_) async => true);
        when(() => mockBio.authenticate()).thenAnswer((_) async => true);
        when(() => mockSession.ensureSupabaseSession()).thenAnswer((_) async => true);
        when(() => mockSession.register(any())).thenAnswer((_) async {});

        final result = await notifier.register();

        expect(result, isTrue);
        expect(notifier.state.isAuthenticated, isTrue);
        expect(notifier.state.username, isNotNull);
        expect(notifier.state.username, isNotEmpty);
      });

      test('fails when biometric not available', () async {
        when(() => mockBio.isBiometricAvailable()).thenAnswer((_) async => false);

        final result = await notifier.register();

        expect(result, isFalse);
        expect(notifier.state.isAuthenticated, isFalse);
        expect(notifier.state.error, isNotNull);
      });

      test('fails when biometric auth fails', () async {
        when(() => mockBio.isBiometricAvailable()).thenAnswer((_) async => true);
        when(() => mockBio.authenticate()).thenAnswer((_) async => false);

        final result = await notifier.register();

        expect(result, isFalse);
        expect(notifier.state.isAuthenticated, isFalse);
      });
    });

    group('login', () {
      test('succeeds with biometric auth', () async {
        when(() => mockSession.isRegistered()).thenAnswer((_) async => true);
        when(() => mockBio.authenticate()).thenAnswer((_) async => true);
        when(() => mockSession.getUsername()).thenAnswer((_) async => 'velvetRose42');
        when(() => mockSession.updateLastLogin()).thenAnswer((_) async {});
        when(() => mockSession.ensureSupabaseSession()).thenAnswer((_) async => true);

        final result = await notifier.login();

        expect(result, isTrue);
        expect(notifier.state.isAuthenticated, isTrue);
        expect(notifier.state.username, 'velvetRose42');
      });

      test('fails when not registered', () async {
        when(() => mockSession.isRegistered()).thenAnswer((_) async => false);

        final result = await notifier.login();

        expect(result, isFalse);
        expect(notifier.state.error, isNotNull);
      });

      test('fails when biometric auth fails', () async {
        when(() => mockSession.isRegistered()).thenAnswer((_) async => true);
        when(() => mockBio.authenticate()).thenAnswer((_) async => false);

        final result = await notifier.login();

        expect(result, isFalse);
        expect(notifier.state.isAuthenticated, isFalse);
      });

      group('rate limiting', () {
        test('3-second cooldown between attempts', () async {
          when(() => mockSession.isRegistered()).thenAnswer((_) async => true);
          when(() => mockBio.authenticate()).thenAnswer((_) async => false);

          // First attempt
          await notifier.login();

          // Immediate second attempt — should be rate limited
          final result = await notifier.login();

          expect(result, isFalse);
          expect(notifier.state.error, contains('Espera'));
        });

        test('exponential backoff after 5 failed attempts', () async {
          when(() => mockSession.isRegistered()).thenAnswer((_) async => true);
          when(() => mockBio.authenticate()).thenAnswer((_) async => false);

          // Each call hits the 3-second cooldown (DateTime.now() can't be mocked).
          // Create a fresh notifier for each attempt so cooldown doesn't block,
          // but _loginAttempts is per-instance. Without DI for the clock,
          // we can only verify that the cooldown message is correct at the boundary.
          //
          // Verify: first attempt fails biometric, immediate retry shows cooldown.
          await notifier.login(); // attempt 1: fails biometric
          final result = await notifier.login(); // attempt 2: hits cooldown
          expect(result, isFalse);
          expect(notifier.state.error, contains('Espera'));
        },
        skip: 'Exponential backoff requires clock injection to test properly; '
              'cooldown behavior is verified in the test above');
      });
    });

    group('logout', () {
      test('clears session and state', () async {
        // First register
        when(() => mockBio.isBiometricAvailable()).thenAnswer((_) async => true);
        when(() => mockBio.authenticate()).thenAnswer((_) async => true);
        when(() => mockSession.ensureSupabaseSession()).thenAnswer((_) async => true);
        when(() => mockSession.register(any())).thenAnswer((_) async {});
        await notifier.register();

        expect(notifier.state.isAuthenticated, isTrue);

        // Now logout
        when(() => mockSession.clear()).thenAnswer((_) async {});
        await notifier.logout();

        expect(notifier.state.isAuthenticated, isFalse);
        expect(notifier.state.username, isNull);
        expect(notifier.state.isLoading, isFalse);
      });
    });
  });
}
