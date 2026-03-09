import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/services/supabase_client.dart';

// ── Data classes ──────────────────────────────────────────────────────────────

/// Revenue overview KPIs for the CEO finance dashboard.
@immutable
class FinanceDashboardKpis {
  final double revenueToday;
  final double revenueThisWeek;
  final double revenueThisMonth;
  final double revenueAllTime;
  final double commissionToday;
  final double commissionThisMonth;
  final double taxWithheldToday;
  final double taxWithheldThisMonth;
  final int bookingsToday;
  final int totalUsers;
  final int totalBusinesses;
  final double avgBookingValue;

  const FinanceDashboardKpis({
    required this.revenueToday,
    required this.revenueThisWeek,
    required this.revenueThisMonth,
    required this.revenueAllTime,
    required this.commissionToday,
    required this.commissionThisMonth,
    required this.taxWithheldToday,
    required this.taxWithheldThisMonth,
    required this.bookingsToday,
    required this.totalUsers,
    required this.totalBusinesses,
    required this.avgBookingValue,
  });

  static const placeholder = FinanceDashboardKpis(
    revenueToday: 0,
    revenueThisWeek: 0,
    revenueThisMonth: 0,
    revenueAllTime: 0,
    commissionToday: 0,
    commissionThisMonth: 0,
    taxWithheldToday: 0,
    taxWithheldThisMonth: 0,
    bookingsToday: 0,
    totalUsers: 0,
    totalBusinesses: 0,
    avgBookingValue: 0,
  );
}

/// Commission breakdown: bookings 3% vs products 10%.
@immutable
class CommissionBreakdown {
  final double bookingCommission;
  final double productCommission;
  final int bookingCount;
  final int productCount;

  const CommissionBreakdown({
    required this.bookingCommission,
    required this.productCommission,
    required this.bookingCount,
    required this.productCount,
  });

  double get total => bookingCommission + productCommission;

  static const placeholder = CommissionBreakdown(
    bookingCommission: 0,
    productCommission: 0,
    bookingCount: 0,
    productCount: 0,
  );
}

/// Tax withholdings summary per period.
@immutable
class TaxWithholdingSummary {
  final double isrThisMonth;
  final double ivaThisMonth;
  final double isrAllTime;
  final double ivaAllTime;

  const TaxWithholdingSummary({
    required this.isrThisMonth,
    required this.ivaThisMonth,
    required this.isrAllTime,
    required this.ivaAllTime,
  });

  double get totalThisMonth => isrThisMonth + ivaThisMonth;
  double get totalAllTime => isrAllTime + ivaAllTime;

  static const placeholder = TaxWithholdingSummary(
    isrThisMonth: 0,
    ivaThisMonth: 0,
    isrAllTime: 0,
    ivaAllTime: 0,
  );
}

/// A single row in the reconciliation table.
@immutable
class ReconciliationRow {
  final DateTime paymentDate;
  final String appointmentId;
  final String businessName;
  final String serviceName;
  final double grossAmount;
  final double platformFee;
  final double isrWithheld;
  final double ivaWithheld;
  final double providerNet;
  final String? paymentMethod;
  final String paymentStatus;
  final String? stripePaymentIntentId;

  const ReconciliationRow({
    required this.paymentDate,
    required this.appointmentId,
    required this.businessName,
    required this.serviceName,
    required this.grossAmount,
    required this.platformFee,
    required this.isrWithheld,
    required this.ivaWithheld,
    required this.providerNet,
    this.paymentMethod,
    required this.paymentStatus,
    this.stripePaymentIntentId,
  });

  /// Difference between gross and (commission + tax + net payout).
  double get discrepancy =>
      grossAmount - (platformFee + isrWithheld + ivaWithheld + providerNet);

  bool get hasDiscrepancy => discrepancy.abs() > 0.01;

  factory ReconciliationRow.fromJson(Map<String, dynamic> json) {
    return ReconciliationRow(
      paymentDate: DateTime.tryParse(json['payment_date']?.toString() ?? '') ??
          DateTime.now(),
      appointmentId: json['appointment_id']?.toString() ?? '',
      businessName: json['business_name'] as String? ?? 'Desconocido',
      serviceName: json['service_name'] as String? ?? '',
      grossAmount: (json['gross_amount'] as num?)?.toDouble() ?? 0,
      platformFee: (json['platform_fee'] as num?)?.toDouble() ?? 0,
      isrWithheld: (json['isr_withheld'] as num?)?.toDouble() ?? 0,
      ivaWithheld: (json['iva_withheld'] as num?)?.toDouble() ?? 0,
      providerNet: (json['provider_net'] as num?)?.toDouble() ?? 0,
      paymentMethod: json['payment_method'] as String?,
      paymentStatus: json['payment_status'] as String? ?? '',
      stripePaymentIntentId: json['stripe_payment_intent_id'] as String?,
    );
  }
}

