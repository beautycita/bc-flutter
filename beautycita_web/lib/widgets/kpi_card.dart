import 'package:flutter/material.dart';

/// Reusable KPI card for the admin dashboard.
///
/// Displays:
/// - Colored icon with background circle
/// - Large bold value
/// - Label text
/// - Optional change indicator (up/down arrow + percentage)
class KpiCard extends StatefulWidget {
  const KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
    this.changePercent,
    this.prefix = '',
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;

  /// If non-null, shows a change indicator arrow + percentage.
  /// Positive = green up arrow, negative = red down arrow, zero = neutral.
  final double? changePercent;

  /// Optional prefix for the value (e.g. "\$").
  final String prefix;

  @override
  State<KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<KpiCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final effectiveIconColor = widget.iconColor ?? colors.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hovering
                ? effectiveIconColor.withValues(alpha: 0.3)
                : colors.outlineVariant,
            width: 1,
          ),
          boxShadow: _hovering
              ? [
                  BoxShadow(
                    color: effectiveIconColor.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with colored background
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: effectiveIconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 22, color: effectiveIconColor),
                ),
                const Spacer(),
                // Change indicator
                if (widget.changePercent != null)
                  _ChangeChip(percent: widget.changePercent!),
              ],
            ),
            const SizedBox(height: 16),
            // Value
            Text(
              '${widget.prefix}${widget.value}',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Label
            Text(
              widget.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  IconData get icon => widget.icon;
}

/// Small chip showing percentage change with colored arrow.
class _ChangeChip extends StatelessWidget {
  const _ChangeChip({required this.percent});
  final double percent;

  @override
  Widget build(BuildContext context) {
    final isPositive = percent > 0;
    final isNeutral = percent == 0;
    final color = isNeutral
        ? Colors.grey
        : isPositive
            ? const Color(0xFF4CAF50)
            : const Color(0xFFE53935);
    final icon = isNeutral
        ? Icons.remove
        : isPositive
            ? Icons.arrow_upward
            : Icons.arrow_downward;
    final text = isNeutral
        ? '0%'
        : '${isPositive ? '+' : ''}${percent.toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 2),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
