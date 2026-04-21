import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:beautycita/config/fonts.dart';
import '../../config/constants.dart';

/// Admin behavioral-intelligence browser for mobile.
///
/// LFPDPPP-compliant: only touches RPCs. [list_users_with_traits] excludes
/// opted-out users; opening a user calls [get_user_trait_data] which atomically
/// logs to admin_trait_access_log before returning data.
class AdminIntelligenceScreen extends ConsumerStatefulWidget {
  const AdminIntelligenceScreen({super.key});

  @override
  ConsumerState<AdminIntelligenceScreen> createState() =>
      _AdminIntelligenceScreenState();
}

class _AdminIntelligenceScreenState
    extends ConsumerState<AdminIntelligenceScreen> {
  final _supabase = Supabase.instance.client;

  String? _segmentFilter;
  String _sortBy = 'rp_candidate_score';
  int _offset = 0;
  static const int _pageSize = 50;

  Future<List<Map<String, dynamic>>>? _listFuture;

  static const _segmentOptions = <String, String>{
    'new': 'Nuevos',
    'active': 'Activos',
    'whale': 'Whales',
    'churn_risk': 'Riesgo churn',
    'rp_candidate': 'Candidatos RP',
  };

  static const _sortOptions = <String, String>{
    'rp_candidate_score': 'RP candidate',
    'whale_score': 'Whale',
    'churn_risk_score': 'Churn risk',
    'total_events': 'Eventos',
    'active_days_30d': 'Activos 30d',
    'last_event_at': 'Último evento',
  };

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _listFuture = _supabase.rpc('list_users_with_traits', params: {
        'p_segment': _segmentFilter,
        'p_sort_by': _sortBy,
        'p_limit': _pageSize,
        'p_offset': _offset,
      }).then((rows) => List<Map<String, dynamic>>.from(rows as List));
    });
  }

  Future<void> _openDetail(Map<String, dynamic> row) async {
    final userId = row['user_id'] as String;
    final displayName = (row['username'] ?? row['full_name'] ?? '(sin nombre)')
        as String;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _UserDetailSheet(
        userId: userId,
        displayName: displayName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilterBar(),
        const Divider(height: 1),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              _refresh();
              await _listFuture;
            },
            child: _buildList(),
          ),
        ),
        _buildPaginationBar(),
      ],
    );
  }

  Widget _buildFilterBar() {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingMD, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _FilterDropdown<String?>(
              label: 'Segmento',
              value: _segmentFilter,
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Todos',
                      style: GoogleFonts.nunito(fontSize: 13)),
                ),
                for (final entry in _segmentOptions.entries)
                  DropdownMenuItem<String?>(
                    value: entry.key,
                    child: Text(entry.value,
                        style: GoogleFonts.nunito(fontSize: 13)),
                  ),
              ],
              onChanged: (v) {
                setState(() {
                  _segmentFilter = v;
                  _offset = 0;
                });
                _refresh();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FilterDropdown<String>(
              label: 'Orden',
              value: _sortBy,
              items: [
                for (final entry in _sortOptions.entries)
                  DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value,
                        style: GoogleFonts.nunito(fontSize: 13)),
                  ),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _sortBy = v;
                  _offset = 0;
                });
                _refresh();
              },
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: colors.primary, size: 22),
            tooltip: 'Refrescar',
            onPressed: _refresh,
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _listFuture,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppConstants.paddingLG),
            children: [
              const SizedBox(height: 60),
              Icon(Icons.error_outline,
                  size: 40,
                  color:
                      Theme.of(ctx).colorScheme.error.withValues(alpha: 0.6)),
              const SizedBox(height: 12),
              Text(
                'Error cargando datos',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                '${snap.error}',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: Theme.of(ctx)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6)),
              ),
            ],
          );
        }
        final rows = snap.data ?? [];
        if (rows.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppConstants.paddingLG),
            children: [
              const SizedBox(height: 60),
              Icon(Icons.psychology_outlined,
                  size: 48,
                  color: Theme.of(ctx)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.35)),
              const SizedBox(height: 16),
              Text(
                'Sin datos de comportamiento',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                _segmentFilter == null
                    ? 'Los traits aparecerán cuando los usuarios generen actividad.'
                    : 'Ningún usuario en el segmento "${_segmentOptions[_segmentFilter] ?? _segmentFilter}".',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: Theme.of(ctx)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6)),
              ),
            ],
          );
        }
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppConstants.paddingMD),
          itemCount: rows.length,
          itemBuilder: (ctx, i) => _UserRow(
            row: rows[i],
            onTap: () => _openDetail(rows[i]),
          ),
        );
      },
    );
  }

  Widget _buildPaginationBar() {
    final total = _offset + _pageSize; // approximate upper bound shown
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
              color: colors.onSurface.withValues(alpha: 0.08), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _offset > 0
                ? () {
                    setState(() => _offset -= _pageSize);
                    _refresh();
                  }
                : null,
          ),
          Text(
            'Página ${(_offset ~/ _pageSize) + 1}  ·  ${_offset + 1}–$total',
            style: GoogleFonts.nunito(
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: 0.7)),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() => _offset += _pageSize);
              _refresh();
            },
          ),
        ],
      ),
    );
  }
}

