// Admin v2 EmptyState primitive.
//
// Unified container for: loading / empty / error / no-permission.
// All four states use the same shape; only the icon, title, body, and action
// vary. Forces consistent UX for every blank-or-broken state in admin v2.

import 'package:flutter/material.dart';

import '../tokens.dart';

enum AdminEmptyKind { loading, empty, error, noPermission }

class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    super.key,
    required this.kind,
    this.title,
    this.body,
    this.action,
    this.onAction,
  });

  final AdminEmptyKind kind;
  final String? title;
  final String? body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (icon, defaultTitle, color) = switch (kind) {
      AdminEmptyKind.loading => (Icons.hourglass_empty, 'Cargando...', colors.primary),
      AdminEmptyKind.empty => (Icons.inbox_outlined, 'Sin datos', AdminV2Tokens.subtle(context)),
      AdminEmptyKind.error => (Icons.error_outline, 'Error', AdminV2Tokens.destructive(context)),
      AdminEmptyKind.noPermission => (Icons.lock_outline, 'Sin acceso', AdminV2Tokens.subtle(context)),
    };

    return Padding(
      padding: const EdgeInsets.all(AdminV2Tokens.spacingLG),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (kind == AdminEmptyKind.loading)
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          else
            Icon(icon, size: 40, color: color.withValues(alpha: 0.6)),
          const SizedBox(height: AdminV2Tokens.spacingSM),
          Text(
            title ?? defaultTitle,
            style: AdminV2Tokens.subtitle(context),
            textAlign: TextAlign.center,
          ),
          if (body != null) ...[
            const SizedBox(height: AdminV2Tokens.spacingXS),
            Text(
              body!,
              style: AdminV2Tokens.muted(context),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null && onAction != null) ...[
            const SizedBox(height: AdminV2Tokens.spacingMD),
            TextButton(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    );
  }
}
