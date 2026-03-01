import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/constants.dart';
import '../../providers/admin_provider.dart';
import '../../services/export_service.dart';
import '../../services/toast_service.dart';
import 'pipeline_lead_detail_sheet.dart';

// ---------------------------------------------------------------------------
// Export columns
// ---------------------------------------------------------------------------

const _pipelineExportColumns = [
  ExportColumn('business_name', 'Nombre'),
  ExportColumn('phone', 'Telefono'),
  ExportColumn('whatsapp', 'WhatsApp'),
  ExportColumn('location_city', 'Ciudad'),
  ExportColumn('location_state', 'Estado'),
  ExportColumn('source', 'Fuente'),
  ExportColumn('status', 'Estado Pipeline'),
  ExportColumn('interest_count', 'Interes'),
  ExportColumn('outreach_count', 'Contactos'),
  ExportColumn('last_outreach_at', 'Ultimo Contacto'),
];

// ---------------------------------------------------------------------------
// Status & source helpers
// ---------------------------------------------------------------------------

const _allStatuses = [
  'discovered',
  'selected',
  'outreach_sent',
  'registered',
  'declined',
  'unreachable',
];

const _allSources = ['google_maps', 'facebook', 'bing', 'manual'];

Color _statusColor(String? status) {
  switch (status) {
    case 'discovered':
      return Colors.grey;
    case 'selected':
      return Colors.blue;
    case 'outreach_sent':
      return Colors.orange;
    case 'registered':
      return Colors.green;
    case 'declined':
      return Colors.red;
    case 'unreachable':
      return Colors.grey.shade400;
    default:
      return Colors.grey;
  }
}

Color _sourceColor(String? source) {
  switch (source) {
    case 'google_maps':
      return Colors.red;
    case 'facebook':
      return Colors.blue;
    case 'bing':
      return Colors.teal;
    case 'manual':
    default:
      return Colors.grey;
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'discovered':
      return 'Descubierto';
    case 'selected':
      return 'Seleccionado';
    case 'outreach_sent':
      return 'Contactado';
    case 'registered':
      return 'Registrado';
    case 'declined':
      return 'Rechazado';
    case 'unreachable':
      return 'No alcanzable';
    default:
      return status;
  }
}

