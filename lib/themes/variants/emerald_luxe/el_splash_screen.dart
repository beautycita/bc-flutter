import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../config/constants.dart';
import '../../../main.dart' show supabaseReady;
import '../../../providers/auth_provider.dart';
import 'el_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ELSplashScreen — Art Deco Structured Elegance
//
// Animation sequence:
// 0.00–0.25  Concentric diamond/rectangle pattern expands from center (CustomPaint)
// 0.20–0.45  Corner bracket accents draw in from screen corners
// 0.40–0.65  "BEAUTYCITA" wordmark reveals inside the expanding pattern
// 0.55–0.75  Gold line extends below wordmark
// 0.70–0.95  Tagline fades in
// ─────────────────────────────────────────────────────────────────────────────

class ELSplashScreen extends ConsumerStatefulWidget {
  const ELSplashScreen({super.key});

  @override
  ConsumerState<ELSplashScreen> createState() => _ELSplashScreenState();
}

class _ELSplashScreenState extends ConsumerState<ELSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  // Concentric geometric pattern expanding outward
  late Animation<double> _patternExpand;

  // Corner brackets drawing in from corners
  late Animation<double> _cornerDraw;

  // Wordmark reveal (fade + scale)
  late Animation<double> _wordmarkFade;
  late Animation<double> _wordmarkScale;

  // Gold line under wordmark
  late Animation<double> _lineExpand;

  // Tagline
  late Animation<double> _taglineFade;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _patternExpand = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    _cornerDraw = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.18, 0.48, curve: Curves.easeOut),
      ),
    );

    _wordmarkFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.38, 0.62, curve: Curves.easeOut),
      ),
    );
    _wordmarkScale = Tween(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.38, 0.65, curve: Curves.easeOutBack),
      ),
    );

    _lineExpand = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.55, 0.75, curve: Curves.easeOut),
      ),
    );

    _taglineFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.70, 0.95, curve: Curves.easeOut),
      ),
    );

    _ctrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndNavigate();
    });
  }

  Future<void> _checkAndNavigate() async {
    await supabaseReady.future;
    try {
      await ref.read(authStateProvider.notifier).checkRegistration();
    } catch (_) {}
    await Future.delayed(AppConstants.splashDuration);
    if (!mounted) return;
    final authState = ref.read(authStateProvider);
    if (authState.isAuthenticated) {
      context.go('/home');
    } else {
      context.go('/auth');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ELColors.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: c.bg,
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Stack(
            children: [
              // ── Expanding concentric geometric pattern ─────────────────
              Positioned.fill(
                child: CustomPaint(
                  painter: _ConcentricPatternPainter(
                    expand: _patternExpand.value,
                    screenSize: size,
                  ),
                ),
              ),

              // ── Corner bracket accents ─────────────────────────────────
              Positioned.fill(
                child: CustomPaint(
                  painter: _CornerBracketPainter(progress: _cornerDraw.value),
                ),
              ),

              // ── Center content ─────────────────────────────────────────
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Wordmark
                    Opacity(
                      opacity: _wordmarkFade.value,
                      child: Transform.scale(
                        scale: _wordmarkScale.value,
                        child: Text(
                          'BEAUTYCITA',
                          style: GoogleFonts.cinzel(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: c.gold,
                            letterSpacing: 5.0,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Gold line expanding below wordmark
                    if (_lineExpand.value > 0)
                      Container(
                        height: 1.5,
                        width: _lineExpand.value * 180,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              c.gold.withValues(alpha: 0.0),
                              c.gold.withValues(alpha: 0.8),
                              c.gold.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Tagline
                    Opacity(
                      opacity: _taglineFade.value,
                      child: Text(
                        AppConstants.tagline.toUpperCase(),
                        style: GoogleFonts.raleway(
                          fontSize: 10,
                          fontWeight: FontWeight.w300,
                          color: c.emerald.withValues(alpha: 0.65),
                          letterSpacing: 3.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Small diamond center accent ─────────────────────────────
              if (_patternExpand.value > 0.1)
                Center(
                  child: Transform.rotate(
                    angle: math.pi / 4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: c.gold.withValues(
                            alpha: _wordmarkFade.value > 0.1
                                ? 0
                                : _patternExpand.value * 0.9),
                        boxShadow: [
                          BoxShadow(
                            color: c.gold.withValues(alpha: 0.4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Painters ────────────────────────────────────────────────────────────────

/// Concentric diamonds + rectangles expanding from center.
/// Each shape strokes from 0 to full as expand goes 0→1.
class _ConcentricPatternPainter extends CustomPainter {
  final double expand;
  final Size screenSize;

  const _ConcentricPatternPainter({
    required this.expand,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (expand <= 0) return;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // 7 concentric shapes, alternating diamond and rectangle
    const count = 7;
    final maxR = math.max(size.width, size.height) * 0.65;

    for (int i = 0; i < count; i++) {
      final delay = i * (1.0 / count);
      final t = ((expand - delay) * count).clamp(0.0, 1.0);
      if (t <= 0) continue;

      final r = (i + 1) * maxR / (count + 1);
      final isDiamond = i % 2 == 0;
      final alpha = (0.5 - i * 0.06).clamp(0.05, 0.5);

      final paint = Paint()
        ..color = isDiamond
            ? elGold.withValues(alpha: alpha)
            : elEmerald.withValues(alpha: alpha * 0.5)
        ..strokeWidth = isDiamond ? 1.0 : 0.5
        ..style = PaintingStyle.stroke;

      if (isDiamond) {
        _drawPartialDiamond(canvas, cx, cy, r, t, paint);
      } else {
        _drawPartialRectangle(canvas, cx, cy, r, r * 0.6, t, paint);
      }
    }
  }

  void _drawPartialDiamond(
      Canvas canvas, double cx, double cy, double r, double t, Paint paint) {
    final corners = [
      Offset(cx, cy - r),
      Offset(cx + r, cy),
      Offset(cx, cy + r),
      Offset(cx - r, cy),
    ];
    _drawPartialPolygon(canvas, corners, t, paint);
  }

  void _drawPartialRectangle(
      Canvas canvas, double cx, double cy, double hw, double hh, double t, Paint paint) {
    final corners = [
      Offset(cx - hw, cy - hh),
      Offset(cx + hw, cy - hh),
      Offset(cx + hw, cy + hh),
      Offset(cx - hw, cy + hh),
    ];
    _drawPartialPolygon(canvas, corners, t, paint);
  }

  void _drawPartialPolygon(
      Canvas canvas, List<Offset> corners, double t, Paint paint) {
    double totalLen = 0;
    for (int i = 0; i < corners.length; i++) {
      totalLen += (corners[(i + 1) % corners.length] - corners[i]).distance;
    }
    double drawn = totalLen * t;

    for (int i = 0; i < corners.length; i++) {
      if (drawn <= 0) break;
      final a = corners[i];
      final b = corners[(i + 1) % corners.length];
      final segLen = (b - a).distance;
      if (drawn >= segLen) {
        canvas.drawLine(a, b, paint);
        drawn -= segLen;
      } else {
        final frac = drawn / segLen;
        canvas.drawLine(
          a,
          Offset(a.dx + (b.dx - a.dx) * frac, a.dy + (b.dy - a.dy) * frac),
          paint,
        );
        drawn = 0;
      }
    }
  }

  @override
  bool shouldRepaint(_ConcentricPatternPainter old) => old.expand != expand;
}

/// Corner bracket accents drawn from screen corners inward.
class _CornerBracketPainter extends CustomPainter {
  final double progress;
  const _CornerBracketPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final paint = Paint()
      ..color = elGold.withValues(alpha: 0.5 * progress)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const margin = 28.0;
    const armLen = 36.0;
    final len = armLen * progress;

    // Top-left
    canvas.drawLine(Offset(margin, margin), Offset(margin + len, margin), paint);
    canvas.drawLine(Offset(margin, margin), Offset(margin, margin + len), paint);

    // Top-right
    canvas.drawLine(Offset(size.width - margin, margin), Offset(size.width - margin - len, margin), paint);
    canvas.drawLine(Offset(size.width - margin, margin), Offset(size.width - margin, margin + len), paint);

    // Bottom-left
    canvas.drawLine(Offset(margin, size.height - margin), Offset(margin + len, size.height - margin), paint);
    canvas.drawLine(Offset(margin, size.height - margin), Offset(margin, size.height - margin - len), paint);

    // Bottom-right
    canvas.drawLine(
        Offset(size.width - margin, size.height - margin), Offset(size.width - margin - len, size.height - margin), paint);
    canvas.drawLine(
        Offset(size.width - margin, size.height - margin), Offset(size.width - margin, size.height - margin - len), paint);

    // Small diamond at each corner tip
    if (progress > 0.7) {
      final dotAlpha = ((progress - 0.7) / 0.3).clamp(0.0, 1.0);
      final dotPaint = Paint()
        ..color = elGold.withValues(alpha: dotAlpha * 0.7)
        ..style = PaintingStyle.fill;
      const d = 3.0;
      _drawDiamond(canvas, Offset(margin + len, margin), d, dotPaint);
      _drawDiamond(canvas, Offset(margin, margin + len), d, dotPaint);
      _drawDiamond(canvas, Offset(size.width - margin - len, margin), d, dotPaint);
      _drawDiamond(canvas, Offset(size.width - margin, margin + len), d, dotPaint);
      _drawDiamond(canvas, Offset(margin + len, size.height - margin), d, dotPaint);
      _drawDiamond(canvas, Offset(margin, size.height - margin - len), d, dotPaint);
      _drawDiamond(canvas, Offset(size.width - margin - len, size.height - margin), d, dotPaint);
      _drawDiamond(canvas, Offset(size.width - margin, size.height - margin - len), d, dotPaint);
    }
  }

  void _drawDiamond(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy - r)
      ..lineTo(center.dx + r, center.dy)
      ..lineTo(center.dx, center.dy + r)
      ..lineTo(center.dx - r, center.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornerBracketPainter old) => old.progress != progress;
}
