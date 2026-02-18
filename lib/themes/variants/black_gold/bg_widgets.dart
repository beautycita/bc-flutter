import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../category_icons.dart';
import '../../theme_variant.dart';

// ─── Brightness-aware color set (Black & Gold) ──────────────────────────────

class BGColors {
  final Color surface0, surface1, surface2, surface3, surface4;
  final Color goldDark, goldMid, goldLight;
  final Color text, textSecondary, textMuted;
  final LinearGradient goldGradient;

  const BGColors._({
    required this.surface0,
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.surface4,
    required this.goldDark,
    required this.goldMid,
    required this.goldLight,
    required this.text,
    required this.textSecondary,
    required this.textMuted,
    required this.goldGradient,
  });

  static const dark = BGColors._(
    surface0: Color(0xFF0A0A0F),
    surface1: Color(0xFF12121A),
    surface2: Color(0xFF16161E),
    surface3: Color(0xFF1A1A24),
    surface4: Color(0xFF1E1E28),
    goldDark: Color(0xFFB8860B),
    goldMid: Color(0xFFD4AF37),
    goldLight: Color(0xFFFFD700),
    text: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB0B0B0),
    textMuted: Color(0xFF808080),
    goldGradient: LinearGradient(
      colors: [Color(0xFFB8860B), Color(0xFFD4AF37), Color(0xFFFFD700)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static const light = BGColors._(
    surface0: Color(0xFFFFF9F0),
    surface1: Color(0xFFFFF5E6),
    surface2: Color(0xFFFFEED4),
    surface3: Color(0xFFFFE7C4),
    surface4: Color(0xFFFFDEB0),
    goldDark: Color(0xFF8B6914),
    goldMid: Color(0xFFB8860B),
    goldLight: Color(0xFFD4AF37),
    text: Color(0xFF2C2416),
    textSecondary: Color(0xFF7A6B55),
    textMuted: Color(0xFFB0A08A),
    goldGradient: LinearGradient(
      colors: [Color(0xFF8B6914), Color(0xFFB8860B), Color(0xFFD4AF37)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static BGColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

// ─── Legacy const aliases (used by widgets below) ────────────────────────────
const bgSurface0 = Color(0xFF0A0A0F);
const bgSurface1 = Color(0xFF12121A);
const bgSurface2 = Color(0xFF16161E);
const bgSurface3 = Color(0xFF1A1A24);
const bgSurface4 = Color(0xFF1E1E28);

const bgGoldDark = Color(0xFFB8860B);
const bgGoldMid = Color(0xFFD4AF37);
const bgGoldLight = Color(0xFFFFD700);

const bgGoldGradient = LinearGradient(
  colors: [bgGoldDark, bgGoldMid, bgGoldLight],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Gold shimmer sweep animation — metallic highlight sweeps across a child.
class BGGoldShimmer extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const BGGoldShimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 2000),
  });

  @override
  State<BGGoldShimmer> createState() => _BGGoldShimmerState();
}

class _BGGoldShimmerState extends State<BGGoldShimmer>
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
        final offset = _controller.value * 3.0 - 1.0;
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                bgGoldMid,
                Color(0xFFFFF8DC),
                bgGoldLight,
                Color(0xFFFFFFE0),
                Color(0xFFFFF8DC),
                bgGoldMid,
              ],
              stops: [
                (offset - 0.3).clamp(0.0, 1.0),
                (offset - 0.1).clamp(0.0, 1.0),
                offset.clamp(0.0, 1.0),
                (offset + 0.1).clamp(0.0, 1.0),
                (offset + 0.3).clamp(0.0, 1.0),
                (offset + 0.5).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: child!,
        );
      },
      child: widget.child,
    );
  }
}

/// Three gold dots loading indicator with pulse animation.
class BGGoldDots extends StatefulWidget {
  const BGGoldDots({super.key});

  @override
  State<BGGoldDots> createState() => _BGGoldDotsState();
}

class _BGGoldDotsState extends State<BGGoldDots>
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
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bgGoldMid.withValues(alpha: opacity),
              ),
            );
          },
        );
      }),
    );
  }
}

/// Dark luxury card with subtle gold border.
class BGLuxuryCard extends StatelessWidget {
  final Widget child;
  final Color? background;
  final double borderOpacity;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;

  const BGLuxuryCard({
    super.key,
    required this.child,
    this.background,
    this.borderOpacity = 0.20,
    this.borderRadius = 12,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background ?? bgSurface2,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: bgGoldMid.withValues(alpha: borderOpacity),
          width: 0.5,
        ),
      ),
      child: child,
    );
  }
}

/// Gold gradient pill button with press scale.
class BGGoldButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final double height;

  const BGGoldButton({
    super.key,
    required this.label,
    this.onTap,
    this.height = 52,
  });

  @override
  State<BGGoldButton> createState() => _BGGoldButtonState();
}

