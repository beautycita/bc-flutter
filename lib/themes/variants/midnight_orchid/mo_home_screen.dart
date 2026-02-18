import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/category.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../config/theme_extension.dart';
import '../../../screens/subcategory_sheet.dart';
import '../../../themes/category_icons.dart';
import '../../../themes/theme_variant.dart';
import 'mo_widgets.dart';

// ─── _buildOrganicPath (local helper, mirrors mo_widgets.dart implementation) ─
Path _buildOrganicPath(Size size, int seed) {
  final rng = math.Random(seed * 31 + 7);
  final w = size.width;
  final h = size.height;
  final tlR = 20.0 + rng.nextDouble() * 24;
  final trR = 18.0 + rng.nextDouble() * 28;
  final brR = 22.0 + rng.nextDouble() * 20;
  final blR = 16.0 + rng.nextDouble() * 26;
  final topBulge = (rng.nextDouble() - 0.35) * 12;
  final rightBulge = (rng.nextDouble() - 0.35) * 10;
  final bottomBulge = (rng.nextDouble() - 0.35) * 14;
  final leftBulge = (rng.nextDouble() - 0.35) * 10;
  final path = Path();
  path.moveTo(tlR, 0);
  path.cubicTo(w * 0.33, -topBulge, w * 0.67, -topBulge, w - trR, 0);
  path.quadraticBezierTo(w, 0, w, trR);
  path.cubicTo(w + rightBulge, h * 0.33, w + rightBulge, h * 0.67, w, h - brR);
  path.quadraticBezierTo(w, h, w - brR, h);
  path.cubicTo(w * 0.67, h + bottomBulge, w * 0.33, h + bottomBulge, blR, h);
  path.quadraticBezierTo(0, h, 0, h - blR);
  path.cubicTo(-leftBulge, h * 0.67, -leftBulge, h * 0.33, 0, tlR);
  path.quadraticBezierTo(0, 0, tlR, 0);
  path.close();
  return path;
}

class MOHomeScreen extends ConsumerStatefulWidget {
  const MOHomeScreen({super.key});

  @override
  ConsumerState<MOHomeScreen> createState() => _MOHomeScreenState();
}

