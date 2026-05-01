import 'dart:async';
import 'package:beautycita/config/app_transitions.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/config/fonts.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../config/constants.dart';
import '../../config/theme_extension.dart';
import '../../providers/admin_provider.dart';
import '../../providers/feature_toggle_provider.dart';
import '../../providers/rp_provider.dart';
import '../../services/export_service.dart';
import 'package:beautycita_core/supabase.dart';
import '../../services/supabase_client.dart';
import '../../services/toast_service.dart';
import '../../widgets/admin/outreach_send_sheet.dart';
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

// ---------------------------------------------------------------------------
// Pipeline views — the user-facing concept of "what stage of the funnel are
// these leads in." Replaces the raw status enum exposure. Each view is a
// preset combination of filter values applied on top of geo + search.
// ---------------------------------------------------------------------------

enum _PipelineView {
  uncontacted, // discovered, never reached out, has WA — ready for first invite
  contacted,   // outreach_sent — awaiting reply
  interested,  // has_interest = true
  assigned,    // rp_status assigned OR visited — RP is working it
  declined,    // declined OR unreachable — dead leads
}

const Map<_PipelineView, String> _viewLabels = {
  _PipelineView.uncontacted: 'Por contactar',
  _PipelineView.contacted: 'Contactados',
  _PipelineView.interested: 'Interesados',
  _PipelineView.assigned: 'Asignados',
  _PipelineView.declined: 'Descartados',
};

