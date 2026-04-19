import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/config/fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/constants.dart';
import '../../config/theme_extension.dart';
import '../../providers/banking_setup_provider.dart';
import '../../providers/business_provider.dart';
import 'package:beautycita_core/supabase.dart';
import '../../services/supabase_client.dart';
import '../../services/toast_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// CLABE Bank Lookup — top ~18 most common Mexican banks
// ═══════════════════════════════════════════════════════════════════════════

const Map<String, String> _clabeBank = {
  '002': 'BANAMEX',
  '012': 'BBVA',
  '014': 'SANTANDER',
  '021': 'HSBC',
  '030': 'BAJIO',
  '036': 'INBURSA',
  '042': 'MIFEL',
  '044': 'SCOTIABANK',
  '058': 'BANREGIO',
  '072': 'BANORTE',
  '127': 'AZTECA',
  '130': 'COMPARTAMOS',
  '137': 'BANCOPPEL',
  '166': 'BANSEFI',
  '646': 'STP',
  '686': 'NU',
  '722': 'MERCADO PAGO',
  '723': 'SPIN BY OXXO',
};

/// Detect bank name from the first 3 digits of a CLABE.
String? _detectBank(String clabe) {
  if (clabe.length < 3) return null;
  return _clabeBank[clabe.substring(0, 3)];
}

/// Validate CLABE checksum (18-digit, weighted mod 10, weights [3,7,1]).
bool _validateClabeChecksum(String clabe) {
  if (clabe.length != 18) return false;
  if (!RegExp(r'^\d{18}$').hasMatch(clabe)) return false;

  const weights = [3, 7, 1];
  int sum = 0;
  for (int i = 0; i < 17; i++) {
    final digit = int.parse(clabe[i]);
    final product = (digit * weights[i % 3]) % 10;
    sum += product;
  }
  final checkDigit = (10 - (sum % 10)) % 10;
  return checkDigit == int.parse(clabe[17]);
}

/// Format CLABE as XXX XXX XXXXXXXXXXXX for display.
String _formatClabe(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length <= 3) return digits;
  if (digits.length <= 6) return '${digits.substring(0, 3)} ${digits.substring(3)}';
  return '${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6)}';
}

/// Mask CLABE for confirmation: show last 4 only.
String _maskClabe(String clabe) {
  if (clabe.length < 4) return clabe;
  return '${'*' * (clabe.length - 4)}${clabe.substring(clabe.length - 4)}';
}

// ═══════════════════════════════════════════════════════════════════════════
// BankingSetupScreen — 3-step wizard
// ═══════════════════════════════════════════════════════════════════════════

class BankingSetupScreen extends ConsumerStatefulWidget {
  const BankingSetupScreen({super.key});

  @override
  ConsumerState<BankingSetupScreen> createState() => _BankingSetupScreenState();
}

class _BankingSetupScreenState extends ConsumerState<BankingSetupScreen> {
  int _step = 0; // 0=banking, 1=ID upload, 2=confirmation

  // Step 1 fields
  final _clabeController = TextEditingController();
  final _beneficiaryController = TextEditingController();
  String? _detectedBank;
  String? _clabeError;
  String? _beneficiaryError;

  // Step 2 fields
  Uint8List? _idFrontBytes;
  Uint8List? _idBackBytes;
  String? _idError;

