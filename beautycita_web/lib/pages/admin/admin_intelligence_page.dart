import 'package:beautycita_core/supabase.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/breakpoints.dart';
import '../../config/web_theme.dart';
import '../../widgets/web_design_system.dart';

/// Admin behavioral intelligence dashboard.
///
/// Sections:
/// 1. Summary KPIs (users with traits, events 90d, triggers fired 24h, active triggers)
/// 2. Segment breakdown (chips with counts per segment)
/// 3. Recent trigger log (data table)
/// 4. User trait browser (searchable, with score bars)
/// 5. Manual compute button (RPC calls)
/// 6. Trigger management (list with active toggle)
class AdminIntelligencePage extends StatefulWidget {
  const AdminIntelligencePage({super.key});

  @override
  State<AdminIntelligencePage> createState() => _AdminIntelligencePageState();
}

class _AdminIntelligencePageState extends State<AdminIntelligencePage> {
  bool _loading = true;
  bool _computing = false;
  String? _error;

  // Summary KPIs
  int _totalUsersWithTraits = 0;
  int _totalEvents90d = 0;
  int _triggersFired24h = 0;
  int _activeTriggersCount = 0;

  // Segment breakdown
  Map<String, int> _segmentCounts = {};

  // Trigger log
  List<Map<String, dynamic>> _triggerLog = [];
  final Map<String, String> _triggerNames = {};
  final Map<String, String> _profileNames = {};

  // User trait browser
  List<Map<String, dynamic>> _userSummaries = [];
  Map<String, List<Map<String, dynamic>>> _userTraits = {};
  String _traitSearchQuery = '';

  // Trigger management
  List<Map<String, dynamic>> _triggers = [];

  static const _traits = [
    'initiative',
    'spend_velocity',
    'consistency',
    'churn_risk',
    'referral_impact',
    'cancellation_rate',
    'geographic_spread',
    'payment_reliability',
  ];

  static const _traitLabels = {
    'initiative': 'Iniciativa',
    'spend_velocity': 'Vel. Gasto',
    'consistency': 'Consistencia',
    'churn_risk': 'Riesgo Churn',
    'referral_impact': 'Impacto Ref.',
    'cancellation_rate': 'Cancelaciones',
    'geographic_spread': 'Geo Spread',
    'payment_reliability': 'Pago Fiable',
  };

  static const _segmentLabels = {
    'new': 'Nuevo',
    'casual': 'Casual',
    'regular': 'Regular',
    'power_user': 'Power User',
    'dormant': 'Dormido',
  };

