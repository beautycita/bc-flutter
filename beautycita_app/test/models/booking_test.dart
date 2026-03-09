import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita/models/booking.dart';
import '../helpers/model_fixtures.dart';

void main() {
  group('Booking', () {
    group('fromJson', () {
      test('parses all required fields', () {
        final json = bookingJson();
        final booking = Booking.fromJson(json);

        expect(booking.id, 'booking-1');
        expect(booking.userId, 'user-1');
        expect(booking.businessId, 'biz-1');
        expect(booking.serviceId, 'svc-1');
        expect(booking.serviceName, 'Manicure Gel');
        expect(booking.serviceType, 'manicure_gel');
        expect(booking.status, 'confirmed');
        expect(booking.price, 350.0);
        expect(booking.transportMode, 'car');
        expect(booking.paymentStatus, 'paid');
      });

      test('computes duration from starts_at and ends_at', () {
        final booking = Booking.fromJson(bookingJson(
          startsAt: '2026-03-10T14:00:00Z',
          endsAt: '2026-03-10T15:30:00Z',
        ));

        expect(booking.durationMinutes, 90);
      });

      test('defaults to 60 minutes when ends_at is null', () {
        final booking = Booking.fromJson(bookingJson(endsAt: null));

        expect(booking.durationMinutes, 60);
      });

      test('extracts provider name from nested businesses join', () {
        final booking = Booking.fromJson(bookingJson(
          businesses: {'name': 'Salon Rosa'},
        ));

        expect(booking.providerName, 'Salon Rosa');
      });

      test('extracts provider name from flat provider_name field', () {
        final booking = Booking.fromJson(bookingJson(
          providerName: 'Salon Azul',
        ));

        expect(booking.providerName, 'Salon Azul');
      });

      test('handles null optional fields', () {
        final booking = Booking.fromJson(bookingJson(
          serviceId: null,
          serviceType: null,
          price: null,
          notes: null,
          transportMode: null,
          paymentStatus: null,
          depositAmount: null,
          updatedAt: null,
        ));

        expect(booking.serviceId, isNull);
        expect(booking.serviceType, isNull);
        expect(booking.price, isNull);
        expect(booking.notes, isNull);
        expect(booking.transportMode, isNull);
        expect(booking.paymentStatus, isNull);
        expect(booking.depositAmount, isNull);
        expect(booking.updatedAt, isNull);
      });

      test('parses dates correctly', () {
        final booking = Booking.fromJson(bookingJson(
          startsAt: '2026-03-10T14:00:00Z',
          createdAt: '2026-03-05T10:00:00Z',
          updatedAt: '2026-03-06T12:00:00Z',
        ));

        expect(booking.scheduledAt, DateTime.utc(2026, 3, 10, 14));
        expect(booking.createdAt, DateTime.utc(2026, 3, 5, 10));
        expect(booking.updatedAt, DateTime.utc(2026, 3, 6, 12));
      });
    });

    group('toJson', () {
      test('round-trips through fromJson', () {
        final original = bookingJson();
        final booking = Booking.fromJson(original);
        final json = booking.toJson();

        expect(json['id'], 'booking-1');
        expect(json['user_id'], 'user-1');
        expect(json['business_id'], 'biz-1');
        expect(json['service_name'], 'Manicure Gel');
        expect(json['status'], 'confirmed');
        expect(json['price'], 350.0);
        expect(json['transport_mode'], 'car');
        expect(json['payment_status'], 'paid');
      });

      test('serializes starts_at and ends_at as ISO 8601', () {
        final booking = Booking.fromJson(bookingJson());
        final json = booking.toJson();

        expect(json['starts_at'], contains('2026-03-10'));
        expect(json['ends_at'], contains('2026-03-10'));
      });

      test('computes ends_at from duration when endsAt is null', () {
        final booking = Booking.fromJson(bookingJson(endsAt: null));
        final json = booking.toJson();

        // Default 60 min duration, so ends_at should be starts_at + 60min
        final starts = DateTime.parse(json['starts_at'] as String);
        final ends = DateTime.parse(json['ends_at'] as String);
        expect(ends.difference(starts).inMinutes, 60);
      });
    });

    group('copyWith', () {
      test('copies with new status', () {
        final booking = Booking.fromJson(bookingJson());
        final cancelled = booking.copyWith(status: 'cancelled_customer');

        expect(cancelled.status, 'cancelled_customer');
        expect(cancelled.id, booking.id);
        expect(cancelled.serviceName, booking.serviceName);
      });

      test('copies with new notes', () {
        final booking = Booking.fromJson(bookingJson());
        final updated = booking.copyWith(notes: 'New note');

        expect(updated.notes, 'New note');
      });

      test('copies with new payment status', () {
        final booking = Booking.fromJson(bookingJson());
        final updated = booking.copyWith(paymentStatus: 'refunded');

        expect(updated.paymentStatus, 'refunded');
      });

      test('preserves unchanged fields', () {
        final booking = Booking.fromJson(bookingJson());
        final copy = booking.copyWith(status: 'pending');

        expect(copy.price, booking.price);
        expect(copy.scheduledAt, booking.scheduledAt);
        expect(copy.durationMinutes, booking.durationMinutes);
      });
    });
  });
}
