import 'package:beautycita_core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Shimmer loading placeholder that mimics a data table.
///
/// Displays [rows] x [columns] rounded rectangles with a shimmer sweep
/// animation powered by `flutter_animate`.
class TableLoadingSkeleton extends StatelessWidget {
  const TableLoadingSkeleton({
    this.rows = 5,
    this.columns = 4,
    super.key,
  });

  /// Number of placeholder rows to display.
  final int rows;

  /// Number of placeholder cells per row.
  final int columns;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final baseColor = colors.onSurface.withValues(alpha: 0.06);

    return Column(
      children: [
        // Header row
        _SkeletonRow(
          columns: columns,
          baseColor: baseColor,
          height: 14,
          isHeader: true,
        ),
        const Divider(height: 1),
        // Data rows
        for (int i = 0; i < rows; i++) ...[
          _SkeletonRow(
            columns: columns,
            baseColor: baseColor,
            height: 12,
            isHeader: false,
          ),
          if (i < rows - 1) const Divider(height: 1),
        ],
      ],
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({
    required this.columns,
    required this.baseColor,
    required this.height,
    required this.isHeader,
  });

  final int columns;
  final Color baseColor;
  final double height;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BCSpacing.md,
        vertical: BCSpacing.md,
      ),
      child: Row(
        children: [
          for (int i = 0; i < columns; i++) ...[
            if (i > 0) const SizedBox(width: BCSpacing.md),
            Expanded(
              // First column wider, last column narrower
              flex: i == 0 ? 3 : (i == columns - 1 ? 1 : 2),
              child: _ShimmerBlock(
                height: height,
                baseColor: baseColor,
                width: isHeader ? 0.6 : (0.5 + (i * 0.1).clamp(0, 0.3)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShimmerBlock extends StatelessWidget {
  const _ShimmerBlock({
    required this.height,
    required this.baseColor,
    required this.width,
  });

  final double height;
  final Color baseColor;

  /// Fraction of available width to fill (0.0–1.0).
  final double width;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: width.clamp(0.3, 1.0),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(BCSpacing.xs),
        ),
      )
          .animate(
            onPlay: (controller) => controller.repeat(),
          )
          .shimmer(
            duration: const Duration(milliseconds: 1200),
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.04),
          ),
    );
  }
}