/// Per-salon revenue row from v_business_revenue.
@immutable
class BusinessRevenueRow {
  final String businessId;
  final String businessName;
  final String? rfc;
  final int totalBookings;
  final double totalRevenue;
  final double totalPlatformFees;
  final double totalIsr;
  final double totalIva;
  final double currentMonthRevenue;
  final int currentMonthBookings;

  const BusinessRevenueRow({
    required this.businessId,
    required this.businessName,
    this.rfc,
    required this.totalBookings,
    required this.totalRevenue,
    required this.totalPlatformFees,
    required this.totalIsr,
    required this.totalIva,
    required this.currentMonthRevenue,
    required this.currentMonthBookings,
  });

  double get netPayable =>
      totalRevenue - totalPlatformFees - totalIsr - totalIva;

  factory BusinessRevenueRow.fromJson(Map<String, dynamic> json) {
    return BusinessRevenueRow(
      businessId: json['business_id']?.toString() ?? '',
      businessName: json['business_name'] as String? ?? 'Desconocido',
      rfc: json['rfc'] as String?,
      totalBookings: (json['total_bookings'] as num?)?.toInt() ?? 0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0,
      totalPlatformFees: (json['total_platform_fees'] as num?)?.toDouble() ?? 0,
      totalIsr: (json['total_isr'] as num?)?.toDouble() ?? 0,
      totalIva: (json['total_iva'] as num?)?.toDouble() ?? 0,
      currentMonthRevenue:
          (json['current_month_revenue'] as num?)?.toDouble() ?? 0,
      currentMonthBookings:
          (json['current_month_bookings'] as num?)?.toInt() ?? 0,
    );
  }
}

// ── Providers ────────────────────────────────────────────────────────────────

/// CEO financial KPIs from v_platform_health and v_daily_revenue.
final financeDashboardKpisProvider =
    FutureProvider<FinanceDashboardKpis>((ref) async {
  if (!SupabaseClientService.isInitialized) return FinanceDashboardKpis.placeholder;

  try {
    final client = SupabaseClientService.client;

    // Fetch platform health (single row) and daily revenue in parallel
    final results = await Future.wait([
      client.from('v_platform_health').select().limit(1),
      client.from('v_daily_revenue').select().limit(30),
    ]);

    final healthRows = results[0] as List;
    final dailyRows = results[1] as List;

    if (healthRows.isEmpty) return FinanceDashboardKpis.placeholder;

    final h = healthRows.first;

    // Calculate weekly revenue from daily data
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    double weeklyRevenue = 0;
    double allTimeRevenue = 0;
    double todayCommission = 0;
    double todayTax = 0;

    for (final row in dailyRows) {
      final date = DateTime.tryParse(row['date']?.toString() ?? '');
      final revenue = (row['total_revenue'] as num?)?.toDouble() ?? 0;
      final fees = (row['platform_fees'] as num?)?.toDouble() ?? 0;
      final isr = (row['isr_withheld'] as num?)?.toDouble() ?? 0;
      final iva = (row['iva_withheld'] as num?)?.toDouble() ?? 0;
      allTimeRevenue += revenue;
      if (date != null && !date.isBefore(weekStart)) {
        weeklyRevenue += revenue;
      }
      if (date != null &&
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        todayCommission = fees;
        todayTax = isr + iva;
      }
    }

    return FinanceDashboardKpis(
      revenueToday: (h['revenue_today'] as num?)?.toDouble() ?? 0,
      revenueThisWeek: weeklyRevenue,
      revenueThisMonth: (h['total_revenue_mtd'] as num?)?.toDouble() ?? 0,
      revenueAllTime: allTimeRevenue,
      commissionToday: todayCommission,
      commissionThisMonth:
          (h['total_platform_fees_mtd'] as num?)?.toDouble() ?? 0,
      taxWithheldToday: todayTax,
      taxWithheldThisMonth:
          ((h['total_isr_mtd'] as num?)?.toDouble() ?? 0) +
              ((h['total_iva_mtd'] as num?)?.toDouble() ?? 0),
      bookingsToday: (h['bookings_today'] as num?)?.toInt() ?? 0,
      totalUsers: (h['total_users'] as num?)?.toInt() ?? 0,
      totalBusinesses: (h['total_businesses'] as num?)?.toInt() ?? 0,
      avgBookingValue: (h['avg_booking_value'] as num?)?.toDouble() ?? 0,
    );
  } catch (e) {
    debugPrint('Finance dashboard KPIs error: $e');
    return FinanceDashboardKpis.placeholder;
  }
});

