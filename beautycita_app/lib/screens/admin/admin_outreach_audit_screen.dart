import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/config/fonts.dart';

import '../../services/supabase_client.dart';

/// Admin Outreach Audit — two columns:
///   1. Recent bulk jobs (last 50): who sent, channel, template, counts, status
///   2. Marketing opt-out registry: who opted out, source, when
///
/// Both come from existing tables (bulk_outreach_jobs + marketing_opt_outs).
/// Purpose: give the admin visibility into what's been sent and who's
/// blocked, so the bulk-send tooling has a paper trail.
class AdminOutreachAuditScreen extends ConsumerStatefulWidget {
  const AdminOutreachAuditScreen({super.key});

  @override
  ConsumerState<AdminOutreachAuditScreen> createState() =>
      _AdminOutreachAuditScreenState();
}

class _AdminOutreachAuditScreenState
    extends ConsumerState<AdminOutreachAuditScreen> {
  late Future<List<Map<String, dynamic>>> _jobs;
  late Future<List<Map<String, dynamic>>> _optOuts;
  late Future<int> _optOutCount;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _jobs = _loadJobs();
    _optOuts = _loadOptOuts();
    _optOutCount = _loadOptOutCount();
  }

  Future<List<Map<String, dynamic>>> _loadJobs() async {
    final res = await SupabaseClientService.client
        .from('bulk_outreach_jobs')
        .select(
          'id, status, channel, total_count, sent_count, skipped_count, '
          'failed_count, optout_skipped_count, cooldown_skipped_count, '
          'created_at, completed_at, '
          'admin:profiles!admin_user_id(full_name, username), '
          'template:outreach_templates(name)',
        )
        .order('created_at', ascending: false)
        .limit(50);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> _loadOptOuts() async {
    final res = await SupabaseClientService.client
        .from('marketing_opt_outs')
        .select('id, phone, email, source, channel_blocked, opted_out_at, notes')
        .order('opted_out_at', ascending: false)
        .limit(100);
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<int> _loadOptOutCount() async {
    final res = await SupabaseClientService.client
        .from('marketing_opt_outs')
        .count();
    return res;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Envíos recientes'),
              Tab(text: 'Lista de baja'),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => setState(_refresh),
              child: TabBarView(
                children: [
                  _buildJobsTab(),
                  _buildOptOutsTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _jobs,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final jobs = snap.data ?? [];
        if (jobs.isEmpty) {
          return const Center(child: Text('Sin envíos en bloque registrados'));
        }
        return ListView.builder(
          itemCount: jobs.length,
          itemBuilder: (_, i) => _JobTile(job: jobs[i]),
        );
      },
    );
  }

  Widget _buildOptOutsTab() {
    return FutureBuilder<int>(
      future: _optOutCount,
      builder: (context, countSnap) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _optOuts,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }
            final rows = snap.data ?? [];
            return ListView(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Row(
                    children: [
                      const Icon(Icons.block_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          countSnap.data != null
                              ? 'Total opt-outs: ${countSnap.data}'
                              : 'Cargando...',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text('Mostrando ${rows.length} más recientes',
                          style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    ],
                  ),
                ),
                ...rows.map((r) => _OptOutTile(row: r)),
              ],
            );
          },
        );
      },
    );
  }
}

class _JobTile extends StatelessWidget {
  final Map<String, dynamic> job;
  const _JobTile({required this.job});

  @override
  Widget build(BuildContext context) {
    final status = job['status'] as String? ?? 'unknown';
    final channel = job['channel'] as String? ?? '';
    final total = (job['total_count'] as num?)?.toInt() ?? 0;
    final sent = (job['sent_count'] as num?)?.toInt() ?? 0;
    final skipped = (job['skipped_count'] as num?)?.toInt() ?? 0;
    final failed = (job['failed_count'] as num?)?.toInt() ?? 0;
    final adminMap = job['admin'] as Map<String, dynamic>?;
    final adminName = adminMap?['full_name'] ?? adminMap?['username'] ?? 'admin';
    final tplMap = job['template'] as Map<String, dynamic>?;
    final tplName = tplMap?['name'] ?? '—';
    final createdAt = DateTime.parse(job['created_at'] as String).toLocal();

    Color statusColor;
    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        break;
      case 'cancelled':
        statusColor = Colors.grey;
        break;
      case 'failed':
        statusColor = Colors.red;
        break;
      case 'queued':
      case 'draining':
        statusColor = Colors.orange;
        break;
      default:
        statusColor = Colors.black54;
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: statusColor.withValues(alpha: 0.15),
        child: Icon(
          channel == 'wa' ? Icons.chat : Icons.mail_outline,
          size: 18,
          color: statusColor,
        ),
      ),
      title: Text(
        '$tplName · $channel',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$adminName · ${_humanDate(createdAt)}'),
          Text(
            '$sent enviados · ${skipped > 0 ? "$skipped omitidos · " : ""}${failed > 0 ? "$failed fallidos · " : ""}$total totales',
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          status,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
        ),
      ),
      isThreeLine: true,
    );
  }

  String _humanDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'hace un momento';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'hace ${diff.inDays} d';
    return '${dt.year}-${dt.month.toString().padLeft(2, "0")}-${dt.day.toString().padLeft(2, "0")}';
  }
}

class _OptOutTile extends StatelessWidget {
  final Map<String, dynamic> row;
  const _OptOutTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final phone = row['phone'] as String?;
    final email = row['email'] as String?;
    final source = row['source'] as String? ?? '';
    final channel = row['channel_blocked'] as String? ?? 'all';
    final at = DateTime.parse(row['opted_out_at'] as String).toLocal();

    final sourceLabel = switch (source) {
      'wa_baja' => 'BAJA por WhatsApp',
      'unsubscribe_link' => 'Click en link de baja',
      'manual_admin' => 'Marcado por admin',
      'inbound_email_unsub' => 'Reply email STOP',
      _ => source,
    };

    return ListTile(
      dense: true,
      leading: const Icon(Icons.do_not_disturb_on_outlined, color: Colors.deepOrange, size: 20),
      title: Text(
        phone ?? email ?? '—',
        style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'monospace'),
      ),
      subtitle: Text(
        '$sourceLabel · ${at.toIso8601String().substring(0, 16)}',
        style: const TextStyle(fontSize: 11),
      ),
      trailing: channel != 'all'
          ? Chip(
              label: Text(channel, style: const TextStyle(fontSize: 10)),
              visualDensity: VisualDensity.compact,
            )
          : null,
    );
  }
}
