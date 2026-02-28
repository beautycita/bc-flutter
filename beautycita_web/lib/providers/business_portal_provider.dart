import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

String _todayISO() => DateTime.now().toIso8601String().substring(0, 10);

String _weekStartISO() {
  final now = DateTime.now();
  final monday = now.subtract(Duration(days: now.weekday - 1));
  return monday.toIso8601String().substring(0, 10);
}

String _monthStartISO() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1).toIso8601String().substring(0, 10);
}

String _monthEndISO() {
  final now = DateTime.now();
  final lastDay = DateTime(now.year, now.month + 1, 0);
  return lastDay.toIso8601String().substring(0, 10);
}

// ── Current Business ─────────────────────────────────────────────────────────

/// Business record owned by the currently authenticated user.
final currentBusinessProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final userId = BCSupabase.client.auth.currentUser?.id;
  if (userId == null) return null;

  final response = await BCSupabase.client
      .from(BCTables.businesses)
      .select()
      .eq('owner_id', userId)
      .maybeSingle();

  return response;
});

// ── Business Stats ───────────────────────────────────────────────────────────

/// Aggregated stats for the business dashboard.
final businessStatsProvider =
    FutureProvider.autoDispose<BusinessStats>((ref) async {
  final biz = await ref.watch(currentBusinessProvider.future);
  if (biz == null) return BusinessStats.empty();

  final bizId = biz['id'] as String;
  final today = _todayISO();
  final weekStart = _weekStartISO();
  final monthStart = _monthStartISO();
  final monthEnd = _monthEndISO();
  final client = BCSupabase.client;

  final results = await Future.wait<dynamic>([
    // 0: appointments today
    client
        .from(BCTables.appointments)
        .select('id')
        .eq('business_id', bizId)
        .gte('starts_at', '${today}T00:00:00')
        .lte('starts_at', '${today}T23:59:59'),
    // 1: appointments this week
    client
        .from(BCTables.appointments)
        .select('id')
        .eq('business_id', bizId)
        .gte('starts_at', '${weekStart}T00:00:00')
        .lte('starts_at', '${today}T23:59:59'),
    // 2: month revenue (sum of amount from payments via appointments)
    client
        .from(BCTables.appointments)
        .select('id')
        .eq('business_id', bizId)
        .gte('starts_at', '${monthStart}T00:00:00')
        .lte('starts_at', '${monthEnd}T23:59:59'),
    // 3: pending confirmations
    client
        .from(BCTables.appointments)
        .select('id')
        .eq('business_id', bizId)
        .eq('status', 'pending'),
    // 4: business info (rating, review count)
    client
        .from(BCTables.businesses)
        .select('average_rating, total_reviews')
        .eq('id', bizId)
        .maybeSingle(),
  ]);

  // Month revenue: get payment amounts for this month's appointment IDs
  final monthApptIds = (results[2] as List)
      .map((a) => (a as Map<String, dynamic>)['id'] as String)
      .toList();

  double revenueMonth = 0;
  if (monthApptIds.isNotEmpty) {
    final payments = await client
        .from(BCTables.payments)
        .select('amount')
        .inFilter('appointment_id', monthApptIds)
        .eq('status', 'completed');
    for (final p in payments as List) {
      revenueMonth += ((p as Map<String, dynamic>)['amount'] as num).toDouble();
    }
  }

  final bizInfo = results[4] as Map<String, dynamic>?;

  return BusinessStats(
    appointmentsToday: (results[0] as List).length,
    appointmentsWeek: (results[1] as List).length,
    revenueMonth: revenueMonth,
    pendingConfirmations: (results[3] as List).length,
    averageRating:
        (bizInfo?['average_rating'] as num?)?.toDouble() ?? 0.0,
    totalReviews: (bizInfo?['total_reviews'] as num?)?.toInt() ?? 0,
  );
});

// ── Monthly Daily Breakdown ──────────────────────────────────────────────────