  static const _segmentColors = {
    'new': kWebInfo,
    'casual': kWebWarning,
    'regular': kWebSuccess,
    'power_user': kWebPrimary,
    'dormant': kWebError,
  };

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await Future.wait([
        _loadSummaryKpis(),
        _loadSegments(),
        _loadTriggerLog(),
        _loadUserTraitBrowser(),
        _loadTriggers(),
      ]);
    } catch (e) {
      _error = e.toString();
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadSummaryKpis() async {
    final client = BCSupabase.client;

    // Total distinct users with trait scores
    final traitUsers = await client
        .from(BCTables.userTraitScores)
        .select('user_id')
        .limit(10000);
    final distinctUsers =
        (traitUsers as List).map((r) => r['user_id']).toSet();
    _totalUsersWithTraits = distinctUsers.length;

    // Total events in last 90 days
    final cutoff90 =
        DateTime.now().subtract(const Duration(days: 90)).toIso8601String();
    final eventsResp = await client
        .from(BCTables.userBehaviorEvents)
        .select('id')
        .gte('created_at', cutoff90);
    _totalEvents90d = (eventsResp as List).length;

    // Triggers fired in last 24h
    final cutoff24h =
        DateTime.now().subtract(const Duration(hours: 24)).toIso8601String();
    final trigLogResp = await client
        .from(BCTables.behaviorTriggerLog)
        .select('id')
        .gte('created_at', cutoff24h);
    _triggersFired24h = (trigLogResp as List).length;

    // Active triggers count
    final activeTriggers = await client
        .from(BCTables.behaviorTriggers)
        .select('id')
        .eq('is_active', true);
    _activeTriggersCount = (activeTriggers as List).length;
  }

  Future<void> _loadSegments() async {
    final summaries = await BCSupabase.client
        .from(BCTables.userBehaviorSummaries)
        .select('segment');
    final counts = <String, int>{};
    for (final row in summaries as List) {
      final seg = (row['segment'] ?? 'unknown') as String;
      counts[seg] = (counts[seg] ?? 0) + 1;
    }
    _segmentCounts = counts;
  }

  Future<void> _loadTriggerLog() async {
    // Fetch recent trigger log entries
    final log = await BCSupabase.client
        .from(BCTables.behaviorTriggerLog)
        .select()
        .order('created_at', ascending: false)
        .limit(50);
    _triggerLog = List<Map<String, dynamic>>.from(log as List);

    // Fetch trigger names for display
    final triggerIds =
        _triggerLog.map((r) => r['trigger_id']).toSet().toList();
    if (triggerIds.isNotEmpty) {
      final triggers = await BCSupabase.client
          .from(BCTables.behaviorTriggers)
          .select('id, name')
          .inFilter('id', triggerIds);
      for (final t in triggers as List) {
        _triggerNames[t['id'].toString()] = t['name'] as String;
      }
    }

    // Fetch profile usernames
    final userIds = _triggerLog.map((r) => r['user_id']).toSet().toList();
    if (userIds.isNotEmpty) {
      final profiles = await BCSupabase.client
          .from(BCTables.profiles)
          .select('id, username, full_name')
          .inFilter('id', userIds);
      for (final p in profiles as List) {
        _profileNames[p['id'].toString()] =
            (p['username'] ?? p['full_name'] ?? p['id']) as String;
      }
    }
  }

  Future<void> _loadUserTraitBrowser() async {
    // Fetch user behavior summaries
    final summaries = await BCSupabase.client
        .from(BCTables.userBehaviorSummaries)
        .select()
        .order('rp_candidate_score', ascending: false)
        .limit(200);
    _userSummaries = List<Map<String, dynamic>>.from(summaries as List);

    // Fetch all trait scores for these users
    final userIds = _userSummaries.map((s) => s['user_id']).toList();
    if (userIds.isNotEmpty) {
      final traits = await BCSupabase.client
          .from(BCTables.userTraitScores)
          .select()
          .inFilter('user_id', userIds);
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final t in traits as List) {
        final uid = t['user_id'].toString();
        grouped.putIfAbsent(uid, () => []);
        grouped[uid]!.add(Map<String, dynamic>.from(t));
      }
      _userTraits = grouped;
    }

    // Also grab profile names for these users
    if (userIds.isNotEmpty) {
      final profiles = await BCSupabase.client
          .from(BCTables.profiles)
          .select('id, username, full_name')
          .inFilter('id', userIds);
      for (final p in profiles as List) {
        _profileNames[p['id'].toString()] =
            (p['username'] ?? p['full_name'] ?? p['id']) as String;
      }
    }
  }

  Future<void> _loadTriggers() async {
    final triggers = await BCSupabase.client
        .from(BCTables.behaviorTriggers)
        .select()
        .order('created_at', ascending: true);
    _triggers = List<Map<String, dynamic>>.from(triggers as List);
  }

  Future<void> _runCompute() async {
    setState(() => _computing = true);
    try {
      await BCSupabase.client.rpc('compute_all_user_traits');
      await BCSupabase.client.rpc('evaluate_behavior_triggers');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Traits recalculados y triggers evaluados.'),
          ),
        );
      }
      await _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
    if (mounted) setState(() => _computing = false);
  }

  Future<void> _toggleTrigger(Map<String, dynamic> trigger) async {
    final newVal = !(trigger['is_active'] as bool);
    try {
      await BCSupabase.client
          .from(BCTables.behaviorTriggers)
          .update({'is_active': newVal}).eq('id', trigger['id']);
      setState(() => trigger['is_active'] = newVal);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cambiar trigger: $e')),
        );
      }
    }
  }

  Future<void> _markReviewed(Map<String, dynamic> logEntry) async {
    try {
      final now = DateTime.now().toIso8601String();
      final userId = BCSupabase.client.auth.currentUser?.id ?? 'admin';
      await BCSupabase.client
          .from(BCTables.behaviorTriggerLog)
          .update({
            'reviewed_by': userId,
            'reviewed_at': now,
          })
          .eq('id', logEntry['id']);
      setState(() {
        logEntry['reviewed_by'] = userId;
        logEntry['reviewed_at'] = now;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = WebBreakpoints.isDesktop(width);
        final isMobile = WebBreakpoints.isMobile(width);
        final horizontalPadding = isMobile ? 16.0 : 24.0;

        if (_loading) {
          return const Center(
            child: CircularProgressIndicator(color: kWebPrimary),
          );
        }

        if (_error != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: kWebError),
                const SizedBox(height: 16),
                Text(
                  'Error cargando datos',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: kWebTextPrimary,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: kWebTextSecondary,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loadAll,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 24,
          ),
          child: StaggeredFadeIn(
            spacing: 24,
            children: [
              // Page header + compute button
              _buildHeader(context, isMobile),

              // Summary KPI cards
              _buildKpiCards(isDesktop, isMobile),

              // Segment breakdown
              _buildSegmentSection(context),

              // Trigger log + Trigger management (side by side on desktop)
              if (isDesktop)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 3, child: _buildTriggerLog(context)),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: _buildTriggerManagement(context)),
                    ],
                  ),
                )
              else ...[
                _buildTriggerLog(context),
                _buildTriggerManagement(context),
              ],

              // User trait browser
              _buildUserTraitBrowser(context, isDesktop),
            ],
          ),
        );
      },
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, bool isMobile) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) =>
                    kWebBrandGradient.createShader(bounds),
                child: Text(
                  'INTELIGENCIA CONDUCTUAL',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                    color: Colors.white,
                    fontFamily: 'system-ui',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Panel de Inteligencia',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: kWebTextPrimary,
                  fontSize: isMobile ? 24 : 28,
                ),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => context.go('/admin/intelligence/users'),
          icon: const Icon(Icons.people_outline, size: 18),
          label: Text(isMobile ? 'Usuarios' : 'Ver usuarios'),
        ),
        const SizedBox(width: 12),
        WebGradientButton(
          onPressed: _computing ? null : _runCompute,
          isLoading: _computing,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.refresh, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(isMobile ? 'Recalcular' : 'Recalcular Traits'),
            ],
          ),
        ),
      ],
    );
  }

  // ── KPI Cards ────────────────────────────────────────────────────────────

  Widget _buildKpiCards(bool isDesktop, bool isMobile) {
    final cards = [
      _SummaryKpiCard(
        icon: Icons.people_outlined,
        label: 'Usuarios con traits',
        value: _totalUsersWithTraits.toString(),
        color: kWebInfo,
      ),
      _SummaryKpiCard(
        icon: Icons.touch_app_outlined,
        label: 'Eventos (90d)',
        value: _formatNumber(_totalEvents90d),
        color: kWebSecondary,
      ),
      _SummaryKpiCard(
        icon: Icons.bolt_outlined,
        label: 'Triggers (24h)',
        value: _triggersFired24h.toString(),
        color: kWebWarning,
      ),
      _SummaryKpiCard(
        icon: Icons.toggle_on_outlined,
        label: 'Triggers activos',
        value: _activeTriggersCount.toString(),
        color: kWebSuccess,
      ),
    ];

    if (isMobile) {
      return Column(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            cards[i],
            if (i < cards.length - 1) const SizedBox(height: 12),
          ],
        ],
      );
    }

    return GridView.count(
      crossAxisCount: isDesktop ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: isDesktop ? 2.4 : 2.0,
      children: cards,
    );
  }

  // ── Segment Breakdown ────────────────────────────────────────────────────

  Widget _buildSegmentSection(BuildContext context) {
    final theme = Theme.of(context);
    final total = _segmentCounts.values.fold(0, (a, b) => a + b);
    // Fixed ordering
    const order = ['new', 'casual', 'regular', 'power_user', 'dormant'];

    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: kWebPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.pie_chart_outline, size: 18, color: kWebPrimary),
              ),
              const SizedBox(width: 10),
              Text(
                'Segmentos de usuarios',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: kWebTextPrimary,
                ),
              ),
              const Spacer(),
              Text(
                'Total: $total',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: kWebTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Segment bar
          if (total > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 28,
                child: Row(
                  children: [
                    for (final seg in order)
                      if ((_segmentCounts[seg] ?? 0) > 0)
                        Expanded(
                          flex: _segmentCounts[seg]!,
                          child: Tooltip(
                            message:
                                '${_segmentLabels[seg] ?? seg}: ${_segmentCounts[seg]}',
                            child: Container(
                              color: _segmentColors[seg] ?? kWebTextHint,
                              alignment: Alignment.center,
                              child: _segmentCounts[seg]! > 0
                                  ? Text(
                                      '${_segmentCounts[seg]}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'system-ui',
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Legend chips
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (final seg in order)
                  if ((_segmentCounts[seg] ?? 0) > 0)
                    _SegmentChip(
                      label: _segmentLabels[seg] ?? seg,
                      count: _segmentCounts[seg]!,
                      color: _segmentColors[seg] ?? kWebTextHint,
                    ),
              ],
            ),
          ] else
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Sin datos de segmentos',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: kWebTextHint,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Trigger Log ──────────────────────────────────────────────────────────

  Widget _buildTriggerLog(BuildContext context) {
    final theme = Theme.of(context);

    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: kWebWarning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bolt_outlined, size: 18, color: kWebWarning),
              ),
              const SizedBox(width: 10),
              Text(
                'Trigger Log',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: kWebTextPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${_triggerLog.length} registros',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: kWebTextHint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_triggerLog.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined,
                        size: 36, color: kWebTextHint.withValues(alpha: 0.5)),
                    const SizedBox(height: 8),
                    Text(
                      'Sin triggers disparados',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: kWebTextHint),
                    ),
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 700),
                child: DataTable(
                  columnSpacing: 20,
                  headingRowHeight: 40,
                  dataRowMinHeight: 44,
                  dataRowMaxHeight: 56,
                  columns: const [
                    DataColumn(label: Text('Trigger')),
                    DataColumn(label: Text('Usuario')),
                    DataColumn(label: Text('Scores')),
                    DataColumn(label: Text('Accion')),
                    DataColumn(label: Text('Fecha')),
                    DataColumn(label: Text('Revisado')),
                  ],
                  rows: [
                    for (final entry in _triggerLog.take(20))
                      DataRow(
                        cells: [
                          DataCell(Text(
                            _triggerNames[entry['trigger_id']?.toString() ??
                                    ''] ??
                                '?',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              fontFamily: 'system-ui',
                            ),
                          )),
                          DataCell(Text(
                            _profileNames[
                                    entry['user_id']?.toString() ?? ''] ??
                                _truncateId(
                                    entry['user_id']?.toString() ?? ''),
                            style: const TextStyle(
                              fontSize: 13,
                              fontFamily: 'system-ui',
                            ),
                          )),
                          DataCell(
                            Tooltip(
                              message: _formatMatchedScores(
                                  entry['matched_scores'], true),
                              child: Text(
                                _formatMatchedScores(
                                    entry['matched_scores'], false),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: kWebTextSecondary,
                                  fontFamily: 'system-ui',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: kWebSecondary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                (entry['action_taken'] ?? '-') as String,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: kWebSecondary,
                                  fontFamily: 'system-ui',
                                ),
                              ),
                            ),
                          ),
                          DataCell(Text(
                            _formatTimestamp(entry['created_at']),
                            style: const TextStyle(
                              fontSize: 12,
                              color: kWebTextHint,
                              fontFamily: 'system-ui',
                            ),
                          )),
                          DataCell(
                            entry['reviewed_by'] != null
                                ? const Icon(Icons.check_circle,
                                    size: 18, color: kWebSuccess)
                                : IconButton(
                                    icon: const Icon(
                                        Icons.check_circle_outline,
                                        size: 18,
                                        color: kWebTextHint),
                                    tooltip: 'Marcar como revisado',
                                    onPressed: () => _markReviewed(entry),
                                  ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Trigger Management ───────────────────────────────────────────────────

  Widget _buildTriggerManagement(BuildContext context) {
    final theme = Theme.of(context);

    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: kWebSuccess.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.tune, size: 18, color: kWebSuccess),
              ),
              const SizedBox(width: 10),
              Text(
                'Triggers',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: kWebTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_triggers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Sin triggers configurados',
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: kWebTextHint),
                ),
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < _triggers.length; i++) ...[
                  _TriggerRow(
                    trigger: _triggers[i],
                    onToggle: () => _toggleTrigger(_triggers[i]),
                  ),
                  if (i < _triggers.length - 1)
                    Divider(
                      height: 1,
                      color: kWebCardBorder.withValues(alpha: 0.5),
                    ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  // ── User Trait Browser ───────────────────────────────────────────────────

  Widget _buildUserTraitBrowser(BuildContext context, bool isDesktop) {
    final theme = Theme.of(context);

    // Filter by search query
    final filtered = _traitSearchQuery.isEmpty
        ? _userSummaries
        : _userSummaries.where((s) {
            final uid = s['user_id']?.toString() ?? '';
            final name = _profileNames[uid]?.toLowerCase() ?? '';
            final segment = (s['segment'] ?? '').toString().toLowerCase();
            final q = _traitSearchQuery.toLowerCase();
            return name.contains(q) || segment.contains(q) || uid.contains(q);
          }).toList();

    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: kWebTertiary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.psychology_outlined,
                    size: 18, color: kWebTertiary),
              ),
              const SizedBox(width: 10),
              Text(
                'Trait Browser',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: kWebTextPrimary,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: isDesktop ? 280 : 200,
                height: 38,
                child: TextField(
                  onChanged: (v) => setState(() => _traitSearchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Buscar usuario...',
                    prefixIcon:
                        const Icon(Icons.search, size: 18, color: kWebTextHint),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: kWebCardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: kWebCardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: kWebPrimary, width: 1.5),
                    ),
                    filled: true,
                    fillColor: kWebBackground,
                  ),
                  style: const TextStyle(fontSize: 13, fontFamily: 'system-ui'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Trait column headers
          if (isDesktop) _buildTraitHeader(theme),
          if (isDesktop) const SizedBox(height: 8),
          // User rows
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  _traitSearchQuery.isEmpty
                      ? 'Sin datos de usuarios'
                      : 'Sin resultados para "$_traitSearchQuery"',
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: kWebTextHint),
                ),
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < filtered.length && i < 30; i++) ...[
                  _UserTraitRow(
                    summary: filtered[i],
                    traits: _userTraits[
                            filtered[i]['user_id']?.toString() ?? ''] ??
                        [],
                    userName: _profileNames[
                            filtered[i]['user_id']?.toString() ?? ''] ??
                        _truncateId(
                            filtered[i]['user_id']?.toString() ?? ''),
                    isDesktop: isDesktop,
                    traitOrder: _traits,
                    traitLabels: _traitLabels,
                    segmentLabel:
                        _segmentLabels[filtered[i]['segment']] ??
                            (filtered[i]['segment'] ?? '-').toString(),
                    segmentColor:
                        _segmentColors[filtered[i]['segment']] ?? kWebTextHint,
                  ),
                  if (i < filtered.length - 1 && i < 29)
                    Divider(
                      height: 1,
                      color: kWebCardBorder.withValues(alpha: 0.5),
                    ),
                ],
                if (filtered.length > 30)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      '+${filtered.length - 30} mas...',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: kWebTextHint),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTraitHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 180),
      child: Row(
        children: [
          for (final trait in _traits)
            Expanded(
              child: Text(
                _traitLabels[trait] ?? trait,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: kWebTextSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return '-';
    try {
      final dt = DateTime.parse(ts as String);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return DateFormat('d/M HH:mm').format(dt.toLocal());
    } catch (_) {
      return ts.toString();
    }
  }

  String _truncateId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 8)}...';
  }

  String _formatMatchedScores(dynamic scores, bool full) {
    if (scores == null) return '-';
    if (scores is Map) {
      final entries = scores.entries.toList();
      if (entries.isEmpty) return '-';
      if (full) {
        return entries
            .map((e) => '${e.key}: ${e.value}')
            .join(', ');
      }
      // Compact: show first 2 entries
      final compact = entries
          .take(2)
          .map((e) {
            final key = (e.key as String).replaceAll('_', ' ');
            final val = e.value is num
                ? (e.value as num).toStringAsFixed(0)
                : e.value.toString();
            return '$key:$val';
          })
          .join(', ');
      if (entries.length > 2) return '$compact +${entries.length - 2}';
      return compact;
    }
    return scores.toString();
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Summary KPI Card
// ════════════════════════════════════════════════════════════════════════════

class _SummaryKpiCard extends StatefulWidget {
  const _SummaryKpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  State<_SummaryKpiCard> createState() => _SummaryKpiCardState();
}

class _SummaryKpiCardState extends State<_SummaryKpiCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hovering ? -4 : 0, 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kWebSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovering
                ? widget.color.withValues(alpha: 0.3)
                : kWebCardBorder,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withValues(alpha: _hovering ? 0.06 : 0.03),
              blurRadius: _hovering ? 16 : 10,
              offset: Offset(0, _hovering ? 6 : 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(widget.icon, size: 22, color: widget.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: kWebTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: kWebTextSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Segment Chip
// ════════════════════════════════════════════════════════════════════════════

class _SegmentChip extends StatelessWidget {
  const _SegmentChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label ($count)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
              fontFamily: 'system-ui',
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Trigger Row
// ════════════════════════════════════════════════════════════════════════════

class _TriggerRow extends StatefulWidget {
  const _TriggerRow({
    required this.trigger,
    required this.onToggle,
  });

  final Map<String, dynamic> trigger;
  final VoidCallback onToggle;

  @override
  State<_TriggerRow> createState() => _TriggerRowState();
}

class _TriggerRowState extends State<_TriggerRow> {
  bool _hovering = false;
  bool _conditionsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = widget.trigger;
    final isActive = t['is_active'] == true;
    final conditions = t['conditions'];
    final lastFired = t['last_fired_at'];

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: _hovering
              ? kWebPrimary.withValues(alpha: 0.03)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (t['name'] ?? '-') as String,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: kWebTextPrimary,
                        ),
                      ),
                      if (t['description'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          t['description'] as String,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: kWebTextSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Fire count
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: kWebInfo.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${t['fire_count'] ?? 0}x',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: kWebInfo,
                      fontFamily: 'system-ui',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Active toggle
                SizedBox(
                  height: 28,
                  child: Switch(
                    value: isActive,
                    onChanged: (_) => widget.onToggle(),
                    activeThumbColor: kWebPrimary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            // Last fired
            if (lastFired != null) ...[
              const SizedBox(height: 4),
              Text(
                'Ultimo disparo: ${_formatTs(lastFired)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: kWebTextHint,
                  fontFamily: 'system-ui',
                ),
              ),
            ],
            // Expandable conditions
            if (conditions != null) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () =>
                    setState(() => _conditionsExpanded = !_conditionsExpanded),
                child: Row(
                  children: [
                    Icon(
                      _conditionsExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 16,
                      color: kWebTextHint,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Condiciones',
                      style: TextStyle(
                        fontSize: 11,
                        color: kWebTextHint,
                        fontFamily: 'system-ui',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (_conditionsExpanded) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kWebBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kWebCardBorder),
                  ),
                  child: Text(
                    _prettyJson(conditions),
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: kWebTextSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _formatTs(dynamic ts) {
    if (ts == null) return '-';
    try {
      final dt = DateTime.parse(ts as String).toLocal();
      return DateFormat('d/M HH:mm').format(dt);
    } catch (_) {
      return ts.toString();
    }
  }

  String _prettyJson(dynamic data) {
    if (data is Map || data is List) {
      try {
        // Simple display
        return data.toString().replaceAll(', ', ',\n  ').replaceAll('{', '{\n  ').replaceAll('}', '\n}');
      } catch (_) {
        return data.toString();
      }
    }
    return data.toString();
  }
}

// ════════════════════════════════════════════════════════════════════════════
// User Trait Row
// ════════════════════════════════════════════════════════════════════════════

class _UserTraitRow extends StatefulWidget {
  const _UserTraitRow({
    required this.summary,
    required this.traits,
    required this.userName,
    required this.isDesktop,
    required this.traitOrder,
    required this.traitLabels,
    required this.segmentLabel,
    required this.segmentColor,
  });

  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> traits;
  final String userName;
  final bool isDesktop;
  final List<String> traitOrder;
  final Map<String, String> traitLabels;
  final String segmentLabel;
  final Color segmentColor;

  @override
  State<_UserTraitRow> createState() => _UserTraitRowState();
}

class _UserTraitRowState extends State<_UserTraitRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Build a map of trait name -> score
    final scoreMap = <String, double>{};
    for (final t in widget.traits) {
      final traitName = t['trait'] as String?;
      final score = t['score'];
      if (traitName != null && score != null) {
        scoreMap[traitName] = (score is num) ? score.toDouble() : 0;
      }
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: _hovering
              ? kWebPrimary.withValues(alpha: 0.03)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: widget.isDesktop
            ? _buildDesktopRow(theme, scoreMap)
            : _buildMobileRow(theme, scoreMap),
      ),
    );
  }

  Widget _buildDesktopRow(ThemeData theme, Map<String, double> scoreMap) {
    return Row(
      children: [
        // User info (fixed width)
        SizedBox(
          width: 172,
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: widget.segmentColor.withValues(alpha: 0.12),
                child: Text(
                  widget.userName.isNotEmpty
                      ? widget.userName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: widget.segmentColor,
                    fontFamily: 'system-ui',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.userName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: kWebTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: widget.segmentColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.segmentLabel,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: widget.segmentColor,
                          fontFamily: 'system-ui',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Trait score bars
        for (final trait in widget.traitOrder)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _TraitBar(
                score: scoreMap[trait] ?? 0,
                maxScore: 100,
                color: _traitColor(trait, scoreMap[trait] ?? 0),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMobileRow(ThemeData theme, Map<String, double> scoreMap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // User info row
        Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: widget.segmentColor.withValues(alpha: 0.12),
              child: Text(
                widget.userName.isNotEmpty
                    ? widget.userName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: widget.segmentColor,
                  fontFamily: 'system-ui',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.userName,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: kWebTextPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: widget.segmentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.segmentLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: widget.segmentColor,
                  fontFamily: 'system-ui',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Compact trait bars in a wrap
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final trait in widget.traitOrder)
              SizedBox(
                width: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.traitLabels[trait] ?? trait,
                      style: const TextStyle(
                        fontSize: 9,
                        color: kWebTextHint,
                        fontFamily: 'system-ui',
                      ),
                    ),
                    const SizedBox(height: 2),
                    _TraitBar(
                      score: scoreMap[trait] ?? 0,
                      maxScore: 100,
                      color: _traitColor(trait, scoreMap[trait] ?? 0),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Color _traitColor(String trait, double score) {
    // For churn_risk and cancellation_rate, high is bad
    if (trait == 'churn_risk' || trait == 'cancellation_rate') {
      if (score >= 70) return kWebError;
      if (score >= 40) return kWebWarning;
      return kWebSuccess;
    }
    // For all others, high is good
    if (score >= 70) return kWebSuccess;
    if (score >= 40) return kWebWarning;
    return kWebError;
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Trait Bar
// ════════════════════════════════════════════════════════════════════════════

class _TraitBar extends StatelessWidget {
  const _TraitBar({
    required this.score,
    required this.maxScore,
    required this.color,
  });

  final double score;
  final double maxScore;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fraction = maxScore > 0 ? (score / maxScore).clamp(0.0, 1.0) : 0.0;

    return Tooltip(
      message: score.toStringAsFixed(1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 6,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: fraction,
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            score.toStringAsFixed(0),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color,
              fontFamily: 'system-ui',
            ),
          ),
        ],
      ),
    );
  }
}
