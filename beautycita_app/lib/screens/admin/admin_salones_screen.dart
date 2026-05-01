import 'dart:async';
import 'package:beautycita/config/app_transitions.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/config/fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/constants.dart';
import '../../providers/admin_provider.dart';
import '../../services/export_service.dart';
import 'package:beautycita_core/supabase.dart';
import '../../services/supabase_client.dart';
import '../../services/toast_service.dart';
import 'admin_pipeline_screen.dart';
import 'admin_salon_detail_screen.dart';
import 'admin_salones_insights_screen.dart';
import 'v3/personas/salones_detail_screen.dart';
import '../../providers/feature_toggle_provider.dart';
import '../../widgets/admin/outreach_send_sheet.dart';

const _salonExportColumns = [
  ExportColumn('name', 'Nombre'),
  ExportColumn('phone', 'Telefono'),
  ExportColumn('whatsapp', 'WhatsApp'),
  ExportColumn('city', 'Ciudad'),
  ExportColumn('state', 'Estado'),
  ExportColumn('address', 'Direccion'),
  ExportColumn('tier', 'Tier'),
  ExportColumn('is_active', 'Activo'),
  ExportColumn('average_rating', 'Calificacion'),
  ExportColumn('total_reviews', 'Resenas'),
];

const _intelligenceExportColumns = [
  ExportColumn('business_name', 'Nombre'),
  ExportColumn('phone', 'Telefono'),
  ExportColumn('email', 'Email'),
  ExportColumn('location_city', 'Ciudad'),
  ExportColumn('location_state', 'Estado'),
  ExportColumn('source', 'Fuente'),
  ExportColumn('rating_average', 'Calificacion'),
  ExportColumn('rating_count', 'Resenas'),
  ExportColumn('employee_range', 'Empleados'),
  ExportColumn('status', 'Estatus'),
];

