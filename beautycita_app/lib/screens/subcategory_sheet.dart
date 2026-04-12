import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/category.dart';
import '../providers/booking_flow_provider.dart';
import '../providers/search_history_provider.dart';
import '../services/toast_service.dart';
import '../widgets/booking_flow_background.dart';

String _getCategoryQuestion(String categoryId) {
  switch (categoryId) {
    case 'nails':
      return 'Manicure, pedicure o algo mas?';
    case 'hair':
      return 'Corte, color o tratamiento?';
    case 'facial':
      return 'Facial, limpieza o tratamiento?';
    case 'lashes_brows':
      return 'Extensiones, lifting o tinte?';
    case 'body_spa':
      return 'Masaje, depilacion o tratamiento?';
    case 'makeup':
      return 'Que tipo de maquillaje?';
    case 'specialized':
      return 'Que tratamiento necesitas?';
    case 'barberia':
      return 'Corte, barba o afeitado?';
    default:
      return 'Que servicio te interesa?';
  }
}

/// Full-screen booking flow page for subcategory/item selection.
///
/// Uses [BookingFlowBackground] with a looping R2 video and gyro parallax.
/// Chips animate in from the bottom. Tapping a chip with items transitions
/// in-place (same screen, same background) to the item chips.
class SubcategorySheet extends StatefulWidget {
  final ServiceCategory category;

  const SubcategorySheet({
    super.key,
    required this.category,
  });

  @override
  State<SubcategorySheet> createState() => _SubcategorySheetState();
}

