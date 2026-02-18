import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── ELColors — brightness-aware color accessor ───────────────────────────────
class ELColors {
  final Color bg, surface, surface2, surface3;
  final Color gold, goldLight, goldDim;
  final Color emerald, emeraldDeep;
  final Color cardBorder;
  final Color text, textSecondary;
  final LinearGradient goldGradient;

  const ELColors._({
    required this.bg, required this.surface, required this.surface2, required this.surface3,
    required this.gold, required this.goldLight, required this.goldDim,
    required this.emerald, required this.emeraldDeep,
    required this.cardBorder,
    required this.text, required this.textSecondary,
    required this.goldGradient,
  });

  static const dark = ELColors._(
    bg: Color(0xFF0A1A0A),
    surface: Color(0xFF0F2A0F),
    surface2: Color(0xFF142814),
    surface3: Color(0xFF172F17),
    gold: Color(0xFFD4AF37),
    goldLight: Color(0xFFFFD700),
    goldDim: Color(0xFFB8961A),
    emerald: Color(0xFF4CAF50),
    emeraldDeep: Color(0xFF1B5E20),
    cardBorder: Color(0xFF1B5E20),
    text: Color(0xFFE8F5E9),
    textSecondary: Color(0xFFA5D6A7),
    goldGradient: LinearGradient(
      colors: [Color(0xFFB8961A), Color(0xFFD4AF37), Color(0xFFFFF8DC)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static const light = ELColors._(
    bg: Color(0xFFFAFAF0),
    surface: Color(0xFFF5F5E8),
    surface2: Color(0xFFEDE8D5),
    surface3: Color(0xFFE8E0C8),
    gold: Color(0xFFB8860B),
    goldLight: Color(0xFFD4AF37),
    goldDim: Color(0xFF8B6914),
    emerald: Color(0xFF2E7D32),
    emeraldDeep: Color(0xFFD4C9A8),
    cardBorder: Color(0xFFD4C9A8),
    text: Color(0xFF1A2A1A),
    textSecondary: Color(0xFF4A6040),
    goldGradient: LinearGradient(
      colors: [Color(0xFF8B6914), Color(0xFFB8860B), Color(0xFFD4AF37)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static ELColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

// ─── Color constants (Art Deco Structured Elegance) ──────────────────────────
const elBg = Color(0xFF0A1A0A);        // Deep dark green
const elSurface = Color(0xFF0F2A0F);   // Card green
const elSurface2 = Color(0xFF142814);  // Tab bar green
const elGold = Color(0xFFD4AF37);      // Gold primary
const elGoldLight = Color(0xFFFFD700); // Light gold
const elEmerald = Color(0xFF4CAF50);   // Emerald accent
const elEmeraldDeep = Color(0xFF1B5E20); // Deep emerald

// Legacy alias used across files
const elCardBorder = elEmeraldDeep;
const elGoldDim = Color(0xFFB8961A);
const elSurface3 = Color(0xFF172F17);

const elGoldGradient = LinearGradient(
  colors: [elGoldDim, elGold, Color(0xFFFFF8DC)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// ─── ELDecoFrame ─────────────────────────────────────────────────────────────
/// Full art deco rectangular frame with corner ornaments and double-line border.
/// Used on auth screen and splash.
class ELDecoFrame extends StatelessWidget {
  final Widget child;
  final double cornerSize;
  final EdgeInsetsGeometry? padding;
  final double frameThickness;

  const ELDecoFrame({
    super.key,
    required this.child,
    this.cornerSize = 20.0,
    this.padding,
    this.frameThickness = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DecoFramePainter(
        cornerSize: cornerSize,
        thickness: frameThickness,
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.all(cornerSize * 0.5 + 8),
        child: child,
      ),
    );
  }
}

class _DecoFramePainter extends CustomPainter {
  final double cornerSize;
  final double thickness;

  const _DecoFramePainter({required this.cornerSize, required this.thickness});

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Paint()
      ..color = elGold.withValues(alpha: 0.55)
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke;
    final inner = Paint()
      ..color = elGold.withValues(alpha: 0.2)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final c = cornerSize;
    // Outer octagonal frame
    final outerPath = Path()
      ..moveTo(c, 0)
      ..lineTo(size.width - c, 0)
      ..lineTo(size.width, c)
      ..lineTo(size.width, size.height - c)
      ..lineTo(size.width - c, size.height)
      ..lineTo(c, size.height)
      ..lineTo(0, size.height - c)
      ..lineTo(0, c)
      ..close();
    canvas.drawPath(outerPath, outer);

    // Inner double-line (4px inset)
    const inset = 5.0;
    final ic = c * 0.7;
    final innerPath = Path()
      ..moveTo(inset + ic, inset)
      ..lineTo(size.width - inset - ic, inset)
      ..lineTo(size.width - inset, inset + ic)
      ..lineTo(size.width - inset, size.height - inset - ic)
      ..lineTo(size.width - inset - ic, size.height - inset)
      ..lineTo(inset + ic, size.height - inset)
      ..lineTo(inset, size.height - inset - ic)
      ..lineTo(inset, inset + ic)
      ..close();
    canvas.drawPath(innerPath, inner);

    // Corner ornament: small L-shaped gold lines at each corner with diamond tip
    _drawCornerOrnament(canvas, Offset.zero, c, outer, false, false);
    _drawCornerOrnament(canvas, Offset(size.width, 0), c, outer, true, false);
    _drawCornerOrnament(canvas, Offset(0, size.height), c, outer, false, true);
    _drawCornerOrnament(canvas, Offset(size.width, size.height), c, outer, true, true);
  }

  void _drawCornerOrnament(Canvas canvas, Offset corner, double len,
      Paint paint, bool flipX, bool flipY) {
    final dx = flipX ? -1.0 : 1.0;
    final dy = flipY ? -1.0 : 1.0;
    final arm = len * 0.6;
    // Small tick mark beyond corner
    canvas.drawLine(corner, Offset(corner.dx + dx * arm, corner.dy), paint);
    canvas.drawLine(corner, Offset(corner.dx, corner.dy + dy * arm), paint);
    // Diamond dot at corner
    final diamondPaint = Paint()
      ..color = elGold.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    final d = 3.0;
    final cx = corner.dx + dx * arm;
    final cy2 = corner.dy;
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy2), width: d, height: d),
      diamondPaint,
    );
  }

  @override
  bool shouldRepaint(_DecoFramePainter old) =>
      old.cornerSize != cornerSize || old.thickness != thickness;
}

// ─── ELGoldAccent ─────────────────────────────────────────────────────────────
/// Three-diamond gold divider row: ◆ ◇ ◆
class ELGoldAccent extends StatelessWidget {
  final bool showDiamond;
  const ELGoldAccent({super.key, this.showDiamond = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    elGold.withValues(alpha: 0.0),
                    elGold.withValues(alpha: 0.4),
                  ],
                ),
              ),
            ),
          ),
          if (showDiamond) ...[
            const SizedBox(width: 10),
            _SmallDiamond(size: 6, filled: true),
            const SizedBox(width: 4),
            _SmallDiamond(size: 4, filled: false),
            const SizedBox(width: 4),
            _SmallDiamond(size: 6, filled: true),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    elGold.withValues(alpha: 0.4),
                    elGold.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallDiamond extends StatelessWidget {
  final double size;
  final bool filled;
  const _SmallDiamond({required this.size, required this.filled});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: filled ? elGold.withValues(alpha: 0.7) : Colors.transparent,
          border: Border.all(
            color: elGold.withValues(alpha: 0.6),
            width: 0.5,
          ),
        ),
      ),
    );
  }
}

