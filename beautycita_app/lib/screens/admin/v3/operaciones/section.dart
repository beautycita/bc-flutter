// Operaciones section host — Cola · Actividad · Salud.

import 'package:flutter/material.dart';

import '../../../../widgets/admin/v2/tokens.dart';
import 'cola.dart';
import 'actividad.dart';
import 'salud.dart';

class OperacionesSection extends StatelessWidget {
  const OperacionesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: AdminV2Tokens.subtle(context),
              indicatorColor: Theme.of(context).colorScheme.primary,
              tabs: const [
                Tab(text: 'Cola'),
                Tab(text: 'Actividad'),
                Tab(text: 'Salud'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                OperacionesCola(),
                OperacionesActividad(),
                OperacionesSalud(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
