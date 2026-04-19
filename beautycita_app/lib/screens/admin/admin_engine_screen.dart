import 'package:flutter/material.dart';
import 'package:beautycita/config/fonts.dart';
import 'service_profile_editor_screen.dart';
import 'engine_settings_editor_screen.dart';
import 'category_tree_screen.dart';
import 'time_rules_screen.dart';

/// Motor wrapper — four sub-tabs: Perfiles, Config, Categorias, Tiempo.
class AdminEngineScreen extends StatelessWidget {
  const AdminEngineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          TabBar(
            labelColor: colors.primary,
            unselectedLabelColor: colors.onSurface.withValues(alpha: 0.5),
            indicatorColor: colors.primary,
            isScrollable: true,
            labelStyle: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            tabs: const [
              Tab(text: 'Perfiles'),
              Tab(text: 'Config'),
              Tab(text: 'Categorias'),
              Tab(text: 'Tiempo'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                ServiceProfileEditorScreen(),
                EngineSettingsEditorScreen(),
                CategoryTreeScreen(),
                TimeRulesScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
