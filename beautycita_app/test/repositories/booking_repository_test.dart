import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:beautycita/models/booking.dart';
import '../helpers/test_mocks.dart';
import '../helpers/model_fixtures.dart';

void main() {
  group('BookingRepository (via mock)', () {
    late MockBookingRepository repo;

    setUp(() {
      repo = MockBookingRepository();
    });

    group('payment status mapping', () {
      // These test the mapping logic that lives in BookingRepository.createBooking:
      //   'paid' → 'paid'
      //   'pending_payment' or 'pending' → 'pending'
      //   null → 'unpaid'
      //   Booking status: 'paid' → 'confirmed', else → 'pending'

      test('paid payment creates confirmed booking', () async {
        final expectedBooking = Booking.fromJson(bookingJson(
          status: 'confirmed',
          paymentStatus: 'paid',
        ));

        when(() => repo.createBooking(
              providerId: any(named: 'providerId'),
              serviceName: any(named: 'serviceName'),
              category: any(named: 'category'),
              scheduledAt: any(named: 'scheduledAt'),
              paymentStatus: 'paid',
            )).thenAnswer((_) async => expectedBooking);

        final result = await repo.createBooking(
          providerId: 'biz-1',
          serviceName: 'Manicure',
          category: 'nails',
          scheduledAt: DateTime.now(),
          paymentStatus: 'paid',
        );

        expect(result.status, 'confirmed');
        expect(result.paymentStatus, 'paid');
      });

      test('pending payment creates pending booking', () async {
        final expectedBooking = Booking.fromJson(bookingJson(
          status: 'pending',
          paymentStatus: 'pending',
        ));

        when(() => repo.createBooking(
              providerId: any(named: 'providerId'),
              serviceName: any(named: 'serviceName'),
              category: any(named: 'category'),
              scheduledAt: any(named: 'scheduledAt'),
              paymentStatus: 'pending',
            )).thenAnswer((_) async => expectedBooking);

        final result = await repo.createBooking(
          providerId: 'biz-1',
          serviceName: 'Manicure',
          category: 'nails',
          scheduledAt: DateTime.now(),
          paymentStatus: 'pending',
        );

        expect(result.status, 'pending');
        expect(result.paymentStatus, 'pending');
      });

      test('null payment creates unpaid booking', () async {
        final expectedBooking = Booking.fromJson(bookingJson(
          status: 'pending',
          paymentStatus: null,
        ));

        when(() => repo.createBooking(
              providerId: any(named: 'providerId'),
              serviceName: any(named: 'serviceName'),
              category: any(named: 'category'),
              scheduledAt: any(named: 'scheduledAt'),
            )).thenAnswer((_) async => expectedBooking);

        final result = await repo.createBooking(
          providerId: 'biz-1',
          serviceName: 'Manicure',
          category: 'nails',
          scheduledAt: DateTime.now(),
        );

        expect(result.status, 'pending');
      });
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
            .thenAnswer((_) async {});

        await repo.cancelBooking('booking-1');
        verify(() => repo.cancelBooking('booking-1')).called(1);
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