/// Wrapper with Salones / Pipeline / Inteligencia tabs.
class AdminSalonesScreen extends StatelessWidget {
  const AdminSalonesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            labelColor: colors.primary,
            unselectedLabelColor: colors.onSurface.withValues(alpha: 0.5),
            indicatorColor: colors.primary,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Salones'),
              Tab(text: 'Pipeline'),
              Tab(text: 'Insights'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _SalonesTab(),
                AdminPipelineScreen(),
                AdminSalonesInsightsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Tab 1: Salones (all registered businesses with filters)
// =============================================================================

class _SalonesTab extends ConsumerStatefulWidget {
  const _SalonesTab();

  @override
  ConsumerState<_SalonesTab> createState() => _SalonesTabState();
}

class _SalonesTabState extends ConsumerState<_SalonesTab> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _activeQuery = '';
  bool _showOrphanedOnly = false;

  // Filter state
  String _verifiedFilter = ''; // '', 'true', 'false'
  String _activeFilter = '';   // '', 'true', 'false'
  String _tierFilter = '';     // '', '1', '2', '3'

  // Selection state for bulk-outreach. Empty when no rows are selected.
  // Cleared whenever the visible set changes (filter/search/orphan flip)
  // so stale ids don't leak into the next message blast.
  final Set<String> _selectedIds = <String>{};

  String get _providerKey =>
      '$_activeQuery|$_verifiedFilter|$_activeFilter|$_tierFilter';

  void _clearSelection() {
    if (_selectedIds.isEmpty) return;
    setState(() => _selectedIds.clear());
  }

  void _toggleSelected(String id) {
    setState(() {
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
    });
  }

  void _selectAllVisible(List<Map<String, dynamic>> visible) {
    final ids = visible
        .map((s) => s['id']?.toString())
        .whereType<String>()
        .toList();
    setState(() {
      _selectedIds.addAll(ids);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _activeQuery = value.trim();
          _selectedIds.clear();
        });
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _debounce?.cancel();
    setState(() {
      _activeQuery = '';
      _selectedIds.clear();
    });
  }

  Future<void> _sendBulkOutreach(List<Map<String, dynamic>> salons) async {
    final ids = salons
        .map((s) => s['id']?.toString())
        .whereType<String>()
        .toList();
    if (ids.isEmpty) return;
    if (ids.length > 100) {
      ToastService.showError(
        'Hay ${ids.length} salones visibles. Máximo 100 por envío — afina los filtros primero.',
      );
      return;
    }
    final sent = await showOutreachSendSheet(
      context: context,
      recipientTable: 'businesses',
      recipientIds: ids,
      recipientLabel: 'Enviar mensaje a ${ids.length} salón${ids.length == 1 ? "" : "es"} registrado${ids.length == 1 ? "" : "s"}',
    );
    if (sent && context.mounted) {
      ref.invalidate(adminAllSalonsProvider(_providerKey));
    }
  }

  void _showExportSheet(List<Map<String, dynamic>> salons) {
    showBurstBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusMD)),
      ),
      builder: (ctx) => _ExportBottomSheet(
        salons: salons,
        query: _activeQuery,
        columns: _salonExportColumns,
        title: 'Salones BeautyCita',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final resultsAsync = ref.watch(adminAllSalonsProvider(_providerKey));

    return Column(
      children: [
        // Search bar
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
                    hintText: 'Buscar salon... (nombre, tel, ciudad)',
                    hintStyle: GoogleFonts.nunito(
                      fontSize: 14,
                      color: colors.onSurface.withValues(alpha: 0.4),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 20,
                      color: colors.onSurface.withValues(alpha: 0.5),
                    ),
                    suffixIcon: _activeQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              size: 18,
                              color: colors.onSurface.withValues(alpha: 0.5),
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
                    fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                      borderSide: BorderSide(
                        color: colors.onSurface.withValues(alpha: 0.1),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                      borderSide: BorderSide(
                        color: colors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.paddingSM),
              // Orphan filter toggle
              IconButton(
                icon: Icon(
                  _showOrphanedOnly
                      ? Icons.filter_alt
                      : Icons.filter_alt_outlined,
                  color: _showOrphanedOnly
                      ? Colors.orange
                      : colors.onSurface.withValues(alpha: 0.5),
                  size: 22,
                ),
                tooltip: _showOrphanedOnly
                    ? 'Mostrando huerfanos'
                    : 'Filtrar huerfanos',
                onPressed: () => setState(() {
                  _showOrphanedOnly = !_showOrphanedOnly;
                  _selectedIds.clear();
                }),
              ),
              // Selection controls — surfaced only when there's a list to act on.
              resultsAsync.whenOrNull(
                data: (salons) {
                  final visible = _showOrphanedOnly
                      ? salons.where((s) => s['owner_id'] == null).toList()
                      : salons;
                  if (visible.isEmpty) return null;
                  final visibleIds = visible
                      .map((s) => s['id']?.toString())
                      .whereType<String>()
                      .toSet();
                  final selectedVisible =
                      _selectedIds.intersection(visibleIds).length;
                  final allVisibleSelected =
                      visibleIds.isNotEmpty && selectedVisible == visibleIds.length;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Select all / deselect all visible
                      IconButton(
                        icon: Icon(
                          allVisibleSelected
                              ? Icons.deselect
                              : Icons.checklist_rounded,
                          color: colors.primary,
                          size: 22,
                        ),
                        tooltip: allVisibleSelected
                            ? 'Deseleccionar todos'
                            : 'Seleccionar todos',
                        onPressed: allVisibleSelected
                            ? _clearSelection
                            : () => _selectAllVisible(visible),
                      ),
                      // Send to selected
                      IconButton(
                        icon: Icon(
                          Icons.send_outlined,
                          color: _selectedIds.isEmpty
                              ? colors.onSurface.withValues(alpha: 0.3)
                              : colors.primary,
                          size: 22,
                        ),
                        tooltip: _selectedIds.isEmpty
                            ? 'Selecciona salones para enviar'
                            : 'Enviar a ${_selectedIds.length} seleccionado${_selectedIds.length == 1 ? "" : "s"}',
                        onPressed: _selectedIds.isEmpty
                            ? null
                            : () {
                                final selectedSalons = salons
                                    .where((s) =>
                                        _selectedIds.contains(s['id']?.toString()))
                                    .toList();
                                _sendBulkOutreach(selectedSalons);
                              },
                      ),
                    ],
                  );
                },
              ) ??
                  const SizedBox.shrink(),
              // Export button
              resultsAsync.whenOrNull(
                data: (salons) => salons.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.file_download_outlined,
                          color: colors.primary,
                          size: 22,
                        ),
                        tooltip: 'Exportar',
                        onPressed: () => _showExportSheet(salons),
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

        // Filter chips
        SizedBox(
          height: 44,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingMD,
              vertical: 4,
            ),
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'Sin verificar',
                  isActive: _verifiedFilter == 'false',
                  color: Colors.orange,
                  onTap: () => setState(() {
                    _verifiedFilter = _verifiedFilter == 'false' ? '' : 'false';
                  }),
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  label: 'Activo',
                  isActive: _activeFilter == 'true',
                  color: Colors.green,
                  onTap: () => setState(() {
                    _activeFilter = _activeFilter == 'true' ? '' : 'true';
                  }),
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  label: 'Inactivo',
                  isActive: _activeFilter == 'false',
                  color: Colors.red,
                  onTap: () => setState(() {
                    _activeFilter = _activeFilter == 'false' ? '' : 'false';
                  }),
                ),
                const SizedBox(width: 6),
                ...[1, 2, 3].map((tier) {
                  final selected = _tierFilter == '$tier';
                  final tColor = tier == 1
                      ? Colors.grey
                      : tier == 2
                          ? Colors.blue
                          : Colors.amber[700]!;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _buildFilterChip(
                      label: 'Tier $tier',
                      isActive: selected,
                      color: tColor,
                      onTap: () => setState(() {
                        _tierFilter = selected ? '' : '$tier';
                      }),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        // Results count
        resultsAsync.whenOrNull(
          data: (salons) => salons.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.paddingLG,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${salons.length} salones',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: colors.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                )
              : null,
        ) ??
            const SizedBox.shrink(),

        const SizedBox(height: AppConstants.paddingXS),

        // Results list
        Expanded(
          child: _buildBody(colors, resultsAsync),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isActive,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return FilterChip(
      label: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 12,
          color: isActive ? Theme.of(context).colorScheme.onPrimary : colors.onSurface,
        ),
      ),
      selected: isActive,
      onSelected: (_) => onTap(),
      selectedColor: color,
      checkmarkColor: Theme.of(context).colorScheme.onPrimary,
      backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
      side: BorderSide(
        color: isActive ? color : colors.onSurface.withValues(alpha: 0.15),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
      showCheckmark: false,
    );
  }

  Widget _buildBody(
    ColorScheme colors,
    AsyncValue<List<Map<String, dynamic>>> resultsAsync,
  ) {
    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingLG),
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
                'Error al cargar salones',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
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
                onPressed: () => ref.invalidate(adminAllSalonsProvider(_providerKey)),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text('Reintentar', style: GoogleFonts.nunito()),
              ),
            ],
          ),
        ),
      ),
      data: (salons) {
        if (salons.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.store_outlined,
                  size: 48,
                  color: colors.onSurface.withValues(alpha: 0.2),
                ),
                const SizedBox(height: 12),
                Text(
                  'Sin salones registrados',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    color: colors.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          );
        }

        final filtered = _showOrphanedOnly
            ? salons.where((s) => s['owner_id'] == null).toList()
            : salons;

        if (filtered.isEmpty && _showOrphanedOnly) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 48,
                  color: colors.onSurface.withValues(alpha: 0.2),
                ),
                const SizedBox(height: 12),
                Text(
                  'Ningun salon huerfano en estos resultados',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    color: colors.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminAllSalonsProvider(_providerKey)),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingMD,
              vertical: AppConstants.paddingXS,
            ),
            itemCount: filtered.length,
            itemBuilder: (context, i) {
              final salon = filtered[i];
              final id = salon['id']?.toString();
              final selected = id != null && _selectedIds.contains(id);
              return _SalonResultCard(
                salon: salon,
                selected: selected,
                onSelectionToggle: id == null ? null : () => _toggleSelected(id),
                hasActiveSelection: _selectedIds.isNotEmpty,
              );
            },
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Salon result card
// ---------------------------------------------------------------------------