/// Daily appointment count and revenue for the current month (bar chart data).
final businessMonthlyDailyProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final biz = await ref.watch(currentBusinessProvider.future);
  if (biz == null) return [];

  final bizId = biz['id'] as String;
  final monthStart = _monthStartISO();
  final monthEnd = _monthEndISO();
  final client = BCSupabase.client;

  // Get all appointments for the month
  final appointments = await client
      .from(BCTables.appointments)
      .select('id, starts_at')
      .eq('business_id', bizId)
      .gte('starts_at', '${monthStart}T00:00:00')
      .lte('starts_at', '${monthEnd}T23:59:59')
      .order('starts_at');

  // Get payment amounts for these appointments
  final apptIds = (appointments as List)
      .map((a) => (a as Map<String, dynamic>)['id'] as String)
      .toList();

  final Map<String, double> paymentsByAppt = {};
  if (apptIds.isNotEmpty) {
    final payments = await client
        .from(BCTables.payments)
        .select('appointment_id, amount')
        .inFilter('appointment_id', apptIds)
        .eq('status', 'completed');
    for (final p in payments as List) {
      final pm = p as Map<String, dynamic>;
      final apptId = pm['appointment_id'] as String;
      paymentsByAppt[apptId] =
          (paymentsByAppt[apptId] ?? 0) + (pm['amount'] as num).toDouble();
    }
  }

  // Group by day
  final Map<String, Map<String, dynamic>> daily = {};
  for (final am in appointments) {
    final day = (am['starts_at'] as String).substring(0, 10);
    final apptId = am['id'] as String;
    daily.putIfAbsent(day, () => {'day': day, 'count': 0, 'revenue': 0.0});
    daily[day]!['count'] = (daily[day]!['count'] as int) + 1;
    daily[day]!['revenue'] =
        (daily[day]!['revenue'] as double) + (paymentsByAppt[apptId] ?? 0.0);
  }

  // Return sorted by day
  final result = daily.values.toList()
    ..sort((a, b) => (a['day'] as String).compareTo(b['day'] as String));
  return result;
});

// ── Appointments by Date Range ───────────────────────────────────────────────

/// Appointments within a date range. Family param: ({String start, String end}).
final businessAppointmentsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, ({String start, String end})>(
        (ref, range) async {
  final biz = await ref.watch(currentBusinessProvider.future);
  if (biz == null) return [];

  final bizId = biz['id'] as String;

  final response = await BCSupabase.client
      .from(BCTables.appointments)
      .select()
      .eq('business_id', bizId)
      .gte('starts_at', range.start)
      .lte('starts_at', range.end)
      .order('starts_at');

  return List<Map<String, dynamic>>.from(response as List);
});

// ── Schedule Blocks by Date Range ────────────────────────────────────────────

/// Staff schedule blocks (time-off, breaks) within a date range.
final businessScheduleBlocksProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, ({String start, String end})>(
        (ref, range) async {
  final biz = await ref.watch(currentBusinessProvider.future);
  if (biz == null) return [];

  final bizId = biz['id'] as String;

  // Get staff IDs for this business
  final staffList = await BCSupabase.client
      .from(BCTables.staff)
      .select('id')
      .eq('business_id', bizId);

  final staffIds = (staffList as List)
      .map((s) => (s as Map<String, dynamic>)['id'] as String)
      .toList();

  if (staffIds.isEmpty) return [];

  final response = await BCSupabase.client
      .from(BCTables.staffScheduleBlocks)
      .select()
      .inFilter('staff_id', staffIds)
      .gte('starts_at', range.start)
      .lte('starts_at', range.end)
      .order('starts_at');

  return List<Map<String, dynamic>>.from(response as List);
});

// ── Services ─────────────────────────────────────────────────────────────────

/// All services for the business, ordered by category then name.
final businessServicesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final biz = await ref.watch(currentBusinessProvider.future);
  if (biz == null) return [];

  final bizId = biz['id'] as String;

  final response = await BCSupabase.client
      .from(BCTables.services)
      .select()
      .eq('business_id', bizId)
      .order('category')
      .order('name');

  return List<Map<String, dynamic>>.from(response as List);
});

