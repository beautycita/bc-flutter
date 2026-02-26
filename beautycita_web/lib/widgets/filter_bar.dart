import 'package:beautycita_core/theme.dart';
import 'package:flutter/material.dart';

/// Horizontal bar with a search field and filter dropdowns.
///
/// Lays out the [searchField] on the left and [filters] on the right.
/// Shows a "Clear all" button when [onClearAll] is non-null (meaning at least
/// one filter is active). Wraps on narrow screens.
class FilterBar extends StatelessWidget {
  const FilterBar({
    this.searchField,
    this.filters = const [],
    this.onClearAll,
    super.key,
  });

  /// Text field with search icon. Placed at the left.
  final Widget? searchField;

  /// Dropdown / chip filters. Placed to the right of the search field.
  final List<Widget> filters;

  /// If non-null a "Limpiar" button is shown and calls this when tapped.
  final VoidCallback? onClearAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BCSpacing.md,
        vertical: BCSpacing.sm,
      ),
      child: Wrap(
        spacing: BCSpacing.sm,
        runSpacing: BCSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Search field — constrain max width so it doesn't stretch endlessly
          if (searchField != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: searchField!,
            ),

          // Filter widgets
          ...filters,

          // Clear all button
          if (onClearAll != null)
            TextButton.icon(
              onPressed: onClearAll,
              icon: Icon(
                Icons.clear_all,
                size: 18,
                color: colors.error,
              ),
              label: Text(
                'Limpiar',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
