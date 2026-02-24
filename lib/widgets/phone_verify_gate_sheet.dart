import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/constants.dart';
import '../config/theme_extension.dart';
import '../providers/profile_provider.dart';

Future<bool> showPhoneVerifyGate(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const PhoneVerifyGateSheet(),
  );
  return result == true;
}

class PhoneVerifyGateSheet extends ConsumerStatefulWidget {
  const PhoneVerifyGateSheet({super.key});

  @override
  ConsumerState<PhoneVerifyGateSheet> createState() =>
      _PhoneVerifyGateSheetState();
}

class _PhoneVerifyGateSheetState extends ConsumerState<PhoneVerifyGateSheet> {
  int _step = 1;
  final _phoneController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(6, (_) => FocusNode());
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final existingPhone = ref.read(profileProvider).phone;
    if (existingPhone != null && existingPhone.isNotEmpty) {
      final stripped = existingPhone.replaceAll('+52', '').replaceAll(' ', '');
      _phoneController.text = stripped;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _formattedPhone => '+52${_phoneController.text.trim()}';

  String get _collectedOtp =>
      _otpControllers.map((c) => c.text).join();

  Future<void> _onSendCode() async {
    setState(() => _errorMessage = null);
    final digits = _phoneController.text.trim();
    if (digits.length != 10) {
      setState(() => _errorMessage = 'Ingresa 10 digitos');
      return;
    }
    final notifier = ref.read(profileProvider.notifier);
    await notifier.updatePhone(_formattedPhone);
    final success = await notifier.sendPhoneOtp();
    if (!mounted) return;
    if (success == true || success == null) {
      setState(() => _step = 2);
    } else {
      setState(() => _errorMessage = 'Error al enviar el codigo. Intenta de nuevo.');
    }
  }

  Future<void> _onVerify() async {
    setState(() => _errorMessage = null);
    final otp = _collectedOtp;
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Ingresa los 6 digitos');
      return;
    }
    final notifier = ref.read(profileProvider.notifier);
    final success = await notifier.verifyPhoneOtp(otp);
    if (!mounted) return;
    if (success == true || success == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _errorMessage = 'Codigo incorrecto. Intenta de nuevo.');
    }
  }

  Future<void> _onResend() async {
    setState(() => _errorMessage = null);
    for (final c in _otpControllers) {
      c.clear();
    }
    if (_otpFocusNodes.isNotEmpty) {
      _otpFocusNodes.first.requestFocus();
    }
    await ref.read(profileProvider.notifier).sendPhoneOtp();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bcTheme = theme.extension<BCThemeExtension>()!;
    final isLoading = ref.watch(profileProvider).isLoading;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusXL),
        ),
      ),
      padding: EdgeInsets.only(
        left: AppConstants.paddingLG,
        right: AppConstants.paddingLG,
        top: AppConstants.paddingMD,
        bottom: AppConstants.paddingLG + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDragHandle(theme),
          const SizedBox(height: AppConstants.paddingLG),
          if (_step == 1)
            _buildStep1(bcTheme, isLoading)
          else
            _buildStep2(bcTheme, isLoading),
        ],
      ),
    );
  }

  Widget _buildDragHandle(ThemeData theme) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withOpacity(0.2),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildStep1(BCThemeExtension bcTheme, bool isLoading) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Verifica tu telefono',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF5A0A2D),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppConstants.paddingMD),
        Text(
          'Para confirmar tu reserva necesitamos verificar tu numero',
          style: GoogleFonts.nunito(
            fontSize: 14,
            color: Colors.black54,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppConstants.paddingLG),
        _buildPhoneField(),
        if (_errorMessage != null) ...[
          const SizedBox(height: AppConstants.paddingMD),
          _buildErrorText(_errorMessage!),
        ],
        const SizedBox(height: AppConstants.paddingLG),
        _buildGradientButton(
          bcTheme: bcTheme,
          label: 'Enviar codigo',
          isLoading: isLoading,
          onTap: isLoading ? null : _onSendCode,
        ),
        const SizedBox(height: AppConstants.paddingMD),
      ],
    );
  }

  Widget _buildStep2(BCThemeExtension bcTheme, bool isLoading) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Ingresa el codigo',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF5A0A2D),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppConstants.paddingMD),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_outlined, color: Color(0xFF25D366), size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Enviamos un codigo a $_formattedPhone via WhatsApp',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.paddingLG),
        _buildOtpRow(),
        if (_errorMessage != null) ...[
          const SizedBox(height: AppConstants.paddingMD),
          _buildErrorText(_errorMessage!),
        ],
        const SizedBox(height: AppConstants.paddingLG),
        _buildGradientButton(
          bcTheme: bcTheme,
          label: 'Verificar',
          isLoading: isLoading,
          onTap: isLoading ? null : _onVerify,
        ),
        const SizedBox(height: AppConstants.paddingMD),
        Center(
          child: TextButton(
            onPressed: isLoading ? null : _onResend,
            child: Text(
              'Reenviar codigo',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF5A0A2D),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      focusNode: _phoneFocusNode,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      style: GoogleFonts.nunito(fontSize: 16),
      decoration: InputDecoration(
        prefixText: '+52 ',
        prefixStyle: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF5A0A2D),
        ),
        hintText: '1234567890',
        hintStyle: GoogleFonts.nunito(color: Colors.black26),
        filled: true,
        fillColor: const Color(0xFFF5F0F3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          borderSide: const BorderSide(color: Color(0xFF5A0A2D), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildOtpRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (i) => _buildOtpBox(i)),
    );
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 44,
      height: 54,
      child: TextFormField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF5A0A2D),
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: const Color(0xFFF5F0F3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
            borderSide: const BorderSide(color: Color(0xFF5A0A2D), width: 1.5),
          ),
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (value) {
          if (value.length == 1 && index < 5) {
            _otpFocusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _otpFocusNodes[index - 1].requestFocus();
          }
        },
      ),
    );
  }

  Widget _buildGradientButton({
    required BCThemeExtension bcTheme,
    required String label,
    required bool isLoading,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: onTap != null
              ? bcTheme.goldGradientDirectional()
              : const LinearGradient(
                  colors: [Color(0xFFCCCCCC), Color(0xFFAAAAAA)],
                ),
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          boxShadow: onTap != null
              ? [
                  BoxShadow(
                    color: const Color(0xFFB8860B).withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  Widget _buildErrorText(String message) {
    return Text(
      message,
      style: GoogleFonts.nunito(
        fontSize: 13,
        color: Colors.red.shade700,
        fontWeight: FontWeight.w600,
      ),
      textAlign: TextAlign.center,
    );
  }
}
