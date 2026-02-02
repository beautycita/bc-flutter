import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/category.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import '../providers/booking_flow_provider.dart';
import '../widgets/cinematic_question_text.dart';

String _getCategoryQuestion(String categoryId) {
  switch (categoryId) {
    case 'nails':
      return 'Manicure, pedicure o algo mas?';
    case 'hair':
      return 'Corte, color o tratamiento?';
    case 'skin':
      return 'Facial, limpieza o tratamiento?';
    case 'lashes':
      return 'Extensiones, lifting o tinte?';
    case 'body':
      return 'Masaje, depilacion o tratamiento?';
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
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.45,
      maxChildSize: AppConstants.bottomSheetMaxHeight,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: BeautyCitaTheme.backgroundWhite,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
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
                  color: Colors.grey[300],
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
                          color: category.color.withValues(alpha: 0.2),
                          width: 1.5,
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

                    // Cinematic question text
                    Expanded(
                      child: CinematicQuestionText(
                        text: _getCategoryQuestion(category.id),
                        primaryColor: category.color,
                        accentColor: BeautyCitaTheme.secondaryGold,
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
              ),

              // Subcategories list
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: category.subcategories.map((subcategory) {
                        return _SubcategoryPill(
                          subcategory: subcategory,
                          categoryColor: category.color,
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

class _SubcategoryPillState extends State<_SubcategoryPill> {
  bool _isPressed = false;

  bool _hasItems() {
    return widget.subcategory.items != null &&
        widget.subcategory.items!.isNotEmpty;
  }

  void _handleTap(BuildContext context) {
    if (_hasItems()) {
      _showItemsSheet(context);
    } else {
      Navigator.of(context).pop();
      final colorValue = widget.categoryColor.value;
      context.push(
          '/providers?category=${Uri.encodeComponent(widget.subcategory.categoryId)}&subcategory=${Uri.encodeComponent(widget.subcategory.nameEs)}&color=$colorValue');
    }
  }

  void _showItemsSheet(BuildContext context) {
    showModalBottomSheet(
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
        _handleTap(context);
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: _isPressed ? color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: _isPressed ? 0.4 : 0.18),
            width: 1.5,
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
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: AppConstants.bottomSheetMaxHeight,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: BeautyCitaTheme.backgroundWhite,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
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
                  color: Colors.grey[300],
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
                        color: BeautyCitaTheme.textLight,
                      ),
                    ),
                  ],
                ),
              ),

              // Items list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: subcategory.items?.length ?? 0,
                  itemBuilder: (context, index) {
                    final item = subcategory.items![index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ServiceItemTile(
                        item: item,
                        categoryColor: categoryColor,
                      ),
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
    Navigator.of(context).pop();
    Navigator.of(context).pop();
    context.push('/book');

    ref
        .read(bookingFlowProvider.notifier)
        .selectService(widget.item.serviceType, widget.item.nameEs);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.categoryColor;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _handleTap(context);
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: _isPressed
              ? color.withValues(alpha: 0.06)
              : BeautyCitaTheme.surfaceCream,
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
                  color: BeautyCitaTheme.textDark,
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
    );
  }
}
