import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/services/supabase_client.dart';

// ---------------------------------------------------------------------------
// Core: current user's business
// ---------------------------------------------------------------------------

final currentBusinessProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final userId = SupabaseClientService.currentUserId;
  if (userId == null) return null;

  final response = await SupabaseClientService.client
      .from('businesses')
      .select()
      .eq('owner_id', userId)
      .maybeSingle();

  return response;
});

final isBusinessOwnerProvider = FutureProvider.autoDispose<bool>((ref) async {
  final biz = await ref.watch(currentBusinessProvider.future);
  if (biz == null) return false;
  return (biz['is_verified'] as bool? ?? false) && (biz['is_active'] as bool? ?? false);
});

/// Application status for the current user's business registration.
/// Returns null if no application, or a string: 'pending', 'approved', 'rejected'.
final applicationStatusProvider = FutureProvider.autoDispose<String?>((ref) async {
  final biz = await ref.watch(currentBusinessProvider.future);
  if (biz == null) return null;
  final isVerified = biz['is_verified'] as bool? ?? false;
  final isActive = biz['is_active'] as bool? ?? false;
  if (isVerified && isActive) return 'approved';
  if (isVerified && !isActive) return 'rejected';
  return 'pending'; // exists but not yet verified
});

// ---------------------------------------------------------------------------
// Dashboard stats
// ---------------------------------------------------------------------------

final businessStatsProvider =
    FutureProvider<BusinessStats>((ref) async {
  final biz = await ref.watch(currentBusinessProvider.future);
  if (biz == null) return BusinessStats.empty();

  final bizId = biz['id'] as String;
  final client = SupabaseClientService.client;
  final now = DateTime.now();
  final today = now.toIso8601String().split('T')[0];
  final weekAgo = now.subtract(const Duration(days: 7)).toIso8601String();
  final firstOfMonth =
      DateTime(now.year, now.month, 1).toIso8601String();

  final todayAppts = client
      .from('appointments').select('id')
      .eq('business_id', bizId)
      .gte('starts_at', '${today}T00:00:00')
      .lte('starts_at', '${today}T23:59:59');
  final weekAppts = client
      .from('appointments').select('id')
      .eq('business_id', bizId)
      .gte('starts_at', weekAgo);
  final monthRevenue = client
      .from('appointments').select('price')
      .eq('business_id', bizId)
      .eq('status', 'completed')
      .gte('created_at', firstOfMonth);
  final pendingQ = client
      .from('appointments').select('id')
      .eq('business_id', bizId)
      .eq('status', 'pending');
  final bizInfo = client
      .from('businesses')
      .select('average_rating, total_reviews')
      .eq('id', bizId)
      .single();

  final results = await Future.wait<dynamic>(
      [todayAppts, weekAppts, monthRevenue, pendingQ, bizInfo]);

  double revenue = 0;
  for (final row in (results[2] as List)) {
    revenue += ((row as Map)['price'] as num?)?.toDouble() ?? 0;
  }

  final bizData = results[4] as Map<String, dynamic>;

  return BusinessStats(
    appointmentsToday: (results[0] as List).length,
    appointmentsWeek: (results[1] as List).length,
    revenueMonth: revenue,
    pendingConfirmations: (results[3] as List).length,
    averageRating: (bizData['average_rating'] as num?)?.toDouble() ?? 0,
    totalReviews: bizData['total_reviews'] as int? ?? 0,
  );
});

// ---------------------------------------------------------------------------
// Monthly daily breakdown (for dashboard bar chart)
// ---------------------------------------------------------------------------

final businessMonthlyDailyProvider =
    FutureProvider<List<({int day, int count, double revenue})>>((ref) async {
  final biz = await ref.watch(currentBusinessProvider.future);
  if (biz == null) return [];

  final bizId = biz['id'] as String;
  final now = DateTime.now();
  final firstOfMonth = DateTime(now.year, now.month, 1);
  final lastOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

  final response = await SupabaseClientService.client
      .from('appointments')
      .select('starts_at, price, status')
      .eq('business_id', bizId)
      .gte('starts_at', firstOfMonth.toIso8601String())
      .lte('starts_at', lastOfMonth.toIso8601String())
      .neq('status', 'cancelled_customer')
      .neq('status', 'cancelled_business');

  final rows = (response as List).cast<Map<String, dynamic>>();

  final Map<int, ({int count, double revenue})> byDay = {};
  for (final row in rows) {
    final dt = DateTime.tryParse(row['starts_at'] as String? ?? '');
    if (dt == null) continue;
    final day = dt.day;
    final price = (row['price'] as num?)?.toDouble() ?? 0;
    final existing = byDay[day];
    byDay[day] = (
      count: (existing?.count ?? 0) + 1,
      revenue: (existing?.revenue ?? 0) + price,
    );
  }

  final daysInMonth = lastOfMonth.day;
  return List.generate(daysInMonth, (i) {
    final day = i + 1;
    final data = byDay[day];
    return (day: day, count: data?.count ?? 0, revenue: data?.revenue ?? 0);
  });
});

