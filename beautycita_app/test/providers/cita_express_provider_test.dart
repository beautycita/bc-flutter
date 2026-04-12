import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:beautycita/models/curate_result.dart';
import 'package:beautycita/providers/cita_express_provider.dart';
import 'package:beautycita/repositories/booking_repository.dart';
import '../helpers/model_fixtures.dart';

class MockBookingRepository extends Mock implements BookingRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  // CitaExpressState
  // ---------------------------------------------------------------------------
  group('CitaExpressState', () {
    test('initial state has loading step', () {
      const state = CitaExpressState();
      expect(state.step, CitaExpressStep.loading);
      expect(state.businessId, '');
      expect(state.services, isEmpty);
      expect(state.selectedServiceId, isNull);
      expect(state.selectedResult, isNull);
      expect(state.bookingId, isNull);
      expect(state.error, isNull);
      expect(state.paymentMethod, 'cash_direct');
      expect(state.nearbyAlternatives, isNull);
    });

    test('copyWith updates step', () {
      const state = CitaExpressState();
      final updated = state.copyWith(step: CitaExpressStep.serviceSelect);
      expect(updated.step, CitaExpressStep.serviceSelect);
      // Other fields preserved
      expect(updated.businessId, '');
      expect(updated.paymentMethod, 'cash_direct');
    });

    test('copyWith updates businessId and services', () {
      const state = CitaExpressState();
      final services = [
        {'id': 'svc-1', 'name': 'Corte', 'is_active': true},
      ];
      final updated = state.copyWith(
        businessId: 'biz-1',
        services: services,
      );
      expect(updated.businessId, 'biz-1');
      expect(updated.services, hasLength(1));
    });

    test('copyWith clears error when null', () {
      final state = const CitaExpressState().copyWith(
        error: 'Some error',
      );
      expect(state.error, 'Some error');

      final cleared = state.copyWith(step: CitaExpressStep.serviceSelect);
      // error parameter defaults to null in copyWith, which sets error to null
      expect(cleared.error, isNull);
    });

    test('copyWith preserves selectedResult', () {
      final result = ResultCard.fromJson(resultCardJson());
      final state = const CitaExpressState().copyWith(
        selectedResult: result,
      );
      expect(state.selectedResult, isNotNull);
      expect(state.selectedResult!.rank, 1);

      // copyWith without selectedResult preserves it
      final updated = state.copyWith(step: CitaExpressStep.confirming);
      expect(updated.selectedResult, isNotNull);
    });

    test('copyWith updates paymentMethod', () {
      const state = CitaExpressState();
      final updated = state.copyWith(paymentMethod: 'saldo');
      expect(updated.paymentMethod, 'saldo');
    });
  });

  // ---------------------------------------------------------------------------
  // CitaExpressNotifier — pure state transitions
  // ---------------------------------------------------------------------------
  group('CitaExpressNotifier (pure state transitions)', () {
    late MockBookingRepository mockRepo;
    late CitaExpressNotifier notifier;

    setUp(() {
      mockRepo = MockBookingRepository();
      notifier = CitaExpressNotifier(mockRepo);
    });

    tearDown(() {
      notifier.dispose();
    });

    ResultCard _makeResult({int rank = 1, String businessId = 'biz-1'}) {
      return ResultCard.fromJson(resultCardJson(
        rank: rank,
        businessId: businessId,
      ));
    }

    CurateResponse _makeCurateResponse() {
      return CurateResponse.fromJson(curateResponseJson());
    }

    group('selectResult', () {
      test('transitions to confirming step', () {
        final result = _makeResult();
        notifier.selectResult(result);

        expect(notifier.state.step, CitaExpressStep.confirming);
        expect(notifier.state.selectedResult, isNotNull);
        expect(notifier.state.selectedResult!.rank, 1);
      });
    });

    group('backToServices', () {
      test('transitions to serviceSelect and clears result', () {
        final result = _makeResult();
        notifier.selectResult(result);
        expect(notifier.state.step, CitaExpressStep.confirming);
        expect(notifier.state.selectedResult, isNotNull);

        notifier.backToServices();

        expect(notifier.state.step, CitaExpressStep.serviceSelect);
        expect(notifier.state.selectedResult, isNull);
        expect(notifier.state.curateResponse, isNull);
      });
    });

    group('backToResults', () {
      test('goes to serviceSelect when no curateResponse', () {
        final result = _makeResult();
        notifier.selectResult(result);
        expect(notifier.state.step, CitaExpressStep.confirming);

        // No curateResponse was set → falls back to serviceSelect
        notifier.backToResults();
        expect(notifier.state.step, CitaExpressStep.serviceSelect);
        expect(notifier.state.selectedResult, isNull);
      });
    });

    group('setPaymentMethod', () {
      test('updates to saldo', () {
        notifier.setPaymentMethod('saldo');
        expect(notifier.state.paymentMethod, 'saldo');
      });

      test('updates to card', () {
        notifier.setPaymentMethod('card');
        expect(notifier.state.paymentMethod, 'card');
      });

      test('updates to cash_direct', () {
        notifier.setPaymentMethod('cash_direct');
        expect(notifier.state.paymentMethod, 'cash_direct');
      });

      test('updates to oxxo', () {
        notifier.setPaymentMethod('oxxo');
        expect(notifier.state.paymentMethod, 'oxxo');
      });
    });

    group('backToNoSlots', () {
      test('transitions to noSlotsToday, clears alternatives', () {
        notifier.backToNoSlots();

        expect(notifier.state.step, CitaExpressStep.noSlotsToday);
        expect(notifier.state.nearbyAlternatives, isNull);
      });
    });

    group('selectNearbyResult', () {
      test('transitions to confirming with selected result', () {
        final result = _makeResult(businessId: 'nearby-biz');
        notifier.selectNearbyResult(result);

        expect(notifier.state.step, CitaExpressStep.confirming);
        expect(notifier.state.selectedResult, isNotNull);
        expect(notifier.state.selectedResult!.business.id, 'nearby-biz');
      });
    });

    group('state machine flow simulation', () {
      test('service select → result select → confirm → back → back', () {
        // Start at loading (default)
        expect(notifier.state.step, CitaExpressStep.loading);

        // Select a result (simulating having gone through service select)
        final result = _makeResult();
        notifier.selectResult(result);
        expect(notifier.state.step, CitaExpressStep.confirming);

        // Set payment method
        notifier.setPaymentMethod('saldo');
        expect(notifier.state.paymentMethod, 'saldo');

        // Back to services — clears result and curateResponse
        notifier.backToServices();
        expect(notifier.state.step, CitaExpressStep.serviceSelect);
        expect(notifier.state.selectedResult, isNull);
      });

      test('nearby flow: no slots → nearby result → confirm → back', () {
        // Simulate no slots state
        notifier.backToNoSlots();
        expect(notifier.state.step, CitaExpressStep.noSlotsToday);

        // Select a nearby result
        final nearby = _makeResult(businessId: 'nearby-1');
        notifier.selectNearbyResult(nearby);
        expect(notifier.state.step, CitaExpressStep.confirming);
        expect(notifier.state.selectedResult!.business.id, 'nearby-1');

        // Back to services — clears everything
        notifier.backToServices();
        expect(notifier.state.step, CitaExpressStep.serviceSelect);
        expect(notifier.state.selectedResult, isNull);
      });
    });
  });

  // ---------------------------------------------------------------------------
  // CitaExpressStep enum coverage
  // ---------------------------------------------------------------------------
  group('CitaExpressStep enum', () {
    test('has all expected steps', () {
      expect(CitaExpressStep.values, containsAll([
        CitaExpressStep.loading,
        CitaExpressStep.serviceSelect,
        CitaExpressStep.searching,
        CitaExpressStep.results,
        CitaExpressStep.noSlotsToday,
        CitaExpressStep.futureResults,
        CitaExpressStep.confirming,
        CitaExpressStep.booking,
        CitaExpressStep.booked,
        CitaExpressStep.nearbySearching,
        CitaExpressStep.nearbyResults,
        CitaExpressStep.error,
      ]));
    });

    test('has 12 steps', () {
      expect(CitaExpressStep.values.length, 12);
    });
  });
}