// ─── ELGeometricButton ───────────────────────────────────────────────────────
/// Angular gold button with octagonal clip — art deco precise geometry.
class ELGeometricButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final double height;
  final bool useEmerald;

  const ELGeometricButton({
    super.key,
    required this.label,
    this.onTap,
    this.height = 52,
    this.useEmerald = false,
  });

  @override
  State<ELGeometricButton> createState() => _ELGeometricButtonState();
}

class _ELGeometricButtonState extends State<ELGeometricButton>
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
    final gradient = widget.useEmerald
        ? LinearGradient(
            colors: [elEmerald, elEmerald.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : elGoldGradient;

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
        child: ClipPath(
          clipper: _OctagonClipper(cut: 10),
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(gradient: gradient),
            alignment: Alignment.center,
            child: Text(
              widget.label,
              style: GoogleFonts.cinzel(
                color: elBg,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 2.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OctagonClipper extends CustomClipper<Path> {
  final double cut;
  const _OctagonClipper({required this.cut});

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(cut, 0)
      ..lineTo(size.width - cut, 0)
      ..lineTo(size.width, cut)
      ..lineTo(size.width, size.height - cut)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(cut, size.height)
      ..lineTo(0, size.height - cut)
      ..lineTo(0, cut)
      ..close();
  }

  @override
  bool shouldReclip(_OctagonClipper old) => old.cut != cut;
}

// ─── ELGeometricDots ─────────────────────────────────────────────────────────
/// Diamond-shaped loading dots sequencing in gold.
class ELGeometricDots extends StatefulWidget {
  const ELGeometricDots({super.key});

  @override
  State<ELGeometricDots> createState() => _ELGeometricDotsState();
}

class _ELGeometricDotsState extends State<ELGeometricDots>
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
          builder: (context, _) {
            final delay = i * 0.25;
            final v = ((_ctrl.value - delay) % 1.0).clamp(0.0, 1.0);
            final opacity = math.sin(v * math.pi).clamp(0.3, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              child: Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  width: 6,
                  height: 6,
                  color: elGold.withValues(alpha: opacity),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

// ─── ELDecoCorner ─────────────────────────────────────────────────────────────
/// Small L-shaped corner ornament drawn via CustomPaint.
/// Place in a Stack at each card corner with appropriate Transform.
class ELDecoCorner extends StatelessWidget {
  final double size;
  const ELDecoCorner({super.key, this.size = 10});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + 2,
      height: size + 2,
      child: CustomPaint(painter: _CornerPainter(size: size)),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final double size;
  const _CornerPainter({required this.size});

  @override
  void paint(Canvas canvas, Size s) {
    final paint = Paint()
      ..color = elGold
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset.zero, Offset(size, 0), paint);
    canvas.drawLine(Offset.zero, Offset(0, size), paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => old.size != size;
}

// ─── ELDiamondIndicator ───────────────────────────────────────────────────────
/// Diamond-shaped tab indicator widget for the top tab bar.
class ELDiamondIndicator extends StatelessWidget {
  final double size;
  const ELDiamondIndicator({super.key, this.size = 6});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: elGold,
          boxShadow: [
            BoxShadow(
              color: elGold.withValues(alpha: 0.5),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── ELDecoSectionHeader ──────────────────────────────────────────────────────
/// Art deco section header: ─── TEXT ───
/// Lines flanking the label text.
class ELDecoSectionHeader extends StatelessWidget {
  final String label;
  const ELDecoSectionHeader({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  elGold.withValues(alpha: 0.0),
                  elGold.withValues(alpha: 0.35),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: GoogleFonts.cinzel(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: elGold.withValues(alpha: 0.6),
              letterSpacing: 2.5,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  elGold.withValues(alpha: 0.35),
                  elGold.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── ELDecoCard ──────────────────────────────────────────────────────────────
/// Card with deep green bg, thin gold border, deco corner accents.
class ELDecoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? background;
  final double cornerLength;

  const ELDecoCard({
    super.key,
    required this.child,
    this.padding,
    this.background,
    this.cornerLength = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: background ?? elSurface,
            border: Border.all(color: elGold.withValues(alpha: 0.25), width: 0.5),
          ),
          child: child,
        ),
        Positioned(top: -1, left: -1, child: ELDecoCorner(size: cornerLength)),
        Positioned(
          top: -1,
          right: -1,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(math.pi),
            child: ELDecoCorner(size: cornerLength),
          ),
        ),
        Positioned(
          bottom: -1,
          left: -1,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationX(math.pi),
            child: ELDecoCorner(size: cornerLength),
          ),
        ),
        Positioned(
          bottom: -1,
          right: -1,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationZ(math.pi),
            child: ELDecoCorner(size: cornerLength),
          ),
        ),
      ],
    );
  }
}

// ─── ELDecoBanner ─────────────────────────────────────────────────────────────
/// Art deco banner header for home screen.
/// Dark green bg with geometric chevron lines (CustomPaint) and centered wordmark.
class ELDecoBanner extends StatelessWidget {
  const ELDecoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      color: elSurface,
      child: Stack(
        children: [
          // Geometric chevron deco lines
          Positioned.fill(
            child: CustomPaint(painter: _BannerDecoPainter()),
          ),
          // Centered content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'BEAUTYCITA',
                  style: GoogleFonts.cinzel(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: elGold,
                    letterSpacing: 4.0,
                  ),
                ),
                const SizedBox(height: 4),
                // Small gold diamond accent
                Transform.rotate(
                  angle: math.pi / 4,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: elGold.withValues(alpha: 0.8),
                      boxShadow: [
                        BoxShadow(
                          color: elGold.withValues(alpha: 0.3),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerDecoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = elGold.withValues(alpha: 0.12)
      ..strokeWidth = 0.75
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Chevron pattern left side
    for (int i = 0; i < 4; i++) {
      final offset = i * 18.0;
      canvas.drawLine(
        Offset(cx - 60 - offset, cy - 10),
        Offset(cx - 20 - offset, cy),
        paint,
      );
      canvas.drawLine(
        Offset(cx - 20 - offset, cy),
        Offset(cx - 60 - offset, cy + 10),
        paint,
      );
    }

    // Chevron pattern right side
    for (int i = 0; i < 4; i++) {
      final offset = i * 18.0;
      canvas.drawLine(
        Offset(cx + 60 + offset, cy - 10),
        Offset(cx + 20 + offset, cy),
        paint,
      );
      canvas.drawLine(
        Offset(cx + 20 + offset, cy),
        Offset(cx + 60 + offset, cy + 10),
        paint,
      );
    }

    // Thin horizontal line at bottom
    final linePaint = Paint()
      ..color = elGold.withValues(alpha: 0.2)
      ..strokeWidth = 0.5;
    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(_BannerDecoPainter old) => false;
}
