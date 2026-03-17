import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Web-styled invite message card with Aphrodite attribution.
///
/// Shows the generated invite message with a left gradient border, or a
/// shimmer loading state while generating. Includes a redo button for
/// regeneration.
class InviteMessageCard extends StatefulWidget {
  const InviteMessageCard({
    required this.message,
    required this.isGenerating,
    this.onRedo,
    super.key,
  });

  final String? message;
  final bool isGenerating;
  final VoidCallback? onRedo;

  @override
  State<InviteMessageCard> createState() => _InviteMessageCardState();
}

class _InviteMessageCardState extends State<InviteMessageCard>
    with TickerProviderStateMixin {
  late AnimationController _shimmerCtrl;
  late AnimationController _badgeShimmerCtrl;
  late AnimationController _redoSpinCtrl;
  bool _redoHovering = false;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _badgeShimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _redoSpinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _badgeShimmerCtrl.dispose();
    _redoSpinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // Nothing to show
    if (widget.message == null && !widget.isGenerating) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant, width: 1),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left gradient border
          Container(
            width: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFec4899), Color(0xFF9333ea)],
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Content
          Expanded(
            child: widget.isGenerating
                ? _buildShimmer()
                : _buildContent(colors),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Message text
        Text(
          widget.message ?? '',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 14,
            color: colors.onSurface.withValues(alpha: 0.87),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        // Footer: Aphrodite badge + redo button
        Row(
          children: [
            // Aphrodite attribution with shimmer sweep
            AnimatedBuilder(
              animation: _badgeShimmerCtrl,
              builder: (context, child) {
                return ShaderMask(
                  shaderCallback: (bounds) {
                    final sweepPos = _badgeShimmerCtrl.value * 3 - 1;
                    return LinearGradient(
                      colors: const [
                        Color(0xFFec4899),
                        Color(0xFFFFFFFF),
                        Color(0xFF3b82f6),
                      ],
                      stops: [
                        (sweepPos - 0.2).clamp(0.0, 1.0),
                        sweepPos.clamp(0.0, 1.0),
                        (sweepPos + 0.2).clamp(0.0, 1.0),
                      ],
                    ).createShader(bounds);
                  },
                  child: child!,
                );
              },
              child: const Text(
                'Creado por Aphrodite',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                  color: Colors.white, // masked by shader
                ),
              ),
            ),
            const Spacer(),
            // Redo button with spin on tap
            if (widget.onRedo != null)
              MouseRegion(
                onEnter: (_) => setState(() => _redoHovering = true),
                onExit: (_) => setState(() => _redoHovering = false),
                child: AnimatedBuilder(
                  animation: _redoSpinCtrl,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _redoSpinCtrl.value * 2 * math.pi,
                      child: child,
                    );
                  },
                  child: IconButton(
                    onPressed: () {
                      _redoSpinCtrl.forward(from: 0);
                      widget.onRedo?.call();
                    },
                    icon: Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: _redoHovering
                          ? colors.primary
                          : colors.onSurface.withValues(alpha: 0.35),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    splashRadius: 18,
                    tooltip: 'Regenerar mensaje',
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildShimmer() {
    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (context, _) {
        final opacity = 0.3 + (_shimmerCtrl.value * 0.4); // 0.3 ↔ 0.7
        return Opacity(
          opacity: opacity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _shimmerBar(width: double.infinity),
              const SizedBox(height: 8),
              _shimmerBar(width: double.infinity),
              const SizedBox(height: 8),
              _shimmerBar(width: 180),
            ],
          ),
        );
      },
    );
  }

  Widget _shimmerBar({required double width}) {
    return Container(
      width: width,
      height: 14,
      decoration: BoxDecoration(
        color: const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
