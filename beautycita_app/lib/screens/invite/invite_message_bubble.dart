import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/constants.dart';

/// WhatsApp-style outgoing message bubble for the invite flow.
class InviteMessageBubble extends StatelessWidget {
  final String? message;
  final bool isGenerating;
  final VoidCallback? onRedo;

  const InviteMessageBubble({
    super.key,
    this.message,
    this.isGenerating = false,
    this.onRedo,
  });

  // Adapt bubble color to theme — light green in light mode, dark green-tint in dark
  Color _bubbleBg(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF1A3A2A) : const Color(0xFFDCF8C6);
  }

  Color _textColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFFE0E0E0) : const Color(0xFF1B1B1B);
  }
  static const _tailSize = 8.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Spacer(flex: 1),
        Flexible(
          flex: 5,
          child: CustomPaint(
            painter: _BubbleTailPainter(color: _bubbleBg(context)),
            child: Container(
              margin: const EdgeInsets.only(right: _tailSize),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              decoration: BoxDecoration(
                color: _bubbleBg(context),
                borderRadius: BorderRadius.circular(AppConstants.radiusSM),
              ),
              child: isGenerating ? _buildShimmer() : _buildContent(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message != null)
          Text(
            message!,
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: _textColor(context),
              height: 1.4,
            ),
          ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Aphrodite badge
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFec4899), Color(0xFF9333ea)],
              ).createShader(bounds),
              child: Text(
                'Creado por Aphrodite',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                  color: Colors.white, // masked by shader
                ),
              ),
            ),
            if (onRedo != null) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  onPressed: onRedo,
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Color(0xFF757575),
                  ),
                  tooltip: 'Regenerar',
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildShimmer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ShimmerLine(width: 220),
        const SizedBox(height: 8),
        _ShimmerLine(width: 180),
        const SizedBox(height: 8),
        _ShimmerLine(width: 140),
      ],
    );
  }
}

/// Animated shimmer bar.
class _ShimmerLine extends StatefulWidget {
  final double width;

  const _ShimmerLine({required this.width});

  @override
  State<_ShimmerLine> createState() => _ShimmerLineState();
}

class _ShimmerLineState extends State<_ShimmerLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppConstants.shimmerAnimation,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: _animation.value),
            borderRadius: BorderRadius.circular(6),
          ),
        );
      },
    );
  }
}

/// Paints a small WhatsApp-style tail on the right side of the bubble.
class _BubbleTailPainter extends CustomPainter {
  final Color color;

  _BubbleTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width - 8, size.height - 18)
      ..lineTo(size.width, size.height - 8)
      ..lineTo(size.width - 8, size.height - 4)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
