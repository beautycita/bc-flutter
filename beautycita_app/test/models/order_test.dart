import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita_core/models.dart';
import '../helpers/model_fixtures.dart';

void main() {
  group('Order', () {
    group('fromJson', () {
      test('parses all required fields', () {
        final o = Order.fromJson(orderJson());

        expect(o.id, 'order-1');
        expect(o.buyerId, 'user-1');
        expect(o.businessId, 'biz-1');
        expect(o.productId, 'prod-1');
        expect(o.productName, 'Shampoo Hidratante');
        expect(o.quantity, 2);
        expect(o.totalAmount, 450.0);
        expect(o.commissionAmount, 45.0);
        expect(o.stripePaymentIntentId, 'pi_abc123');
        expect(o.status, 'paid');
        expect(o.createdAt, DateTime.utc(2026, 3, 10, 10));
      });

      test('defaults quantity to 1 when null', () {
        final json = orderJson();
        json.remove('quantity');
        final o = Order.fromJson(json);

        expect(o.quantity, 1);
      });

      test('handles null optional fields', () {
        final o = Order.fromJson(orderJson(
          productId: null,
          stripePaymentIntentId: null,
          trackingNumber: null,
          shippingAddress: null,
          shippedAt: null,
          deliveredAt: null,
          refundedAt: null,
        ));

        expect(o.productId, isNull);
        expect(o.stripePaymentIntentId, isNull);
        expect(o.trackingNumber, isNull);
        expect(o.shippingAddress, isNull);
        expect(o.shippedAt, isNull);
        expect(o.deliveredAt, isNull);
        expect(o.refundedAt, isNull);
      });

      test('parses shipping dates', () {
        final o = Order.fromJson(orderJson(
          shippedAt: '2026-03-11T10:00:00Z',
          deliveredAt: '2026-03-13T15:00:00Z',
        ));

        expect(o.shippedAt, DateTime.utc(2026, 3, 11, 10));
        expect(o.deliveredAt, DateTime.utc(2026, 3, 13, 15));
      });
    });

    group('status helpers', () {
      test('isPaid returns true for paid status', () {
        expect(Order.fromJson(orderJson(status: 'paid')).isPaid, true);
        expect(Order.fromJson(orderJson(status: 'shipped')).isPaid, false);
      });

      test('isShipped returns true for shipped status', () {
        expect(Order.fromJson(orderJson(status: 'shipped')).isShipped, true);
      });

      test('isDelivered returns true for delivered status', () {
        expect(Order.fromJson(orderJson(status: 'delivered')).isDelivered, true);
      });

      test('isRefunded returns true for refunded status', () {
        expect(Order.fromJson(orderJson(status: 'refunded')).isRefunded, true);
      });

      test('isCancelled returns true for cancelled status', () {
        expect(Order.fromJson(orderJson(status: 'cancelled')).isCancelled, true);
      });

      test('needsAction returns true only for paid status', () {
        expect(Order.fromJson(orderJson(status: 'paid')).needsAction, true);
        expect(Order.fromJson(orderJson(status: 'shipped')).needsAction, false);
      });
    });

    group('shipping deadline', () {
      test('daysSinceOrder computes from createdAt', () {
        final recent = Order.fromJson(orderJson(
          createdAt: DateTime.now().toUtc().toIso8601String(),
        ));
        expect(recent.daysSinceOrder, 0);
      });

      test('isShippingOverdue when past 14 days', () {
        final old = Order.fromJson(orderJson(
          createdAt: DateTime.now().subtract(const Duration(days: 20)).toUtc().toIso8601String(),
        ));
        expect(old.isShippingOverdue, true);
      });

      test('isShippingUrgent when 3 or fewer days left', () {
        final urgent = Order.fromJson(orderJson(
          createdAt: DateTime.now().subtract(const Duration(days: 12)).toUtc().toIso8601String(),
        ));
        expect(urgent.isShippingUrgent, true);
        expect(urgent.isShippingOverdue, false);
      });
    });
  });
}
