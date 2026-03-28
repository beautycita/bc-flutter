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

/// A single commission record row.
@immutable
class CommissionRecord {
  final String id;
  final String businessId;
  final String businessName;
  final String source; // 'appointment' or 'product'
  final double amount;
  final String? referenceId;
  final String period; // 'YYYY-MM'
  final DateTime createdAt;

  const CommissionRecord({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.source,
    required this.amount,
    this.referenceId,
    required this.period,
    required this.createdAt,
  });

  factory CommissionRecord.fromJson(Map<String, dynamic> json) {
    return CommissionRecord(
      id: json['id']?.toString() ?? '',
      businessId: json['business_id']?.toString() ?? '',
      businessName: json['business_name'] as String? ??
          json['businesses']?['business_name'] as String? ?? 'Desconocido',
      source: json['source'] as String? ?? 'appointment',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      referenceId: json['reference_id'] as String?,
      period: json['period'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

/// A single payout record row.
@immutable
class PayoutRecord {
  final String id;
  final String businessId;
  final String businessName;
  final double amount;
  final String status; // 'completed', 'pending', 'failed'
  final String? referenceNumber;
  final String? paymentMethod;
  final String period;
  final DateTime createdAt;

  const PayoutRecord({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.amount,
    required this.status,
    this.referenceNumber,
    this.paymentMethod,
    required this.period,
    required this.createdAt,
  });

  factory PayoutRecord.fromJson(Map<String, dynamic> json) {
    return PayoutRecord(
      id: json['id']?.toString() ?? '',
      businessId: json['business_id']?.toString() ?? '',
      businessName: json['business_name'] as String? ??
          json['businesses']?['business_name'] as String? ?? 'Desconocido',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'pending',
      referenceNumber: json['reference_number'] as String?,
      paymentMethod: json['payment_method'] as String?,
      period: json['period'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

/// A single CFDI record.
@immutable
class CfdiRecord {
  final String id;
  final String businessId;
  final String businessName;
  final String? folio;
  final String? uuidFiscal;
  final String status; // 'timbrado', 'pendiente', 'cancelado'
  final double subtotal;
  final double iva;
  final double total;
  final String period;
  final DateTime createdAt;

  const CfdiRecord({
    required this.id,
    required this.businessId,
    required this.businessName,
    this.folio,
    this.uuidFiscal,
    required this.status,
    required this.subtotal,
    required this.iva,
    required this.total,
    required this.period,
    required this.createdAt,
  });

  factory CfdiRecord.fromJson(Map<String, dynamic> json) {
    return CfdiRecord(
      id: json['id']?.toString() ?? '',
      businessId: json['business_id']?.toString() ?? '',
      businessName: json['business_name'] as String? ??
          json['businesses']?['business_name'] as String? ?? 'Desconocido',
      folio: json['folio'] as String?,
      uuidFiscal: json['uuid_fiscal'] as String?,
      status: json['status'] as String? ?? 'pendiente',
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      iva: (json['iva'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      period: json['period'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

/// Platform-level SAT declaration aggregate.
@immutable
class PlatformSatDeclaration {
  final String id;
  final String period;
  final double totalRevenue;
  final double ivaCollected;
  final double isrCollected;
  final double bankInterest;
  final double uberReferrals;
  final String status;
  final DateTime createdAt;

  const PlatformSatDeclaration({
    required this.id,
    required this.period,
    required this.totalRevenue,
    required this.ivaCollected,
    required this.isrCollected,
    required this.bankInterest,
    required this.uberReferrals,
    required this.status,
    required this.createdAt,
  });

  factory PlatformSatDeclaration.fromJson(Map<String, dynamic> json) {
    return PlatformSatDeclaration(
      id: json['id']?.toString() ?? '',
      period: json['period'] as String? ?? '',
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0,
      ivaCollected: (json['iva_collected'] as num?)?.toDouble() ?? 0,
      isrCollected: (json['isr_collected'] as num?)?.toDouble() ?? 0,
      bankInterest: (json['bank_interest'] as num?)?.toDouble() ?? 0,
      uberReferrals: (json['uber_referrals'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'pendiente',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

/// Per-business SAT monthly report row.
@immutable
class SatMonthlyReport {
  final String id;
  final String businessId;
  final String businessName;
  final String period;
  final double revenue;
  final double ivaWithheld;
  final double isrWithheld;
  final double platformFees;
  final double netPayout;
  final DateTime createdAt;

  const SatMonthlyReport({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.period,
    required this.revenue,
    required this.ivaWithheld,
    required this.isrWithheld,
    required this.platformFees,
    required this.netPayout,
    required this.createdAt,
  });

  factory SatMonthlyReport.fromJson(Map<String, dynamic> json) {
    return SatMonthlyReport(
      id: json['id']?.toString() ?? '',
      businessId: json['business_id']?.toString() ?? '',
      businessName: json['business_name'] as String? ??
          json['businesses']?['business_name'] as String? ?? 'Desconocido',
      period: json['period'] as String? ?? '',
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      ivaWithheld: (json['iva_withheld'] as num?)?.toDouble() ?? 0,
      isrWithheld: (json['isr_withheld'] as num?)?.toDouble() ?? 0,
      platformFees: (json['platform_fees'] as num?)?.toDouble() ?? 0,
      netPayout: (json['net_payout'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

/// A single salon debt record.
@immutable
class SalonDebt {
  final String id;
  final String businessId;
  final String businessName;
  final double originalAmount;
  final double remainingAmount;
  final String? reason;
  final DateTime createdAt;
  final DateTime? clearedAt;

  const SalonDebt({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.originalAmount,
    required this.remainingAmount,
    this.reason,
    required this.createdAt,
    this.clearedAt,
  });

  bool get isPending => remainingAmount > 0;

  factory SalonDebt.fromJson(Map<String, dynamic> json) {
    return SalonDebt(
      id: json['id']?.toString() ?? '',
      businessId: json['business_id']?.toString() ?? '',
      businessName: json['business_name'] as String? ?? 'Desconocido',
      originalAmount: (json['original_amount'] as num?)?.toDouble() ?? 0,
      remainingAmount: (json['remaining_amount'] as num?)?.toDouble() ?? 0,
      reason: json['reason'] as String?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      clearedAt: json['cleared_at'] != null
          ? DateTime.tryParse(json['cleared_at'].toString())
          : null,
    );
  }
}

/// A single debt payment record.
@immutable
class DebtPayment {
  final String id;
  final String debtId;
  final String businessName;
  final double amount;
  final String? note;
  final DateTime createdAt;

  const DebtPayment({
    required this.id,
    required this.debtId,
    required this.businessName,
    required this.amount,
    this.note,
    required this.createdAt,
  });

  factory DebtPayment.fromJson(Map<String, dynamic> json) {
    return DebtPayment(
      id: json['id']?.toString() ?? '',
      debtId: json['debt_id']?.toString() ?? json['salon_debt_id']?.toString() ?? '',
      businessName: json['business_name'] as String? ??
          (json['salon_debts'] is Map ? json['salon_debts']['business_name'] as String? : null) ??
          'Desconocido',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      note: json['note'] as String?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

/// Summary of all outstanding debts.
@immutable
class DebtSummary {
  final double totalOutstanding;
  final int salonsWithDebt;
  final List<SalonDebt> debts;
  final List<DebtPayment> recentPayments;

  const DebtSummary({
    required this.totalOutstanding,
    required this.salonsWithDebt,
    required this.debts,
    required this.recentPayments,
  });

  static const placeholder = DebtSummary(
    totalOutstanding: 0,
    salonsWithDebt: 0,
    debts: [],
    recentPayments: [],
  );
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
    if (kDebugMode) debugPrint('Finance dashboard KPIs error: $e');
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
    if (kDebugMode) debugPrint('Commission breakdown error: $e');
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
    if (kDebugMode) debugPrint('Tax withholding error: $e');
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
    if (kDebugMode) debugPrint('Reconciliation error: $e');
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
    if (kDebugMode) debugPrint('Business revenue error: $e');
    return [];
  }
});

/// Commission records from commission_records table.
final commissionRecordsProvider =
    FutureProvider<List<CommissionRecord>>((ref) async {
  if (!SupabaseClientService.isInitialized) return [];

  try {
    final data = await SupabaseClientService.client
        .from('commission_records')
        .select('*, businesses(business_name)')
        .order('created_at', ascending: false)
        .limit(500);

    return (data as List)
        .map((row) => CommissionRecord.fromJson(row))
        .toList();
  } catch (e) {
    if (kDebugMode) debugPrint('Commission records error: $e');
    return [];
  }
});

/// Payout records from payout_records table.
final payoutRecordsProvider =
    FutureProvider<List<PayoutRecord>>((ref) async {
  if (!SupabaseClientService.isInitialized) return [];

  try {
    final data = await SupabaseClientService.client
        .from('payout_records')
        .select('*, businesses(business_name)')
        .order('created_at', ascending: false)
        .limit(500);

    return (data as List)
        .map((row) => PayoutRecord.fromJson(row))
        .toList();
  } catch (e) {
    if (kDebugMode) debugPrint('Payout records error: $e');
    return [];
  }
});

/// CFDI records from cfdi_records table.
final cfdiRecordsProvider =
    FutureProvider<List<CfdiRecord>>((ref) async {
  if (!SupabaseClientService.isInitialized) return [];

  try {
    final data = await SupabaseClientService.client
        .from('cfdi_records')
        .select('*, businesses(business_name)')
        .order('created_at', ascending: false)
        .limit(500);

    return (data as List)
        .map((row) => CfdiRecord.fromJson(row))
        .toList();
  } catch (e) {
    if (kDebugMode) debugPrint('CFDI records error: $e');
    return [];
  }
});

/// Platform-level SAT declarations.
final platformSatDeclarationsProvider =
    FutureProvider<List<PlatformSatDeclaration>>((ref) async {
  if (!SupabaseClientService.isInitialized) return [];

  try {
    final data = await SupabaseClientService.client
        .from('platform_sat_declarations')
        .select()
        .order('period', ascending: false)
        .limit(24);

    return (data as List)
        .map((row) => PlatformSatDeclaration.fromJson(row))
        .toList();
  } catch (e) {
    if (kDebugMode) debugPrint('Platform SAT declarations error: $e');
    return [];
  }
});

/// Per-business SAT monthly reports.
final satMonthlyReportsProvider =
    FutureProvider<List<SatMonthlyReport>>((ref) async {
  if (!SupabaseClientService.isInitialized) return [];

  try {
    final data = await SupabaseClientService.client
        .from('sat_monthly_reports')
        .select('*, businesses(business_name)')
        .order('period', ascending: false)
        .limit(500);

    return (data as List)
        .map((row) => SatMonthlyReport.fromJson(row))
        .toList();
  } catch (e) {
    if (kDebugMode) debugPrint('SAT monthly reports error: $e');
    return [];
  }
});

/// Salon debts + recent debt payments combined.
final salonDebtSummaryProvider =
    FutureProvider<DebtSummary>((ref) async {
  if (!SupabaseClientService.isInitialized) return DebtSummary.placeholder;

  try {
    final client = SupabaseClientService.client;

    final results = await Future.wait([
      client
          .from('salon_debts')
          .select('*, businesses(name)')
          .order('remaining_amount', ascending: false),
      client
          .from('debt_payments')
          .select('*, salon_debts(business_id, businesses(name))')
          .order('created_at', ascending: false)
          .limit(50),
    ]);

    final debtRows = results[0] as List;
    final paymentRows = results[1] as List;

    final debts = debtRows.map((row) {
      final biz = row['businesses'] as Map<String, dynamic>?;
      return SalonDebt.fromJson({
        ...row,
        'business_name': biz?['name'] ?? 'Desconocido',
      });
    }).toList();

    final payments = paymentRows.map((row) {
      final salonDebt = row['salon_debts'] as Map<String, dynamic>?;
      final biz = salonDebt?['businesses'] as Map<String, dynamic>?;
      return DebtPayment.fromJson({
        ...row,
        'business_name': biz?['name'] ?? 'Desconocido',
      });
    }).toList();

    double totalOutstanding = 0;
    final salonsWithDebt = <String>{};
    for (final d in debts) {
      if (d.remainingAmount > 0) {
        totalOutstanding += d.remainingAmount;
        salonsWithDebt.add(d.businessId);
      }
    }

    return DebtSummary(
      totalOutstanding: totalOutstanding,
      salonsWithDebt: salonsWithDebt.length,
      debts: debts,
      recentPayments: payments,
    );
  } catch (e) {
    if (kDebugMode) debugPrint('Salon debt summary error: $e');
    return DebtSummary.placeholder;
  }
});