// ---------------------------------------------------------------------------
// Appointments for calendar
// ---------------------------------------------------------------------------

final businessAppointmentsProvider = FutureProvider.family<
    List<Map<String, dynamic>>, ({String start, String end})>(
  (ref, range) async {
    final biz = await ref.watch(currentBusinessProvider.future);
    if (biz == null) return [];

    final bizId = biz['id'] as String;
    final response = await SupabaseClientService.client
        .from('appointments')
        .select()
        .eq('business_id', bizId)
        .gte('starts_at', range.start)
        .lte('starts_at', range.end)
        .order('starts_at');

    return (response as List).cast<Map<String, dynamic>>();
  },
);

// ---------------------------------------------------------------------------
// Schedule blocks (lunch, breaks, time-off)
// ---------------------------------------------------------------------------

final businessScheduleBlocksProvider = FutureProvider.family<
    List<Map<String, dynamic>>, ({String start, String end})>(
  (ref, range) async {
    final biz = await ref.watch(currentBusinessProvider.future);
    if (biz == null) return [];

    final bizId = biz['id'] as String;
    final response = await SupabaseClientService.client
        .from('staff_schedule_blocks')
        .select()
        .eq('business_id', bizId)
        .gte('starts_at', range.start)
        .lte('ends_at', range.end)
        .order('starts_at');

    return (response as List).cast<Map<String, dynamic>>();
  },
);

/// Blocks for a specific staff member (for time-off list).
final staffBlocksProvider = FutureProvider.family<
    List<Map<String, dynamic>>, String>(
  (ref, staffId) async {
    final response = await SupabaseClientService.client
        .from('staff_schedule_blocks')
        .select()
        .eq('staff_id', staffId)
        .gte('ends_at', DateTime.now().toIso8601String())
        .order('starts_at');

    return (response as List).cast<Map<String, dynamic>>();
  },
);

// ---------------------------------------------------------------------------
// Services
// ---------------------------------------------------------------------------

final businessServicesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final biz = await ref.watch(currentBusinessProvider.future);
  if (biz == null) return [];

  final bizId = biz['id'] as String;
  final response = await SupabaseClientService.client
      .from('services')
      .select()
      .eq('business_id', bizId)
      .order('category')
      .order('name');

  return (response as List).cast<Map<String, dynamic>>();
});

// ---------------------------------------------------------------------------
// Staff
// ---------------------------------------------------------------------------

final businessStaffProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final biz = await ref.watch(currentBusinessProvider.future);
  if (biz == null) return [];

  final bizId = biz['id'] as String;
  final response = await SupabaseClientService.client
      .from('staff')
      .select()
      .eq('business_id', bizId)
      .order('sort_order');

  return (response as List).cast<Map<String, dynamic>>();
});

final staffScheduleProvider = FutureProvider.family<
    List<Map<String, dynamic>>, String>(
  (ref, staffId) async {
    final response = await SupabaseClientService.client
        .from('staff_schedules')
        .select()
        .eq('staff_id', staffId)
        .order('day_of_week');

    return (response as List).cast<Map<String, dynamic>>();
  },
);

final staffServicesProvider = FutureProvider.family<
    List<Map<String, dynamic>>, String>(
  (ref, staffId) async {
    final response = await SupabaseClientService.client
        .from('staff_services')
        .select('*, services(name, price, duration_minutes)')
        .eq('staff_id', staffId);

    return (response as List).cast<Map<String, dynamic>>();
  },
);

