import 'package:beautycita_core/supabase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// HVT (High-Value Target) classifier — recruitment posture per discovered
/// salon. Six tiers ordered top-down. NOT a CRM. NOT analytics. Tier guides
/// HOW to approach a lead BEFORE first contact.
///
/// Mirrors admin_salones_insights_screen.dart (mobile) so admin/superadmin on
/// desktop sees the same tier board with the same actions.
class SalonsInsightsPage extends ConsumerStatefulWidget {
  const SalonsInsightsPage({super.key});

  @override
  ConsumerState<SalonsInsightsPage> createState() => _SalonsInsightsPageState();
}

class _SalonsInsightsPageState extends ConsumerState<SalonsInsightsPage> {
  final _supabase = Supabase.instance.client;
  Future<_BoardData>? _future;

  @override
  void initState() {
    super.initState();
    _future = _loadBoard();
  }

  Future<_BoardData> _loadBoard() async {
    final tiersRaw = await _supabase
        .from(BCTables.discoveredSalonTiers)
        .select('id, rank, label, description, posture, color_hex, is_active')
        .eq('is_active', true)
        .order('rank');
    final tiers = (tiersRaw as List).cast<Map<String, dynamic>>();

    final salonsRaw = await _supabase
        .from(BCTables.discoveredSalons)
        .select('id, business_name, location_city, location_state, '
            'tier_id, hvt_score, owner_chain_size, years_in_business, '
            'reputation_score, reputation_signal_count, social_followers, '
            'press_mentions, tier_locked')
        .not('tier_id', 'is', null)
        .order('hvt_score', ascending: false)
        .limit(800);
    final salons = (salonsRaw as List).cast<Map<String, dynamic>>();

    final byTier = <String, List<Map<String, dynamic>>>{};
    for (final s in salons) {
      final t = s['tier_id'] as String?;
      if (t == null) continue;
      byTier.putIfAbsent(t, () => []).add(s);
    }
    // Cap each visible column to 80 on the wider desktop layout.
    for (final list in byTier.values) {
      if (list.length > 80) list.removeRange(80, list.length);
    }

    final countsRaw = await _supabase.rpc('count_salons_per_tier').catchError(
      (_) => null,
    );
    final counts = <String, int>{};
    if (countsRaw is List) {
      for (final row in countsRaw) {
        if (row is Map) {
          counts[row['tier_id'] as String] = (row['n'] as num).toInt();
        }
      }
    } else {
      for (final s in salons) {
        final t = s['tier_id'] as String?;
        if (t != null) counts[t] = (counts[t] ?? 0) + 1;
      }
    }

    return _BoardData(tiers: tiers, salonsByTier: byTier, counts: counts);
  }

  Future<void> _refresh() async {
    setState(() => _future = _loadBoard());
    await _future;
  }

