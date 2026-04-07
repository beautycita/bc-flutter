import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';

// ── Data classes ──────────────────────────────────────────────────────────────

@immutable
class SystemHealth {
  final bool databaseOnline;
  final int edgeFunctionErrors;
  final DateTime? lastBackupAt;
  final String? lastBackupStatus;
  final DateTime checkedAt;

  const SystemHealth({
    required this.databaseOnline,
    required this.edgeFunctionErrors,
    this.lastBackupAt,
    this.lastBackupStatus,
    required this.checkedAt,
  });

  static final placeholder = SystemHealth(
    databaseOnline: false,
    edgeFunctionErrors: 0,
    checkedAt: DateTime.now(),
  );
}

@immutable
class BusinessActivity {
  final int bookingsConfirmed;
  final int bookingsPending;
  final int bookingsCancelled;
  final double revenueToday;
  final int newSalonsLast7Days;
  final int activeUsersLast24h;
  final int pendingDisputes;
  final int totalBookingsToday;

  const BusinessActivity({
    required this.bookingsConfirmed,
    required this.bookingsPending,
    required this.bookingsCancelled,
    required this.revenueToday,
    required this.newSalonsLast7Days,
    required this.activeUsersLast24h,
    required this.pendingDisputes,
    required this.totalBookingsToday,
  });

  static const placeholder = BusinessActivity(
    bookingsConfirmed: 0,
    bookingsPending: 0,
    bookingsCancelled: 0,
    revenueToday: 0,
    newSalonsLast7Days: 0,
    activeUsersLast24h: 0,
    pendingDisputes: 0,
    totalBookingsToday: 0,
  );
}

@immutable
class OpsLogEntry {
  final String id;
  final String type; // 'admin_action', 'toggle_change', 'failed_payment'
  final String description;
  final DateTime timestamp;
  final String? actor;

  const OpsLogEntry({
    required this.id,
    required this.type,
    required this.description,
    required this.timestamp,
    this.actor,
  });
}

// ── Auto-refresh ticker ─────────────────────────────────────────────────────
// All ops providers depend on this. It ticks every 30 seconds, causing
// dependent providers to refetch. No stale data on the ops dashboard.

final _opsRefreshProvider = StreamProvider<int>((ref) {
  return Stream.periodic(const Duration(seconds: 30), (i) => i);
});

// ── Providers ────────────────────────────────────────────────────────────────

/// System health check — tests DB connectivity and retrieves metrics.
/// Auto-refreshes every 30 seconds via _opsRefreshProvider.
final systemHealthProvider = FutureProvider<SystemHealth>((ref) async {
  ref.watch(_opsRefreshProvider); // triggers refetch every 30s

  if (!BCSupabase.isInitialized) return SystemHealth.placeholder;

  try {
    final client = BCSupabase.client;

    // Test DB connectivity — if the query completes without throwing, DB is online
    bool dbOnline = false;
    try {
      await client.from(BCTables.profiles).select('id').limit(1);
      dbOnline = true;
    } catch (_) {
      dbOnline = false;
    }

    // Edge function errors from audit_log in last 24h
    int edgeFunctionErrors = 0;
    try {
      final last24h = DateTime.now()
          .subtract(const Duration(hours: 24))
          .toIso8601String();
      final errorRows = await client
          .from(BCTables.auditLog)
          .select('id')
          .eq('action', 'edge_function_error')
          .gte('created_at', last24h)
          .count();
      edgeFunctionErrors = errorRows.count;
    } catch (_) {}

    // Last backup from app_config
    DateTime? lastBackupAt;
    String? lastBackupStatus;
    try {
      final backupConfig = await client
          .from(BCTables.appConfig)
          .select('value')
          .eq('key', 'last_backup')
          .limit(1);
      if ((backupConfig as List).isNotEmpty) {
        final val = backupConfig.first['value'];
        if (val is Map) {
          lastBackupAt =
              DateTime.tryParse(val['timestamp']?.toString() ?? '');
          lastBackupStatus = val['status'] as String?;
        }
      }
    } catch (_) {}

    return SystemHealth(
      databaseOnline: dbOnline,
      edgeFunctionErrors: edgeFunctionErrors,
      lastBackupAt: lastBackupAt,
      lastBackupStatus: lastBackupStatus,
      checkedAt: DateTime.now(),
    );
  } catch (e) {
    debugPrint('System health error: $e');
    return SystemHealth.placeholder;
  }
});

