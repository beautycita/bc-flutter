import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';

// ── Period selector state ─────────────────────────────────────────────────────

@immutable
class TaxReportPeriod {
  final int year;
  final int month;

  const TaxReportPeriod({required this.year, required this.month});

  TaxReportPeriod copyWith({int? year, int? month}) =>
      TaxReportPeriod(year: year ?? this.year, month: month ?? this.month);
}

final taxReportPeriodProvider = StateProvider<TaxReportPeriod>((ref) {
  final now = DateTime.now();
  return TaxReportPeriod(year: now.year, month: now.month);
});

// ── Report data models ────────────────────────────────────────────────────────

@immutable
class TaxReportSummary {
  final int totalTransactions;
  final double isrWithheld;
  final double ivaWithheld;
  final double platformFees;
  final double grossRevenue;
  final double netPayout;

  const TaxReportSummary({
    required this.totalTransactions,
    required this.isrWithheld,
    required this.ivaWithheld,
    required this.platformFees,
    required this.grossRevenue,
    required this.netPayout,
  });

  static const empty = TaxReportSummary(
    totalTransactions: 0,
    isrWithheld: 0,
    ivaWithheld: 0,
    platformFees: 0,
    grossRevenue: 0,
    netPayout: 0,
  );
}

@immutable
class TaxReportBusiness {
  final String businessId;
  final String businessName;
  final int transactions;
  final double grossRevenue;
  final double isrWithheld;
  final double ivaWithheld;
  final double platformFee;
  final double netPayout;

  const TaxReportBusiness({
    required this.businessId,
    required this.businessName,
    required this.transactions,
    required this.grossRevenue,
    required this.isrWithheld,
    required this.ivaWithheld,
    required this.platformFee,
    required this.netPayout,
  });

  factory TaxReportBusiness.fromJson(Map<String, dynamic> json) {
    return TaxReportBusiness(
      businessId: (json['business_id'] ?? '') as String,
      businessName: (json['business_name'] ?? 'Desconocido') as String,
      transactions: (json['transaction_count'] as num?)?.toInt() ?? 0,
      grossRevenue: (json['gross_revenue'] as num?)?.toDouble() ?? 0,
      isrWithheld: (json['isr_withheld'] as num?)?.toDouble() ?? 0,
      ivaWithheld: (json['iva_withheld'] as num?)?.toDouble() ?? 0,
      platformFee: (json['platform_fee'] as num?)?.toDouble() ?? 0,
      netPayout: (json['provider_net'] as num?)?.toDouble() ?? 0,
    );
  }
}

@immutable
class TaxReport {
  final TaxReportSummary summary;
  final List<TaxReportBusiness> businesses;

  const TaxReport({required this.summary, required this.businesses});

  static const empty = TaxReport(
    summary: TaxReportSummary.empty,
    businesses: [],
  );
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Null means "not yet generated" (user must press button).
final adminTaxReportProvider =
    StateProvider<AsyncValue<TaxReport>?>((ref) => null);

class AdminTaxReportNotifier {
  static Future<void> generate(
    WidgetRef ref,
    TaxReportPeriod period,
  ) async {
    ref.read(adminTaxReportProvider.notifier).state =
        const AsyncValue.loading();
    try {
      final client = BCSupabase.client;

      // Call sat-reporting edge function
      final response = await client.functions.invoke(
        'sat-reporting',
        body: {
          'year': period.year,
          'month': period.month,
          'action': 'generate',
        },
      );

      if (response.status != 200) {
        final data = response.data as Map<String, dynamic>?;
        throw Exception(data?['error'] ?? 'Error ${response.status}');
      }

      final data = response.data as Map<String, dynamic>;

      // Build summary from edge function response or fall back to DB query
      final summary = TaxReportSummary(
        totalTransactions:
            (data['total_transactions'] as num?)?.toInt() ?? 0,
        isrWithheld:
            (data['total_isr_withheld'] as num?)?.toDouble() ?? 0,
        ivaWithheld:
            (data['total_iva_withheld'] as num?)?.toDouble() ?? 0,
        platformFees:
            (data['total_platform_fees'] as num?)?.toDouble() ?? 0,
        grossRevenue:
            (data['total_gross_revenue'] as num?)?.toDouble() ?? 0,
        netPayout:
            (data['total_net_payout'] as num?)?.toDouble() ?? 0,
      );

      final rawBusinesses =
          (data['businesses'] as List<dynamic>?) ?? [];
      final businesses = rawBusinesses
          .map((e) =>
              TaxReportBusiness.fromJson(e as Map<String, dynamic>))
          .toList();

      ref.read(adminTaxReportProvider.notifier).state =
          AsyncValue.data(TaxReport(
        summary: summary,
        businesses: businesses,
      ));
    } catch (e, st) {
      debugPrint('AdminTaxReportNotifier.generate error: $e');
      ref.read(adminTaxReportProvider.notifier).state =
          AsyncValue.error(e, st);
    }
  }
}

// ── Sort state for the business breakdown table ───────────────────────────────

@immutable
class TaxTableSort {
  final String column;
  final bool ascending;

  const TaxTableSort({
    this.column = 'gross_revenue',
    this.ascending = false,
  });

  TaxTableSort copyWith({String? column, bool? ascending}) => TaxTableSort(
        column: column ?? this.column,
        ascending: ascending ?? this.ascending,
      );
}

final taxTableSortProvider =
    StateProvider<TaxTableSort>((ref) => const TaxTableSort());