  Future<void> _runReclassify({String? salonId}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final body = salonId != null
          ? {'salon_ids': [salonId], 'force': true}
          : {'force': true};
      final res = await _supabase.functions
          .invoke('classify-discovered-salons', body: body);
      final data = res.data as Map<String, dynamic>?;
      messenger.showSnackBar(
        SnackBar(
          content: Text(salonId != null
              ? 'Salón reclasificado'
              : 'Reclasificación masiva: ${data?['updated'] ?? 0} actualizados'),
          duration: const Duration(seconds: 3),
        ),
      );
      await _refresh();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _toggleLock(Map<String, dynamic> salon) async {
    final wasLocked = salon['tier_locked'] == true;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _supabase
          .from(BCTables.discoveredSalons)
          .update({'tier_locked': !wasLocked}).eq('id', salon['id']);
      await _refresh();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _showReassignDialog(
    Map<String, dynamic> salon,
    List<Map<String, dynamic>> tiers,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reasignar tier'),
        content: SizedBox(
          width: 480,
          child: ListView(
            shrinkWrap: true,
            children: tiers.map((t) {
              final isCurrent = t['id'] == salon['tier_id'];
              return ListTile(
                leading: CircleAvatar(
                  radius: 10,
                  backgroundColor:
                      _hexColor(t['color_hex'] as String? ?? '#777'),
                ),
                title: Text(t['label'] as String,
                    style: TextStyle(
                      fontWeight:
                          isCurrent ? FontWeight.w800 : FontWeight.w500,
                    )),
                subtitle: Text(t['description'] as String,
                    style: const TextStyle(fontSize: 11)),
                trailing: isCurrent ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, t['id'] as String),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
        ],
      ),
    );
    if (picked == null || picked == salon['tier_id']) return;

    try {
      final user = _supabase.auth.currentUser;
      await _supabase.from(BCTables.discoveredSalonTierAssignments).insert({
        'discovered_salon_id': salon['id'],
        'tier_id': picked,
        'assigned_by': user?.id,
        'source': 'manual',
        'reason':
            'Manual reassignment from ${salon['tier_id']} to $picked',
        'is_current': true,
      });
      await _refresh();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showSalonSheet(
    Map<String, dynamic> salon,
    List<Map<String, dynamic>> tiers,
  ) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: _SalonInsightDetail(
            salon: salon,
            tiers: tiers,
            onClose: () => Navigator.pop(context),
            onReassign: () {
              Navigator.pop(context);
              _showReassignDialog(salon, tiers);
            },
            onToggleLock: () {
              Navigator.pop(context);
              _toggleLock(salon);
            },
            onReclassify: () {
              Navigator.pop(context);
              _runReclassify(salonId: salon['id'] as String);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FutureBuilder<_BoardData>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 40, color: colors.error.withValues(alpha: 0.6)),
                  const SizedBox(height: 12),
                  const Text('Error cargando insights'),
                  const SizedBox(height: 8),
                  SelectableText('${snap.error}',
                      style: TextStyle(
                          color: colors.onSurface.withValues(alpha: 0.6))),
                ],
              ),
            ),
          );
        }
        final data = snap.data;
        if (data == null) return const SizedBox.shrink();
        return _buildBoard(data);
      },
    );
  }

  Widget _buildBoard(_BoardData data) {
    final colors = Theme.of(context).colorScheme;
    final total = data.counts.values.fold<int>(0, (a, b) => a + b);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.diamond_outlined, color: colors.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Insights de objetivos',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '$total salones clasificados — clic en un tier para ver detalle',
                        style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurface.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Reclasificar todo'),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title:
                            const Text('Reclasificar todos los salones?'),
                        content: const Text(
                            'Esto recalcula tier para todos los salones no bloqueados. Puede tomar 1-2 minutos.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancelar')),
                          ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Reclasificar')),
                        ],
                      ),
                    );
                    if (ok == true) await _runReclassify();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Six-column tier board on wide desktop, stacked on narrow.
          LayoutBuilder(
            builder: (ctx, constraints) {
              final wide = constraints.maxWidth >= 1280;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final tier in data.tiers)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: _buildTierColumn(
                            tier,
                            data.salonsByTier[tier['id']] ?? const [],
                            data.counts[tier['id']] ?? 0,
                            data.tiers,
                          ),
                        ),
                      ),
                  ],
                );
              }
              return Column(
                children: [
                  for (final tier in data.tiers)
                    _buildTierColumn(
                      tier,
                      data.salonsByTier[tier['id']] ?? const [],
                      data.counts[tier['id']] ?? 0,
                      data.tiers,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTierColumn(
    Map<String, dynamic> tier,
    List<Map<String, dynamic>> salons,
    int totalCount,
    List<Map<String, dynamic>> allTiers,
  ) {
    final colors = Theme.of(context).colorScheme;
    final tierColor = _hexColor(tier['color_hex'] as String? ?? '#777');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: tierColor.withValues(alpha: 0.30), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 6),
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                      color: tierColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tier['label'] as String,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: tierColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$totalCount',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: tierColor),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              tier['posture'] as String,
              style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: colors.onSurface.withValues(alpha: 0.62)),
            ),
          ),
          const SizedBox(height: 8),
          if (salons.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
              child: Text(
                'Sin salones en este tier todavía.',
                style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurface.withValues(alpha: 0.45)),
              ),
            )
          else
            ...salons.map((s) => _buildSalonRow(s, allTiers, tierColor)),
          if (totalCount > salons.length)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Text(
                '+${totalCount - salons.length} más en este tier',
                style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurface.withValues(alpha: 0.55)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSalonRow(
    Map<String, dynamic> salon,
    List<Map<String, dynamic>> tiers,
    Color tierColor,
  ) {
    final colors = Theme.of(context).colorScheme;
    final name = (salon['business_name'] ?? '—') as String;
    final city = salon['location_city']?.toString();
    final score = (salon['hvt_score'] as num?)?.toDouble() ?? 0;
    final chain = (salon['owner_chain_size'] as num?)?.toInt() ?? 1;
    final years = (salon['years_in_business'] as num?)?.toInt();
    final rating = (salon['reputation_score'] as num?)?.toDouble();
    final ratingCount =
        (salon['reputation_signal_count'] as num?)?.toInt() ?? 0;
    final social = (salon['social_followers'] as num?)?.toInt();
    final locked = salon['tier_locked'] == true;

    final pills = <Widget>[];
    if (chain >= 2) pills.add(_pill('${chain}x ubic.', Colors.blue.shade700));
    if (years != null && years >= 5) pills.add(_pill('$years+ años', Colors.teal));
    if (rating != null && ratingCount > 0) {
      pills.add(_pill(
        '★${rating.toStringAsFixed(1)} · $ratingCount',
        Colors.amber.shade800,
      ));
    }
    if (social != null && social >= 1000) {
      pills.add(_pill(
        social >= 1000000
            ? '${(social / 1000000).toStringAsFixed(1)}M'
            : '${(social / 1000).toStringAsFixed(0)}K',
        Colors.purple.shade400,
      ));
    }

    return InkWell(
      onTap: () => _showSalonSheet(salon, tiers),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (locked)
                        Icon(Icons.lock,
                            size: 12,
                            color:
                                colors.onSurface.withValues(alpha: 0.5)),
                      const SizedBox(width: 6),
                      Text(
                        score.toStringAsFixed(0),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: tierColor),
                      ),
                    ],
                  ),
                  if (city != null && city.isNotEmpty)
                    Text(city,
                        style: TextStyle(
                            fontSize: 10,
                            color:
                                colors.onSurface.withValues(alpha: 0.55))),
                  if (pills.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(spacing: 6, runSpacing: 4, children: pills),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: colors.onSurface.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      );
}

