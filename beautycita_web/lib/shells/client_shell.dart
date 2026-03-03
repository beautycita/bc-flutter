import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/router.dart';

class ClientShell extends StatelessWidget {
  const ClientShell({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentPath = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 56,
        title: Text(
          'BeautyCita',
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          _NavButton(
            label: 'Reservar',
            route: WebRoutes.reservar,
            isActive: currentPath == WebRoutes.reservar,
          ),
          _NavButton(
            label: 'Mis Citas',
            route: WebRoutes.misCitas,
            isActive: currentPath == WebRoutes.misCitas,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: child,
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.route,
    required this.isActive,
  });

  final String label;
  final String route;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextButton(
      onPressed: () => context.go(route),
      style: TextButton.styleFrom(
        foregroundColor: isActive
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface.withValues(alpha: 0.7),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}
