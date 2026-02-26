import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../config/breakpoints.dart';
import '../../providers/admin_outreach_provider.dart';

/// Outreach pipeline page — `/app/admin/outreach`
///
/// Kanban-style view of discovered salons moving through the pipeline:
/// Nuevos -> Contactados -> Respondidos -> Interesados -> Onboarded
class OutreachPage extends ConsumerStatefulWidget {
  const OutreachPage({super.key});

  @override
  ConsumerState<OutreachPage> createState() => _OutreachPageState();
}

class _OutreachPageState extends ConsumerState<OutreachPage> {
  DiscoveredSalon? _selectedSalon;

  @override
  Widget build(BuildContext context) {
    final salonsAsync = ref.watch(discoveredSalonsProvider);
    final stageCounts = ref.watch(outreachStageCounts);

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
              isMobile: isMobile,
            ),
            const Divider(height: 1),
            Expanded(
              child: salonsAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (salons) {
                  if (salons.isEmpty) {
                    return _emptyState(context);
                  }

                  if (_selectedSalon != null && !isMobile) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _KanbanBoard(
                            salons: salons,
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
                            ref: ref,
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
                      ref: ref,
                      onClose: () =>
                          setState(() => _selectedSalon = null),
                    );
                  }

                  return _KanbanBoard(
                    salons: salons,
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
            'Sin salones descubiertos',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'El scraper aun no ha encontrado salones.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.stageCounts, required this.isMobile});
  final Map<OutreachStage, int> stageCounts;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final total =
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$total salones',
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
              for (final stage in OutreachStage.values)
                _StageChip(
                  stage: stage,
                  count: stageCounts[stage] ?? 0,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.stage, required this.count});
  final OutreachStage stage;
  final int count;

  Color get _color => switch (stage) {
        OutreachStage.nuevo => const Color(0xFF2196F3),
        OutreachStage.contactado => const Color(0xFFFF9800),
        OutreachStage.respondido => const Color(0xFF9C27B0),
        OutreachStage.interesado => const Color(0xFF4CAF50),
        OutreachStage.onboarded => const Color(0xFF00BCD4),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '${stage.label} ($count)',
        style: theme.textTheme.labelSmall?.copyWith(
          color: _color,
          fontWeight: FontWeight.w600,
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
    // Group salons by stage
    final grouped = <OutreachStage, List<DiscoveredSalon>>{};
    for (final stage in OutreachStage.values) {
      grouped[stage] = [];
    }
    for (final salon in salons) {
      grouped[salon.stage]!.add(salon);
    }

    if (isMobile) {
      // Mobile: show as tabs
      return DefaultTabController(
        length: OutreachStage.values.length,
        child: Column(
          children: [
            TabBar(
              isScrollable: true,
              tabs: [
                for (final stage in OutreachStage.values)
                  Tab(
                    text:
                        '${stage.label} (${grouped[stage]!.length})',
                  ),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final stage in OutreachStage.values)
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
          for (final stage in OutreachStage.values) ...[
            _KanbanColumn(
              stage: stage,
              salons: grouped[stage]!,
              width: isDesktop ? 260.0 : 220.0,
              onSelect: onSelect,
            ),
            if (stage != OutreachStage.values.last)
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
        OutreachStage.nuevo => const Color(0xFF2196F3),
        OutreachStage.contactado => const Color(0xFFFF9800),
        OutreachStage.respondido => const Color(0xFF9C27B0),
        OutreachStage.interesado => const Color(0xFF4CAF50),
        OutreachStage.onboarded => const Color(0xFF00BCD4),
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
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
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
                      color: colors.primary.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
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
                      widget.salon.city,
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
                    )
                  else
                    Text(
                      '--',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.3),
                      ),
                    ),
                ],
              ),
              if (widget.salon.lastContactDate != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Ultimo contacto: ${DateFormat('d/M/yy').format(widget.salon.lastContactDate!)}',
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

class _SalonDetail extends StatelessWidget {
  const _SalonDetail({
    required this.salon,
    required this.ref,
    required this.onClose,
  });

  final DiscoveredSalon salon;
  final WidgetRef ref;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
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
                  _InfoRow(label: 'Ciudad', value: salon.city),
                  _InfoRow(label: 'Telefono', value: salon.phone),
                  _InfoRow(
                    label: 'WhatsApp',
                    value: salon.hasWhatsApp ? 'Si' : 'No',
                  ),
                  _InfoRow(
                    label: 'Etapa',
                    value: salon.stage.label,
                  ),
                  if (salon.source != null)
                    _InfoRow(label: 'Fuente', value: salon.source!),
                  if (salon.address != null)
                    _InfoRow(label: 'Direccion', value: salon.address!),
                  if (salon.notes != null)
                    _InfoRow(label: 'Notas', value: salon.notes!),
                  if (salon.lastContactDate != null)
                    _InfoRow(
                      label: 'Ultimo contacto',
                      value: DateFormat('d MMM yyyy', 'es')
                          .format(salon.lastContactDate!),
                    ),
                  const SizedBox(height: 16),

                  // Action buttons
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Enviar WA: proximamente'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.message, size: 16),
                        label: const Text('Enviar WA'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF25D366),
                          side: const BorderSide(color: Color(0xFF25D366)),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Marcar interesado: proximamente'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.star_outline, size: 16),
                        label: const Text('Interesado'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Importar: proximamente'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.upload, size: 16),
                        label: const Text('Importar'),
                      ),
                    ],
                  ),
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
            Icons.circle,
            size: 8,
            color: colors.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.action,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (entry.notes != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.notes!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            DateFormat('d/M HH:mm').format(entry.createdAt),
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
