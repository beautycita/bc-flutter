import 'package:flutter/material.dart';

/// Admin shell scaffold with sidebar placeholder.
///
/// Full sidebar with navigation built in Task 1.3.
class AdminShell extends StatelessWidget {
  const AdminShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Row(
        children: [
          // Sidebar placeholder (240px)
          Container(
            width: 240,
            color: theme.colorScheme.surface,
            child: Column(
              children: [
                const SizedBox(height: 24),
                Text(
                  'BeautyCita',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Admin',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          // Vertical divider
          VerticalDivider(width: 1, thickness: 1, color: theme.dividerColor),
          // Content area
          Expanded(child: child),
        ],
      ),
    );
  }
}
