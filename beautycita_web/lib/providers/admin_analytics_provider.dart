import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';

// ── Data classes ──────────────────────────────────────────────────────────────

@immutable
class BookingsOverTime {
  /// Daily booking counts for the last 30 days.
  final List<int> counts;
  final List<String> labels;

  const BookingsOverTime({required this.counts, required this.labels});

  static BookingsOverTime get placeholder {
    final now = DateTime.now();
    final labels = List.generate(30, (i) {
      final d = now.subtract(Duration(days: 29 - i));
      return '${d.day}/${d.month}';
    });
    return BookingsOverTime(counts: List.filled(30, 0), labels: labels);
  }
}

@immutable
class UserGrowth {
  /// Cumulative user count per day for the last 30 days.
  final List<int> cumulativeCounts;
  final List<String> labels;

  const UserGrowth({required this.cumulativeCounts, required this.labels});

  static UserGrowth get placeholder {
    final now = DateTime.now();
    final labels = List.generate(30, (i) {
      final d = now.subtract(Duration(days: 29 - i));
      return '${d.day}/${d.month}';
    });
    return UserGrowth(cumulativeCounts: List.filled(30, 0), labels: labels);
  }
}

@immutable
class RevenueByCategoryItem {
  final String categoryName;
  final double revenue;

  const RevenueByCategoryItem({
    required this.categoryName,
    required this.revenue,
  });
}

@immutable
class PeakHoursData {
  /// 7 rows (Mon=0..Sun=6) x 24 columns (hour 0..23), count of bookings
  final List<List<int>> grid;

  const PeakHoursData({required this.grid});

  int get maxCount {
    int m = 0;
    for (final row in grid) {
      for (final v in row) {
        if (v > m) m = v;
      }
    }
    return m;
  }

  static PeakHoursData get placeholder => PeakHoursData(
        grid: List.generate(7, (_) => List.filled(24, 0)),
      );
}

@immutable
class RetentionMetrics {
  final int newUsersThisMonth;
  final int returningUsers;
  final double churnRate;

  const RetentionMetrics({
    required this.newUsersThisMonth,
    required this.returningUsers,
    required this.churnRate,
  });

  static const placeholder = RetentionMetrics(
    newUsersThisMonth: 0,
    returningUsers: 0,
    churnRate: 0,
  );
}

@immutable
class TopSalonEntry {
  final String salonName;
  final int bookingCount;
  final double revenue;

  const TopSalonEntry({
    required this.salonName,
    required this.bookingCount,
    required this.revenue,
  });
}

// ── Providers ────────────────────────────────────────────────────────────────

/// Bookings per day for the last 30 days.
final bookingsOverTimeProvider =
    FutureProvider<BookingsOverTime>((ref) async {
  if (!BCSupabase.isInitialized) return BookingsOverTime.placeholder;

  try {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final start = DateTime(thirtyDaysAgo.year, thirtyDaysAgo.month,
            thirtyDaysAgo.day)
        .toIso8601String();

    final data = await BCSupabase.client
        .from(BCTables.appointments)
        .select('created_at')
        .gte('created_at', start);

    final baseDate = DateTime(
        thirtyDaysAgo.year, thirtyDaysAgo.month, thirtyDaysAgo.day);
    final daily = List.filled(30, 0);

    for (final row in data) {
      final dt = DateTime.tryParse(row['created_at'] as String? ?? '');
      if (dt != null) {
        final idx = dt.difference(baseDate).inDays;
        if (idx >= 0 && idx < 30) daily[idx]++;
      }
    }

    final labels = List.generate(30, (i) {
      final d = baseDate.add(Duration(days: i));
      return '${d.day}/${d.month}';
    });

    return BookingsOverTime(counts: daily, labels: labels);
  } catch (e) {
    debugPrint('Bookings over time error: $e');
    return BookingsOverTime.placeholder;
  }
});

/// Cumulative user registrations over the last 30 days.
final userGrowthProvider = FutureProvider<UserGrowth>((ref) async {
  if (!BCSupabase.isInitialized) return UserGrowth.placeholder;

  try {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final start = DateTime(thirtyDaysAgo.year, thirtyDaysAgo.month,
            thirtyDaysAgo.day)
        .toIso8601String();

    // Total users before the period
    final beforeResult = await BCSupabase.client
        .from(BCTables.profiles)
        .select('id')
        .lt('created_at', start)
        .count();
    final baseLine = beforeResult.count;

    // New users during the period
    final data = await BCSupabase.client
        .from(BCTables.profiles)
        .select('created_at')
        .gte('created_at', start);

    final baseDate = DateTime(
        thirtyDaysAgo.year, thirtyDaysAgo.month, thirtyDaysAgo.day);
    final daily = List.filled(30, 0);

    for (final row in data) {
      final dt = DateTime.tryParse(row['created_at'] as String? ?? '');
      if (dt != null) {
        final idx = dt.difference(baseDate).inDays;
        if (idx >= 0 && idx < 30) daily[idx]++;
      }
    }

    // Build cumulative
    final cumulative = List.filled(30, 0);
    var running = baseLine;
    for (var i = 0; i < 30; i++) {
      running += daily[i];
      cumulative[i] = running;
    }

    final labels = List.generate(30, (i) {
      final d = baseDate.add(Duration(days: i));
      return '${d.day}/${d.month}';
    });

    return UserGrowth(cumulativeCounts: cumulative, labels: labels);
  } catch (e) {
    debugPrint('User growth error: $e');
    return UserGrowth.placeholder;
  }
});

