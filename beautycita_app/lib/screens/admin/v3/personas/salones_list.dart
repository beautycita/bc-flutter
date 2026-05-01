// Personas → Salones list (v3).
//
// Filter chips drive an onboarding-state filter that surfaces the actual
// state of the salon ("Solo descubrimiento" / "Reservable" / "Lista para
// depósitos"), not internal tier numbers. Each row shows "Qué falta" chips
// when something's missing. Tap → consolidated detail screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes.dart';
import '../../../../providers/admin_provider.dart';
import '../../../../widgets/admin/v2/layout/card.dart';
import '../../../../widgets/admin/v2/layout/empty_state.dart';
import '../../../../widgets/admin/v2/tokens.dart';

enum SalonState {
  any,
  discoveryOnly,
  bookable,
  payoutReady,
}

extension on SalonState {
  String get label => switch (this) {
        SalonState.any => 'Todos',
        SalonState.discoveryOnly => 'Solo descubrimiento',
        SalonState.bookable => 'Reservable',
        SalonState.payoutReady => 'Lista para depósitos',
      };
}

class PersonasSalonesList extends ConsumerStatefulWidget {
  const PersonasSalonesList({super.key});

  @override
  ConsumerState<PersonasSalonesList> createState() => _State();
}

class _State extends ConsumerState<PersonasSalonesList> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  SalonState _state = SalonState.any;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _providerKey => '$_query|||';

  bool _matches(Map<String, dynamic> s) {
    if (_state == SalonState.any) return true;
    final completed = s['onboarding_complete'] == true;
    final stripeC = s['stripe_charges_enabled'] == true;
    final stripeP = s['stripe_payouts_enabled'] == true;
    final salonState = (stripeC && stripeP && completed)
        ? SalonState.payoutReady
        : completed
            ? SalonState.bookable
            : SalonState.discoveryOnly;
    return salonState == _state;
  }

  List<String> _missing(Map<String, dynamic> s) {
    final out = <String>[];
    if ((s['rfc'] as String?)?.isNotEmpty != true) out.add('RFC');
    if ((s['clabe'] as String?)?.isNotEmpty != true) out.add('CLABE');
    if (s['stripe_charges_enabled'] != true) out.add('Stripe');
    if (s['id_verification_status'] != 'verified') out.add('ID');
    if (s['has_services'] != true) out.add('Servicios');
    if (s['has_schedule'] != true) out.add('Horario');
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final asyncSalons = ref.watch(adminAllSalonsProvider(_providerKey));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AdminV2Tokens.spacingMD, AdminV2Tokens.spacingMD, AdminV2Tokens.spacingMD, AdminV2Tokens.spacingSM),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v.trim()),
                decoration: InputDecoration(
                  hintText: 'Buscar nombre / teléfono / ciudad',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AdminV2Tokens.radiusSM)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: AdminV2Tokens.spacingSM),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final s in SalonState.values) ...[
                      ChoiceChip(
                        label: Text(s.label),
                        selected: _state == s,
                        onSelected: (_) => setState(() => _state = s),
                      ),
                      const SizedBox(width: AdminV2Tokens.spacingSM),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: asyncSalons.when(
            loading: () => const AdminEmptyState(kind: AdminEmptyKind.loading),
            error: (e, _) => AdminEmptyState(
              kind: AdminEmptyKind.error,
              body: '$e',
              action: 'Reintentar',
              onAction: () => ref.invalidate(adminAllSalonsProvider(_providerKey)),
            ),
            data: (rows) {
              final filtered = rows.where(_matches).toList();
              if (filtered.isEmpty) {
                return const AdminEmptyState(kind: AdminEmptyKind.empty, title: 'Sin coincidencias');
              }
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(adminAllSalonsProvider(_providerKey)),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(AdminV2Tokens.spacingMD, 0, AdminV2Tokens.spacingMD, AdminV2Tokens.spacingMD),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final s = filtered[i];
                    return _Row(salon: s, missing: _missing(s));
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.salon, required this.missing});
  final Map<String, dynamic> salon;
  final List<String> missing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final id = salon['id'] as String?;
    final name = (salon['name'] as String?) ?? '(sin nombre)';
    final city = (salon['city'] as String?) ?? '';
    final phone = (salon['phone'] as String?) ?? '';
    final isVerified = salon['is_verified'] == true;
    final isActive = salon['is_active'] != false;

    return AdminCard(
      margin: const EdgeInsets.only(bottom: AdminV2Tokens.spacingSM),
      padding: const EdgeInsets.all(AdminV2Tokens.spacingMD),
      child: InkWell(
        onTap: id == null
            ? null
            : () => context.push(AppRoutes.adminV3PersonasSalonDetail.replaceFirst(':id', id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(name, style: AdminV2Tokens.subtitle(context), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if (isVerified) Icon(Icons.verified, size: 16, color: colors.primary),
                if (!isActive) ...[
                  const SizedBox(width: AdminV2Tokens.spacingXS),
                  Icon(Icons.pause_circle_outline, size: 16, color: AdminV2Tokens.destructive(context)),
                ],
              ],
            ),
            if (city.isNotEmpty || phone.isNotEmpty) ...[
              const SizedBox(height: AdminV2Tokens.spacingXS),
              Text([city, phone].where((s) => s.isNotEmpty).join(' · '), style: AdminV2Tokens.muted(context)),
            ],
            if (missing.isNotEmpty) ...[
              const SizedBox(height: AdminV2Tokens.spacingSM),
              Wrap(
                spacing: AdminV2Tokens.spacingXS,
                runSpacing: AdminV2Tokens.spacingXS,
                children: missing.map((m) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: AdminV2Tokens.spacingSM, vertical: 2),
                  decoration: BoxDecoration(
                    color: AdminV2Tokens.warning(context).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AdminV2Tokens.radiusFull),
                  ),
                  child: Text(m, style: AdminV2Tokens.muted(context).copyWith(fontSize: 11, color: AdminV2Tokens.warning(context), fontWeight: FontWeight.w600)),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