class _SalonResultCard extends ConsumerWidget {
  final Map<String, dynamic> salon;
  final bool selected;
  final VoidCallback? onSelectionToggle;
  /// True when at least one row in the list is currently selected. While in
  /// this mode, tapping any row toggles selection instead of navigating —
  /// matches the platform-standard "selection mode" interaction.
  final bool hasActiveSelection;

  const _SalonResultCard({
    required this.salon,
    this.selected = false,
    this.onSelectionToggle,
    this.hasActiveSelection = false,
  });

  Color _tierColor(int? tier, ColorScheme colors) {
    switch (tier) {
      case 1:
        return Colors.grey;
      case 2:
        return Colors.blue;
      case 3:
        return colors.secondary;
      default:
        return colors.onSurface.withValues(alpha: 0.4);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final toggles = ref.watch(featureTogglesProvider);
    final useV3 = toggles.isEnabled('admin_v2_section_personas_salones_enabled');

    final name = salon['name'] as String? ?? 'Sin nombre';
    final city = salon['city'] as String? ?? '';
    final state = salon['state'] as String? ?? '';
    final phone = salon['phone'] as String? ?? '';
    final tier = salon['tier'] as int?;
    final isActive = salon['is_active'] as bool? ?? false;
    final isVerified = salon['is_verified'] as bool? ?? false;
    final rating = (salon['average_rating'] as num?)?.toDouble();
    final reviews = salon['total_reviews'] as int?;
    final isOrphaned = salon['owner_id'] == null;

    final locationLine = [city, state].where((s) => s.isNotEmpty).join(', ');
    final tierColor = _tierColor(tier, colors);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.paddingXS),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppConstants.radiusSM),
          onTap: () {
            // Selection-mode tap toggles instead of navigating.
            if (hasActiveSelection && onSelectionToggle != null) {
              onSelectionToggle!();
              return;
            }
            final id = salon['id'] as String?;
            if (id == null) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => useV3
                    ? PersonasSalonesDetailScreen(businessId: id)
                    : AdminSalonDetailScreen(businessId: id),
              ),
            );
          },
          onLongPress: onSelectionToggle,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
              border: Border.all(
                color: selected
                    ? colors.primary
                    : colors.onSurface.withValues(alpha: 0.1),
                width: selected ? 1.5 : 1,
              ),
              color: selected
                  ? colors.primary.withValues(alpha: 0.04)
                  : null,
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Selection checkbox — only present when the list supports
                  // selection (admin Salones tab does; sub-tabs may not).
                  if (onSelectionToggle != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: Checkbox(
                            value: selected,
                            onChanged: (_) => onSelectionToggle!(),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Active status indicator bar
                  Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green : Colors.red,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(AppConstants.radiusSM),
                        bottomLeft: Radius.circular(AppConstants.radiusSM),
                      ),
                    ),
                  ),

                  // Main content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.paddingMD,
                        vertical: AppConstants.paddingSM + 2,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Row 1: Name + badges
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
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
                              if (!isVerified) ...[
                                const SizedBox(width: AppConstants.paddingSM),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Sin verificar',
                                    style: GoogleFonts.nunito(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.orange[800],
                                    ),
                                  ),
                                ),
                              ],
                              if (tier != null) ...[
                                const SizedBox(width: AppConstants.paddingSM),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tierColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Tier $tier',
                                    style: GoogleFonts.nunito(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: tierColor,
                                    ),
                                  ),
                                ),
                              ],
                              if (isOrphaned) ...[
                                const SizedBox(width: AppConstants.paddingSM),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Huerfano',
                                    style: GoogleFonts.nunito(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.red[700],
                                    ),
                                  ),
                                ),
                              ],
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

                          // Row 3: Phone + rating
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (phone.isNotEmpty) ...[
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
                                    color: colors.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                              if (phone.isNotEmpty && rating != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Text(
                                    '·',
                                    style: TextStyle(
                                      color: colors.onSurface.withValues(alpha: 0.3),
                                    ),
                                  ),
                                ),
                              if (rating != null) ...[
                                Icon(
                                  Icons.star_rounded,
                                  size: 14,
                                  color: colors.secondary,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: GoogleFonts.nunito(
                                    fontSize: 12,
                                    color: colors.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                                if (reviews != null && reviews > 0) ...[
                                  const SizedBox(width: 2),
                                  Text(
                                    '($reviews)',
                                    style: GoogleFonts.nunito(
                                      fontSize: 11,
                                      color: colors.onSurface.withValues(alpha: 0.35),
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Chevron
                  Padding(
                    padding: const EdgeInsets.only(right: AppConstants.paddingSM),
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

// =============================================================================
// Tab 3: Inteligencia (discovered salons database intelligence)
// =============================================================================

class _IntelligenceTab extends StatefulWidget {
  const _IntelligenceTab();

  @override
  State<_IntelligenceTab> createState() => _IntelligenceTabState();
}

class _IntelligenceTabState extends State<_IntelligenceTab> {
  final _searchCtrl = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  String _query = '';

  // Filters
  String? _stateFilter;
  String? _cityFilter;
  String? _sourceFilter;
  bool _hasPhoneFilter = false;
  bool _hasEmailFilter = false;
  double? _minRating;
  String? _employeeRange;
  String? _statusFilter;

  // Dropdown options
  List<String> _states = [];
  List<String> _cities = [];
  Map<String, int> _stateCounts = {};
  Map<String, int> _cityCounts = {};

  // Results + pagination
  List<Map<String, dynamic>> _results = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  static const _pageSize = 50;

  // Stats
  int _totalCount = 0;
  int _withPhone = 0;
  int _withEmail = 0;
  double _avgRating = 0;

  @override
  void initState() {
    super.initState();
    _loadStates();
    _fetchResults(reset: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore) {
      _fetchResults(reset: false);
    }
  }

  Future<void> _loadStates() async {
    try {
      final data = await SupabaseClientService.client
          .rpc('discovered_salon_counts', params: {'p_group': 'state', 'p_country': 'MX'});
      final counts = <String, int>{};
      final list = <String>[];
      for (final row in data as List) {
        final label = row['label'] as String?;
        final cnt = (row['cnt'] as num?)?.toInt() ?? 0;
        if (label != null && label.isNotEmpty) {
          counts[label] = cnt;
          list.add(label);
        }
      }
      if (mounted) setState(() { _states = list; _stateCounts = counts; });
    } catch (e) { if (kDebugMode) debugPrint('[Salones] Error: $e'); }
  }

  Future<void> _loadCities(String state) async {
    setState(() { _cities = []; _cityCounts = {}; });
    try {
      final data = await SupabaseClientService.client
          .rpc('discovered_salon_counts', params: {
            'p_group': 'city',
            'p_country': 'MX',
            'p_state': state,
          });
      final counts = <String, int>{};
      final list = <String>[];
      for (final row in data as List) {
        final label = row['label'] as String?;
        final cnt = (row['cnt'] as num?)?.toInt() ?? 0;
        if (label != null && label.isNotEmpty) {
          counts[label] = cnt;
          list.add(label);
        }
      }
      if (mounted) setState(() { _cities = list; _cityCounts = counts; });
    } catch (e) { if (kDebugMode) debugPrint('[Salones] Error: $e'); }
  }

  Future<void> _fetchResults({required bool reset}) async {
    if (reset) {
      setState(() {
        _offset = 0;
        _results = [];
        _loading = true;
        _hasMore = true;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      var q = SupabaseClientService.client
          .from(BCTables.discoveredSalons)
          .select('id, business_name, phone, email, whatsapp, location_address, location_city, location_state, latitude, longitude, source, rating_average, rating_count, employee_range, razon_social, scian_class, status, notes, feature_image_url, created_at');

      // Apply filters
      q = q.eq('country', 'MX');

      if (_query.isNotEmpty) {
        q = q.ilike('business_name', '%$_query%');
      }
      if (_stateFilter != null) {
        q = q.eq('location_state', _stateFilter!);
      }
      if (_cityFilter != null) {
        q = q.eq('location_city', _cityFilter!);
      }
      if (_sourceFilter != null) {
        q = q.eq('source', _sourceFilter!);
      }
      if (_hasPhoneFilter) {
        q = q.not('phone', 'is', null).neq('phone', '');
      }
      if (_hasEmailFilter) {
        q = q.not('email', 'is', null).neq('email', '');
      }
      if (_minRating != null) {
        q = q.gte('rating_average', _minRating!);
      }
      if (_employeeRange != null) {
        q = q.eq('employee_range', _employeeRange!);
      }
      if (_statusFilter != null) {
        q = q.eq('status', _statusFilter!);
      } else {
        // Default: exclude registered/declined/unreachable
        q = q.inFilter('status', ['discovered', 'selected', 'outreach_sent']);
      }

      final data = await q
          .order('rating_average', ascending: false)
          .range(_offset, _offset + _pageSize - 1);

      final newResults = List<Map<String, dynamic>>.from(data);

      if (mounted) {
        setState(() {
          if (reset) {
            _results = newResults;
          } else {
            _results.addAll(newResults);
          }
          _offset += newResults.length;
          _hasMore = newResults.length >= _pageSize;
          _loading = false;
          _loadingMore = false;
        });
      }

      // Update stats on first load
      if (reset) {
        _updateStats();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Intelligence] Error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _updateStats() async {
    try {
      var q = SupabaseClientService.client
          .from(BCTables.discoveredSalons)
          .select('phone, email, rating_average')
          .eq('country', 'MX');

      if (_query.isNotEmpty) q = q.ilike('business_name', '%$_query%');
      if (_stateFilter != null) q = q.eq('location_state', _stateFilter!);
      if (_cityFilter != null) q = q.eq('location_city', _cityFilter!);
      if (_sourceFilter != null) q = q.eq('source', _sourceFilter!);
      if (_hasPhoneFilter) q = q.not('phone', 'is', null).neq('phone', '');
      if (_hasEmailFilter) q = q.not('email', 'is', null).neq('email', '');
      if (_minRating != null) q = q.gte('rating_average', _minRating!);
      if (_employeeRange != null) q = q.eq('employee_range', _employeeRange!);
      if (_statusFilter != null) {
        q = q.eq('status', _statusFilter!);
      } else {
        q = q.inFilter('status', ['discovered', 'selected', 'outreach_sent']);
      }

      final data = await q.limit(10000);
      final all = List<Map<String, dynamic>>.from(data);

      int phones = 0;
      int emails = 0;
      double ratingSum = 0;
      int ratingCount = 0;
      for (final row in all) {
        final phone = row['phone'] as String?;
        if (phone != null && phone.isNotEmpty) phones++;
        final email = row['email'] as String?;
        if (email != null && email.isNotEmpty) emails++;
        final r = (row['rating_average'] as num?)?.toDouble();
        if (r != null && r > 0) {
          ratingSum += r;
          ratingCount++;
        }
      }

      if (mounted) {
        setState(() {
          _totalCount = all.length;
          _withPhone = phones;
          _withEmail = emails;
          _avgRating = ratingCount > 0 ? ratingSum / ratingCount : 0;
        });
      }
    } catch (e) { if (kDebugMode) debugPrint('[Salones] Error: $e'); }
  }

  void _onFilterChanged() {
    _fetchResults(reset: true);
  }

  void _showExportSheet() {
    showBurstBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusMD)),
      ),
      builder: (ctx) => _ExportBottomSheet(
        salons: _results,
        query: _query,
        columns: _intelligenceExportColumns,
        title: 'Inteligencia BeautyCita',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Search + export
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.paddingMD,
            AppConstants.paddingSM,
            AppConstants.paddingMD,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar salon descubierto...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                              _onFilterChanged();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (v) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 400), () {
                      if (mounted) {
                        setState(() => _query = v.trim());
                        _onFilterChanged();
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.file_download_outlined, color: _results.isNotEmpty ? colors.primary : colors.onSurface.withValues(alpha: 0.3)),
                tooltip: 'Exportar',
                onPressed: _results.isNotEmpty ? _showExportSheet : null,
              ),
            ],
          ),
        ),

        // Filter chips row
        SizedBox(
          height: 44,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingMD,
              vertical: 4,
            ),
            child: Row(
              children: [
                // State dropdown
                _DropdownChip(
                  label: _stateFilter != null
                      ? '$_stateFilter (${_stateCounts[_stateFilter] ?? ''})'
                      : 'Estado',
                  isActive: _stateFilter != null,
                  options: _states.map((s) => '$s (${_stateCounts[s] ?? 0})').toList(),
                  optionValues: _states,
                  onSelected: (v) {
                    setState(() {
                      _stateFilter = v;
                      _cityFilter = null;
                      _cities = [];
                    });
                    if (v != null) _loadCities(v);
                    _onFilterChanged();
                  },
                  onClear: () {
                    setState(() {
                      _stateFilter = null;
                      _cityFilter = null;
                      _cities = [];
                    });
                    _onFilterChanged();
                  },
                  colors: colors,
                ),
                const SizedBox(width: 6),
                // City dropdown
                _DropdownChip(
                  label: _cityFilter != null
                      ? '$_cityFilter (${_cityCounts[_cityFilter] ?? ''})'
                      : 'Ciudad',
                  isActive: _cityFilter != null,
                  options: _cities.map((c) => '$c (${_cityCounts[c] ?? 0})').toList(),
                  optionValues: _cities,
                  onSelected: (v) {
                    setState(() => _cityFilter = v);
                    _onFilterChanged();
                  },
                  onClear: () {
                    setState(() => _cityFilter = null);
                    _onFilterChanged();
                  },
                  colors: colors,
                  enabled: _stateFilter != null,
                ),
                const SizedBox(width: 6),
                // Source chips
                ..._buildSourceChips(colors),
                const SizedBox(width: 6),
                // Has Phone
                FilterChip(
                  label: Text('Con telefono', style: GoogleFonts.nunito(fontSize: 12, color: _hasPhoneFilter ? Theme.of(context).colorScheme.onPrimary : colors.onSurface)),
                  selected: _hasPhoneFilter,
                  onSelected: (_) {
                    setState(() => _hasPhoneFilter = !_hasPhoneFilter);
                    _onFilterChanged();
                  },
                  selectedColor: Colors.blue[600],
                  backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                  side: BorderSide(color: _hasPhoneFilter ? Colors.blue : colors.onSurface.withValues(alpha: 0.15)),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                  showCheckmark: false,
                  avatar: Icon(Icons.phone, size: 14, color: _hasPhoneFilter ? Theme.of(context).colorScheme.onPrimary : Colors.blue),
                ),
                const SizedBox(width: 6),
                // Has Email
                FilterChip(
                  label: Text('Con email', style: GoogleFonts.nunito(fontSize: 12, color: _hasEmailFilter ? Theme.of(context).colorScheme.onPrimary : colors.onSurface)),
                  selected: _hasEmailFilter,
                  onSelected: (_) {
                    setState(() => _hasEmailFilter = !_hasEmailFilter);
                    _onFilterChanged();
                  },
                  selectedColor: Colors.purple[600],
                  backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                  side: BorderSide(color: _hasEmailFilter ? Colors.purple : colors.onSurface.withValues(alpha: 0.15)),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                  showCheckmark: false,
                  avatar: Icon(Icons.email, size: 14, color: _hasEmailFilter ? Theme.of(context).colorScheme.onPrimary : Colors.purple),
                ),
                const SizedBox(width: 6),
                // Rating chips
                ..._buildRatingChips(colors),
                const SizedBox(width: 6),
                // Employee range chips
                ..._buildEmployeeChips(colors),
                const SizedBox(width: 6),
                // Status chips
                ..._buildStatusChips(colors),
              ],
            ),
          ),
        ),

        // Stats bar
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingMD,
            vertical: 6,
          ),
          child: Row(
            children: [
              _StatBadge(label: 'Total', value: '$_totalCount', color: colors.primary),
              const SizedBox(width: 8),
              _StatBadge(label: 'Telefono', value: '$_withPhone', color: Colors.blue),
              const SizedBox(width: 8),
              _StatBadge(label: 'Email', value: '$_withEmail', color: Colors.purple),
              const SizedBox(width: 8),
              _StatBadge(
                label: 'Rating',
                value: _avgRating > 0 ? _avgRating.toStringAsFixed(1) : '--',
                color: Colors.amber[700]!,
              ),
            ],
          ),
        ),

        // Results
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _results.isEmpty
                  ? Center(
                      child: Text(
                        'Sin resultados',
                        style: GoogleFonts.nunito(color: colors.onSurface.withValues(alpha: 0.5)),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMD),
                      itemCount: _results.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i >= _results.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                                  SizedBox(height: 8),
                                  Text('Cargando mas...'),
                                ],
                              ),
                            ),
                          );
                        }
                        return _IntelligenceCard(
                          salon: _results[i],
                          onTap: () => _showDetailSheet(_results[i]),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  List<Widget> _buildSourceChips(ColorScheme colors) {
    const sources = ['google_maps', 'denue', 'facebook', 'bing'];
    const labels = {'google_maps': 'Google', 'denue': 'DENUE', 'facebook': 'Facebook', 'bing': 'Bing'};
    const sourceColors = {'google_maps': Colors.red, 'denue': Colors.teal, 'facebook': Colors.blue, 'bing': Colors.cyan};
    return sources.map((s) {
      final selected = _sourceFilter == s;
      final c = sourceColors[s] ?? Colors.grey;
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: FilterChip(
          label: Text(labels[s] ?? s, style: GoogleFonts.nunito(fontSize: 12, color: selected ? Theme.of(context).colorScheme.onPrimary : colors.onSurface)),
          selected: selected,
          onSelected: (_) {
            setState(() => _sourceFilter = selected ? null : s);
            _onFilterChanged();
          },
          selectedColor: c,
          backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
          side: BorderSide(color: selected ? c : colors.onSurface.withValues(alpha: 0.15)),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
          showCheckmark: false,
        ),
      );
    }).toList();
  }

  List<Widget> _buildRatingChips(ColorScheme colors) {
    const ratings = [3.0, 4.0, 4.5];
    final labels = <double, String>{3.0: '3+', 4.0: '4+', 4.5: '4.5+'};
    return ratings.map((r) {
      final selected = _minRating == r;
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: FilterChip(
          label: Text(labels[r] ?? '$r', style: GoogleFonts.nunito(fontSize: 12, color: selected ? Theme.of(context).colorScheme.onPrimary : colors.onSurface)),
          selected: selected,
          onSelected: (_) {
            setState(() => _minRating = selected ? null : r);
            _onFilterChanged();
          },
          selectedColor: Colors.amber[700],
          backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
          side: BorderSide(color: selected ? Colors.amber[700]! : colors.onSurface.withValues(alpha: 0.15)),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
          showCheckmark: false,
          avatar: Icon(Icons.star, size: 14, color: selected ? Theme.of(context).colorScheme.onPrimary : Colors.amber[700]),
        ),
      );
    }).toList();
  }

  List<Widget> _buildEmployeeChips(ColorScheme colors) {
    const ranges = ['0 a 5 personas', '6 a 10 personas', '11 a 30 personas', '31 a 50 personas', '51 a 100 personas'];
    const labels = {'0 a 5 personas': '0-5', '6 a 10 personas': '6-10', '11 a 30 personas': '11-30', '31 a 50 personas': '31-50', '51 a 100 personas': '51+'};
    return ranges.map((r) {
      final selected = _employeeRange == r;
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: FilterChip(
          label: Text(labels[r] ?? r, style: GoogleFonts.nunito(fontSize: 12, color: selected ? Theme.of(context).colorScheme.onPrimary : colors.onSurface)),
          selected: selected,
          onSelected: (_) {
            setState(() => _employeeRange = selected ? null : r);
            _onFilterChanged();
          },
          selectedColor: Colors.teal,
          backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
          side: BorderSide(color: selected ? Colors.teal : colors.onSurface.withValues(alpha: 0.15)),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
          showCheckmark: false,
        ),
      );
    }).toList();
  }

  List<Widget> _buildStatusChips(ColorScheme colors) {
    const statuses = ['discovered', 'selected', 'outreach_sent'];
    const labels = {'discovered': 'Encontrado', 'selected': 'Seleccionado', 'outreach_sent': 'Contactado'};
    const statusColors = {'discovered': Colors.grey, 'selected': Colors.blue, 'outreach_sent': Colors.orange};
    return statuses.map((s) {
      final selected = _statusFilter == s;
      final c = statusColors[s] ?? Colors.grey;
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: FilterChip(
          label: Text(labels[s] ?? s, style: GoogleFonts.nunito(fontSize: 12, color: selected ? Theme.of(context).colorScheme.onPrimary : colors.onSurface)),
          selected: selected,
          onSelected: (_) {
            setState(() => _statusFilter = selected ? null : s);
            _onFilterChanged();
          },
          selectedColor: c,
          backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
          side: BorderSide(color: selected ? c : colors.onSurface.withValues(alpha: 0.15)),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
          showCheckmark: false,
          avatar: Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: selected ? Theme.of(context).colorScheme.onPrimary : c, shape: BoxShape.circle),
          ),
        ),
      );
    }).toList();
  }

  void _showDetailSheet(Map<String, dynamic> salon) {
    final colors = Theme.of(context).colorScheme;
    final name = salon['business_name'] as String? ?? 'Sin nombre';
    final phone = salon['phone'] as String?;
    final email = salon['email'] as String?;
    final address = salon['location_address'] as String?;
    final city = salon['location_city'] as String?;
    final state = salon['location_state'] as String?;
    final lat = (salon['latitude'] as num?)?.toDouble();
    final lng = (salon['longitude'] as num?)?.toDouble();
    final hasCoords = lat != null && lng != null;
    final rating = (salon['rating_average'] as num?)?.toDouble();
    final reviews = (salon['rating_count'] as num?)?.toInt();
    final source = salon['source'] as String?;
    final employeeRange = salon['employee_range'] as String?;
    final razonSocial = salon['razon_social'] as String?;
    final scianClass = salon['scian_class'] as String?;
    final notes = salon['notes'] as String?;
    final salonId = salon['id'] as String;

    final notesCtrl = TextEditingController(text: notes ?? '');

    showBurstBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(20),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Name
              Text(name, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),

              // Location
              if (address != null || city != null) ...[
                Text(
                  [address, city, state].where((s) => s != null && s.isNotEmpty).join(', '),
                  style: GoogleFonts.nunito(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 8),
              ],

              // Badges row
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (source != null)
                    _badge(source.replaceAll('_', ' ').toUpperCase(), _sourceColor(source)),
                  if (employeeRange != null)
                    _badge(employeeRange, Colors.teal),
                  if (rating != null)
                    _badge('${rating.toStringAsFixed(1)} (${reviews ?? 0})', Colors.amber[700]!),
                ],
              ),
              const SizedBox(height: 16),

              // Contact methods
              Text('CONTACTO', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: colors.onSurface.withValues(alpha: 0.4), letterSpacing: 1)),
              const SizedBox(height: 8),

              if (phone != null && phone.isNotEmpty) ...[
                _contactRow(Icons.phone, phone, Colors.blue, () => launchUrl(Uri.parse('tel:$phone'))),
                _contactRow(Icons.chat, '$phone (WhatsApp)', const Color(0xFF25D366), () {
                  final clean = phone.replaceAll(RegExp(r'[^\d]'), '');
                  launchUrl(Uri.parse('https://wa.me/$clean'));
                }),
              ],
              if (email != null && email.isNotEmpty)
                _contactRow(Icons.email, email, Colors.purple, () => launchUrl(Uri.parse('mailto:$email'))),
              if (hasCoords)
                _contactRow(Icons.map, 'Ver en mapa', Colors.green, () {
                  launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'));
                }),

              const SizedBox(height: 16),

              // DENUE data
              if (razonSocial != null || scianClass != null || employeeRange != null) ...[
                Text('DATOS DENUE', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: colors.onSurface.withValues(alpha: 0.4), letterSpacing: 1)),
                const SizedBox(height: 8),
                if (razonSocial != null)
                  _dataRow('Razon social', razonSocial, colors),
                if (scianClass != null)
                  _dataRow('Clase SCIAN', scianClass, colors),
                if (employeeRange != null)
                  _dataRow('Empleados', employeeRange, colors),
                const SizedBox(height: 16),
              ],

              // Notes
              Text('NOTAS', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: colors.onSurface.withValues(alpha: 0.4), letterSpacing: 1)),
              const SizedBox(height: 8),
              TextField(
                controller: notesCtrl,
                maxLines: 3,
                style: GoogleFonts.nunito(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Agregar notas sobre este salon...',
                  hintStyle: GoogleFonts.nunito(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.3)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    try {
                      await SupabaseClientService.client
                          .from(BCTables.discoveredSalons)
                          .update({'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim()})
                          .eq('id', salonId);
                      ToastService.showSuccess('Notas guardadas');
                    } catch (e, stack) {
                      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
                    }
                  },
                  icon: const Icon(Icons.save, size: 16),
                  label: Text('Guardar notas', style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _contactRow(IconData icon, String text, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.nunito(fontSize: 13, color: color, decoration: TextDecoration.underline),
              ),
            ),
            Icon(Icons.open_in_new, size: 14, color: color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _dataRow(String label, String value, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: colors.onSurface.withValues(alpha: 0.5))),
          ),
          Expanded(
            child: Text(value, style: GoogleFonts.nunito(fontSize: 13, color: colors.onSurface)),
          ),
        ],
      ),
    );
  }

  Color _sourceColor(String? source) => switch (source) {
    'google_maps' => Colors.red,
    'denue' => Colors.teal,
    'facebook' => Colors.blue,
    'bing' => Colors.cyan,
    _ => Colors.grey,
  };
}

