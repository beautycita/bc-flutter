import 'package:flutter/material.dart';

/// Shimmer loading widget for skeleton states
class BCShimmer extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const BCShimmer({
    super.key,
    this.width = double.infinity,
    this.height = 200,
    this.borderRadius = 12,
  });

  @override
  State<BCShimmer> createState() => _BCShimmerState();
}

class _BCShimmerState extends State<BCShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          gradient: LinearGradient(
            begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
            end: Alignment(-1.0 + 2.0 * _controller.value + 1.0, 0),
            colors: [
              Colors.grey[300]!,
              Colors.grey[100]!,
              Colors.grey[300]!,
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated three-dot loading indicator
class BCLoadingDots extends StatefulWidget {
  const BCLoadingDots({super.key});

  @override
  State<BCLoadingDots> createState() => _BCLoadingDotsState();
}

class _BCLoadingDotsState extends State<BCLoadingDots>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      )..repeat(reverse: true);
    });
    for (var i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) _controllers[i].forward();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _controllers[i],
            builder: (_, __) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary.withValues(
                  alpha: 0.3 + _controllers[i].value * 0.7,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Centered loading spinner
class BCLoadingSpinner extends StatelessWidget {
  const BCLoadingSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: 'Cargando',
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
