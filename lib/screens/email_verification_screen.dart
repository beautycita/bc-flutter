import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/constants.dart';
import '../config/theme_extension.dart';
import '../providers/security_provider.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  final VoidCallback onSkip;
  final void Function(String email) onComplete;

  const EmailVerificationScreen({
    super.key,
    required this.onSkip,
    required this.onComplete,
  });

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  bool _googleLoading = false;
  bool _emailLoading = false;
  String? _emailError;
  bool _hasTriggeredComplete = false;

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim());
  }

  Future<void> _handleGoogleLink() async {
    setState(() {
      _googleLoading = true;
    });

    try {
      await ref.read(securityProvider.notifier).linkGoogle();
    } finally {
      if (mounted) {
        setState(() {
          _googleLoading = false;
        });
      }
    }
  }

  Future<void> _handleEmailSubmit() async {
    final email = _emailController.text.trim();

    if (!_isValidEmail(email)) {
      setState(() {
        _emailError = 'Ingresa un email válido';
      });
      return;
    }

    setState(() {
      _emailError = null;
      _emailLoading = true;
    });

    HapticFeedback.lightImpact();

    try {
      await ref.read(securityProvider.notifier).addEmail(email);
      if (mounted && !_hasTriggeredComplete) {
        _hasTriggeredComplete = true;
        widget.onComplete(email);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _emailError = 'No se pudo guardar el email. Intenta de nuevo.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _emailLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final securityState = ref.watch(securityProvider);
    final theme = Theme.of(context);
    final bcTheme = theme.extension<BCThemeExtension>()!;

    // React to Google link success
    ref.listen(securityProvider, (previous, next) {
      if (!_hasTriggeredComplete &&
          next.isGoogleLinked &&
          next.email != null &&
          next.email!.isNotEmpty) {
        _hasTriggeredComplete = true;
        widget.onComplete(next.email!);
      }
    });

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingLG,
              vertical: AppConstants.paddingXL,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: AppConstants.paddingXL),

                // Success indicator
                _SuccessBadge(),

                const SizedBox(height: AppConstants.paddingLG),

                // Heading
                Text(
                  'Recibe tu recibo por email',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                    height: 1.3,
                  ),
                ),

                const SizedBox(height: AppConstants.paddingSM),

                // Subtitle
                Text(
                  'Te enviaremos el detalle de tu cita',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withOpacity(0.55),
                    fontWeight: FontWeight.w400,
                  ),
                ),

                const SizedBox(height: AppConstants.paddingXL),

                // Google One Tap button
                _GoogleButton(
                  loading: _googleLoading || securityState.isLoading,
                  onTap: _googleLoading || securityState.isLoading
                      ? null
                      : _handleGoogleLink,
                ),

                const SizedBox(height: AppConstants.paddingLG),

                // Divider
                _DividerRow(label: 'O ingresa tu email'),

                const SizedBox(height: AppConstants.paddingLG),

                // Email field
                TextField(
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  onSubmitted: (_) => _handleEmailSubmit(),
                  onChanged: (_) {
                    if (_emailError != null) {
                      setState(() {
                        _emailError = null;
                      });
                    }
                  },
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'tu@email.com',
                    hintStyle: GoogleFonts.nunito(
                      fontSize: 15,
                      color: theme.colorScheme.onSurface.withOpacity(0.35),
                    ),
                    errorText: _emailError,
                    prefixIcon: Icon(
                      Icons.mail_outline_rounded,
                      size: 20,
                      color: theme.colorScheme.onSurface.withOpacity(0.45),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.5),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.paddingMD,
                      vertical: AppConstants.paddingMD,
                    ),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMD),
                      borderSide: BorderSide(
                        color:
                            theme.colorScheme.onSurface.withOpacity(0.12),
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMD),
                      borderSide: BorderSide(
                        color:
                            theme.colorScheme.onSurface.withOpacity(0.12),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMD),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMD),
                      borderSide: BorderSide(
                        color: theme.colorScheme.error,
                        width: 1,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMD),
                      borderSide: BorderSide(
                        color: theme.colorScheme.error,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppConstants.paddingMD),

                // Gold gradient submit button
                _GoldGradientButton(
                  label: 'Enviar recibo',
                  loading: _emailLoading,
                  gradient: bcTheme.goldGradientDirectional(),
                  onTap: _emailLoading ? null : _handleEmailSubmit,
                ),

                const SizedBox(height: AppConstants.paddingXL),

                // Skip option
                GestureDetector(
                  onTap: widget.onSkip,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppConstants.paddingSM,
                    ),
                    child: Text(
                      'Omitir',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                        decoration: TextDecoration.underline,
                        decorationColor:
                            theme.colorScheme.onSurface.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppConstants.paddingMD),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _SuccessBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle_rounded,
            size: 44,
            color: Colors.green.shade600,
          ),
        ),
        const SizedBox(height: AppConstants.paddingSM),
        Text(
          'Pago exitoso',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.green.shade700,
          ),
        ),
      ],
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onTap;

  const _GoogleButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF3C4043),
          side: BorderSide(
            color: const Color(0xFFDADCE0),
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppConstants.radiusMD),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingMD,
          ),
        ),
        child: loading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: const Color(0xFF4285F4),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GoogleColorIcon(),
                  const SizedBox(width: 10),
                  Text(
                    'Continuar con Google',
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF3C4043),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GoogleColorIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw a simple stylized G using colored arcs
    final paintBlue = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    final paintRed = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    final paintYellow = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    final paintGreen = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    const toRad = 3.14159265 / 180.0;

    final rect = Rect.fromCircle(center: center, radius: radius - 1.6);

    // Blue arc (top-right, wrapping)
    canvas.drawArc(rect, -60 * toRad, 110 * toRad, false, paintBlue);
    // Red arc (top-left)
    canvas.drawArc(rect, (180 + 30) * toRad, 110 * toRad, false, paintRed);
    // Yellow arc (bottom-left)
    canvas.drawArc(rect, (180 + 140) * toRad, 60 * toRad, false, paintYellow);
    // Green arc (bottom-right)
    canvas.drawArc(rect, (360 - 80) * toRad, 80 * toRad, false, paintGreen);

    // Horizontal bar for "G"
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(center.dx, center.dy),
      Offset(center.dx + radius - 1.6, center.dy),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DividerRow extends StatelessWidget {
  final String label;

  const _DividerRow({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dividerColor = theme.colorScheme.onSurface.withOpacity(0.15);

    return Row(
      children: [
        Expanded(child: Divider(color: dividerColor, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingSM,
          ),
          child: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ),
        Expanded(child: Divider(color: dividerColor, thickness: 1)),
      ],
    );
  }
}

class _GoldGradientButton extends StatelessWidget {
  final String label;
  final bool loading;
  final Gradient gradient;
  final VoidCallback? onTap;

  const _GoldGradientButton({
    required this.label,
    required this.loading,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          opacity: onTap == null ? 0.55 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            decoration: BoxDecoration(
              gradient: onTap != null ? gradient : null,
              color: onTap == null
                  ? Theme.of(context).colorScheme.onSurface.withOpacity(0.12)
                  : null,
              borderRadius:
                  BorderRadius.circular(AppConstants.radiusMD),
              boxShadow: onTap != null
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
