import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita_core/models.dart';
import '../helpers/model_fixtures.dart';

void main() {
  group('Payment', () {
    group('fromJson', () {
      test('parses all fields', () {
        final p = Payment.fromJson(paymentJson());

        expect(p.id, 'pay-1');
        expect(p.appointmentId, 'booking-1');
        expect(p.amount, 350.0);
        expect(p.method, 'card');
        expect(p.status, 'completed');
        expect(p.createdAt, DateTime.utc(2026, 3, 10, 14));
      });

      test('defaults method to unknown when null', () {
        final json = paymentJson();
        json.remove('method');
        final p = Payment.fromJson(json);

        expect(p.method, 'unknown');
      });

      test('defaults status to pending when null', () {
        final json = paymentJson();
        json.remove('status');
        final p = Payment.fromJson(json);

        expect(p.status, 'pending');
      });

      test('handles integer amount via num cast', () {
        final p = Payment.fromJson(paymentJson(amount: 500));
        expect(p.amount, 500.0);
        expect(p.amount, isA<double>());
      });
    });

    group('toJson', () {
      test('round-trips through fromJson', () {
        final p = Payment.fromJson(paymentJson());
        final json = p.toJson();

        expect(json['id'], 'pay-1');
        expect(json['appointment_id'], 'booking-1');
        expect(json['amount'], 350.0);
        expect(json['method'], 'card');
        expect(json['status'], 'completed');
        expect(json['created_at'], contains('2026-03-10'));
      });
    });
  });
}