/// All staff→service mappings for the business (staffId → set of serviceIds).
/// Used by drag-and-drop validation to check if a staff can perform a service.
final allStaffServicesProvider =
    FutureProvider<Map<String, Set<String>>>((ref) async {
  final biz = await ref.watch(currentBusinessProvider.future);
  if (biz == null) return {};

  final bizId = biz['id'] as String;

  final staffList = await SupabaseClientService.client
      .from('staff')
      .select('id')
      .eq('business_id', bizId);

  final staffIds = (staffList as List)
      .map((s) => (s as Map<String, dynamic>)['id'] as String)
      .toList();

  if (staffIds.isEmpty) return {};

  final response = await SupabaseClientService.client
      .from('staff_services')
      .select('staff_id, service_id')
      .inFilter('staff_id', staffIds);

  final result = <String, Set<String>>{};
  for (final row in (response as List)) {
    final m = row as Map<String, dynamic>;
    final staffId = m['staff_id'] as String;
    final serviceId = m['service_id'] as String;
    result.putIfAbsent(staffId, () => <String>{}).add(serviceId);
  }
  return result;
});

// ---------------------------------------------------------------------------
// Disputes (business side)
// ---------------------------------------------------------------------------

final businessDisputesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final biz = await ref.watch(currentBusinessProvider.future);
  if (biz == null) return [];

  final bizId = biz['id'] as String;

  // Get appointment IDs for this business
  final appointments = await SupabaseClientService.client
      .from('appointments')
      .select('id')
      .eq('business_id', bizId);

  final appointmentIds = (appointments as List)
      .map((a) => (a as Map)['id'] as String)
      .toList();

  if (appointmentIds.isEmpty) return [];

  final response = await SupabaseClientService.client
      .from('disputes')
      .select()
      .inFilter('appointment_id', appointmentIds)
      .order('created_at', ascending: false);

  return (response as List).cast<Map<String, dynamic>>();
});

// ---------------------------------------------------------------------------
// Payments
// ---------------------------------------------------------------------------

final businessPaymentsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final biz = await ref.watch(currentBusinessProvider.future);
  if (biz == null) return [];

  final bizId = biz['id'] as String;

  final appointments = await SupabaseClientService.client
      .from('appointments')
      .select('id')
      .eq('business_id', bizId);

  final appointmentIds = (appointments as List)
      .map((a) => (a as Map)['id'] as String)
      .toList();

  if (appointmentIds.isEmpty) return [];

  final response = await SupabaseClientService.client
      .from('payments')
      .select()
      .inFilter('appointment_id', appointmentIds)
      .order('created_at', ascending: false)
      .limit(50);

  return (response as List).cast<Map<String, dynamic>>();
});

// ---------------------------------------------------------------------------
// Reviews
// ---------------------------------------------------------------------------

final businessReviewsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final biz = await ref.watch(currentBusinessProvider.future);
  if (biz == null) return [];

  final bizId = biz['id'] as String;
  final response = await SupabaseClientService.client
      .from('reviews')
      .select()
      .eq('business_id', bizId)
      .order('created_at', ascending: false)
      .limit(50);

  return (response as List).cast<Map<String, dynamic>>();
});

// ---------------------------------------------------------------------------
// Staff productivity analytics
// ---------------------------------------------------------------------------