/// Commission breakdown (booking 3% vs product 10%) from v_monthly_revenue.
final commissionBreakdownProvider =
    FutureProvider<CommissionBreakdown>((ref) async {
  if (!SupabaseClientService.isInitialized) return CommissionBreakdown.placeholder;

  try {
    final client = SupabaseClientService.client;
    final now = DateTime.now();

    // Get current month from v_monthly_revenue
    final data = await client
        .from('v_monthly_revenue')
        .select()
        .eq('year', now.year)
        .eq('month', now.month)
        .limit(1);

    if ((data as List).isEmpty) return CommissionBreakdown.placeholder;

    final row = data.first;
    return CommissionBreakdown(
      bookingCommission:
          (row['booking_platform_fees'] as num?)?.toDouble() ??
              ((row['booking_revenue'] as num?)?.toDouble() ?? 0) * 0.03,
      productCommission:
          (row['product_platform_fees'] as num?)?.toDouble() ??
              ((row['product_revenue'] as num?)?.toDouble() ?? 0) * 0.10,
      bookingCount: (row['booking_count'] as num?)?.toInt() ?? 0,
      productCount: (row['product_orders'] as num?)?.toInt() ?? 0,
    );
  } catch (e) {
    debugPrint('Commission breakdown error: $e');
    return CommissionBreakdown.placeholder;
  }
});

/// Tax withholding summary from v_monthly_revenue and all-time from daily.
final taxWithholdingProvider =
    FutureProvider<TaxWithholdingSummary>((ref) async {
  if (!SupabaseClientService.isInitialized) return TaxWithholdingSummary.placeholder;

  try {
    final client = SupabaseClientService.client;
    final now = DateTime.now();

    final results = await Future.wait([
      client
          .from('v_monthly_revenue')
          .select('isr_withheld, iva_withheld')
          .eq('year', now.year)
          .eq('month', now.month)
          .limit(1),
      client.from('v_monthly_revenue').select('isr_withheld, iva_withheld'),
    ]);

    final currentMonth = results[0] as List;
    final allMonths = results[1] as List;

    double isrMonth = 0, ivaMonth = 0, isrAll = 0, ivaAll = 0;

    if (currentMonth.isNotEmpty) {
      isrMonth = (currentMonth.first['isr_withheld'] as num?)?.toDouble() ?? 0;
      ivaMonth = (currentMonth.first['iva_withheld'] as num?)?.toDouble() ?? 0;
    }

    for (final row in allMonths) {
      isrAll += (row['isr_withheld'] as num?)?.toDouble() ?? 0;
      ivaAll += (row['iva_withheld'] as num?)?.toDouble() ?? 0;
    }

    return TaxWithholdingSummary(
      isrThisMonth: isrMonth,
      ivaThisMonth: ivaMonth,
      isrAllTime: isrAll,
      ivaAllTime: ivaAll,
    );
  } catch (e) {
    debugPrint('Tax withholding error: $e');
    return TaxWithholdingSummary.placeholder;
  }
});

/// Reconciliation table data from v_payment_reconciliation.
final reconciliationProvider =
    FutureProvider<List<ReconciliationRow>>((ref) async {
  if (!SupabaseClientService.isInitialized) return [];

  try {
    final data = await SupabaseClientService.client
        .from('v_payment_reconciliation')
        .select()
        .limit(200);

    return (data as List)
        .map((row) => ReconciliationRow.fromJson(row))
        .toList();
  } catch (e) {
    debugPrint('Reconciliation error: $e');
    return [];
  }
});

/// Per-salon revenue breakdown from v_business_revenue.
final businessRevenueProvider =
    FutureProvider<List<BusinessRevenueRow>>((ref) async {
  if (!SupabaseClientService.isInitialized) return [];

  try {
    final data = await SupabaseClientService.client
        .from('v_business_revenue')
        .select()
        .limit(500);

    return (data as List)
        .map((row) => BusinessRevenueRow.fromJson(row))
        .toList();
  } catch (e) {
    debugPrint('Business revenue error: $e');
    return [];
  }
});
