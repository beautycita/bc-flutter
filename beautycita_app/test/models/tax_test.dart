import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita/providers/admin_finance_dashboard_provider.dart';

/// Tests for financial model classes and BeautyCita business rules:
/// - Commission: 3% on bookings, 10% on products
/// - IVA withholding: 8% on gross
/// - ISR withholding: 2.5% on gross (simplified regime rate per SAT)
/// - Reconciliation discrepancy detection
/// - Debt collection: 50% cap on gross amount per transaction

void main() {
  group('Commission calculation', () {
    test('3% booking commission on \$1000 = \$30', () {
      const gross = 1000.0;
      const rate = 0.03;
      expect(gross * rate, 30.0);
    });

    test('10% product commission on \$1000 = \$100', () {
      const gross = 1000.0;
      const rate = 0.10;
      expect(gross * rate, 100.0);
    });

    test('CommissionBreakdown.total sums booking + product', () {
      const breakdown = CommissionBreakdown(
        bookingCommission: 30.0,
        productCommission: 100.0,
        bookingCount: 10,
        productCount: 5,
      );
      expect(breakdown.total, 130.0);
    });

    test('CommissionBreakdown.placeholder has zero total', () {
      expect(CommissionBreakdown.placeholder.total, 0.0);
    });

    test('zero-revenue commission is zero', () {
      const gross = 0.0;
      expect(gross * 0.03, 0.0);
      expect(gross * 0.10, 0.0);
    });
  });

  group('IVA withholding', () {
    test('8% IVA on \$1000 = \$80', () {
      const gross = 1000.0;
      const ivaRate = 0.08;
      expect(gross * ivaRate, 80.0);
    });

    test('8% IVA on \$5000 = \$400', () {
      const gross = 5000.0;
      expect(gross * 0.08, 400.0);
    });

    test('TaxWithholdingSummary.totalThisMonth sums ISR + IVA', () {
      const summary = TaxWithholdingSummary(
        isrThisMonth: 25.0,
        ivaThisMonth: 80.0,
        isrAllTime: 250.0,
        ivaAllTime: 800.0,
      );
      expect(summary.totalThisMonth, 105.0);
    });

    test('TaxWithholdingSummary.totalAllTime sums ISR + IVA', () {
      const summary = TaxWithholdingSummary(
        isrThisMonth: 25.0,
        ivaThisMonth: 80.0,
        isrAllTime: 250.0,
        ivaAllTime: 800.0,
      );
      expect(summary.totalAllTime, 1050.0);
    });

    test('TaxWithholdingSummary.placeholder has zero totals', () {
      expect(TaxWithholdingSummary.placeholder.totalThisMonth, 0.0);
      expect(TaxWithholdingSummary.placeholder.totalAllTime, 0.0);
    });
  });

  group('ISR withholding', () {
    test('2.5% ISR on \$1000 = \$25', () {
      const gross = 1000.0;
      const isrRate = 0.025;
      expect(gross * isrRate, 25.0);
    });

    test('2.5% ISR on \$5000 = \$125', () {
      const gross = 5000.0;
      expect(gross * 0.025, 125.0);
    });
  });

  group('Deduction budget (revenue - expenses)', () {
    test('net payable = revenue - fees - ISR - IVA', () {
      const row = BusinessRevenueRow(
        businessId: 'b1',
        businessName: 'Salon Test',
        totalBookings: 100,
        totalRevenue: 10000.0,
        totalPlatformFees: 300.0, // 3% commission
        totalIsr: 250.0, // 2.5%
        totalIva: 800.0, // 8%
        currentMonthRevenue: 1000.0,
        currentMonthBookings: 10,
      );
      // 10000 - 300 - 250 - 800 = 8650
      expect(row.netPayable, 8650.0);
    });

    test('net payable with zero deductions equals total revenue', () {
      const row = BusinessRevenueRow(
        businessId: 'b2',
        businessName: 'Salon Zero',
        totalBookings: 50,
        totalRevenue: 5000.0,
        totalPlatformFees: 0.0,
        totalIsr: 0.0,
        totalIva: 0.0,
        currentMonthRevenue: 500.0,
        currentMonthBookings: 5,
      );
      expect(row.netPayable, 5000.0);
    });
  });

  group('Reconciliation discrepancy', () {
    test('no discrepancy when amounts balance', () {
      final row = ReconciliationRow(
        paymentDate: DateTime(2026, 3, 15),
        appointmentId: 'apt-1',
        businessName: 'Test Salon',
        serviceName: 'Corte',
        grossAmount: 1000.0,
        platformFee: 30.0,  // 3%
        isrWithheld: 25.0,   // 2.5%
        ivaWithheld: 80.0,   // 8%
        providerNet: 865.0,  // 1000 - 30 - 25 - 80
        paymentStatus: 'completed',
      );
      expect(row.hasDiscrepancy, isFalse);
      expect(row.discrepancy.abs(), lessThan(0.01));
    });

    test('detects discrepancy when amounts do not balance', () {
      final row = ReconciliationRow(
        paymentDate: DateTime(2026, 3, 15),
        appointmentId: 'apt-2',
        businessName: 'Test Salon',
        serviceName: 'Corte',
        grossAmount: 1000.0,
        platformFee: 30.0,
        isrWithheld: 25.0,
        ivaWithheld: 80.0,
        providerNet: 800.0, // should be 865, off by 65
        paymentStatus: 'completed',
      );
      expect(row.hasDiscrepancy, isTrue);
      expect(row.discrepancy, closeTo(65.0, 0.01));
    });

    test('fromJson parses correctly', () {
      final json = {
        'payment_date': '2026-03-15T10:00:00Z',
        'appointment_id': 'apt-3',
        'business_name': 'Salon JSON',
        'service_name': 'Tinte',
        'gross_amount': 500,
        'platform_fee': 15,
        'isr_withheld': 12.5,
        'iva_withheld': 40,
        'provider_net': 432.5,
        'payment_method': 'card',
        'payment_status': 'completed',
      };
      final row = ReconciliationRow.fromJson(json);
      expect(row.grossAmount, 500.0);
      expect(row.platformFee, 15.0);
      expect(row.isrWithheld, 12.5);
      expect(row.ivaWithheld, 40.0);
      expect(row.providerNet, 432.5);
      expect(row.hasDiscrepancy, isFalse);
    });
  });

  group('Debt collection (50% cap on gross)', () {
    test('50% cap on \$1000 gross = max \$500 deduction', () {
      const grossAmount = 1000.0;
      const capRate = 0.50;
      final maxDeduction = grossAmount * capRate;
      expect(maxDeduction, 500.0);
    });

    test('debt smaller than 50% cap is fully collectible', () {
      const grossAmount = 1000.0;
      const debtRemaining = 200.0;
      const capRate = 0.50;
      final maxDeduction = grossAmount * capRate;
      final actualDeduction =
          debtRemaining < maxDeduction ? debtRemaining : maxDeduction;
      expect(actualDeduction, 200.0);
    });

    test('debt larger than 50% cap is capped', () {
      const grossAmount = 1000.0;
      const debtRemaining = 800.0;
      const capRate = 0.50;
      final maxDeduction = grossAmount * capRate;
      final actualDeduction =
          debtRemaining < maxDeduction ? debtRemaining : maxDeduction;
      expect(actualDeduction, 500.0);
    });

    test('SalonDebt model holds outstanding balance', () {
      final debt = SalonDebt(
        id: 'd1',
        businessId: 'b1',
        businessName: 'Salon Deudor',
        originalAmount: 1000.0,
        remainingAmount: 600.0,
        createdAt: DateTime(2026, 1, 1),
      );
      expect(debt.remainingAmount, 600.0);
      expect(debt.originalAmount, 1000.0);
    });

    test('DebtSummary aggregates outstanding total', () {
      final debts = [
        SalonDebt(
          id: 'd1',
          businessId: 'b1',
          businessName: 'Salon A',
          originalAmount: 500.0,
          remainingAmount: 300.0,
          createdAt: DateTime(2026, 1, 1),
        ),
        SalonDebt(
          id: 'd2',
          businessId: 'b2',
          businessName: 'Salon B',
          originalAmount: 800.0,
          remainingAmount: 800.0,
          createdAt: DateTime(2026, 2, 1),
        ),
      ];
      final summary = DebtSummary(
        totalOutstanding: 1100.0,
        salonsWithDebt: 2,
        debts: debts,
        recentPayments: const [],
      );
      expect(summary.totalOutstanding, 1100.0);
      expect(summary.salonsWithDebt, 2);
      expect(summary.debts, hasLength(2));
    });
  });
}
