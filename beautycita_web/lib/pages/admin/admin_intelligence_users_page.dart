import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin per-user trait analytics dashboard.
///
/// LFPDPPP-compliant: every per-user fetch via [get_user_trait_data] writes
/// an admin_trait_access_log row. The list view ([list_users_with_traits])
/// excludes opted-out users.
class AdminIntelligenceUsersPage extends ConsumerStatefulWidget {
  const AdminIntelligenceUsersPage({super.key});

  @override
  ConsumerState<AdminIntelligenceUsersPage> createState() => _State();
}

class _State extends ConsumerState<AdminIntelligenceUsersPage> {
  final _supabase = Supabase.instance.client;

  String? _segmentFilter;
  String _sortBy = 'rp_candidate_score';
  int _offset = 0;
  static const int _pageSize = 50;

  Future<List<Map<String, dynamic>>>? _listFuture;
  Map<String, dynamic>? _selectedDetail;
  String? _selectedUserId;
  bool _detailLoading = false;
  String? _detailError;

  @override
  void initState() {
    super.initState();
    _refreshList();
  }

  void _refreshList() {
    setState(() {
      _listFuture = _supabase.rpc('list_users_with_traits', params: {
        'p_segment': _segmentFilter,
        'p_sort_by': _sortBy,
        'p_limit': _pageSize,
        'p_offset': _offset,
      }).then((rows) => List<Map<String, dynamic>>.from(rows as List));
    });
  }

