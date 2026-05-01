// Sistema section — Toggles · Auditoría.
// Sub-tabs only render for superadmin (the section itself is hidden for
// lower tiers via shell.dart's _visible() filter).

import 'package:flutter/material.dart';

import '../../../../widgets/admin/v2/tokens.dart';
import 'toggles.dart';
import 'auditoria.dart';

class SistemaSection extends StatelessWidget {
  const SistemaSection({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: AdminV2Tokens.subtle(context),
              indicatorColor: Theme.of(context).colorScheme.primary,
              tabs: const [
                Tab(text: 'Toggles'),
                Tab(text: 'Auditoría'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                SistemaToggles(),
                SistemaAuditoria(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
