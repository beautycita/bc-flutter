import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── CBColors — brightness-aware color palette ────────────────────────────────
class CBColors {
  final Color bg, card;
  final Color pink, pinkLight, lavender, peach;
  final Color text, textSoft;
  final Color border;

  const CBColors._({
    required this.bg, required this.card,
    required this.pink, required this.pinkLight,
    required this.lavender, required this.peach,
    required this.text, required this.textSoft,
    required this.border,
  });

  static const light = CBColors._(
    bg: Color(0xFFFFF8F5),
    card: Color(0xFFFFFFFF),
    pink: Color(0xFFE91E63),
    pinkLight: Color(0xFFFCE4EC),
    lavender: Color(0xFFCE93D8),
    peach: Color(0xFFFFCCBC),
    text: Color(0xFF2D1B30),
    textSoft: Color(0xFF5C3A5E),
    border: Color(0xFFFCE4EC),
  );

  static const dark = CBColors._(
    bg: Color(0xFF0C0810),
    card: Color(0xFF1A1020),
    pink: Color(0xFFFF6B9D),
    pinkLight: Color(0xFF3D1830),
    lavender: Color(0xFFCE93D8),
    peach: Color(0xFFFF8A80),
    text: Color(0xFFF0E5F0),
    textSoft: Color(0xFFB090B8),
    border: Color(0xFF3D1830),
  );

  static CBColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

// ─── Color palette (Zen Minimal Japanese) ─────────────────────────────────────
const cbBg = Color(0xFFFFF8F5);       // Warm white
const cbCard = Color(0xFFFFFFFF);     // Pure white cards
const cbPink = Color(0xFFE91E63);     // Primary pink
const cbPinkLight = Color(0xFFFCE4EC); // Light pink
const cbLavender = Color(0xFFCE93D8); // Lavender accent
const cbPeach = Color(0xFFFFCCBC);    // Peach accent
const cbText = Color(0xFF2D1B30);     // Dark text
const cbTextSoft = Color(0xFF5C3A5E); // Softer text

// Legacy aliases kept for cross-file compatibility
const cbOnSurface = cbText;
const cbBorder = cbPinkLight;

// ─── CBWatercolorBlob ──────────────────────────────────────────────────────────
/// Large blurred circle with soft color, animated slow drift.
class CBWatercolorBlob extends StatefulWidget {
  final Color color;
  final double size;
  final double driftAmplitude;
  final int durationSeconds;
  final int seed;

  const CBWatercolorBlob({
    super.key,
    required this.color,
    required this.size,
    this.driftAmplitude = 12.0,
    this.durationSeconds = 10,
    this.seed = 0,
  });

  @override
  State<CBWatercolorBlob> createState() => _CBWatercolorBlobState();
}

class _CBWatercolorBlobState extends State<CBWatercolorBlob>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late double _phaseX;
  late double _phaseY;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(widget.seed * 31 + 7);
    _phaseX = rng.nextDouble() * math.pi * 2;
    _phaseY = rng.nextDouble() * math.pi * 2;
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.durationSeconds),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value * math.pi * 2;
        final dx = math.sin(t + _phaseX) * widget.driftAmplitude;
        final dy = math.cos(t * 0.7 + _phaseY) * widget.driftAmplitude;
        return Transform.translate(
          offset: Offset(dx, dy),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
            ),
          ),
        );
      },
    );
  }
}

// ─── CBFloatingPetal ───────────────────────────────────────────────────────────
/// Small rotated ellipse that falls slowly and drifts sideways.
class CBFloatingPetal extends StatefulWidget {
  final int index;
  final double screenWidth;
  final double screenHeight;