// ── Staff ────────────────────────────────────────────────────────────────────

/// All staff members for the business, ordered by sort_order.
final businessStaffProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final biz = await ref.watch(currentBusinessProvider.future);
  if (biz == null) return [];

  final bizId = biz['id'] as String;

  final response = await BCSupabase.client
      .from(BCTables.staff)
      .select()
      .eq('business_id', bizId)
      .order('sort_order');

  return List<Map<String, dynamic>>.from(response as List);
});

// ── Staff Schedule ───────────────────────────────────────────────────────────

/// Weekly schedule template for a specific staff member.
final staffScheduleProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, staffId) async {
  final response = await BCSupabase.client
      .from(BCTables.staffSchedules)
      .select()
      .eq('staff_id', staffId)
      .order('day_of_week');

  return List<Map<String, dynamic>>.from(response as List);
});

// ── Staff Services ───────────────────────────────────────────────────────────

/// Services assigned to a specific staff member, with joined service details.
final staffServicesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, staffId) async {
  final response = await BCSupabase.client
      .from(BCTables.staffServices)
      .select('*, services(name, price, duration_minutes)')
      .eq('staff_id', staffId);

  return List<Map<String, dynamic>>.from(response as List);
});

// ── Payments ─────────────────────────────────────────────────────────────────

/// Recent 50 payments for the business (via appointment IDs).
final businessPaymentsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final biz = await ref.watch(currentBusinessProvider.future);
  if (biz == null) return [];

  final bizId = biz['id'] as String;
  final client = BCSupabase.client;

  // Step 1: get appointment IDs for this business
  final appointments = await client
      .from(BCTables.appointments)
      .select('id')
      .eq('business_id', bizId);

  final appointmentIds = (appointments as List)
      .map((a) => (a as Map<String, dynamic>)['id'] as String)
      .toList();

  if (appointmentIds.isEmpty) return [];

  // Step 2: get payments for those appointments
  final response = await client
      .from(BCTables.payments)
      .select()
      .inFilter('appointment_id', appointmentIds)
      .order('created_at', ascending: false)
      .limit(50);

  return List<Map<String, dynamic>>.from(response as List);
});

// ── Disputes ─────────────────────────────────────────────────────────────────

/// Disputes for the business (via appointment IDs).
final businessDisputesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final biz = await ref.watch(currentBusinessProvider.future);
  if (biz == null) return [];

  final bizId = biz['id'] as String;
  final client = BCSupabase.client;

  // Step 1: get appointment IDs for this business
  final appointments = await client
      .from(BCTables.appointments)
      .select('id')
      .eq('business_id', bizId);

  final appointmentIds = (appointments as List)
      .map((a) => (a as Map<String, dynamic>)['id'] as String)
      .toList();

  if (appointmentIds.isEmpty) return [];

  // Step 2: get disputes for those appointments
  final response = await client
      .from(BCTables.disputes)
      .select()
      .inFilter('appointment_id', appointmentIds)
      .order('created_at', ascending: false);

  return List<Map<String, dynamic>>.from(response as List);
});

// ── Reviews ──────────────────────────────────────────────────────────────────

/// Recent 50 reviews for the business.
final businessReviewsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final biz = await ref.watch(currentBusinessProvider.future);
  if (biz == null) return [];

  final bizId = biz['id'] as String;

  final response = await BCSupabase.client
      .from(BCTables.reviews)
      .select()
      .eq('business_id', bizId)
      .order('created_at', ascending: false)
      .limit(50);

  return List<Map<String, dynamic>>.from(response as List);
});

// ── Staff Schedule Blocks (per staff) ────────────────────────────────────────

/// Time-off / break blocks for a specific staff member.
final staffBlocksProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, staffId) async {
  final response = await BCSupabase.client
      .from(BCTables.staffScheduleBlocks)
      .select()
      .eq('staff_id', staffId)
      .order('starts_at', ascending: false);

  return List<Map<String, dynamic>>.from(response as List);
});

