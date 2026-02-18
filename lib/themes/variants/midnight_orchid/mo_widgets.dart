import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── MOColors – brightness-aware color set ───────────────────────────────────
class MOColors {
  final Color surface, card;
  final Color orchidPink, orchidPurple, orchidDeep, orchidLight;
  final Color text, textSecondary;
  final LinearGradient orchidGradient, orchidGradientVertical;

  const MOColors._({
    required this.surface, required this.card,
    required this.orchidPink, required this.orchidPurple,
    required this.orchidDeep, required this.orchidLight,
    required this.text, required this.textSecondary,
    required this.orchidGradient, required this.orchidGradientVertical,
  });

  static const dark = MOColors._(
    surface: Color(0xFF0D0618),
    card: Color(0xFF1A0A2E),
    orchidPink: Color(0xFFDA70D6),
    orchidPurple: Color(0xFF9B59B6),
    orchidDeep: Color(0xFF3D1A6E),
    orchidLight: Color(0xFFE8A0E8),
    text: Color(0xFFF3E5F5),
    textSecondary: Color(0xFFCE93D8),
    orchidGradient: LinearGradient(
      colors: [Color(0xFF9B59B6), Color(0xFFDA70D6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    orchidGradientVertical: LinearGradient(
      colors: [Color(0xFFDA70D6), Color(0xFF9B59B6)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );

  static const light = MOColors._(
    surface: Color(0xFFF8F0FA),
    card: Color(0xFFFFFFFF),
    orchidPink: Color(0xFFAD1457),
    orchidPurple: Color(0xFF7B1FA2),
    orchidDeep: Color(0x66CE93D8),
    orchidLight: Color(0xFFE040FB),
    text: Color(0xFF2D1040),
    textSecondary: Color(0xFF6A3D7D),
    orchidGradient: LinearGradient(
      colors: [Color(0xFF7B1FA2), Color(0xFFAD1457)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    orchidGradientVertical: LinearGradient(
      colors: [Color(0xFFAD1457), Color(0xFF7B1FA2)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );

  static MOColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

// ─── Bioluminescent Botanical Garden – Color Palette ────────────────────────
const moSurface = Color(0xFF0D0618);
const moCard = Color(0xFF1A0A2E);
const moOrchidPink = Color(0xFFDA70D6);
const moOrchidPurple = Color(0xFF9B59B6);
const moOrchidDeep = Color(0xFF3D1A6E);
const moOrchidLight = Color(0xFFE8A0E8);

// Legacy aliases (keep other files compiling)
const moAccent = moOrchidPink;
const moPrimary = moOrchidPurple;
const moCardBorder = moOrchidDeep;

const moOrchidGradient = LinearGradient(
  colors: [moOrchidPurple, moOrchidPink],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const moOrchidGradientVertical = LinearGradient(
  colors: [moOrchidPink, moOrchidPurple],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);

// ─── MOOrchidGlow ────────────────────────────────────────────────────────────
/// Wraps child with orchid glow BoxShadow.
class MOOrchidGlow extends StatelessWidget {
  final Widget child;
  final double blurRadius;
  final double spread;
  final Color color;

  const MOOrchidGlow({
    super.key,
    required this.child,
    this.blurRadius = 24,
    this.spread = -4,
    this.color = moOrchidPink,
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

// ─── MOFloatingParticles ─────────────────────────────────────────────────────
/// Stack of floating particles with configurable count, color, size range.
class MOFloatingParticles extends StatelessWidget {
  final int count;
  final Color color;
  final double minSize;
  final double maxSize;
  final int seedOffset;

  const MOFloatingParticles({
    super.key,
    this.count = 20,
    this.color = moOrchidPink,
    this.minSize = 1.0,
    this.maxSize = 3.0,
    this.seedOffset = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(
        count,
        (i) => MOOrchidParticle(
          index: i + seedOffset,
          baseColor: color,
          minSize: minSize,
          maxSize: maxSize,
        ),
      ),
    );
  }
}

// ─── MOOrganicClipper ────────────────────────────────────────────────────────
/// CustomClipper that generates organic blob contour seeded by index.
class MOOrganicClipper extends CustomClipper<Path> {
  final int seed;

  const MOOrganicClipper({required this.seed});

  @override
  Path getClip(Size size) {
    return _buildOrganicPath(size, seed);
  }

  @override
  bool shouldReclip(MOOrganicClipper oldClipper) => oldClipper.seed != seed;
}

Path _buildOrganicPath(Size size, int seed) {
  final rng = math.Random(seed * 31 + 7);
  final w = size.width;
  final h = size.height;

  // Generate 8 control points around the perimeter with organic offsets
  // Top-left corner radius
  final tlR = 20.0 + rng.nextDouble() * 24;
  // Top-right corner radius
  final trR = 18.0 + rng.nextDouble() * 28;
  // Bottom-right corner radius
  final brR = 22.0 + rng.nextDouble() * 20;
  // Bottom-left corner radius
  final blR = 16.0 + rng.nextDouble() * 26;

  // Organic bulge on each side (positive = outward, negative = inward)
  final topBulge = (rng.nextDouble() - 0.35) * 12;
  final rightBulge = (rng.nextDouble() - 0.35) * 10;
  final bottomBulge = (rng.nextDouble() - 0.35) * 14;
  final leftBulge = (rng.nextDouble() - 0.35) * 10;

  final path = Path();

  // Start at top edge after top-left corner
  path.moveTo(tlR, 0);

  // Top edge with organic curve
  path.cubicTo(
    w * 0.33, -topBulge,
    w * 0.67, -topBulge,
    w - trR, 0,
  );

  // Top-right corner
  path.quadraticBezierTo(w, 0, w, trR);

  // Right edge with organic curve
  path.cubicTo(
    w + rightBulge, h * 0.33,
    w + rightBulge, h * 0.67,
    w, h - brR,
  );

  // Bottom-right corner
  path.quadraticBezierTo(w, h, w - brR, h);

  // Bottom edge with organic curve
  path.cubicTo(
    w * 0.67, h + bottomBulge,
    w * 0.33, h + bottomBulge,
    blR, h,
  );

  // Bottom-left corner
  path.quadraticBezierTo(0, h, 0, h - blR);

  // Left edge with organic curve
  path.cubicTo(
    -leftBulge, h * 0.67,
    -leftBulge, h * 0.33,
    0, tlR,
  );

  // Top-left corner
  path.quadraticBezierTo(0, 0, tlR, 0);

  path.close();
  return path;
}

// ─── MOOrganicCard ───────────────────────────────────────────────────────────
/// ClipPath with organic blob shape + orchid border + inner glow.
class MOOrganicCard extends StatelessWidget {
  final Widget child;
  final int seed;
  final Color glowColor;
  final double glowIntensity;
  final EdgeInsetsGeometry? padding;

  const MOOrganicCard({
    super.key,
    required this.child,
    required this.seed,
    this.glowColor = moOrchidPink,
    this.glowIntensity = 0.08,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OrganicCardPainter(
        seed: seed,
        glowColor: glowColor,
        glowIntensity: glowIntensity,
      ),
      child: ClipPath(
        clipper: MOOrganicClipper(seed: seed),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

class _OrganicCardPainter extends CustomPainter {
  final int seed;
  final Color glowColor;
  final double glowIntensity;

  _OrganicCardPainter({
    required this.seed,
    required this.glowColor,
    required this.glowIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildOrganicPath(size, seed);

    // Fill
    final fillPaint = Paint()
      ..color = moCard
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Border glow
    final borderPaint = Paint()
      ..color = moOrchidDeep.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(path, borderPaint);

    // Inner glow (shadow drawn outside)
    final glowPaint = Paint()
      ..color = glowColor.withValues(alpha: glowIntensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 16)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, glowPaint);
  }

  @override
  bool shouldRepaint(_OrganicCardPainter oldDelegate) =>
      oldDelegate.seed != seed || oldDelegate.glowIntensity != glowIntensity;
}

// ─── MOOrchidButton ──────────────────────────────────────────────────────────
/// Pill button with orchid gradient fill.
class MOOrchidButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final double height;
  final IconData? icon;

  const MOOrchidButton({
    super.key,
    required this.label,
    this.onTap,
    this.height = 52,
    this.icon,
  });

  @override
  State<MOOrchidButton> createState() => _MOOrchidButtonState();
}

class _MOOrchidButtonState extends State<MOOrchidButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
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
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            gradient: moOrchidGradient,
            borderRadius: BorderRadius.circular(widget.height / 2),
            boxShadow: [
              BoxShadow(
                color: moOrchidPink.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: GoogleFonts.quicksand(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── MOLoadingDots ───────────────────────────────────────────────────────────
/// Orchid-colored loading dots.
class MOLoadingDots extends StatefulWidget {
  const MOLoadingDots({super.key});

  @override
  State<MOLoadingDots> createState() => _MOLoadingDotsState();
}

class _MOLoadingDotsState extends State<MOLoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
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
          builder: (_, __) {
            final delay = i * 0.2;
            final v = ((_ctrl.value - delay) % 1.0).clamp(0.0, 1.0);
            final opacity = math.sin(v * math.pi).clamp(0.25, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: moOrchidPurple.withValues(alpha: opacity),
              ),
            );
          },
        );
      }),
    );
  }
}

// ─── MOConcaveBottomNav ───────────────────────────────────────────────────────
/// Bottom nav bar with a genuine concave valley shape using CustomClipper.
class MOConcaveBottomNav extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTap;

  const MOConcaveBottomNav({
    super.key,
    required this.activeIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _ConcaveValleyClipper(),
      child: Container(
        decoration: BoxDecoration(
          color: moCard,
          boxShadow: [
            BoxShadow(
              color: moOrchidPink.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 70,
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Reservar',
                  isActive: activeIndex == 0,
                  onTap: () => onTap(0),
                ),
                _NavItem(
                  icon: Icons.calendar_month_rounded,
                  label: 'Mis Citas',
                  isActive: activeIndex == 1,
                  onTap: () => onTap(1),
                ),
                _NavItem(
                  icon: Icons.person_outline_rounded,
                  label: 'Perfil',
                  isActive: activeIndex == 2,
                  onTap: () => onTap(2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Creates a concave valley shape — the center dips DOWN like a bowl.
class _ConcaveValleyClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const valleyDepth = 22.0;
    const valleyWidth = 0.5; // center 50% of width
    final vLeft = size.width * (0.5 - valleyWidth / 2);
    final vRight = size.width * (0.5 + valleyWidth / 2);

    final path = Path();
    // Start top-left at full height (no clip on left side)
    path.moveTo(0, 0);
    // Flat left section
    path.lineTo(vLeft - 40, 0);
    // Smooth curve down into valley
    path.cubicTo(
      vLeft, 0,
      vLeft + 20, valleyDepth,
      size.width / 2, valleyDepth,
    );
    // Smooth curve back up from valley
    path.cubicTo(
      vRight - 20, valleyDepth,
      vRight, 0,
      vRight + 40, 0,
    );
    // Flat right section
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_ConcaveValleyClipper _) => false;
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isActive)
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          moOrchidPink.withValues(alpha: 0.28),
                          moOrchidPurple.withValues(alpha: 0.10),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        moOrchidGradient.createShader(bounds),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                ],
              )
            else
              Icon(icon, color: moOrchidDeep.withValues(alpha: 0.9), size: 22),
            const SizedBox(height: 4),
            isActive
                ? ShaderMask(
                    shaderCallback: (b) => moOrchidGradient.createShader(b),
                    child: Text(
                      label,
                      style: GoogleFonts.quicksand(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  )
                : Text(
                    label,
                    style: GoogleFonts.quicksand(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: moOrchidDeep.withValues(alpha: 0.9),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

// ─── MOGlowCard (legacy compat) ───────────────────────────────────────────────
class MOGlowCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final double glowIntensity;
  final Color? background;

  const MOGlowCard({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.padding,
    this.glowIntensity = 0.12,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background ?? moCard,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: moOrchidDeep, width: 1),
        boxShadow: [
          BoxShadow(
            color: moOrchidPink.withValues(alpha: glowIntensity),
            blurRadius: 24,
            spreadRadius: -4,
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─── MOOrchidDivider ──────────────────────────────────────────────────────────
class MOOrchidDivider extends StatelessWidget {
  const MOOrchidDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            moOrchidPurple.withValues(alpha: 0.0),
            moOrchidPurple.withValues(alpha: 0.35),
            moOrchidPurple.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

// ─── MOOrchidParticle ──────────────────────────────────────────────────────────
/// A single floating orchid particle with slow organic drift.
class MOOrchidParticle extends StatefulWidget {
  final int index;
  final double baseOpacity;
  final Color? baseColor;
  final double minSize;
  final double maxSize;

  const MOOrchidParticle({
    super.key,
    required this.index,
    this.baseOpacity = 1.0,
    this.baseColor,
    this.minSize = 1.5,
    this.maxSize = 4.0,
  });

  @override
  State<MOOrchidParticle> createState() => _MOOrchidParticleState();
}

class _MOOrchidParticleState extends State<MOOrchidParticle>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late double _startX, _startY, _size, _opacity, _driftFactor;
  late Color _color;

  static const _colors = [moOrchidPink, moOrchidPurple, moOrchidLight];

  @override
  void initState() {
    super.initState();
    final rng = math.Random(widget.index * 37 + 13);
    _startX = rng.nextDouble();
    _startY = rng.nextDouble();
    _size = widget.minSize + rng.nextDouble() * (widget.maxSize - widget.minSize);
    _opacity = (0.10 + rng.nextDouble() * 0.25) * widget.baseOpacity;
    _color = widget.baseColor ?? _colors[rng.nextInt(_colors.length)];
    _driftFactor = 0.018 + rng.nextDouble() * 0.022;

    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 5000 + rng.nextInt(5000)),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        final dx = math.sin(t * math.pi) * _driftFactor;
        final dy = math.cos(t * math.pi * 1.3) * _driftFactor * 0.7;
        final glow = 0.5 + t * 0.5;
        return Positioned(
          left: (_startX + dx).clamp(0.0, 1.0) * size.width,
          top: (_startY + dy).clamp(0.0, 1.0) * size.height,
          child: Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _color.withValues(alpha: _opacity * glow),
              boxShadow: [
                BoxShadow(
                  color: _color.withValues(alpha: _opacity * 0.4 * glow),
                  blurRadius: _size * 2.5,
                  spreadRadius: _size * 0.4,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── MOPulseGlow ──────────────────────────────────────────────────────────────
class MOPulseGlow extends StatefulWidget {
  final double radius;
  final Color color;
  final Duration duration;

  const MOPulseGlow({
    super.key,
    this.radius = 120,
    this.color = moOrchidPink,
    this.duration = const Duration(milliseconds: 2200),
  });

  @override
  State<MOPulseGlow> createState() => _MOPulseGlowState();
}

class _MOPulseGlowState extends State<MOPulseGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale, _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
    _scale = Tween(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _opacity = Tween(begin: 0.08, end: 0.22).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
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
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Container(
          width: widget.radius * 2,
          height: widget.radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                widget.color.withValues(alpha: _opacity.value),
                widget.color.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── MOGradientText ────────────────────────────────────────────────────────────
class MOGradientText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const MOGradientText({super.key, required this.text, required this.style});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => moOrchidGradient.createShader(bounds),
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }
}
