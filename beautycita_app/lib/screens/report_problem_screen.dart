import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/constants.dart';
import '../config/theme_extension.dart';
import '../services/toast_service.dart';

// ── Problem categories ──

const _kCategories = [
  'Acoso o intimidacion',
  'Fraude o estafa',
  'Comportamiento inapropiado',
  'Perfil falso',
  'Spam o contenido enganoso',
  'Preocupacion de seguridad',
  'Problema de pago',
  'Error en la aplicacion',
  'Otra violacion',
];

// ── Screen ──

class ReportProblemScreen extends ConsumerStatefulWidget {
  const ReportProblemScreen({super.key});

  @override
  ConsumerState<ReportProblemScreen> createState() =>
      _ReportProblemScreenState();
}

class _ReportProblemScreenState extends ConsumerState<ReportProblemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _involvedController = TextEditingController();
  final _dateController = TextEditingController();

  String? _selectedCategory;
  bool _submitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _involvedController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final client = Supabase.instance.client;
      final description = _descriptionController.text.trim();
      final involved = _involvedController.text.trim();
      final date = _dateController.text.trim();

      await client.from('contact_submissions').insert({
        'user_id': client.auth.currentUser?.id,
        'category': _selectedCategory,
        'description': description,
        if (involved.isNotEmpty) 'involved_user': involved,
        if (date.isNotEmpty) 'incident_date': date,
        'metadata': {
          'app_version': AppConstants.version,
          'platform': Theme.of(context).platform.name,
        },
      });

      // Best-effort admin push notification
      try {
        await client.functions.invoke('send-push-notification', body: {
          'user_id': 'admin',
          'title': 'Nuevo reporte',
          'body':
              '[$_selectedCategory] ${description.length > 50 ? description.substring(0, 50) : description}...',
        });
      } catch (_) {}

      if (!mounted) return;
      ToastService.showSuccess('Reporte enviado. Lo revisaremos pronto.');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ToastService.showError('Error al enviar el reporte. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Reportar un problema',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
      ),
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeroHeader(gradient: ext.primaryGradient),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.screenPaddingHorizontal,
                vertical: AppConstants.paddingLG,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Category dropdown ──
                    _SectionLabel(
                      label: 'Tipo de problema',
                      required: true,
                    ),
                    const SizedBox(height: AppConstants.paddingSM),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: _inputDecoration(
                        context: context,
                        hintText: 'Selecciona una categoria',
                      ),
                      isExpanded: true,
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        color: colorScheme.onSurface,
                      ),
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      items: _kCategories.map((cat) {
                        return DropdownMenuItem(
                          value: cat,
                          child: Text(
                            cat,
                            style: GoogleFonts.nunito(fontSize: 15),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _selectedCategory = value),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor selecciona el tipo de problema';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: AppConstants.paddingLG),

                    // ── Description ──
                    _SectionLabel(
                      label: 'Describe el problema',
                      required: true,
                    ),
                    const SizedBox(height: AppConstants.paddingSM),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 6,
                      maxLength: 1000,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        color: colorScheme.onSurface,
                      ),
                      decoration: _inputDecoration(
                        context: context,
                        hintText:
                            'Cuentanos que paso con el mayor detalle posible...',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'La descripcion es requerida';
                        }
                        if (value.trim().length < 10) {
                          return 'Por favor incluye mas detalles (minimo 10 caracteres)';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: AppConstants.paddingLG),

                    // ── Optional fields heading ──
                    Text(
                      'Informacion adicional (opcional)',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: AppConstants.paddingMD),

                    // ── Involved user / salon ──
                    _SectionLabel(
                      label: 'Nombre de usuario o salon involucrado (opcional)',
                    ),
                    const SizedBox(height: AppConstants.paddingSM),
                    TextFormField(
                      controller: _involvedController,
                      maxLines: 1,
                      textInputAction: TextInputAction.next,
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        color: colorScheme.onSurface,
                      ),
                      decoration: _inputDecoration(
                        context: context,
                        hintText: 'Ej. salon_rosalinda o @usuario',
                      ),
                    ),

                    const SizedBox(height: AppConstants.paddingMD),

                    // ── Incident date ──
                    _SectionLabel(
                      label: 'Fecha aproximada del incidente (opcional)',
                    ),
                    const SizedBox(height: AppConstants.paddingSM),
                    TextFormField(
                      controller: _dateController,
                      maxLines: 1,
                      textInputAction: TextInputAction.done,
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        color: colorScheme.onSurface,
                      ),
                      decoration: _inputDecoration(
                        context: context,
                        hintText: 'Ej. 05 de marzo de 2026',
                      ),
                    ),

                    const SizedBox(height: AppConstants.paddingXL),

                    // ── Safety notice ──
                    _SafetyNoticeCard(ext: ext),

                    const SizedBox(height: AppConstants.paddingLG),

                    // ── Submit button ──
                    _GradientSubmitButton(
                      gradient: ext.primaryGradient,
                      onTap: _submitting ? null : _submit,
                      loading: _submitting,
                    ),

                    const SizedBox(height: AppConstants.paddingXXL),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required BuildContext context,
    required String hintText,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.nunito(
        fontSize: 14,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
      ),
      errorStyle: GoogleFonts.nunito(fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMD,
        vertical: AppConstants.paddingMD,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        borderSide: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.5),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        borderSide: BorderSide(
          color: colorScheme.primary,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        borderSide: BorderSide(color: colorScheme.error, width: 1.5),
      ),
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
    );
  }
}