class _MOHomeScreenState extends ConsumerState<MOHomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerCtrl;
  late AnimationController _waveCtrl;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;
  late Animation<double> _waveAnim;

  final List<AnimationController> _cardControllers = [];
  final List<Animation<double>> _cardFades = [];
  final List<Animation<Offset>> _cardSlides = [];

  static const _cardCount = 16; // pre-allocate enough controllers

  @override
  void initState() {
    super.initState();

    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    _headerFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut),
    );
    _headerSlide = Tween(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOutCubic));

    _waveAnim = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveCtrl, curve: Curves.easeInOut),
    );

    // Pre-create card stagger controllers
    for (int i = 0; i < _cardCount; i++) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      );
      _cardControllers.add(ctrl);
      _cardFades.add(Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: ctrl, curve: Curves.easeOut),
      ));
      _cardSlides.add(Tween(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic)));
    }

    _headerCtrl.forward();

    // Stagger card animations
    for (int i = 0; i < _cardCount; i++) {
      Future.delayed(Duration(milliseconds: 300 + i * 80), () {
        if (mounted && i < _cardControllers.length) {
          _cardControllers[i].forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _waveCtrl.dispose();
    for (final ctrl in _cardControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _showSubcategorySheet(BuildContext context, ServiceCategory category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SubcategorySheet(category: category),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = MOColors.of(context);
    final categories = ref.watch(categoriesProvider);
    final ext = Theme.of(context).extension<BCThemeExtension>()!;

    return Scaffold(
      backgroundColor: c.surface,
      extendBody: true,
      body: Stack(
        children: [
          // Floating pollen particles layer
          const MOFloatingParticles(count: 15, seedOffset: 100),

          // Ambient background glow — top left orchid bloom
          Positioned(
            top: -80,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    c.orchidPurple.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Ambient background glow — bottom right
          Positioned(
            bottom: 100,
            right: -80,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    c.orchidPink.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Organic header ────────────────────────────────────────────
                FadeTransition(
                  opacity: _headerFade,
                  child: SlideTransition(
                    position: _headerSlide,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: Row(
                        children: [
                          // BC monogram with orchid glow
                          Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: c.orchidPurple.withValues(alpha: 0.45),
                                  blurRadius: 24,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ShaderMask(
                              shaderCallback: (bounds) =>
                                  c.orchidGradient.createShader(bounds),
                              child: Text(
                                'BC',
                                style: GoogleFonts.quicksand(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          // Business owner icon
                          Consumer(
                            builder: (_, ref, __) {
                              final isBiz = ref.watch(isBusinessOwnerProvider);
                              return isBiz.when(
                                data: (isOwner) => isOwner
                                    ? _PillHeaderIcon(
                                        icon: Icons.storefront_rounded,
                                        onTap: () =>
                                            context.push('/business'),
                                      )
                                    : const SizedBox.shrink(),
                                loading: () => const SizedBox.shrink(),
                                error: (_, __) => const SizedBox.shrink(),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          _PillHeaderIcon(
                            icon: Icons.chat_bubble_outline_rounded,
                            onTap: () => context.push('/chat'),
                          ),
                          const SizedBox(width: 8),
                          _PillHeaderIcon(
                            icon: Icons.settings_outlined,
                            onTap: () => context.push('/settings'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // ── Greeting with animated wavy underline ─────────────────────
                FadeTransition(
                  opacity: _headerFade,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              c.orchidGradient.createShader(bounds),
                          child: Text(
                            'Que necesitas hoy?',
                            style: GoogleFonts.quicksand(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Wavy animated underline
                        AnimatedBuilder(
                          animation: _waveAnim,
                          builder: (_, __) {
                            return CustomPaint(
                              size: const Size(180, 10),
                              painter: _WavyUnderlinePainter(
                                t: _waveAnim.value,
                                gradient: c.orchidGradient,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // ── Full-width organic category card feed ─────────────────────
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      for (int i = 0; i < categories.length; i++) ...[
                        _buildStaggeredCard(
                          i: i,
                          category: categories[i],
                          color: ext.categoryColors.length > i
                              ? ext.categoryColors[i]
                              : c.orchidPink,
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ── Recomienda CTA — organic blob card ────────────────
                      _RecomendaCTA(
                        onTap: () => context.push('/invite'),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // ── Concave valley bottom nav ─────────────────────────────────────────
      bottomNavigationBar: MOConcaveBottomNav(
        activeIndex: 0,
        onTap: (i) {
          if (i == 1) context.push('/my-bookings');
          if (i == 2) context.push('/settings/profile');
        },
      ),
    );
  }

  Widget _buildStaggeredCard({
    required int i,
    required ServiceCategory category,
    required Color color,
  }) {
    final ctrlIndex = i.clamp(0, _cardCount - 1);
    return FadeTransition(
      opacity: _cardFades[ctrlIndex],
      child: SlideTransition(
        position: _cardSlides[ctrlIndex],
        child: _FullWidthOrganicCard(
          category: category,
          color: color,
          index: i,
          onTap: () => _showSubcategorySheet(context, category),
        ),
      ),
    );
  }
}

// ─── Wavy underline painter ───────────────────────────────────────────────────
class _WavyUnderlinePainter extends CustomPainter {
  final double t;
  final LinearGradient gradient;
  _WavyUnderlinePainter({required this.t, required this.gradient});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = gradient.createShader(Offset.zero & size)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final amplitude = 2.5 + t * 1.5;
    final phase = t * math.pi * 2;
    path.moveTo(0, size.height / 2);
    for (double x = 0; x <= size.width; x++) {
      final y = size.height / 2 +
          math.sin((x / size.width) * math.pi * 3 + phase) * amplitude;
      path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WavyUnderlinePainter old) => old.t != t;
}

// ─── Full-width organic category card ─────────────────────────────────────────
class _FullWidthOrganicCard extends StatefulWidget {
  final ServiceCategory category;
  final Color color;
  final int index;
  final VoidCallback onTap;

  const _FullWidthOrganicCard({
    required this.category,
    required this.color,
    required this.index,
    required this.onTap,
  });

  @override
  State<_FullWidthOrganicCard> createState() => _FullWidthOrganicCardState();
}

class _FullWidthOrganicCardState extends State<_FullWidthOrganicCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;
  bool _pressed = false;

  // Height varies by index to give organic rhythm
  static const _heights = [180.0, 140.0, 160.0];

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2600 + widget.index * 280),
    )..repeat(reverse: true);
    _glowAnim = Tween(begin: 0.05, end: 0.20).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = MOColors.of(context);
    final cardHeight = _heights[widget.index % 3];
    // Unique organic seed per card
    final seed = widget.index * 17 + 3;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: AnimatedBuilder(
          animation: _glowAnim,
          builder: (_, child) {
            return CustomPaint(
              painter: _OrganicCardGlowPainter(
                seed: seed,
                glowColor: widget.color,
                glowAlpha: _glowAnim.value,
                cardColor: c.card,
                borderColor: c.orchidDeep,
              ),
              child: ClipPath(
                clipper: MOOrganicClipper(seed: seed),
                child: SizedBox(
                  height: cardHeight,
                  width: double.infinity,
                  child: child,
                ),
              ),
            );
          },
          child: _buildContent(context, cardHeight),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, double cardHeight) {
    final c = MOColors.of(context);
    final rng = math.Random(widget.index * 11);
    final isWide = cardHeight >= 170;

    return Container(
      color: c.card,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: isWide
            ? _buildTallContent(context, rng)
            : _buildCompactContent(context),
      ),
    );
  }

  /// Tall card layout: emoji large top + name below
  Widget _buildTallContent(BuildContext context, math.Random rng) {
    final c = MOColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Large emoji badge
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: widget.color.withValues(alpha: 0.10),
                border: Border.all(
                  color: widget.color.withValues(alpha: 0.25),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.12),
                    blurRadius: 16,
                    spreadRadius: -4,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: getCategoryIcon(
                variant: ThemeVariant.midnightOrchid,
                categoryId: widget.category.id,
                color: widget.color,
                size: 34,
              ),
            ),
            const Spacer(),
            // Orchid accent decorative petal
            _OrchidPetalDecor(color: widget.color, size: 40),
          ],
        ),
        const Spacer(),
        // Category name
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [widget.color, c.orchidLight],
          ).createShader(bounds),
          child: Text(
            widget.category.nameEs,
            style: GoogleFonts.quicksand(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 6),
        // Orchid gradient accent bar
        Container(
          height: 3,
          width: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [widget.color, widget.color.withValues(alpha: 0.0)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  /// Compact card layout: emoji left + name right
  Widget _buildCompactContent(BuildContext context) {
    return Row(
      children: [
        // Emoji orb
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: 0.10),
            border: Border.all(
              color: widget.color.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: getCategoryIcon(
            variant: ThemeVariant.midnightOrchid,
            categoryId: widget.category.id,
            color: widget.color,
            size: 26,
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.category.nameEs,
                style: GoogleFonts.quicksand(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 5),
              Container(
                height: 2,
                width: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.color,
                      widget.color.withValues(alpha: 0.0),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        ),
        // Chevron in orchid circle
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: 0.12),
          ),
          child: Icon(
            Icons.chevron_right_rounded,
            color: widget.color.withValues(alpha: 0.85),
            size: 20,
          ),
        ),
      ],
    );
  }
}

// Organic petal-like decorative element
class _OrchidPetalDecor extends StatelessWidget {
  final Color color;
  final double size;

  const _OrchidPetalDecor({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _PetalPainter(color: color),
    );
  }
}

class _PetalPainter extends CustomPainter {
  final Color color;
  _PetalPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Draw 3 overlapping ellipses rotated to form a petal cluster
    for (int i = 0; i < 3; i++) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(i * math.pi * 2 / 3);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, -size.height * 0.2),
          width: size.width * 0.45,
          height: size.height * 0.7,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PetalPainter _) => false;
}

// Organic glow painter (draws glow OUTSIDE the clip path)
class _OrganicCardGlowPainter extends CustomPainter {
  final int seed;
  final Color glowColor;
  final double glowAlpha;
  final Color cardColor;
  final Color borderColor;

  _OrganicCardGlowPainter({
    required this.seed,
    required this.glowColor,
    required this.glowAlpha,
    required this.cardColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildOrganicPath(size, seed);

    // Card fill
    canvas.drawPath(path, Paint()..color = cardColor);

    // Orchid border
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Dynamic glow
    canvas.drawPath(
      path,
      Paint()
        ..color = glowColor.withValues(alpha: glowAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 18)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_OrganicCardGlowPainter old) =>
      old.glowAlpha != glowAlpha || old.seed != seed;
}

// ─── Recomienda CTA ────────────────────────────────────────────────────────────
class _RecomendaCTA extends StatelessWidget {
  final VoidCallback onTap;
  const _RecomendaCTA({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = MOColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: c.orchidPink.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: c.orchidPink.withValues(alpha: 0.15),
              blurRadius: 24,
              spreadRadius: -4,
            ),
            BoxShadow(
              color: c.orchidPurple.withValues(alpha: 0.08),
              blurRadius: 12,
              spreadRadius: -2,
            ),
          ],
        ),
        child: Row(
          children: [
            // Glowing star icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    c.orchidPink.withValues(alpha: 0.20),
                    c.orchidPurple.withValues(alpha: 0.08),
                  ],
                ),
                border: Border.all(
                  color: c.orchidPink.withValues(alpha: 0.30),
                  width: 1,
                ),
              ),
              child: ShaderMask(
                shaderCallback: (b) => c.orchidGradient.createShader(b),
                child: const Icon(
                  Icons.star_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recomienda tu salon',
                    style: GoogleFonts.quicksand(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Invita y gana beneficios exclusivos',
                    style: GoogleFonts.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: c.orchidPurple.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.orchidPink.withValues(alpha: 0.10),
              ),
              child: Icon(
                Icons.chevron_right_rounded,
                color: c.orchidPink.withValues(alpha: 0.7),
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pill header icon button ───────────────────────────────────────────────────
class _PillHeaderIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _PillHeaderIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = MOColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: c.orchidDeep.withValues(alpha: 0.7), width: 1),
          color: c.card.withValues(alpha: 0.85),
        ),
        child: Icon(icon, color: c.orchidPurple.withValues(alpha: 0.85), size: 20),
      ),
    );
  }
}