class _BoardData {
  final List<Map<String, dynamic>> tiers;
  final Map<String, List<Map<String, dynamic>>> salonsByTier;
  final Map<String, int> counts;
  _BoardData({
    required this.tiers,
    required this.salonsByTier,
    required this.counts,
  });
}

class _SalonInsightDetail extends StatelessWidget {
  final Map<String, dynamic> salon;
  final List<Map<String, dynamic>> tiers;
  final VoidCallback onClose;
  final VoidCallback onReassign;
  final VoidCallback onToggleLock;
  final VoidCallback onReclassify;
  const _SalonInsightDetail({
    required this.salon,
    required this.tiers,
    required this.onClose,
    required this.onReassign,
    required this.onToggleLock,
    required this.onReclassify,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tierId = salon['tier_id'] as String?;
    final tier = tiers.firstWhere(
      (t) => t['id'] == tierId,
      orElse: () => {
        'label': '—',
        'color_hex': '#777',
        'description': '',
        'posture': '',
      },
    );
    final tierColor = _hexColor(tier['color_hex'] as String? ?? '#777');
    final locked = salon['tier_locked'] == true;
    final score = (salon['hvt_score'] as num?)?.toDouble() ?? 0;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (salon['business_name'] ?? '—') as String,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: onClose),
            ],
          ),
          Text(
            [
              if ((salon['location_city'] ?? '') != '') salon['location_city'],
              if ((salon['location_state'] ?? '') != '') salon['location_state'],
            ].join(', '),
            style: TextStyle(
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: 0.65)),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tierColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tierColor.withValues(alpha: 0.30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                          color: tierColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tier['label'] as String,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: tierColor),
                    ),
                    const Spacer(),
                    if (locked)
                      Icon(Icons.lock_outline, size: 16, color: tierColor),
                    Text('  ${score.toStringAsFixed(1)}',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: tierColor)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(tier['description'] as String,
                    style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                Text(tier['posture'] as String,
                    style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: colors.onSurface.withValues(alpha: 0.75))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _section('Señales'),
          const SizedBox(height: 8),
          _row('Cadena (ubicaciones)', '${salon['owner_chain_size'] ?? 1}'),
          _row('Años en el negocio',
              salon['years_in_business']?.toString() ?? '—'),
          _row(
            'Reputación',
            (salon['reputation_score'] != null)
                ? '${(salon['reputation_score'] as num).toStringAsFixed(1)} ★ · ${salon['reputation_signal_count'] ?? 0} reseñas'
                : '—',
          ),
          _row('Seguidores RSS',
              salon['social_followers']?.toString() ?? '—'),
          _row('Menciones de prensa',
              salon['press_mentions']?.toString() ?? '0'),
          const SizedBox(height: 20),
          _section('Acciones'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.swap_vert),
                label: const Text('Reasignar tier'),
                onPressed: onReassign,
              ),
              OutlinedButton.icon(
                icon: Icon(locked ? Icons.lock_open : Icons.lock_outline),
                label: Text(locked ? 'Desbloquear tier' : 'Bloquear tier'),
                onPressed: onToggleLock,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Reclasificar este salón'),
                onPressed: onReclassify,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section(String text) => Text(
        text.toUpperCase(),
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: Colors.grey.shade600),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade700)),
            ),
            Expanded(
              flex: 2,
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

Color _hexColor(String hex) {
  var h = hex.replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}
