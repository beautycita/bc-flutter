// Tests for the pure, non-Supabase surface of contact_match_provider.
//
// The notifier (ContactMatchNotifier) hard-codes `ContactMatchService()` in
// its provider wiring and the service methods hit Supabase / platform
// channels — those belong in a live flow test, not here. This file pins the
// two pieces that are pure and user-facing:
//
//   - ContactMatchState: default construction + copyWith transitions
//     (idle → requesting → scanning → loaded | denied | error), plus the
//     `clearError` semantics which are easy to get wrong.
//   - EnrichedMatch: the getters that switch on salonType ('d' discovered
//     vs 'r' registered) — different column names on each side.
//
// Regression risk: the discovered/registered schema divergence (business_name
// vs name, location_city vs city, feature_image_url vs photo_url,
// rating_average vs average_rating) is the exact shape of bug that could
// silently render empty cards if a future refactor pulled from the wrong key.

import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita/providers/contact_match_provider.dart';

void main() {
  group('ContactMatchState', () {
    test('default state is idle, empty matches, no error', () {
      const state = ContactMatchState();
      expect(state.step, ContactMatchStep.idle);
      expect(state.matches, isEmpty);
      expect(state.error, isNull);
    });

    test('copyWith transitions idle → requesting preserving other fields', () {
      const state = ContactMatchState();
      final next = state.copyWith(step: ContactMatchStep.requesting);
      expect(next.step, ContactMatchStep.requesting);
      expect(next.matches, isEmpty);
      expect(next.error, isNull);
    });

    test('copyWith with matches replaces list, keeps step unless set', () {
      const state = ContactMatchState(step: ContactMatchStep.scanning);
      final match = EnrichedMatch(
        contactName: 'Maria',
        salon: const {'id': 'r-1', 'name': 'Salon Uno'},
        salonType: 'r',
        matchedPhone: '+523221234567',
      );
      final next = state.copyWith(matches: [match]);
      expect(next.step, ContactMatchStep.scanning);
      expect(next.matches.length, 1);
      expect(next.matches.first.contactName, 'Maria');
    });

    test('copyWith sets error AND step together (typical error path)', () {
      const state = ContactMatchState(step: ContactMatchStep.scanning);
      final next = state.copyWith(
        step: ContactMatchStep.error,
        error: 'network down',
      );
      expect(next.step, ContactMatchStep.error);
      expect(next.error, 'network down');
    });

    test('copyWith with clearError: true wipes error even if error arg set',
        () {
      const state = ContactMatchState(
        step: ContactMatchStep.error,
        error: 'prior',
      );
      final next = state.copyWith(
        step: ContactMatchStep.requesting,
        error: 'ignored',
        clearError: true,
      );
      expect(next.step, ContactMatchStep.requesting);
      expect(next.error, isNull);
    });

    test('copyWith without error arg preserves existing error', () {
      // Important: copyWith must NOT accidentally null out the error on a
      // plain step change — the error survives until explicitly cleared.
      const state = ContactMatchState(
        step: ContactMatchStep.error,
        error: 'kept',
      );
      final next = state.copyWith(step: ContactMatchStep.scanning);
      expect(next.error, 'kept');
    });
  });

  group('EnrichedMatch getters (discovered salon, type=d)', () {
    final m = EnrichedMatch(
      contactName: 'Contact D',
      salon: const {
        'id': 'd-1',
        'business_name': 'Descubierto Salon',
        'location_city': 'Puerto Vallarta',
        'feature_image_url': 'https://img.example/d.png',
        'rating_average': 4.5,
      },
      salonType: 'd',
      matchedPhone: '+523221111111',
    );

    test('salonId / salonName / salonCity / salonPhoto / salonRating read '
        'discovered-shape columns', () {
      expect(m.salonId, 'd-1');
      expect(m.salonName, 'Descubierto Salon');
      expect(m.salonCity, 'Puerto Vallarta');
      expect(m.salonPhoto, 'https://img.example/d.png');
      expect(m.salonRating, 4.5);
    });
  });

  group('EnrichedMatch getters (registered business, type=r)', () {
    final m = EnrichedMatch(
      contactName: 'Contact R',
      salon: const {
        'id': 'r-1',
        'name': 'Registrado Salon',
        'city': 'Guadalajara',
        'photo_url': 'https://img.example/r.png',
        'average_rating': 4.8,
      },
      salonType: 'r',
      matchedPhone: '+523339999999',
    );

    test('salonId / salonName / salonCity / salonPhoto / salonRating read '
        'registered-shape columns', () {
      expect(m.salonId, 'r-1');
      expect(m.salonName, 'Registrado Salon');
      expect(m.salonCity, 'Guadalajara');
      expect(m.salonPhoto, 'https://img.example/r.png');
      expect(m.salonRating, 4.8);
    });

    test('rating as int (not double) still returns a double', () {
      // Postgres numerics come through as num; the getter must cast.
      final withIntRating = EnrichedMatch(
        contactName: 'x',
        salon: const {'id': 'r-2', 'name': 'X', 'average_rating': 5},
        salonType: 'r',
        matchedPhone: '+523330000000',
      );
      expect(withIntRating.salonRating, 5.0);
      expect(withIntRating.salonRating, isA<double>());
    });
  });
}
