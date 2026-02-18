import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── GlColors: brightness-aware color set ─────────────────────────────────────
class GlColors {
  final Color bgDeep, bgMid, surface2, surface3;
  final Color neonPink, neonCyan, neonPurple;
  final Color violet, indigo, teal, amber;
  final Color tint, borderWhite;
  final Color text, textSecondary, textMuted;
  final LinearGradient neonGradient, neonGradientVertical;

  const GlColors._({
    required this.bgDeep, required this.bgMid, required this.surface2, required this.surface3,
    required this.neonPink, required this.neonCyan, required this.neonPurple,
    required this.violet, required this.indigo, required this.teal, required this.amber,
    required this.tint, required this.borderWhite,
    required this.text, required this.textSecondary, required this.textMuted,
    required this.neonGradient, required this.neonGradientVertical,
  });

  static const dark = GlColors._(
    bgDeep: Color(0xFF0A0B1E),
    bgMid: Color(0xFF12143A),
    surface2: Color(0xFF1A1C4A),
    surface3: Color(0xFF0F3460),
    neonPink: Color(0xFFFF6B9D),
    neonCyan: Color(0xFF00E5FF),
    neonPurple: Color(0xFFB388FF),
    violet: Color(0xFFCE93D8),
    indigo: Color(0xFF9FA8DA),
    teal: Color(0xFF80DEEA),
    amber: Color(0xFFFFD54F),
    tint: Color(0x14FFFFFF),
    borderWhite: Color(0x26FFFFFF),
    text: Color(0xFFFFFFFF),
    textSecondary: Color(0xB3FFFFFF),
    textMuted: Color(0x80FFFFFF),
    neonGradient: LinearGradient(
      colors: [Color(0xFFFF6B9D), Color(0xFFB388FF), Color(0xFF00E5FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    neonGradientVertical: LinearGradient(
      colors: [Color(0xFFFF6B9D), Color(0xFFB388FF), Color(0xFF00E5FF)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );

  static const light = GlColors._(
    bgDeep: Color(0xFFF5F0FA),
    bgMid: Color(0xFFEDE5F5),
    surface2: Color(0xFFE5DDF0),
    surface3: Color(0xFFDDD5EB),
    neonPink: Color(0xFFE91E63),
    neonCyan: Color(0xFF00ACC1),
    neonPurple: Color(0xFF7E57C2),
    violet: Color(0xFF9C27B0),
    indigo: Color(0xFF5C6BC0),
    teal: Color(0xFF00838F),
    amber: Color(0xFFF57C00),
    tint: Color(0x0D000000),
    borderWhite: Color(0x1A000000),
    text: Color(0xFF1A1A2E),
    textSecondary: Color(0xFF5C5070),
    textMuted: Color(0xFF9088A0),
    neonGradient: LinearGradient(
      colors: [Color(0xFFE91E63), Color(0xFF7E57C2), Color(0xFF00ACC1)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    neonGradientVertical: LinearGradient(
      colors: [Color(0xFFE91E63), Color(0xFF7E57C2), Color(0xFF00ACC1)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );

  static GlColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

// ─── Glass Color Palette (legacy consts) ──────────────────────────────────────
const glBgDeep = Color(0xFF0A0B1E); // Deep navy background
const glBgMid = Color(0xFF12143A);
const glNeonPink = Color(0xFFFF6B9D);
const glNeonCyan = Color(0xFF00E5FF);
const glNeonPurple = Color(0xFFB388FF);

// Legacy aliases (kept for backwards compat across files)
const glScaffold = glBgDeep;
const glSurface = glBgMid;
const glSurface2 = Color(0xFF1A1C4A);
const glSurface3 = Color(0xFF0F3460);
const glPink = glNeonPink;
const glPurple = glNeonPurple;
const glBlue = glNeonCyan;
const glViolet = Color(0xFFCE93D8);
const glIndigo = Color(0xFF9FA8DA);
const glTeal = Color(0xFF80DEEA);
const glAmber = Color(0xFFFFD54F);

/// 8% white tint for glass panels
const glTint = Color(0x14FFFFFF);

/// 15% white for glass borders
const glBorderWhite = Color(0x26FFFFFF);

/// Neon gradient (pink → purple → cyan)
const glNeonGradient = LinearGradient(
  colors: [glNeonPink, glNeonPurple, glNeonCyan],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const glNeonGradientVertical = LinearGradient(
  colors: [glNeonPink, glNeonPurple, glNeonCyan],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);

/// Category accent colors — vivid neon palette
const glCategoryColors = [
  Color(0xFFFF6B9D),
  Color(0xFFB388FF),
  Color(0xFF00E5FF),
  Color(0xFFFF8A65),
  Color(0xFF80DEEA),
  Color(0xFFCE93D8),
  Color(0xFFFFD54F),
  Color(0xFF9FA8DA),
];

// ─── GlAuroraBackground ───────────────────────────────────────────────────────
/// Full-screen animated aurora: deep navy base with shifting neon radial orbs.
/// Uses multiple overlapping RadialGradients that orbit slowly.
class GlAuroraBackground extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const GlAuroraBackground({
    super.key,
    required this.child,
    this.duration = const Duration(seconds: 8),
  });

  @override
  State<GlAuroraBackground> createState() => _GlAuroraBackgroundState();
}

class _GlAuroraBackgroundState extends State<GlAuroraBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
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
      builder: (context, child) {
        final t = _controller.value;
        // Orb 1: pink — drifts top-left ↔ top-right
        final orb1x = -0.6 + t * 1.2;
        final orb1y = -0.8 + t * 0.4;
        // Orb 2: purple — drifts bottom-right ↔ bottom-left
        final orb2x = 0.8 - t * 1.0;
        final orb2y = 0.6 + t * 0.3;
        // Orb 3: cyan — drifts centre
        final orb3x = math.sin(t * math.pi * 2) * 0.5;
        final orb3y = math.cos(t * math.pi) * 0.3;

        return Container(
          decoration: const BoxDecoration(color: glBgDeep),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Orb 1 — pink
              Positioned.fill(
                child: _radialOrb(
                  Alignment(orb1x, orb1y),
                  glNeonPink.withValues(alpha: 0.22),
                  1.0,
                ),
              ),
              // Orb 2 — purple
              Positioned.fill(
                child: _radialOrb(
                  Alignment(orb2x, orb2y),
                  glNeonPurple.withValues(alpha: 0.18),
                  0.8,
                ),
              ),
              // Orb 3 — cyan
              Positioned.fill(
                child: _radialOrb(
                  Alignment(orb3x, orb3y),
                  glNeonCyan.withValues(alpha: 0.12),
                  0.6,
                ),
              ),
              // Content on top
              child!,
            ],
          ),
        );
      },
      child: widget.child,
    );
  }

  Widget _radialOrb(Alignment center, Color color, double radius) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: center,
          radius: radius,
          colors: [color, Colors.transparent],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}

// ─── GlFrostedPanel ───────────────────────────────────────────────────────────
/// Reusable frosted glass container.
/// ClipRRect → BackdropFilter(blur=20) → decorated Container.
class GlFrostedPanel extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final double blurSigma;
  final double tintOpacity;
  final double borderOpacity;
  final List<BoxShadow>? shadows;
  final Color? borderColor;

  const GlFrostedPanel({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.padding,
    this.blurSigma = 20,
    this.tintOpacity = 0.08,
    this.borderOpacity = 0.15,
    this.shadows,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: tintOpacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: (borderColor ?? Colors.white).withValues(alpha: borderOpacity),
              width: 1.0,
            ),
            boxShadow: shadows,
          ),
          child: child,
        ),
      ),
    );
  }
}

