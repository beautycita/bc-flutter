import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:beautycita_core/supabase.dart';

import '../../config/breakpoints.dart';
import '../../providers/admin_outreach_provider.dart';
import '../../providers/admin_salons_provider.dart' as salons_provider;
import '../../providers/rp_centro_provider.dart';
import '../../widgets/contact_panel.dart';

/// Outreach pipeline page — `/app/admin/outreach`
///
/// Kanban-style view of salons moving through the outreach pipeline:
/// Seleccionados -> Contactados -> Registrados | Rechazados / No alcanzables
///
/// "Descubiertos" (28k+) are NOT shown individually — only a count in the
/// header. Use the Salons page to browse the full discovered list.
class OutreachPage extends ConsumerStatefulWidget {
  const OutreachPage({super.key});

  @override
  ConsumerState<OutreachPage> createState() => _OutreachPageState();
}

class _OutreachPageState extends ConsumerState<OutreachPage> {
  DiscoveredSalon? _selectedSalon;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<DiscoveredSalon> _filterSalons(List<DiscoveredSalon> salons) {
    if (_searchQuery.isEmpty) return salons;
    final q = _searchQuery.toLowerCase();
    return salons.where((s) => s.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final salonsAsync = ref.watch(pipelineSalonsProvider);
    final stageCounts = ref.watch(outreachStageCounts);
    final discoveredCounts = ref.watch(discoveredCountsProvider);
    final enrichmentAsync = ref.watch(enrichmentStatsProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = WebBreakpoints.isMobile(width);
        final isDesktop = WebBreakpoints.isDesktop(width);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              stageCounts: stageCounts,
              discoveredCounts: discoveredCounts,
              isMobile: isMobile,
              searchController: _searchController,
              onSearchChanged: (value) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), () {
                  setState(() => _searchQuery = value);
                });
              },
            ),
            // Enrichment monitor card
            _EnrichmentMonitorCard(enrichmentAsync: enrichmentAsync),
            const Divider(height: 1),
            Expanded(
              child: salonsAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (salons) {
                  final filtered = _filterSalons(salons);
                  if (filtered.isEmpty && salons.isEmpty) {
                    return _emptyState(context);
                  }

                  if (_selectedSalon != null && !isMobile) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _KanbanBoard(
                            salons: filtered,
                            isDesktop: isDesktop,
                            isMobile: isMobile,
                            onSelect: (s) =>
                                setState(() => _selectedSalon = s),
                          ),
                        ),
                        VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        SizedBox(
                          width: 380,
                          child: _SalonDetail(
                            salon: _selectedSalon!,
                            onClose: () =>
                                setState(() => _selectedSalon = null),
                          ),
                        ),
                      ],
                    );
                  }

                  if (_selectedSalon != null && isMobile) {
                    return _SalonDetail(
                      salon: _selectedSalon!,
                      onClose: () =>
                          setState(() => _selectedSalon = null),
                    );
                  }

                  return _KanbanBoard(
                    salons: filtered,
                    isDesktop: isDesktop,
                    isMobile: isMobile,
                    onSelect: (s) =>
                        setState(() => _selectedSalon = s),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _emptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.campaign_outlined,
            size: 48,
            color: colors.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'Sin salones en el pipeline',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Selecciona salones desde la pagina de Salones para iniciar outreach.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.4),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.stageCounts,
    required this.discoveredCounts,
    required this.isMobile,
    required this.searchController,
    required this.onSearchChanged,
  });
  final Map<OutreachStage, int> stageCounts;
  final AsyncValue<Map<String, int>> discoveredCounts;
  final bool isMobile;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final pipelineTotal =
        stageCounts.values.fold<int>(0, (sum, c) => sum + c);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16.0 : 24.0,
        vertical: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pipeline de Outreach',
                  style: (isMobile
                          ? theme.textTheme.titleMedium
                          : theme.textTheme.headlineSmall)
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              // Discovered count (from scraper)
              discoveredCounts.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (counts) {
                  final total = counts['total'] ?? 0;
                  final mx = counts['MX'] ?? 0;
                  final us = counts['US'] ?? 0;
                  if (total == 0) return const SizedBox.shrink();
                  return Tooltip(
                    message: 'MX: $mx  |  US: $us',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.radar, size: 14,
                              color: colors.onSurface.withValues(alpha: 0.5)),
                          const SizedBox(width: 4),
                          Text(
                            '${_formatCount(total)} descubiertos',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colors.onSurface.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$pipelineTotal en pipeline',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Stage counts chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final stage in OutreachStage.kanbanStages)
                _StageChip(
                  stage: stage,
                  count: stageCounts[stage] ?? 0,
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Search bar
          SizedBox(
            height: 36,
            width: isMobile ? double.infinity : 320,
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Buscar salon...',
                prefixIcon: const Icon(Icons.search, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12),
                isDense: true,
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          searchController.clear();
                          onSearchChanged('');
                        },
                      )
                    : null,
              ),
              style: theme.textTheme.bodySmall,
              onChanged: onSearchChanged,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

// ── Enrichment Monitor Card ────────────────────────────────────────────────

class _EnrichmentMonitorCard extends StatefulWidget {
  const _EnrichmentMonitorCard({required this.enrichmentAsync});
  final AsyncValue<EnrichmentStats> enrichmentAsync;

  @override
  State<_EnrichmentMonitorCard> createState() => _EnrichmentMonitorCardState();
}

class _EnrichmentMonitorCardState extends State<_EnrichmentMonitorCard> {
  AsyncValue<EnrichmentStats> get enrichmentAsync => widget.enrichmentAsync;

  String _fmt(int n) {
    if (n >= 1000) return NumberFormat.compact().format(n);
    return '$n';
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'hace ${diff.inSeconds}s';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    return 'hace ${diff.inHours}h';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return enrichmentAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (stats) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        ),
        child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(10),
          color: colors.surfaceContainerHighest.withValues(alpha: 0.2),
        ),
        child: Row(
          children: [
            Icon(Icons.sync, size: 16,
                color: colors.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 8),
            Text(
              'Enrichment',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            _StatChip(label: 'Total', value: _fmt(stats.total)),
            const SizedBox(width: 8),
            _StatChip(label: 'WA checked', value: _fmt(stats.waChecked)),
            const SizedBox(width: 8),
            _StatChip(label: 'IG checked', value: _fmt(stats.igChecked)),
            const SizedBox(width: 8),
            _StatChip(label: 'Completo', value: _fmt(stats.fullyEnriched), color: Colors.green),
            const SizedBox(width: 8),
            _StatChip(
              label: 'Sin enriquecer',
              value: _fmt(stats.notEnriched),
              color: stats.notEnriched > 0 ? Colors.orange : Colors.green,
            ),
            const Spacer(),
            // Active indicator
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'Activo',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _timeAgo(stats.fetchedAt),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    this.color,
  });
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final chipColor = color ?? colors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: chipColor,
        ),
      ),
    );
  }
}

