import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';

// ── Data classes ──────────────────────────────────────────────────────────────

@immutable
class FinanceKpis {
  final double totalRevenue;
  final double revenueChangePercent;
  final double platformFees;
  final double pendingPayouts;
  final int activeSubscriptions;

  const FinanceKpis({
    required this.totalRevenue,
    required this.revenueChangePercent,
    required this.platformFees,
    required this.pendingPayouts,
    required this.activeSubscriptions,
  });

  static const placeholder = FinanceKpis(
    totalRevenue: 0,
    revenueChangePercent: 0,
    platformFees: 0,
    pendingPayouts: 0,
    activeSubscriptions: 0,
  );
}

@immutable
class MonthlyRevenue {
  final List<double> values;
  final List<String> labels;

  const MonthlyRevenue({required this.values, required this.labels});

  static MonthlyRevenue get placeholder {
    final now = DateTime.now();
    final labels = List.generate(12, (i) {
      final month = now.month - 11 + i;
      final year = now.year + (month <= 0 ? -1 : 0);
      final m = month <= 0 ? month + 12 : month;
      return _monthName(m, year);
    });
    return MonthlyRevenue(values: List.filled(12, 0), labels: labels);
  }

  static String _monthName(int month, int year) {
    const names = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
    ];
    return '${names[month - 1]} $year';
  }
}

@immutable
class PaymentMethodBreakdown {
  final double stripe;
  final double btcpay;
  final double cash;

  const PaymentMethodBreakdown({
    required this.stripe,
    required this.btcpay,
    required this.cash,
  });

  double get total => stripe + btcpay + cash;

  static const placeholder = PaymentMethodBreakdown(
    stripe: 0,
    btcpay: 0,
    cash: 0,
  );
}

@immutable
class PayoutRecord {
  final String id;
  final String salonName;
  final double amount;
  final String status; // 'pending', 'processing', 'completed', 'failed'
  final String method; // 'stripe', 'bank_transfer'
  final DateTime date;

  const PayoutRecord({
    required this.id,
    required this.salonName,
    required this.amount,
    required this.status,
    required this.method,
    required this.date,
  });