// ---------------------------------------------------------------------------
// Intelligence result card
// ---------------------------------------------------------------------------

class _IntelligenceCard extends StatelessWidget {
  final Map<String, dynamic> salon;
  final VoidCallback onTap;

  const _IntelligenceCard({required this.salon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = salon['business_name'] as String? ?? '';
    final city = salon['location_city'] as String? ?? '';
    final state = salon['location_state'] as String? ?? '';
    final phone = salon['phone'] as String?;
    final email = salon['email'] as String?;
    final rating = (salon['rating_average'] as num?)?.toDouble();
    final reviews = (salon['rating_count'] as num?)?.toInt();
    final source = salon['source'] as String?;
    final employeeRange = salon['employee_range'] as String?;
    final status = salon['status'] as String? ?? 'discovered';
    final location = [city, state].where((s) => s.isNotEmpty).join(', ');

    Color sourceColor(String? s) => switch (s) {
      'google_maps' => Colors.red,
      'denue' => Colors.teal,
      'facebook' => Colors.blue,
      'bing' => Colors.cyan,
      _ => Colors.grey,
    };
    Color statusColor(String? s) => switch (s) {
      'discovered' => Colors.grey,
      'selected' => Colors.blue,
      'outreach_sent' => Colors.orange,
      _ => Colors.grey,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppConstants.radiusSM),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
              border: Border.all(color: colors.onSurface.withValues(alpha: 0.1)),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingMD,
              vertical: AppConstants.paddingSM + 2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Name + badges
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (source != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: sourceColor(source).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          source.replaceAll('_', ' '),
                          style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: sourceColor(source)),
                        ),
                      ),
                    ],
                    if (employeeRange != null) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          employeeRange.replaceAll(' personas', ''),
                          style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.teal),
                        ),
                      ),
                    ],
                  ],
                ),

                // Row 2: Location
                if (location.isNotEmpty)
                  Text(location, style: GoogleFonts.nunito(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5))),

                // Row 3: Contact + rating
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (phone != null && phone.isNotEmpty) ...[
                      GestureDetector(
                        onTap: () => launchUrl(Uri.parse('tel:$phone')),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.phone, size: 12, color: Colors.blue[600]),
                            const SizedBox(width: 3),
                            Text(phone, style: GoogleFonts.nunito(fontSize: 12, color: Colors.blue[600])),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          final clean = phone.replaceAll(RegExp(r'[^\d]'), '');
                          launchUrl(Uri.parse('https://wa.me/$clean'));
                        },
                        child: Icon(Icons.chat, size: 14, color: const Color(0xFF25D366)),
                      ),
                    ],
                    if (email != null && email.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => launchUrl(Uri.parse('mailto:$email')),
                        child: Icon(Icons.email, size: 13, color: Colors.purple[400]),
                      ),
                    ],
                    const Spacer(),
                    if (rating != null && rating > 0) ...[
                      Icon(Icons.star_rounded, size: 14, color: Colors.amber[700]),
                      const SizedBox(width: 2),
                      Text(
                        '${rating.toStringAsFixed(1)}${reviews != null ? ' ($reviews)' : ''}',
                        style: GoogleFonts.nunito(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5)),
                      ),
                    ],
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: statusColor(status).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        switch (status) { 'discovered' => 'Encontrado', 'selected' => 'Seleccionado', 'outreach_sent' => 'Contactado', _ => status },
                        style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor(status)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats badge for intelligence header
