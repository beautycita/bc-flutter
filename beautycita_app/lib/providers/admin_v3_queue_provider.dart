// Providers feeding Operaciones → Cola.
// Each sub-queue is a tiny aggregation against an existing table.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_client.dart';

class AdminQueueCounts {
  AdminQueueCounts({
    required this.arcoOpen,
    required this.roleChangePending,
    required this.disputesOpen,
    required this.alertsOpen,
    required this.banking,
  });
  final int arcoOpen;
  final int roleChangePending;
  final int disputesOpen;
  final int alertsOpen;
  final int banking;

  int get total => arcoOpen + roleChangePending + disputesOpen + alertsOpen + banking;
}

final adminQueueCountsProvider = FutureProvider<AdminQueueCounts>((ref) async {
  final c = SupabaseClientService.client;
  final arcoOpen = (await c.from('arco_requests').select('id').neq('status', 'resolved').limit(500)) as List;
  final roleChange = (await c.from('role_change_requests').select('id').eq('status', 'pending').limit(500)) as List;
  final disputes = (await c.from('disputes').select('id').inFilter('status', ['open', 'pending', 'investigating']).limit(500)) as List;
  final alerts = (await c.from('admin_alerts').select('id').filter('resolved_at', 'is', null).limit(500)) as List;
  final banking = (await c.from('businesses').select('id')
      .eq('id_verification_status', 'pending')
      .neq('clabe', '')
      .limit(500)) as List;

  return AdminQueueCounts(
    arcoOpen: arcoOpen.length,
    roleChangePending: roleChange.length,
    disputesOpen: disputes.length,
    alertsOpen: alerts.length,
    banking: banking.length,
  );
});

/// Recent activity feed sourced from audit_log.
final adminRecentAuditProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await SupabaseClientService.client
      .from('audit_log')
      .select('id, occurred_at, actor_id, actor_role, action, target_table, target_id, after_data')
      .order('occurred_at', ascending: false)
      .limit(50);
  return (res as List).cast<Map<String, dynamic>>();
});

/// system_health_probes — last 60 minutes for the timeline.
final adminHealthProbesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await SupabaseClientService.client
      .from('system_health_probes')
      .select()
      .order('probed_at', ascending: false)
      .limit(60);
  return (res as List).cast<Map<String, dynamic>>();
});
