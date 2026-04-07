import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita_core/models.dart';
import '../helpers/model_fixtures.dart';

void main() {
  group('UberRide', () {
    group('fromJson', () {
      test('parses all fields', () {
        final r = UberRide.fromJson(uberRideJson());

        expect(r.id, 'ride-1');
        expect(r.appointmentId, 'booking-1');
        expect(r.leg, 'outbound');
        expect(r.pickupLat, 20.6534);
        expect(r.pickupLng, -105.2253);
        expect(r.pickupAddress, 'Av. Mexico 123');
        expect(r.dropoffLat, 20.6600);
        expect(r.dropoffLng, -105.2300);
        expect(r.dropoffAddress, 'Salon Rosa, Calle Flores 45');
        expect(r.estimatedFareMin, 45.0);
        expect(r.estimatedFareMax, 65.0);
        expect(r.currency, 'MXN');
        expect(r.status, 'scheduled');
        expect(r.scheduledPickupAt, DateTime.utc(2026, 3, 10, 13, 30));
      });

      test('defaults currency to MXN when null', () {
        final json = uberRideJson();
        json.remove('currency');
        final r = UberRide.fromJson(json);

        expect(r.currency, 'MXN');
      });

      test('defaults status to scheduled when null', () {
        final json = uberRideJson();
        json.remove('status');
        final r = UberRide.fromJson(json);

        expect(r.status, 'scheduled');
      });

      test('handles null optional fields', () {
        final r = UberRide.fromJson(uberRideJson(
          uberRequestId: null,
          pickupLat: null,
          pickupLng: null,
          pickupAddress: null,
          dropoffLat: null,
          dropoffLng: null,
          dropoffAddress: null,
          scheduledPickupAt: null,
          estimatedFareMin: null,
          estimatedFareMax: null,
        ));

        expect(r.uberRequestId, isNull);
        expect(r.pickupLat, isNull);
        expect(r.scheduledPickupAt, isNull);
        expect(r.estimatedFareMin, isNull);
      });
    });

    group('statusLabel', () {
      test('returns Spanish labels for known statuses', () {
        expect(UberRide.fromJson(uberRideJson(status: 'scheduled')).statusLabel, 'Programado');
        expect(UberRide.fromJson(uberRideJson(status: 'requested')).statusLabel, 'Solicitado');
        expect(UberRide.fromJson(uberRideJson(status: 'accepted')).statusLabel, 'Aceptado');
        expect(UberRide.fromJson(uberRideJson(status: 'arriving')).statusLabel, 'En camino');
        expect(UberRide.fromJson(uberRideJson(status: 'in_progress')).statusLabel, 'En curso');
        expect(UberRide.fromJson(uberRideJson(status: 'completed')).statusLabel, 'Completado');
        expect(UberRide.fromJson(uberRideJson(status: 'cancelled')).statusLabel, 'Cancelado');
      });

      test('returns raw status for unknown values', () {
        expect(UberRide.fromJson(uberRideJson(status: 'mystery')).statusLabel, 'mystery');
      });
    });

    group('isActive', () {
      test('returns true for non-terminal statuses', () {
        expect(UberRide.fromJson(uberRideJson(status: 'scheduled')).isActive, true);
        expect(UberRide.fromJson(uberRideJson(status: 'arriving')).isActive, true);
        expect(UberRide.fromJson(uberRideJson(status: 'in_progress')).isActive, true);
      });

      test('returns false for terminal statuses', () {
        expect(UberRide.fromJson(uberRideJson(status: 'completed')).isActive, false);
        expect(UberRide.fromJson(uberRideJson(status: 'cancelled')).isActive, false);
      });
    });
  });
}
