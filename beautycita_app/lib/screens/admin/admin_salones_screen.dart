import 'dart:async';
import 'package:beautycita/config/app_transitions.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/constants.dart';
import '../../providers/admin_provider.dart';
import '../../services/export_service.dart';
import '../../services/supabase_client.dart';
import '../../services/toast_service.dart';
import 'admin_pipeline_screen.dart';
import 'admin_salon_detail_screen.dart';
import 'pipeline_lead_detail_sheet.dart';

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

/// Wrapper with Registrados / Descubiertos tabs.
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
              Tab(text: 'Registrados'),
              Tab(text: 'Descubiertos'),
              Tab(text: 'Pipeline'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _RegisteredSalonesTab(),
                _DiscoveredSalonesTab(),
                AdminPipelineScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tab 1: Registered salons (original AdminSalonesScreen content).
class _RegisteredSalonesTab extends ConsumerStatefulWidget {
  const _RegisteredSalonesTab();

  @override
  ConsumerState<_RegisteredSalonesTab> createState() => _RegisteredSalonesTabState();
}

class _RegisteredSalonesTabState extends ConsumerState<_RegisteredSalonesTab> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _activeQuery = '';
  bool _showOrphanedOnly = false;

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
        setState(() => _activeQuery = value.trim());
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _debounce?.cancel();
    setState(() => _activeQuery = '');
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final resultsAsync = ref.watch(searchSalonsProvider(_activeQuery));

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
                    hintText: 'Buscar salon... (nombre, tel, ciudad, etc.)',
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
                onPressed: () =>
                    setState(() => _showOrphanedOnly = !_showOrphanedOnly),
              ),
              // Export button — only active when there are results
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

        // Results count
        if (_activeQuery.length >= 2)
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

  Widget _buildBody(
    ColorScheme colors,
    AsyncValue<List<Map<String, dynamic>>> resultsAsync,
  ) {
    // No query entered yet
    if (_activeQuery.length < 2) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.manage_search,
              size: 52,
              color: colors.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
            Text(
              'Escribe para buscar salones',
              style: GoogleFonts.nunito(
                fontSize: 15,
                color: colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Minimo 2 caracteres',
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      );
    }

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
                'Error al buscar salones',
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
                onPressed: () => ref.invalidate(searchSalonsProvider(_activeQuery)),
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
                  Icons.search_off,
                  size: 48,
                  color: colors.onSurface.withValues(alpha: 0.2),
                ),
                const SizedBox(height: 12),
                Text(
                  'No se encontraron salones',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    color: colors.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '"$_activeQuery"',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: colors.onSurface.withValues(alpha: 0.3),
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

        return ListView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingMD,
            vertical: AppConstants.paddingXS,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, i) => _SalonResultCard(salon: filtered[i]),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Salon result card
// ---------------------------------------------------------------------------

class _SalonResultCard extends StatelessWidget {
  final Map<String, dynamic> salon;

  const _SalonResultCard({required this.salon});

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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final name = salon['name'] as String? ?? 'Sin nombre';
    final city = salon['city'] as String? ?? '';
    final state = salon['state'] as String? ?? '';
    final phone = salon['phone'] as String? ?? '';
    final tier = salon['tier'] as int?;
    final isActive = salon['is_active'] as bool? ?? false;
    final rating = (salon['average_rating'] as num?)?.toDouble();
    final reviews = salon['total_reviews'] as int?;
    final isOrphaned = salon['owner_id'] == null;

