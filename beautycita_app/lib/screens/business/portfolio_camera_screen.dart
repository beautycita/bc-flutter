import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/constants.dart';
import '../../providers/business_provider.dart';
import '../../services/portfolio_service.dart';
import '../../services/supabase_client.dart';
import '../../services/toast_service.dart';

// ---------------------------------------------------------------------------
// Route parameter container — passed via GoRouter extra
// ---------------------------------------------------------------------------

class PortfolioCameraArgs {
  final String businessId;
  final String? appointmentId;

  const PortfolioCameraArgs({
    required this.businessId,
    this.appointmentId,
  });
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class PortfolioCameraScreen extends ConsumerStatefulWidget {
  final String businessId;
  final String? appointmentId;

  const PortfolioCameraScreen({
    super.key,
    required this.businessId,
    this.appointmentId,
  });

  @override
  ConsumerState<PortfolioCameraScreen> createState() =>
      _PortfolioCameraScreenState();
}

class _PortfolioCameraScreenState
    extends ConsumerState<PortfolioCameraScreen> {
  static const _tipsPrefKey = 'portfolio_camera_tips_seen';

  // Tips overlay
  bool _tipsVisible = false;

  // Before section
  bool? _clientAuthorized; // null = not answered yet
  final List<Uint8List> _beforeShots = [];
  int _bestBeforeIndex = 0;
  int _selectedBeforeIndex = 0;

  // After section
  final List<Uint8List> _afterShots = [];
  int _bestAfterIndex = 0;
  int _selectedAfterIndex = 0;

  // Tagging
  String? _selectedServiceCategory;
  String? _selectedStaffId;
  final _captionCtrl = TextEditingController();
  final _productTagsCtrl = TextEditingController();

  // UI state
  bool _saving = false;

  final _picker = ImagePicker();

  // Predefined service categories — real values come from Supabase services
  // but we fall back to these well-known ones if the fetch is empty.
  static const _fallbackCategories = [
    'Cabello',
    'Unas',
    'Maquillaje',
    'Pestanas',
    'Cejas',
    'Piel / Facial',
    'Masaje',
    'Otro',
  ];

  @override
  void initState() {
    super.initState();
    _checkTips();
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    _productTagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkTips() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_tipsPrefKey) ?? false;
    if (!seen && mounted) {
      setState(() => _tipsVisible = true);
    }
  }