// Legacy alias for backwards compat
class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? tint;
  final double borderOpacity;
  final double blurSigma;
  final List<BoxShadow>? shadows;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.padding,
    this.tint,
    this.borderOpacity = 0.15,
    this.blurSigma = 20,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    return GlFrostedPanel(
      borderRadius: borderRadius,
      padding: padding ?? const EdgeInsets.all(16),
      blurSigma: blurSigma,
      tintOpacity: tint != null ? 0.08 : 0.08,
      borderOpacity: borderOpacity,
      shadows: shadows,
      child: child,
    );
  }
}

// ─── GlNeonButton ─────────────────────────────────────────────────────────────
/// Button with neon gradient border and frosted interior. Full-width by default.
class GlNeonButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final double height;
  final Widget? leading;

  const GlNeonButton({
    super.key,
    required this.label,
    this.onTap,
    this.height = 52,
    this.leading,
  });

  @override
  State<GlNeonButton> createState() => _GlNeonButtonState();
}

class _GlNeonButtonState extends State<GlNeonButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween(begin: 1.0, end: 0.96).animate(
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
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.height / 2),
            gradient: glNeonGradient,
            boxShadow: [
              BoxShadow(
                color: glNeonPink.withValues(alpha: 0.25),
                blurRadius: 16,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(1.5),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.height / 2 - 1),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(widget.height / 2 - 1),
                ),
                alignment: Alignment.center,
                child: widget.leading != null
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          widget.leading!,
                          const SizedBox(width: 8),
                          _buttonLabel(),
                        ],
                      )
                    : _buttonLabel(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buttonLabel() {
    return Text(
      widget.label,
      style: GoogleFonts.inter(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 15,
        letterSpacing: 1.0,
      ),
    );
  }
}

// Legacy alias
typedef GlassButton = GlNeonButton;

// ─── GlNeonBorder ─────────────────────────────────────────────────────────────
/// Animated rotating neon gradient border (SweepGradient sweep).
/// Used for the fingerprint circle on auth screen.
class GlNeonBorder extends StatefulWidget {
  final Widget child;
  final double size;
  final double borderWidth;
  final Duration duration;

  const GlNeonBorder({
    super.key,
    required this.child,
    this.size = 100,
    this.borderWidth = 2.5,
    this.duration = const Duration(seconds: 3),
  });

  @override
  State<GlNeonBorder> createState() => _GlNeonBorderState();
}

