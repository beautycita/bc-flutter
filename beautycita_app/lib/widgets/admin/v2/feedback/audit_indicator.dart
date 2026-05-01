// Admin v2 AuditIndicator — small "Acción registrada" affordance.
//
// Show as a 2-second toast / chip after a mutation completes successfully.
// Reinforces to the operator that the action was logged in audit_log
// (Phase 0 trigger fires automatically; this is the UI confirmation).

import 'package:flutter/material.dart';

import '../tokens.dart';

class AdminAuditIndicator extends StatelessWidget {
  const AdminAuditIndicator({super.key, this.label = 'Acción registrada'});
  final String label;

  static void show(BuildContext context, {String? label}) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.removeCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: AdminAuditIndicator(label: label ?? 'Acción registrada'),
        duration: const Duration(seconds: 2),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        behavior: SnackBarBehavior.floating,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AdminV2Tokens.radiusFull)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.fact_check_outlined, size: 18, color: AdminV2Tokens.success(context)),
        const SizedBox(width: AdminV2Tokens.spacingSM),
        Text(label, style: AdminV2Tokens.body(context)),
      ],
    );
  }
}
