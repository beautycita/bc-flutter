import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:beautycita_core/beautycita_core.dart';
import 'package:beautycita/services/supabase_client.dart';
import '../../config/constants.dart';
import '../../providers/business_provider.dart';
import '../../providers/portfolio_provider.dart';
import '../../services/portfolio_service.dart';
import '../../services/toast_service.dart';

// ---------------------------------------------------------------------------
// Theme definitions
// ---------------------------------------------------------------------------

class _PortfolioThemeDef {
  final String key;
  final String name;
  final String description;

  const _PortfolioThemeDef({
    required this.key,
    required this.name,
    required this.description,
  });
}

const _themes = <_PortfolioThemeDef>[
  _PortfolioThemeDef(
    key: 'portfolio',
    name: 'Portfolio',
    description: 'Clasico y elegante',
  ),
  _PortfolioThemeDef(
    key: 'team_builder',
    name: 'Team Builder',
    description: 'Destaca a tu equipo',
  ),
  _PortfolioThemeDef(
    key: 'storefront',
    name: 'Storefront',
    description: 'Estilo tienda online',
  ),
  _PortfolioThemeDef(
    key: 'gallery',
    name: 'Gallery',
    description: 'Galeria minimalista',
  ),
  _PortfolioThemeDef(
    key: 'local',
    name: 'Local',
    description: 'Negocio de barrio',
  ),
];

const _kAgreementVersion = '1.0';
const _kAgreementType = 'portfolio';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class PortfolioManagementScreen extends ConsumerStatefulWidget {
  const PortfolioManagementScreen({super.key});

  @override
  ConsumerState<PortfolioManagementScreen> createState() =>
      _PortfolioManagementScreenState();
}