// ── Hero header ──

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.gradient});

  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: gradient),
      padding: const EdgeInsets.fromLTRB(
        AppConstants.paddingLG,
        AppConstants.paddingMD,
        AppConstants.paddingLG,
        AppConstants.paddingXL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.15),
            ),
            child: Icon(
              Icons.flag_rounded,
              size: AppConstants.iconSizeXL,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: AppConstants.paddingMD),
          Text(
            'Ayudanos a mejorar',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: AppConstants.paddingXS),
          Text(
            'Tu reporte nos ayuda a mantener\nuna comunidad segura.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.85),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ──

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.required = false});

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return RichText(
      text: TextSpan(
        text: label,
        style: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        children: required
            ? [
                TextSpan(
                  text: ' *',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.error,
                  ),
                ),
              ]
            : [],
      ),
    );
  }
}

// ── Safety notice card ──

class _SafetyNoticeCard extends StatelessWidget {
  const _SafetyNoticeCard({required this.ext});

  final BCThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_rounded,
            size: AppConstants.iconSizeLG,
            color: ext.successColor,
          ),
          const SizedBox(width: AppConstants.paddingMD),
          Expanded(
            child: Text(
              'Tu reporte es confidencial. No compartiremos tu identidad con la persona reportada.',
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: colorScheme.onSurface,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Gradient submit button ──

class _GradientSubmitButton extends StatelessWidget {
  const _GradientSubmitButton({
    required this.gradient,
    required this.onTap,
    required this.loading,
  });

  final LinearGradient gradient;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? AppConstants.opacityDisabled : 1.0,
        duration: AppConstants.shortAnimation,
        child: Container(
          height: AppConstants.comfortableTouchHeight,
          decoration: BoxDecoration(
            gradient: onTap == null
                ? LinearGradient(
                    colors: [Colors.grey.shade400, Colors.grey.shade500],
                  )
                : gradient,
            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
            boxShadow: onTap == null
                ? null
                : [
                    BoxShadow(
                      color: gradient.colors.first.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          alignment: Alignment.center,
          child: loading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.onPrimary),
                  ),
                )
              : Text(
                  'Enviar reporte',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onPrimary,
                    letterSpacing: 0.2,
                  ),
                ),
        ),
      ),
    );
  }
}