  Future<void> _dismissTips() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tipsPrefKey, true);
    if (mounted) setState(() => _tipsVisible = false);
  }

  // ---------------------------------------------------------------------------
  // Camera helpers
  // ---------------------------------------------------------------------------

  Future<void> _captureShot({required bool isBefore}) async {
    final xFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: AppConstants.imageQualityHigh,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (xFile == null) return;

    final bytes = await xFile.readAsBytes();

    if (isBefore) {
      setState(() => _beforeShots.add(bytes));
      _updateBestBefore();
    } else {
      setState(() => _afterShots.add(bytes));
      _updateBestAfter();
    }
  }

  Future<void> _updateBestBefore() async {
    if (_beforeShots.isEmpty) return;
    final best = await PortfolioService.selectBestImage(_beforeShots);
    if (mounted) {
      setState(() {
        _bestBeforeIndex = best;
        _selectedBeforeIndex = best;
      });
    }
  }

  Future<void> _updateBestAfter() async {
    if (_afterShots.isEmpty) return;
    final best = await PortfolioService.selectBestImage(_afterShots);
    if (mounted) {
      setState(() {
        _bestAfterIndex = best;
        _selectedAfterIndex = best;
      });
    }
  }

  void _removeBeforeShot(int index) {
    setState(() {
      _beforeShots.removeAt(index);
      if (_selectedBeforeIndex >= _beforeShots.length) {
        _selectedBeforeIndex = (_beforeShots.length - 1).clamp(0, 999);
      }
      if (_bestBeforeIndex >= _beforeShots.length) {
        _bestBeforeIndex = 0;
      }
    });
    if (_beforeShots.length > 1) _updateBestBefore();
  }

  void _removeAfterShot(int index) {
    setState(() {
      _afterShots.removeAt(index);
      if (_selectedAfterIndex >= _afterShots.length) {
        _selectedAfterIndex = (_afterShots.length - 1).clamp(0, 999);
      }
      if (_bestAfterIndex >= _afterShots.length) {
        _bestAfterIndex = 0;
      }
    });
    if (_afterShots.length > 1) _updateBestAfter();
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  Future<void> _save(List<Map<String, dynamic>> categories) async {
    if (_afterShots.isEmpty) {
      ToastService.showError('Necesitas al menos una foto del resultado');
      return;
    }

    setState(() => _saving = true);

    try {
      final rawAfter = _afterShots[_selectedAfterIndex];
      final correctedAfter = await PortfolioService.autoCorrectImage(rawAfter);

      Uint8List? correctedBefore;
      if (_clientAuthorized == true && _beforeShots.isNotEmpty) {
        final rawBefore = _beforeShots[_selectedBeforeIndex];
        correctedBefore = await PortfolioService.autoCorrectImage(rawBefore);
      }

      final photoType = correctedBefore != null ? 'before_after' : 'after_only';

      // Build product tags map from the free-text field (structured later with POS)
      Map<String, dynamic>? productTags;
      final tagsText = _productTagsCtrl.text.trim();
      if (tagsText.isNotEmpty) {
        productTags = {'raw': tagsText};
      }

      // Resolve category: prefer selection, fall back to first fallback
      final category = _selectedServiceCategory ??
          (categories.isNotEmpty
              ? (categories.first['name'] as String? ?? _fallbackCategories.first)
              : _fallbackCategories.first);

      await PortfolioService.uploadPhoto(
        businessId: widget.businessId,
        staffId: _selectedStaffId,
        beforeBytes: correctedBefore,
        afterBytes: correctedAfter,
        photoType: photoType,
        serviceCategory: category,
        caption: _captionCtrl.text.trim().isEmpty ? null : _captionCtrl.text.trim(),
        productTags: productTags,
        appointmentId: widget.appointmentId,
      );

      ToastService.showSuccess('Foto guardada en tu portafolio');
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      ToastService.showError('Error al guardar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final staffAsync = ref.watch(businessStaffProvider);

    // Fetch services for category dropdown
    final servicesAsync = ref.watch(_businessServicesProvider(widget.businessId));

    return Stack(
      children: [
        Scaffold(
          backgroundColor: colors.surface,
          appBar: AppBar(
            backgroundColor: colors.surface,
            elevation: 0,
            centerTitle: false,
            title: Text(
              'Foto Antes / Despues',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: colors.onSurface,
              ),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.onSurface),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: servicesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => _buildBody(context, colors, staffAsync, []),
            data: (categories) => _buildBody(context, colors, staffAsync, categories),
          ),
        ),

        // Tips overlay — rendered on top of everything
        if (_tipsVisible) _TipsOverlay(onDismiss: _dismissTips),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    ColorScheme colors,
    AsyncValue<List<Map<String, dynamic>>> staffAsync,
    List<Map<String, dynamic>> categories,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.paddingMD,
        AppConstants.paddingMD,
        AppConstants.paddingMD,
        120, // space for the save button
      ),
      children: [
        // ---- Before section ----
        _SectionLabel(label: 'FOTO DEL ANTES', colors: colors),
        const SizedBox(height: AppConstants.paddingSM),
        _buildBeforeSection(context, colors),

        const SizedBox(height: AppConstants.paddingLG),

        // ---- After section ----
        _SectionLabel(label: 'FOTO DEL RESULTADO', colors: colors),
        const SizedBox(height: AppConstants.paddingSM),
        _buildAfterSection(context, colors),

        const SizedBox(height: AppConstants.paddingLG),

        // ---- Tagging section ----
        _SectionLabel(label: 'ETIQUETAS', colors: colors),
        const SizedBox(height: AppConstants.paddingSM),
        _buildTaggingSection(context, colors, staffAsync, categories),

        const SizedBox(height: AppConstants.paddingLG),

        // ---- Save button ----
        _buildSaveButton(colors, categories),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Before section
  // ---------------------------------------------------------------------------

  Widget _buildBeforeSection(BuildContext context, ColorScheme colors) {
    return _Card(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿La clienta autoriza la foto del antes?',
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: AppConstants.paddingSM),
          Row(
            children: [
              Expanded(
                child: _AuthButton(
                  label: 'Si',
                  icon: Icons.check_circle_rounded,
                  selected: _clientAuthorized == true,
                  selectedColor: colors.primary,
                  colors: colors,
                  onTap: () => setState(() => _clientAuthorized = true),
                ),
              ),
              const SizedBox(width: AppConstants.paddingSM),
              Expanded(
                child: _AuthButton(
                  label: 'No',
                  icon: Icons.cancel_rounded,
                  selected: _clientAuthorized == false,
                  selectedColor: colors.error,
                  colors: colors,
                  onTap: () => setState(() {
                    _clientAuthorized = false;
                    _beforeShots.clear();
                  }),
                ),
              ),
            ],
          ),

          if (_clientAuthorized == true) ...[
            const SizedBox(height: AppConstants.paddingMD),
            _buildShotCapture(
              context: context,
              colors: colors,
              shots: _beforeShots,
              bestIndex: _bestBeforeIndex,
              selectedIndex: _selectedBeforeIndex,
              isBefore: true,
              onCapture: () => _captureShot(isBefore: true),
              onSelect: (i) => setState(() => _selectedBeforeIndex = i),
              onRemove: _removeBeforeShot,
            ),
          ],

          if (_clientAuthorized == false)
            Padding(
              padding: const EdgeInsets.only(top: AppConstants.paddingMD),
              child: Text(
                'Se omitira la foto del antes.',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: colors.onSurface.withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // After section
  // ---------------------------------------------------------------------------

  Widget _buildAfterSection(BuildContext context, ColorScheme colors) {
    return _Card(
      colors: colors,
      child: _buildShotCapture(
        context: context,
        colors: colors,
        shots: _afterShots,
        bestIndex: _bestAfterIndex,
        selectedIndex: _selectedAfterIndex,
        isBefore: false,
        onCapture: () => _captureShot(isBefore: false),
        onSelect: (i) => setState(() => _selectedAfterIndex = i),
        onRemove: _removeAfterShot,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared shot-capture widget
  // ---------------------------------------------------------------------------

  Widget _buildShotCapture({
    required BuildContext context,
    required ColorScheme colors,
    required List<Uint8List> shots,
    required int bestIndex,
    required int selectedIndex,
    required bool isBefore,
    required VoidCallback onCapture,
    required ValueChanged<int> onSelect,
    required ValueChanged<int> onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Large preview of selected shot (or placeholder)
        AspectRatio(
          aspectRatio: 3 / 4,
          child: shots.isEmpty
              ? _CameraPlaceholder(colors: colors)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                  child: Image.memory(
                    shots[selectedIndex.clamp(0, shots.length - 1)],
                    fit: BoxFit.cover,
                  ),
                ),
        ),

        const SizedBox(height: AppConstants.paddingSM),

        // Thumbnails row (only when there are shots)
        if (shots.isNotEmpty)
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: shots.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: AppConstants.paddingXS),
              itemBuilder: (context, i) {
                final isSelected = i == selectedIndex;
                final isBest = i == bestIndex && shots.length > 1;
                return GestureDetector(
                  onTap: () => onSelect(i),
                  onLongPress: () => _confirmRemoveShot(context, i, onRemove),
                  child: Stack(
                    children: [
                      AnimatedContainer(
                        duration: AppConstants.shortAnimation,
                        width: 60,
                        height: 72,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                          border: Border.all(
                            color: isSelected
                                ? colors.primary
                                : colors.onSurface.withValues(alpha: 0.15),
                            width: isSelected ? 2.5 : 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppConstants.radiusSM - 1),
                          child: Image.memory(shots[i], fit: BoxFit.cover),
                        ),
                      ),
                      if (isBest)
                        Positioned(
                          top: 3,
                          right: 3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 3, vertical: 1),
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius:
                                  BorderRadius.circular(AppConstants.radiusXS),
                            ),
                            child: Text(
                              'mejor',
                              style: GoogleFonts.nunito(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: colors.onPrimary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

        if (shots.isNotEmpty)
          const SizedBox(height: AppConstants.paddingSM),

        // Capture button
        SizedBox(
          width: double.infinity,
          height: AppConstants.comfortableTouchHeight,
          child: OutlinedButton.icon(
            onPressed: onCapture,
            icon: Icon(Icons.camera_alt_rounded, size: AppConstants.iconSizeSM),
            label: Text(
              shots.isEmpty ? 'Tomar foto' : 'Tomar otra',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              ),
            ),
          ),
        ),

        if (shots.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: AppConstants.paddingXS),
            child: Text(
              'Mantén presionada una miniatura para eliminarla.',
              style: GoogleFonts.nunito(
                fontSize: 11,
                color: colors.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _confirmRemoveShot(
    BuildContext context,
    int index,
    ValueChanged<int> onRemove,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Eliminar foto',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('¿Quieres eliminar esta foto?',
            style: GoogleFonts.nunito()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Eliminar',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) onRemove(index);
  }

  // ---------------------------------------------------------------------------
  // Tagging section
  // ---------------------------------------------------------------------------

  Widget _buildTaggingSection(
    BuildContext context,
    ColorScheme colors,
    AsyncValue<List<Map<String, dynamic>>> staffAsync,
    List<Map<String, dynamic>> categories,
  ) {
    final gray = colors.onSurface.withValues(alpha: 0.12);

    // Build category name list
    final categoryNames = categories.isNotEmpty
        ? categories
            .map((c) => c['name'] as String? ?? '')
            .where((s) => s.isNotEmpty)
            .toList()
        : _fallbackCategories;

    // Build staff list
    final staffList = staffAsync.valueOrNull ?? [];

    return _Card(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Service category dropdown
          DropdownButtonFormField<String>(
            initialValue: _selectedServiceCategory,
            hint: Text('Categoria de servicio',
                style: GoogleFonts.nunito(
                    color: colors.onSurface.withValues(alpha: 0.5))),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                borderSide: BorderSide(color: gray, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                borderSide: BorderSide(color: colors.primary, width: 1.5),
              ),
            ),
            items: categoryNames
                .map((name) => DropdownMenuItem(
                      value: name,
                      child: Text(name, style: GoogleFonts.nunito()),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _selectedServiceCategory = v),
          ),

          const SizedBox(height: AppConstants.paddingSM),

          // Staff dropdown
          if (staffList.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: _selectedStaffId,
              hint: Text('Estilista (opcional)',
                  style: GoogleFonts.nunito(
                      color: colors.onSurface.withValues(alpha: 0.5))),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                  borderSide: BorderSide(color: gray, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                  borderSide: BorderSide(color: colors.primary, width: 1.5),
                ),
              ),
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text('Sin asignar', style: GoogleFonts.nunito()),
                ),
                ...staffList.map((s) {
                  final name = s['display_name'] as String? ??
                      s['name'] as String? ??
                      'Estilista';
                  return DropdownMenuItem(
                    value: s['id'] as String,
                    child: Text(name, style: GoogleFonts.nunito()),
                  );
                }),
              ],
              onChanged: (v) => setState(() => _selectedStaffId = v),
            ),

          if (staffList.isNotEmpty) const SizedBox(height: AppConstants.paddingSM),

          // Caption field
          TextField(
            controller: _captionCtrl,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            style: GoogleFonts.nunito(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Descripcion del trabajo (opcional)',
              hintStyle: GoogleFonts.nunito(
                  color: colors.onSurface.withValues(alpha: 0.45)),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                borderSide: BorderSide(color: gray, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                borderSide: BorderSide(color: colors.primary, width: 1.5),
              ),
            ),
          ),

          const SizedBox(height: AppConstants.paddingSM),

          // Product tags field
          TextField(
            controller: _productTagsCtrl,
            textCapitalization: TextCapitalization.sentences,
            style: GoogleFonts.nunito(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Productos usados (opcional)',
              hintStyle: GoogleFonts.nunito(
                  color: colors.onSurface.withValues(alpha: 0.45)),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                borderSide: BorderSide(color: gray, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                borderSide: BorderSide(color: colors.primary, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Save button
  // ---------------------------------------------------------------------------

  Widget _buildSaveButton(
      ColorScheme colors, List<Map<String, dynamic>> categories) {
    final canSave = _afterShots.isNotEmpty && !_saving;
    return SizedBox(
      width: double.infinity,
      height: AppConstants.largeTouchHeight,
      child: FilledButton(
        onPressed: canSave ? () => _save(categories) : null,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          ),
        ),
        child: _saving
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: colors.onPrimary,
                ),
              )
            : Text(
                'Guardar en portafolio',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Provider: business services for category list
// ---------------------------------------------------------------------------

final _businessServicesProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, businessId) async {
    final response = await SupabaseClientService.client
        .from('services')
        .select('id, name')
        .eq('business_id', businessId)
        .order('name');
    return (response as List).cast<Map<String, dynamic>>();
  },
);

// ---------------------------------------------------------------------------
// Tips overlay
// ---------------------------------------------------------------------------

class _TipsOverlay extends StatelessWidget {
  final VoidCallback onDismiss;

  const _TipsOverlay({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.6),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingLG,
            ),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppConstants.radiusLG),
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.paddingLG),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.tips_and_updates_rounded,
                      size: 48,
                      color: colors.primary,
                    ),
                    const SizedBox(height: AppConstants.paddingSM),
                    Text(
                      'Para mejores resultados:',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppConstants.paddingMD),
                    _TipRow(
                      icon: Icons.spa_rounded,
                      text:
                          'Usa un fondo limpio (floral, blanco, color solido)',
                    ),
                    const SizedBox(height: AppConstants.paddingMD),
                    _TipRow(
                      icon: Icons.location_on_rounded,
                      text:
                          'Marca un punto en el piso donde se pare la clienta',
                    ),
                    const SizedBox(height: AppConstants.paddingMD),
                    _TipRow(
                      icon: Icons.wb_sunny_rounded,
                      text: 'Buena iluminacion hace la diferencia',
                    ),
                    const SizedBox(height: AppConstants.paddingLG),
                    SizedBox(
                      width: double.infinity,
                      height: AppConstants.comfortableTouchHeight,
                      child: FilledButton(
                        onPressed: onDismiss,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppConstants.radiusMD),
                          ),
                        ),
                        child: Text(
                          'Entendido',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TipRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: colors.primary),
        const SizedBox(width: AppConstants.paddingSM),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: colors.onSurface.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Small private widgets
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String label;
  final ColorScheme colors;

  const _SectionLabel({required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: colors.onSurface.withValues(alpha: 0.45),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final ColorScheme colors;

  const _Card({required this.child, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(
          color: colors.onSurface.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _AuthButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color selectedColor;
  final ColorScheme colors;
  final VoidCallback onTap;

  const _AuthButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.selectedColor,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppConstants.shortAnimation,
        height: AppConstants.comfortableTouchHeight,
        decoration: BoxDecoration(
          color: selected
              ? selectedColor.withValues(alpha: 0.1)
              : colors.onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          border: Border.all(
            color: selected
                ? selectedColor
                : colors.onSurface.withValues(alpha: 0.15),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: AppConstants.iconSizeSM,
                color: selected ? selectedColor : colors.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: selected ? selectedColor : colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraPlaceholder extends StatelessWidget {
  final ColorScheme colors;

  const _CameraPlaceholder({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(
          color: colors.onSurface.withValues(alpha: 0.1),
          width: 1,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_a_photo_rounded,
            size: 48,
            color: colors.onSurface.withValues(alpha: 0.25),
          ),
          const SizedBox(height: AppConstants.paddingSM),
          Text(
            'Sin foto',
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: colors.onSurface.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}
