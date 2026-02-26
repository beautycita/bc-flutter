import 'package:beautycita_core/theme.dart';
import 'package:flutter/material.dart';

/// Sticky bottom bar that appears when items are selected in a data table.
///
/// Shows the selection count, action buttons, and a clear-selection button.
/// Slides up from the bottom with a 200ms animation.
class BulkActionBar extends StatelessWidget {
  const BulkActionBar({
    required this.selectedCount,
    required this.actions,
    required this.onClearSelection,
    super.key,
  });

  /// Number of currently selected items.
  final int selectedCount;

  /// Action buttons (delete, export, etc.).
  final List<Widget> actions;

  /// Called when the user taps "Deseleccionar".
  final VoidCallback onClearSelection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AnimatedSlide(
      offset: selectedCount > 0 ? Offset.zero : const Offset(0, 1),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: selectedCount > 0 ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: BCSpacing.md,
            vertical: BCSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(
              top: BorderSide(color: colors.outlineVariant),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.onSurface.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Selection count
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: BCSpacing.sm,
                  vertical: BCSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
                ),
                child: Text(
                  '$selectedCount seleccionados',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(width: BCSpacing.md),

              // Actions
              ...actions.map(
                (action) => Padding(
                  padding: const EdgeInsets.only(right: BCSpacing.sm),
                  child: action,
                ),
              ),

              const Spacer(),

              // Clear selection
              TextButton(
                onPressed: onClearSelection,
                child: Text(
                  'Deseleccionar',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.6),
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
