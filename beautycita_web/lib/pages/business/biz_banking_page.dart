import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../config/breakpoints.dart';
import '../../config/web_theme.dart';
import '../../providers/business_portal_provider.dart';
import '../../widgets/web_design_system.dart';

// ── CLABE bank code lookup (top 30 Mexican banks) ──────────────────────────

const _clabeBanks = <String, String>{
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

// ── CLABE validation ────────────────────────────────────────────────────────

/// Validates CLABE checksum (digit 18 is check digit).
/// Weights cycle [3,7,1] across digits 1-17, sum mod 10, check = (10 - sum%10) % 10.
bool _validateClabe(String clabe) {
  if (clabe.length != 18) return false;
  if (!RegExp(r'^\d{18}$').hasMatch(clabe)) return false;

  const weights = [3, 7, 1];
  var sum = 0;
  for (var i = 0; i < 17; i++) {
    final digit = int.parse(clabe[i]);
    sum += (digit * weights[i % 3]) % 10;
  }
  final checkDigit = (10 - (sum % 10)) % 10;
  return checkDigit == int.parse(clabe[17]);
}

/// Extracts bank code (first 3 digits) from CLABE.
String? _bankFromClabe(String clabe) {
  if (clabe.length < 3) return null;
  return _clabeBanks[clabe.substring(0, 3)];
}

// ── Page ─────────────────────────────────────────────────────────────────────

/// 3-step form for collecting salon banking info (CLABE, ID upload, confirmation).
class BizBankingPage extends ConsumerStatefulWidget {
  const BizBankingPage({super.key});

  @override
  ConsumerState<BizBankingPage> createState() => _BizBankingPageState();
}

class _BizBankingPageState extends ConsumerState<BizBankingPage> {
  int _step = 0; // 0=banking, 1=ID upload, 2=confirm

  // Step 1
  final _clabeController = TextEditingController();
  final _beneficiaryController = TextEditingController();
  String? _detectedBank;
  String? _clabeError;

  // Step 2
  Uint8List? _idFrontBytes;
  String? _idFrontName;
  Uint8List? _idBackBytes;
  String? _idBackName;
  String? _idError;

  // Step 3
  bool _submitting = false;
  String? _resultMessage;
  bool _resultSuccess = false;

  @override
  void dispose() {
    _clabeController.dispose();
    _beneficiaryController.dispose();
    super.dispose();
  }

  // ── Step 1 validation ─────────────────────────────────────────────────────

  void _onClabeChanged(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    setState(() {
      _detectedBank = _bankFromClabe(digits);
      _clabeError = null;
    });
  }

  bool _validateStep1() {
    final clabe = _clabeController.text.trim();
    if (clabe.length != 18) {
      setState(() => _clabeError = 'La CLABE debe tener 18 digitos');
      return false;
    }
    if (!_validateClabe(clabe)) {
      setState(() => _clabeError = 'CLABE invalida — verifica el digito verificador');
      return false;
    }
    if (_beneficiaryController.text.trim().isEmpty) {
      setState(() => _clabeError = 'Ingresa el nombre del beneficiario');
      return false;
    }
    return true;
  }

  // ── Step 2 file pick ──────────────────────────────────────────────────────

  Future<void> _pickFile(bool isFront) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    // Validate size
    if (bytes.length < 200 * 1024) {
      setState(() => _idError = 'El archivo es muy pequeno (minimo 200KB)');
      return;
    }
    if (bytes.length > 10 * 1024 * 1024) {
      setState(() => _idError = 'El archivo es muy grande (maximo 10MB)');
      return;
    }

    setState(() {
      _idError = null;
      if (isFront) {
        _idFrontBytes = bytes;
        _idFrontName = file.name;
      } else {
        _idBackBytes = bytes;
        _idBackName = file.name;
      }
    });
  }

  bool _validateStep2() {
    if (_idFrontBytes == null || _idBackBytes == null) {
      setState(() => _idError = 'Sube ambos lados de tu identificacion');
      return false;
    }
    return true;
  }

  // ── Step 3 submit ─────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final biz = await ref.read(currentBusinessProvider.future);
    if (biz == null) return;

    setState(() {
      _submitting = true;
      _resultMessage = null;
    });

    final bizId = biz['id'] as String;
    final clabe = _clabeController.text.trim();
    final beneficiary = _beneficiaryController.text.trim();

    try {
      // Upload ID images to Supabase storage
      final frontExt = _idFrontName?.split('.').last ?? 'jpg';
      final backExt = _idBackName?.split('.').last ?? 'jpg';
      final frontPath = 'salon-ids/$bizId/id_front.$frontExt';
      final backPath = 'salon-ids/$bizId/id_back.$backExt';

      await Future.wait([
        BCSupabase.client.storage.from('salon-ids').uploadBinary(
              frontPath,
              _idFrontBytes!,
              fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
            ),
        BCSupabase.client.storage.from('salon-ids').uploadBinary(
              backPath,
              _idBackBytes!,
              fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
            ),
      ]);

      // Save CLABE + beneficiary to businesses table
      await BCSupabase.client.from(BCTables.businesses).update({
        'clabe': clabe,
        'clabe_beneficiary': beneficiary,
        'clabe_bank': _detectedBank ?? '',
        'banking_complete': false, // will be set true by edge function on verification
        'id_front_path': frontPath,
        'id_back_path': backPath,
      }).eq('id', bizId);

      // Call edge function for verification
      final response = await BCSupabase.client.functions.invoke(
        'verify-salon-id',
        body: {
          'business_id': bizId,
          'id_front_path': frontPath,
          'id_back_path': backPath,
        },
      );

      final data = response.data as Map<String, dynamic>?;
      final verified = data?['verified'] as bool? ?? false;

      if (verified) {
        // Mark banking complete
        await BCSupabase.client.from(BCTables.businesses).update({
          'banking_complete': true,
        }).eq('id', bizId);

        setState(() {
          _resultSuccess = true;
          _resultMessage = 'Cuenta bancaria verificada y activada correctamente.';
        });

        // Invalidate the business provider to refresh data
        ref.invalidate(currentBusinessProvider);
      } else {
        final reason = data?['reason'] as String? ?? 'No se pudo verificar la identificacion.';
        setState(() {
          _resultSuccess = false;
          _resultMessage = reason;
        });
      }
    } catch (e) {
      setState(() {
        _resultSuccess = false;
        _resultMessage = 'Error: $e';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bizAsync = ref.watch(currentBusinessProvider);

    return bizAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (biz) {
        if (biz == null) return const Center(child: Text('Sin negocio'));
        return _buildContent(context, biz);
      },
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> biz) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = WebBreakpoints.isMobile(constraints.maxWidth);
        final padding = isMobile ? 16.0 : 24.0;
        final maxFormWidth = isMobile ? double.infinity : 640.0;

        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              TextButton.icon(
                onPressed: () => context.go('/negocio/payments'),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Volver a Pagos'),
              ),
              const SizedBox(height: 8),

              WebSectionHeader(
                label: 'Configuracion',
                title: 'Datos Bancarios',
                centered: false,
                titleSize: 28,
              ),
              const SizedBox(height: 8),
              Text(
                'Configura tu cuenta bancaria para recibir depositos de BeautyCita.',
                style: theme.textTheme.bodyMedium?.copyWith(color: kWebTextSecondary),
              ),
              const SizedBox(height: 32),

              // Step indicator
              _StepIndicator(currentStep: _step),
              const SizedBox(height: 32),

              // Form content centered
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxFormWidth),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: switch (_step) {
                      0 => _buildStep1(theme),
                      1 => _buildStep2(theme),
                      2 => _buildStep3(theme, biz),
                      _ => const SizedBox.shrink(),
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Step 1: Datos Bancarios ───────────────────────────────────────────────

  Widget _buildStep1(ThemeData theme) {
    return WebCard(
      key: const ValueKey('step1'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: kWebBrandGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance, size: 22, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Text('Datos Bancarios', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 24),

          // CLABE input
          Text('CLABE Interbancaria', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _clabeController,
            decoration: InputDecoration(
              hintText: '18 digitos',
              prefixIcon: const Icon(Icons.pin_outlined, size: 20),
              counterText: '${_clabeController.text.length}/18',
              errorText: _clabeError,
            ),
            keyboardType: TextInputType.number,
            maxLength: 18,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: _onClabeChanged,
          ),
          const SizedBox(height: 12),

          // Auto-detected bank (read-only)
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _detectedBank != null
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: kWebSuccess.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kWebSuccess.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified, color: kWebSuccess, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          'Banco: $_detectedBank',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: kWebSuccess,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),

          // Beneficiary name
          Text('Nombre del Beneficiario', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _beneficiaryController,
            decoration: const InputDecoration(
              hintText: 'Tal como aparece en tu estado de cuenta',
              prefixIcon: Icon(Icons.person_outline, size: 20),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 32),

          // Next button
          Align(
            alignment: Alignment.centerRight,
            child: WebGradientButton(
              onPressed: () {
                if (_validateStep1()) setState(() => _step = 1);
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Siguiente'),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Identificacion Oficial ────────────────────────────────────────

  Widget _buildStep2(ThemeData theme) {
    return WebCard(
      key: const ValueKey('step2'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: kWebBrandGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.badge_outlined, size: 22, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Text('Identificacion Oficial', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Sube ambos lados de tu INE o pasaporte. JPG o PNG, entre 200KB y 10MB.',
            style: theme.textTheme.bodySmall?.copyWith(color: kWebTextSecondary),
          ),
          const SizedBox(height: 24),

          // Two upload zones side by side on desktop, stacked on mobile
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 480;
              final children = [
                Expanded(
                  child: _DropZone(
                    label: 'Frente de INE',
                    fileName: _idFrontName,
                    bytes: _idFrontBytes,
                    onTap: () => _pickFile(true),
                  ),
                ),
                SizedBox(width: narrow ? 0 : 16, height: narrow ? 16 : 0),
                Expanded(
                  child: _DropZone(
                    label: 'Reverso de INE',
                    fileName: _idBackName,
                    bytes: _idBackBytes,
                    onTap: () => _pickFile(false),
                  ),
                ),
              ];

              if (narrow) {
                return Column(
                  children: [
                    _DropZone(
                      label: 'Frente de INE',
                      fileName: _idFrontName,
                      bytes: _idFrontBytes,
                      onTap: () => _pickFile(true),
                    ),
                    const SizedBox(height: 16),
                    _DropZone(
                      label: 'Reverso de INE',
                      fileName: _idBackName,
                      bytes: _idBackBytes,
                      onTap: () => _pickFile(false),
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              );
            },
          ),

          if (_idError != null) ...[
            const SizedBox(height: 12),
            Text(_idError!, style: theme.textTheme.bodySmall?.copyWith(color: kWebError)),
          ],
          const SizedBox(height: 32),

          // Nav buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              WebOutlinedButton(
                onPressed: () => setState(() => _step = 0),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back, size: 18),
                    SizedBox(width: 8),
                    Text('Atras'),
                  ],
                ),
              ),
              WebGradientButton(
                onPressed: () {
                  if (_validateStep2()) setState(() => _step = 2);
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Siguiente'),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Step 3: Confirmacion ──────────────────────────────────────────────────

  Widget _buildStep3(ThemeData theme, Map<String, dynamic> biz) {
    final clabe = _clabeController.text.trim();
    final maskedClabe = '************${clabe.substring(clabe.length - 4)}';
    final beneficiary = _beneficiaryController.text.trim();

    return WebCard(
      key: const ValueKey('step3'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: kWebBrandGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.verified_user_outlined, size: 22, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Text('Confirmar Datos', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 24),

          // Summary
          _SummaryRow(label: 'Banco', value: _detectedBank ?? 'Desconocido'),
          const SizedBox(height: 12),
          _SummaryRow(label: 'CLABE', value: maskedClabe),
          const SizedBox(height: 12),
          _SummaryRow(label: 'Beneficiario', value: beneficiary),
          const SizedBox(height: 20),

          // ID previews
          Text('Identificacion', style: theme.textTheme.labelLarge),
          const SizedBox(height: 12),
          Row(
            children: [
              if (_idFrontBytes != null)
                _IdPreview(label: 'Frente', bytes: _idFrontBytes!),
              const SizedBox(width: 16),
              if (_idBackBytes != null)
                _IdPreview(label: 'Reverso', bytes: _idBackBytes!),
            ],
          ),
          const SizedBox(height: 24),

          // Result message
          if (_resultMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (_resultSuccess ? kWebSuccess : kWebError).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (_resultSuccess ? kWebSuccess : kWebError).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _resultSuccess ? Icons.check_circle : Icons.error_outline,
                    color: _resultSuccess ? kWebSuccess : kWebError,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _resultMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _resultSuccess ? kWebSuccess : kWebError,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              WebOutlinedButton(
                onPressed: _submitting ? null : () => setState(() => _step = 1),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back, size: 18),
                    SizedBox(width: 8),
                    Text('Atras'),
                  ],
                ),
              ),
              WebGradientButton(
                isLoading: _submitting,
                onPressed: _submitting
                    ? null
                    : () {
                        if (_resultSuccess) {
                          context.go('/negocio/payments');
                        } else {
                          _submit();
                        }
                      },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _resultSuccess ? Icons.check : Icons.verified_user,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(_resultSuccess ? 'Listo' : 'Verificar y Activar'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Step indicator ──────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep});
  final int currentStep;

  static const _labels = ['Datos Bancarios', 'Identificacion', 'Confirmacion'];
  static const _icons = [Icons.account_balance, Icons.badge_outlined, Icons.verified_user_outlined];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        for (int i = 0; i < 3; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: i <= currentStep ? kWebPrimary : kWebCardBorder,
              ),
            ),
          _StepDot(
            index: i,
            icon: _icons[i],
            label: _labels[i],
            isActive: i == currentStep,
            isComplete: i < currentStep,
            theme: theme,
          ),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.isComplete,
    required this.theme,
  });

  final int index;
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isComplete;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final color = isActive || isComplete ? kWebPrimary : kWebTextHint;

    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? kWebPrimary
                : isComplete
                    ? kWebPrimary.withValues(alpha: 0.12)
                    : kWebCardBorder,
          ),
          child: Icon(
            isComplete ? Icons.check : icon,
            size: 20,
            color: isActive ? Colors.white : color,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Drop zone for file upload ───────────────────────────────────────────────

class _DropZone extends StatelessWidget {
  const _DropZone({
    required this.label,
    required this.fileName,
    required this.bytes,
    required this.onTap,
  });

  final String label;
  final String? fileName;
  final Uint8List? bytes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFile = bytes != null;

    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            color: hasFile ? kWebSuccess.withValues(alpha: 0.04) : kWebBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasFile ? kWebSuccess.withValues(alpha: 0.3) : kWebCardBorder,
              width: hasFile ? 2 : 1,
            ),
          ),
          child: hasFile
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(bytes!, fit: BoxFit.cover),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          color: Colors.black54,
                          child: Text(
                            fileName ?? label,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: kWebSuccess,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_upload_outlined, size: 36, color: kWebTextHint),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: kWebTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Arrastra o haz clic',
                      style: theme.textTheme.labelSmall?.copyWith(color: kWebTextHint),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Summary row ─────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: kWebTextSecondary)),
        ),
        Expanded(
          child: Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// ── ID preview thumbnail ────────────────────────────────────────────────────

class _IdPreview extends StatelessWidget {
  const _IdPreview({required this.label, required this.bytes});
  final String label;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            width: 120,
            height: 80,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: kWebTextSecondary)),
      ],
    );
  }
}
