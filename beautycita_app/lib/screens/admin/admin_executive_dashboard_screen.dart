import 'package:flutter/material.dart';
import 'package:beautycita/config/fonts.dart';
import 'admin_finance_dashboard_screen.dart';
import 'admin_operations_dashboard_screen.dart';
import 'analytics_screen.dart';

/// Executive Dashboard wrapper — three sub-tabs: Finanzas, Operaciones, Analitica.
class AdminExecutiveDashboardScreen extends StatelessWidget {
  const AdminExecutiveDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 3,
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
              Tab(text: 'Analitica'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                AdminFinanceDashboardScreen(),
                AdminOperationsDashboardScreen(),
                AnalyticsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