const Map<_PipelineView, IconData> _viewIcons = {
  _PipelineView.uncontacted: Icons.fiber_new_outlined,
  _PipelineView.contacted: Icons.send_outlined,
  _PipelineView.interested: Icons.favorite_outline,
  _PipelineView.assigned: Icons.person_outline,
  _PipelineView.declined: Icons.do_not_disturb_alt,
};

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
  bool? _hasEmail;
  bool? _hasInterest;
  String? _rpStatusFilter;
  _PipelineView _currentView = _PipelineView.uncontacted;
  String? _assignedRpId;
  double? _pinLat;
  double? _pinLng;
  double _radiusKm = 25;
  Set<String> _selectedIds = {};

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
  /// Resolve the active smart view into concrete filter values. Returns
  /// `(statusFilter, rpStatus, hasInterest)`. The view is the dominant
  /// intent — "show me leads in stage X" — and overrides any conflicting
  /// advanced toggles; the advanced toggles still layer on top for the
  /// orthogonal axes (WA, email, geo).
  ({
    List<String>? statusFilter,
    String? rpStatus,
    bool? hasInterest,
    bool unassignedOnly,
  }) get _viewSlice {
    switch (_currentView) {
      case _PipelineView.uncontacted:
        return (
          statusFilter: ['discovered', 'selected'],
          rpStatus: null,
          hasInterest: null,
          unassignedOnly: true,
        );
      case _PipelineView.contacted:
        return (
          statusFilter: ['outreach_sent'],
          rpStatus: null,
          hasInterest: null,
          unassignedOnly: false,
        );
      case _PipelineView.interested:
        return (
          statusFilter: null,
          rpStatus: null,
          hasInterest: true,
          unassignedOnly: false,
        );
      case _PipelineView.assigned:
        return (
          statusFilter: null,
          rpStatus: _rpStatusFilter ?? 'assigned',
          hasInterest: null,
          unassignedOnly: false,
        );
      case _PipelineView.declined:
        return (
          statusFilter: ['declined', 'unreachable'],
          rpStatus: null,
          hasInterest: null,
          unassignedOnly: false,
        );
    }
  }

  String get _searchKey {
    final v = _viewSlice;
    final parts = <String>['v:${_currentView.name}', _searchQuery];
    final mergedStatuses = <String>{
      ..._statusFilters,
      ...?v.statusFilter,
    };
    if (mergedStatuses.isNotEmpty) {
      final sorted = mergedStatuses.toList()..sort();
      parts.add('s:${sorted.join(',')}');
    }
    if (_hasWhatsapp == true) parts.add('wa:1');
    if (_hasEmail == true) parts.add('em:1');
    final hasInterest = _hasInterest ?? v.hasInterest;
    if (hasInterest == true) parts.add('int:1');
    final rpStatus = v.rpStatus ?? _rpStatusFilter;
    if (rpStatus != null) parts.add('rps:$rpStatus');
    if (_assignedRpId != null) parts.add('rp:$_assignedRpId');
    if (_hasGeoFilter) parts.add('geo:$_pinLat,$_pinLng,$_radiusKm');
    if (_countryFilter != null) parts.add('country:$_countryFilter');
    if (_stateFilter != null) parts.add('state:$_stateFilter');
    if (_cityFilter != null) parts.add('city:$_cityFilter');
    return parts.join('|');
  }

  Map<String, dynamic> get _searchParams {
    final v = _viewSlice;
    final mergedStatuses = <String>{
      ..._statusFilters,
      ...?v.statusFilter,
    };
    final hasInterest = _hasInterest ?? v.hasInterest;
    final rpStatus = v.rpStatus ?? _rpStatusFilter;
    return {
      'query': _searchQuery,
      if (mergedStatuses.isNotEmpty)
        'status_filter': mergedStatuses.toList(),
      if (_hasWhatsapp == true) 'has_whatsapp': true,
      if (_hasEmail == true) 'has_email_client': true,
      if (hasInterest == true) 'has_interest': true,
      'p_rp_status_filter': ?rpStatus,
      if (_assignedRpId != null) 'p_assigned_rp_id': _assignedRpId,
      if (_assignedRpId == null && rpStatus == null && v.unassignedOnly)
        'p_unassigned_only': true,
      if (_pinLat != null) 'p_pin_lat': _pinLat,
      if (_pinLng != null) 'p_pin_lng': _pinLng,
      if (_hasGeoFilter) 'p_radius_km': _radiusKm,
      if (_cityFilter != null) 'city_filter': _cityFilter,
      if (_countryFilter != null) 'country_filter': _countryFilter,
      if (_stateFilter != null) 'state_filter': _stateFilter,
    };
  }

  /// Translate raw funnel-status counts into smart-view counts. Some
  /// views are unions of multiple statuses (uncontacted = discovered +
  /// selected; declined = declined + unreachable); two views (interested,
  /// assigned) don't map to status counts at all and stay null until we
  /// add dedicated counters server-side.
  Map<_PipelineView, int?> _funnelCountsFromStats(
      AsyncValue<Map<String, int>> statsAsync) {
    final s = statsAsync.valueOrNull;
    if (s == null) {
      return {for (final v in _PipelineView.values) v: null};
    }
    int g(String k) => s[k] ?? 0;
    return {
      _PipelineView.uncontacted: g('discovered') + g('selected'),
      _PipelineView.contacted: g('outreach_sent'),
      _PipelineView.interested: null, // needs interest_count breakdown
      _PipelineView.assigned: null,   // needs rp_status breakdown
      _PipelineView.declined: g('declined') + g('unreachable'),
    };
  }

  void _setView(_PipelineView v) {
    if (_currentView == v) return;
    setState(() {
      _currentView = v;
      // Reset transient overrides — the view sets the headline filter,
      // and we don't want stale extras polluting the next slice.
      _statusFilters = {};
      _rpStatusFilter = null;
      _hasInterest = null;
      _selectedIds = {};
    });
  }

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
          .from(BCTables.discoveredSalons)
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
          .from(BCTables.discoveredSalons)
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
          .from(BCTables.discoveredSalons)
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
    setState(() => _selectedIds = {});
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
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

  Future<void> _bulkUpdateStatus(String newStatus) async {
    final ids = _selectedIds.toList();
    final count = ids.length;
    try {
      await SupabaseClientService.client
          .from(BCTables.discoveredSalons)
          .update({'status': newStatus})
          .inFilter('id', ids);
    } catch (e) {
      if (mounted) ToastService.showError('Error al actualizar: $e');
      return;
    }

    ref.invalidate(searchDiscoveredSalonsProvider(_searchKey));
    ref.invalidate(pipelineFunnelStatsProvider(_searchKey));

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
    // Set params first so both pipelineFunnelStatsProvider and
    // searchDiscoveredSalonsProvider see the current filter chain on this frame.
    ref.read(pipelineSearchParamsProvider.notifier).state = _searchParams;
    final statsAsync = ref.watch(pipelineFunnelStatsProvider(_searchKey));
    final leadsAsync = ref.watch(searchDiscoveredSalonsProvider(_searchKey));

    return Stack(
      children: [
        Column(
          children: [
            // 1. Smart-view selector — the user's primary axis through the
            // funnel. Hides the raw status enum behind named workflows.
            _PipelineViewBar(
              current: _currentView,
              onSelect: _setView,
              counts: _funnelCountsFromStats(statsAsync),
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

            // 3. Geo + advanced toggles (a compact single row, scrollable)
            _PipelineFilterStrip(
              hasWhatsapp: _hasWhatsapp,
              hasEmail: _hasEmail,
              countryFilter: _countryFilter,
              stateFilter: _stateFilter,
              cityFilter: _cityFilter,
              countries: _countries,
              states: _states,
              cities: _cities,
              onCountrySelect: _setCountryFilter,
              onStateSelect: _setStateFilter,
              onCitySelect: _setCityFilter,
              onWhatsappToggle: () {
                setState(() {
                  _hasWhatsapp = _hasWhatsapp == true ? null : true;
                });
              },
              onEmailToggle: () {
                setState(() {
                  _hasEmail = _hasEmail == true ? null : true;
                });
              },
            ),

            const SizedBox(height: AppConstants.paddingXS),

            // 4. Lead list — leave room at bottom for the always-visible
            // bulk action bar so the last card never sits behind it.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 64),
                child: _buildLeadList(colors, leadsAsync),
              ),
            ),
          ],
        ),

        // 5. Bulk action bar — always visible. Empty state prompts the
        // user to start selecting; populated state activates the actions.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _BulkActionBar(
            count: _selectedIds.length,
            totalLoaded: leadsAsync.maybeWhen(
              data: (l) => l.length,
              orElse: () => 0,
            ),
            onOutreach: () async {
              if (_selectedIds.isEmpty) return;
              final ids = _selectedIds.toList();
              if (ids.length > 100) {
                ToastService.showError(
                  'Máximo 100 salones por envío. Hay ${ids.length} seleccionados.',
                );
                return;
              }
              final sent = await showOutreachSendSheet(
                context: context,
                recipientTable: 'discovered_salons',
                recipientIds: ids,
                recipientLabel: 'Enviar mensaje a ${ids.length} salones',
              );
              if (sent && context.mounted) {
                _exitSelection();
                ref.invalidate(searchDiscoveredSalonsProvider(_searchKey));
                ref.invalidate(pipelineFunnelStatsProvider(_searchKey));
              }
            },
            onAssignRp: _selectedIds.isEmpty ? null : _showBulkAssignDialog,
            onMarcar: _selectedIds.isEmpty
                ? null
                : () => _showMarcarDialog(context),
            onSelectAll: () {
              leadsAsync.whenData((leads) {
                setState(() {
                  _selectedIds = leads
                      .map((l) => l['id']?.toString() ?? '')
                      .where((id) => id.isNotEmpty)
                      .toSet();
                });
              });
            },
            onClear: _selectedIds.isEmpty ? null : _exitSelection,
          ),
        ),
      ],
    );
  }

  /// Disposition picker — the only manual state-machine surface left.
  /// Three options that map to the public "this lead is dead/promising/
  /// unreachable" mental model. Routes through `_bulkUpdateStatus`.
  Future<void> _showMarcarDialog(BuildContext context) async {
    if (_selectedIds.isEmpty) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingMD),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Marcar ${_selectedIds.length} salones como…',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.favorite, color: Colors.pink),
                title: const Text('Interesados'),
                subtitle: const Text(
                    'Mostraron interés en respuesta a un mensaje'),
                onTap: () => Navigator.of(ctx).pop('interested'),
              ),
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: Colors.red),
                title: const Text('Declinados'),
                subtitle: const Text('Dijeron explícitamente que no'),
                onTap: () => Navigator.of(ctx).pop('declined'),
              ),
              ListTile(
                leading: Icon(Icons.signal_cellular_off,
                    color: Colors.grey.shade500),
                title: const Text('Inalcanzables'),
                subtitle: const Text('Teléfono fuera de servicio o sin respuesta'),
                onTap: () => Navigator.of(ctx).pop('unreachable'),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !context.mounted) return;

    if (picked == 'interested') {
      // Bump interest_count via direct table update so the "Interesados"
      // view picks the leads up. Status stays at outreach_sent.
      try {
        await SupabaseClientService.client
            .from('discovered_salons')
            .update({'interest_count': 1})
            .inFilter('id', _selectedIds.toList());
        ref.invalidate(searchDiscoveredSalonsProvider(_searchKey));
        ref.invalidate(pipelineFunnelStatsProvider(_searchKey));
        if (mounted) {
          ToastService.showSuccess(
              '${_selectedIds.length} marcados como interesados');
        }
        _exitSelection();
      } catch (e, stack) {
        ToastService.showErrorWithDetails(
            ToastService.friendlyError(e), e, stack);
      }
      return;
    }

    await _bulkUpdateStatus(picked);
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
              onTap: () => showLeadDetailSheet(context, lead),
              onToggleSelection: () => _toggleSelection(id),
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

