import 'package:beautycita_core/theme.dart';
import 'package:flutter/material.dart';

/// Centered empty-state placeholder with icon, title, subtitle, and optional CTA.
///
/// Used inside [BCDataTable] when the items list is empty, and anywhere else
/// a "nothing here yet" screen is needed.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    required this.icon,
    this.subtitle,
    this.action,
    super.key,
  });

  /// Primary message (e.g. "No hay usuarios").
  final String title;

  /// Explanatory text below the title.
  final String? subtitle;

  /// Large icon rendered above the title.
  final IconData icon;

  /// Optional call-to-action widget (button, link, etc.).
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: BCSpacing.xl,
          vertical: BCSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: BCSpacing.iconXl,
                color: colors.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: BCSpacing.lg),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: BCSpacing.sm),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: BCSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
