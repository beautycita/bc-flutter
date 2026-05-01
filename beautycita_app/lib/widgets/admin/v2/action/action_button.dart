// Admin v2 ActionButton — primary / secondary / destructive variants.
// Server-truth: caller passes `isPermitted=false` to hide; UI never decides
// "is this allowed" — server decides via tier check on the underlying RPC.

import 'package:flutter/material.dart';

import '../tokens.dart';

enum AdminActionVariant { primary, secondary, destructive }

class AdminActionButton extends StatelessWidget {
  const AdminActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AdminActionVariant.primary,
    this.isLoading = false,
    this.requiresStepUp = false,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AdminActionVariant variant;
  final bool isLoading;
  final bool requiresStepUp;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (bg, fg) = switch (variant) {
      AdminActionVariant.primary => (colors.primary, colors.onPrimary),
      AdminActionVariant.secondary => (colors.surface, colors.primary),
      AdminActionVariant.destructive => (AdminV2Tokens.destructive(context), Colors.white),
    };
    final isOutlined = variant == AdminActionVariant.secondary;

    final child = isLoading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(fg)),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: AdminV2Tokens.spacingSM),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: fg, fontWeight: FontWeight.w600),
                ),
              ),
              if (requiresStepUp) ...[
                const SizedBox(width: AdminV2Tokens.spacingXS),
                Icon(Icons.lock_outline, size: 14, color: fg.withValues(alpha: 0.7)),
              ],
            ],
          );

    final padding = EdgeInsets.symmetric(
      horizontal: dense ? AdminV2Tokens.spacingMD : AdminV2Tokens.spacingLG,
      vertical: dense ? AdminV2Tokens.spacingSM : AdminV2Tokens.spacingMD,
    );

    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AdminV2Tokens.radiusFull));

    if (isOutlined) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AdminV2Tokens.minTapHeight),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: fg,
            side: BorderSide(color: fg.withValues(alpha: 0.4), width: 1.5),
            padding: padding,
            shape: shape,
          ),
          onPressed: isLoading ? null : onPressed,
          child: child,
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AdminV2Tokens.minTapHeight),
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          padding: padding,
          shape: shape,
        ),
        onPressed: isLoading ? null : onPressed,
        child: child,
      ),
    );
  }
}
