import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';

// ── Data classes ──────────────────────────────────────────────────────────────

@immutable
class DashboardKpis {
  final double monthlyRevenue;
  final double revenueChangePercent;
  final int activeUsers;
  final int bookingsToday;
  final int registeredSalons;

  const DashboardKpis({
    required this.monthlyRevenue,
    required this.revenueChangePercent,
    required this.activeUsers,
    required this.bookingsToday,
    required this.registeredSalons,
  });

  /// Placeholder data for when Supabase is offline.
  static const placeholder = DashboardKpis(
    monthlyRevenue: 0,
    revenueChangePercent: 0,
    activeUsers: 0,
    bookingsToday: 0,
    registeredSalons: 0,
  );
}

@immutable
class ActivityItem {
  final String id;
  final String type; // 'booking', 'user', 'salon', 'cancellation'
  final String title;
  final String subtitle;
  final DateTime timestamp;

  const ActivityItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timestamp,
  });
}

@immutable
class DashboardAlerts {
  final int pendingDisputes;
  final int unverifiedSalons;
  final int failedPayments;

  const DashboardAlerts({
    required this.pendingDisputes,
    required this.unverifiedSalons,
    required this.failedPayments,
  });

  int get total => pendingDisputes + unverifiedSalons + failedPayments;

  static const placeholder = DashboardAlerts(
    pendingDisputes: 0,
    unverifiedSalons: 0,
    failedPayments: 0,
  );
}

@immutable
class WeeklyBookings {
  /// 7 entries, Mon=0 through Sun=6
  final List<int> counts;
  final List<String> labels;

  const WeeklyBookings({required this.counts, required this.labels});

  static const placeholder = WeeklyBookings(
    counts: [0, 0, 0, 0, 0, 0, 0],
    labels: ['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom'],
  );
}

@immutable
class RevenueTrend {
  /// Daily revenue values for the last 30 days.
  final List<double> values;
  final List<String> labels;

  const RevenueTrend({required this.values, required this.labels});

  static RevenueTrend get placeholder {
    final now = DateTime.now();
    final labels = List.generate(30, (i) {
      final d = now.subtract(Duration(days: 29 - i));
      return '${d.day}/${d.month}';
    });
    return RevenueTrend(
      values: List.filled(30, 0),
      labels: labels,
    );
  }
}

// ── Providers ────────────────────────────────────────────────────────────────

/// KPI metrics for the dashboard header cards.
final dashboardKpisProvider = FutureProvider<DashboardKpis>((ref) async {
  if (!BCSupabase.isInitialized) return DashboardKpis.placeholder;

  try {
    final client = BCSupabase.client;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();

    // Run count queries in parallel
    final countResults = await Future.wait([
      // Bookings today
      client
          .from('appointments')
          .select('id')
          .gte('created_at', startOfDay)
          .count(),
      // Active users (profiles count)
      client.from('profiles').select('id').count(),
      // Registered salons
      client.from('businesses').select('id').count(),
    ]);

    final bookingsToday = countResults[0].count;
    final activeUsers = countResults[1].count;
    final registeredSalons = countResults[2].count;

    // Revenue this month (sum of payments)
    final paymentRows = await client
        .from('payments')
        .select('amount')
        .gte('created_at', startOfMonth)
        .eq('status', 'completed');

    double monthlyRevenue = 0;
    for (final row in paymentRows) {
      monthlyRevenue += (row['amount'] as num?)?.toDouble() ?? 0;
    }

    // Calculate revenue change (compare with previous month)
    final prevMonthStart =
        DateTime(now.year, now.month - 1, 1).toIso8601String();
    final prevPayments = await client
        .from('payments')
        .select('amount')
        .gte('created_at', prevMonthStart)
        .lt('created_at', startOfMonth)
        .eq('status', 'completed');

    double prevRevenue = 0;
    for (final row in prevPayments) {
      prevRevenue += (row['amount'] as num?)?.toDouble() ?? 0;
    }

    final changePercent = prevRevenue > 0
        ? ((monthlyRevenue - prevRevenue) / prevRevenue) * 100
        : 0.0;

    return DashboardKpis(
      monthlyRevenue: monthlyRevenue,
      revenueChangePercent: changePercent,
      activeUsers: activeUsers,
      bookingsToday: bookingsToday,
      registeredSalons: registeredSalons,
    );
  } catch (e) {
    debugPrint('Dashboard KPIs error: $e');
    return DashboardKpis.placeholder;
  }
});