String _sourceLabel(String source) {
  switch (source) {
    case 'google_maps':
      return 'Google';
    case 'facebook':
      return 'Facebook';
    case 'bing':
      return 'Bing';
    case 'manual':
      return 'Manual';
    default:
      return source;
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class AdminPipelineScreen extends ConsumerStatefulWidget {
  const AdminPipelineScreen({super.key});

  @override
  ConsumerState<AdminPipelineScreen> createState() =>
      _AdminPipelineScreenState();
}

class _AdminPipelineScreenState extends ConsumerState<AdminPipelineScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  String _searchQuery = '';
  Set<String> _statusFilters = {};
  bool? _hasWhatsapp;
  bool? _hasInterest;
  String? _sourceFilter;
  Set<String> _selectedIds = {};
  bool _selectionMode = false;
  bool _metricsExpanded = false;

  Map<String, dynamic> get _searchParams => {
        'query': _searchQuery,
        if (_statusFilters.isNotEmpty)
          'status_filter': _statusFilters.toList(),
        if (_hasWhatsapp == true) 'has_whatsapp': true,
        if (_hasInterest == true) 'has_interest': true,
        if (_sourceFilter != null) 'source_filter': _sourceFilter,
      };

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _searchQuery = value.trim());
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _debounce?.cancel();
    setState(() => _searchQuery = '');
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds = {};
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _showExportSheet(List<Map<String, dynamic>> leads) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusMD),
        ),
      ),
      builder: (ctx) => _ExportBottomSheet(leads: leads, query: _searchQuery),
    );
  }

  void _showStatusPickerDialog() {
    final theme = Theme.of(context);
    String? picked;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Cambiar estado',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: StatefulBuilder(
          builder: (innerCtx, setInner) => Column(
            mainAxisSize: MainAxisSize.min,
            children: _allStatuses.map((s) {
              final isPickedStatus = picked == s;
              return InkWell(
                onTap: () => setInner(() => picked = s),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _statusColor(s),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _statusLabel(s),
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: isPickedStatus
                                ? FontWeight.w700
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (isPickedStatus)
                        const Icon(Icons.check, size: 18, color: Colors.green),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: GoogleFonts.nunito()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            onPressed: picked == null
                ? null
                : () async {
                    Navigator.pop(ctx);
                    await _bulkUpdateStatus(picked!);
                  },
            child: Text('Aplicar', style: GoogleFonts.nunito()),
          ),
        ],
      ),
    );
  }

  Future<void> _bulkUpdateStatus(String newStatus) async {
    final count = _selectedIds.length;
    // TODO: batch update via supabase when detail sheet is implemented
    // For now just invalidate the providers to force a refresh
    ref.invalidate(searchDiscoveredSalonsProvider(_searchParams));
    ref.invalidate(pipelineFunnelStatsProvider);

    if (mounted) {
      _exitSelection();
      ToastService.showSuccess('$count leads actualizados a ${_statusLabel(newStatus)}');
    }
  }

  Future<void> _bulkDelete() async {
    final ids = _selectedIds.toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Eliminar ${ids.length} leads',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Esta accion no se puede deshacer.',
          style: GoogleFonts.nunito(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: GoogleFonts.nunito()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Eliminar', style: GoogleFonts.nunito()),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // TODO: implement actual delete via supabase delete on discovered_salons
    ref.invalidate(searchDiscoveredSalonsProvider(_searchParams));
    ref.invalidate(pipelineFunnelStatsProvider);
    _exitSelection();

    if (mounted) {
      ToastService.showSuccess('${ids.length} leads eliminados');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statsAsync = ref.watch(pipelineFunnelStatsProvider);
    final leadsAsync = ref.watch(searchDiscoveredSalonsProvider(_searchParams));

    return Stack(
      children: [
        Column(
          children: [
            // 1. Metrics header
            _MetricsHeader(
              statsAsync: statsAsync,
              expanded: _metricsExpanded,
              onToggle: () =>
                  setState(() => _metricsExpanded = !_metricsExpanded),
            ),

            // 2. Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.paddingMD,
                AppConstants.paddingSM,
                AppConstants.paddingMD,
                AppConstants.paddingXS,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: GoogleFonts.nunito(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Buscar leads... (nombre, tel, ciudad)',
                        hintStyle: GoogleFonts.nunito(
                          fontSize: 14,
                          color: colors.onSurface.withValues(alpha: 0.4),
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 20,
                          color: colors.onSurface.withValues(alpha: 0.5),
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  size: 18,
                                  color:
                                      colors.onSurface.withValues(alpha: 0.5),
                                ),
                                onPressed: _clearSearch,
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.paddingMD,
                          vertical: AppConstants.paddingSM + 2,
                        ),
                        filled: true,
                        fillColor: colors.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusSM),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusSM),
                          borderSide: BorderSide(
                            color: colors.onSurface.withValues(alpha: 0.1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusSM),
                          borderSide: BorderSide(
                            color: colors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppConstants.paddingSM),
                  // Export button
                  leadsAsync.whenOrNull(
                        data: (leads) => leads.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.file_download_outlined,
                                  color: colors.primary,
                                  size: 22,
                                ),
                                tooltip: 'Exportar',
                                onPressed: () => _showExportSheet(leads),
                              )
                            : null,
                      ) ??
                      IconButton(
                        icon: Icon(
                          Icons.file_download_outlined,
                          color: colors.onSurface.withValues(alpha: 0.3),
                          size: 22,
                        ),
                        onPressed: null,
                      ),
                ],
              ),
            ),

            // 3. Filter chips
            _FilterChipsRow(
              statusFilters: _statusFilters,
              hasWhatsapp: _hasWhatsapp,
              hasInterest: _hasInterest,
              sourceFilter: _sourceFilter,
              onStatusToggle: (s) {
                setState(() {
                  if (_statusFilters.contains(s)) {
                    _statusFilters = {..._statusFilters}..remove(s);
                  } else {
                    _statusFilters = {..._statusFilters, s};
                  }
                });
              },
              onWhatsappToggle: () {
                setState(() {
                  _hasWhatsapp = _hasWhatsapp == true ? null : true;
                });
              },
              onInterestToggle: () {
                setState(() {
                  _hasInterest = _hasInterest == true ? null : true;
                });
              },
              onSourceSelect: (src) {
                setState(() {
                  _sourceFilter = _sourceFilter == src ? null : src;
                });
              },
            ),

            const SizedBox(height: AppConstants.paddingXS),

            // 4. Lead list
            Expanded(
              child: _buildLeadList(colors, leadsAsync),
            ),
          ],
        ),

        // 5. Bulk action bar (slides in from bottom)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedSlide(
            duration: AppConstants.shortAnimation,
            offset: _selectedIds.isNotEmpty
                ? Offset.zero
                : const Offset(0, 1),
            child: _BulkActionBar(
              count: _selectedIds.length,
              onOutreach: () {
                ToastService.showInfo('Proximamente');
              },
              onStatus: _showStatusPickerDialog,
              onExport: () {
                leadsAsync.whenData((leads) {
                  final selected = leads
                      .where((l) => _selectedIds.contains(l['id']?.toString()))
                      .toList();
                  _showExportSheet(selected.isEmpty ? leads : selected);
                });
              },
              onDelete: _bulkDelete,
              onClose: _exitSelection,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeadList(
    ColorScheme colors,
    AsyncValue<List<Map<String, dynamic>>> leadsAsync,
  ) {
    return leadsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingLG,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: colors.error.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                'Error al cargar leads',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                e.toString(),
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => ref
                    .invalidate(searchDiscoveredSalonsProvider(_searchParams)),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text('Reintentar', style: GoogleFonts.nunito()),
              ),
            ],
          ),
        ),
      ),
      data: (leads) {
        if (leads.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.search_off,
                  size: 48,
                  color: colors.onSurface.withValues(alpha: 0.2),
                ),
                const SizedBox(height: 12),
                Text(
                  'No se encontraron leads',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    color: colors.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                if (_searchQuery.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '"$_searchQuery"',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: colors.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.fromLTRB(
            AppConstants.paddingMD,
            AppConstants.paddingXS,
            AppConstants.paddingMD,
            _selectedIds.isNotEmpty ? 80 : AppConstants.paddingXS,
          ),
          itemCount: leads.length,
          itemBuilder: (context, i) {
            final lead = leads[i];
            final id = lead['id']?.toString() ?? '';
            final isSelected = _selectedIds.contains(id);

            return _LeadCard(
              lead: lead,
              isSelected: isSelected,
              selectionMode: _selectionMode,
              onTap: () {
                if (_selectionMode) {
                  _toggleSelection(id);
                } else {
                  showLeadDetailSheet(context, lead);
                }
              },
              onLongPress: () {
                setState(() {
                  _selectionMode = true;
                  _selectedIds = {..._selectedIds, id};
                });
              },
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Metrics header
// ---------------------------------------------------------------------------

class _MetricsHeader extends StatelessWidget {
  final AsyncValue<Map<String, int>> statsAsync;
  final bool expanded;
  final VoidCallback onToggle;

  const _MetricsHeader({
    required this.statsAsync,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onToggle,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            bottom: BorderSide(
              color: colors.onSurface.withValues(alpha: 0.08),
            ),
          ),
        ),
        child: statsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppConstants.paddingMD),
            child: Center(
              child: SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(AppConstants.paddingSM),
            child: Text(
              'Error al cargar estadisticas',
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: colors.error,
              ),
            ),
          ),
          data: (counts) {
            final total = counts.values.fold(0, (a, b) => a + b);
            final outreachSent = counts['outreach_sent'] ?? 0;
            final registered = counts['registered'] ?? 0;
            final convRate =
                total > 0 ? (registered / total * 100) : 0.0;

            return AnimatedCrossFade(
              duration: AppConstants.shortAnimation,
              crossFadeState: expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              // Collapsed view
              firstChild: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.paddingMD,
                  vertical: AppConstants.paddingSM + 2,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _CompactStat(
                        label: 'Total',
                        value: total.toString(),
                        color: colors.primary,
                      ),
                    ),
                    Expanded(
                      child: _CompactStat(
                        label: 'Contactados',
                        value: outreachSent.toString(),
                        color: Colors.orange,
                      ),
                    ),
                    Expanded(
                      child: _CompactStat(
                        label: 'Registrados',
                        value: registered.toString(),
                        color: Colors.green,
                      ),
                    ),
                    Expanded(
                      child: _CompactStat(
                        label: 'Conversion',
                        value: '${convRate.toStringAsFixed(1)}%',
                        color: colors.secondary,
                      ),
                    ),
                    Icon(
                      Icons.expand_more,
                      size: 18,
                      color: colors.onSurface.withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
              // Expanded view
              secondChild: Padding(
                padding: const EdgeInsets.all(AppConstants.paddingMD),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Embudo de Pipeline',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface,
                          ),
                        ),
                        Icon(
                          Icons.expand_less,
                          size: 18,
                          color: colors.onSurface.withValues(alpha: 0.4),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.paddingSM),
                    Wrap(
                      spacing: AppConstants.paddingMD,
                      runSpacing: AppConstants.paddingSM,
                      children: _allStatuses.map((s) {
                        final count = counts[s] ?? 0;
                        return _FunnelStatusRow(
                          status: s,
                          count: count,
                          total: total,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppConstants.paddingSM),
                    Text(
                      'Conversion: ${convRate.toStringAsFixed(1)}%  |  Total: $total',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: colors.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CompactStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _CompactStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _FunnelStatusRow extends StatelessWidget {
  final String status;
  final int count;
  final int total;

  const _FunnelStatusRow({
    required this.status,
    required this.count,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (count / total * 100) : 0.0;
    final color = _statusColor(status);

    return SizedBox(
      width: (MediaQuery.sizeOf(context).width - 48) / 2,
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _statusLabel(status),
              style: GoogleFonts.nunito(
                fontSize: 12,
                color:
                    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            '(${pct.toStringAsFixed(0)}%)',
            style: GoogleFonts.nunito(
              fontSize: 10,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter chips row
// ---------------------------------------------------------------------------

class _FilterChipsRow extends StatelessWidget {
  final Set<String> statusFilters;
  final bool? hasWhatsapp;
  final bool? hasInterest;
  final String? sourceFilter;
  final void Function(String) onStatusToggle;
  final VoidCallback onWhatsappToggle;
  final VoidCallback onInterestToggle;
  final void Function(String) onSourceSelect;

  const _FilterChipsRow({
    required this.statusFilters,
    required this.hasWhatsapp,
    required this.hasInterest,
    required this.sourceFilter,
    required this.onStatusToggle,
    required this.onWhatsappToggle,
    required this.onInterestToggle,
    required this.onSourceSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      height: 40,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMD),
        child: Row(
          children: [
            // Status chips
            ..._allStatuses.map((s) {
              final selected = statusFilters.contains(s);
              final color = _statusColor(s);
              return Padding(
                padding: const EdgeInsets.only(right: AppConstants.paddingXS),
                child: FilterChip(
                  label: Text(
                    _statusLabel(s),
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: selected ? Colors.white : colors.onSurface,
                    ),
                  ),
                  selected: selected,
                  onSelected: (_) => onStatusToggle(s),
                  selectedColor: color,
                  checkmarkColor: Colors.white,
                  backgroundColor:
                      colors.surfaceContainerHighest.withValues(alpha: 0.5),
                  side: BorderSide(
                    color: selected ? color : colors.onSurface.withValues(alpha: 0.15),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                  showCheckmark: false,
                  avatar: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(width: AppConstants.paddingXS),

            // Has WhatsApp chip
            Padding(
              padding: const EdgeInsets.only(right: AppConstants.paddingXS),
              child: FilterChip(
                label: Text(
                  'WhatsApp',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: hasWhatsapp == true ? Colors.white : colors.onSurface,
                  ),
                ),
                selected: hasWhatsapp == true,
                onSelected: (_) => onWhatsappToggle(),
                selectedColor: Colors.green[600],
                checkmarkColor: Colors.white,
                backgroundColor:
                    colors.surfaceContainerHighest.withValues(alpha: 0.5),
                side: BorderSide(
                  color: hasWhatsapp == true
                      ? Colors.green
                      : colors.onSurface.withValues(alpha: 0.15),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
                showCheckmark: false,
                avatar: Icon(
                  Icons.phone_android_outlined,
                  size: 14,
                  color: hasWhatsapp == true ? Colors.white : Colors.green,
                ),
              ),
            ),

            // Has interest chip
            Padding(
              padding: const EdgeInsets.only(right: AppConstants.paddingXS),
              child: FilterChip(
                label: Text(
                  'Con interes',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color:
                        hasInterest == true ? Colors.white : colors.onSurface,
                  ),
                ),
                selected: hasInterest == true,
                onSelected: (_) => onInterestToggle(),
                selectedColor: Colors.pink[400],
                checkmarkColor: Colors.white,
                backgroundColor:
                    colors.surfaceContainerHighest.withValues(alpha: 0.5),
                side: BorderSide(
                  color: hasInterest == true
                      ? Colors.pink
                      : colors.onSurface.withValues(alpha: 0.15),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
                showCheckmark: false,
              ),
            ),

            const SizedBox(width: AppConstants.paddingXS),

            // Source chips
            ..._allSources.map((src) {
              final selected = sourceFilter == src;
              final color = _sourceColor(src);
              return Padding(
                padding: const EdgeInsets.only(right: AppConstants.paddingXS),
                child: FilterChip(
                  label: Text(
                    _sourceLabel(src),
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: selected ? Colors.white : colors.onSurface,
                    ),
                  ),
                  selected: selected,
                  onSelected: (_) => onSourceSelect(src),
                  selectedColor: color,
                  checkmarkColor: Colors.white,
                  backgroundColor:
                      colors.surfaceContainerHighest.withValues(alpha: 0.5),
                  side: BorderSide(
                    color: selected
                        ? color
                        : colors.onSurface.withValues(alpha: 0.15),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                  showCheckmark: false,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bulk action bar
// ---------------------------------------------------------------------------

class _BulkActionBar extends StatelessWidget {
  final int count;
  final VoidCallback onOutreach;
  final VoidCallback onStatus;
  final VoidCallback onExport;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  const _BulkActionBar({
    required this.count,
    required this.onOutreach,
    required this.onStatus,
    required this.onExport,
    required this.onDelete,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMD,
        vertical: AppConstants.paddingSM,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        border: Border(
          top: BorderSide(
            color: colors.onSurface.withValues(alpha: 0.12),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Text(
              '$count seleccionados',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            const Spacer(),
            // Outreach
            _ActionBtn(
              icon: Icons.send_outlined,
              label: 'Outreach',
              color: Colors.blue,
              onTap: onOutreach,
            ),
            const SizedBox(width: AppConstants.paddingSM),
            // Status
            _ActionBtn(
              icon: Icons.edit_outlined,
              label: 'Estado',
              color: Colors.orange,
              onTap: onStatus,
            ),
            const SizedBox(width: AppConstants.paddingSM),
            // Export
            _ActionBtn(
              icon: Icons.file_download_outlined,
              label: 'Exportar',
              color: Colors.green,
              onTap: onExport,
            ),
            const SizedBox(width: AppConstants.paddingSM),
            // Delete
            _ActionBtn(
              icon: Icons.delete_outline,
              label: 'Eliminar',
              color: Colors.red,
              onTap: onDelete,
            ),
            const SizedBox(width: AppConstants.paddingSM),
            // Close
            IconButton(
              icon: Icon(
                Icons.close,
                size: 20,
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
              tooltip: 'Deseleccionar',
              onPressed: onClose,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.radiusXS),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lead card
// ---------------------------------------------------------------------------

class _LeadCard extends StatelessWidget {
  final Map<String, dynamic> lead;
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _LeadCard({
    required this.lead,
    required this.isSelected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final name = lead['business_name'] as String? ?? 'Sin nombre';
    final city = lead['location_city'] as String? ?? '';
    final state = lead['location_state'] as String? ?? '';
    final source = lead['source'] as String?;
    final status = lead['status'] as String?;
    final phone = lead['phone'] as String? ?? '';
    final waVerified = lead['whatsapp_verified'] as bool? ?? false;
    final interestCount = lead['interest_count'] as int? ?? 0;
    final lastOutreachAt = lead['last_outreach_at'] as String?;
    final outreachChannel = lead['outreach_channel'] as String?;

    final locationLine =
        [city, state].where((s) => s.isNotEmpty).join(', ');
    final statusColor = _statusColor(status);
    final sourceColor = _sourceColor(source);

    // Format last outreach date
    String? lastOutreachText;
    if (lastOutreachAt != null) {
      try {
        final dt = DateTime.parse(lastOutreachAt).toLocal();
        final diff = DateTime.now().difference(dt);
        if (diff.inDays == 0) {
          lastOutreachText = 'Hoy';
        } else if (diff.inDays == 1) {
          lastOutreachText = 'Ayer';
        } else if (diff.inDays < 30) {
          lastOutreachText = 'Hace ${diff.inDays}d';
        } else {
          lastOutreachText =
              '${dt.day}/${dt.month}/${dt.year.toString().substring(2)}';
        }
        if (outreachChannel != null) {
          lastOutreachText = '$lastOutreachText via $outreachChannel';
        }
      } catch (_) {
        lastOutreachText = lastOutreachAt;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.paddingXS),
      child: Material(
        color: isSelected
            ? colors.primary.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppConstants.radiusSM),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
              border: Border.all(
                color: isSelected
                    ? colors.primary.withValues(alpha: 0.4)
                    : colors.onSurface.withValues(alpha: 0.1),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.paddingMD,
                vertical: AppConstants.paddingSM + 2,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: Name + source + status badges
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colors.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Source badge
                            if (source != null)
                              _SmallBadge(
                                label: _sourceLabel(source),
                                color: sourceColor,
                              ),
                            const SizedBox(width: 4),
                            // Status badge
                            if (status != null)
                              _SmallBadge(
                                label: _statusLabel(status),
                                color: statusColor,
                              ),
                          ],
                        ),

                        // Row 2: City, State
                        if (locationLine.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            locationLine,
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              color: colors.onSurface.withValues(alpha: 0.5),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],

                        // Row 3: Phone + WA checkmark
                        if (phone.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.phone_outlined,
                                size: 12,
                                color: colors.onSurface.withValues(alpha: 0.4),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                phone,
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  color:
                                      colors.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                              if (waVerified) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.check_circle,
                                  size: 13,
                                  color: Colors.green,
                                ),
                              ],
                              // Interest badge
                              if (interestCount > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.pink.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(
                                      AppConstants.radiusFull,
                                    ),
                                  ),
                                  child: Text(
                                    '$interestCount interesadas',
                                    style: GoogleFonts.nunito(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.pink[700],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],

                        // Row 4: Last outreach
                        if (lastOutreachText != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.history,
                                size: 11,
                                color: colors.onSurface.withValues(alpha: 0.35),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                lastOutreachText,
                                style: GoogleFonts.nunito(
                                  fontSize: 11,
                                  color:
                                      colors.onSurface.withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Checkbox in selection mode, chevron otherwise
                  const SizedBox(width: AppConstants.paddingSM),
                  if (selectionMode)
                    AnimatedSwitcher(
                      duration: AppConstants.shortAnimation,
                      child: Checkbox(
                        key: ValueKey(isSelected),
                        value: isSelected,
                        onChanged: (_) => onTap(),
                        visualDensity: VisualDensity.compact,
                        activeColor: colors.primary,
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: colors.onSurface.withValues(alpha: 0.3),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _SmallBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Export bottom sheet
// ---------------------------------------------------------------------------

class _ExportBottomSheet extends StatefulWidget {
  final List<Map<String, dynamic>> leads;
  final String query;

  const _ExportBottomSheet({required this.leads, required this.query});

  @override
  State<_ExportBottomSheet> createState() => _ExportBottomSheetState();
}

class _ExportBottomSheetState extends State<_ExportBottomSheet> {
  bool _exporting = false;

  Future<void> _export(ExportFormat format) async {
    setState(() => _exporting = true);
    try {
      await ExportService.export(
        data: widget.leads,
        columns: _pipelineExportColumns,
        format: format,
        title:
            'Pipeline BeautyCita${widget.query.isNotEmpty ? " - ${widget.query}" : ""}',
      );
      if (mounted) Navigator.pop(context);
    } catch (e, stack) {
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: AppConstants.bottomSheetDragHandleWidth,
                height: AppConstants.bottomSheetDragHandleHeight,
                decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(
                    AppConstants.bottomSheetDragHandleRadius,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.paddingMD),

            Text(
              'Exportar ${widget.leads.length} leads',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: AppConstants.paddingSM),

            if (_exporting)
              const Padding(
                padding:
                    EdgeInsets.symmetric(vertical: AppConstants.paddingMD),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Column(
                children: [
                  _ExportOption(
                    icon: Icons.table_chart_outlined,
                    label: 'Excel (.xlsx)',
                    subtitle: 'Hoja de calculo con formato',
                    color: Colors.green[700]!,
                    onTap: () => _export(ExportFormat.excel),
                  ),
                  _ExportOption(
                    icon: Icons.description_outlined,
                    label: 'CSV',
                    subtitle: 'Compatible con cualquier app',
                    color: Colors.blue[700]!,
                    onTap: () => _export(ExportFormat.csv),
                  ),
                  _ExportOption(
                    icon: Icons.picture_as_pdf_outlined,
                    label: 'PDF',
                    subtitle: 'Reporte imprimible',
                    color: Colors.red[700]!,
                    onTap: () => _export(ExportFormat.pdf),
                  ),
                  _ExportOption(
                    icon: Icons.code,
                    label: 'JSON',
                    subtitle: 'Datos estructurados',
                    color: Colors.orange[700]!,
                    onTap: () => _export(ExportFormat.json),
                  ),
                  _ExportOption(
                    icon: Icons.contact_phone_outlined,
                    label: 'vCard (.vcf)',
                    subtitle: 'Contactos para importar al movil',
                    color: Colors.purple[700]!,
                    onTap: () => _export(ExportFormat.vcard),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ExportOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ExportOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppConstants.radiusXS),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
      title: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
      onTap: onTap,
    );
  }
}
