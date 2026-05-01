import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/config/fonts.dart';

import '../../providers/admin_provider.dart';

/// Compact pill showing the current admin tier. Renders in the v2 shell
/// header so the user always knows what permissions they're carrying.
/// Tap → opens a sheet listing what the tier can / can't do.
class RoleChip extends ConsumerWidget {
  const RoleChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tier = ref.watch(currentAdminTierProvider);
    final colors = Theme.of(context).colorScheme;
    return tier.when(
      data: (t) {
        final (label, color) = switch (t) {
          AdminTier.superadmin => ('Superadmin', const Color(0xFFE53935)),
          AdminTier.admin => ('Admin', const Color(0xFF1E88E5)),
          AdminTier.opsAdmin => ('Ops', const Color(0xFF43A047)),
          AdminTier.none => ('Sin permisos', colors.onSurface.withValues(alpha: 0.4)),
        };
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.32), width: 1),
          ),
          child: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        );
      },
      loading: () => const SizedBox(width: 64, height: 24),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