  const CBFloatingPetal({
    super.key,
    required this.index,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  State<CBFloatingPetal> createState() => _CBFloatingPetalState();
}

class _CBFloatingPetalState extends State<CBFloatingPetal>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late double _startX;
  late double _size;
  late double _opacity;
  late double _driftFactor;
  late double _rotation;
  late Color _color;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(widget.index * 137 + 13);
    _startX = rng.nextDouble();
    _size = 4.0 + rng.nextDouble() * 4.0;
    _opacity = 0.15 + rng.nextDouble() * 0.10;
    _driftFactor = (rng.nextDouble() - 0.5) * 0.06;
    _rotation = rng.nextDouble() * math.pi * 2;
    _color = rng.nextBool() ? cbPink : cbLavender;

    final ms = 9000 + rng.nextInt(6000);
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: ms),
    )..repeat();
    _ctrl.value = rng.nextDouble();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final p = _ctrl.value;
        final y = -_size * 2 + p * (widget.screenHeight + _size * 4);
        final sway = math.sin(p * math.pi * 2.5 + _startX * math.pi * 2);
        final x = _startX * widget.screenWidth +
            sway * widget.screenWidth * 0.03 +
            _driftFactor * widget.screenWidth;
        final fadeIn = p < 0.08 ? p / 0.08 : 1.0;
        final fadeOut = p > 0.88 ? (1.0 - p) / 0.12 : 1.0;
        final alpha = _opacity * fadeIn * fadeOut;

        return Positioned(
          left: x,
          top: y,
          child: Transform.rotate(
            angle: _rotation + p * math.pi * 2,
            child: Container(
              width: _size * 0.65,
              height: _size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_size * 0.5),
                color: _color.withValues(alpha: alpha),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Legacy alias so splash screen still compiles
typedef CBPetalParticle = CBFloatingPetal;

// ─── CBSoftButton ──────────────────────────────────────────────────────────────
/// Minimal pink gradient pill button with press scale.
class CBSoftButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final double height;
  final Widget? leading;

  const CBSoftButton({
    super.key,
    required this.label,
    this.onTap,
    this.height = 52,
    this.leading,
  });

  @override
  State<CBSoftButton> createState() => _CBSoftButtonState();
}

class _CBSoftButtonState extends State<CBSoftButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _scale = Tween(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                cbPink,
                cbPink.withValues(alpha: 0.75),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(widget.height / 2),
            boxShadow: [
              BoxShadow(
                color: cbPink.withValues(alpha: 0.22),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.leading != null) ...[
                widget.leading!,
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: GoogleFonts.nunitoSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── CBLoadingDots ─────────────────────────────────────────────────────────────
/// Three pink dots pulsing sequentially.
class CBLoadingDots extends StatefulWidget {
  const CBLoadingDots({super.key});

  @override
  State<CBLoadingDots> createState() => _CBLoadingDotsState();
}

class _CBLoadingDotsState extends State<CBLoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final delay = i * 0.18;
            final v = ((_ctrl.value - delay) % 1.0).clamp(0.0, 1.0);
            final op = (math.sin(v * math.pi)).clamp(0.2, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cbPink.withValues(alpha: op),
              ),
            );
          },
        );
      }),
    );
  }
}

// ─── CBFloatingPill ────────────────────────────────────────────────────────────
/// Frosted white bottom navigation pill — two items, swipe-up handler.
class CBFloatingPill extends StatefulWidget {
  final bool myBookingsActive;
  final VoidCallback onMyBookingsTap;
  final VoidCallback onSwipeUp;

  const CBFloatingPill({
    super.key,
    this.myBookingsActive = false,
    required this.onMyBookingsTap,
    required this.onSwipeUp,
  });

  @override
  State<CBFloatingPill> createState() => _CBFloatingPillState();
}

class _CBFloatingPillState extends State<CBFloatingPill> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! < -80) {
          widget.onSwipeUp();
        }
      },
      child: Container(
        width: 180,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: cbPink.withValues(alpha: 0.10),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _PillItem(
              label: 'Servicios',
              isActive: !widget.myBookingsActive,
              onTap: () {},
            ),
            Container(
              width: 1,
              height: 20,
              color: cbPink.withValues(alpha: 0.15),
            ),
            _PillItem(
              label: 'Mis Citas',
              isActive: widget.myBookingsActive,
              onTap: widget.onMyBookingsTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _PillItem extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _PillItem({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isActive ? 4 : 0,
            height: isActive ? 4 : 0,
            margin: const EdgeInsets.only(bottom: 3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: cbPink,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.nunitoSans(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? cbPink : cbText.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── CBAccentLine ──────────────────────────────────────────────────────────────
/// Thin gradient line: pink to transparent.
class CBAccentLine extends StatelessWidget {
  final double width;
  final double height;

  const CBAccentLine({super.key, this.width = 40, this.height = 2});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cbPink, cbPink.withValues(alpha: 0.0)],
        ),
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}

// ─── CBWatercolorCard (kept for settings screen) ───────────────────────────────
class CBWatercolorCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? background;
  final bool elevated;

  const CBWatercolorCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 16,
    this.background,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background ?? cbCard,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: cbPink.withValues(alpha: 0.10),
          width: 1.0,
        ),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: cbPink.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: cbPink.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: child,
    );
  }
}

// ─── CBPetalDivider (kept for settings/auth screens) ──────────────────────────
class CBPetalDivider extends StatelessWidget {
  const CBPetalDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cbPink.withValues(alpha: 0.0),
            cbPink.withValues(alpha: 0.15),
            cbPink.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}
