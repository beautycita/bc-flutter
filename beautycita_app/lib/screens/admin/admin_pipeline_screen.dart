import 'dart:async';
import 'package:beautycita/config/app_transitions.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../config/constants.dart';
import '../../config/theme_extension.dart';
import '../../providers/admin_provider.dart';
import '../../providers/feature_toggle_provider.dart';
import '../../providers/rp_provider.dart';
import '../../services/export_service.dart';
import '../../services/supabase_client.dart';
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

Color _statusColor(BuildContext context, String? status) {
  final colors = Theme.of(context).colorScheme;
  final bcExt = Theme.of(context).extension<BCThemeExtension>()!;
  switch (status) {
    case 'discovered':
      return colors.onSurface.withValues(alpha: 0.4);
    case 'selected':
      return Colors.blue;
    case 'outreach_sent':
      return bcExt.warningColor;
    case 'registered':
      return bcExt.successColor;
    case 'declined':
      return colors.error;
    case 'unreachable':
      return colors.onSurface.withValues(alpha: 0.4);
    default:
      return colors.onSurface.withValues(alpha: 0.4);
  }
}

Color _sourceColor(BuildContext context, String? source) {
  final colors = Theme.of(context).colorScheme;
  switch (source) {
    case 'google_maps':
      return colors.error;
    case 'facebook':
      return Colors.blue;
    case 'bing':
      return Colors.teal;
    case 'manual':
    default:
      return colors.onSurface.withValues(alpha: 0.4);
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
// RP status helpers
// ---------------------------------------------------------------------------

const _allRpStatuses = [
  'unassigned',
  'assigned',
  'visited',
  'onboarding_complete',
];

Color _rpStatusColor(BuildContext context, String? rpStatus) {
  final colors = Theme.of(context).colorScheme;
  final bcExt = Theme.of(context).extension<BCThemeExtension>()!;
  switch (rpStatus) {
    case 'unassigned':
      return colors.onSurface.withValues(alpha: 0.4);
    case 'assigned':
      return Colors.blue;
    case 'visited':
      return bcExt.warningColor;
    case 'onboarding_complete':
      return bcExt.successColor;
    default:
      return colors.onSurface.withValues(alpha: 0.4);
  }
}

String _rpStatusLabel(String rpStatus) {
  switch (rpStatus) {
    case 'unassigned':
      return 'Sin asignar';
    case 'assigned':
      return 'Asignado';
    case 'visited':
      return 'Visitado';
    case 'onboarding_complete':
      return 'Onboarding completo';
    default:
      return rpStatus;
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
  String? _rpStatusFilter;
  String? _assignedRpId;
  double? _pinLat;
  double? _pinLng;
  double _radiusKm = 25;
  Set<String> _selectedIds = {};
  bool _selectionMode = false;
  bool _metricsExpanded = false;

  // Location filters
  String? _countryFilter;
  String? _stateFilter;
  String? _cityFilter;
  List<String> _countries = [];
  List<String> _states = [];
  List<String> _cities = [];

  bool get _hasGeoFilter => _pinLat != null && _pinLng != null;

  /// Stable string key for the family provider (Map has reference equality,
  /// which creates a new provider on every rebuild). This encodes all filters
  /// into a single string so Riverpod can cache correctly.
  String get _searchKey {
    final parts = <String>[_searchQuery];
    if (_statusFilters.isNotEmpty) {
      final sorted = _statusFilters.toList()..sort();
      parts.add('s:${sorted.join(',')}');
    }
    if (_hasWhatsapp == true) parts.add('wa:1');
    if (_hasInterest == true) parts.add('int:1');
    if (_sourceFilter != null) parts.add('src:$_sourceFilter');
    if (_rpStatusFilter != null) parts.add('rps:$_rpStatusFilter');
    if (_assignedRpId != null) parts.add('rp:$_assignedRpId');
    if (_hasGeoFilter) parts.add('geo:$_pinLat,$_pinLng,$_radiusKm');
    if (_countryFilter != null) parts.add('country:$_countryFilter');
    if (_stateFilter != null) parts.add('state:$_stateFilter');
    if (_cityFilter != null) parts.add('city:$_cityFilter');
    return parts.join('|');
  }

  Map<String, dynamic> get _searchParams => {
        'query': _searchQuery,
        if (_statusFilters.isNotEmpty)
          'status_filter': _statusFilters.toList(),
        if (_hasWhatsapp == true) 'has_whatsapp': true,
        if (_hasInterest == true) 'has_interest': true,
        if (_sourceFilter != null) 'source_filter': _sourceFilter,
        if (_rpStatusFilter != null) 'p_rp_status_filter': _rpStatusFilter,
        if (_assignedRpId != null) 'p_assigned_rp_id': _assignedRpId,
        // Only show unassigned when no RP-specific filters are active
        if (_assignedRpId == null && _rpStatusFilter == null)
          'p_unassigned_only': true,
        if (_pinLat != null) 'p_pin_lat': _pinLat,
        if (_pinLng != null) 'p_pin_lng': _pinLng,
        if (_hasGeoFilter) 'p_radius_km': _radiusKm,
        if (_cityFilter != null) 'city_filter': _cityFilter,
        if (_countryFilter != null) 'country_filter': _countryFilter,
        if (_stateFilter != null) 'state_filter': _stateFilter,
      };

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCountries() async {
    try {
      final data = await SupabaseClientService.client
          .from('discovered_salons')
          .select('country')
          .not('country', 'is', null)
          .order('country');
      final set = <String>{};
      for (final row in data) {
        final c = row['country'] as String?;
        if (c != null && c.isNotEmpty) set.add(c);
      }
      if (mounted) setState(() => _countries = set.toList());
    } catch (e) { if (kDebugMode) debugPrint('[Pipeline] Error: $e'); }
  }

  Future<void> _loadStates(String country) async {
    setState(() {
      _states = [];
      _cities = [];
    });
    try {
      final data = await SupabaseClientService.client
          .from('discovered_salons')
          .select('location_state')
          .eq('country', country)
          .not('location_state', 'is', null)
          .order('location_state');
      final set = <String>{};
      for (final row in data) {
        final s = row['location_state'] as String?;
        if (s != null && s.isNotEmpty) set.add(s);
      }
      if (mounted) setState(() => _states = set.toList());
    } catch (e) { if (kDebugMode) debugPrint('[Pipeline] Error: $e'); }
  }

  Future<void> _loadCities(String state) async {
    setState(() => _cities = []);
    try {
      var q = SupabaseClientService.client
          .from('discovered_salons')
          .select('location_city')
          .eq('location_state', state)
          .not('location_city', 'is', null);
      if (_countryFilter != null) {
        q = q.eq('country', _countryFilter!);
      }
      final data = await q.order('location_city');
      final set = <String>{};
      for (final row in data) {
        final c = row['location_city'] as String?;
        if (c != null && c.isNotEmpty) set.add(c);
      }
      if (mounted) setState(() => _cities = set.toList());
    } catch (e) { if (kDebugMode) debugPrint('[Pipeline] Error: $e'); }
  }

  void _setCountryFilter(String? country) {
    setState(() {
      _countryFilter = country;
      _stateFilter = null;
      _cityFilter = null;
      _states = [];
      _cities = [];
    });
    if (country != null) _loadStates(country);
  }

  void _setStateFilter(String? state) {
    setState(() {
      _stateFilter = state;
      _cityFilter = null;
      _cities = [];
    });
    if (state != null) _loadCities(state);
  }

  void _setCityFilter(String? city) {
    setState(() => _cityFilter = city);
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

  void _clearGeoFilter() {
    setState(() {
      _pinLat = null;
      _pinLng = null;
    });
  }

  void _showPinDropDialog() {
    showBurstDialog(
      context: context,
      builder: (ctx) => _PinDropDialog(
        initialLat: _pinLat,
        initialLng: _pinLng,
        initialRadius: _radiusKm,
        onConfirm: (lat, lng, radius) {
          setState(() {
            _pinLat = lat;
            _pinLng = lng;
            _radiusKm = radius;
          });
        },
      ),
    );
  }

  void _showBulkAssignDialog() {
    final rpUsersAsync = ref.read(rpUsersProvider);
    rpUsersAsync.whenData((rpUsers) {
      if (rpUsers.isEmpty) {
        ToastService.showInfo('No hay usuarios RP registrados');
        return;
      }
      showBurstDialog(
        context: context,
        builder: (ctx) => _RpPickerDialog(
          rpUsers: rpUsers,
          salonCount: _selectedIds.length,
          onConfirm: (rpUserId, rpName) async {
            Navigator.pop(ctx);
            try {
              await adminAssignSalonsToRp(
                salonIds: _selectedIds.toList(),
                rpUserId: rpUserId,
              );
              ref.invalidate(searchDiscoveredSalonsProvider(_searchKey));
              if (mounted) {
                _exitSelection();
                ToastService.showSuccess(
                  '${_selectedIds.length} salones asignados a $rpName',
                );
              }
            } catch (e) {
              if (mounted) ToastService.showError('Error al asignar: $e');
            }
          },
        ),
      );
    });
  }

  Future<void> _bulkUnassign() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Desasignar $count salones?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Se removera la asignacion RP de $count salones.',
          style: GoogleFonts.nunito(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: GoogleFonts.nunito()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).extension<BCThemeExtension>()!.warningColor,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Desasignar', style: GoogleFonts.nunito()),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await adminUnassignSalons(salonIds: _selectedIds.toList());
      ref.invalidate(searchDiscoveredSalonsProvider(_searchKey));
      if (mounted) {
        _exitSelection();
        ToastService.showSuccess('$count salones desasignados');
      }
    } catch (e) {
      if (mounted) ToastService.showError('Error al desasignar: $e');
    }
  }

  void _showExportSheet(List<Map<String, dynamic>> leads) {
    showBurstBottomSheet(
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

    showBurstDialog(
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
                  padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingSM, horizontal: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _statusColor(context, s),
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
                        Icon(Icons.check, size: 18, color: Theme.of(context).extension<BCThemeExtension>()!.successColor),
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
    final ids = _selectedIds.toList();
    final count = ids.length;
    try {
      await SupabaseClientService.client
          .from('discovered_salons')
          .update({'status': newStatus})
          .inFilter('id', ids);
    } catch (e) {
      if (mounted) ToastService.showError('Error al actualizar: $e');
      return;
    }

    ref.invalidate(searchDiscoveredSalonsProvider(_searchKey));
    ref.invalidate(pipelineFunnelStatsProvider);

    if (mounted) {
      _exitSelection();
      ToastService.showSuccess('$count leads actualizados a ${_statusLabel(newStatus)}');
    }
  }


  @override
  Widget build(BuildContext context) {
    final toggles = ref.watch(featureTogglesProvider);
    if (!toggles.isEnabled('enable_outreach_pipeline')) {
      return const Center(child: Text('Pipeline no disponible'));
    }

    final colors = Theme.of(context).colorScheme;
    final statsAsync = ref.watch(pipelineFunnelStatsProvider);
    // Set params before watching so the provider can read them
    ref.read(pipelineSearchParamsProvider.notifier).state = _searchParams;
    final leadsAsync = ref.watch(searchDiscoveredSalonsProvider(_searchKey));

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
                  // Pin drop button
                  Stack(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.location_on,
                          color: _hasGeoFilter
                              ? colors.primary
                              : colors.onSurface.withValues(alpha: 0.5),
                          size: 22,
                        ),
                        tooltip: 'Busqueda por zona',
                        onPressed: _showPinDropDialog,
                      ),
                      if (_hasGeoFilter)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: GestureDetector(
                            onTap: _clearGeoFilter,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: colors.error,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close,
                                size: 10,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
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
              rpStatusFilter: _rpStatusFilter,
              assignedRpId: _assignedRpId,
              rpUsersAsync: ref.watch(rpUsersProvider),
              countryFilter: _countryFilter,
              stateFilter: _stateFilter,
              cityFilter: _cityFilter,
              countries: _countries,
              states: _states,
              cities: _cities,
              onCountrySelect: _setCountryFilter,
              onStateSelect: _setStateFilter,
              onCitySelect: _setCityFilter,
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
              onRpStatusSelect: (rps) {
                setState(() {
                  _rpStatusFilter = _rpStatusFilter == rps ? null : rps;
                });
              },
              onAssignedRpSelect: (rpId) {
                setState(() {
                  _assignedRpId = _assignedRpId == rpId ? null : rpId;
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
              onAssignRp: _showBulkAssignDialog,
              onUnassign: _bulkUnassign,
              onExport: () {
                leadsAsync.whenData((leads) {
                  final selected = leads
                      .where((l) => _selectedIds.contains(l['id']?.toString()))
                      .toList();
                  _showExportSheet(selected.isEmpty ? leads : selected);
                });
              },
              onClose: _exitSelection,
              onSelectAll: () {
                leadsAsync.whenData((leads) {
                  setState(() {
                    _selectedIds = leads.map((l) => l['id']?.toString() ?? '').where((id) => id.isNotEmpty).toSet();
                  });
                });
              },
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
                    .invalidate(searchDiscoveredSalonsProvider(_searchKey)),
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
                        color: Theme.of(context).extension<BCThemeExtension>()!.warningColor,
                      ),
                    ),
                    Expanded(
                      child: _CompactStat(
                        label: 'Registrados',
                        value: registered.toString(),
                        color: Theme.of(context).extension<BCThemeExtension>()!.successColor,
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
    final color = _statusColor(context, status);

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
  final String? rpStatusFilter;
  final String? assignedRpId;
  final AsyncValue<List<Map<String, dynamic>>> rpUsersAsync;
  final String? countryFilter;
  final String? stateFilter;
  final String? cityFilter;
  final List<String> countries;
  final List<String> states;
  final List<String> cities;
  final void Function(String?) onCountrySelect;
  final void Function(String?) onStateSelect;
  final void Function(String?) onCitySelect;
  final void Function(String) onStatusToggle;
  final VoidCallback onWhatsappToggle;
  final VoidCallback onInterestToggle;
  final void Function(String) onSourceSelect;
  final void Function(String) onRpStatusSelect;
  final void Function(String) onAssignedRpSelect;

  const _FilterChipsRow({
    required this.statusFilters,
    required this.hasWhatsapp,
    required this.hasInterest,
    required this.sourceFilter,
    required this.rpStatusFilter,
    required this.assignedRpId,
    required this.rpUsersAsync,
    required this.countryFilter,
    required this.stateFilter,
    required this.cityFilter,
    required this.countries,
    required this.states,
    required this.cities,
    required this.onCountrySelect,
    required this.onStateSelect,
    required this.onCitySelect,
    required this.onStatusToggle,
    required this.onWhatsappToggle,
    required this.onInterestToggle,
    required this.onSourceSelect,
    required this.onRpStatusSelect,
    required this.onAssignedRpSelect,
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
            // Location dropdown chips
            _PipelineDropdownChip(
              label: countryFilter ?? 'Pais',
              isActive: countryFilter != null,
              options: countries,
              onSelected: onCountrySelect,
              onClear: () => onCountrySelect(null),
              colors: colors,
            ),
            const SizedBox(width: AppConstants.paddingXS),
            _PipelineDropdownChip(
              label: stateFilter ?? 'Estado',
              isActive: stateFilter != null,
              options: states,
              onSelected: onStateSelect,
              onClear: () => onStateSelect(null),
              colors: colors,
              enabled: countryFilter != null,
            ),
            const SizedBox(width: AppConstants.paddingXS),
            _PipelineDropdownChip(
              label: cityFilter ?? 'Ciudad',
              isActive: cityFilter != null,
              options: cities,
              onSelected: onCitySelect,
              onClear: () => onCitySelect(null),
              colors: colors,
              enabled: stateFilter != null,
            ),
            const SizedBox(width: AppConstants.paddingSM),
            // Status chips
            ..._allStatuses.map((s) {
              final selected = statusFilters.contains(s);
              final color = _statusColor(context, s);
              return Padding(
                padding: const EdgeInsets.only(right: AppConstants.paddingXS),
                child: FilterChip(
                  label: Text(
                    _statusLabel(s),
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: selected ? Theme.of(context).colorScheme.onPrimary : colors.onSurface,
                    ),
                  ),
                  selected: selected,
                  onSelected: (_) => onStatusToggle(s),
                  selectedColor: color,
                  checkmarkColor: Theme.of(context).colorScheme.onPrimary,
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
                      color: selected ? Theme.of(context).colorScheme.onPrimary : color,
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
                    color: hasWhatsapp == true ? Theme.of(context).colorScheme.onPrimary : colors.onSurface,
                  ),
                ),
                selected: hasWhatsapp == true,
                onSelected: (_) => onWhatsappToggle(),
                selectedColor: Theme.of(context).extension<BCThemeExtension>()!.successColor,
                checkmarkColor: Theme.of(context).colorScheme.onPrimary,
                backgroundColor:
                    colors.surfaceContainerHighest.withValues(alpha: 0.5),
                side: BorderSide(
                  color: hasWhatsapp == true
                      ? Theme.of(context).extension<BCThemeExtension>()!.successColor
                      : colors.onSurface.withValues(alpha: 0.15),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
                showCheckmark: false,
                avatar: Icon(
                  Icons.phone_android_outlined,
                  size: 14,
                  color: hasWhatsapp == true ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).extension<BCThemeExtension>()!.successColor,
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
                        hasInterest == true ? Theme.of(context).colorScheme.onPrimary : colors.onSurface,
                  ),
                ),
                selected: hasInterest == true,
                onSelected: (_) => onInterestToggle(),
                selectedColor: Colors.pink[400],
                checkmarkColor: Theme.of(context).colorScheme.onPrimary,
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
              final color = _sourceColor(context, src);
              return Padding(
                padding: const EdgeInsets.only(right: AppConstants.paddingXS),
                child: FilterChip(
                  label: Text(
                    _sourceLabel(src),
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: selected ? Theme.of(context).colorScheme.onPrimary : colors.onSurface,
                    ),
                  ),
                  selected: selected,
                  onSelected: (_) => onSourceSelect(src),
                  selectedColor: color,
                  checkmarkColor: Theme.of(context).colorScheme.onPrimary,
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

            const SizedBox(width: AppConstants.paddingSM),

            // RP Status chips
            ..._allRpStatuses.map((rps) {
              final selected = rpStatusFilter == rps;
              final color = _rpStatusColor(context, rps);
              return Padding(
                padding: const EdgeInsets.only(right: AppConstants.paddingXS),
                child: FilterChip(
                  label: Text(
                    _rpStatusLabel(rps),
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: selected ? Theme.of(context).colorScheme.onPrimary : colors.onSurface,
                    ),
                  ),
                  selected: selected,
                  onSelected: (_) => onRpStatusSelect(rps),
                  selectedColor: color,
                  checkmarkColor: Theme.of(context).colorScheme.onPrimary,
                  backgroundColor:
                      colors.surfaceContainerHighest.withValues(alpha: 0.5),
                  side: BorderSide(
                    color: selected ? color : colors.onSurface.withValues(alpha: 0.15),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                  showCheckmark: false,
                  avatar: Icon(
                    Icons.person_outline,
                    size: 14,
                    color: selected ? Theme.of(context).colorScheme.onPrimary : color,
                  ),
                ),
              );
            }),

            const SizedBox(width: AppConstants.paddingSM),

            // RP user filter chips
            ...rpUsersAsync.when(
              loading: () => [const Padding(
                padding: EdgeInsets.all(AppConstants.paddingSM),
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              )],
              error: (e, _) => [Padding(
                padding: const EdgeInsets.all(AppConstants.paddingSM),
                child: Text('Error', style: TextStyle(color: Colors.red.shade400, fontSize: 12)),
              )],
              data: (rpUsers) => rpUsers.map((rp) {
                final rpId = rp['id'] as String;
                final rpName = rp['full_name'] as String? ??
                    rp['username'] as String? ??
                    'RP';
                final selected = assignedRpId == rpId;
                return Padding(
                  padding: const EdgeInsets.only(right: AppConstants.paddingXS),
                  child: FilterChip(
                    label: Text(
                      rpName,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: selected ? Theme.of(context).colorScheme.onPrimary : colors.onSurface,
                      ),
                    ),
                    selected: selected,
                    onSelected: (_) => onAssignedRpSelect(rpId),
                    selectedColor: Colors.indigo,
                    checkmarkColor: Theme.of(context).colorScheme.onPrimary,
                    backgroundColor:
                        colors.surfaceContainerHighest.withValues(alpha: 0.5),
                    side: BorderSide(
                      color: selected
                          ? Colors.indigo
                          : colors.onSurface.withValues(alpha: 0.15),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                    showCheckmark: false,
                    avatar: const Icon(
                      Icons.badge_outlined,
                      size: 14,
                      color: Colors.indigo,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pipeline dropdown chip (location filters)
// ---------------------------------------------------------------------------

class _PipelineDropdownChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final List<String> options;
  final ValueChanged<String?> onSelected;
  final VoidCallback onClear;
  final ColorScheme colors;
  final bool enabled;

  const _PipelineDropdownChip({
    required this.label,
    required this.isActive,
    required this.options,
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
                items: options
                    .map((o) => PopupMenuItem<String>(
                          value: o,
                          child: Text(
                            o,
                            style: GoogleFonts.nunito(fontSize: 13),
                          ),
                        ))
                    .toList(),
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
            Icon(Icons.arrow_drop_down, size: 16, color: fgColor),
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
                child: Icon(Icons.close, size: 14, color: fgColor),
              ),
            ],
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
  final VoidCallback onAssignRp;
  final VoidCallback onUnassign;
  final VoidCallback onExport;
  final VoidCallback onClose;
  final VoidCallback onSelectAll;

  const _BulkActionBar({
    required this.count,
    required this.onOutreach,
    required this.onStatus,
    required this.onAssignRp,
    required this.onUnassign,
    required this.onExport,
    required this.onClose,
    required this.onSelectAll,
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
            color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
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
              '$count',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            // Select All button
            TextButton(
              onPressed: onSelectAll,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 28),
              ),
              child: Text(
                'Todos',
                style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: AppConstants.paddingSM),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Assign RP (most important action)
                    _ActionBtn(
                      icon: Icons.person_add_outlined,
                      label: 'Asignar RP',
                      color: Colors.indigo,
                      onTap: onAssignRp,
                    ),
                    const SizedBox(width: AppConstants.paddingSM),
                    // Unassign
                    _ActionBtn(
                      icon: Icons.person_remove_outlined,
                      label: 'Desasignar',
                      color: Colors.deepOrange,
                      onTap: onUnassign,
                    ),
                    const SizedBox(width: AppConstants.paddingSM),
                    // Status
                    _ActionBtn(
                      icon: Icons.edit_outlined,
                      label: 'Estado',
                      color: Theme.of(context).extension<BCThemeExtension>()!.warningColor,
                      onTap: onStatus,
                    ),
                    const SizedBox(width: AppConstants.paddingSM),
                    // Outreach
                    _ActionBtn(
                      icon: Icons.send_outlined,
                      label: 'Outreach',
                      color: Colors.blue,
                      onTap: onOutreach,
                    ),
                    const SizedBox(width: AppConstants.paddingSM),
                    // Export
                    _ActionBtn(
                      icon: Icons.file_download_outlined,
                      label: 'Exportar',
                      color: Theme.of(context).extension<BCThemeExtension>()!.successColor,
                      onTap: onExport,
                    ),
                  ],
                ),
              ),
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
    final rpStatus = lead['rp_status'] as String?;
    final rpName = lead['rp_full_name'] as String?;
    final phone = lead['phone'] as String? ?? '';
    final waVerified = lead['whatsapp_verified'] as bool? ?? false;
    final interestCount = lead['interest_count'] as int? ?? 0;
    final lastOutreachAt = lead['last_outreach_at'] as String?;
    final outreachChannel = lead['outreach_channel'] as String?;

    final locationLine =
        [city, state].where((s) => s.isNotEmpty).join(', ');
    final statusColor = _statusColor(context, status);
    final sourceColor = _sourceColor(context, source);

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
            : Theme.of(context).colorScheme.surface,
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
                            // RP assignment badge
                            if (rpName != null && rpStatus != null) ...[
                              const SizedBox(width: 4),
                              _SmallBadge(
                                label: rpName,
                                color: _rpStatusColor(context, rpStatus),
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
                                Icon(
                                  Icons.check_circle,
                                  size: 13,
                                  color: Theme.of(context).extension<BCThemeExtension>()!.successColor,
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
                    color: Theme.of(context).extension<BCThemeExtension>()!.warningColor,
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
      trailing: Icon(Icons.chevron_right, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
      onTap: onTap,
    );
  }
}

// ---------------------------------------------------------------------------
// Pin Drop Dialog
// ---------------------------------------------------------------------------

class _PinDropDialog extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final double initialRadius;
  final void Function(double lat, double lng, double radiusKm) onConfirm;

  const _PinDropDialog({
    this.initialLat,
    this.initialLng,
    required this.initialRadius,
    required this.onConfirm,
  });

  @override
  State<_PinDropDialog> createState() => _PinDropDialogState();
}

class _PinDropDialogState extends State<_PinDropDialog> {
  ll.LatLng? _pin;
  double _radius = 25;

  static const _radiusOptions = [5.0, 10.0, 25.0, 50.0];

  @override
  void initState() {
    super.initState();
    _radius = widget.initialRadius;
    if (widget.initialLat != null && widget.initialLng != null) {
      _pin = ll.LatLng(widget.initialLat!, widget.initialLng!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initialCenter = _pin ?? const ll.LatLng(20.6, -103.3);
    final initialZoom = _pin != null ? 10.0 : 5.0;

    return AlertDialog(
      contentPadding: const EdgeInsets.all(AppConstants.paddingSM),
      title: Text(
        'Buscar por zona',
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: SizedBox(
        width: MediaQuery.sizeOf(context).width * 0.85,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Map
            SizedBox(
              height: 300,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: initialCenter,
                    initialZoom: initialZoom,
                    onTap: (tapPos, latLng) {
                      setState(() => _pin = latLng);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.beautycita.app',
                    ),
                    if (_pin != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _pin!,
                            width: 30,
                            height: 30,
                            child: Icon(
                              Icons.location_on,
                              color: Theme.of(context).colorScheme.error,
                              size: 30,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppConstants.paddingSM),

            // Radius selector
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Radio:',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                ..._radiusOptions.map((r) {
                  final selected = _radius == r;
                  return ChoiceChip(
                    label: Text(
                      '${r.toInt()} km',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: selected ? Theme.of(context).colorScheme.onPrimary : colors.onSurface,
                      ),
                    ),
                    selected: selected,
                    onSelected: (_) => setState(() => _radius = r),
                    selectedColor: colors.primary,
                    backgroundColor: colors.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  );
                }),
              ],
            ),

            if (_pin == null) ...[
              const SizedBox(height: AppConstants.paddingSM),
              Text(
                'Toca el mapa para colocar el pin',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: colors.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar', style: GoogleFonts.nunito()),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
          ),
          onPressed: _pin == null
              ? null
              : () {
                  Navigator.pop(context);
                  widget.onConfirm(_pin!.latitude, _pin!.longitude, _radius);
                },
          child: Text('Confirmar', style: GoogleFonts.nunito()),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// RP Picker Dialog (for bulk assign)
// ---------------------------------------------------------------------------

class _RpPickerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> rpUsers;
  final int salonCount;
  final void Function(String rpUserId, String rpName) onConfirm;

  const _RpPickerDialog({
    required this.rpUsers,
    required this.salonCount,
    required this.onConfirm,
  });

  @override
  State<_RpPickerDialog> createState() => _RpPickerDialogState();
}

class _RpPickerDialogState extends State<_RpPickerDialog> {
  String? _selectedId;
  String? _selectedName;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(
        'Asignar RP',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selecciona un RP para ${widget.salonCount} salones:',
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppConstants.paddingSM),
            ...widget.rpUsers.map((rp) {
              final rpId = rp['id'] as String;
              final rpName = rp['full_name'] as String? ??
                  rp['username'] as String? ??
                  'RP';
              final isSelected = _selectedId == rpId;
              return InkWell(
                onTap: () => setState(() {
                  _selectedId = rpId;
                  _selectedName = rpName;
                }),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppConstants.paddingSM, horizontal: 4),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: isSelected
                            ? colors.primary
                            : Colors.indigo.withValues(alpha: 0.15),
                        child: Text(
                          rpName.isNotEmpty ? rpName[0].toUpperCase() : '?',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Theme.of(context).colorScheme.onPrimary : Colors.indigo,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          rpName,
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check, size: 18, color: Theme.of(context).extension<BCThemeExtension>()!.successColor),
                    ],
                  ),
                ),
              );
            }),
            if (_selectedName != null) ...[
              const SizedBox(height: AppConstants.paddingSM),
              Container(
                padding: const EdgeInsets.all(AppConstants.paddingSM),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppConstants.radiusXS),
                ),
                child: Text(
                  'Asignar ${widget.salonCount} salones a $_selectedName?',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar', style: GoogleFonts.nunito()),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
          onPressed: _selectedId == null
              ? null
              : () => widget.onConfirm(_selectedId!, _selectedName!),
          child: Text('Asignar', style: GoogleFonts.nunito()),
        ),
      ],
    );
  }
}
