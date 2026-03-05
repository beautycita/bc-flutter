/// Demo-mode provider overrides that return static Salon de Vallarta data.
/// Used by DemoShell via ProviderScope overrides — no Supabase calls.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'business_portal_provider.dart';
import '../data/demo_data.dart';

/// True when running inside the demo portal. Pages check this to hide write
/// operations (add/edit/delete buttons, forms, etc.).
final isDemoProvider = StateProvider<bool>((ref) => false);

/// All provider overrides needed for demo mode.
List<Override> get demoProviderOverrides => [
      isDemoProvider.overrideWith((ref) => true),
      currentBusinessProvider.overrideWith((ref) async => DemoData.business),
      businessStatsProvider.overrideWith((ref) async => _demoStats()),
      businessWeeklyTrendProvider.overrideWith((ref) async => _demoWeeklyTrend()),
      businessMonthlyDailyProvider.overrideWith((ref) async => _demoMonthlyDaily()),
      businessServicesProvider.overrideWith((ref) async => DemoData.services),
      businessStaffProvider.overrideWith((ref) async => DemoData.staff),
      businessReviewsProvider.overrideWith((ref) async => DemoData.reviews),
      businessDisputesProvider.overrideWith((ref) async => DemoData.disputes),
      businessPaymentsProvider.overrideWith((ref) async => DemoData.payments),
    ];

// ── Computed demo stats ─────────────────────────────────────────────────────

BusinessStats _demoStats() {
  final appts = DemoData.appointments;
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

WeeklyTrend _demoWeeklyTrend() {
  final now = DateTime.now();
  final appts = DemoData.appointments;
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

List<Map<String, dynamic>> _demoMonthlyDaily() {
  final now = DateTime.now();
  final appts = DemoData.appointments;
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
