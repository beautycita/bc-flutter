import 'package:flutter/material.dart';
import 'package:beautycita/config/fonts.dart';
import 'admin_finance_dashboard_screen.dart';
import 'admin_operations_dashboard_screen.dart';

/// Executive Dashboard wrapper — two sub-tabs: Finanzas, Operaciones.
/// (Analitica sub-tab dropped 2026-05-01 per redesign decision #18 — its
/// metrics were placeholder values; real charts arrive in Phase 3.)
class AdminExecutiveDashboardScreen extends StatelessWidget {
  const AdminExecutiveDashboardScreen({super.key});

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
              Tab(text: 'Finanzas'),
              Tab(text: 'Operaciones'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                AdminFinanceDashboardScreen(),
                AdminOperationsDashboardScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
