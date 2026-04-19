import 'package:flutter/material.dart';
import 'package:beautycita/config/fonts.dart';
import 'notification_templates_screen.dart';
import 'feature_toggles_screen.dart';

/// Sistema wrapper — two sub-tabs: Notificaciones, Toggles.
class AdminSystemScreen extends StatelessWidget {
  const AdminSystemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: colors.primary,
            unselectedLabelColor: colors.onSurface.withValues(alpha: 0.5),
            indicatorColor: colors.primary,
            labelStyle: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            tabs: const [
              Tab(text: 'Notificaciones'),
              Tab(text: 'Toggles'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                NotificationTemplatesScreen(),
                FeatureTogglesScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