  // Step 3
  bool _submitting = false;
  bool _success = false;
  String? _submitError;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _clabeController.dispose();
    _beneficiaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _stepTitle(),
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        leading: _step > 0 && !_submitting
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _step--),
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            _StepProgress(currentStep: _step),
            const SizedBox(height: AppConstants.paddingMD),

            // Step content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.screenPaddingHorizontal,
                ),
                child: _buildStep(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _stepTitle() {
    switch (_step) {
      case 0:
        return 'Datos Bancarios';
      case 1:
        return 'Identificacion Oficial';
      case 2:
        return 'Confirmacion';
      default:
        return '';
    }
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      default:
        return const SizedBox.shrink();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step 1: Datos Bancarios
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStep1() {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppConstants.paddingSM),

        // CLABE label
        Text(
          'CLABE Interbancaria',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: AppConstants.paddingXS),
        Text(
          '18 digitos — la encuentras en tu estado de cuenta o app bancaria',
          style: GoogleFonts.nunito(
            fontSize: 12,
            color: colors.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: AppConstants.paddingSM),

        // CLABE input
        TextField(
          controller: _clabeController,
          keyboardType: TextInputType.number,
          maxLength: 18,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
          decoration: InputDecoration(
            hintText: '000 000 000000000000',
            hintStyle: GoogleFonts.poppins(
              fontSize: 18,
              color: colors.onSurface.withValues(alpha: 0.2),
              letterSpacing: 1.5,
            ),
            counterText: '',
            errorText: _clabeError,
            prefixIcon: const Icon(Icons.account_balance_rounded),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              borderSide: BorderSide(
                color: colors.onSurface.withValues(alpha: 0.15),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              borderSide: BorderSide(color: colors.primary, width: 2),
            ),
          ),
          onChanged: (value) {
            final digits = value.replaceAll(RegExp(r'\D'), '');
            setState(() {
              _detectedBank = _detectBank(digits);
              _clabeError = null;
            });
          },
        ),

        // Detected bank display
        if (_detectedBank != null) ...[
          const SizedBox(height: AppConstants.paddingSM),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingMD,
              vertical: AppConstants.paddingSM,
            ),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    size: 20, color: colors.primary),
                const SizedBox(width: AppConstants.paddingSM),
                Text(
                  _detectedBank!,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Formatted display
        if (_clabeController.text.isNotEmpty) ...[
          const SizedBox(height: AppConstants.paddingXS),
          Text(
            _formatClabe(_clabeController.text),
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: colors.onSurface.withValues(alpha: 0.4),
              letterSpacing: 2,
            ),
          ),
        ],

        const SizedBox(height: AppConstants.paddingLG),

        // Beneficiary name
        Text(
          'Nombre del Beneficiario',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: AppConstants.paddingXS),
        Text(
          'Nombre legal como aparece en la cuenta bancaria',
          style: GoogleFonts.nunito(
            fontSize: 12,
            color: colors.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: AppConstants.paddingSM),

        TextField(
          controller: _beneficiaryController,
          textCapitalization: TextCapitalization.words,
          style: GoogleFonts.nunito(fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Ej: Maria Garcia Lopez',
            hintStyle: GoogleFonts.nunito(
              fontSize: 16,
              color: colors.onSurface.withValues(alpha: 0.2),
            ),
            errorText: _beneficiaryError,
            prefixIcon: const Icon(Icons.person_outline_rounded),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              borderSide: BorderSide(
                color: colors.onSurface.withValues(alpha: 0.15),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              borderSide: BorderSide(color: colors.primary, width: 2),
            ),
          ),
          onChanged: (_) => setState(() => _beneficiaryError = null),
        ),

        const SizedBox(height: AppConstants.paddingXL),

        // Next button
        SizedBox(
          width: double.infinity,
          height: AppConstants.comfortableTouchHeight,
          child: FilledButton(
            onPressed: _validateStep1,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              ),
            ),
            child: Text(
              'Siguiente',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        const SizedBox(height: AppConstants.paddingLG),
      ],
    );
  }

  void _validateStep1() {
    final clabe = _clabeController.text.replaceAll(RegExp(r'\D'), '');
    final beneficiary = _beneficiaryController.text.trim();
    bool hasError = false;

    if (clabe.length != 18) {
      setState(() => _clabeError = 'La CLABE debe tener 18 digitos');
      hasError = true;
    } else if (!_validateClabeChecksum(clabe)) {
      setState(() => _clabeError = 'CLABE invalida — verifica los digitos');
      hasError = true;
    }

    if (beneficiary.isEmpty) {
      setState(() => _beneficiaryError = 'Ingresa el nombre del beneficiario');
      hasError = true;
    } else if (beneficiary.length < 3) {
      setState(
          () => _beneficiaryError = 'Nombre demasiado corto');
      hasError = true;
    }

    if (!hasError) {
      HapticFeedback.lightImpact();
      setState(() => _step = 1);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step 2: ID Upload
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStep2() {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppConstants.paddingSM),

        Text(
          'Sube fotos de tu INE/IFE',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: AppConstants.paddingXS),
        Text(
          'Necesitamos ambos lados para verificar tu identidad',
          style: GoogleFonts.nunito(
            fontSize: 13,
            color: colors.onSurface.withValues(alpha: 0.5),
          ),
        ),

        if (_idError != null) ...[
          const SizedBox(height: AppConstants.paddingSM),
          Container(
            padding: const EdgeInsets.all(AppConstants.paddingSM),
            decoration: BoxDecoration(
              color: colors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 18, color: colors.error),
                const SizedBox(width: AppConstants.paddingSM),
                Expanded(
                  child: Text(
                    _idError!,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: colors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: AppConstants.paddingLG),

        // Front of INE
        _IdUploadCard(
          label: 'Frente de tu INE/IFE',
          icon: Icons.credit_card_rounded,
          imageBytes: _idFrontBytes,
          onTap: () => _pickIdImage(front: true),
        ),

        const SizedBox(height: AppConstants.paddingMD),

        // Back of INE
        _IdUploadCard(
          label: 'Reverso de tu INE/IFE',
          icon: Icons.credit_card_rounded,
          imageBytes: _idBackBytes,
          onTap: () => _pickIdImage(front: false),
        ),

        const SizedBox(height: AppConstants.paddingXL),

        // Next button
        SizedBox(
          width: double.infinity,
          height: AppConstants.comfortableTouchHeight,
          child: FilledButton(
            onPressed: _validateStep2,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              ),
            ),
            child: Text(
              'Siguiente',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        const SizedBox(height: AppConstants.paddingLG),
      ],
    );
  }

  Future<void> _pickIdImage({required bool front}) async {
    final source = await _showSourcePicker();
    if (source == null) return;

    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();

      // Validate size: > 200KB and < 10MB
      if (bytes.length < 200 * 1024) {
        setState(() => _idError =
            'La imagen es muy pequena (${(bytes.length / 1024).toStringAsFixed(0)} KB). Minimo 200 KB.');
        return;
      }
      if (bytes.length > 10 * 1024 * 1024) {
        setState(() => _idError =
            'La imagen es muy grande (${(bytes.length / 1024 / 1024).toStringAsFixed(1)} MB). Maximo 10 MB.');
        return;
      }

      HapticFeedback.lightImpact();
      setState(() {
        _idError = null;
        if (front) {
          _idFrontBytes = bytes;
        } else {
          _idBackBytes = bytes;
        }
      });
    } catch (e) {
      if (kDebugMode) debugPrint('BankingSetup: pickIdImage error: $e');
      ToastService.showError('Error al seleccionar imagen');
    }
  }

  Future<ImageSource?> _showSourcePicker() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusXL),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingLG),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingLG),
                Text(
                  'Seleccionar imagen',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMD),
                Row(
                  children: [
                    Expanded(
                      child: _SourceOption(
                        icon: Icons.photo_library_outlined,
                        label: 'Galeria',
                        onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                      ),
                    ),
                    const SizedBox(width: AppConstants.paddingMD),
                    Expanded(
                      child: _SourceOption(
                        icon: Icons.camera_alt_outlined,
                        label: 'Camara',
                        onTap: () => Navigator.pop(ctx, ImageSource.camera),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.paddingSM),
              ],
            ),
          ),
        );
      },
    );
  }

  void _validateStep2() {
    if (_idFrontBytes == null || _idBackBytes == null) {
      setState(
          () => _idError = 'Necesitas subir ambos lados de tu identificacion');
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _idError = null;
      _step = 2;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step 3: Confirmation
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStep3() {
    final colors = Theme.of(context).colorScheme;
    final clabe = _clabeController.text.replaceAll(RegExp(r'\D'), '');

    if (_success) {
      return _buildSuccessView(colors);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppConstants.paddingSM),

        Text(
          'Verifica tus datos',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: AppConstants.paddingMD),

        // Summary card
        Card(
          elevation: 0,
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
            side: BorderSide(
              color: colors.onSurface.withValues(alpha: 0.08),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bank
                _SummaryRow(
                  icon: Icons.account_balance_rounded,
                  label: 'Banco',
                  value: _detectedBank ?? 'No identificado',
                ),
                const Divider(height: AppConstants.paddingLG),

                // CLABE masked
                _SummaryRow(
                  icon: Icons.lock_outline_rounded,
                  label: 'CLABE',
                  value: _maskClabe(clabe),
                ),
                const Divider(height: AppConstants.paddingLG),

                // Beneficiary
                _SummaryRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Beneficiario',
                  value: _beneficiaryController.text.trim(),
                ),
                const Divider(height: AppConstants.paddingLG),

                // ID thumbnails
                Text(
                  'Identificacion',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: colors.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingSM),
                Row(
                  children: [
                    if (_idFrontBytes != null)
                      _IdThumbnail(
                        bytes: _idFrontBytes!,
                        label: 'Frente',
                      ),
                    const SizedBox(width: AppConstants.paddingMD),
                    if (_idBackBytes != null)
                      _IdThumbnail(
                        bytes: _idBackBytes!,
                        label: 'Reverso',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),

        if (_submitError != null) ...[
          const SizedBox(height: AppConstants.paddingMD),
          Container(
            padding: const EdgeInsets.all(AppConstants.paddingSM),
            decoration: BoxDecoration(
              color: colors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 18, color: colors.error),
                const SizedBox(width: AppConstants.paddingSM),
                Expanded(
                  child: Text(
                    _submitError!,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: colors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: AppConstants.paddingXL),

        // Submit button
        SizedBox(
          width: double.infinity,
          height: AppConstants.comfortableTouchHeight,
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              ),
            ),
            child: _submitting
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.onPrimary,
                    ),
                  )
                : Text(
                    'Verificar y Activar',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: AppConstants.paddingLG),
      ],
    );
  }

  Widget _buildSuccessView(ColorScheme colors) {
    final bcTheme = Theme.of(context).extension<BCThemeExtension>();

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingXXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppConstants.paddingLG),
              decoration: BoxDecoration(
                color: (bcTheme?.successColor ?? Colors.green)
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_rounded,
                size: 64,
                color: bcTheme?.successColor ?? Colors.green,
              ),
            ),
            const SizedBox(height: AppConstants.paddingLG),
            Text(
              'Datos bancarios verificados',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: AppConstants.paddingSM),
            Text(
              'Tu salon ya puede recibir pagos y reservas',
              style: GoogleFonts.nunito(
                fontSize: 15,
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.paddingXL),
            SizedBox(
              width: double.infinity,
              height: AppConstants.comfortableTouchHeight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusMD),
                  ),
                ),
                child: Text(
                  'Volver al panel',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Payout-lock disclosure modal — fires when EDITING existing beneficiary/CLABE.
  /// Not shown on first-time setup. DB trigger opens the hold regardless; this
  /// dialog just makes the consequence visible at the edit point.
  Future<bool> _confirmPayoutLockChange({required String changedFields}) async {
    var acknowledged = false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Confirmar cambio en datos de pago'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Estas a punto de modificar $changedFields. Al confirmar:'),
                const SizedBox(height: 10),
                const Text('1. Se suspenderan todos los pagos pendientes hasta que un administrador verifique la nueva informacion (24-72 h habiles).'),
                const SizedBox(height: 6),
                const Text('2. La nueva cuenta debe pertenecer a la misma persona o empresa con el nombre y RFC registrados.'),
                const SizedBox(height: 6),
                const Text('3. Si alguien reclama que enviaste pagos a una cuenta que no corresponde al titular, BeautyCita puede cancelar tu cuenta.'),
                const SizedBox(height: 6),
                const Text('4. En caso de cancelacion, el saldo a tu favor se retiene como compensacion y la deuda queda extinguida. Apelable ante Panel Arbitral.'),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Checkbox(
                      value: acknowledged,
                      onChanged: (v) => setDialogState(() => acknowledged = v ?? false),
                    ),
                    const Expanded(child: Text('He leido y acepto.', style: TextStyle(fontSize: 13))),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: acknowledged ? () => Navigator.of(dialogContext).pop(true) : null,
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      final biz = await ref.read(currentBusinessProvider.future);
      if (biz == null) {
        setState(() {
          _submitError = 'No se encontro el negocio. Intenta de nuevo.';
          _submitting = false;
        });
        return;
      }

      final businessId = biz['id'] as String;
      final clabe = _clabeController.text.replaceAll(RegExp(r'\D'), '');
      final beneficiary = _beneficiaryController.text.trim();
      final client = SupabaseClientService.client;

      // Disclosure modal on edit (not on first-time setup)
      final existingBeneficiary = (biz['beneficiary_name'] as String?)?.trim();
      final existingClabe = (biz['clabe'] as String?)?.trim();
      final nameChanged = existingBeneficiary != null && existingBeneficiary.isNotEmpty && existingBeneficiary != beneficiary;
      final clabeChanged = existingClabe != null && existingClabe.isNotEmpty && existingClabe != clabe;
      if (nameChanged || clabeChanged) {
        final parts = <String>[];
        if (nameChanged) parts.add('el Nombre del Beneficiario');
        if (clabeChanged) parts.add('la CLABE');
        if (!mounted) return;
        final confirmed = await _confirmPayoutLockChange(changedFields: parts.join(' y '));
        if (!confirmed) {
          setState(() {
            _submitting = false;
          });
          return;
        }
      }

      // 1. Upload ID front
      final frontPath = 'salon-ids/$businessId/id_front.jpg';
      await client.storage.from('salon-ids').uploadBinary(
            frontPath,
            _idFrontBytes!,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      // 2. Upload ID back
      final backPath = 'salon-ids/$businessId/id_back.jpg';
      await client.storage.from('salon-ids').uploadBinary(
            backPath,
            _idBackBytes!,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      // 3. Save CLABE + beneficiary + ID URLs to businesses table
      await client.from(BCTables.businesses).update({
        'clabe': clabe,
        'beneficiary_name': beneficiary,
        'bank_name': _detectedBank ?? '',
        'id_front_url': frontPath,
        'id_back_url': backPath,
        'banking_complete': false, // set true by edge function on verification
      }).eq('id', businessId);

      // 4. Call verify-salon-id Edge Function
      // TODO: bank account details (CLABE routing) pending BBVA meeting
      final response = await client.functions.invoke(
        'verify-salon-id',
        body: {
          'business_id': businessId,
          'beneficiary_name': beneficiary,
        },
      );

      if (response.status != 200) {
        final errorMsg =
            (response.data as Map<String, dynamic>?)?['error'] as String? ??
                'Error de verificacion. Intenta de nuevo.';
        setState(() {
          _submitError = errorMsg;
          _submitting = false;
        });
        return;
      }

      // Invalidate providers to refresh dashboard
      ref.invalidate(currentBusinessProvider);
      ref.invalidate(bankingCompleteProvider);

      HapticFeedback.heavyImpact();
      setState(() {
        _submitting = false;
        _success = true;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('BankingSetup: submit error: $e');
      setState(() {
        _submitError = ToastService.friendlyError(e);
        _submitting = false;
      });
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Subwidgets
// ═══════════════════════════════════════════════════════════════════════════

class _StepProgress extends StatelessWidget {
  final int currentStep;
  const _StepProgress({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final labels = ['Banco', 'INE', 'Confirmar'];

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.screenPaddingHorizontal,
        vertical: AppConstants.paddingSM,
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final isActive = i <= currentStep;
          final isCurrentOrPast = i <= currentStep;
          return Expanded(
            child: Row(
              children: [
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isCurrentOrPast
                          ? colors.primary
                          : colors.onSurface.withValues(alpha: 0.12),
                    ),
                  ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isActive
                        ? colors.primary
                        : colors.onSurface.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: i < currentStep
                        ? Icon(Icons.check, size: 16, color: colors.onPrimary)
                        : Text(
                            '${i + 1}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isActive
                                  ? colors.onPrimary
                                  : colors.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                  ),
                ),
                if (i < labels.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: i < currentStep
                          ? colors.primary
                          : colors.onSurface.withValues(alpha: 0.12),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _IdUploadCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Uint8List? imageBytes;
  final VoidCallback onTap;

  const _IdUploadCard({
    required this.label,
    required this.icon,
    this.imageBytes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasImage = imageBytes != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: hasImage ? 200 : 140,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          border: Border.all(
            color: hasImage
                ? colors.primary.withValues(alpha: 0.3)
                : colors.onSurface.withValues(alpha: 0.12),
            width: hasImage ? 2 : 1,
          ),
        ),
        child: hasImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusMD - 1),
                    child: Image.memory(
                      imageBytes!,
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Overlay with label
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.paddingSM,
                        vertical: AppConstants.paddingXS,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            colors.onSurface.withValues(alpha: 0.6),
                          ],
                        ),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(AppConstants.radiusMD - 1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, size: 16,
                              color: colors.onPrimary),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.onPrimary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Cambiar',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              color: colors.onPrimary.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppConstants.paddingMD),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 32,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingSM),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingXS),
                  Text(
                    'Toca para subir',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: colors.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 20, color: colors.primary),
        const SizedBox(width: AppConstants.paddingSM),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _IdThumbnail extends StatelessWidget {
  final Uint8List bytes;
  final String label;

  const _IdThumbnail({required this.bytes, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Expanded(
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.radiusSM),
            child: AspectRatio(
              aspectRatio: 1.6,
              child: Image.memory(
                bytes,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: AppConstants.paddingXS),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 11,
              color: colors.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingMD,
            vertical: AppConstants.paddingMD,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: colors.primary),
              const SizedBox(width: AppConstants.paddingXS),
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
