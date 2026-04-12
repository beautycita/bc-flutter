import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:beautycita/providers/user_preferences_provider.dart';
import '../helpers/test_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('UserPrefsState', () {
    test('default values are correct', () {
      const state = UserPrefsState();

      expect(state.defaultTransport, 'car');
      expect(state.notificationsEnabled, isTrue);
      expect(state.notifyBookingReminders, isTrue);
      expect(state.notifyPromotions, isTrue);
      expect(state.notifyMessages, isTrue);
      expect(state.notifyAppointmentUpdates, isTrue);
      expect(state.searchRadiusKm, 50);
      expect(state.priceComfort, 'moderate');
      expect(state.qualitySpeed, 0.7);
      expect(state.exploreLoyalty, 0.3);
      expect(state.onboardingComplete, isFalse);
      expect(state.reduceAnimations, isTrue);
    });

    group('copyWith', () {
      test('updates defaultTransport', () {
        const state = UserPrefsState();
        final updated = state.copyWith(defaultTransport: 'uber');

        expect(updated.defaultTransport, 'uber');
        expect(updated.notificationsEnabled, isTrue); // unchanged
      });

      test('updates notification toggles', () {
        const state = UserPrefsState();
        final updated = state.copyWith(
          notificationsEnabled: false,
          notifyBookingReminders: false,
          notifyPromotions: false,
        );

        expect(updated.notificationsEnabled, isFalse);
        expect(updated.notifyBookingReminders, isFalse);
        expect(updated.notifyPromotions, isFalse);
        expect(updated.notifyMessages, isTrue); // unchanged
      });

      test('updates search radius', () {
        const state = UserPrefsState();
        final updated = state.copyWith(searchRadiusKm: 100);
        expect(updated.searchRadiusKm, 100);
      });

      test('updates price comfort', () {
        const state = UserPrefsState();
        final updated = state.copyWith(priceComfort: 'premium');
        expect(updated.priceComfort, 'premium');
      });

      test('updates quality/speed slider', () {
        const state = UserPrefsState();
        final updated = state.copyWith(qualitySpeed: 0.2);
        expect(updated.qualitySpeed, 0.2);
      });

      test('updates explore/loyalty slider', () {
        const state = UserPrefsState();
        final updated = state.copyWith(exploreLoyalty: 0.9);
        expect(updated.exploreLoyalty, 0.9);
      });

      test('updates onboarding complete', () {
        const state = UserPrefsState();
        final updated = state.copyWith(onboardingComplete: true);
        expect(updated.onboardingComplete, isTrue);
      });

      test('updates reduceAnimations', () {
        const state = UserPrefsState();
        final updated = state.copyWith(reduceAnimations: true);
        expect(updated.reduceAnimations, isTrue);
        // other fields unchanged
        expect(updated.defaultTransport, 'car');
        expect(updated.notificationsEnabled, isTrue);
      });

      test('reduceAnimations defaults to false in copyWith', () {
        const state = UserPrefsState(reduceAnimations: true);
        // copyWith without specifying reduceAnimations keeps existing value
        final updated = state.copyWith(defaultTransport: 'uber');
        expect(updated.reduceAnimations, isTrue);
      });
    });
  });

  group('UserPrefsNotifier', () {
    late MockUserPreferences mockPrefs;
    late UserPrefsNotifier notifier;

    setUp(() {
      mockPrefs = MockUserPreferences();
      // Configure mocks for loadFromServer and all getters
      when(() => mockPrefs.loadFromServer()).thenAnswer((_) async {});
      when(() => mockPrefs.getDefaultTransport()).thenAnswer((_) async => 'car');
      when(() => mockPrefs.getNotificationsEnabled()).thenAnswer((_) async => true);
      when(() => mockPrefs.getNotifyBookingReminders()).thenAnswer((_) async => true);
      when(() => mockPrefs.getNotifyPromotions()).thenAnswer((_) async => true);
      when(() => mockPrefs.getNotifyMessages()).thenAnswer((_) async => true);
      when(() => mockPrefs.getNotifyAppointmentUpdates()).thenAnswer((_) async => true);
      when(() => mockPrefs.getSearchRadius()).thenAnswer((_) async => 50);
      when(() => mockPrefs.getPriceComfort()).thenAnswer((_) async => 'moderate');
      when(() => mockPrefs.getQualitySpeed()).thenAnswer((_) async => 0.7);
      when(() => mockPrefs.getExploreLoyalty()).thenAnswer((_) async => 0.3);
      when(() => mockPrefs.getOnboardingComplete()).thenAnswer((_) async => false);
      when(() => mockPrefs.getBool(any(), defaultValue: any(named: 'defaultValue')))
          .thenAnswer((_) async => false);

      notifier = UserPrefsNotifier(mockPrefs);
    });

    tearDown(() {
      notifier.dispose();
    });

    test('loads prefs from server on creation', () async {
      await Future<void>.delayed(Duration.zero);
      verify(() => mockPrefs.loadFromServer()).called(1);
    });

    group('setDefaultTransport', () {
      test('updates state and persists', () async {
        when(() => mockPrefs.setDefaultTransport(any()))
            .thenAnswer((_) async {});

        await notifier.setDefaultTransport('uber');

        expect(notifier.state.defaultTransport, 'uber');
        verify(() => mockPrefs.setDefaultTransport('uber')).called(1);
      });
    });

    group('toggleNotifications', () {
      test('toggles from true to false', () async {
        await Future<void>.delayed(Duration.zero); // let _load finish
        when(() => mockPrefs.setNotificationsEnabled(any()))
            .thenAnswer((_) async {});

        await notifier.toggleNotifications();

        expect(notifier.state.notificationsEnabled, isFalse);
        verify(() => mockPrefs.setNotificationsEnabled(false)).called(1);
      });
    });

    group('toggleBookingReminders', () {
      test('toggles from true to false', () async {
        await Future<void>.delayed(Duration.zero);
        when(() => mockPrefs.setBool(any(), any()))
            .thenAnswer((_) async {});

        await notifier.toggleBookingReminders();

        expect(notifier.state.notifyBookingReminders, isFalse);
      });
    });

    group('setSearchRadius', () {
      test('updates radius', () async {
        when(() => mockPrefs.setSearchRadius(any()))
            .thenAnswer((_) async {});

        await notifier.setSearchRadius(100);

        expect(notifier.state.searchRadiusKm, 100);
        verify(() => mockPrefs.setSearchRadius(100)).called(1);
      });
    });

    group('setPriceComfort', () {
      test('updates price comfort', () async {
        when(() => mockPrefs.setPriceComfort(any()))
            .thenAnswer((_) async {});

        await notifier.setPriceComfort('premium');

        expect(notifier.state.priceComfort, 'premium');
      });
    });

    group('setQualitySpeed', () {
      test('updates quality/speed slider', () async {
        when(() => mockPrefs.setQualitySpeed(any()))
            .thenAnswer((_) async {});

        await notifier.setQualitySpeed(0.9);

        expect(notifier.state.qualitySpeed, 0.9);
      });
    });

    group('setOnboardingComplete', () {
      test('marks onboarding as complete', () async {
        when(() => mockPrefs.setOnboardingComplete(any()))
            .thenAnswer((_) async {});

        await notifier.setOnboardingComplete(true);

        expect(notifier.state.onboardingComplete, isTrue);
      });
    });

    group('toggleReduceAnimations', () {
      test('toggles from false to true', () async {
        await Future<void>.delayed(Duration.zero); // let _load finish
        when(() => mockPrefs.setBool(any(), any()))
            .thenAnswer((_) async {});

        expect(notifier.state.reduceAnimations, isFalse);
        await notifier.toggleReduceAnimations();

        expect(notifier.state.reduceAnimations, isTrue);
      });

      test('toggles from true back to false', () async {
        await Future<void>.delayed(Duration.zero);
        when(() => mockPrefs.setBool(any(), any()))
            .thenAnswer((_) async {});

        await notifier.toggleReduceAnimations(); // false → true
        await notifier.toggleReduceAnimations(); // true → false

        expect(notifier.state.reduceAnimations, isFalse);
      });
    });
  });
}