class _StageChip extends StatefulWidget {
  const _StageChip({required this.stage, required this.count});
  final OutreachStage stage;
  final int count;

  @override
  State<_StageChip> createState() => _StageChipState();
}

class _StageChipState extends State<_StageChip> {
  bool _hovering = false;

  Color get _color => switch (widget.stage) {
        OutreachStage.discovered => const Color(0xFF607D8B),
        OutreachStage.selected => const Color(0xFF2196F3),
        OutreachStage.outreachSent => const Color(0xFFFF9800),
        OutreachStage.registered => const Color(0xFF4CAF50),
        OutreachStage.declined => const Color(0xFFF44336),
        OutreachStage.unreachable => const Color(0xFF9E9E9E),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.diagonal3Values(_hovering ? 1.02 : 1.0, _hovering ? 1.02 : 1.0, 1.0),
        transformAlignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: _hovering ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _color.withValues(alpha: 0.3)),
        ),
        child: Text(
          '${widget.stage.label} (${widget.count})',
          style: theme.textTheme.labelSmall?.copyWith(
            color: _color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Kanban Board ───────────────────────────────────────────────────────────

class _KanbanBoard extends StatelessWidget {
  const _KanbanBoard({
    required this.salons,
    required this.isDesktop,
    required this.isMobile,
    required this.onSelect,
  });

  final List<DiscoveredSalon> salons;
  final bool isDesktop;
  final bool isMobile;
  final ValueChanged<DiscoveredSalon> onSelect;

  @override
  Widget build(BuildContext context) {
    // Group salons by stage (kanban stages only)
    final grouped = <OutreachStage, List<DiscoveredSalon>>{};
    for (final stage in OutreachStage.kanbanStages) {
      grouped[stage] = [];
    }
    for (final salon in salons) {
      if (grouped.containsKey(salon.stage)) {
        grouped[salon.stage]!.add(salon);
      }
    }

    if (isMobile) {
      return DefaultTabController(
        length: OutreachStage.kanbanStages.length,
        child: Column(
          children: [
            TabBar(
              isScrollable: true,
              tabs: [
                for (final stage in OutreachStage.kanbanStages)
                  Tab(
                    text:
                        '${stage.label} (${grouped[stage]!.length})',
                  ),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final stage in OutreachStage.kanbanStages)
                    _ColumnContent(
                      salons: grouped[stage]!,
                      onSelect: onSelect,
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Desktop/tablet: horizontal columns
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final stage in OutreachStage.kanbanStages) ...[
            _KanbanColumn(
              stage: stage,
              salons: grouped[stage]!,
              width: isDesktop ? 260.0 : 220.0,
              onSelect: onSelect,
            ),
            if (stage != OutreachStage.kanbanStages.last)
              const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}

// ── Kanban column ──────────────────────────────────────────────────────────

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({
    required this.stage,
    required this.salons,
    required this.width,
    required this.onSelect,
  });

  final OutreachStage stage;
  final List<DiscoveredSalon> salons;
  final double width;
  final ValueChanged<DiscoveredSalon> onSelect;

  Color get _headerColor => switch (stage) {
        OutreachStage.discovered => const Color(0xFF607D8B),
        OutreachStage.selected => const Color(0xFF2196F3),
        OutreachStage.outreachSent => const Color(0xFFFF9800),
        OutreachStage.registered => const Color(0xFF4CAF50),
        OutreachStage.declined => const Color(0xFFF44336),
        OutreachStage.unreachable => const Color(0xFF9E9E9E),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Column header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _headerColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _headerColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  stage.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: _headerColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${salons.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _headerColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Cards
          if (salons.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Sin salones',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.4),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 500),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.all(8),
                itemCount: salons.length,
                itemBuilder: (context, index) => _SalonCard(
                  salon: salons[index],
                  onTap: () => onSelect(salons[index]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Column content (mobile tab) ────────────────────────────────────────────

class _ColumnContent extends StatelessWidget {
  const _ColumnContent({
    required this.salons,
    required this.onSelect,
  });

  final List<DiscoveredSalon> salons;
  final ValueChanged<DiscoveredSalon> onSelect;

  @override
  Widget build(BuildContext context) {
    if (salons.isEmpty) {
      return Center(
        child: Text(
          'Sin salones en esta etapa',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
              ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: salons.length,
      itemBuilder: (context, index) => _SalonCard(
        salon: salons[index],
        onTap: () => onSelect(salons[index]),
      ),
    );
  }
}

// ── Salon card ─────────────────────────────────────────────────────────────

class _SalonCard extends StatefulWidget {
  const _SalonCard({required this.salon, required this.onTap});
  final DiscoveredSalon salon;
  final VoidCallback onTap;

  @override
  State<_SalonCard> createState() => _SalonCardState();
}

class _SalonCardState extends State<_SalonCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          transform: Matrix4.translationValues(0, _hovering ? -1 : 0, 0),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovering
                  ? colors.primary.withValues(alpha: 0.3)
                  : colors.outlineVariant,
            ),
            boxShadow: _hovering
                ? [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: colors.onSurface.withValues(alpha: 0.02),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.salon.name,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 12,
                    color: colors.onSurface.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${widget.salon.city}, ${widget.salon.country}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // WhatsApp indicator
                  if (widget.salon.hasWhatsApp)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'WA',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF25D366),
                        ),
                      ),
                    ),
                ],
              ),
              if (widget.salon.lastOutreachAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Ultimo contacto: ${DateFormat('d/M/yy').format(widget.salon.lastOutreachAt!)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.4),
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Salon detail panel ─────────────────────────────────────────────────────

class _SalonDetail extends ConsumerWidget {
  const _SalonDetail({
    required this.salon,
    required this.onClose,
  });

  final DiscoveredSalon salon;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final logAsync = ref.watch(salonOutreachLogProvider(salon.id));

    return ColoredBox(
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: colors.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onClose,
                  tooltip: 'Cerrar',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    salon.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                    label: 'Ciudad',
                    value: '${salon.city}, ${salon.state ?? salon.country}',
                  ),
                  _InfoRow(label: 'Pais', value: salon.country),
                  _InfoRow(label: 'Telefono', value: salon.phone),
                  _InfoRow(
                    label: 'WhatsApp',
                    value: salon.hasWhatsApp ? 'Verificado' : 'No verificado',
                  ),
                  _InfoRow(label: 'Etapa', value: salon.stage.label),
                  if (salon.source != null)
                    _InfoRow(label: 'Fuente', value: salon.source!),
                  if (salon.address != null)
                    _InfoRow(label: 'Direccion', value: salon.address!),
                  if (salon.ratingAverage != null)
                    _InfoRow(
                      label: 'Rating',
                      value:
                          '${salon.ratingAverage}${salon.ratingCount != null ? ' (${salon.ratingCount} reviews)' : ''}',
                    ),
                  if (salon.categories != null)
                    _InfoRow(label: 'Categorias', value: salon.categories!),
                  if (salon.website != null)
                    _InfoRow(label: 'Website', value: salon.website!),
                  if (salon.outreachCount > 0)
                    _InfoRow(
                      label: 'Contactos',
                      value: '${salon.outreachCount} veces',
                    ),
                  if (salon.lastOutreachAt != null)
                    _InfoRow(
                      label: 'Ultimo contacto',
                      value: DateFormat('d MMM yyyy', 'es')
                          .format(salon.lastOutreachAt!),
                    ),
                  const SizedBox(height: 16),

                  // Action buttons
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          // Fetch full salon data for ContactPanel
                          try {
                            final data = await BCSupabase.client
                                .from('discovered_salons')
                                .select()
                                .eq('id', salon.id)
                                .single();
                            final fullSalon =
                                salons_provider.DiscoveredSalon.fromJson(data);
                            if (!context.mounted) return;
                            showDialog(
                              context: context,
                              builder: (ctx) => Dialog(
                                insetPadding: const EdgeInsets.all(24),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 500,
                                    maxHeight: 700,
                                  ),
                                  child: ContactPanel(
                                    salon: fullSalon,
                                    onClose: () => Navigator.of(ctx).pop(),
                                    onSent: () {
                                      ref.invalidate(pipelineSalonsProvider);
                                    },
                                  ),
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        },
                        icon: const Icon(Icons.message, size: 16),
                        label: const Text('Enviar WA'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF25D366),
                          side: const BorderSide(color: Color(0xFF25D366)),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            await BCSupabase.client.functions.invoke(
                              'outreach-discovered-salon',
                              body: {
                                'action': 'invite',
                                'discovered_salon_id': salon.id,
                              },
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Marcado como interesado'),
                              ),
                            );
                            ref.invalidate(pipelineSalonsProvider);
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        },
                        icon: const Icon(Icons.star_outline, size: 16),
                        label: const Text('Interesado'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Importar (CSV)'),
                              content: const Text(
                                'Subir archivo CSV con salones.\n\n'
                                'Esta funcionalidad esta en desarrollo.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Text('Cerrar'),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.upload, size: 16),
                        label: const Text('Importar (CSV)'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── RP Assignment Info ──
                  _RpAssignmentSection(salon: salon),
                  const SizedBox(height: 16),

                  // ── Checklist ──
                  _RpChecklistSection(salonId: salon.id),
                  const SizedBox(height: 16),

                  // ── Meetings ──
                  _RpMeetingsSection(salonId: salon.id, salonName: salon.name),
                  const SizedBox(height: 16),

                  // ── Close Process ──
                  _RpCloseProcessButton(salon: salon),
                  const SizedBox(height: 24),

                  // Outreach history
                  Text(
                    'Historial de contacto',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  logAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    error: (e, _) => Text('Error: $e'),
                    data: (entries) {
                      if (entries.isEmpty) {
                        return Text(
                          'Sin historial de contacto',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                colors.onSurface.withValues(alpha: 0.5),
                          ),
                        );
                      }

                      return Column(
                        children: [
                          for (final entry in entries) ...[
                            _LogEntryRow(entry: entry),
                            if (entry != entries.last)
                              Divider(
                                height: 1,
                                color: colors.outlineVariant
                                    .withValues(alpha: 0.5),
                              ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── RP Assignment Info ─────────────────────────────────────────────────────

class _RpAssignmentSection extends ConsumerWidget {
  const _RpAssignmentSection({required this.salon});
  final DiscoveredSalon salon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final rpNameAsync = ref.watch(rpAssignmentInfoProvider(salon.assignedRpId));
    final rpStatus = salon.rpStatus ?? 'unassigned';

    const statusLabels = {
      'unassigned': 'Sin asignar',
      'assigned': 'Sin visitar',
      'visited': 'Contactado',
      'contacted': 'Contactado',
      'onboarding': 'En onboarding',
      'onboarding_complete': 'Completado',
      'converted': 'Convertido',
      'declined': 'Rechazado',
    };
    final statusColors = {
      'unassigned': Colors.grey,
      'assigned': Colors.blue,
      'visited': Colors.orange,
      'contacted': Colors.orange,
      'onboarding': Colors.purple,
      'onboarding_complete': Colors.green,
      'converted': Colors.green.shade800,
      'declined': Colors.red,
    };
    final statusColor = statusColors[rpStatus] ?? Colors.grey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Asignación RP',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.person_outline, size: 16,
                color: colors.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 8),
            Expanded(
              child: rpNameAsync.when(
                data: (name) => Text(
                  name ?? 'Sin asignar',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                loading: () => const SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
                error: (_, __) => Text(
                  'Error cargando RP',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.error,
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusLabels[rpStatus] ?? rpStatus,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── RP Checklist Section ──────────────────────────────────────────────────

class _RpChecklistSection extends ConsumerStatefulWidget {
  const _RpChecklistSection({required this.salonId});
  final String salonId;

  @override
  ConsumerState<_RpChecklistSection> createState() =>
      _RpChecklistSectionState();
}

class _RpChecklistSectionState extends ConsumerState<_RpChecklistSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final checklistAsync = ref.watch(rpChecklistProvider(widget.salonId));
    final progress = ref.watch(rpChecklistProgressProvider(widget.salonId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Checklist de Onboarding',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${progress.required}/7 requeridos',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  size: 20,
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.total > 0
                ? progress.required / progress.total
                : 0,
            minHeight: 6,
            backgroundColor: colors.outlineVariant.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation<Color>(
              progress.required >= 7 ? Colors.green : colors.primary,
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 12),
          checklistAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (e, _) => Text('Error: $e',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colors.error)),
            data: (items) {
              final checkedKeys = {
                for (final item in items)
                  if (item.checkedAt != null) item.itemKey,
              };

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Requeridos',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...kRpChecklistRequired.map((key) =>
                      _checklistTile(context, ref, key,
                          checkedKeys.contains(key))),
                  const SizedBox(height: 12),
                  Text(
                    'Opcionales',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...kRpChecklistOptional.map((key) =>
                      _checklistTile(context, ref, key,
                          checkedKeys.contains(key))),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _checklistTile(
      BuildContext context, WidgetRef ref, String key, bool checked) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 36,
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: checked,
              onChanged: (val) async {
                try {
                  await rpToggleChecklistItem(
                    salonId: widget.salonId,
                    itemKey: key,
                    checked: val ?? false,
                  );
                  ref.invalidate(rpChecklistProvider(widget.salonId));
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              kRpChecklistLabels[key] ?? key,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                decoration:
                    checked ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── RP Meetings Section ───────────────────────────────────────────────────

class _RpMeetingsSection extends ConsumerWidget {
  const _RpMeetingsSection({
    required this.salonId,
    required this.salonName,
  });
  final String salonId;
  final String salonName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final meetingAsync = ref.watch(rpNextMeetingProvider(salonId));

    const statusColors = {
      'pending': Colors.amber,
      'confirmed': Colors.green,
      'denied': Colors.red,
      'rescheduled': Colors.orange,
    };
    const statusLabels = {
      'pending': 'Pendiente',
      'confirmed': 'Confirmada',
      'denied': 'Rechazada',
      'rescheduled': 'Reagendada',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Próxima Reunión',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        meetingAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (e, _) => Text('Error: $e',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: colors.error)),
          data: (meeting) {
            if (meeting == null) {
              return Text(
                'Sin reuniones programadas',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
              );
            }

            final color = statusColors[meeting.status] ?? Colors.grey;
            return Row(
              children: [
                Icon(Icons.calendar_today, size: 16,
                    color: colors.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('dd MMM yyyy, HH:mm', 'es')
                            .format(meeting.proposedAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (meeting.note != null && meeting.note!.isNotEmpty)
                        Text(
                          meeting.note!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color:
                                colors.onSurface.withValues(alpha: 0.5),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabels[meeting.status] ?? meeting.status,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showMeetingDialog(context, ref),
            icon: const Icon(Icons.calendar_month, size: 16),
            label: const Text('Agendar Reunión'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ],
    );
  }

  void _showMeetingDialog(BuildContext context, WidgetRef ref) {
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Agendar Reunión'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(selectedDate != null
                    ? DateFormat('dd MMM yyyy').format(selectedDate!)
                    : 'Seleccionar fecha'),
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate:
                        DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate:
                        DateTime.now().add(const Duration(days: 90)),
                  );
                  if (d != null) setDialogState(() => selectedDate = d);
                },
              ),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: Text(selectedTime != null
                    ? selectedTime!.format(ctx)
                    : 'Seleccionar hora'),
                onTap: () async {
                  final t = await showTimePicker(
                      context: ctx,
                      initialTime: const TimeOfDay(hour: 10, minute: 0));
                  if (t != null) setDialogState(() => selectedTime = t);
                },
              ),
              TextField(
                controller: noteCtrl,
                decoration:
                    const InputDecoration(hintText: 'Nota (opcional)'),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: (selectedDate == null || selectedTime == null)
                  ? null
                  : () async {
                      final proposedAt = DateTime(
                        selectedDate!.year,
                        selectedDate!.month,
                        selectedDate!.day,
                        selectedTime!.hour,
                        selectedTime!.minute,
                      );
                      final note = noteCtrl.text.trim();
                      try {
                        await rpCreateMeeting(
                          salonId: salonId,
                          proposedAt: proposedAt,
                          note: note.isEmpty ? null : note,
                        );
                        ref.invalidate(rpNextMeetingProvider(salonId));
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Reunión solicitada')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
              child: const Text('Solicitar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── RP Close Process Button ───────────────────────────────────────────────

class _RpCloseProcessButton extends ConsumerWidget {
  const _RpCloseProcessButton({required this.salon});
  final DiscoveredSalon salon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only show if an RP is assigned
    if (salon.assignedRpId == null) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showCerrarDialog(context, ref),
        icon: const Icon(Icons.close, size: 16, color: Colors.red),
        label: const Text('Cerrar Proceso'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  void _showCerrarDialog(BuildContext context, WidgetRef ref) {
    String? outcome;
    String? selectedReason;
    final reasonCtrl = TextEditingController();
    const reasons = [
      'No interesado',
      'Ya tiene sistema',
      'Cerró el negocio',
      'No contactable',
      'Otro',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Cerrar Proceso'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('¿El salón se registró en BeautyCita?'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Sí, completado'),
                      selected: outcome == 'completed',
                      onSelected: (_) => setDialogState(() {
                        outcome = 'completed';
                        selectedReason = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('No'),
                      selected: outcome == 'not_converted',
                      onSelected: (_) =>
                          setDialogState(() => outcome = 'not_converted'),
                    ),
                  ),
                ],
              ),
              if (outcome == 'not_converted') ...[
                const SizedBox(height: 16),
                const Text('Razón:'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: reasons
                      .map((r) => ChoiceChip(
                            label: Text(r),
                            selected: selectedReason == r,
                            onSelected: (_) =>
                                setDialogState(() => selectedReason = r),
                          ))
                      .toList(),
                ),
                if (selectedReason == 'Otro') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonCtrl,
                    decoration: const InputDecoration(
                        hintText: 'Especificar razón'),
                  ),
                ],
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: outcome == null ||
                      (outcome == 'not_converted' && selectedReason == null)
                  ? null
                  : () async {
                      try {
                        final assignmentId =
                            await getActiveAssignmentId(salon.id);
                        if (assignmentId == null) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('No se encontró asignación activa'),
                              ),
                            );
                          }
                          return;
                        }
                        final finalReason = selectedReason == 'Otro'
                            ? reasonCtrl.text.trim()
                            : selectedReason;
                        await rpCloseProcess(
                          salonId: salon.id,
                          assignmentId: assignmentId,
                          outcome: outcome!,
                          reason: outcome == 'not_converted'
                              ? finalReason
                              : null,
                        );
                        ref.invalidate(pipelineSalonsProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                outcome == 'completed'
                                    ? 'Proceso cerrado: Convertido'
                                    : 'Proceso cerrado',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
              child: const Text('Cerrar Proceso'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Info row ───────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Log entry row ──────────────────────────────────────────────────────────

class _LogEntryRow extends StatelessWidget {
  const _LogEntryRow({required this.entry});
  final OutreachLogEntry entry;

  IconData get _channelIcon => switch (entry.channel) {
        'whatsapp' => Icons.message,
        'sms' => Icons.sms,
        'email' => Icons.email,
        _ => Icons.circle,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _channelIcon,
            size: 14,
            color: colors.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.channel.toUpperCase(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
                if (entry.messageText != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.messageText!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.5),
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Text(
            DateFormat('d/M HH:mm').format(entry.sentAt),
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
