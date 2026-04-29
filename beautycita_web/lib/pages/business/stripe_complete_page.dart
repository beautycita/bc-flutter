import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/router.dart';
import '../../config/web_theme.dart';
import '../../providers/business_portal_provider.dart';

/// Lands here from Stripe's hosted onboarding return_url. Validates that the
/// `business_id` query param actually belongs to the signed-in user before
/// bouncing into the negocio payments dashboard. A mismatch silently routes
/// to home so a tampered link can't surface another salon's onboarding state.
class StripeCompletePage extends ConsumerWidget {
  const StripeCompletePage({super.key, required this.businessIdQuery});

  final String? businessIdQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bizAsync = ref.watch(currentBusinessProvider);
    return bizAsync.when(
      loading: () => const _Spinner(),
      error: (_, __) => const _Spinner(),
      data: (biz) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          final ownedId = biz?['id'] as String?;
          if (ownedId == null) {
            context.go(WebRoutes.home);
            return;
          }
          if (businessIdQuery != null && businessIdQuery != ownedId) {
            context.go(WebRoutes.home);
            return;
          }
          context.go(WebRoutes.negocioPayments);
        });
        return const _Spinner();
      },
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: kWebBackground,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