/// Fetches staff analytics for a given period.
/// period: 'week' or 'month'
final staffProductivityProvider = FutureProvider.family<
    StaffProductivityData, String>(
  (ref, period) async {
    final biz = await ref.watch(currentBusinessProvider.future);
    if (biz == null) return StaffProductivityData.empty();

    final bizId = biz['id'] as String;
    final ownerId = biz['owner_id'] as String?;
    final client = SupabaseClientService.client;
    final now = DateTime.now();

    final DateTime periodStart;
    if (period == 'week') {
      periodStart = now.subtract(Duration(days: now.weekday - 1));
    } else {
      periodStart = DateTime(now.year, now.month, 1);
    }
    final startStr = DateTime(periodStart.year, periodStart.month,
            periodStart.day)
        .toUtc()
        .toIso8601String();
    final endStr = now.toUtc().toIso8601String();

    // Fetch staff, completed appointments, and reviews in parallel
    final staffFuture = client
        .from('staff')
        .select()
        .eq('business_id', bizId)
        .order('sort_order');
    final apptsFuture = client
        .from('appointments')
        .select('staff_id, price, starts_at, ends_at, status')
        .eq('business_id', bizId)
        .gte('starts_at', startStr)
        .lte('starts_at', endStr);
    final reviewsFuture = client
        .from('reviews')
        .select('staff_id, rating')
        .eq('business_id', bizId)
        .gte('created_at', startStr)
        .lte('created_at', endStr);

    final results = await Future.wait([staffFuture, apptsFuture, reviewsFuture]);
    final staffRows =
        (results[0] as List).cast<Map<String, dynamic>>();
    final apptRows =
        (results[1] as List).cast<Map<String, dynamic>>();
    final reviewRows =
        (results[2] as List).cast<Map<String, dynamic>>();

    final staffEntries = <StaffProductivityEntry>[];
    for (final s in staffRows) {
      final sid = s['id'] as String;
      final staffAppts = apptRows.where((a) => a['staff_id'] == sid);
      final completed =
          staffAppts.where((a) => a['status'] == 'completed').toList();
      final noShows =
          staffAppts.where((a) => a['status'] == 'no_show').length;
      final totalAppts = staffAppts.length;

      double revenue = 0;
      double hoursWorked = 0;
      final Map<int, double> dailyHours = {}; // weekday -> hours

      for (final a in completed) {
        revenue += (a['price'] as num?)?.toDouble() ?? 0;
        final start = DateTime.tryParse(a['starts_at'] as String? ?? '');
        final end = DateTime.tryParse(a['ends_at'] as String? ?? '');
        if (start != null && end != null) {
          final hrs = end.difference(start).inMinutes / 60.0;
          hoursWorked += hrs;
          dailyHours[start.weekday] =
              (dailyHours[start.weekday] ?? 0) + hrs;
        }
      }

      final staffReviews = reviewRows.where((r) => r['staff_id'] == sid);
      final reviewCount = staffReviews.length;
      double avgRating = 0;
      if (reviewCount > 0) {
        avgRating = staffReviews
                .map((r) => (r['rating'] as num?)?.toDouble() ?? 0)
                .reduce((a, b) => a + b) /
            reviewCount;
      }

      staffEntries.add(StaffProductivityEntry(
        staffId: sid,
        name:
            '${s['first_name'] ?? ''} ${s['last_name'] ?? ''}'.trim(),
        firstName: s['first_name'] as String? ?? '',
        totalAppointments: totalAppts,
        completedAppointments: completed.length,
        noShows: noShows,
        revenue: revenue,
        hoursWorked: hoursWorked,
        dailyHours: dailyHours,
        reviewCount: reviewCount,
        avgRating: avgRating,
        allTimeRating:
            (s['average_rating'] as num?)?.toDouble() ?? 0,
        allTimeReviews: s['total_reviews'] as int? ?? 0,
      ));
    }

    return StaffProductivityData(
      period: period,
      entries: staffEntries,
      ownerId: ownerId,
    );
  },
);

class StaffProductivityEntry {
  final String staffId;
  final String name;
  final String firstName;
  final int totalAppointments;
  final int completedAppointments;
  final int noShows;
  final double revenue;
  final double hoursWorked;
  final Map<int, double> dailyHours; // weekday (1=Mon) -> hours
  final int reviewCount;
  final double avgRating;
  final double allTimeRating;
  final int allTimeReviews;

  const StaffProductivityEntry({
    required this.staffId,
    required this.name,
    required this.firstName,
    required this.totalAppointments,
    required this.completedAppointments,
    required this.noShows,
    required this.revenue,
    required this.hoursWorked,
    required this.dailyHours,
    required this.reviewCount,
    required this.avgRating,
    required this.allTimeRating,
    required this.allTimeReviews,
  });
}

class StaffProductivityData {
  final String period;
  final List<StaffProductivityEntry> entries;
  final String? ownerId;

  const StaffProductivityData({
    required this.period,
    required this.entries,
    this.ownerId,
  });

  factory StaffProductivityData.empty() =>
      const StaffProductivityData(period: 'week', entries: []);

  StaffProductivityEntry? get topEarner {
    if (entries.isEmpty) return null;
    return entries.reduce((a, b) => a.revenue > b.revenue ? a : b);
  }

  StaffProductivityEntry? get mostReviewed {
    if (entries.isEmpty) return null;
    return entries.reduce(
        (a, b) => a.reviewCount > b.reviewCount ? a : b);
  }

  StaffProductivityEntry? get mostBooked {
    if (entries.isEmpty) return null;
    return entries.reduce(
        (a, b) => a.totalAppointments > b.totalAppointments ? a : b);
  }

  double get totalRevenue =>
      entries.fold(0, (sum, e) => sum + e.revenue);

  double get totalHours =>
      entries.fold(0, (sum, e) => sum + e.hoursWorked);
}

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

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
        revenueMonth: 0,
        pendingConfirmations: 0,
        averageRating: 0,
        totalReviews: 0,
      );
}