  factory PayoutRecord.fromJson(Map<String, dynamic> json) {
    return PayoutRecord(
      id: json['id'] as String,
      salonName: json['salon_name'] as String? ??
          (json['businesses'] != null
              ? json['businesses']['name'] as String? ?? 'Salon'
              : 'Salon'),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'pending',
      method: json['method'] as String? ?? 'stripe',
      date: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  String get statusLabel => switch (status) {
        'pending' => 'Pendiente',
        'processing' => 'Procesando',
        'completed' => 'Completado',
        'failed' => 'Fallido',
        _ => status,
      };
}

@immutable
class PlatformFeeRecord {
  final String id;
  final String? bookingRef;
  final double feeAmount;
  final String status;
  final DateTime date;

  const PlatformFeeRecord({
    required this.id,
    this.bookingRef,
    required this.feeAmount,
    required this.status,
    required this.date,
  });

  factory PlatformFeeRecord.fromJson(Map<String, dynamic> json) {
    return PlatformFeeRecord(
      id: json['id'] as String,
      bookingRef: json['appointment_id'] as String?,
      feeAmount: (json['platform_fee'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'pending',
      date: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

// ── Providers ────────────────────────────────────────────────────────────────

/// Financial KPI metrics.
final financeKpisProvider = FutureProvider<FinanceKpis>((ref) async {
  if (!BCSupabase.isInitialized) return FinanceKpis.placeholder;

  try {
    final client = BCSupabase.client;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();
    final prevMonthStart =
        DateTime(now.year, now.month - 1, 1).toIso8601String();

    // Current month revenue
    final currentPayments = await client
        .from(BCTables.payments)
        .select('amount, platform_fee')
        .gte('created_at', startOfMonth)
        .eq('status', 'completed');

    double totalRevenue = 0;
    double platformFees = 0;
    for (final row in currentPayments) {
      totalRevenue += (row['amount'] as num?)?.toDouble() ?? 0;
      platformFees += (row['platform_fee'] as num?)?.toDouble() ?? 0;
    }

    // Previous month for change %
    final prevPayments = await client
        .from(BCTables.payments)
        .select('amount')
        .gte('created_at', prevMonthStart)
        .lt('created_at', startOfMonth)
        .eq('status', 'completed');

    double prevRevenue = 0;
    for (final row in prevPayments) {
      prevRevenue += (row['amount'] as num?)?.toDouble() ?? 0;
    }

    final changePercent = prevRevenue > 0
        ? ((totalRevenue - prevRevenue) / prevRevenue) * 100
        : 0.0;

    // Pending payouts
    final pendingPayoutsData = await client
        .from(BCTables.payments)
        .select('amount')
        .eq('status', 'pending');

    double pendingPayouts = 0;
    for (final row in pendingPayoutsData) {
      pendingPayouts += (row['amount'] as num?)?.toDouble() ?? 0;
    }

    // Active subscriptions (businesses with active status)
    final subsResult = await client
        .from(BCTables.businesses)
        .select('id')
        .eq('subscription_status', 'active')
        .count();

    return FinanceKpis(
      totalRevenue: totalRevenue,
      revenueChangePercent: changePercent,
      platformFees: platformFees,
      pendingPayouts: pendingPayouts,
      activeSubscriptions: subsResult.count,
    );
  } catch (e) {
    debugPrint('Finance KPIs error: $e');
    return FinanceKpis.placeholder;
  }
});

/// Monthly revenue chart data for the last 12 months.
final monthlyRevenueProvider = FutureProvider<MonthlyRevenue>((ref) async {
  if (!BCSupabase.isInitialized) return MonthlyRevenue.placeholder;

  try {
    final now = DateTime.now();
    final twelveMonthsAgo = DateTime(now.year - 1, now.month, 1);
    final start = twelveMonthsAgo.toIso8601String();

    final data = await BCSupabase.client
        .from(BCTables.payments)
        .select('amount, created_at')
        .gte('created_at', start)
        .eq('status', 'completed');

    // Aggregate by month
    final monthly = <int, double>{};
    for (var i = 0; i < 12; i++) {
      monthly[i] = 0;
    }

    for (final row in data) {
      final dt = DateTime.tryParse(row['created_at'] as String? ?? '');
      if (dt != null) {
        final monthDiff =
            (dt.year - twelveMonthsAgo.year) * 12 +
                (dt.month - twelveMonthsAgo.month);
        if (monthDiff >= 0 && monthDiff < 12) {
          monthly[monthDiff] =
              (monthly[monthDiff] ?? 0) +
                  ((row['amount'] as num?)?.toDouble() ?? 0);
        }
      }
    }

    final values = List.generate(12, (i) => monthly[i] ?? 0);
    final labels = List.generate(12, (i) {
      final d = DateTime(twelveMonthsAgo.year, twelveMonthsAgo.month + i, 1);
      const names = [
        'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
        'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
      ];
      return names[d.month - 1];
    });

    return MonthlyRevenue(values: values, labels: labels);
  } catch (e) {
    debugPrint('Monthly revenue error: $e');
    return MonthlyRevenue.placeholder;
  }
});

/// Payment methods breakdown.
final paymentMethodsProvider =
    FutureProvider<PaymentMethodBreakdown>((ref) async {
  if (!BCSupabase.isInitialized) return PaymentMethodBreakdown.placeholder;

  try {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();

    final data = await BCSupabase.client
        .from(BCTables.payments)
        .select('amount, method')
        .gte('created_at', startOfMonth)
        .eq('status', 'completed');

    double stripe = 0;
    double btcpay = 0;
    double cash = 0;

    for (final row in data) {
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      final method = row['method'] as String? ?? '';
      switch (method) {
        case 'stripe':
          stripe += amount;
        case 'btcpay':
        case 'bitcoin':
          btcpay += amount;
        case 'cash':
        case 'efectivo':
          cash += amount;
        default:
          stripe += amount; // default to stripe
      }
    }

    return PaymentMethodBreakdown(
      stripe: stripe,
      btcpay: btcpay,
      cash: cash,
    );
  } catch (e) {
    debugPrint('Payment methods error: $e');
    return PaymentMethodBreakdown.placeholder;
  }
});

/// Recent payout history.
final payoutHistoryProvider = FutureProvider<List<PayoutRecord>>((ref) async {
  if (!BCSupabase.isInitialized) return [];

  try {
    final data = await BCSupabase.client
        .from(BCTables.payments)
        .select('*, businesses!salon_id(name)')
        .order('created_at', ascending: false)
        .limit(20);

    return (data as List).map((row) {
      final bizData = row['businesses'] as Map<String, dynamic>?;
      final json = Map<String, dynamic>.from(row);
      if (bizData != null) {
        json['salon_name'] = bizData['name'] ?? 'Salon';
      }
      return PayoutRecord.fromJson(json);
    }).toList();
  } catch (e) {
    debugPrint('Payout history error: $e');
    return [];
  }
});

/// Platform fee collection records.
final platformFeesProvider =
    FutureProvider<List<PlatformFeeRecord>>((ref) async {
  if (!BCSupabase.isInitialized) return [];

  try {
    final data = await BCSupabase.client
        .from(BCTables.payments)
        .select('id, appointment_id, platform_fee, status, created_at')
        .gt('platform_fee', 0)
        .order('created_at', ascending: false)
        .limit(20);

    return (data as List)
        .map((row) => PlatformFeeRecord.fromJson(row))
        .toList();
  } catch (e) {
    debugPrint('Platform fees error: $e');
    return [];
  }
});
