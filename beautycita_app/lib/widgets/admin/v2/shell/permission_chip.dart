// Admin v2 PermissionChip — small badge showing why an action is hidden/gated.
// Used inside DangerZone cards to set operator expectation:
//   "Solo lectura" — caller's tier doesn't permit
//   "Requiere step-up" — caller will be re-auth-prompted

import 'package:flutter/material.dart';

import '../tokens.dart';

enum AdminPermissionState { allowed, requiresStepUp, readOnly }

class AdminPermissionChip extends StatelessWidget {
  const AdminPermissionChip({super.key, required this.state});
  final AdminPermissionState state;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (state) {
      AdminPermissionState.allowed => ('Permitido', Icons.check_circle_outline, AdminV2Tokens.success(context)),
      AdminPermissionState.requiresStepUp => ('Requiere step-up', Icons.lock_outline, AdminV2Tokens.warning(context)),
      AdminPermissionState.readOnly => ('Solo lectura', Icons.visibility_outlined, AdminV2Tokens.subtle(context)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AdminV2Tokens.spacingSM, vertical: AdminV2Tokens.spacingXS),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AdminV2Tokens.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AdminV2Tokens.spacingXS),
          Text(label, style: AdminV2Tokens.muted(context).copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