// ── Weekly Trend (7 days) ────────────────────────────────────────────────

/// Daily appointment counts and revenue for the past 7 days (sparkline data).
final businessWeeklyTrendProvider =
    FutureProvider.autoDispose<WeeklyTrend>((ref) async {
  final biz = await ref.watch(currentBusinessProvider.future);
  if (biz == null) return WeeklyTrend.empty();

  final bizId = biz['id'] as String;
  final now = DateTime.now();
  final weekAgo = now.subtract(const Duration(days: 6));
  final startDate = weekAgo.toIso8601String().substring(0, 10);
  final endDate = now.toIso8601String().substring(0, 10);
  final client = BCSupabase.client;

  final appointments = await client
      .from(BCTables.appointments)
      .select('id, starts_at, status')
      .eq('business_id', bizId)
      .gte('starts_at', '${startDate}T00:00:00')
      .lte('starts_at', '${endDate}T23:59:59')
      .order('starts_at');

  final apptIds = (appointments as List)
      .map((a) => (a as Map<String, dynamic>)['id'] as String)
      .toList();

  final Map<String, double> paymentsByAppt = {};
  if (apptIds.isNotEmpty) {
    final payments = await client
        .from(BCTables.payments)
        .select('appointment_id, amount')
        .inFilter('appointment_id', apptIds)
        .eq('status', 'completed');
    for (final p in payments as List) {
      final pm = p as Map<String, dynamic>;
      final apptId = pm['appointment_id'] as String;
      paymentsByAppt[apptId] =
          (paymentsByAppt[apptId] ?? 0) + (pm['amount'] as num).toDouble();
    }
  }

  // Build 7-day arrays
  final dailyCounts = <double>[];
  final dailyRevenue = <double>[];
  final dailyPending = <double>[];

  for (var i = 0; i < 7; i++) {
    final date = weekAgo.add(Duration(days: i));
    final dateStr = date.toIso8601String().substring(0, 10);
    var count = 0;
    var revenue = 0.0;
    var pending = 0;

    for (final a in appointments) {
      final aDate = (a['starts_at'] as String).substring(0, 10);
      if (aDate == dateStr) {
        count++;
        revenue += paymentsByAppt[a['id'] as String] ?? 0;
        if (a['status'] == 'pending') pending++;
      }
    }

    dailyCounts.add(count.toDouble());
    dailyRevenue.add(revenue);
    dailyPending.add(pending.toDouble());
  }

  return WeeklyTrend(
    dailyCounts: dailyCounts,
    dailyRevenue: dailyRevenue,
    dailyPending: dailyPending,
  );
});

// ── Models ───────────────────────────────────────────────────────────────────

/// Aggregated business statistics for the dashboard.
class BusinessStats {
  final int appointmentsToday;
  final int appointmentsWeek;
  final double revenueMonth;
  final int pendingConfirmations;
  final double averageRating;
  final int totalReviews;

  const BusinessStats({
    required this.appointmentsToday,
    required this.appointmentsWeek,
    required this.revenueMonth,
    required this.pendingConfirmations,
    required this.averageRating,
    required this.totalReviews,
  });

  factory BusinessStats.empty() => const BusinessStats(
        appointmentsToday: 0,
        appointmentsWeek: 0,
        revenueMonth: 0.0,
        pendingConfirmations: 0,
        averageRating: 0.0,
        totalReviews: 0,
      );
}

/// 7-day trend data for sparklines on KPI cards.
class WeeklyTrend {
  final List<double> dailyCounts;
  final List<double> dailyRevenue;
  final List<double> dailyPending;

  const WeeklyTrend({
    required this.dailyCounts,
    required this.dailyRevenue,
    required this.dailyPending,
  });

  factory WeeklyTrend.empty() => const WeeklyTrend(
        dailyCounts: [],
        dailyRevenue: [],
        dailyPending: [],
      );
}
