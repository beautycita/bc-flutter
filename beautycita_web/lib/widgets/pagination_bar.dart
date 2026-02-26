import 'dart:math' as math;

import 'package:beautycita_core/theme.dart';
import 'package:flutter/material.dart';

/// Bottom pagination controls for data tables.
///
/// Shows "Mostrando 1-20 de 150", page-size dropdown, and prev/next buttons
/// with page-number indicators.
class PaginationBar extends StatelessWidget {
  const PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.pageSize,
    required this.onPageChanged,
    required this.onPageSizeChanged,
    super.key,
  });

  /// Zero-based current page index.
  final int currentPage;

  /// Total number of pages.
  final int totalPages;

  /// Total number of items across all pages.
  final int totalItems;

  /// Items per page.
  final int pageSize;

  /// Fires when user navigates to a different page (zero-based index).
  final ValueChanged<int> onPageChanged;

  /// Fires when user changes items-per-page.
  final ValueChanged<int> onPageSizeChanged;

  static const _pageSizes = [10, 20, 50, 100];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final start = totalItems == 0 ? 0 : (currentPage * pageSize) + 1;
    final end = math.min((currentPage + 1) * pageSize, totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BCSpacing.md,
        vertical: BCSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          // "Showing X-Y of Z"
          Text(
            'Mostrando $start-$end de $totalItems',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.6),
            ),
          ),

          const SizedBox(width: BCSpacing.md),

          // Page size dropdown
          _PageSizeDropdown(
            value: pageSize,
            onChanged: onPageSizeChanged,
          ),

          const Spacer(),

          // Page number indicators
          ..._buildPageIndicators(context),

          const SizedBox(width: BCSpacing.sm),

          // Previous
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: currentPage > 0
                ? () => onPageChanged(currentPage - 1)
                : null,
            tooltip: 'Anterior',
            style: IconButton.styleFrom(
              minimumSize: const Size(36, 36),
            ),
          ),

          // Next
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: currentPage < totalPages - 1
                ? () => onPageChanged(currentPage + 1)
                : null,
            tooltip: 'Siguiente',
            style: IconButton.styleFrom(
              minimumSize: const Size(36, 36),
            ),
          ),
        ],
      ),
    );
  }

  /// Build a compact list of page number buttons with ellipsis.
  List<Widget> _buildPageIndicators(BuildContext context) {
    if (totalPages <= 1) return const [];

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final pages = <Widget>[];

    // Show at most 5 page buttons with ellipsis
    const maxVisible = 5;
    int startPage = 0;
    int endPage = totalPages - 1;

    if (totalPages > maxVisible) {
      startPage = math.max(0, currentPage - 2);
      endPage = math.min(totalPages - 1, startPage + maxVisible - 1);
      if (endPage - startPage < maxVisible - 1) {
        startPage = math.max(0, endPage - maxVisible + 1);
      }
    }

    // First page + ellipsis
    if (startPage > 0) {
      pages.add(_pageButton(context, 0, colors, theme));
      if (startPage > 1) {
        pages.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            '...',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ));
      }
    }

    // Visible range
    for (int i = startPage; i <= endPage; i++) {
      pages.add(_pageButton(context, i, colors, theme));
    }

    // Ellipsis + last page
    if (endPage < totalPages - 1) {
      if (endPage < totalPages - 2) {
        pages.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            '...',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ));
      }
      pages.add(_pageButton(context, totalPages - 1, colors, theme));
    }

    return pages;
  }

  Widget _pageButton(
    BuildContext context,
    int page,
    ColorScheme colors,
    ThemeData theme,
  ) {
    final isActive = page == currentPage;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: SizedBox(
        width: 32,
        height: 32,
        child: TextButton(
          onPressed: isActive ? null : () => onPageChanged(page),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(32, 32),
            backgroundColor:
                isActive ? colors.primary.withValues(alpha: 0.1) : null,
            foregroundColor: isActive ? colors.primary : colors.onSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: Text(
            '${page + 1}',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Page size dropdown ────────────────────────────────────────────────────────

class _PageSizeDropdown extends StatelessWidget {
  const _PageSizeDropdown({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Por pagina:',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(width: BCSpacing.xs),
        DropdownButton<int>(
          value: value,
          underline: const SizedBox.shrink(),
          isDense: true,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w500,
          ),
          items: PaginationBar._pageSizes
              .map((size) => DropdownMenuItem<int>(
                    value: size,
                    child: Text('$size'),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }
}