class _PortfolioManagementScreenState
    extends ConsumerState<PortfolioManagementScreen> {
  // Settings controllers
  final _slugCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();

  bool _isPublic = false;
  String _selectedTheme = 'portfolio';
  bool _hiringSlot = false;
  bool _settingsInitialized = false;
  bool _savingSettings = false;

  // Photo filter: null = all, staffId = filter by that staff member
  String? _photoFilter;

  // Staff bio state keyed by staffId
  final Map<String, TextEditingController> _bioCtrls = {};
  final Map<String, List<String>> _specialties = {};
  final Map<String, bool> _savingBio = {};

  @override
  void dispose() {
    _slugCtrl.dispose();
    _bioCtrl.dispose();
    _taglineCtrl.dispose();
    for (final c in _bioCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _initFromConfig(PortfolioConfig config) {
    if (_settingsInitialized) return;
    _settingsInitialized = true;
    _isPublic = config.isPublic;
    _selectedTheme = config.theme;
    _slugCtrl.text = config.slug ?? '';
    _bioCtrl.text = config.bio ?? '';
    _taglineCtrl.text = config.tagline ?? '';
  }

  void _initStaffBio(Map<String, dynamic> staff) {
    final id = staff['id'] as String;
    if (_bioCtrls.containsKey(id)) return;
    _bioCtrls[id] = TextEditingController(
      text: staff['bio'] as String? ?? '',
    );
    final raw = staff['specialties'];
    _specialties[id] = raw is List
        ? raw.map((e) => e.toString()).toList()
        : [];
  }

  // -------------------------------------------------------------------------
  // Agreement dialog
  // -------------------------------------------------------------------------

  Future<bool> _showAgreementDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            final colors = Theme.of(ctx).colorScheme;
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              ),
              title: Text(
                'Acuerdo de Portafolio Publico',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              content: SingleChildScrollView(
                child: Text(
                  'Al hacer tu portafolio publico, aceptas que las fotos y la '
                  'informacion de tu negocio seran visibles para todos los '
                  'usuarios de BeautyCita.\n\n'
                  'Tu eres responsable de que el contenido que publiques sea '
                  'tuyo o cuentes con los derechos necesarios para publicarlo.\n\n'
                  'BeautyCita puede usar las fotos de tu portafolio para '
                  'promover tu negocio dentro de la plataforma.',
                  style: GoogleFonts.nunito(fontSize: 14, height: 1.5),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(
                    'Cancelar',
                    style: GoogleFonts.poppins(
                      color: colors.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(
                    'Acepto',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  // -------------------------------------------------------------------------
  // Toggle public with agreement check
  // -------------------------------------------------------------------------

  Future<void> _handlePublicToggle(bool value, String bizId) async {
    if (!value) {
      setState(() => _isPublic = false);
      return;
    }

    bool hasAccepted = false;
    try {
      hasAccepted = await ref.read(
        portfolioAgreementProvider(
            (businessId: bizId, version: _kAgreementVersion)).future,
      );
    } catch (_) {
      hasAccepted = false;
    }

    if (!mounted) return;

    if (!hasAccepted) {
      final accepted = await _showAgreementDialog();
      if (!mounted) return;
      if (!accepted) return;

      try {
        await PortfolioService.acceptAgreement(
            bizId, _kAgreementType, _kAgreementVersion);
        ref.invalidate(portfolioAgreementProvider);
      } catch (e, s) {
        ToastService.showErrorWithDetails(
            ToastService.friendlyError(e), e, s);
        return;
      }
    }

    setState(() => _isPublic = true);
  }

  // -------------------------------------------------------------------------
  // Save settings
  // -------------------------------------------------------------------------

  Future<void> _saveSettings(String bizId) async {
    setState(() => _savingSettings = true);
    try {
      final config = PortfolioConfig(
        slug: _slugCtrl.text.trim().isEmpty ? null : _slugCtrl.text.trim(),
        isPublic: _isPublic,
        theme: _selectedTheme,
        bio: _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
        tagline: _taglineCtrl.text.trim().isEmpty
            ? null
            : _taglineCtrl.text.trim(),
      );
      await PortfolioService.updateConfig(bizId, config);

      await SupabaseClientService.client
          .from('businesses')
          .update({'show_hiring_slot': _hiringSlot}).eq('id', bizId);

      ref.invalidate(portfolioConfigProvider);
      ref.invalidate(currentBusinessProvider);
      ToastService.showSuccess('Configuracion guardada');
    } catch (e, s) {
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, s);
    } finally {
      if (mounted) setState(() => _savingSettings = false);
    }
  }

  // -------------------------------------------------------------------------
  // Photo operations
  // -------------------------------------------------------------------------

  Future<void> _addPhotos(String bizId) async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 90);
    if (picked.isEmpty) return;
    if (!mounted) return;

    int uploaded = 0;
    for (final xfile in picked) {
      try {
        final bytes = await xfile.readAsBytes();
        final corrected = await PortfolioService.autoCorrectImage(bytes);
        await PortfolioService.uploadPhoto(
          businessId: bizId,
          afterBytes: corrected,
          photoType: 'after_only',
        );
        uploaded++;
      } catch (e, s) {
        ToastService.showErrorWithDetails(
            ToastService.friendlyError(e), e, s);
      }
    }

    if (uploaded > 0) {
      ref.invalidate(portfolioPhotosProvider);
      ToastService.showSuccess(
          '$uploaded foto${uploaded > 1 ? 's' : ''} agregada${uploaded > 1 ? 's' : ''}');
    }
  }

  Future<void> _deletePhoto(String photoId, String bizId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        ),
        title: Text('Eliminar foto',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('Esta accion no se puede deshacer.',
            style: GoogleFonts.nunito(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await PortfolioService.deletePhoto(photoId);
      ref.invalidate(portfolioPhotosProvider);
      ToastService.showSuccess('Foto eliminada');
    } catch (e, s) {
      ToastService.showErrorWithDetails(
          ToastService.friendlyError(e), e, s);
    }
  }

  Future<void> _toggleVisibility(PortfolioPhoto photo) async {
    try {
      await PortfolioService.updatePhoto(
        photo.id,
        isVisible: !photo.isVisible,
      );
      ref.invalidate(portfolioPhotosProvider);
    } catch (e, s) {
      ToastService.showErrorWithDetails(
          ToastService.friendlyError(e), e, s);
    }
  }

  Future<void> _reorder(
    List<PortfolioPhoto> photos,
    int oldIndex,
    int newIndex,
    String bizId,
  ) async {
    if (newIndex > oldIndex) newIndex--;
    final reordered = [...photos];
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);
    try {
      await PortfolioService.reorderPhotos(
        bizId,
        reordered.map((p) => p.id).toList(),
      );
      ref.invalidate(portfolioPhotosProvider);
    } catch (e, s) {
      ToastService.showErrorWithDetails(
          ToastService.friendlyError(e), e, s);
    }
  }

  void _openCaptionSheet(PortfolioPhoto photo) {
    final captionCtrl = TextEditingController(text: photo.caption ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusLG),
        ),
      ),
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppConstants.paddingMD,
            AppConstants.paddingMD,
            AppConstants.paddingMD,
            MediaQuery.of(ctx).viewInsets.bottom + AppConstants.paddingLG,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.paddingMD),
              Text(
                'Editar Foto',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppConstants.paddingMD),
              TextFormField(
                controller: captionCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Descripcion',
                  labelStyle: GoogleFonts.nunito(),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusMD),
                    borderSide: BorderSide(
                        color: colors.onSurface.withValues(alpha: 0.12)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusMD),
                    borderSide:
                        BorderSide(color: colors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.paddingMD),
              SizedBox(
                width: double.infinity,
                height: AppConstants.minTouchHeight,
                child: FilledButton(
                  onPressed: () async {
                    try {
                      await PortfolioService.updatePhoto(
                        photo.id,
                        caption: captionCtrl.text.trim(),
                      );
                      ref.invalidate(portfolioPhotosProvider);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      ToastService.showSuccess('Foto actualizada');
                    } catch (e, s) {
                      ToastService.showErrorWithDetails(
                          ToastService.friendlyError(e), e, s);
                    }
                  },
                  child: Text(
                    'Guardar',
                    style:
                        GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // Save staff bio
  // -------------------------------------------------------------------------

  Future<void> _saveStaffBio(String staffId) async {
    setState(() => _savingBio[staffId] = true);
    try {
      await SupabaseClientService.client.from('staff').update({
        'bio': _bioCtrls[staffId]?.text.trim(),
        'specialties': _specialties[staffId] ?? [],
      }).eq('id', staffId);

      ref.invalidate(businessStaffProvider);
      ToastService.showSuccess('Bio guardada');
    } catch (e, s) {
      ToastService.showErrorWithDetails(
          ToastService.friendlyError(e), e, s);
    } finally {
      if (mounted) setState(() => _savingBio[staffId] = false);
    }
  }

  void _addSpecialty(String staffId) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        ),
        title: Text('Agregar especialidad',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Ej: Corte bob, Balayage...',
            hintStyle: GoogleFonts.nunito(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) {
                setState(() {
                  _specialties[staffId] = [
                    ...(_specialties[staffId] ?? []),
                    val,
                  ];
                });
              }
              Navigator.of(ctx).pop();
            },
            child: Text(
              'Agregar',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Styling helpers
  // -------------------------------------------------------------------------

  BoxDecoration _cardDecoration(ColorScheme colors) {
    return BoxDecoration(
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
    );
  }

  InputDecoration _styledInput(String label) {
    final colors = Theme.of(context).colorScheme;
    final gray = colors.onSurface.withValues(alpha: 0.12);
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        borderSide: BorderSide(color: gray, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bizAsync = ref.watch(currentBusinessProvider);
    final configAsync = ref.watch(portfolioConfigProvider);
    final staffAsync = ref.watch(businessStaffProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(AppConstants.radiusMD),
          ),
        ),
        title: Text(
          'Portafolio',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: const Color(0xFF000000),
          ),
        ),
        iconTheme: IconThemeData(color: colors.primary),
      ),
      body: bizAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: GoogleFonts.nunito(color: colors.error)),
        ),
        data: (biz) {
          if (biz == null) {
            return Center(
              child: Text('Sin negocio',
                  style: GoogleFonts.nunito(color: colors.error)),
            );
          }

          final bizId = biz['id'] as String;

          // Read hiring slot without overwriting during rebuilds if user toggled it
          if (!_settingsInitialized) {
            _hiringSlot = biz['show_hiring_slot'] as bool? ?? false;
          }

          return configAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text('Error: $e',
                  style: GoogleFonts.nunito(color: colors.error)),
            ),
            data: (config) {
              if (config != null) _initFromConfig(config);

              final photosAsync =
                  ref.watch(portfolioPhotosProvider(bizId));

              return ListView(
                padding:
                    const EdgeInsets.all(AppConstants.paddingMD),
                children: [
                  // ====================================================
                  // 1. PORTFOLIO SETTINGS CARD
                  // ====================================================
                  _SectionHeader(label: 'CONFIGURACION DEL PORTAFOLIO'),
                  const SizedBox(height: AppConstants.paddingSM),
                  Container(
                    decoration: _cardDecoration(colors),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Public toggle
                        SwitchListTile(
                          title: Text(
                            'Portafolio publico',
                            style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            _slugCtrl.text.isNotEmpty
                                ? 'Visible en beautycita.com/s/${_slugCtrl.text}'
                                : 'Configura una URL para compartir',
                            style: GoogleFonts.nunito(fontSize: 12),
                          ),
                          value: _isPublic,
                          onChanged: (v) =>
                              _handlePublicToggle(v, bizId),
                          activeTrackColor: colors.primary,
                        ),
                        const Divider(height: 1),

                        // Theme picker label
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'Tema del portafolio',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ),

                        // Horizontal theme cards
                        SizedBox(
                          height: 80,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppConstants.paddingMD),
                            itemCount: _themes.length,
                            separatorBuilder: (context2, idx) =>
                                const SizedBox(width: 8),
                            itemBuilder: (ctx, i) {
                              final theme = _themes[i];
                              final isSelected =
                                  _selectedTheme == theme.key;
                              return GestureDetector(
                                onTap: () => setState(
                                    () => _selectedTheme = theme.key),
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? colors.primary
                                        : colors.primary
                                            .withValues(alpha: 0.06),
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? colors.primary
                                          : colors.primary
                                              .withValues(alpha: 0.2),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        theme.name,
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected
                                              ? Colors.white
                                              : colors.primary,
                                        ),
                                      ),
                                      Text(
                                        theme.description,
                                        style: GoogleFonts.nunito(
                                          fontSize: 11,
                                          color: isSelected
                                              ? Colors.white
                                                  .withValues(alpha: 0.85)
                                              : colors.onSurface
                                                  .withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: AppConstants.paddingMD),
                        const Divider(height: 1),

                        // Slug field
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.only(right: 4),
                                child: Text(
                                  'beautycita.com/s/',
                                  style: GoogleFonts.nunito(
                                    fontSize: 13,
                                    color: colors.onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _slugCtrl,
                                  decoration:
                                      _styledInput('URL personalizada'),
                                  style:
                                      GoogleFonts.poppins(fontSize: 14),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppConstants.paddingSM),

                        // Tagline
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            controller: _taglineCtrl,
                            decoration: _styledInput('Eslogan'),
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: AppConstants.paddingSM),

                        // Bio
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            controller: _bioCtrl,
                            maxLines: 4,
                            decoration:
                                _styledInput('Bio del negocio'),
                            style: GoogleFonts.nunito(fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: AppConstants.paddingMD),

                        // Hiring slot toggle
                        const Divider(height: 1),
                        SwitchListTile(
                          title: Text(
                            'Mostrar "Estamos buscando..."',
                            style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            'Muestra una tarjeta de vacante en tu portafolio',
                            style: GoogleFonts.nunito(fontSize: 12),
                          ),
                          value: _hiringSlot,
                          onChanged: (v) =>
                              setState(() => _hiringSlot = v),
                          activeTrackColor: colors.primary,
                        ),

                        // Save
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(
                              AppConstants.paddingMD),
                          child: SizedBox(
                            width: double.infinity,
                            height: AppConstants.minTouchHeight,
                            child: FilledButton(
                              onPressed: _savingSettings
                                  ? null
                                  : () => _saveSettings(bizId),
                              child: _savingSettings
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : Text(
                                      'Guardar Configuracion',
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ====================================================
                  // 2. PHOTO GRID CARD
                  // ====================================================
                  const SizedBox(height: AppConstants.paddingLG),
                  _SectionHeader(label: 'FOTOS DEL PORTAFOLIO'),
                  const SizedBox(height: AppConstants.paddingSM),
                  Container(
                    decoration: _cardDecoration(colors),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 14, 8, 0),
                          child: Row(
                            children: [
                              Text(
                                'Fotos',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () => _addPhotos(bizId),
                                icon: Icon(
                                    Icons.add_photo_alternate_rounded,
                                    size: 18,
                                    color: colors.primary),
                                label: Text(
                                  'Agregar',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: colors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Staff filter chips
                        staffAsync.when(
                          data: (staffList) {
                            if (staffList.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(
                                  top: AppConstants.paddingSM),
                              child: SizedBox(
                                height: 36,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal:
                                          AppConstants.paddingMD),
                                  children: [
                                    _FilterChip(
                                      label: 'Todos',
                                      selected: _photoFilter == null,
                                      onTap: () => setState(
                                          () => _photoFilter = null),
                                      colors: colors,
                                    ),
                                    for (final s in staffList) ...[
                                      const SizedBox(width: 6),
                                      _FilterChip(
                                        label:
                                            '${s['first_name'] ?? ''} ${s['last_name'] ?? ''}'
                                                .trim(),
                                        selected: _photoFilter ==
                                            (s['id'] as String),
                                        onTap: () => setState(
                                          () => _photoFilter =
                                              s['id'] as String,
                                        ),
                                        colors: colors,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                          loading: () => const SizedBox(height: 36),
                          error: (err, st) => const SizedBox.shrink(),
                        ),

                        const SizedBox(height: AppConstants.paddingSM),

                        // Photo grid
                        photosAsync.when(
                          loading: () => const Padding(
                            padding:
                                EdgeInsets.all(AppConstants.paddingXL),
                            child: Center(
                                child: CircularProgressIndicator()),
                          ),
                          error: (e, _) => Padding(
                            padding: const EdgeInsets.all(
                                AppConstants.paddingMD),
                            child: Text('Error: $e',
                                style: GoogleFonts.nunito(
                                    color: colors.error)),
                          ),
                          data: (allPhotos) {
                            final photos = _photoFilter == null
                                ? allPhotos
                                : allPhotos
                                    .where((p) =>
                                        p.staffId == _photoFilter)
                                    .toList();

                            if (photos.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.all(
                                    AppConstants.paddingXL),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.photo_library_outlined,
                                        size: 48,
                                        color: colors.onSurface
                                            .withValues(alpha: 0.25),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Sin fotos. Toca Agregar para subir.',
                                        style: GoogleFonts.nunito(
                                          color: colors.onSurface
                                              .withValues(alpha: 0.4),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            // Build 2-column rows as a reorderable list
                            // where each row = one reorderable item.
                            // Reorder is by pair-row; within a row the
                            // user can long-press the drag handle.
                            final rowCount =
                                (photos.length / 2).ceil();

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppConstants.paddingSM),
                              child: ReorderableListView.builder(
                                shrinkWrap: true,
                                physics:
                                    const NeverScrollableScrollPhysics(),
                                buildDefaultDragHandles: false,
                                onReorder: (oldIndex, newIndex) =>
                                    _reorder(photos, oldIndex * 2,
                                        newIndex * 2, bizId),
                                itemCount: rowCount,
                                itemBuilder: (ctx, rowIndex) {
                                  final leftIdx = rowIndex * 2;
                                  final rightIdx = leftIdx + 1;
                                  return Padding(
                                    key: ValueKey(
                                        photos[leftIdx].id),
                                    padding: const EdgeInsets.only(
                                        bottom:
                                            AppConstants.paddingSM),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: _PhotoTile(
                                            photo: photos[leftIdx],
                                            dragIndex: rowIndex,
                                            onDelete: () => _deletePhoto(
                                                photos[leftIdx].id,
                                                bizId),
                                            onToggleVisibility: () =>
                                                _toggleVisibility(
                                                    photos[leftIdx]),
                                            onTap: () =>
                                                _openCaptionSheet(
                                                    photos[leftIdx]),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (rightIdx < photos.length)
                                          Expanded(
                                            child: _PhotoTile(
                                              photo: photos[rightIdx],
                                              dragIndex: rowIndex,
                                              onDelete: () =>
                                                  _deletePhoto(
                                                      photos[rightIdx]
                                                          .id,
                                                      bizId),
                                              onToggleVisibility: () =>
                                                  _toggleVisibility(
                                                      photos[rightIdx]),
                                              onTap: () =>
                                                  _openCaptionSheet(
                                                      photos[rightIdx]),
                                            ),
                                          )
                                        else
                                          const Expanded(
                                              child: SizedBox.shrink()),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: AppConstants.paddingSM),
                      ],
                    ),
                  ),

                  // ====================================================
                  // 3. TEAM BIOS CARD
                  // ====================================================
                  const SizedBox(height: AppConstants.paddingLG),
                  _SectionHeader(label: 'BIOS DEL EQUIPO'),
                  const SizedBox(height: AppConstants.paddingSM),
                  staffAsync.when(
                    loading: () => const Center(
                        child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error: $e',
                        style:
                            GoogleFonts.nunito(color: colors.error)),
                    data: (staffList) {
                      if (staffList.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(
                              AppConstants.paddingLG),
                          decoration: _cardDecoration(colors),
                          child: Center(
                            child: Text(
                              'Sin personal registrado',
                              style: GoogleFonts.nunito(
                                color: colors.onSurface
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        );
                      }

                      for (final s in staffList) {
                        _initStaffBio(s);
                      }

                      return Column(
                        children: [
                          for (final staff in staffList)
                            _StaffBioCard(
                              staff: staff,
                              bioCtrl: _bioCtrls[
                                  staff['id'] as String]!,
                              specialties: _specialties[
                                      staff['id'] as String] ??
                                  [],
                              isSaving: _savingBio[
                                      staff['id'] as String] ??
                                  false,
                              cardDecoration: _cardDecoration(colors),
                              styledInput: _styledInput,
                              colors: colors,
                              onSave: () => _saveStaffBio(
                                  staff['id'] as String),
                              onAddSpecialty: () => _addSpecialty(
                                  staff['id'] as String),
                              onRemoveSpecialty: (sp) => setState(() {
                                _specialties[staff['id'] as String]
                                    ?.remove(sp);
                              }),
                            ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: AppConstants.paddingXL),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header (mirrors business_settings_screen.dart)
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppConstants.paddingSM),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: colors.onSurface.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter chip
// ---------------------------------------------------------------------------

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme colors;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary
              : colors.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? colors.primary
                : colors.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : colors.primary,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Photo tile
// ---------------------------------------------------------------------------

class _PhotoTile extends StatelessWidget {
  final PortfolioPhoto photo;
  final int dragIndex;
  final VoidCallback onDelete;
  final VoidCallback onToggleVisibility;
  final VoidCallback onTap;

  const _PhotoTile({
    required this.photo,
    required this.dragIndex,
    required this.onDelete,
    required this.onToggleVisibility,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Thumbnail
            AspectRatio(
              aspectRatio: 1,
              child: Image.network(
                photo.afterUrl,
                fit: BoxFit.cover,
                errorBuilder: (ctx2, err, st) => Container(
                  color: colors.primary.withValues(alpha: 0.08),
                  child: Icon(
                    Icons.broken_image_rounded,
                    color: colors.primary.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),

            // Before/after badge
            if (photo.beforeUrl != null)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Antes/Despues',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

            // Drag handle (top-right)
            Positioned(
              top: 6,
              right: 6,
              child: ReorderableDragStartListener(
                index: dragIndex,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.drag_handle_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // Visibility toggle (bottom-left)
            Positioned(
              bottom: 6,
              left: 6,
              child: GestureDetector(
                onTap: onToggleVisibility,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    photo.isVisible
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    size: 14,
                    color: photo.isVisible
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),

            // Delete button (bottom-right)
            Positioned(
              bottom: 6,
              right: 6,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Staff bio card
// ---------------------------------------------------------------------------

class _StaffBioCard extends StatelessWidget {
  final Map<String, dynamic> staff;
  final TextEditingController bioCtrl;
  final List<String> specialties;
  final bool isSaving;
  final BoxDecoration cardDecoration;
  final InputDecoration Function(String) styledInput;
  final ColorScheme colors;
  final VoidCallback onSave;
  final VoidCallback onAddSpecialty;
  final ValueChanged<String> onRemoveSpecialty;

  const _StaffBioCard({
    required this.staff,
    required this.bioCtrl,
    required this.specialties,
    required this.isSaving,
    required this.cardDecoration,
    required this.styledInput,
    required this.colors,
    required this.onSave,
    required this.onAddSpecialty,
    required this.onRemoveSpecialty,
  });

  @override
  Widget build(BuildContext context) {
    final name =
        '${staff['first_name'] ?? ''} ${staff['last_name'] ?? ''}'.trim();
    final avatarUrl = staff['avatar_url'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.paddingSM),
      decoration: cardDecoration,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar + name row
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor:
                      colors.primary.withValues(alpha: 0.12),
                  backgroundImage: avatarUrl != null
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null
                      ? Text(
                          name.isNotEmpty
                              ? name[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.primary,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: AppConstants.paddingSM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isNotEmpty ? name : 'Sin nombre',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (staff['role'] != null)
                        Text(
                          staff['role'] as String,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: colors.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingMD),

            // Bio field
            TextFormField(
              controller: bioCtrl,
              maxLines: 3,
              decoration: styledInput('Bio'),
              style: GoogleFonts.nunito(fontSize: 14),
            ),
            const SizedBox(height: AppConstants.paddingSM),

            // Specialties header
            Row(
              children: [
                Text(
                  'Especialidades',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onAddSpecialty,
                  child: Icon(
                    Icons.add_circle_outline_rounded,
                    size: 20,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Specialty chips
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final sp in specialties)
                  Chip(
                    label: Text(sp,
                        style: GoogleFonts.nunito(fontSize: 12)),
                    deleteIcon:
                        const Icon(Icons.close_rounded, size: 14),
                    onDeleted: () => onRemoveSpecialty(sp),
                    backgroundColor:
                        colors.primary.withValues(alpha: 0.08),
                    side: BorderSide(
                        color:
                            colors.primary.withValues(alpha: 0.2)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4),
                    labelPadding:
                        const EdgeInsets.symmetric(horizontal: 4),
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                  ),
                if (specialties.isEmpty)
                  Text(
                    'Sin especialidades',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color:
                          colors.onSurface.withValues(alpha: 0.35),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingMD),

            // Save button
            SizedBox(
              width: double.infinity,
              height: AppConstants.minTouchHeight,
              child: FilledButton(
                onPressed: isSaving ? null : onSave,
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Guardar Bio',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
