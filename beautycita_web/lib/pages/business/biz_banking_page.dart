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
import '../../providers/demo_providers.dart';
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
  final _rfcController = TextEditingController();
  String? _detectedBank;
  String? _clabeError;
  String? _rfcError;
  bool _rfcLocked = false;

  // Mexican RFC format check (DB trigger is the strict authority).
  static final _rfcRegExp = RegExp(r'^[A-ZÑ&]{3,4}\d{6}[A-Z0-9]{3}$');
  bool _validRfc(String s) => _rfcRegExp.hasMatch(s);

  /// Soft name↔RFC consistency check matching the mobile heuristic:
  /// PF (13) char[0] ≈ paternal surname's first letter; PM (12) char[0]
  /// ≈ first letter of company name's first word.
  String? _nameRfcWarning(String rfc, String name) {
    final clean = name.toUpperCase().replaceAll(RegExp(r'[^A-ZÑ\s]'), '').trim();
    if (clean.isEmpty || rfc.length < 4) return null;
    final words = clean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return null;
    final isPF = rfc.length == 13;
    if (isPF) {
      String paternal;
      if (words.length >= 3) {
        paternal = words[words.length - 2];
      } else if (words.length == 2) {
        paternal = words[1];
      } else {
        paternal = words[0];
      }
      if (rfc[0] != paternal[0]) {
        return 'El RFC no parece coincidir con "${paternal.toLowerCase()}". Revisa.';
      }
      return null;
    }
    final first = words[0];
    if (rfc[0] != first[0]) {
      return 'El RFC empresarial no coincide con "${first.toLowerCase()}". Revisa.';
    }
    return null;
  }

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
  void initState() {
    super.initState();
    Future.microtask(_prefillFromBusiness);
  }

  Future<void> _prefillFromBusiness() async {
    try {
      final biz = await ref.read(currentBusinessProvider.future);
      if (!mounted || biz == null) return;
      final rfc = (biz['rfc'] as String?)?.trim() ?? '';
      final clabe = (biz['clabe'] as String?)?.trim() ?? '';
      final ben = (biz['beneficiary_name'] as String?)?.trim() ?? '';
      setState(() {
        if (rfc.isNotEmpty) {
          _rfcController.text = rfc.toUpperCase();
          _rfcLocked = true;
        }
        if (clabe.isNotEmpty) {
          _clabeController.text = clabe;
          // onChanged listener doesn't fire on .text= so re-detect manually.
          final digits = clabe.replaceAll(RegExp(r'\D'), '');
          if (digits.length >= 3) _detectedBank = _bankFromClabe(digits);
        }
        if (ben.isNotEmpty) _beneficiaryController.text = ben;
      });
    } catch (_) {/* best-effort prefill */}
  }

  @override
  void dispose() {
    _clabeController.dispose();
    _beneficiaryController.dispose();
    _rfcController.dispose();
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
    final beneficiary = _beneficiaryController.text.trim();
    if (beneficiary.isEmpty) {
      setState(() => _clabeError = 'Ingresa el nombre del beneficiario');
      return false;
    }
    final rfc = _rfcController.text.trim().toUpperCase();
    if (rfc.isEmpty) {
      setState(() => _rfcError = 'RFC requerido — SAT lo exige para depositos');
      return false;
    }
    if (rfc.length < 12 || rfc.length > 13) {
      setState(() => _rfcError = 'RFC debe tener 12 o 13 caracteres');
      return false;
    }
    if (!_validRfc(rfc)) {
      setState(() => _rfcError = 'Formato de RFC invalido');
      return false;
    }
    if (!_rfcLocked) {
      final warn = _nameRfcWarning(rfc, beneficiary);
      if (warn != null) {
        setState(() => _rfcError = warn);
        return false;
      }
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

  // ── Payout-lock disclosure modal (fires on edit, not first-time setup) ───
  //
  // Per decision #15 / ToS § 1-7, changing beneficiary_name, rfc, or clabe
  // auto-freezes all payouts until admin review. User must acknowledge before
  // the write goes through. The DB trigger will open the payout_hold whether
  // or not the modal is shown — this dialog exists to make the consequence
  // visible at the point of edit.
  Future<bool> _confirmPayoutLockChange({required String changedFields}) async {
    var acknowledged = false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Confirmar cambio en datos de pago'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Estas a punto de modificar $changedFields asociado a tu cuenta bancaria para recibir pagos de BeautyCita. Al confirmar este cambio:',
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  const _BulletLine(
                    number: '1',
                    text: 'Se suspenderan inmediatamente todos los pagos pendientes y programados hacia tu cuenta hasta que un administrador verifique y autorice la nueva informacion. Este proceso puede tardar entre 24 y 72 horas habiles.',
                  ),
                  const _BulletLine(
                    number: '2',
                    text: 'La nueva cuenta bancaria debe pertenecer a la misma persona o empresa cuyo nombre y RFC declares en este formulario. BeautyCita unicamente transferira fondos a cuentas cuyo titular coincida con los datos registrados.',
                  ),
                  const _BulletLine(
                    number: '3',
                    text: 'Si alguien reclama posteriormente que enviaste pagos a una cuenta que no corresponde al titular original, BeautyCita puede cancelar tu cuenta por cualquier motivo, a nuestra entera discrecion.',
                  ),
                  const _BulletLine(
                    number: '4',
                    text: 'En caso de cancelacion, cualquier saldo a tu favor en la Plataforma se retiene como compensacion, y cualquier deuda que tengas con BeautyCita queda extinguida. La decision puede apelarse ante un Panel Arbitral de tres personas designadas por BeautyCita; su resolucion es final.',
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: acknowledged,
                        onChanged: (v) => setDialogState(() => acknowledged = v ?? false),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => acknowledged = !acknowledged),
                          child: Text(
                            'He leido y acepto estas condiciones y los Terminos y Condiciones completos.',
                            style: Theme.of(ctx).textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: acknowledged ? () => Navigator.of(dialogContext).pop(true) : null,
              child: const Text('Confirmar cambio'),
            ),
          ],
        ),
      ),
    );
    return confirmed ?? false;
  }

  // ── Step 3 submit ─────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final biz = await ref.read(currentBusinessProvider.future);
    if (biz == null) return;

    final bizId = biz['id'] as String;
    final clabe = _clabeController.text.trim();
    final beneficiary = _beneficiaryController.text.trim();
    final rfc = _rfcController.text.trim().toUpperCase();

    // Disclosure modal — fires only when EDITING existing values, not on first setup.
    final existingBeneficiary = (biz['beneficiary_name'] as String?)?.trim();
    final existingClabe = (biz['clabe'] as String?)?.trim();
    final existingRfc = (biz['rfc'] as String?)?.trim();
    final nameChanged = existingBeneficiary != null && existingBeneficiary.isNotEmpty && existingBeneficiary != beneficiary;
    final clabeChanged = existingClabe != null && existingClabe.isNotEmpty && existingClabe != clabe;
    final rfcChanged = existingRfc != null && existingRfc.isNotEmpty && existingRfc != rfc;
    if (nameChanged || clabeChanged) {
      final parts = <String>[];
      if (nameChanged) parts.add('el Nombre del Beneficiario');
      if (clabeChanged) parts.add('la CLABE');
      final confirmed = await _confirmPayoutLockChange(changedFields: parts.join(' y '));
      if (!confirmed) {
        return; // user cancelled — keep existing state
      }
    }

    setState(() {
      _submitting = true;
      _resultMessage = null;
    });

    try {
      // Upload ID images to Supabase storage
      final frontExt = _idFrontName?.split('.').last ?? 'jpg';
      final backExt = _idBackName?.split('.').last ?? 'jpg';
      final frontPath = '$bizId/id_front.$frontExt';
      final backPath = '$bizId/id_back.$backExt';

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

      // Save CLABE + beneficiary + RFC + ID URLs to businesses table.
      // Only write rfc when not locked AND it actually changed — prevents
      // a benign re-save from tripping the payout-lock audit on every edit.
      final updatePayload = <String, dynamic>{
        'clabe': clabe,
        'beneficiary_name': beneficiary,
        'bank_name': _detectedBank ?? '',
        'banking_complete': false, // set true by edge function on verification
        'id_front_url': frontPath,
        'id_back_url': backPath,
      };
      if (!_rfcLocked && (existingRfc == null || existingRfc.isEmpty || rfcChanged)) {
        updatePayload['rfc'] = rfc;
      }
      await BCSupabase.client.from(BCTables.businesses).update(updatePayload).eq('id', bizId);

      // Call edge function for verification
      // TODO: bank account details (CLABE routing) pending BBVA meeting
      final response = await BCSupabase.client.functions.invoke(
        'verify-salon-id',
        body: {
          'business_id': bizId,
          'beneficiary_name': beneficiary,
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
        // Edge fn returns `rejection_reason` on a verified=false response.
        final reason = data?['rejection_reason'] as String?
            ?? data?['error'] as String?
            ?? 'No se pudo verificar la identificacion. Revisa tus fotos e intentalo de nuevo.';
        setState(() {
          _resultSuccess = false;
          _resultMessage = reason;
        });
      }
    } catch (e) {
      // Surface the raw exception under the friendly message so storage
      // / RLS / network failures are diagnosable without a debugger.
      final raw = e.toString();
      final detail = raw.length > 240 ? '${raw.substring(0, 240)}…' : raw;
      setState(() {
        _resultSuccess = false;
        _resultMessage = 'Error: $detail';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bizAsync = ref.watch(currentBusinessProvider);
    final isDemo = ref.watch(isDemoProvider);

    return bizAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (biz) {
        if (biz == null) return const Center(child: Text('Sin negocio'));
        if (isDemo) return const _BankingDemoPlaceholder();
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
          const SizedBox(height: 20),

          // RFC (required)
          Text('RFC', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            _rfcLocked
                ? 'El RFC esta vinculado a tu cuenta. Para cambiarlo contacta soporte.'
                : '13 caracteres si eres persona fisica, 12 si es empresa. SAT lo requiere para depositar.',
            style: theme.textTheme.bodySmall?.copyWith(color: kWebTextSecondary),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _rfcController,
            enabled: !_rfcLocked,
            textCapitalization: TextCapitalization.characters,
            maxLength: 13,
            decoration: InputDecoration(
              hintText: 'XAXX010101000',
              counterText: '',
              prefixIcon: Icon(_rfcLocked ? Icons.lock_outline : Icons.badge_outlined, size: 20),
              errorText: _rfcError,
            ),
            onChanged: (v) {
              final cleaned = v.toUpperCase().replaceAll(RegExp(r'\s'), '');
              if (cleaned != v) {
                _rfcController.value = TextEditingValue(
                  text: cleaned,
                  selection: TextSelection.collapsed(offset: cleaned.length),
                );
              }
              if (_rfcError != null) setState(() => _rfcError = null);
            },
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
              final narrow = constraints.maxWidth < WebBreakpoints.mobileXSmall;
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
          _SummaryRow(label: 'Banco', value: _detectedBank ?? 'No identificado'),
          const SizedBox(height: 12),
          _SummaryRow(label: 'CLABE', value: maskedClabe),
          const SizedBox(height: 12),
          _SummaryRow(label: 'Beneficiario', value: beneficiary),
          const SizedBox(height: 12),
          _SummaryRow(
            label: 'RFC',
            value: _rfcController.text.trim().toUpperCase(),
          ),
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

/// Numbered bullet line used inside the payout-lock disclosure dialog.
class _BulletLine extends StatelessWidget {
  const _BulletLine({required this.number, required this.text});
  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Text('$number.', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
          ),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _BankingDemoPlaceholder extends StatelessWidget {
  const _BankingDemoPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: WebCard(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: kWebPrimary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_balance_outlined, size: 40, color: kWebPrimary),
              ),
              const SizedBox(height: 20),
              Text(
                "Configuracion Bancaria",
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700, color: kWebTextPrimary),
              ),
              const SizedBox(height: 12),
              Text(
                "Aqui registras la cuenta bancaria que recibe tus pagos. "
                "Necesitas CLABE, RFC del titular y una identificacion oficial. "
                "Verificacion automatica en menos de 24 horas.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: kWebTextSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              ShaderMask(
                shaderCallback: (b) => kWebBrandGradient.createShader(b),
                child: Text(
                  "Sin comisiones por dispersion. Pagos directos a tu cuenta.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