// ─── User row ────────────────────────────────────────────────────────────────

class _UserRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onTap;

  const _UserRow({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = (row['username'] ?? row['full_name'] ?? '—') as String;
    final segment = row['segment']?.toString() ?? '—';
    final rp = _fmtScore(row['rp_candidate_score']);
    final whale = _fmtScore(row['whale_score']);
    final churn = _fmtScore(row['churn_risk_score']);
    final events = row['total_events'] ?? 0;
    final active30 = row['active_days_30d'] ?? 0;
    final city = row['primary_city']?.toString() ?? '—';
    final lastEvent = _fmtRelative(row['last_event_at']);
    final traitCount = row['trait_count'] ?? 0;
    final segColor = _segmentColor(segment, colors);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        side: BorderSide(color: colors.onSurface.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: segColor.withValues(alpha: 0.14),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: segColor),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.poppins(
                              fontSize: 14, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            _SegmentChip(
                              label:
                                  _AdminIntelligenceScreenState._segmentOptions[
                                          segment] ??
                                      segment,
                              color: segColor,
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.auto_graph,
                                size: 12,
                                color: colors.onSurface
                                    .withValues(alpha: 0.45)),
                            const SizedBox(width: 2),
                            Text(
                              '$traitCount traits',
                              style: GoogleFonts.nunito(
                                  fontSize: 11,
                                  color: colors.onSurface
                                      .withValues(alpha: 0.55)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: colors.onSurface.withValues(alpha: 0.4)),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _MetricPill(label: 'RP', value: rp, color: colors.primary),
                  _MetricPill(
                      label: 'Whale',
                      value: whale,
                      color: const Color(0xFFC026D3)),
                  _MetricPill(
                      label: 'Churn',
                      value: churn,
                      color: const Color(0xFFEF4444)),
                  _MetricPill(
                      label: 'Eventos',
                      value: '$events',
                      color: colors.onSurface.withValues(alpha: 0.6)),
                  _MetricPill(
                      label: 'Activos 30d',
                      value: '$active30',
                      color: colors.onSurface.withValues(alpha: 0.6)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 13, color: colors.onSurface.withValues(alpha: 0.5)),
                  const SizedBox(width: 4),
                  Text(city,
                      style: GoogleFonts.nunito(
                          fontSize: 11,
                          color: colors.onSurface.withValues(alpha: 0.6))),
                  const Spacer(),
                  Icon(Icons.schedule,
                      size: 13, color: colors.onSurface.withValues(alpha: 0.5)),
                  const SizedBox(width: 4),
                  Text(lastEvent,
                      style: GoogleFonts.nunito(
                          fontSize: 11,
                          color: colors.onSurface.withValues(alpha: 0.6))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Detail bottom sheet ─────────────────────────────────────────────────────

class _UserDetailSheet extends StatefulWidget {
  final String userId;
  final String displayName;
  const _UserDetailSheet({required this.userId, required this.displayName});

  @override
  State<_UserDetailSheet> createState() => _UserDetailSheetState();
}

class _UserDetailSheetState extends State<_UserDetailSheet> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _detail;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _supabase.rpc('get_user_trait_data', params: {
        'p_user_id': widget.userId,
      });
      if (!mounted) return;
      setState(() {
        _detail = Map<String, dynamic>.from(data as Map);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final maxH = MediaQuery.of(context).size.height * 0.9;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dragHandle(colors),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.displayName,
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody(colors)),
        ],
      ),
    );
  }

  Widget _dragHandle(ColorScheme colors) => Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: colors.onSurface.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _buildBody(ColorScheme colors) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: colors.error, size: 40),
            const SizedBox(height: 12),
            Text('Error cargando traits',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(_error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: colors.onSurface.withValues(alpha: 0.65))),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              onPressed: _load,
            ),
          ],
        ),
      );
    }
    final d = _detail;
    if (d == null) return const SizedBox.shrink();

    final profile = d['profile'] as Map<String, dynamic>?;
    final traits =
        List<Map<String, dynamic>>.from((d['trait_scores'] ?? []) as List);
    final summary = d['behavior_summary'] as Map<String, dynamic>?;
    final events =
        List<Map<String, dynamic>>.from((d['recent_events'] ?? []) as List);
    final accessLog =
        List<Map<String, dynamic>>.from((d['access_log_recent'] ?? []) as List);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (profile != null) _buildProfileStrip(profile, colors),
        if (profile?['analytics_opt_out'] == true) _buildOptOutWarning(colors),
        const SizedBox(height: 16),
        _sectionTitle('Resumen de comportamiento'),
        const SizedBox(height: 8),
        if (summary == null)
          _emptyInline('Sin resumen calculado aún')
        else
          _buildSummaryGrid(summary, colors),
        const SizedBox(height: 20),
        _sectionTitle('Trait scores (${traits.length})'),
        const SizedBox(height: 8),
        if (traits.isEmpty)
          _emptyInline('Sin scores calculados aún')
        else
          ...traits.map((t) => _buildTraitRow(t, colors)),
        const SizedBox(height: 20),
        _sectionTitle('Eventos recientes (${events.length})'),
        const SizedBox(height: 8),
        if (events.isEmpty)
          _emptyInline('Sin eventos recientes')
        else
          ...events.take(20).map((e) => _buildEventRow(e, colors)),
        const SizedBox(height: 20),
        _sectionTitle('Últimas consultas admin (${accessLog.length})'),
        const SizedBox(height: 8),
        if (accessLog.isEmpty)
          _emptyInline('Esta es la primera vista registrada')
        else
          ...accessLog.map((a) => _buildAccessLogRow(a, colors)),
      ],
    );
  }

  Widget _sectionTitle(String text) => Text(
        text.toUpperCase(),
        style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.55)),
      );

  Widget _emptyInline(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text,
            style: GoogleFonts.nunito(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5))),
      );

  Widget _buildProfileStrip(Map<String, dynamic> profile, ColorScheme colors) {
    final role = profile['role']?.toString() ?? '—';
    final status = profile['status']?.toString() ?? '—';
    final created = _fmtDate(profile['created_at']);
    final lastSeen = _fmtRelative(profile['last_seen']);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          _ProfileField(label: 'Rol', value: role),
          _ProfileField(label: 'Status', value: status),
          _ProfileField(label: 'Creado', value: created),
          _ProfileField(label: 'Último login', value: lastSeen),
        ],
      ),
    );
  }

  Widget _buildOptOutWarning(ColorScheme colors) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colors.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: colors.error.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.shield_outlined, color: colors.error, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Usuario ejerció oposición LFPDPPP — no debería ser visible.',
                  style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.error),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildSummaryGrid(Map<String, dynamic> s, ColorScheme colors) {
    final items = <MapEntry<String, String>>[
      MapEntry('Segmento', s['segment']?.toString() ?? '—'),
      MapEntry('RP candidate', _fmtScore(s['rp_candidate_score'])),
      MapEntry('Whale', _fmtScore(s['whale_score'])),
      MapEntry('Churn risk', _fmtScore(s['churn_risk_score'])),
      MapEntry('Total eventos', '${s['total_events'] ?? 0}'),
      MapEntry('Activos 30d', '${s['active_days_30d'] ?? 0}'),
      MapEntry('Activos 90d', '${s['active_days_90d'] ?? 0}'),
      MapEntry('Primera actividad', _fmtDate(s['first_event_at'])),
      MapEntry('Última actividad', _fmtRelative(s['last_event_at'])),
      MapEntry('Ciudad', s['primary_city']?.toString() ?? '—'),
    ];
    return Wrap(
      spacing: 16,
      runSpacing: 10,
      children: items
          .map((e) => SizedBox(
                width: 150,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.key,
                        style: GoogleFonts.nunito(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface.withValues(alpha: 0.55))),
                    Text(e.value,
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildTraitRow(Map<String, dynamic> t, ColorScheme colors) {
    final trait = t['trait']?.toString() ?? '—';
    final score = (t['score'] as num?)?.toDouble() ?? 0;
    final pct = (t['percentile'] as num?)?.toDouble();
    final fraction = (score / 100).clamp(0.0, 1.0);
    final isNegative = trait == 'churn_risk' || trait == 'cancellation_rate';
    final barColor = isNegative
        ? (score >= 70
            ? colors.error
            : score >= 40
                ? const Color(0xFFF59E0B)
                : const Color(0xFF10B981))
        : (score >= 70
            ? const Color(0xFF10B981)
            : score >= 40
                ? const Color(0xFFF59E0B)
                : colors.error);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(trait,
                    style: GoogleFonts.nunito(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              Text(score.toStringAsFixed(1),
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: barColor)),
              if (pct != null) ...[
                const SizedBox(width: 6),
                Text('p${pct.toStringAsFixed(0)}',
                    style: GoogleFonts.nunito(
                        fontSize: 10,
                        color: colors.onSurface.withValues(alpha: 0.55))),
              ],
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Stack(
              children: [
                Container(
                  height: 5,
                  color: barColor.withValues(alpha: 0.14),
                ),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(height: 5, color: barColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventRow(Map<String, dynamic> e, ColorScheme colors) {
    final type = e['event_type']?.toString() ?? '—';
    final target = e['target_type']?.toString();
    final source = e['source']?.toString();
    final when = _fmtRelative(e['created_at']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(when,
                style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: colors.onSurface.withValues(alpha: 0.55))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$type${target != null ? " → $target" : ""}'
              '${source != null && source != "organic" ? " ($source)" : ""}',
              style: GoogleFonts.nunito(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessLogRow(Map<String, dynamic> a, ColorScheme colors) {
    final when = _fmtRelative(a['created_at']);
    final ctx = a['context']?.toString() ?? '—';
    final admin = a['admin_id']?.toString() ?? '';
    final adminShort = admin.length > 8 ? admin.substring(0, 8) : admin;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$when  ·  admin $adminShort…  ·  $ctx',
        style: GoogleFonts.nunito(
            fontSize: 11, color: colors.onSurface.withValues(alpha: 0.6)),
      ),
    );
  }
}

// ─── Small building blocks ──────────────────────────────────────────────────

class _FilterDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.nunito(
            fontSize: 12,
            color: colors.onSurface.withValues(alpha: 0.6)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              BorderSide(color: colors.onSurface.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              BorderSide(color: colors.onSurface.withValues(alpha: 0.12)),
        ),
        isDense: true,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _SegmentChip extends StatelessWidget {
  final String label;
  final Color color;
  const _SegmentChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
            fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MetricPill(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text('$label ',
            style: GoogleFonts.nunito(
                fontSize: 11,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.55))),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

class _ProfileField extends StatelessWidget {
  final String label;
  final String value;
  const _ProfileField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.nunito(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: colors.onSurface.withValues(alpha: 0.55))),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────────

String _fmtScore(dynamic v) {
  if (v == null) return '—';
  final n = (v is num) ? v : num.tryParse(v.toString());
  if (n == null) return v.toString();
  return n.toStringAsFixed(1);
}

String _fmtDate(dynamic v) {
  if (v == null) return '—';
  try {
    final d = DateTime.parse(v.toString()).toLocal();
    return DateFormat('d MMM y').format(d);
  } catch (_) {
    return v.toString();
  }
}

String _fmtRelative(dynamic v) {
  if (v == null) return '—';
  try {
    final d = DateTime.parse(v.toString()).toLocal();
    final diff = DateTime.now().difference(d);
    if (diff.isNegative) return _fmtDate(v);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('d MMM').format(d);
  } catch (_) {
    return v.toString();
  }
}

Color _segmentColor(String segment, ColorScheme colors) {
  switch (segment) {
    case 'whale':
      return const Color(0xFFC026D3);
    case 'rp_candidate':
      return const Color(0xFF3B82F6);
    case 'churn_risk':
      return const Color(0xFFEF4444);
    case 'active':
      return const Color(0xFF10B981);
    case 'new':
      return const Color(0xFFF59E0B);
    default:
      return colors.onSurface.withValues(alpha: 0.5);
  }
}
