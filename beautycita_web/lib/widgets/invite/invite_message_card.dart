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
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerCtrl;
  bool _redoHovering = false;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
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
            // Aphrodite attribution
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFec4899), Color(0xFF9333ea), Color(0xFF3b82f6)],
              ).createShader(bounds),
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
            // Redo button
            if (widget.onRedo != null)
              MouseRegion(
                onEnter: (_) => setState(() => _redoHovering = true),
                onExit: (_) => setState(() => _redoHovering = false),
                child: IconButton(
                  onPressed: widget.onRedo,
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