/// Revenue by service category.
final revenueByCategoryProvider =
    FutureProvider<List<RevenueByCategoryItem>>((ref) async {
  if (!BCSupabase.isInitialized) return [];

  try {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();

    // Get payments with appointment data
    final data = await BCSupabase.client
        .from(BCTables.payments)
        .select('amount, appointments!appointment_id(service_name)')
        .gte('created_at', startOfMonth)
        .eq('status', 'succeeded');

    final byCategory = <String, double>{};
    for (final row in data) {
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      final apt = row['appointments'] as Map<String, dynamic>?;
      final category =
          apt?['service_name'] as String? ?? 'Sin categoria';
      byCategory[category] = (byCategory[category] ?? 0) + amount;
    }

    final sorted = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted
        .map((e) =>
            RevenueByCategoryItem(categoryName: e.key, revenue: e.value))
        .toList();
  } catch (e) {
    debugPrint('Revenue by category error: $e');
    return [];
  }
});

/// Peak hours heatmap data.
final peakHoursProvider = FutureProvider<PeakHoursData>((ref) async {
  if (!BCSupabase.isInitialized) return PeakHoursData.placeholder;

  try {
    final now = DateTime.now();
    final thirtyDaysAgo =
        now.subtract(const Duration(days: 30)).toIso8601String();

    final data = await BCSupabase.client
        .from(BCTables.appointments)
        .select('starts_at')
        .gte('starts_at', thirtyDaysAgo);

    final grid = List.generate(7, (_) => List.filled(24, 0));

    for (final row in data) {
      final dt =
          DateTime.tryParse(row['starts_at'] as String? ?? '');
      if (dt != null) {
        final dayIndex = dt.weekday - 1; // Mon=0..Sun=6
        final hour = dt.hour;
        grid[dayIndex][hour]++;
      }
    }

    return PeakHoursData(grid: grid);
  } catch (e) {
    debugPrint('Peak hours error: $e');
    return PeakHoursData.placeholder;
  }
});

/// Retention metrics (new, returning, churn).
final retentionMetricsProvider =
    FutureProvider<RetentionMetrics>((ref) async {
  if (!BCSupabase.isInitialized) return RetentionMetrics.placeholder;

  try {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();
    final prevMonthStart =
        DateTime(now.year, now.month - 1, 1).toIso8601String();

    // New users this month
    final newResult = await BCSupabase.client
        .from(BCTables.profiles)
        .select('id')
        .gte('created_at', startOfMonth)
        .count();

    // Users who booked this month AND last month (returning)
    final thisMonthBookers = await BCSupabase.client
        .from(BCTables.appointments)
        .select('user_id')
        .gte('created_at', startOfMonth);

    final prevMonthBookers = await BCSupabase.client
        .from(BCTables.appointments)
        .select('user_id')
        .gte('created_at', prevMonthStart)
        .lt('created_at', startOfMonth);

    final currentUserIds = <String>{};
    for (final row in thisMonthBookers) {
      final uid = row['user_id'] as String?;
      if (uid != null) currentUserIds.add(uid);
    }

    final prevUserIds = <String>{};
    for (final row in prevMonthBookers) {
      final uid = row['user_id'] as String?;
      if (uid != null) prevUserIds.add(uid);
    }

    final returning = currentUserIds.intersection(prevUserIds).length;
    final churned = prevUserIds.difference(currentUserIds).length;
    final churnRate =
        prevUserIds.isNotEmpty ? (churned / prevUserIds.length) * 100 : 0.0;

    return RetentionMetrics(
      newUsersThisMonth: newResult.count,
      returningUsers: returning,
      churnRate: churnRate,
    );
  } catch (e) {
    debugPrint('Retention metrics error: $e');
    return RetentionMetrics.placeholder;
  }
});

/// Top 5 salons by booking count.
final topSalonsProvider =
    FutureProvider<List<TopSalonEntry>>((ref) async {
  if (!BCSupabase.isInitialized) return [];

  try {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();

    final data = await BCSupabase.client
        .from(BCTables.appointments)
        .select('business_id, businesses!business_id(name)')
        .gte('created_at', startOfMonth);

    // Aggregate
    final bySalon = <String, (String name, int count)>{};
    for (final row in data) {
      final bizId = row['business_id'] as String? ?? '';
      final bizData = row['businesses'] as Map<String, dynamic>?;
      final name = bizData?['name'] as String? ?? 'Salon';
      final prev = bySalon[bizId];
      bySalon[bizId] = (name, (prev?.$2 ?? 0) + 1);
    }

    final sorted = bySalon.entries.toList()
      ..sort((a, b) => b.value.$2.compareTo(a.value.$2));

    return sorted.take(5).map((e) {
      return TopSalonEntry(
        salonName: e.value.$1,
        bookingCount: e.value.$2,
        revenue: 0, // Would need payment join; show booking count instead
      );
    }).toList();
  } catch (e) {
    debugPrint('Top salons error: $e');
    return [];
  }
});
