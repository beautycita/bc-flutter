import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/services/supabase_client.dart';
import 'package:beautycita_core/supabase.dart';

// ── Data classes ──────────────────────────────────────────────────────────────

/// System health metrics for the operations dashboard.
@immutable
class SystemHealth {
  final bool databaseOnline;
  final int connectionCount;
  final int edgeFunctionErrors;
  final DateTime? lastBackupAt;
  final String? lastBackupStatus;

  const SystemHealth({
    required this.databaseOnline,
    required this.connectionCount,
    required this.edgeFunctionErrors,
    this.lastBackupAt,
    this.lastBackupStatus,
  });

  static const placeholder = SystemHealth(
    databaseOnline: false,
    connectionCount: 0,
    edgeFunctionErrors: 0,
  );
}

/// Business activity metrics for the operations dashboard.
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

/// A single log entry for the alerts/logs column.
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

// ── Providers ────────────────────────────────────────────────────────────────

/// System health check — tests DB connectivity and retrieves metrics.
final systemHealthProvider = FutureProvider<SystemHealth>((ref) async {
  if (!SupabaseClientService.isInitialized) return SystemHealth.placeholder;

  try {
    final client = SupabaseClientService.client;

    // Test DB connectivity by running a simple query
    final dbTest = await client
        .from(BCTables.profiles)
        .select('id')
        .limit(1);

    final dbOnline = (dbTest as List).isNotEmpty || true; // query succeeded

    // Check for edge function errors from audit_log if available
    int edgeFunctionErrors = 0;
    try {
      final now = DateTime.now();
      final last24h = now.subtract(const Duration(hours: 24)).toIso8601String();
      final errorRows = await client
          .from(BCTables.auditLog)
          .select('id')
          .eq('action', 'edge_function_error')
          .gte('created_at', last24h)
          .count();
      edgeFunctionErrors = errorRows.count;
    } catch (_) {
      // audit_log may not have edge_function_error entries
    }

    // Check last backup from app_config if available
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
          lastBackupAt = DateTime.tryParse(val['timestamp']?.toString() ?? '');
          lastBackupStatus = val['status'] as String?;
        }
      }
    } catch (_) {
      // Config key may not exist
    }

    return SystemHealth(
      databaseOnline: dbOnline,
      connectionCount: 0, // Not available via client API
      edgeFunctionErrors: edgeFunctionErrors,
      lastBackupAt: lastBackupAt,
      lastBackupStatus: lastBackupStatus,
    );
  } catch (e) {
    debugPrint('System health error: $e');
    return SystemHealth.placeholder;
  }
});

/// Business activity metrics from live tables.
final businessActivityProvider = FutureProvider<BusinessActivity>((ref) async {
  if (!SupabaseClientService.isInitialized) return BusinessActivity.placeholder;

  try {
    final client = SupabaseClientService.client;
    final now = DateTime.now();
    final startOfDay =
        DateTime(now.year, now.month, now.day).toIso8601String();
    final last7Days =
        now.subtract(const Duration(days: 7)).toIso8601String();
    final last24h =
        now.subtract(const Duration(hours: 24)).toIso8601String();

    final results = await Future.wait([
      // Bookings today — confirmed
      client
          .from(BCTables.appointments)
          .select('id')
          .gte('created_at', startOfDay)
          .eq('status', 'confirmed')
          .count(),
      // Bookings today — pending
      client
          .from(BCTables.appointments)
          .select('id')
          .gte('created_at', startOfDay)
          .eq('status', 'pending')
          .count(),
      // Bookings today — cancelled
      client
          .from(BCTables.appointments)
          .select('id')
          .gte('created_at', startOfDay)
          .eq('status', 'cancelled')
          .count(),
      // New salons last 7 days
      client
          .from(BCTables.businesses)
          .select('id')
          .gte('created_at', last7Days)
          .count(),
      // Active users last 24h (profiles with recent activity)
      client
          .from(BCTables.profiles)
          .select('id')
          .gte('updated_at', last24h)
          .count(),
      // Pending disputes
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

    // Revenue today from payments
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
final opsLogsProvider = FutureProvider<List<OpsLogEntry>>((ref) async {
  if (!SupabaseClientService.isInitialized) return [];

  try {
    final client = SupabaseClientService.client;
    final entries = <OpsLogEntry>[];

    // Fetch from audit_log table if available
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
    } catch (_) {
      // audit_log might not exist or have different schema
    }

    // Fetch failed payments from last 7 days
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
    } catch (_) {
      // payments table query may fail
    }

    // Sort by timestamp descending
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries.take(30).toList();
  } catch (e) {
    debugPrint('Ops logs error: $e');
    return [];
  }
});