/// Realtime activity feed from appointments and profiles.
final activityFeedProvider = StreamProvider<List<ActivityItem>>((ref) {
  if (!BCSupabase.isInitialized) {
    return Stream.value(<ActivityItem>[]);
  }

  final controller = StreamController<List<ActivityItem>>();
  final items = <ActivityItem>[];

  // Subscribe to new appointments
  final appointmentsSub = BCSupabase.client
      .from('appointments')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(10)
      .listen((data) {
    final newItems = <ActivityItem>[];
    for (final row in data) {
      final status = row['status'] as String? ?? '';
      final type = status == 'cancelled' ? 'cancellation' : 'booking';
      final title = type == 'cancellation'
          ? 'Reserva cancelada'
          : 'Nueva reserva';
      newItems.add(ActivityItem(
        id: 'apt_${row['id']}',
        type: type,
        title: title,
        subtitle: row['service_name'] as String? ?? 'Servicio',
        timestamp: DateTime.tryParse(row['created_at'] as String? ?? '') ??
            DateTime.now(),
      ));
    }
    items
      ..removeWhere((i) => i.id.startsWith('apt_'))
      ..addAll(newItems)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    controller.add(List.unmodifiable(items.take(20)));
  });

  // Subscribe to new profiles
  final profilesSub = BCSupabase.client
      .from('profiles')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(10)
      .listen((data) {
    final newItems = <ActivityItem>[];
    for (final row in data) {
      newItems.add(ActivityItem(
        id: 'usr_${row['id']}',
        type: 'user',
        title: 'Nuevo usuario',
        subtitle: row['display_name'] as String? ?? 'Usuario',
        timestamp: DateTime.tryParse(row['created_at'] as String? ?? '') ??
            DateTime.now(),
      ));
    }
    items
      ..removeWhere((i) => i.id.startsWith('usr_'))
      ..addAll(newItems)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    controller.add(List.unmodifiable(items.take(20)));
  });

  ref.onDispose(() {
    appointmentsSub.cancel();
    profilesSub.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Dashboard alert counts.
final dashboardAlertsProvider = FutureProvider<DashboardAlerts>((ref) async {
  if (!BCSupabase.isInitialized) return DashboardAlerts.placeholder;

  try {
    final client = BCSupabase.client;

    final results = await Future.wait([
      // Pending disputes
      client
          .from('disputes')
          .select('id')
          .eq('status', 'pending')
          .count(),
      // Unverified businesses
      client
          .from('businesses')
          .select('id')
          .eq('verified', false)
          .count(),
      // Failed payments
      client
          .from('payments')
          .select('id')
          .eq('status', 'failed')
          .count(),
    ]);

    return DashboardAlerts(
      pendingDisputes: (results[0] as dynamic).count as int? ?? 0,
      unverifiedSalons: (results[1] as dynamic).count as int? ?? 0,
      failedPayments: (results[2] as dynamic).count as int? ?? 0,
    );
  } catch (e) {
    debugPrint('Dashboard alerts error: $e');
    return DashboardAlerts.placeholder;
  }
});

/// Weekly bookings chart data (current week, Mon-Sun).
final weeklyBookingsProvider = FutureProvider<WeeklyBookings>((ref) async {
  if (!BCSupabase.isInitialized) return WeeklyBookings.placeholder;

  try {
    final now = DateTime.now();
    // Monday of this week
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeek =
        DateTime(monday.year, monday.month, monday.day).toIso8601String();
    final endOfWeek = DateTime(monday.year, monday.month, monday.day + 7)
        .toIso8601String();

    final data = await BCSupabase.client
        .from('appointments')
        .select('created_at')
        .gte('created_at', startOfWeek)
        .lt('created_at', endOfWeek);

    final counts = List.filled(7, 0);
    for (final row in data) {
      final dt = DateTime.tryParse(row['created_at'] as String? ?? '');
      if (dt != null) {
        counts[dt.weekday - 1]++;
      }
    }

    return WeeklyBookings(
      counts: counts,
      labels: const ['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom'],
    );
  } catch (e) {
    debugPrint('Weekly bookings error: $e');
    return WeeklyBookings.placeholder;
  }
});

/// Revenue trend for the last 30 days.
final revenueTrendProvider = FutureProvider<RevenueTrend>((ref) async {
  if (!BCSupabase.isInitialized) return RevenueTrend.placeholder;

  try {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final start = DateTime(thirtyDaysAgo.year, thirtyDaysAgo.month,
            thirtyDaysAgo.day)
        .toIso8601String();

    final data = await BCSupabase.client
        .from('payments')
        .select('amount, created_at')
        .gte('created_at', start)
        .eq('status', 'completed');

    // Aggregate by day
    final dailyRevenue = <int, double>{};
    for (var i = 0; i < 30; i++) {
      dailyRevenue[i] = 0;
    }

    final baseDate = DateTime(
        thirtyDaysAgo.year, thirtyDaysAgo.month, thirtyDaysAgo.day);
    for (final row in data) {
      final dt = DateTime.tryParse(row['created_at'] as String? ?? '');
      if (dt != null) {
        final dayIndex = dt.difference(baseDate).inDays;
        if (dayIndex >= 0 && dayIndex < 30) {
          dailyRevenue[dayIndex] =
              (dailyRevenue[dayIndex] ?? 0) +
                  ((row['amount'] as num?)?.toDouble() ?? 0);
        }
      }
    }

    final values = List.generate(30, (i) => dailyRevenue[i] ?? 0);
    final labels = List.generate(30, (i) {
      final d = baseDate.add(Duration(days: i));
      return '${d.day}/${d.month}';
    });

    return RevenueTrend(values: values, labels: labels);
  } catch (e) {
    debugPrint('Revenue trend error: $e');
    return RevenueTrend.placeholder;
  }
});
