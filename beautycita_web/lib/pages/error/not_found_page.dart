import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/router.dart';

/// 404 page shown when no route matches.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '404',
              style: theme.textTheme.displayLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Pagina no encontrada',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.go(WebRoutes.auth),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Volver al inicio'),
            ),
          ],
        ),
      ),
    );
  }
}
