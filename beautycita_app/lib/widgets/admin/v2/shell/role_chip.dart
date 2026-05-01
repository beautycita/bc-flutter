// Admin v2 RoleChip — small badge in the shell header showing caller's tier.
// Reads currentAdminTierProvider; renders nothing while loading.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/admin_provider.dart';
import '../tokens.dart';

class AdminRoleChip extends ConsumerWidget {
  const AdminRoleChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tierAsync = ref.watch(currentAdminTierProvider);
    return tierAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (tier) {
        final (label, color) = switch (tier) {
          AdminTier.opsAdmin => ('Ops', Colors.blueGrey),
          AdminTier.admin => ('Admin', Theme.of(context).colorScheme.primary),
          AdminTier.superadmin => ('Super', Colors.deepPurple),
          AdminTier.none => (null, AdminV2Tokens.subtle(context)),
        };
        if (label == null) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: AdminV2Tokens.spacingSM, vertical: AdminV2Tokens.spacingXS),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AdminV2Tokens.radiusFull),
          ),
          child: Text(label, style: AdminV2Tokens.muted(context).copyWith(color: color, fontWeight: FontWeight.w700)),
        );
      },
    );
  }
}
