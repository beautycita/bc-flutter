import 'package:flutter/material.dart';
import 'package:beautycita/config/app_transitions.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/category.dart';
import '../config/constants.dart';
import '../providers/booking_flow_provider.dart';
import '../providers/search_history_provider.dart';
import '../services/toast_service.dart';

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

class SubcategorySheet extends StatelessWidget {
  final ServiceCategory category;

  const SubcategorySheet({
    super.key,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.45,
      maxChildSize: AppConstants.bottomSheetMaxHeight,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppConstants.radiusXL),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF000000).withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header with category icon and title
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Row(
                  children: [
                    // Category emoji in colored circle
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            category.color.withValues(alpha: 0.15),
                            category.color.withValues(alpha: 0.08),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          category.icon,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Question text
                    Expanded(
                      child: Text(
                        _getCategoryQuestion(category.id),
                        style: GoogleFonts.poppins(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: palette.onSurface,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: 350.ms, curve: Curves.easeOut)
                  .slideX(begin: -0.05, end: 0, duration: 350.ms, curve: Curves.easeOutCubic),

              // Subcategories list
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: category.subcategories.asMap().entries.map((entry) {
                        final index = entry.key;
                        final subcategory = entry.value;
                        return _SubcategoryPill(
                          subcategory: subcategory,
                          categoryColor: category.color,
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
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SubcategoryPill extends StatefulWidget {
  final ServiceSubcategory subcategory;
  final Color categoryColor;

  const _SubcategoryPill({
    required this.subcategory,
    required this.categoryColor,
  });

  @override
  State<_SubcategoryPill> createState() => _SubcategoryPillState();
}

class _SubcategoryPillState extends State<_SubcategoryPill>
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

  bool _hasItems() {
    final items = widget.subcategory.items;
    return items != null && items.isNotEmpty;
  }

  void _handleTap(BuildContext ctx) {
    _playShimmer();
    final navigator = Navigator.of(ctx);
    final router = GoRouter.of(ctx);
    if (_hasItems()) {
      // Short delay so shimmer is visible before sheet opens
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _showItemsSheet(context);
      });
    } else {
      // Capture values before async gap
      final colorValue = widget.categoryColor.toARGB32();
      final catId = widget.subcategory.categoryId;
      final nameEs = widget.subcategory.nameEs;
      // Short delay so shimmer is visible before navigation
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        navigator.pop();
        router.push(
            '/providers?category=${Uri.encodeComponent(catId)}&subcategory=${Uri.encodeComponent(nameEs)}&color=$colorValue');
      });
    }
  }

  void _showItemsSheet(BuildContext context) {
    showBurstBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ServiceItemsSheet(
        subcategory: widget.subcategory,
        categoryColor: widget.categoryColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.categoryColor;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        HapticFeedback.selectionClick();
        _handleTap(context);
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: _isPressed ? Curves.easeInCubic : Curves.elasticOut,
        child: AnimatedBuilder(
          animation: _shimmerController,
          builder: (context, child) {
            final pillChild = AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: _isPressed ? color.withValues(alpha: 0.12) : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
                boxShadow: _isPressed
                    ? []
                    : [
                        BoxShadow(
                          color: color.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.subcategory.nameEs,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: color.withValues(alpha: 0.85),
                    ),
                  ),
                  if (_hasItems()) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: color.withValues(alpha: 0.5),
                      size: 20,
                    ),
                  ],
                ],
              ),
            );

            if (!_showShimmer) return pillChild;

            // Shimmer gradient sweep left to right
            final shimmerOffset = -1.0 + 2.0 * _shimmerController.value;
            return ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (bounds) {
                return LinearGradient(
                  begin: Alignment(shimmerOffset - 0.5, 0),
                  end: Alignment(shimmerOffset + 0.5, 0),
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    color.withValues(alpha: 0.35),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ).createShader(bounds);
              },
              child: pillChild,
            );
          },
        ),
      ),
    );
  }
}

class _ServiceItemsSheet extends StatelessWidget {
  final ServiceSubcategory subcategory;
  final Color categoryColor;

  const _ServiceItemsSheet({
    required this.subcategory,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: AppConstants.bottomSheetMaxHeight,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppConstants.radiusXL),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF000000).withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subcategory.nameEs,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: categoryColor,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Elige el tipo exacto',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: palette.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: 350.ms, curve: Curves.easeOut)
                  .slideX(begin: -0.05, end: 0, duration: 350.ms, curve: Curves.easeOutCubic),

              // Items list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: (subcategory.items ?? []).length,
                  itemBuilder: (context, index) {
                    final items = subcategory.items ?? [];
                    final item = items[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ServiceItemTile(
                        item: item,
                        categoryColor: categoryColor,
                      ),
                    )
                        .animate()
                        .fadeIn(
                          duration: 300.ms,
                          delay: (60 * index).ms,
                          curve: Curves.easeOut,
                        )
                        .slideX(
                          begin: 0.06,
                          end: 0,
                          duration: 300.ms,
                          delay: (60 * index).ms,
                          curve: Curves.easeOutCubic,
                        );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ServiceItemTile extends ConsumerStatefulWidget {
  final ServiceItem item;
  final Color categoryColor;

  const _ServiceItemTile({
    required this.item,
    required this.categoryColor,
  });

  @override
  ConsumerState<_ServiceItemTile> createState() => _ServiceItemTileState();
}

class _ServiceItemTileState extends ConsumerState<_ServiceItemTile> {
  bool _isPressed = false;

  void _handleTap(BuildContext context) {
    final serviceType = widget.item.serviceType;
    if (serviceType.isEmpty) {
      ToastService.showWarning('Servicio no disponible');
      return;
    }

    Navigator.of(context).pop();
    Navigator.of(context).pop();
    context.push('/book');

    ref
        .read(bookingFlowProvider.notifier)
        .selectService(serviceType, widget.item.nameEs);

    // Save to search history
    ref.read(searchHistoryProvider.notifier).addEntry(
          serviceType: widget.item.serviceType,
          serviceName: widget.item.nameEs,
          category: widget.item.subcategoryId,
        );
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.categoryColor;
    final palette = Theme.of(context).colorScheme;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        HapticFeedback.lightImpact();
        _handleTap(context);
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: _isPressed ? Curves.easeInCubic : Curves.elasticOut,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: _isPressed
              ? color.withValues(alpha: 0.06)
              : palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isPressed
                ? color.withValues(alpha: 0.2)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Colored accent bar
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 14),

            // Item name
            Expanded(
              child: Text(
                widget.item.nameEs,
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: palette.onSurface,
                ),
              ),
            ),

            // Chevron
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: color.withValues(alpha: 0.35),
              size: 16,
            ),
          ],
        ),
      ),
      ),
    );
  }
}
