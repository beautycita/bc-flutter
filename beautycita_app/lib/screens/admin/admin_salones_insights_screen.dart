import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:beautycita/config/fonts.dart';
import '../../config/constants.dart';
import '../../services/toast_service.dart';

/// HVT (High-Value Target) classifier — recruitment posture per discovered
/// salon. Six tiers ordered top-down. NOT a CRM. NOT analytics. The team uses
/// the tier to decide HOW to approach a lead BEFORE first contact.
class AdminSalonesInsightsScreen extends ConsumerStatefulWidget {
  const AdminSalonesInsightsScreen({super.key});

  @override
  ConsumerState<AdminSalonesInsightsScreen> createState() =>
      _AdminSalonesInsightsScreenState();
}

class _AdminSalonesInsightsScreenState
    extends ConsumerState<AdminSalonesInsightsScreen> {
  final _supabase = Supabase.instance.client;
  Future<_BoardData>? _future;

  @override
  void initState() {
    super.initState();
    _future = _loadBoard();
  }

  Future<_BoardData> _loadBoard() async {
    // Tier definitions (admin-editable). We rely on RLS to scope correctly.
    final tiersRaw = await _supabase
        .from('discovered_salon_tiers')
        .select('id, rank, label, description, posture, color_hex, is_active')
        .eq('is_active', true)
        .order('rank');
    final tiers = (tiersRaw as List).cast<Map<String, dynamic>>();

    // Salons per tier — top-N by score within each tier so the screen stays
    // responsive even with 100K+ rows. "Show all" lives behind a per-column
    // expand action wired in v2.
    final salonsRaw = await _supabase
        .from('discovered_salons')
        .select('id, business_name, location_city, location_state, '
            'tier_id, hvt_score, owner_chain_size, years_in_business, '
            'reputation_score, reputation_signal_count, social_followers, '
            'press_mentions, tier_locked')
        .not('tier_id', 'is', null)
        .order('hvt_score', ascending: false)
        .limit(600);
    final salons = (salonsRaw as List).cast<Map<String, dynamic>>();

    // Group by tier_id, cap each column to 50 visible.
    final byTier = <String, List<Map<String, dynamic>>>{};
    for (final s in salons) {
      final t = s['tier_id'] as String?;
      if (t == null) continue;
      byTier.putIfAbsent(t, () => []).add(s);
    }
    for (final list in byTier.values) {
      if (list.length > 50) list.removeRange(50, list.length);
    }

    // Total counts per tier (cheap aggregate).
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
      // RPC missing — fall back to client-side count
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
      ToastService.showError('Error al reclasificar: $e');
    }
  }

  Future<void> _toggleLock(Map<String, dynamic> salon) async {
    final wasLocked = salon['tier_locked'] == true;
    try {
      await _supabase
          .from('discovered_salons')
          .update({'tier_locked': !wasLocked}).eq('id', salon['id']);
      ToastService.showSuccess(wasLocked ? 'Tier desbloqueado' : 'Tier bloqueado');
      await _refresh();
    } catch (e) {
      ToastService.showError('Error: $e');
    }
  }

  Future<void> _showReassignDialog(
      Map<String, dynamic> salon, List<Map<String, dynamic>> tiers) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reasignar tier',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: double.maxFinite,
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
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight:
                            isCurrent ? FontWeight.w800 : FontWeight.w500)),
                subtitle: Text(t['description'] as String,
                    style: GoogleFonts.nunito(fontSize: 11)),
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
      // Append a new current tier_assignment with source='manual'. Trigger
      // demotes the prior current row + syncs cached column.
      final user = _supabase.auth.currentUser;
      await _supabase.from('discovered_salon_tier_assignments').insert({
        'discovered_salon_id': salon['id'],
        'tier_id': picked,
        'assigned_by': user?.id,
        'source': 'manual',
        'reason':
            'Manual reassignment from ${salon['tier_id']} to $picked',
        'is_current': true,
      });
      ToastService.showSuccess('Tier reasignado a $picked');
      await _refresh();
    } catch (e) {
      ToastService.showError('Error al reasignar: $e');
    }
  }

  void _showSalonSheet(Map<String, dynamic> salon, List<Map<String, dynamic>> tiers) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SalonInsightSheet(
        salon: salon,
        tiers: tiers,
        onReassign: () => _showReassignDialog(salon, tiers),
        onToggleLock: () => _toggleLock(salon),
        onReclassify: () => _runReclassify(salonId: salon['id'] as String),
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
                  Text('Error cargando insights',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('${snap.error}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                          fontSize: 12,
                          color:
                              colors.onSurface.withValues(alpha: 0.6))),
                ],
              ),
            ),
          );
        }
        final data = snap.data;
        if (data == null) return const SizedBox.shrink();

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppConstants.paddingMD,
              AppConstants.paddingSM,
              AppConstants.paddingMD,
              AppConstants.paddingLG,
            ),
            children: [
              _buildHeader(data),
              const SizedBox(height: 12),
              for (final tier in data.tiers)
                _buildTierColumn(
                  tier,
                  data.salonsByTier[tier['id']] ?? const [],
                  data.counts[tier['id']] ?? 0,
                  data.tiers,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(_BoardData data) {
    final colors = Theme.of(context).colorScheme;
    final total =
        data.counts.values.fold<int>(0, (a, b) => a + b);
    return Container(
      padding: const EdgeInsets.all(12),
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
                Text(
                  'Insights de objetivos',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                Text(
                  '$total salones clasificados — toca un tier para ver detalle',
                  style: GoogleFonts.nunito(
                      fontSize: 11,
                      color: colors.onSurface.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reclasificar todo',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Reclasificar todos los salones?'),
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
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
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
                    color: tierColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tier['label'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: tierColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$totalCount',
                    style: GoogleFonts.poppins(
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
              style: GoogleFonts.nunito(
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
                style: GoogleFonts.nunito(
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
                style: GoogleFonts.nunito(
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
            ? '${(social / 1000000).toStringAsFixed(1)}M IG'
            : '${(social / 1000).toStringAsFixed(0)}K IG',
        Colors.purple.shade400,
      ));
    }

    return InkWell(
      onTap: () => _showSalonSheet(salon, tiers),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                          style: GoogleFonts.poppins(
                              fontSize: 13, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (locked)
                        Icon(Icons.lock,
                            size: 12,
                            color: colors.onSurface.withValues(alpha: 0.5)),
                      const SizedBox(width: 6),
                      Text(
                        score.toStringAsFixed(0),
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: tierColor),
                      ),
                    ],
                  ),
                  if (city != null && city.isNotEmpty)
                    Text(city,
                        style: GoogleFonts.nunito(
                            fontSize: 10,
                            color: colors.onSurface
                                .withValues(alpha: 0.55))),
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
            style: GoogleFonts.nunito(
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

class _SalonInsightSheet extends StatelessWidget {
  final Map<String, dynamic> salon;
  final List<Map<String, dynamic>> tiers;
  final VoidCallback onReassign;
  final VoidCallback onToggleLock;
  final VoidCallback onReclassify;
  const _SalonInsightSheet({
    required this.salon,
    required this.tiers,
    required this.onReassign,
    required this.onToggleLock,
    required this.onReclassify,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final maxH = MediaQuery.of(context).size.height * 0.85;
    final tierId = salon['tier_id'] as String?;
    final tier = tiers.firstWhere(
      (t) => t['id'] == tierId,
      orElse: () => {'label': '—', 'color_hex': '#777', 'description': '', 'posture': ''},
    );
    final tierColor = _hexColor(tier['color_hex'] as String? ?? '#777');
    final locked = salon['tier_locked'] == true;
    final score = (salon['hvt_score'] as num?)?.toDouble() ?? 0;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            (salon['business_name'] ?? '—') as String,
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            [
              if ((salon['location_city'] ?? '') != '') salon['location_city'],
              if ((salon['location_state'] ?? '') != '') salon['location_state'],
            ].join(', '),
            style: GoogleFonts.nunito(
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: 0.65)),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
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
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: tierColor),
                    ),
                    const Spacer(),
                    if (locked)
                      Icon(Icons.lock_outline, size: 16, color: tierColor),
                    Text('  ${score.toStringAsFixed(1)}',
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: tierColor)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(tier['description'] as String,
                    style: GoogleFonts.nunito(fontSize: 12)),
                const SizedBox(height: 8),
                Text(tier['posture'] as String,
                    style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: colors.onSurface.withValues(alpha: 0.75))),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _sectionTitle('Señales'),
          const SizedBox(height: 8),
          _signalRow('Cadena (ubicaciones)',
              '${salon['owner_chain_size'] ?? 1}', colors),
          _signalRow('Años en el negocio',
              salon['years_in_business']?.toString() ?? '—', colors),
          _signalRow(
            'Reputación',
            (salon['reputation_score'] != null)
                ? '${(salon['reputation_score'] as num).toStringAsFixed(1)} ★ · ${salon['reputation_signal_count'] ?? 0} reseñas'
                : '—',
            colors,
          ),
          _signalRow('Seguidores RSS',
              salon['social_followers']?.toString() ?? '—', colors),
          _signalRow('Menciones de prensa',
              salon['press_mentions']?.toString() ?? '0', colors),
          const SizedBox(height: 20),
          _sectionTitle('Acciones'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.swap_vert),
            label: const Text('Reasignar tier'),
            onPressed: () {
              Navigator.pop(context);
              onReassign();
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: Icon(locked ? Icons.lock_open : Icons.lock_outline),
            label: Text(locked ? 'Desbloquear tier' : 'Bloquear tier'),
            onPressed: () {
              Navigator.pop(context);
              onToggleLock();
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Reclasificar este salón'),
            onPressed: () {
              Navigator.pop(context);
              onReclassify();
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text.toUpperCase(),
        style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: Colors.grey.shade600),
      );

  Widget _signalRow(String label, String value, ColorScheme colors) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(label,
                  style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: colors.onSurface.withValues(alpha: 0.6))),
            ),
            Expanded(
              flex: 2,
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.poppins(
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