class _BGGoldButtonState extends State<BGGoldButton>
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
        builder: (context, child) {
          return Transform.scale(scale: _scale.value, child: child);
        },
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            gradient: bgGoldGradient,
            borderRadius: BorderRadius.circular(widget.height / 2),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: const TextStyle(
              color: bgSurface0,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// Centered gold line with faded edges.
class BGGoldDivider extends StatelessWidget {
  final double width;
  const BGGoldDivider({super.key, this.width = 0.6});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            bgGoldMid.withValues(alpha: 0.0),
            bgGoldMid.withValues(alpha: 0.4),
            bgGoldMid.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

// ─── NEW WIDGETS ─────────────────────────────────────────────────────────────

/// Round gold-rimmed story-style category chip.
class BGCategoryChip extends StatefulWidget {
  final String categoryId;
  final String label;
  final VoidCallback onTap;

  const BGCategoryChip({
    super.key,
    required this.categoryId,
    required this.label,
    required this.onTap,
  });

  @override
  State<BGCategoryChip> createState() => _BGCategoryChipState();
}

class _BGCategoryChipState extends State<BGCategoryChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween(begin: 1.0, end: 0.92).animate(
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
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gold-rimmed circle
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [bgGoldDark, bgGoldLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2.5),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: bgSurface1,
                  ),
                  alignment: Alignment.center,
                  child: getCategoryIcon(
                    variant: ThemeVariant.blackGold,
                    categoryId: widget.categoryId,
                    color: const Color(0xFFD4AF37),
                    size: 26,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 70,
              child: Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFB0A080),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Data model for a single BGHeroCarousel slide.
class BGCarouselItem {
  final String categoryId;
  final String title;
  final Color accentColor;
  final VoidCallback onTap;

  const BGCarouselItem({
    required this.categoryId,
    required this.title,
    required this.accentColor,
    required this.onTap,
  });
}

/// Full-width PageView hero carousel with auto-scroll and dots indicator.
class BGHeroCarousel extends StatefulWidget {
  final List<BGCarouselItem> items;

  const BGHeroCarousel({super.key, required this.items});

  @override
  State<BGHeroCarousel> createState() => _BGHeroCarouselState();
}

class _BGHeroCarouselState extends State<BGHeroCarousel> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);
    _startAutoScroll();
  }

  void _startAutoScroll() {
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      final next = (_currentPage + 1) % widget.items.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
      _startAutoScroll();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 280,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.items.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return GestureDetector(
                onTap: item.onTap,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: bgSurface2,
                    border: Border.all(
                      color: bgGoldMid.withValues(alpha: 0.15),
                      width: 0.5,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Color wash from accent
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              colors: [
                                item.accentColor.withValues(alpha: 0.18),
                                item.accentColor.withValues(alpha: 0.04),
                              ],
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                            ),
                          ),
                        ),
                      ),
                      // Dark gradient overlay bottom
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                bgSurface0.withValues(alpha: 0.85),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                      // Content
                      Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Category icon large
                            getCategoryIcon(
                              variant: ThemeVariant.blackGold,
                              categoryId: item.categoryId,
                              color: item.accentColor,
                              size: 56,
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontFamily: 'Playfair Display',
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                // Gold accent line
                                Container(
                                  height: 2,
                                  width: 48,
                                  decoration: BoxDecoration(
                                    gradient: bgGoldGradient,
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Dots indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.items.length, (i) {
            final isActive = i == _currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: isActive ? bgGoldGradient : null,
                color: isActive ? null : bgGoldMid.withValues(alpha: 0.25),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// Floating action button with animated radial fan menu.
/// Four options fan out from the FAB when tapped.
class BGFab extends StatefulWidget {
  final List<BGFabItem> items;

  const BGFab({super.key, required this.items});

  @override
  State<BGFab> createState() => _BGFabState();
}

class BGFabItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const BGFabItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class _BGFabState extends State<BGFab> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expand;
  late Animation<double> _rotate;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _expand = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _rotate = Tween(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _close() {
    if (_open) _toggle();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.items.length;
    // Fan angle: items spread from -90deg (up) to -180deg (left)
    const startAngle = -math.pi / 2; // straight up
    const sweep = -math.pi / 2;       // sweep left to -180deg

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Backdrop tap-to-close
        if (_open)
          Positioned.fill(
            child: GestureDetector(
              onTap: _close,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),

        // Fan menu items
        ...List.generate(count, (i) {
          final angle = startAngle + (count > 1 ? sweep * i / (count - 1) : 0);
          const radius = 80.0;
          final dx = math.cos(angle) * radius;
          final dy = math.sin(angle) * radius;
          final item = widget.items[i];

          return AnimatedBuilder(
            animation: _expand,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(dx * _expand.value, dy * _expand.value),
                child: Opacity(
                  opacity: _expand.value.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: _BGFabMenuItem(item: item, onTap: () {
              _close();
              item.onTap();
            }),
          );
        }),

        // Main FAB
        GestureDetector(
          onTap: _toggle,
          child: AnimatedBuilder(
            animation: _rotate,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotate.value * 2 * math.pi,
                child: child,
              );
            },
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: bgGoldGradient,
                boxShadow: [
                  BoxShadow(
                    color: bgGoldMid.withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.add,
                color: bgSurface0,
                size: 28,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BGFabMenuItem extends StatelessWidget {
  final BGFabItem item;
  final VoidCallback onTap;

  const _BGFabMenuItem({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgSurface2,
              border: Border.all(color: bgGoldMid.withValues(alpha: 0.5), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(item.icon, color: bgGoldMid, size: 20),
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: bgSurface1.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              item.label,
              style: const TextStyle(
                color: bgGoldMid,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