    final locationLine = [city, state].where((s) => s.isNotEmpty).join(', ');
    final tierColor = _tierColor(tier, colors);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.paddingXS),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppConstants.radiusSM),
          onTap: () {
            final id = salon['id'] as String?;
            if (id == null) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminSalonDetailScreen(businessId: id),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
              border: Border.all(
                color: colors.onSurface.withValues(alpha: 0.1),
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                          // Row 1: Name + tier badge
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
                                    color: Colors.orange.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Huerfano',
                                    style: GoogleFonts.nunito(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.orange[800],
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

// ---------------------------------------------------------------------------
// Export bottom sheet
// ---------------------------------------------------------------------------

class _ExportBottomSheet extends StatefulWidget {
  final List<Map<String, dynamic>> salons;
  final String query;

  const _ExportBottomSheet({required this.salons, required this.query});

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
        columns: _salonExportColumns,
        format: format,
        title: 'Salones BeautyCita${widget.query.isNotEmpty ? " - ${widget.query}" : ""}',
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
// Tab 2: Discovered salons (pipeline)
// ---------------------------------------------------------------------------

class _DiscoveredSalonesTab extends ConsumerStatefulWidget {
  const _DiscoveredSalonesTab();

  @override
  ConsumerState<_DiscoveredSalonesTab> createState() => _DiscoveredSalonesTabState();
}

class _DiscoveredSalonesTabState extends ConsumerState<_DiscoveredSalonesTab> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _query = '';

  // Location filter state
  String? _countryFilter;
  String? _stateFilter;
  String? _cityFilter;
  bool _waVerifiedFilter = false;
  bool _hasPhoneFilter = false;
  String? _statusFilter;

  // Dropdown options (loaded from DB)
  List<String> _countries = [];
  List<String> _states = [];
  List<String> _cities = [];

  static const _allDiscoveredStatuses = [
    'discovered',
    'selected',
    'outreach_sent',
    'registered',
    'declined',
    'unreachable',
  ];

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
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
    } catch (_) {}
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
    } catch (_) {}
  }

  Future<void> _loadCities(String state) async {
    setState(() {
      _cities = [];
    });
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
    } catch (_) {}
  }

  void _setCountry(String? country) {
    setState(() {
      _countryFilter = country;
      _stateFilter = null;
      _cityFilter = null;
      _states = [];
      _cities = [];
    });
    if (country != null) _loadStates(country);
  }

  void _setState(String? state) {
    setState(() {
      _stateFilter = state;
      _cityFilter = null;
      _cities = [];
    });
    if (state != null) _loadCities(state);
  }

  void _setCity(String? city) {
    setState(() => _cityFilter = city);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.paddingMD,
            AppConstants.paddingMD,
            AppConstants.paddingMD,
            0,
          ),
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
                if (mounted) setState(() => _query = v.trim());
              });
            },
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
                // Country dropdown chip
                _DropdownChip(
                  label: _countryFilter ?? 'Pais',
                  isActive: _countryFilter != null,
                  options: _countries,
                  onSelected: _setCountry,
                  onClear: () => _setCountry(null),
                  colors: colors,
                ),
                const SizedBox(width: 6),
                // State dropdown chip
                _DropdownChip(
                  label: _stateFilter ?? 'Estado',
                  isActive: _stateFilter != null,
                  options: _states,
                  onSelected: _setState,
                  onClear: () => _setState(null),
                  colors: colors,
                  enabled: _countryFilter != null,
                ),
                const SizedBox(width: 6),
                // City dropdown chip
                _DropdownChip(
                  label: _cityFilter ?? 'Ciudad',
                  isActive: _cityFilter != null,
                  options: _cities,
                  onSelected: _setCity,
                  onClear: () => _setCity(null),
                  colors: colors,
                  enabled: _stateFilter != null,
                ),
                const SizedBox(width: 6),
                // WA Verified toggle
                FilterChip(
                  label: Text(
                    'WA Verificado',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: _waVerifiedFilter ? Colors.white : colors.onSurface,
                    ),
                  ),
                  selected: _waVerifiedFilter,
                  onSelected: (_) => setState(() => _waVerifiedFilter = !_waVerifiedFilter),
                  selectedColor: Colors.green[600],
                  checkmarkColor: Colors.white,
                  backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                  side: BorderSide(
                    color: _waVerifiedFilter ? Colors.green : colors.onSurface.withValues(alpha: 0.15),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                  showCheckmark: false,
                  avatar: Icon(
                    Icons.verified,
                    size: 14,
                    color: _waVerifiedFilter ? Colors.white : Colors.green,
                  ),
                ),
                const SizedBox(width: 6),
                // Has Phone toggle
                FilterChip(
                  label: Text(
                    'Con telefono',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: _hasPhoneFilter ? Colors.white : colors.onSurface,
                    ),
                  ),
                  selected: _hasPhoneFilter,
                  onSelected: (_) => setState(() => _hasPhoneFilter = !_hasPhoneFilter),
                  selectedColor: Colors.blue[600],
                  checkmarkColor: Colors.white,
                  backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                  side: BorderSide(
                    color: _hasPhoneFilter ? Colors.blue : colors.onSurface.withValues(alpha: 0.15),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                  showCheckmark: false,
                  avatar: Icon(
                    Icons.phone,
                    size: 14,
                    color: _hasPhoneFilter ? Colors.white : Colors.blue,
                  ),
                ),
                const SizedBox(width: 6),
                // Status chips
                ..._allDiscoveredStatuses.map((s) {
                  final selected = _statusFilter == s;
                  final color = _statusColor(s);
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: FilterChip(
                      label: Text(
                        _statusLabel(s),
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: selected ? Colors.white : colors.onSurface,
                        ),
                      ),
                      selected: selected,
                      onSelected: (_) => setState(() {
                        _statusFilter = selected ? null : s;
                      }),
                      selectedColor: color,
                      checkmarkColor: Colors.white,
                      backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
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
              ],
            ),
          ),
        ),

        // Results
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchDiscovered(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final salons = snap.data ?? [];
              if (salons.isEmpty) {
                return Center(
                  child: Text(
                    _query.isEmpty && _countryFilter == null && !_waVerifiedFilter && !_hasPhoneFilter && _statusFilter == null
                        ? 'Cargando salones...'
                        : 'Sin resultados',
                    style: GoogleFonts.nunito(color: colors.onSurface.withValues(alpha: 0.5)),
                  ),
                );
              }
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingLG),
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
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMD),
                      itemCount: salons.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final s = salons[i];
                        final name = s['business_name'] as String? ?? '';
                        final city = s['location_city'] as String? ?? '';
                        final status = s['status'] as String? ?? 'discovered';
                        final rating = s['rating_average'];
                        final waVerified = s['whatsapp_verified'] == true;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colors.primary.withValues(alpha: 0.1),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                color: colors.primary,
                              ),
                            ),
                          ),
                          title: Text(
                            name,
                            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Row(
                            children: [
                              Text(city, style: GoogleFonts.nunito(fontSize: 12)),
                              if (rating != null) ...[
                                const SizedBox(width: 8),
                                Icon(Icons.star, size: 12, color: Colors.amber.shade700),
                                Text(' $rating', style: GoogleFonts.nunito(fontSize: 12)),
                              ],
                              const SizedBox(width: 8),
                              if (waVerified)
                                const Icon(Icons.verified, size: 12, color: Colors.green),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _statusColor(status).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _statusLabel(status),
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _statusColor(status),
                              ),
                            ),
                          ),
                          onTap: () {
                            // Open discovered salon detail
                            showLeadDetailSheet(context, s);
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _fetchDiscovered() async {
    try {
      var query = SupabaseClientService.client
          .from('discovered_salons')
          .select('id, business_name, phone, whatsapp, location_city, location_state, country, status, rating_average, rating_count, whatsapp_verified, feature_image_url, matched_categories, interest_count')
          .not('latitude', 'is', null);

      if (_query.isNotEmpty) {
        query = query.ilike('business_name', '%$_query%');
      }

      // Location cascading filters
      if (_countryFilter != null) {
        query = query.eq('country', _countryFilter!);
      }
      if (_stateFilter != null) {
        query = query.eq('location_state', _stateFilter!);
      }
      if (_cityFilter != null) {
        query = query.eq('location_city', _cityFilter!);
      }

      // Toggle filters
      if (_waVerifiedFilter) {
        query = query.eq('whatsapp_verified', true);
      }
      if (_hasPhoneFilter) {
        query = query.not('phone', 'is', null).neq('phone', '');
      }

      // Status filter
      if (_statusFilter != null) {
        query = query.eq('status', _statusFilter!);
      }

      final data = await query
          .order('interest_count', ascending: false)
          .limit(200);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      if (kDebugMode) debugPrint('[DiscoveredTab] Error: $e');
      return [];
    }
  }

  Color _statusColor(String status) => switch (status) {
    'discovered' => Colors.grey,
    'selected' => Colors.blue,
    'outreach_sent' => Colors.orange,
    'registered' => Colors.green,
    'converted' => Colors.green,
    'declined' => Colors.red,
    'unreachable' => Colors.grey.shade400,
    _ => Colors.grey,
  };

  String _statusLabel(String status) => switch (status) {
    'discovered' => 'Encontrado',
    'selected' => 'Seleccionado',
    'outreach_sent' => 'Contactado',
    'registered' => 'Registrado',
    'converted' => 'Convertido',
    'declined' => 'Rechazado',
    'unreachable' => 'Inalcanzable',
    _ => status,
  };
}

// ---------------------------------------------------------------------------
// Reusable dropdown chip for location filters
// ---------------------------------------------------------------------------

class _DropdownChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final List<String> options;
  final ValueChanged<String?> onSelected;
  final VoidCallback onClear;
  final ColorScheme colors;
  final bool enabled;

  const _DropdownChip({
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
            ? Colors.white
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
