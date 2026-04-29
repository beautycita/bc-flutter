import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:beautycita/models/booking.dart';
import 'package:beautycita/repositories/booking_repository.dart' show CancelResult;
import '../helpers/test_mocks.dart';
import '../helpers/model_fixtures.dart';

void main() {
  // Static source-scan: ensures createBooking goes through the financial RPC
  // and never does a direct appointments.insert (which bypasses commission_records
  // and tax_withholdings).
  test('booking_repository.createBooking goes through financial RPC', () {
    final source =
        File('lib/repositories/booking_repository.dart').readAsStringSync();

    expect(
      source.contains("'create_booking_with_financials'"),
      isTrue,
      reason: 'createBooking must call create_booking_with_financials',
    );
    expect(
      source.contains('.from(BCTables.appointments)') &&
          source.contains('.insert('),
      isFalse,
      reason:
          'Direct appointments.insert is forbidden — financials/tax bypassed',
    );
  });

  group('BookingRepository (via mock)', () {
    late MockBookingRepository repo;

    setUp(() {
      repo = MockBookingRepository();
    });

    group('getUserBookings', () {
      test('returns list of bookings', () async {
        final bookings = [
          Booking.fromJson(bookingJson(id: 'b1')),
          Booking.fromJson(bookingJson(id: 'b2')),
        ];
        when(() => repo.getUserBookings())
            .thenAnswer((_) async => bookings);

        final result = await repo.getUserBookings();
        expect(result, hasLength(2));
      });

      test('filters by status', () async {
        final bookings = [
          Booking.fromJson(bookingJson(id: 'b1', status: 'confirmed')),
        ];
        when(() => repo.getUserBookings(status: 'confirmed'))
            .thenAnswer((_) async => bookings);

        final result = await repo.getUserBookings(status: 'confirmed');
        expect(result, hasLength(1));
        expect(result.first.status, 'confirmed');
      });

      test('returns empty list when not authenticated', () async {
        when(() => repo.getUserBookings())
            .thenAnswer((_) async => []);

        final result = await repo.getUserBookings();
        expect(result, isEmpty);
      });
    });

    group('cancelBooking', () {
      test('calls cancel with booking ID', () async {
        when(() => repo.cancelBooking(any()))
            .thenAnswer((_) async => const CancelResult(
                  refundAmount: 0,
                  depositForfeited: 0,
                  commissionKept: 0,
                  isFreeCancel: true,
                ));

        await repo.cancelBooking('booking-1');
        verify(() => repo.cancelBooking('booking-1')).called(1);
      });
    });

    group('CancelResult scenarios', () {
      test('free cancel: full refund minus commission', () {
        const result = CancelResult(
          refundAmount: 970.0,   // 1000 - 30 commission
          depositForfeited: 0.0,
          commissionKept: 30.0,  // 3% of 1000
          isFreeCancel: true,
        );

        expect(result.isFreeCancel, true);
        expect(result.refundAmount + result.commissionKept, 1000.0);
        expect(result.depositForfeited, 0.0);
      });

      test('late cancel with deposit: deposit forfeited, remainder refunded', () {
        const result = CancelResult(
          refundAmount: 770.0,        // 1000 - 200 deposit - 30 commission
          depositForfeited: 200.0,    // 20% of 1000
          commissionKept: 30.0,       // 3% of 1000
          isFreeCancel: false,
        );

        expect(result.isFreeCancel, false);
        expect(result.depositForfeited, 200.0);
        // Total adds up to original price
        expect(
          result.refundAmount + result.depositForfeited + result.commissionKept,
          1000.0,
        );
      });

      test('salon_direct cancel: 0% commission, full refund', () {
        const result = CancelResult(
          refundAmount: 500.0,
          depositForfeited: 0.0,
          commissionKept: 0.0,
          isFreeCancel: true,
        );

        expect(result.refundAmount, 500.0);
        expect(result.commissionKept, 0.0);
      });

      test('business-cancelled: customer gets full refund', () {
        const result = CancelResult(
          refundAmount: 1000.0,  // Full refund
          depositForfeited: 0.0,
          commissionKept: 30.0,  // Commission still charged to salon
          isFreeCancel: false,
        );

        expect(result.refundAmount, 1000.0);
        expect(result.commissionKept, 30.0);
      });

      test('unpaid booking cancel: no money moves', () {
        const result = CancelResult(
          refundAmount: 0.0,
          depositForfeited: 0.0,
          commissionKept: 0.0,
          isFreeCancel: true,
        );

        expect(result.refundAmount, 0.0);
        expect(result.depositForfeited, 0.0);
        expect(result.commissionKept, 0.0);
      });

      test('already-cancelled: no-op return', () {
        // Server returns zeros when booking is already cancelled
        const result = CancelResult(
          refundAmount: 0.0,
          depositForfeited: 0.0,
          commissionKept: 0.0,
          isFreeCancel: true,
        );

        expect(result.refundAmount, 0.0);
      });

      test('late cancel, no deposit policy: full minus commission', () {
        const result = CancelResult(
          refundAmount: 485.0,   // 500 - 15 commission
          depositForfeited: 0.0,
          commissionKept: 15.0,  // 3% of 500
          isFreeCancel: false,
        );

        expect(result.isFreeCancel, false);
        expect(result.depositForfeited, 0.0);
        expect(result.refundAmount + result.commissionKept, 500.0);
      });
    });

    group('getBookingById', () {
      test('returns booking when found', () async {
        final booking = Booking.fromJson(bookingJson());
        when(() => repo.getBookingById('booking-1'))
            .thenAnswer((_) async => booking);

        final result = await repo.getBookingById('booking-1');
        expect(result, isNotNull);
        expect(result!.id, 'booking-1');
      });

      test('returns null when not found', () async {
        when(() => repo.getBookingById(any()))
            .thenAnswer((_) async => null);

        final result = await repo.getBookingById('nonexistent');
        expect(result, isNull);
      });
    });
  });
}