class _GlNeonBorderState extends State<GlNeonBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: widget.duration)..repeat();
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
      builder: (context, child) {
        return CustomPaint(
          painter: _NeonBorderPainter(
            progress: _controller.value,
            borderWidth: widget.borderWidth,
          ),
          child: child,
        );
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: widget.child,
      ),
    );
  }
}

class _NeonBorderPainter extends CustomPainter {
  final double progress;
  final double borderWidth;

  _NeonBorderPainter({required this.progress, required this.borderWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - borderWidth / 2;

    final rect = Rect.fromCircle(center: center, radius: radius);

    final sweepAngle = progress * 2 * math.pi;

    final gradient = SweepGradient(
      startAngle: sweepAngle,
      endAngle: sweepAngle + 2 * math.pi,
      colors: const [
        glNeonPink,
        glNeonPurple,
        glNeonCyan,
        glNeonPink,
      ],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 4);

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_NeonBorderPainter old) => old.progress != progress;
}

// ─── GlNeonDots ───────────────────────────────────────────────────────────────
/// Three neon pulsing dots loading indicator.
class GlNeonDots extends StatefulWidget {
  final Color color;
  const GlNeonDots({super.key, this.color = glNeonPink});

  @override
  State<GlNeonDots> createState() => _GlNeonDotsState();
}

class _GlNeonDotsState extends State<GlNeonDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final delay = i * 0.2;
            final value = ((_controller.value - delay) % 1.0).clamp(0.0, 1.0);
            final opacity = (math.sin(value * math.pi)).clamp(0.3, 1.0);
            const colors = [glNeonPink, glNeonPurple, glNeonCyan];
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors[i].withValues(alpha: opacity),
                boxShadow: [
                  BoxShadow(
                    color: colors[i].withValues(alpha: opacity * 0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
            );
          },
        );
      }),
    );
  }
}

// ─── GlFloatingParticle ───────────────────────────────────────────────────────
/// Small neon particle that drifts slowly across the screen.
class GlFloatingParticle extends StatefulWidget {
  final int index;
  const GlFloatingParticle({super.key, required this.index});

  @override
  State<GlFloatingParticle> createState() => _GlFloatingParticleState();
}

class _GlFloatingParticleState extends State<GlFloatingParticle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late double _startX, _startY, _size;
  late Color _color;

  static const _palette = [glNeonPink, glNeonPurple, glNeonCyan, glViolet, glTeal];

  @override
  void initState() {
    super.initState();
    final rng = math.Random(widget.index * 31 + 7);
    _startX = rng.nextDouble();
    _startY = rng.nextDouble();
    _size = 2.0 + rng.nextDouble() * 4.0;
    _color = _palette[rng.nextInt(_palette.length)];

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 5000 + rng.nextInt(5000)),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final drift = _controller.value * 0.05;
        final opacity = 0.1 + _controller.value * 0.35;
        return Positioned(
          left: (_startX + drift) * screenSize.width,
          top: (_startY - drift * 0.5) * screenSize.height,
          child: Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _color.withValues(alpha: opacity),
              boxShadow: [
                BoxShadow(
                  color: _color.withValues(alpha: opacity * 0.7),
                  blurRadius: _size * 2.5,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Legacy alias
typedef GlNeonParticle = GlFloatingParticle;

// ─── GlDivider ────────────────────────────────────────────────────────────────
class GlDivider extends StatelessWidget {
  const GlDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            glNeonPink.withValues(alpha: 0.0),
            glNeonPurple.withValues(alpha: 0.4),
            glNeonCyan.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

// ─── IridescentBorder ─────────────────────────────────────────────────────────
/// Animated rotating iridescent gradient border ring.
class IridescentBorder extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final double borderWidth;
  final Duration duration;

  const IridescentBorder({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.borderWidth = 1,
    this.duration = const Duration(seconds: 4),
  });

  @override
  State<IridescentBorder> createState() => _IridescentBorderState();
}

class _IridescentBorderState extends State<IridescentBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
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
      builder: (context, child) {
        final t = _controller.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: SweepGradient(
              center: Alignment.center,
              startAngle: t * math.pi * 2,
              endAngle: t * math.pi * 2 + math.pi * 2,
              colors: const [
                glNeonPink,
                glViolet,
                glNeonPurple,
                glNeonCyan,
                glTeal,
                glNeonPink,
              ],
            ),
          ),
          padding: EdgeInsets.all(widget.borderWidth),
          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(widget.borderRadius - widget.borderWidth),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

// ─── NeonGlow (util) ─────────────────────────────────────────────────────────
class NeonGlow extends StatelessWidget {
  final Widget child;
  final Color color;
  final double blurRadius;
  final double spread;

  const NeonGlow({
    super.key,
    required this.child,
    this.color = glNeonPink,
    this.blurRadius = 20,
    this.spread = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: blurRadius,
            spreadRadius: spread,
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─── AuroraGradient (legacy alias) ───────────────────────────────────────────
typedef AuroraGradient = GlAuroraBackground;