  Future<void> _openDetail(String userId) async {
    setState(() {
      _selectedUserId = userId;
      _selectedDetail = null;
      _detailError = null;
      _detailLoading = true;
    });
    try {
      final data = await _supabase.rpc('get_user_trait_data', params: {
        'p_user_id': userId,
      });
      setState(() {
        _selectedDetail = Map<String, dynamic>.from(data as Map);
        _detailLoading = false;
      });
    } catch (e) {
      setState(() {
        _detailError = e.toString();
        _detailLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final showDetail = _selectedUserId != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Intelligence — Usuarios'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            icon: const Icon(Icons.refresh),
            onPressed: _refreshList,
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(flex: showDetail ? 3 : 5, child: _buildListColumn()),
          if (showDetail)
            Container(
              width: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          if (showDetail) Expanded(flex: 4, child: _buildDetailPanel()),
        ],
      ),
    );
  }

  // ── List column ──────────────────────────────────────────────────────────
  Widget _buildListColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFilterBar(),
        const Divider(height: 1),
        Expanded(child: _buildTable()),
        _buildPaginationBar(),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          DropdownButton<String?>(
            value: _segmentFilter,
            hint: const Text('Todos los segmentos'),
            items: const [
              DropdownMenuItem(value: null, child: Text('Todos los segmentos')),
              DropdownMenuItem(value: 'new', child: Text('Nuevos')),
              DropdownMenuItem(value: 'active', child: Text('Activos')),
              DropdownMenuItem(value: 'whale', child: Text('Whales')),
              DropdownMenuItem(value: 'churn_risk', child: Text('Riesgo de churn')),
              DropdownMenuItem(value: 'rp_candidate', child: Text('Candidatos RP')),
            ],
            onChanged: (v) {
              setState(() {
                _segmentFilter = v;
                _offset = 0;
              });
              _refreshList();
            },
          ),
          const SizedBox(width: 16),
          DropdownButton<String>(
            value: _sortBy,
            items: const [
              DropdownMenuItem(value: 'rp_candidate_score', child: Text('Sort: RP candidate')),
              DropdownMenuItem(value: 'whale_score', child: Text('Sort: Whale score')),
              DropdownMenuItem(value: 'churn_risk_score', child: Text('Sort: Churn risk')),
              DropdownMenuItem(value: 'total_events', child: Text('Sort: Total events')),
              DropdownMenuItem(value: 'active_days_30d', child: Text('Sort: Active days (30d)')),
              DropdownMenuItem(value: 'last_event_at', child: Text('Sort: Last event')),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _sortBy = v;
                _offset = 0;
              });
              _refreshList();
            },
          ),
          const Spacer(),
          const Text('LFPDPPP: viewing a user logs to admin_trait_access_log',
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _listFuture,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final rows = snap.data ?? [];
        if (rows.isEmpty) {
          return const Center(child: Text('Sin usuarios en este filtro.'));
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(
                  Theme.of(context).colorScheme.surfaceContainerHighest),
              columns: const [
                DataColumn(label: Text('User')),
                DataColumn(label: Text('Segment')),
                DataColumn(label: Text('RP'), numeric: true),
                DataColumn(label: Text('Whale'), numeric: true),
                DataColumn(label: Text('Churn'), numeric: true),
                DataColumn(label: Text('Events'), numeric: true),
                DataColumn(label: Text('30d active'), numeric: true),
                DataColumn(label: Text('City')),
                DataColumn(label: Text('Last event')),
                DataColumn(label: Text('Traits'), numeric: true),
              ],
              rows: rows.map((r) {
                final isSel = r['user_id'] == _selectedUserId;
                return DataRow(
                  selected: isSel,
                  onSelectChanged: (_) => _openDetail(r['user_id'] as String),
                  cells: [
                    DataCell(Text(
                      r['username'] ?? r['full_name'] ?? '(sin nombre)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    )),
                    DataCell(_segmentChip(r['segment'])),
                    DataCell(Text(_fmtScore(r['rp_candidate_score']))),
                    DataCell(Text(_fmtScore(r['whale_score']))),
                    DataCell(Text(_fmtScore(r['churn_risk_score']))),
                    DataCell(Text('${r['total_events'] ?? 0}')),
                    DataCell(Text('${r['active_days_30d'] ?? 0}')),
                    DataCell(Text(r['primary_city'] ?? '—')),
                    DataCell(Text(_fmtTimestamp(r['last_event_at']))),
                    DataCell(Text('${r['trait_count'] ?? 0}')),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaginationBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _offset > 0
                ? () {
                    setState(() => _offset -= _pageSize);
                    _refreshList();
                  }
                : null,
          ),
          Text('Offset: $_offset · Página: ${(_offset ~/ _pageSize) + 1}'),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() => _offset += _pageSize);
              _refreshList();
            },
          ),
        ],
      ),
    );
  }

  // ── Detail panel ─────────────────────────────────────────────────────────
  Widget _buildDetailPanel() {
    if (_detailLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_detailError != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 8),
                const Text('Error',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: _closeDetail),
              ],
            ),
            const SizedBox(height: 16),
            Text(_detailError!, style: const TextStyle(fontFamily: 'monospace')),
          ],
        ),
      );
    }
    final d = _selectedDetail;
    if (d == null) return const SizedBox.shrink();

    final profile = d['profile'] as Map<String, dynamic>?;
    final traitScores =
        List<Map<String, dynamic>>.from((d['trait_scores'] ?? []) as List);
    final summary = d['behavior_summary'] as Map<String, dynamic>?;
    final events =
        List<Map<String, dynamic>>.from((d['recent_events'] ?? []) as List);
    final accessLog =
        List<Map<String, dynamic>>.from((d['access_log_recent'] ?? []) as List);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  profile?['username'] ??
                      profile?['full_name'] ??
                      'Usuario sin nombre',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: _closeDetail),
            ],
          ),
          const SizedBox(height: 8),
          Text('Role: ${profile?['role'] ?? '—'}  ·  '
              'Status: ${profile?['status'] ?? '—'}  ·  '
              'Created: ${_fmtTimestamp(profile?['created_at'])}'),
          if (profile?['analytics_opt_out'] == true)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Chip(
                avatar: Icon(Icons.shield, size: 16),
                label: Text('OPTED OUT — should not be visible'),
                backgroundColor: Color(0xFFFEF2F2),
              ),
            ),
          const Divider(height: 32),

          _sectionTitle('Behavior summary'),
          if (summary == null)
            const Text('Sin resumen calculado.')
          else
            _summaryGrid(summary),
          const SizedBox(height: 24),

          _sectionTitle('Trait scores (${traitScores.length})'),
          if (traitScores.isEmpty)
            const Text('Sin scores calculados.')
          else
            DataTable(
              columns: const [
                DataColumn(label: Text('Trait')),
                DataColumn(label: Text('Score'), numeric: true),
                DataColumn(label: Text('Raw'), numeric: true),
                DataColumn(label: Text('Pct'), numeric: true),
                DataColumn(label: Text('Computed')),
              ],
              rows: traitScores
                  .map((t) => DataRow(cells: [
                        DataCell(Text(t['trait']?.toString() ?? '—')),
                        DataCell(Text(_fmtScore(t['score']))),
                        DataCell(Text(_fmtScore(t['raw_value']))),
                        DataCell(Text(_fmtScore(t['percentile']))),
                        DataCell(Text(_fmtTimestamp(t['computed_at']))),
                      ]))
                  .toList(),
            ),
          const SizedBox(height: 24),

          _sectionTitle('Recent events (${events.length})'),
          if (events.isEmpty)
            const Text('Sin eventos recientes.')
          else
            ...events.take(20).map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                          width: 140,
                          child: Text(_fmtTimestamp(e['created_at']),
                              style: const TextStyle(fontSize: 12))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${e['event_type']}'
                          '${e['target_type'] != null ? " → ${e['target_type']}" : ""}'
                          '${e['source'] != null && e['source'] != "organic" ? " (${e['source']})" : ""}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )),
          const SizedBox(height: 24),

          _sectionTitle('Access log — last 10 admin views'),
          if (accessLog.isEmpty)
            const Text('Esta es la primera vista registrada.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic))
          else
            ...accessLog.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${_fmtTimestamp(a['created_at'])}  ·  admin ${(a['admin_id'] as String).substring(0, 8)}…  ·  ${a['context']}',
                    style: const TextStyle(fontSize: 12),
                  ),
                )),
        ],
      ),
    );
  }

  void _closeDetail() {
    setState(() {
      _selectedUserId = null;
      _selectedDetail = null;
      _detailError = null;
      _detailLoading = false;
    });
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: Colors.grey)),
      );

  Widget _summaryGrid(Map<String, dynamic> s) {
    final fields = <String, String>{
      'Segment': s['segment']?.toString() ?? '—',
      'Total events': '${s['total_events'] ?? 0}',
      'Active 30d': '${s['active_days_30d'] ?? 0} días',
      'Active 90d': '${s['active_days_90d'] ?? 0} días',
      'First event': _fmtTimestamp(s['first_event_at']),
      'Last event': _fmtTimestamp(s['last_event_at']),
      'Primary city': s['primary_city']?.toString() ?? '—',
      'RP candidate': _fmtScore(s['rp_candidate_score']),
      'Whale score': _fmtScore(s['whale_score']),
      'Churn risk': _fmtScore(s['churn_risk_score']),
    };
    return Wrap(
      spacing: 24,
      runSpacing: 12,
      children: fields.entries
          .map((e) => SizedBox(
                width: 160,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.key,
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontWeight: FontWeight.w600)),
                    Text(e.value,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _segmentChip(dynamic seg) {
    final s = seg?.toString() ?? '—';
    Color bg;
    switch (s) {
      case 'whale':
        bg = const Color(0xFFFCE7F3);
        break;
      case 'rp_candidate':
        bg = const Color(0xFFE0F2FE);
        break;
      case 'churn_risk':
        bg = const Color(0xFFFEE2E2);
        break;
      case 'active':
        bg = const Color(0xFFD1FAE5);
        break;
      default:
        bg = const Color(0xFFF3F4F6);
    }
    return Chip(
      label: Text(s, style: const TextStyle(fontSize: 11)),
      backgroundColor: bg,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  String _fmtScore(dynamic v) {
    if (v == null) return '—';
    final n = (v is num) ? v : num.tryParse(v.toString());
    if (n == null) return v.toString();
    return n.toStringAsFixed(1);
  }

  String _fmtTimestamp(dynamic v) {
    if (v == null) return '—';
    try {
      final d = DateTime.parse(v.toString()).toLocal();
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return v.toString();
    }
  }
}
