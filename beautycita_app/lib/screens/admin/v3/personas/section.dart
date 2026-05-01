// Personas section host — tabs for Salones · Usuarios.
// Búsqueda global is the header search icon, not a sub-tab.

import 'package:flutter/material.dart';

import '../../../../widgets/admin/v2/tokens.dart';
import 'salones_list.dart';
import 'usuarios_list.dart';

class PersonasSection extends StatelessWidget {
  const PersonasSection({super.key});

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
                Tab(text: 'Salones'),
                Tab(text: 'Usuarios'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                PersonasSalonesList(),
                PersonasUsuariosList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
