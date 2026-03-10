import 'package:flutter/material.dart';

import '../config/constants.dart';

/// A hollow outlined button that plays a brand-gradient shimmer across its
/// label on tap, then fires [onPressed] after the animation completes (~600ms).
///
/// While the shimmer is running the button ignores additional taps.
class ShimmerOutlinedButton extends StatefulWidget {
  const ShimmerOutlinedButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  State<ShimmerOutlinedButton> createState() => _ShimmerOutlinedButtonState();
}

class _ShimmerOutlinedButtonState extends State<ShimmerOutlinedButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _shimmering = false;

  // Brand gradient colors (pink → purple → blue).
  static const _brandColors = [
    Color(0xFFEC4899),
    Color(0xFF9333EA),
    Color(0xFF3B82F6),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addStatusListener(_onAnimationStatus);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() => _shimmering = false);
      _controller.reset();
      widget.onPressed?.call();
    }
  }

  void _handleTap() {
    if (_shimmering || widget.onPressed == null) return;
    setState(() => _shimmering = true);
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: widget.onPressed != null ? _handleTap : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(
            vertical: AppConstants.paddingMD,
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            if (!_shimmering) return child!;
            return ShaderMask(
              shaderCallback: (bounds) {
                // Sweep a narrow gradient band from left (-1) to right (+2).
                final dx = _controller.value * 3.0 - 1.0;
                return LinearGradient(
                  colors: _brandColors,
                  stops: const [0.0, 0.5, 1.0],
                  begin: Alignment(dx - 0.3, 0),
                  end: Alignment(dx + 0.3, 0),
                ).createShader(bounds);
              },
              blendMode: BlendMode.srcIn,
              child: child,
            );
          },
          child: _buildContent(primary),
        ),
      ),
    );
  }

  Widget _buildContent(Color color) {
    if (widget.icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, size: 20),
          const SizedBox(width: 8),
          Text(
            widget.label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ],
      );
    }
    return Text(
      widget.label,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
    );
  }
}
