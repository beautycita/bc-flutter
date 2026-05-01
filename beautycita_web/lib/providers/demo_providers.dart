/// Demo-mode provider overrides that return static Salon de Vallarta data.
/// Used by DemoShell via ProviderScope overrides — no Supabase calls.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'business_portal_provider.dart';
import 'demo_session_store.dart';
import '../data/demo_data.dart';
import 'package:beautycita_core/beautycita_core.dart';

/// True when running inside the demo portal. Pages check this to hide write
/// operations (add/edit/delete buttons, forms, etc.).
final isDemoProvider = StateProvider<bool>((ref) => false);

/// Whether the current user has a verified phone number.
/// In demo mode, this gates interactive features like drag-and-drop reschedule.
final demoPhoneVerifiedProvider = FutureProvider<bool>((ref) async {
  final user = BCSupabase.client.auth.currentUser;
  if (user == null) return false;
  final res = await BCSupabase.client
      .from(BCTables.profiles)
      .select('phone')
      .eq('id', user.id)
      .maybeSingle();
  final phone = res?['phone'] as String?;
  return phone != null && phone.isNotEmpty;
});

/// All provider overrides needed for demo mode.
///
/// Reads that depend on appointments (stats, trends, payments, the calendar
/// list itself) all watch [demoSessionStoreProvider] so the dashboard and
/// calendar both update in lock-step when a session mutation lands.
List<Override> get demoProviderOverrides => [
      isDemoProvider.overrideWith((ref) => true),
      currentBusinessProvider.overrideWith((ref) async => DemoData.business),
      businessStatsProvider.overrideWith((ref) async {
        final session = ref.watch(demoSessionStoreProvider);
        return _demoStats(session.appointments);
      }),
      businessWeeklyTrendProvider.overrideWith((ref) async {
        final session = ref.watch(demoSessionStoreProvider);
        return _demoWeeklyTrend(session.appointments);
      }),
      businessMonthlyDailyProvider.overrideWith((ref) async {
        final session = ref.watch(demoSessionStoreProvider);
        return _demoMonthlyDaily(session.appointments);
      }),
      businessServicesProvider.overrideWith((ref) async => DemoData.services),
      businessStaffProvider.overrideWith((ref) async => DemoData.staff),
      businessReviewsProvider.overrideWith((ref) async => DemoData.reviews),
      businessDisputesProvider.overrideWith((ref) async => DemoData.disputes),
      businessPaymentsProvider.overrideWith((ref) async {
        final session = ref.watch(demoSessionStoreProvider);
        return _demoPayments(session.appointments);
      }),
      businessAppointmentsProvider.overrideWith((ref, range) async {
        final session = ref.watch(demoSessionStoreProvider);
        return session.appointments.where((a) {
          final startsAt = a['starts_at'] as String;
          return startsAt.compareTo(range.start) >= 0 &&
              startsAt.compareTo(range.end) <= 0;
        }).toList();
      }),
      businessScheduleBlocksProvider.overrideWith((ref, range) async => []),
      allStaffServicesProvider.overrideWith((ref) async => _demoStaffServices()),
      // Dashboard finance cards — synthetic but coherent with appointments.
      businessTaxSummaryProvider.overrideWith((ref) async {
        final session = ref.watch(demoSessionStoreProvider);
        return _demoTaxSummary(session.appointments);
      }),
      businessCfdiProvider.overrideWith((ref) async => DemoData.cfdiRecords),
      businessPayoutRecordsProvider
          .overrideWith((ref) async => DemoData.payoutRecords),
      businessCommissionRecordsProvider
          .overrideWith((ref) async => DemoData.commissionRecords),
    ];

// ── Computed demo stats ─────────────────────────────────────────────────────

BusinessStats _demoStats(List<Map<String, dynamic>> appts) {
  final now = DateTime.now();
  final todayStr = DateTime(now.year, now.month, now.day)
      .toIso8601String()
      .substring(0, 10);
  final weekStart = now
      .subtract(Duration(days: now.weekday - 1))
      .toIso8601String()
      .substring(0, 10);

  int todayCount = 0;
  int weekCount = 0;
  double monthRevenue = 0;
  int pending = 0;

  final monthStart = DateTime(now.year, now.month, 1)
      .toIso8601String()
      .substring(0, 10);

  for (final a in appts) {
    final dateStr = (a['starts_at'] as String).substring(0, 10);
    if (dateStr == todayStr) todayCount++;
    if (dateStr.compareTo(weekStart) >= 0 &&
        dateStr.compareTo(todayStr) <= 0) {
      weekCount++;
    }
    if (dateStr.compareTo(monthStart) >= 0 &&
        (a['status'] == 'completed' || a['status'] == 'confirmed')) {
      monthRevenue += (a['price'] as num).toDouble();
    }
    if (a['status'] == 'pending') pending++;
  }

  return BusinessStats(
    appointmentsToday: todayCount,
    appointmentsWeek: weekCount,
    revenueMonth: monthRevenue,
    pendingConfirmations: pending,
    averageRating: 4.75,
    totalReviews: 16,
  );
}

