import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/constants.dart';
import '../../providers/admin_provider.dart';
import '../../services/export_service.dart';
// TODO(task8): AdminSalonDetailScreen will be fully implemented in Task 8
import 'admin_salon_detail_screen.dart';

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

class AdminSalonesScreen extends ConsumerStatefulWidget {
  const AdminSalonesScreen({super.key});

  @override
  ConsumerState<AdminSalonesScreen> createState() => _AdminSalonesScreenState();
}

class _AdminSalonesScreenState extends ConsumerState<AdminSalonesScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _activeQuery = '';

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
    showModalBottomSheet(
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

        return ListView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingMD,
            vertical: AppConstants.paddingXS,
          ),
          itemCount: salons.length,
          itemBuilder: (context, i) => _SalonResultCard(salon: salons[i]),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar: $e'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
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
