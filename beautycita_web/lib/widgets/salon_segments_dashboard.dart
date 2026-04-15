import 'package:beautycita_core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/salon_segments_provider.dart';

/// Card grid showing 10 computed salon segments from discovered_salons.
/// Designed for the admin Intelligence section.
class SalonSegmentsDashboard extends ConsumerWidget {
  const SalonSegmentsDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segmentsAsync = ref.watch(salonSegmentsProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return segmentsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Error: $e', style: TextStyle(color: colors.error)),
      ),
      data: (data) {
        if (data.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Text('Sin datos de segmentacion'),
          );
        }

        final total = (data['total'] as int?) ?? 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, BCSpacing.md),
              child: Row(
                children: [
                  Icon(Icons.analytics_outlined, size: 20, color: colors.primary),
                  const SizedBox(width: BCSpacing.sm),
                  Text(
                    'Segmentacion de Mercado',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_fmt(total)} salones descubiertos',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: BCSpacing.sm),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    tooltip: 'Actualizar',
                    onPressed: () => ref.invalidate(salonSegmentsProvider),
                  ),
                ],
              ),
            ),

            // Segment cards grid
            Wrap(
              spacing: BCSpacing.md,
              runSpacing: BCSpacing.md,
              children: [
                _SegmentCard(
                  icon: Icons.business,
                  title: 'Cadenas',
                  value: '${data['chains']?['count'] ?? 0}',
                  subtitle: '${data['chains']?['total_locations'] ?? 0} ubicaciones',
                  color: Colors.indigo,
                ),
                _SegmentCard(
                  icon: Icons.trending_up,
                  title: 'Alto Volumen',
                  value: _fmt((data['high_volume']?['count'] as int?) ?? 0),
                  subtitle: '\$${_fmt((data['high_volume']?['avg_revenue'] as int?) ?? 0)}/mes prom',
                  color: Colors.green,
                ),
                _SegmentCard(
                  icon: Icons.person,
                  title: 'Solo Stylists',
                  value: _fmt((data['solo_stylists']?['count'] as int?) ?? 0),
                  subtitle: 'Operacion individual',
                  color: Colors.teal,
                ),
                _SegmentCard(
                  icon: Icons.star,
                  title: 'Especialistas',
                  value: _fmt((data['specialists']?['count'] as int?) ?? 0),
                  subtitle: 'Una sola categoria',
                  color: Colors.purple,
                ),
                _buildPriceTierCard(data['price_tiers'] ?? {}),
                _buildTechCard(data['tech_readiness'] ?? {}),
                _buildOutreachCard(data['outreach_status'] ?? {}),
                _buildEnrichmentCard(data['enrichment'] ?? {}),
              ],
            ),

            const SizedBox(height: BCSpacing.lg),

            // Geographic clusters
            if (data['geographic_clusters'] != null)
              _buildClustersSection(context, data['geographic_clusters'] as List),

            const SizedBox(height: BCSpacing.md),

            // State distribution
            if (data['state_distribution'] != null)
              _buildStatesSection(context, data['state_distribution'] as List),
          ],
        );
      },
    );
  }

  Widget _buildPriceTierCard(Map<String, dynamic> tiers) {
    final b = (tiers['budget'] as int?) ?? 0;
    final m = (tiers['mid'] as int?) ?? 0;
    final p = (tiers['premium'] as int?) ?? 0;
    final l = (tiers['luxury'] as int?) ?? 0;
    return _SegmentCard(
      icon: Icons.attach_money,
      title: 'Nivel de Precio',
      value: _fmt(b + m + p + l),
      subtitle: 'B:${_fmt(b)} M:${_fmt(m)} P:${_fmt(p)} L:${_fmt(l)}',
      color: Colors.amber.shade700,
    );
  }

  Widget _buildTechCard(Map<String, dynamic> tech) {
    return _SegmentCard(
      icon: Icons.devices,
      title: 'Tech Readiness',
      value: _fmt((tech['has_booking_system'] as int?) ?? 0),
      subtitle: 'Con booking system. ${_fmt((tech['paper_only'] as int?) ?? 0)} sin presencia digital',
      color: Colors.blue,
    );
  }

  Widget _buildOutreachCard(Map<String, dynamic> o) {
    return _SegmentCard(
      icon: Icons.campaign,
      title: 'Outreach',
      value: _fmt((o['never_contacted'] as int?) ?? 0),
      subtitle: 'Nunca contactados. WA: ${_fmt((o['wa_verified'] as int?) ?? 0)}',
      color: Colors.deepOrange,
    );
  }

  Widget _buildEnrichmentCard(Map<String, dynamic> e) {
    return _SegmentCard(
      icon: Icons.auto_awesome,
      title: 'Enrichment',
      value: _fmt((e['fully_enriched'] as int?) ?? 0),
      subtitle: 'Completos. ${_fmt((e['not_enriched'] as int?) ?? 0)} sin enriquecer',
      color: Colors.cyan,
    );
  }

  Widget _buildClustersSection(BuildContext context, List clusters) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Top Ciudades por Densidad',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: BCSpacing.sm),
        Wrap(
          spacing: BCSpacing.sm,
          runSpacing: BCSpacing.sm,
          children: clusters.map<Widget>((c) {
            final m = c as Map<String, dynamic>;
            return Chip(
              avatar: CircleAvatar(
                backgroundColor: colors.primary.withValues(alpha: 0.1),
                child: Text('${m['salon_count']}',
                    style: TextStyle(fontSize: 10, color: colors.primary, fontWeight: FontWeight.w700)),
              ),
              label: Text('${m['city']}, ${m['state']}',
                  style: theme.textTheme.bodySmall),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStatesSection(BuildContext context, List states) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Top Estados',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: BCSpacing.sm),
        Wrap(
          spacing: BCSpacing.sm,
          runSpacing: BCSpacing.sm,
          children: states.map<Widget>((s) {
            final m = s as Map<String, dynamic>;
            return Chip(
              avatar: CircleAvatar(
                backgroundColor: colors.secondary.withValues(alpha: 0.1),
                child: Text(_fmt((m['salon_count'] as int?) ?? 0),
                    style: TextStyle(fontSize: 9, color: colors.secondary, fontWeight: FontWeight.w700)),
              ),
              label: Text('${m['state']}', style: theme.textTheme.bodySmall),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
          }).toList(),
        ),
      ],
    );
  }

  static String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _SegmentCard extends StatefulWidget {
  const _SegmentCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  @override
  State<_SegmentCard> createState() => _SegmentCardState();
}

class _SegmentCardState extends State<_SegmentCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 220,
        padding: const EdgeInsets.all(BCSpacing.md),
        decoration: BoxDecoration(
          color: _hovering
              ? widget.color.withValues(alpha: 0.06)
              : colors.surface,
          borderRadius: BorderRadius.circular(BCSpacing.radiusSm),
          border: Border.all(
            color: _hovering
                ? widget.color.withValues(alpha: 0.3)
                : colors.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(widget.icon, size: 18, color: widget.color),
                const SizedBox(width: BCSpacing.sm),
                Expanded(
                  child: Text(
                    widget.title,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: BCSpacing.sm),
            Text(
              widget.value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: widget.color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.5),
                fontSize: 11,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
