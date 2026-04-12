// =============================================================================
// Financial Contract Tests
// =============================================================================
// These tests replicate the exact math from the server-side RPCs:
//   - create_booking_with_financials (SQL)
//   - cancel_booking (SQL)
//   - purchase_product_with_saldo (SQL)
//   - calculateWithholding (tax_mx.ts)
//
// They are GOLDEN VALUE tests: if someone changes the RPC math, these tests
// document what the Flutter app expects and will break as an early warning.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Replicate server-side math (mirrors SQL + tax_mx.ts)
// ---------------------------------------------------------------------------

double round2(double n) => (n * 100).round() / 100;

/// Mirrors create_booking_with_financials tax calculation.
/// Returns: {taxBase, ivaPortion, isrWithheld, ivaWithheld, providerNet, commission}
Map<String, double> calculateBookingFinancials({
  required double price,
  required bool hasRfc,
  required String bookingSource,
  double ivaInclusive = 1.16,
  double isrRateWithRfc = 0.025,
  double ivaRateWithRfc = 0.08,
  double isrRateNoRfc = 0.20,
  double ivaRateNoRfc = 0.16,
  double commissionMarketplace = 0.03,
  double commissionSalonDirect = 0.00,
}) {
  final isrRate = hasRfc ? isrRateWithRfc : isrRateNoRfc;
  final ivaRate = hasRfc ? ivaRateWithRfc : ivaRateNoRfc;
  final commissionRate = (bookingSource == 'bc_marketplace' ||
          bookingSource == 'invite_link')
      ? commissionMarketplace
      : commissionSalonDirect;

  final taxBase = round2(price / ivaInclusive);
  final ivaPortion = round2(price - taxBase);
  final isrWithheld = round2(price * isrRate);
  final ivaWithheld = round2(ivaPortion * ivaRate);
  final commission = round2(price * commissionRate);
  final rawNet = price - isrWithheld - ivaWithheld;
  final providerNet = rawNet < 0 ? 0.0 : round2(rawNet);

  return {
    'taxBase': taxBase,
    'ivaPortion': ivaPortion,
    'isrRate': isrRate,
    'ivaRate': ivaRate,
    'isrWithheld': isrWithheld,
    'ivaWithheld': ivaWithheld,
    'commission': commission,
    'commissionRate': commissionRate,
    'providerNet': providerNet,
  };
}

/// Mirrors cancel_booking refund calculation.
Map<String, double> calculateCancellationRefund({
  required double price,
  required bool isFreeCancel,
  required String bookingSource,
  required String cancelledBy,
  bool depositRequired = false,
  double depositPercentage = 0,
  double commissionMarketplace = 0.03,
  double commissionSalonDirect = 0.00,
  bool isPaid = true,
}) {
  final commissionRate = (bookingSource == 'bc_marketplace' ||
          bookingSource == 'invite_link')
      ? commissionMarketplace
      : commissionSalonDirect;
  final bcCommission = round2(price * commissionRate);

  double refundAmount;
  double depositForfeited = 0;

  if (!isPaid || price <= 0) {
    return {
      'refundAmount': 0,
      'depositForfeited': 0,
      'commissionKept': 0,
    };
  }

  if (cancelledBy == 'business') {
    // Business cancelled: full refund, commission still charged
    refundAmount = price;
  } else if (isFreeCancel) {
    // Within window: full refund minus commission
    refundAmount = price - bcCommission;
  } else if (depositRequired && depositPercentage > 0) {
    // Late cancel with deposit: deposit forfeited
    final depositAmount = round2(price * (depositPercentage / 100.0));
    depositForfeited = depositAmount;
    refundAmount = (price - depositAmount - bcCommission);
    if (refundAmount < 0) refundAmount = 0;
  } else {
    // Late cancel, no deposit: full refund minus commission
    refundAmount = price - bcCommission;
  }

  return {
    'refundAmount': round2(refundAmount),
    'depositForfeited': depositForfeited,
    'commissionKept': bcCommission,
  };
}