class _SubcategorySheetState extends State<SubcategorySheet>
    with TickerProviderStateMixin {
  /// When non-null, we're showing items for this subcategory.
  ServiceSubcategory? _selectedSub;

  /// Key used to trigger AnimatedSwitcher transitions.
  int _depth = 0;

  void _selectSubcategory(ServiceSubcategory sub) {
    setState(() {
      _selectedSub = sub;
      _depth++;
    });
  }

  void _goBackToSubcategories() {
    setState(() {
      _selectedSub = null;
      _depth++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: BookingFlowBackground(
        categoryId: widget.category.id,
        accentColor: widget.category.color,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top zone: back button + header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        if (_selectedSub != null) {
                          _goBackToSubcategories();
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.category.nameEs,
                            style: GoogleFonts.poppins(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Text(
                              _selectedSub != null
                                  ? _selectedSub!.nameEs
                                  : _getCategoryQuestion(widget.category.id),
                              key: ValueKey(_selectedSub?.id ?? '__root'),
                              style: GoogleFonts.nunito(
                                fontSize: 15,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: 350.ms, delay: 100.ms)
                  .slideY(
                      begin: -0.1,
                      end: 0,
                      duration: 350.ms,
                      curve: Curves.easeOutCubic),

              // ── Spacer: push chips to bottom (thumb-reachable) ──
              const Spacer(),

              // ── Bottom zone: chips (thumb-reachable, bottom 55%) ──
              SizedBox(
                height: mq.size.height * 0.55,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final slideIn = Tween<Offset>(
                      begin: const Offset(1.0, 0.0),
                      end: Offset.zero,
                    ).animate(animation);
                    return SlideTransition(
                      position: slideIn,
                      child: child,
                    );
                  },
                  // Keep both children visible during the crossfade (prevents flash)
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      children: [
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    );
                  },
                  child: _selectedSub != null
                      ? _ItemChips(
                          key: ValueKey('items_$_depth'),
                          subcategory: _selectedSub!,
                          categoryColor: widget.category.color,
                        )
                      : _SubcategoryChips(
                          key: ValueKey('subs_$_depth'),
                          category: widget.category,
                          onSelect: _selectSubcategory,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Subcategory chips ─────────────────────────────────────────────────────────

class _SubcategoryChips extends StatelessWidget {
  final ServiceCategory category;
  final ValueChanged<ServiceSubcategory> onSelect;

  const _SubcategoryChips({
    super.key,
    required this.category,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children:
              category.subcategories.asMap().entries.map((entry) {
            final index = entry.key;
            final sub = entry.value;
            return _GlassPill(
              label: sub.nameEs,
              hasChevron: sub.items != null && sub.items!.isNotEmpty,
              onTap: () {
                if (sub.items != null && sub.items!.isNotEmpty) {
                  onSelect(sub);
                } else {
                  // Direct navigate — no items
                  Navigator.of(context).pop();
                  final colorValue = category.color.toARGB32();
                  context.push(
                    '/providers?category=${Uri.encodeComponent(sub.categoryId)}&subcategory=${Uri.encodeComponent(sub.nameEs)}&color=$colorValue',
                  );
                }
              },
            )
                .animate()
                .fadeIn(
                  duration: 350.ms,
                  delay: (65 * index).ms,
                  curve: Curves.easeOut,
                )
                .slideY(
                  begin: 0.4,
                  end: 0,
                  duration: 400.ms,
                  delay: (65 * index).ms,
                  curve: Curves.easeOutCubic,
                )
                .scale(
                  begin: const Offset(0.92, 0.92),
                  end: const Offset(1, 1),
                  duration: 350.ms,
                  delay: (65 * index).ms,
                  curve: Curves.easeOutCubic,
                );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Item chips (second depth) ─────────────────────────────────────────────────

class _ItemChips extends ConsumerWidget {
  final ServiceSubcategory subcategory;
  final Color categoryColor;

  const _ItemChips({
    super.key,
    required this.subcategory,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = subcategory.items ?? [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _GlassPill(
              label: item.nameEs,
              hasChevron: false,
              onTap: () {
                final serviceType = item.serviceType;
                if (serviceType.isEmpty) {
                  ToastService.showWarning('Servicio no disponible');
                  return;
                }
                Navigator.of(context).pop();
                context.push('/book');
                ref
                    .read(bookingFlowProvider.notifier)
                    .selectService(serviceType, item.nameEs);
                ref.read(searchHistoryProvider.notifier).addEntry(
                      serviceType: item.serviceType,
                      serviceName: item.nameEs,
                      category: item.subcategoryId,
                    );
              },
            )
                .animate()
                .fadeIn(
                  duration: 350.ms,
                  delay: (65 * index).ms,
                  curve: Curves.easeOut,
                )
                .slideY(
                  begin: 0.4,
                  end: 0,
                  duration: 400.ms,
                  delay: (65 * index).ms,
                  curve: Curves.easeOutCubic,
                )
                .scale(
                  begin: const Offset(0.92, 0.92),
                  end: const Offset(1, 1),
                  duration: 350.ms,
                  delay: (65 * index).ms,
                  curve: Curves.easeOutCubic,
                );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Glass pill (frosted chip on dark background) ──────────────────────────────

class _GlassPill extends StatefulWidget {
  final String label;
  final bool hasChevron;
  final VoidCallback onTap;

  const _GlassPill({
    required this.label,
    required this.hasChevron,
    required this.onTap,
  });

  @override
  State<_GlassPill> createState() => _GlassPillState();
}

class _GlassPillState extends State<_GlassPill>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  bool _showShimmer = false;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  void _playShimmer() {
    setState(() => _showShimmer = true);
    _shimmerController.forward(from: 0).then((_) {
      if (mounted) setState(() => _showShimmer = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        HapticFeedback.selectionClick();
        _playShimmer();
        // Short delay so shimmer is visible
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) widget.onTap();
        });
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: _isPressed ? Curves.easeIn : Curves.elasticOut,
        child: AnimatedBuilder(
          animation: _shimmerController,
          builder: (context, child) {
            final pill = Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: BoxDecoration(
                color: _isPressed
                    ? Colors.white.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  if (widget.hasChevron) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white.withValues(alpha: 0.5),
                      size: 20,
                    ),
                  ],
                ],
              ),
            );

            if (!_showShimmer) return pill;

            final shimmerOffset = -1.0 + 2.0 * _shimmerController.value;
            return ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (bounds) {
                return LinearGradient(
                  begin: Alignment(shimmerOffset - 0.5, 0),
                  end: Alignment(shimmerOffset + 0.5, 0),
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.35),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ).createShader(bounds);
              },
              child: pill,
            );
          },
        ),
      ),
    );
  }
}

// ── Item tile (for second-level items) ────────────────────────────────────────

class _ItemTile extends StatefulWidget {
  final ServiceItem item;
  final Color categoryColor;
  final VoidCallback onTap;

  const _ItemTile({
    required this.item,
    required this.categoryColor,
    required this.onTap,
  });

  @override
  State<_ItemTile> createState() => _ItemTileState();
}

class _ItemTileState extends State<_ItemTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: _isPressed ? Curves.easeIn : Curves.elasticOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: _isPressed
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.item.nameEs,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withValues(alpha: 0.35), size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