// ---------------------------------------------------------------------------

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
            Text(label, style: GoogleFonts.nunito(fontSize: 10, color: color.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Export bottom sheet (shared by Salones and Intelligence)
// ---------------------------------------------------------------------------

class _ExportBottomSheet extends StatefulWidget {
  final List<Map<String, dynamic>> salons;
  final String query;
  final List<ExportColumn> columns;
  final String title;

  const _ExportBottomSheet({
    required this.salons,
    required this.query,
    required this.columns,
    required this.title,
  });

  @override
  State<_ExportBottomSheet> createState() => _ExportBottomSheetState();
}

class _ExportBottomSheetState extends State<_ExportBottomSheet> {
  bool _exporting = false;

  Future<void> _export(ExportFormat format) async {
    setState(() => _exporting = true);
    try {
      await ExportService.export(
        data: widget.salons,
        columns: widget.columns,
        format: format,
        title: '${widget.title}${widget.query.isNotEmpty ? " - ${widget.query}" : ""}',
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
              'Exportar ${widget.salons.length} salones',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: AppConstants.paddingSM),

            if (_exporting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppConstants.paddingMD),
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

// ---------------------------------------------------------------------------
// Reusable dropdown chip for location filters
// ---------------------------------------------------------------------------

class _DropdownChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final List<String> options;
  final List<String>? optionValues;
  final ValueChanged<String?> onSelected;
  final VoidCallback onClear;
  final ColorScheme colors;
  final bool enabled;

  const _DropdownChip({
    required this.label,
    required this.isActive,
    required this.options,
    this.optionValues,
    required this.onSelected,
    required this.onClear,
    required this.colors,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = !enabled
        ? colors.surfaceContainerHighest.withValues(alpha: 0.2)
        : isActive
            ? colors.primary
            : colors.surfaceContainerHighest.withValues(alpha: 0.5);
    final fgColor = !enabled
        ? colors.onSurface.withValues(alpha: 0.25)
        : isActive
            ? Theme.of(context).colorScheme.onPrimary
            : colors.onSurface;

    return GestureDetector(
      onTap: !enabled || options.isEmpty
          ? null
          : () {
              final RenderBox box = context.findRenderObject() as RenderBox;
              final offset = box.localToGlobal(Offset.zero);
              showMenu<String>(
                context: context,
                position: RelativeRect.fromLTRB(
                  offset.dx,
                  offset.dy + box.size.height,
                  offset.dx + box.size.width,
                  0,
                ),
                constraints: const BoxConstraints(maxHeight: 300),
                items: List.generate(options.length, (i) {
                  final display = options[i];
                  final value = optionValues != null && i < optionValues!.length
                      ? optionValues![i]
                      : display;
                  return PopupMenuItem<String>(
                    value: value,
                    child: Text(display, style: GoogleFonts.nunito(fontSize: 13)),
                  );
                }),
              ).then((value) {
                if (value != null) onSelected(value);
              });
            },
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? colors.primary
                : colors.onSurface.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: fgColor,
            ),
            const SizedBox(width: 2),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: fgColor,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: fgColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
