// Sistema → Toggles
//
// Reads + flips boolean app_config rows. Server-side RLS gates writes to
// superadmin (existing app_config policy). Audit trigger on app_config
// fires automatically on update.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/feature_toggle_provider.dart';
import '../../../../services/supabase_client.dart';
import '../../../../services/toast_service.dart';
import '../../../../widgets/admin/v2/feedback/audit_indicator.dart';
import '../../../../widgets/admin/v2/layout/card.dart';
import '../../../../widgets/admin/v2/layout/empty_state.dart';
import '../../../../widgets/admin/v2/tokens.dart';

class SistemaToggles extends ConsumerStatefulWidget {
  const SistemaToggles({super.key});

  @override
  ConsumerState<SistemaToggles> createState() => _State();
}

class _State extends ConsumerState<SistemaToggles> {
  String _busyKey = '';

  Future<void> _flip(String key, bool current) async {
    setState(() => _busyKey = key);
    try {
      // Use jsonb literal — app_config.value is jsonb.
      await SupabaseClientService.client
          .from('app_config')
          .update({'value': !current})
          .eq('key', key);
      ref.invalidate(featureTogglesProvider);
      if (!mounted) return;
      AdminAuditIndicator.show(context, label: 'Toggle actualizado');
    } catch (e, st) {
      if (!mounted) return;
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, st);
    } finally {
      if (mounted) setState(() => _busyKey = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final togglesAsync = ref.watch(featureTogglesProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(featureTogglesProvider),
      child: togglesAsync.when(
        loading: () => const AdminEmptyState(kind: AdminEmptyKind.loading),
        error: (e, _) => Center(child: AdminEmptyState(kind: AdminEmptyKind.error, body: '$e')),
        data: (map) {
          if (map.isEmpty) {
            return const Center(child: AdminEmptyState(kind: AdminEmptyKind.empty, title: 'Sin toggles'));
          }
          final keys = map.keys.toList()..sort();
          return ListView.builder(
            padding: const EdgeInsets.all(AdminV2Tokens.spacingMD),
            itemCount: keys.length,
            itemBuilder: (ctx, i) {
              final k = keys[i];
              final v = map[k] ?? false;
              return AdminCard(
                margin: const EdgeInsets.only(bottom: AdminV2Tokens.spacingSM),
                padding: const EdgeInsets.all(AdminV2Tokens.spacingMD),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(k, style: AdminV2Tokens.body(context).copyWith(fontFamily: 'monospace', fontWeight: FontWeight.w600)),
                    ),
                    if (_busyKey == k)
                      const Padding(
                        padding: EdgeInsets.only(right: AdminV2Tokens.spacingSM),
                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                    Switch(
                      value: v,
                      onChanged: _busyKey.isNotEmpty ? null : (_) => _flip(k, v),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
