import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/category.dart';
import '../config/theme.dart';
import '../config/constants.dart';

class SubcategorySheet extends StatelessWidget {
  final ServiceCategory category;

  const SubcategorySheet({
    super.key,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: AppConstants.bottomSheetMaxHeight,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: BeautyCitaTheme.backgroundWhite,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(BeautyCitaTheme.radiusXL),
            ),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.symmetric(
                  vertical: BeautyCitaTheme.spaceMD,
                ),
                width: AppConstants.bottomSheetDragHandleWidth,
                height: AppConstants.bottomSheetDragHandleHeight,
                decoration: BoxDecoration(
                  color: BeautyCitaTheme.dividerLight,
                  borderRadius: BorderRadius.circular(
                    AppConstants.bottomSheetDragHandleRadius,
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: BeautyCitaTheme.spaceLG,
                  vertical: BeautyCitaTheme.spaceMD,
                ),
                child: Row(
                  children: [
                    // Category icon
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: category.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(
                          BeautyCitaTheme.radiusMedium,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          category.icon,
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                    ),
                    const SizedBox(width: BeautyCitaTheme.spaceMD),

                    // Title
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¿Qué tipo de servicio?',
                            style: textTheme.titleMedium?.copyWith(
                              color: BeautyCitaTheme.textLight,
                            ),
                          ),
                          const SizedBox(height: BeautyCitaTheme.spaceXS),
                          Text(
                            category.nameEs,
                            style: textTheme.headlineSmall?.copyWith(
                              color: category.color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Subcategories list
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(BeautyCitaTheme.spaceLG),
                  children: [
                    Wrap(
                      spacing: BeautyCitaTheme.spaceMD,
                      runSpacing: BeautyCitaTheme.spaceMD,
                      children: category.subcategories.map((subcategory) {
                        return _SubcategoryChip(
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

class _SubcategoryChip extends StatelessWidget {
  final ServiceSubcategory subcategory;
  final Color categoryColor;

  const _SubcategoryChip({
    required this.subcategory,
    required this.categoryColor,
  });

  bool _hasItems() {
    return subcategory.items != null && subcategory.items!.isNotEmpty;
  }

  void _handleTap(BuildContext context) {
    if (_hasItems()) {
      _showItemsSheet(context);
    } else {
      // Navigate to provider list for this subcategory
      Navigator.of(context).pop(); // close bottom sheet
      final colorValue = categoryColor.value;
      context.push('/providers?category=${Uri.encodeComponent(subcategory.categoryId)}&subcategory=${Uri.encodeComponent(subcategory.nameEs)}&color=$colorValue');
    }
  }

  void _showItemsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ServiceItemsSheet(
        subcategory: subcategory,
        categoryColor: categoryColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Material(
      color: categoryColor.withOpacity(0.1),
      borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusLarge),
      child: InkWell(
        onTap: () => _handleTap(context),
        borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusLarge),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: BeautyCitaTheme.spaceLG,
            vertical: BeautyCitaTheme.spaceMD,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: categoryColor.withOpacity(0.3),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusLarge),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                subcategory.nameEs,
                style: textTheme.titleMedium?.copyWith(
                  color: categoryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_hasItems()) ...[
                const SizedBox(width: BeautyCitaTheme.spaceXS),
                Icon(
                  Icons.chevron_right,
                  color: categoryColor,
                  size: AppConstants.iconSizeSM,
                ),
              ],
            ],
          ),
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
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: AppConstants.bottomSheetMaxHeight,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: BeautyCitaTheme.backgroundWhite,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(BeautyCitaTheme.radiusXL),
            ),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.symmetric(
                  vertical: BeautyCitaTheme.spaceMD,
                ),
                width: AppConstants.bottomSheetDragHandleWidth,
                height: AppConstants.bottomSheetDragHandleHeight,
                decoration: BoxDecoration(
                  color: BeautyCitaTheme.dividerLight,
                  borderRadius: BorderRadius.circular(
                    AppConstants.bottomSheetDragHandleRadius,
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: BeautyCitaTheme.spaceLG,
                  vertical: BeautyCitaTheme.spaceMD,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subcategory.nameEs,
                      style: textTheme.headlineSmall?.copyWith(
                        color: categoryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: BeautyCitaTheme.spaceXS),
                    Text(
                      'Selecciona un servicio específico',
                      style: textTheme.bodyMedium?.copyWith(
                        color: BeautyCitaTheme.textLight,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Items list
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.all(BeautyCitaTheme.spaceLG),
                  itemCount: subcategory.items?.length ?? 0,
                  separatorBuilder: (context, index) => const SizedBox(
                    height: BeautyCitaTheme.spaceSM,
                  ),
                  itemBuilder: (context, index) {
                    final item = subcategory.items![index];
                    return _ServiceItemTile(
                      item: item,
                      categoryColor: categoryColor,
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

class _ServiceItemTile extends StatelessWidget {
  final ServiceItem item;
  final Color categoryColor;

  const _ServiceItemTile({
    required this.item,
    required this.categoryColor,
  });

  void _handleTap(BuildContext context) {
    // Close both bottom sheets then navigate to provider list
    Navigator.of(context).pop();
    Navigator.of(context).pop();
    final colorValue = categoryColor.value;
    context.push('/providers?category=${Uri.encodeComponent(item.subcategoryId)}&subcategory=${Uri.encodeComponent(item.nameEs)}&color=$colorValue');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Material(
      color: BeautyCitaTheme.surfaceCream,
      borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
      child: InkWell(
        onTap: () => _handleTap(context),
        borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
        child: Container(
          padding: const EdgeInsets.all(BeautyCitaTheme.spaceMD),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
          ),
          child: Row(
            children: [
              // Icon indicator
              Container(
                width: 8,
                height: 40,
                decoration: BoxDecoration(
                  color: categoryColor,
                  borderRadius: BorderRadius.circular(4.0),
                ),
              ),
              const SizedBox(width: BeautyCitaTheme.spaceMD),

              // Item name
              Expanded(
                child: Text(
                  item.nameEs,
                  style: textTheme.titleMedium?.copyWith(
                    color: BeautyCitaTheme.textDark,
                  ),
                ),
              ),

              // Chevron
              Icon(
                Icons.arrow_forward_ios,
                color: categoryColor.withOpacity(0.5),
                size: AppConstants.iconSizeSM,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