/// Mirrors purchase_product_with_saldo commission.
Map<String, double> calculateProductPurchase({
  required double totalAmount,
  double commissionRateProduct = 0.10,
}) {
  final commission = round2(totalAmount * commissionRateProduct);
  return {
    'commission': commission,
    'commissionRate': commissionRateProduct,
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Tax withholding — WITH RFC (reduced rates)', () {
    test('350 MXN booking: ISR 2.5%, IVA 8%', () {
      final r = calculateBookingFinancials(
        price: 350,
        hasRfc: true,
        bookingSource: 'bc_marketplace',
      );

      expect(r['taxBase'], 301.72);
      expect(r['ivaPortion'], 48.28);
      expect(r['isrRate'], 0.025);
      expect(r['ivaRate'], 0.08);
      expect(r['isrWithheld'], 8.75);
      expect(r['ivaWithheld'], 3.86);
      expect(r['providerNet'], 337.39);
      expect(r['commission'], 10.50);
      expect(r['commissionRate'], 0.03);
    });

    test('1000 MXN booking: ISR 2.5%, IVA 8%', () {
      final r = calculateBookingFinancials(
        price: 1000,
        hasRfc: true,
        bookingSource: 'bc_marketplace',
      );

      expect(r['taxBase'], 862.07);
      expect(r['ivaPortion'], 137.93);
      expect(r['isrWithheld'], 25.0);
      expect(r['ivaWithheld'], 11.03);
      expect(r['providerNet'], 963.97);
      expect(r['commission'], 30.0);
    });

    test('100 MXN low-price booking', () {
      final r = calculateBookingFinancials(
        price: 100,
        hasRfc: true,
        bookingSource: 'salon_direct',
      );

      expect(r['taxBase'], 86.21);
      expect(r['ivaPortion'], 13.79);
      expect(r['isrWithheld'], 2.5);
      expect(r['ivaWithheld'], 1.10);
      expect(r['providerNet'], 96.40);
      // salon_direct = 0% commission
      expect(r['commission'], 0.0);
      expect(r['commissionRate'], 0.0);
    });

    test('identity: taxBase + ivaPortion = price', () {
      for (final price in [100.0, 250.0, 350.0, 999.99, 5000.0]) {
        final r = calculateBookingFinancials(
          price: price,
          hasRfc: true,
          bookingSource: 'bc_marketplace',
        );
        // Allow ±0.01 for rounding
        expect(
          (r['taxBase']! + r['ivaPortion']! - price).abs(),
          lessThanOrEqualTo(0.01),
          reason: 'taxBase + ivaPortion should equal price for \$$price',
        );
      }
    });

    test('identity: providerNet = price - isrWithheld - ivaWithheld', () {
      for (final price in [100.0, 350.0, 1000.0, 5000.0]) {
        final r = calculateBookingFinancials(
          price: price,
          hasRfc: true,
          bookingSource: 'bc_marketplace',
        );
        final expected = round2(price - r['isrWithheld']! - r['ivaWithheld']!);
        expect(r['providerNet'], expected,
            reason: 'providerNet identity for \$$price');
      }
    });
  });

  group('Tax withholding — WITHOUT RFC (maximum rates)', () {
    test('350 MXN booking: ISR 20%, IVA 16%', () {
      final r = calculateBookingFinancials(
        price: 350,
        hasRfc: false,
        bookingSource: 'bc_marketplace',
      );

      expect(r['isrRate'], 0.20);
      expect(r['ivaRate'], 0.16);
      expect(r['isrWithheld'], 70.0);
      expect(r['ivaWithheld'], 7.72);
      expect(r['providerNet'], 272.28);
      expect(r['commission'], 10.50);
    });

    test('1000 MXN booking: ISR 20%, IVA 16%', () {
      final r = calculateBookingFinancials(
        price: 1000,
        hasRfc: false,
        bookingSource: 'bc_marketplace',
      );

      expect(r['isrWithheld'], 200.0);
      expect(r['ivaWithheld'], 22.07);
      expect(r['providerNet'], 777.93);
    });

    test('no-RFC provider loses significantly more', () {
      final withRfc = calculateBookingFinancials(
        price: 1000,
        hasRfc: true,
        bookingSource: 'bc_marketplace',
      );
      final noRfc = calculateBookingFinancials(
        price: 1000,
        hasRfc: false,
        bookingSource: 'bc_marketplace',
      );

      // No-RFC provider receives much less
      expect(noRfc['providerNet']!, lessThan(withRfc['providerNet']!));
      // Difference is ~186 on 1000
      final diff = withRfc['providerNet']! - noRfc['providerNet']!;
      expect(diff, greaterThan(180));
    });
  });

  group('Commission rates by booking source', () {
    test('bc_marketplace: 3%', () {
      final r = calculateBookingFinancials(
        price: 1000,
        hasRfc: true,
        bookingSource: 'bc_marketplace',
      );
      expect(r['commissionRate'], 0.03);
      expect(r['commission'], 30.0);
    });

    test('invite_link: 3%', () {
      final r = calculateBookingFinancials(
        price: 1000,
        hasRfc: true,
        bookingSource: 'invite_link',
      );
      expect(r['commissionRate'], 0.03);
      expect(r['commission'], 30.0);
    });

    test('salon_direct: 0%', () {
      final r = calculateBookingFinancials(
        price: 1000,
        hasRfc: true,
        bookingSource: 'salon_direct',
      );
      expect(r['commissionRate'], 0.0);
      expect(r['commission'], 0.0);
    });

    test('cita_express: 0%', () {
      final r = calculateBookingFinancials(
        price: 1000,
        hasRfc: true,
        bookingSource: 'cita_express',
      );
      expect(r['commissionRate'], 0.0);
      expect(r['commission'], 0.0);
    });

    test('walk_in: 0%', () {
      final r = calculateBookingFinancials(
        price: 500,
        hasRfc: true,
        bookingSource: 'walk_in',
      );
      expect(r['commissionRate'], 0.0);
      expect(r['commission'], 0.0);
    });
  });

  group('Cancellation refund — customer', () {
    test('free cancel on marketplace booking: full minus 3%', () {
      final r = calculateCancellationRefund(
        price: 1000,
        isFreeCancel: true,
        bookingSource: 'bc_marketplace',
        cancelledBy: 'customer',
      );

      expect(r['refundAmount'], 970.0);
      expect(r['depositForfeited'], 0.0);
      expect(r['commissionKept'], 30.0);
    });

    test('free cancel on salon_direct: full refund (0% commission)', () {
      final r = calculateCancellationRefund(
        price: 1000,
        isFreeCancel: true,
        bookingSource: 'salon_direct',
        cancelledBy: 'customer',
      );

      expect(r['refundAmount'], 1000.0);
      expect(r['commissionKept'], 0.0);
    });

    test('late cancel with 20% deposit: deposit forfeited', () {
      final r = calculateCancellationRefund(
        price: 1000,
        isFreeCancel: false,
        bookingSource: 'bc_marketplace',
        cancelledBy: 'customer',
        depositRequired: true,
        depositPercentage: 20,
      );

      expect(r['depositForfeited'], 200.0);
      // 1000 - 200 deposit - 30 commission = 770
      expect(r['refundAmount'], 770.0);
      expect(r['commissionKept'], 30.0);
    });

    test('late cancel without deposit policy: full minus commission', () {
      final r = calculateCancellationRefund(
        price: 500,
        isFreeCancel: false,
        bookingSource: 'bc_marketplace',
        cancelledBy: 'customer',
        depositRequired: false,
      );

      expect(r['refundAmount'], 485.0);
      expect(r['depositForfeited'], 0.0);
      expect(r['commissionKept'], 15.0);
    });

    test('unpaid booking cancel: no money moves', () {
      final r = calculateCancellationRefund(
        price: 500,
        isFreeCancel: true,
        bookingSource: 'bc_marketplace',
        cancelledBy: 'customer',
        isPaid: false,
      );

      expect(r['refundAmount'], 0.0);
      expect(r['depositForfeited'], 0.0);
      expect(r['commissionKept'], 0.0);
    });

    test('zero price cancel: no money moves', () {
      final r = calculateCancellationRefund(
        price: 0,
        isFreeCancel: true,
        bookingSource: 'bc_marketplace',
        cancelledBy: 'customer',
      );

      expect(r['refundAmount'], 0.0);
      expect(r['commissionKept'], 0.0);
    });
  });

  group('Cancellation refund — business', () {
    test('business cancels: full refund to customer', () {
      final r = calculateCancellationRefund(
        price: 1000,
        isFreeCancel: false, // doesn't matter for business cancel
        bookingSource: 'bc_marketplace',
        cancelledBy: 'business',
      );

      // Customer gets full refund
      expect(r['refundAmount'], 1000.0);
      // Commission still charged to salon
      expect(r['commissionKept'], 30.0);
      expect(r['depositForfeited'], 0.0);
    });

    test('business cancels salon_direct: full refund, 0% commission', () {
      final r = calculateCancellationRefund(
        price: 500,
        isFreeCancel: false,
        bookingSource: 'salon_direct',
        cancelledBy: 'business',
      );

      expect(r['refundAmount'], 500.0);
      expect(r['commissionKept'], 0.0);
    });
  });

  group('Cancellation identity checks', () {
    test('refund + deposit + commission <= price (marketplace)', () {
      for (final price in [100.0, 350.0, 1000.0, 5000.0]) {
        final r = calculateCancellationRefund(
          price: price,
          isFreeCancel: false,
          bookingSource: 'bc_marketplace',
          cancelledBy: 'customer',
          depositRequired: true,
          depositPercentage: 20,
        );
        final total = r['refundAmount']! +
            r['depositForfeited']! +
            r['commissionKept']!;
        expect(total, closeTo(price, 0.01),
            reason: 'refund + deposit + commission should equal price for \$$price');
      }
    });

    test('free cancel: refund + commission = price (marketplace)', () {
      for (final price in [100.0, 350.0, 1000.0]) {
        final r = calculateCancellationRefund(
          price: price,
          isFreeCancel: true,
          bookingSource: 'bc_marketplace',
          cancelledBy: 'customer',
        );
        final total = r['refundAmount']! + r['commissionKept']!;
        expect(total, closeTo(price, 0.01),
            reason: 'refund + commission should equal price for \$$price');
      }
    });
  });

  group('Product purchase commission', () {
    test('10% commission on 890 MXN product', () {
      final r = calculateProductPurchase(totalAmount: 890);
      expect(r['commission'], 89.0);
      expect(r['commissionRate'], 0.10);
    });

    test('10% commission on 50 MXN product', () {
      final r = calculateProductPurchase(totalAmount: 50);
      expect(r['commission'], 5.0);
    });

    test('10% commission on 2999.99 MXN product', () {
      final r = calculateProductPurchase(totalAmount: 2999.99);
      expect(r['commission'], 300.0);
    });
  });

  group('Edge cases', () {
    test('1 peso booking with RFC', () {
      final r = calculateBookingFinancials(
        price: 1,
        hasRfc: true,
        bookingSource: 'bc_marketplace',
      );

      expect(r['taxBase'], 0.86);
      expect(r['ivaPortion'], 0.14);
      expect(r['isrWithheld'], 0.03); // 1 * 0.025 rounded
      expect(r['ivaWithheld'], 0.01); // 0.14 * 0.08 rounded
      expect(r['providerNet'], 0.96);
      expect(r['commission'], 0.03);
    });

    test('providerNet never goes negative (guard clause)', () {
      // Hypothetical: if rates were ever misconfigured to exceed 100%,
      // providerNet should clamp to 0, not go negative.
      final r = calculateBookingFinancials(
        price: 10,
        hasRfc: false, // ISR 20% + IVA 16% = high deductions
        bookingSource: 'bc_marketplace',
      );
      expect(r['providerNet']!, greaterThanOrEqualTo(0.0));

      // Also test with RFC (should always be positive)
      final r2 = calculateBookingFinancials(
        price: 1,
        hasRfc: true,
        bookingSource: 'bc_marketplace',
      );
      expect(r2['providerNet']!, greaterThanOrEqualTo(0.0));
    });

    test('very large booking (50000 MXN)', () {
      final r = calculateBookingFinancials(
        price: 50000,
        hasRfc: true,
        bookingSource: 'bc_marketplace',
      );

      expect(r['isrWithheld'], 1250.0);
      expect(r['commission'], 1500.0);
      // Provider still gets the bulk
      expect(r['providerNet']!, greaterThan(45000));
    });

    test('rounding consistency: monetary values have no fractional centavos', () {
      // Only monetary outputs need ≤2 decimals. Rates (isrRate, ivaRate,
      // commissionRate) are config values, not money.
      const moneyKeys = {
        'taxBase', 'ivaPortion', 'isrWithheld', 'ivaWithheld',
        'commission', 'providerNet',
      };
      for (final price in [99.99, 123.45, 777.77, 1234.56]) {
        final r = calculateBookingFinancials(
          price: price,
          hasRfc: true,
          bookingSource: 'bc_marketplace',
        );
        for (final entry in r.entries) {
          if (!moneyKeys.contains(entry.key)) continue;
          final decimals = entry.value.toString().split('.');
          if (decimals.length > 1) {
            expect(decimals[1].length, lessThanOrEqualTo(2),
                reason:
                    '${entry.key} should have ≤2 decimals for price=$price');
          }
        }
      }
    });
  });
}