/// Sticky bulk action bar — always visible. Three primary actions:
///   📨 Enviar invitación (outreach)
///   👤 Asignar RP
///   🚫 Marcar como (interesados/declinados/inalcanzables)
/// All disabled when nothing is selected. The "Todos" pill helps select
/// the entire current view in one tap.
class _BulkActionBar extends StatelessWidget {
  final int count;
  final int totalLoaded;
  final VoidCallback onOutreach;
  final VoidCallback? onAssignRp;
  final VoidCallback? onMarcar;
  final VoidCallback onSelectAll;
  final VoidCallback? onClear;

  const _BulkActionBar({
    required this.count,
    required this.totalLoaded,
    required this.onOutreach,
    required this.onAssignRp,
    required this.onMarcar,
    required this.onSelectAll,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasSelection = count > 0;
    final caption = hasSelection
        ? '$count de $totalLoaded'
        : (totalLoaded == 0
            ? 'Sin resultados'
            : 'Toca un salon para seleccionarlo');

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
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    caption,
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      color: colors.onSurface.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: totalLoaded > 0 ? onSelectAll : null,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: const Size(0, 24),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Todos',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (onClear != null)
                        TextButton(
                          onPressed: onClear,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minimumSize: const Size(0, 24),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Limpiar',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: colors.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Primary action: send invite. Always shown; disabled until selection.
            _ActionBtn(
              icon: Icons.send_outlined,
              label: 'Invitar',
              color: colors.primary,
              onTap: hasSelection ? onOutreach : null,
            ),
            const SizedBox(width: AppConstants.paddingSM),
            _ActionBtn(
              icon: Icons.person_add_outlined,
              label: 'Asignar',
              color: Colors.indigo,
              onTap: onAssignRp,
            ),
            const SizedBox(width: AppConstants.paddingSM),
            _ActionBtn(
              icon: Icons.flag_outlined,
              label: 'Marcar',
              color: Theme.of(context).extension<BCThemeExtension>()!.warningColor,
              onTap: onMarcar,
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
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final tone =
        disabled ? Theme.of(context).disabledColor : color;
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
            Icon(icon, size: 18, color: tone),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 10,
                color: tone,
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
// Smart-view selector — horizontal pill row pinned at the top of the screen.
// ---------------------------------------------------------------------------

class _PipelineViewBar extends StatelessWidget {
  final _PipelineView current;
  final ValueChanged<_PipelineView> onSelect;
  final Map<_PipelineView, int?> counts;

  const _PipelineViewBar({
    required this.current,
    required this.onSelect,
    required this.counts,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(
            color: colors.onSurface.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingMD,
            vertical: 8,
          ),
          children: _PipelineView.values.map((v) {
            final selected = v == current;
            final count = counts[v];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => onSelect(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? colors.primary
                        : colors.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _viewIcons[v],
                        size: 14,
                        color: selected
                            ? colors.onPrimary
                            : colors.onSurface.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _viewLabels[v]!,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? colors.onPrimary
                              : colors.onSurface,
                        ),
                      ),
                      if (count != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? colors.onPrimary.withValues(alpha: 0.18)
                                : colors.onSurface.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            count.toString(),
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? colors.onPrimary
                                  : colors.onSurface
                                      .withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Compact filter strip — geo dropdowns + WhatsApp/Email toggles. The
// smart-view selector handles status; this strip is for orthogonal axes.
// ---------------------------------------------------------------------------

class _PipelineFilterStrip extends StatelessWidget {
  final bool? hasWhatsapp;
  final bool? hasEmail;
  final String? countryFilter;
  final String? stateFilter;
  final String? cityFilter;
  final List<String> countries;
  final List<String> states;
  final List<String> cities;
  final void Function(String?) onCountrySelect;
  final void Function(String?) onStateSelect;
  final void Function(String?) onCitySelect;
  final VoidCallback onWhatsappToggle;
  final VoidCallback onEmailToggle;

  const _PipelineFilterStrip({
    required this.hasWhatsapp,
    required this.hasEmail,
    required this.countryFilter,
    required this.stateFilter,
    required this.cityFilter,
    required this.countries,
    required this.states,
    required this.cities,
    required this.onCountrySelect,
    required this.onStateSelect,
    required this.onCitySelect,
    required this.onWhatsappToggle,
    required this.onEmailToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<BCThemeExtension>()!;

    Widget toggleChip({
      required String label,
      required bool selected,
      required Color accent,
      required VoidCallback onTap,
      required IconData icon,
    }) {
      return Padding(
        padding: const EdgeInsets.only(right: AppConstants.paddingXS),
        child: FilterChip(
          label: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 12,
              color:
                  selected ? colors.onPrimary : colors.onSurface,
            ),
          ),
          selected: selected,
          onSelected: (_) => onTap(),
          selectedColor: accent,
          checkmarkColor: colors.onPrimary,
          backgroundColor:
              colors.surfaceContainerHighest.withValues(alpha: 0.5),
          side: BorderSide(
            color:
                selected ? accent : colors.onSurface.withValues(alpha: 0.15),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
          showCheckmark: false,
          avatar: Icon(
            icon,
            size: 14,
            color: selected ? colors.onPrimary : accent,
          ),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: AppConstants.paddingMD),
        child: Row(
          children: [
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
            toggleChip(
              label: 'WhatsApp',
              selected: hasWhatsapp == true,
              accent: ext.successColor,
              onTap: onWhatsappToggle,
              icon: Icons.phone_android_outlined,
            ),
            toggleChip(
              label: 'Email',
              selected: hasEmail == true,
              accent: Colors.blueGrey,
              onTap: onEmailToggle,
              icon: Icons.email_outlined,
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
  final VoidCallback onTap;
  final VoidCallback onToggleSelection;

  const _LeadCard({
    required this.lead,
    required this.isSelected,
    required this.onTap,
    required this.onToggleSelection,
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
    final emailRaw = lead['email'] as String? ?? '';
    final hasEmail = emailRaw.contains('@');
    final phoneOnly = !waVerified && !hasEmail && phone.isNotEmpty;
    final interestCount = lead['interest_count'] as int? ?? 0;
    final lastOutreachAt = lead['last_outreach_at'] as String?;
    final outreachChannel = lead['outreach_channel'] as String?;
    // HVT enrichment from admin_provider follow-up fetch.
    final tierId = lead['tier_id'] as String?;
    final hvtScore = (lead['hvt_score'] as num?)?.toDouble();
    final tierLocked = lead['tier_locked'] == true;

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
                            // HVT tier badge (highest first — tier dot + score).
                            if (tierId != null) ...[
                              _TierBadge(
                                tierId: tierId,
                                score: hvtScore,
                                locked: tierLocked,
                              ),
                              const SizedBox(width: 4),
                            ],
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
                            // Phone-only — no email, no verified WA. Highlight
                            // for outreach prep: these need email/WA enrichment
                            // before bulk send works.
                            if (phoneOnly) ...[
                              const SizedBox(width: 4),
                              const _SmallBadge(
                                label: '📞 Solo teléfono',
                                color: Colors.deepOrange,
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

                  // Checkbox is always visible — the bulk action bar is
                  // always present, so selection is the default mental
                  // model. Tap card body to view detail; tap checkbox to
                  // include in the next bulk action.
                  const SizedBox(width: AppConstants.paddingSM),
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => onToggleSelection(),
                    visualDensity: VisualDensity.compact,
                    activeColor: colors.primary,
                  ),
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

/// Inline HVT tier badge — small dot + label + (optional) score, with a
/// padlock icon when tier_locked. Colors match discovered_salon_tiers seed.
class _TierBadge extends StatelessWidget {
  final String tierId;
  final double? score;
  final bool locked;
  const _TierBadge({required this.tierId, required this.score, required this.locked});

  static const _meta = <String, ({String label, Color color})>{
    't1': (label: 'Estrella',    color: Color(0xFFFFD700)),
    't2': (label: 'Líder',       color: Color(0xFFC0C0C0)),
    't3': (label: 'Establecido', color: Color(0xFFCD7F32)),
    't4': (label: 'Estándar',    color: Color(0xFFA8A8A8)),
    't5': (label: 'Volumen',     color: Color(0xFF7FB069)),
    't6': (label: 'Marginal',    color: Color(0xFF5C5C5C)),
  };

  @override
  Widget build(BuildContext context) {
    final m = _meta[tierId] ?? (label: tierId, color: Colors.grey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: m.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: m.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            m.label,
            style: GoogleFonts.nunito(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: m.color,
            ),
          ),
          if (score != null) ...[
            const SizedBox(width: 4),
            Text(
              score!.toStringAsFixed(0),
              style: GoogleFonts.nunito(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: m.color,
              ),
            ),
          ],
          if (locked) ...[
            const SizedBox(width: 3),
            Icon(Icons.lock, size: 9, color: m.color),
          ],
        ],
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