WeeklyTrend _demoWeeklyTrend(List<Map<String, dynamic>> appts) {
  final now = DateTime.now();
  final counts = <double>[];
  final revenue = <double>[];
  final pendingList = <double>[];

  for (var i = 6; i >= 0; i--) {
    final date = now.subtract(Duration(days: i));
    final dateStr =
        DateTime(date.year, date.month, date.day)
            .toIso8601String()
            .substring(0, 10);
    int c = 0;
    double r = 0;
    for (final a in appts) {
      final aDate = (a['starts_at'] as String).substring(0, 10);
      if (aDate == dateStr) {
        c++;
        if (a['payment_status'] == 'paid') {
          r += (a['price'] as num).toDouble();
        }
      }
    }
    counts.add(c.toDouble());
    revenue.add(r);
    pendingList.add(0);
  }

  return WeeklyTrend(
    dailyCounts: counts,
    dailyRevenue: revenue,
    dailyPending: pendingList,
  );
}

Map<String, Set<String>> _demoStaffServices() {
  // Built from the immutable baseline — staff↔service pairings don't change
  // on reschedule, so no need to read the session store here.
  final result = <String, Set<String>>{};
  for (final a in DemoData.appointments) {
    final staffId = a['staff_id'] as String?;
    final serviceId = a['service_id'] as String?;
    if (staffId != null && serviceId != null) {
      result.putIfAbsent(staffId, () => <String>{}).add(serviceId);
    }
  }
  return result;
}

List<Map<String, dynamic>> _demoPayments(List<Map<String, dynamic>> appts) {
  return appts
      .where((a) =>
          a['payment_status'] == 'paid' || a['payment_status'] == 'refunded')
      .map((a) => {
            'id': 'pay-${a['id']}',
            'appointment_id': a['id'],
            // Payments table exposes `amount` (pesos) — the table/row widgets
            // read that field. Without it they all render $0.
            'amount': (a['price'] as num?)?.toDouble() ?? 0,
            'amount_centavos': a['payment_amount_centavos'],
            'beautycita_fee_centavos': a['beautycita_fee_centavos'],
            'method': a['payment_method'] ?? 'card',
            'status':
                a['payment_status'] == 'refunded' ? 'refunded' : 'completed',
            'created_at': a['starts_at'],
          })
      .toList();
}

TaxSummary _demoTaxSummary(List<Map<String, dynamic>> appts) {
  final ytd = DemoData.taxYtdFromAppts(appts);
  // Synthetic year-to-date expenses so the "Net" panel reflects something
  // believable for a busy salon (rent, utilities, supplies).
  const ytdExpenses = 28400.0;
  final now = DateTime.now();
  return TaxSummary(
    ytdRevenue: ytd.ytdRevenue,
    ytdExpenses: ytdExpenses,
    outstandingDebt: 0,
    daysUntilYearEnd: DateTime(now.year, 12, 31).difference(now).inDays,
  );
}

List<Map<String, dynamic>> _demoMonthlyDaily(List<Map<String, dynamic>> appts) {
  final now = DateTime.now();
  final Map<String, Map<String, dynamic>> daily = {};

  for (final a in appts) {
    final dateStr = (a['starts_at'] as String).substring(0, 10);
    final month = dateStr.substring(0, 7);
    final currentMonth =
        DateTime(now.year, now.month, 1).toIso8601String().substring(0, 7);
    if (month != currentMonth) continue;

    daily.putIfAbsent(
        dateStr, () => {'day': dateStr, 'count': 0, 'revenue': 0.0});
    daily[dateStr]!['count'] = (daily[dateStr]!['count'] as int) + 1;
    if (a['payment_status'] == 'paid') {
      daily[dateStr]!['revenue'] = (daily[dateStr]!['revenue'] as double) +
          (a['price'] as num).toDouble();
    }
  }

  final result = daily.values.toList()
    ..sort((a, b) => (a['day'] as String).compareTo(b['day'] as String));
  return result;
}