/// Business activity metrics from live tables.
/// Auto-refreshes every 30 seconds.
final businessActivityProvider = FutureProvider<BusinessActivity>((ref) async {
  ref.watch(_opsRefreshProvider);

  if (!BCSupabase.isInitialized) return BusinessActivity.placeholder;

  try {
    final client = BCSupabase.client;
    final now = DateTime.now();
    final startOfDay =
        DateTime(now.year, now.month, now.day).toIso8601String();
    final last7Days =
        now.subtract(const Duration(days: 7)).toIso8601String();
    final last24h =
        now.subtract(const Duration(hours: 24)).toIso8601String();

    final results = await Future.wait([
      client
          .from(BCTables.appointments)
          .select('id')
          .gte('created_at', startOfDay)
          .eq('status', 'confirmed')
          .count(),
      client
          .from(BCTables.appointments)
          .select('id')
          .gte('created_at', startOfDay)
          .eq('status', 'pending')
          .count(),
      client
          .from(BCTables.appointments)
          .select('id')
          .gte('created_at', startOfDay)
          .eq('status', 'cancelled')
          .count(),
      client
          .from(BCTables.businesses)
          .select('id')
          .gte('created_at', last7Days)
          .count(),
      client
          .from(BCTables.profiles)
          .select('id')
          .gte('updated_at', last24h)
          .count(),
      client
          .from(BCTables.disputes)
          .select('id')
          .eq('status', 'pending')
          .count(),
    ]);

    final confirmed = results[0].count;
    final pending = results[1].count;
    final cancelled = results[2].count;
    final newSalons = results[3].count;
    final activeUsers = results[4].count;
    final disputes = results[5].count;

    final todayPayments = await client
        .from(BCTables.payments)
        .select('amount')
        .gte('created_at', startOfDay)
        .eq('status', 'succeeded');

    double revenueToday = 0;
    for (final row in todayPayments) {
      revenueToday += (row['amount'] as num?)?.toDouble() ?? 0;
    }

    return BusinessActivity(
      bookingsConfirmed: confirmed,
      bookingsPending: pending,
      bookingsCancelled: cancelled,
      revenueToday: revenueToday,
      newSalonsLast7Days: newSalons,
      activeUsersLast24h: activeUsers,
      pendingDisputes: disputes,
      totalBookingsToday: confirmed + pending + cancelled,
    );
  } catch (e) {
    debugPrint('Business activity error: $e');
    return BusinessActivity.placeholder;
  }
});

/// Recent ops logs: admin actions, toggle changes, failed payments.
/// Auto-refreshes every 30 seconds.
final opsLogsProvider = FutureProvider<List<OpsLogEntry>>((ref) async {
  ref.watch(_opsRefreshProvider);

  if (!BCSupabase.isInitialized) return [];

  try {
    final client = BCSupabase.client;
    final entries = <OpsLogEntry>[];

    try {
      final auditData = await client
          .from(BCTables.auditLog)
          .select('id, action, details, created_at, actor_id')
          .order('created_at', ascending: false)
          .limit(20);

      for (final row in auditData as List) {
        final action = row['action'] as String? ?? '';
        final details = row['details'];
        String description;
        String type;

        if (action.contains('toggle')) {
          type = 'toggle_change';
          description = details is Map
              ? 'Toggle: ${details['key'] ?? action}'
              : 'Toggle modificado: $action';
        } else {
          type = 'admin_action';
          description = details is Map
              ? (details['description'] as String? ?? action)
              : action;
        }

        entries.add(OpsLogEntry(
          id: row['id']?.toString() ?? '',
          type: type,
          description: description,
          timestamp:
              DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                  DateTime.now(),
          actor: row['actor_id']?.toString(),
        ));
      }
    } catch (_) {}

    try {
      final failedPayments = await client
          .from(BCTables.payments)
          .select('id, created_at, amount')
          .eq('status', 'failed')
          .order('created_at', ascending: false)
          .limit(10);

      for (final row in failedPayments as List) {
        final amount = (row['amount'] as num?)?.toDouble() ?? 0;
        entries.add(OpsLogEntry(
          id: 'fp_${row['id']}',
          type: 'failed_payment',
          description: 'Pago fallido: \$${amount.toStringAsFixed(0)} MXN',
          timestamp:
              DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                  DateTime.now(),
        ));
      }
    } catch (_) {}

    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries.take(30).toList();
  } catch (e) {
    debugPrint('Ops logs error: $e');
    return [];
  }
});
