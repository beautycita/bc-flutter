import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/category.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../providers/business_provider.dart';
import '../../../screens/subcategory_sheet.dart';
import '../../../themes/category_icons.dart';
import '../../../themes/theme_variant.dart';
import 'gl_widgets.dart';

// ─── Tab index provider (local) ───────────────────────────────────────────────
final _glTabIndexProvider = StateProvider<int>((ref) => 0);

// ─── GLHomeScreen ─────────────────────────────────────────────────────────────
class GLHomeScreen extends ConsumerWidget {
  const GLHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = GlColors.of(context);
    final tabIndex = ref.watch(_glTabIndexProvider);

    return Scaffold(
      backgroundColor: c.bgDeep,
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen aurora — always visible behind everything
          const GlAuroraBackground(child: SizedBox.expand()),

          // Tab content
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Floating glass TabBar at top
                _GlTopTabBar(
                  currentIndex: tabIndex,
                  onTap: (i) {
                    if (i == 1) {
                      context.push('/my-bookings');
                    } else if (i == 2) {
                      context.push('/settings/profile');
                    } else {
                      ref.read(_glTabIndexProvider.notifier).state = i;
                    }
                  },
                ),

                const SizedBox(height: 12),

                // Content area
                Expanded(
                  child: tabIndex == 0
                      ? const _ExplorarTab()
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Top floating glass TabBar ────────────────────────────────────────────────
class _GlTopTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _GlTopTabBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = GlColors.of(context);
    const tabs = ['Explorar', 'Citas', 'Perfil'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: Row(
              children: List.generate(tabs.length, (i) {
                final isActive = currentIndex == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(i),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tabs[i],
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: isActive
                                  ? c.text
                                  : c.text.withValues(alpha: 0.45),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          // Neon gradient underline indicator
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            height: 2,
                            width: isActive ? 32 : 0,
                            decoration: BoxDecoration(
                              gradient: isActive ? c.neonGradient : null,
                              borderRadius: BorderRadius.circular(1),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: c.neonPink
                                            .withValues(alpha: 0.5),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Explorar Tab — Stacked Card Deck ─────────────────────────────────────────
class _ExplorarTab extends ConsumerStatefulWidget {
  const _ExplorarTab();

  @override
  ConsumerState<_ExplorarTab> createState() => _ExplorarTabState();
}

class _ExplorarTabState extends ConsumerState<_ExplorarTab>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  double _dragDelta = 0;
  bool _isDragging = false;
  late AnimationController _swipeController;
  late Animation<double> _swipeAnimation;
  bool _showQuickActions = false;
  late AnimationController _sheetController;
  late Animation<double> _sheetAnimation;

  @override
  void initState() {
    super.initState();
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _swipeAnimation =
        Tween<double>(begin: 0, end: 0).animate(_swipeController);

    _sheetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _sheetAnimation = CurvedAnimation(
      parent: _sheetController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _swipeController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    setState(() {
      _dragDelta += d.delta.dx;
      _isDragging = true;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails d, int total) {
    final threshold = 80.0;
    final velocity = d.velocity.pixelsPerSecond.dx;

    if (_dragDelta < -threshold || velocity < -400) {
      // swipe left → next
      _animateSwipe(-1, total);
    } else if (_dragDelta > threshold || velocity > 400) {
      // swipe right → prev
      _animateSwipe(1, total);
    } else {
      // snap back
      setState(() {
        _dragDelta = 0;
        _isDragging = false;
      });
    }
  }

  void _animateSwipe(int direction, int total) {
    final start = _dragDelta;
    _swipeAnimation = Tween<double>(begin: start, end: 0).animate(
      CurvedAnimation(parent: _swipeController, curve: Curves.easeOutBack),
    );

    _swipeController.forward(from: 0).then((_) {
      setState(() {
        _currentIndex =
            (_currentIndex - direction + total) % total;
        _dragDelta = 0;
        _isDragging = false;
      });
    });
  }

  void _toggleQuickActions() {
    setState(() => _showQuickActions = !_showQuickActions);
    if (_showQuickActions) {
      _sheetController.forward();
    } else {
      _sheetController.reverse();
    }
  }

  void _showSubcategorySheet(BuildContext ctx, ServiceCategory category) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SubcategorySheet(category: category),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = GlColors.of(context);
    final categories = ref.watch(categoriesProvider);
    if (categories.isEmpty) {
      return Center(
        child: Text(
          'Cargando...',
          style: GoogleFonts.inter(
            color: c.text.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    final screenSize = MediaQuery.of(context).size;

    return Stack(
      children: [
        // Main stacked card deck area
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section title
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  children: [
                    Text(
                      'Que necesitas hoy?',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                    const Spacer(),
                    // Business owner icon
                    Consumer(builder: (ctx, ref, _) {
                      final isBizOwner = ref.watch(isBusinessOwnerProvider);
                      return isBizOwner.when(
                        data: (isOwner) => isOwner
                            ? _GlIconButton(
                                icon: Icons.storefront_rounded,
                                onTap: () => context.push('/business'),
                              )
                            : const SizedBox.shrink(),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      );
                    }),
                    const SizedBox(width: 8),
                    _GlIconButton(
                      icon: Icons.settings_outlined,
                      onTap: () => context.push('/settings'),
                    ),
                  ],
                ),
              ),

              // Card deck
              Expanded(
                child: GestureDetector(
                  onHorizontalDragUpdate: _onHorizontalDragUpdate,
                  onHorizontalDragEnd: (d) =>
                      _onHorizontalDragEnd(d, categories.length),
                  child: _CardDeck(
                    categories: categories,
                    currentIndex: _currentIndex,
                    dragDelta: _isDragging
                        ? _dragDelta
                        : (_swipeController.isAnimating
                            ? _swipeAnimation.value
                            : 0),
                    onTap: (cat) => _showSubcategorySheet(context, cat),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Pagination dots
              _PaginationDots(
                count: categories.length,
                currentIndex: _currentIndex,
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),

        // Quick action handle at bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _QuickActionsPanel(
            isExpanded: _showQuickActions,
            animation: _sheetAnimation,
            onToggle: _toggleQuickActions,
            onInvite: () {
              if (_showQuickActions) _toggleQuickActions();
              context.push('/invite');
            },
          ),
        ),
      ],
    );
  }
}

// ─── Card Deck renderer ───────────────────────────────────────────────────────
class _CardDeck extends StatelessWidget {
  final List<ServiceCategory> categories;
  final int currentIndex;
  final double dragDelta;
  final ValueChanged<ServiceCategory> onTap;

  const _CardDeck({
    required this.categories,
    required this.currentIndex,
    required this.dragDelta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Show up to 3 cards: back → middle → front
    final count = categories.length;
    const visibleCards = 3;

    return Stack(
      alignment: Alignment.center,
      children: List.generate(
        math.min(visibleCards, count),
        (stackPos) {
          // stackPos 0 = front, visibleCards-1 = furthest back
          final revPos = (visibleCards - 1 - stackPos);
          final catIndex = (currentIndex + revPos) % count;
          final category = categories[catIndex];

          // Front card follows drag; back cards stay static
          final isFront = revPos == 0;
          final xOffset = isFront ? dragDelta * 0.4 : 0.0;
          final yOffset = stackPos * 10.0; // back cards peek from top
          final scale = 1.0 - revPos * 0.05;
          final opacity = 1.0 - revPos * 0.25;

          return Transform.translate(
            offset: Offset(xOffset, -yOffset),
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: _CategoryGlassCard(
                  category: category,
                  isFront: isFront,
                  dragDelta: isFront ? dragDelta : 0,
                  onTap: isFront ? () => onTap(category) : null,
                ),
              ),
            ),
          );
        },
      ).reversed.toList(),
    );
  }
}

// ─── Individual glass category card ──────────────────────────────────────────
class _CategoryGlassCard extends StatefulWidget {
  final ServiceCategory category;
  final bool isFront;
  final double dragDelta;
  final VoidCallback? onTap;

  const _CategoryGlassCard({
    required this.category,
    required this.isFront,
    required this.dragDelta,
    this.onTap,
  });

  @override
  State<_CategoryGlassCard> createState() => _CategoryGlassCardState();
}

class _CategoryGlassCardState extends State<_CategoryGlassCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = GlColors.of(context);
    final tiltAngle = widget.isFront ? widget.dragDelta * 0.0008 : 0.0;

    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.onTap != null
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Transform.rotate(
          angle: tiltAngle,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1,
                  ),
                  boxShadow: widget.isFront
                      ? [
                          BoxShadow(
                            color: widget.category.color
                                .withValues(alpha: 0.2),
                            blurRadius: 32,
                            spreadRadius: 4,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  children: [
                    // Ambient color glow top-right
                    Positioned(
                      top: -30,
                      right: -30,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              widget.category.color.withValues(alpha: 0.28),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Bottom ambient
                    Positioned(
                      bottom: -20,
                      left: -20,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              c.neonPurple.withValues(alpha: 0.15),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 36, 28, 36),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Top row: neon dot accent
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: widget.category.color,
                                  boxShadow: [
                                    BoxShadow(
                                      color: widget.category.color
                                          .withValues(alpha: 0.6),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                              if (widget.isFront)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.swipe_rounded,
                                      color: c.text
                                          .withValues(alpha: 0.25),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'desliza',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: c.text
                                            .withValues(alpha: 0.25),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),

                          // Big category icon centered
                          Center(
                            child: getCategoryIcon(
                              variant: ThemeVariant.glass,
                              categoryId: widget.category.id,
                              color: widget.category.color,
                              size: 80,
                            ),
                          ),

                          // Bottom: name + service count + tap hint
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.category.nameEs,
                                style: GoogleFonts.inter(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: c.text,
                                  shadows: [
                                    Shadow(
                                      color: widget.category.color
                                          .withValues(alpha: 0.4),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    '${widget.category.subcategories.length} servicios',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: c.text
                                          .withValues(alpha: 0.55),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (widget.isFront)
                                    ShaderMask(
                                      shaderCallback: (bounds) =>
                                          c.neonGradient.createShader(bounds),
                                      child: Text(
                                        'VER OPCIONES',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Pagination dots ──────────────────────────────────────────────────────────
class _PaginationDots extends StatelessWidget {
  final int count;
  final int currentIndex;

  const _PaginationDots({required this.count, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final c = GlColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        math.min(count, 8),
        (i) {
          final isActive = i == currentIndex % 8;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: isActive ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: isActive ? c.neonGradient : null,
              color: isActive
                  ? null
                  : c.text.withValues(alpha: 0.25),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: c.neonPink.withValues(alpha: 0.4),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          );
        },
      ),
    );
  }
}

// ─── Quick Actions Panel ──────────────────────────────────────────────────────
class _QuickActionsPanel extends StatelessWidget {
  final bool isExpanded;
  final Animation<double> animation;
  final VoidCallback onToggle;
  final VoidCallback onInvite;

  const _QuickActionsPanel({
    required this.isExpanded,
    required this.animation,
    required this.onToggle,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    final c = GlColors.of(context);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Expanded quick actions (fades in from bottom)
            if (animation.value > 0.01)
              Opacity(
                opacity: animation.value,
                child: Transform.translate(
                  offset: Offset(0, (1 - animation.value) * 40),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter:
                            ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _QuickActionTile(
                                icon: Icons.star_rounded,
                                label: 'Recomienda tu salon',
                                subtitle: 'Invita y gana beneficios',
                                onTap: onInvite,
                              ),
                              Container(
                                height: 0.5,
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16),
                                color:
                                    Colors.white.withValues(alpha: 0.08),
                              ),
                              _QuickActionTile(
                                icon: Icons.search_rounded,
                                label: 'Buscar salon',
                                subtitle: 'Encuentra por nombre',
                                onTap: () => context.push('/search'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Handle pill
            GestureDetector(
              onTap: onToggle,
              onVerticalDragEnd: (d) {
                if (d.velocity.pixelsPerSecond.dy < -200 && !isExpanded) {
                  onToggle();
                } else if (d.velocity.pixelsPerSecond.dy > 200 &&
                    isExpanded) {
                  onToggle();
                }
              },
              child: Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  width: 60,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: c.neonGradient,
                    boxShadow: [
                      BoxShadow(
                        color: c.neonPink.withValues(alpha: 0.4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = GlColors.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            ShaderMask(
              shaderCallback: (bounds) => c.neonGradient.createShader(bounds),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: c.text.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: c.text.withValues(alpha: 0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Small icon button (top bar) ──────────────────────────────────────────────
class _GlIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = GlColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 0.8,
              ),
            ),
            child: Icon(
              icon,
              color: c.text.withValues(alpha: 0.8),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
