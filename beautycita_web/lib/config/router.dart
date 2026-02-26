import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita_core/supabase.dart';

import '../pages/admin/analytics_page.dart';
import '../pages/admin/bookings_page.dart';
import '../pages/admin/config_page.dart';
import '../pages/admin/dashboard_page.dart';
import '../pages/admin/disputes_page.dart';
import '../pages/admin/finance_page.dart';
import '../pages/admin/services_page.dart';
import '../pages/admin/engine_categories_page.dart';
import '../pages/admin/engine_page.dart';
import '../pages/admin/engine_profiles_page.dart';
import '../pages/admin/engine_time_page.dart';
import '../pages/admin/outreach_page.dart';
import '../pages/admin/salons_page.dart';
import '../pages/admin/toggles_page.dart';
import '../pages/admin/users_page.dart';
import '../pages/auth/callback_page.dart';
import '../pages/auth/forgot_page.dart';
import '../pages/auth/login_page.dart';
import '../pages/auth/qr_page.dart';
import '../pages/auth/register_page.dart';
import '../pages/auth/verify_page.dart';
import '../pages/error/not_found_page.dart';
import '../shells/admin_shell.dart';
import '../shells/business_shell.dart';
import '../shells/client_shell.dart';

// ── Route paths ──────────────────────────────────────────────────────────────

abstract final class WebRoutes {
  // Auth
  static const String auth = '/auth';
  static const String register = '/auth/register';
  static const String verify = '/auth/verify';
  static const String callback = '/auth/callback';
  static const String forgot = '/auth/forgot';
  static const String qr = '/auth/qr';

  // Admin
  static const String admin = '/admin';
  static const String adminUsers = '/admin/users';
  static const String adminSalons = '/admin/salons';
  static const String adminBookings = '/admin/bookings';
  static const String adminServices = '/admin/services';
  static const String adminDisputes = '/admin/disputes';
  static const String adminFinance = '/admin/finance';
  static const String adminAnalytics = '/admin/analytics';
  static const String adminEngine = '/admin/engine';
  static const String adminEngineProfiles = '/admin/engine/profiles';
  static const String adminEngineCategories = '/admin/engine/categories';
  static const String adminEngineTime = '/admin/engine/time';
  static const String adminOutreach = '/admin/outreach';
  static const String adminConfig = '/admin/config';
  static const String adminToggles = '/admin/toggles';

  // Business
  static const String negocio = '/negocio';

  // Client
  static const String reservar = '/reservar';
  static const String misCitas = '/mis-citas';
}

// ── Placeholder page ─────────────────────────────────────────────────────────

class _Placeholder extends StatelessWidget {
  const _Placeholder(this.path);
  final String path;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.construction, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Proximamente',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            path,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

// ── Router provider ──────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: WebRoutes.auth,
    debugLogDiagnostics: true,

    // Redirect logic — wired to live Supabase auth state
    redirect: (context, state) {
      final isAuthenticated =
          BCSupabase.isInitialized && BCSupabase.isAuthenticated;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');

      if (!isAuthenticated && !isAuthRoute) {
        return WebRoutes.auth;
      }
      if (isAuthenticated && isAuthRoute) {
        return WebRoutes.admin;
      }
      return null;
    },

    // 404 handler
    errorBuilder: (context, state) => const NotFoundPage(),

    routes: [
      // ── Auth routes (no shell) ───────────────────────────────────────────
      GoRoute(
        path: WebRoutes.auth,
        builder: (context, state) => const LoginPage(),
        routes: [
          GoRoute(
            path: 'register',
            builder: (context, state) => const RegisterPage(),
          ),
          GoRoute(
            path: 'verify',
            builder: (context, state) => const VerifyPage(),
          ),
          GoRoute(
            path: 'callback',
            builder: (context, state) => const CallbackPage(),
          ),
          GoRoute(
            path: 'forgot',
            builder: (context, state) => const ForgotPage(),
          ),
          GoRoute(
            path: 'qr',
            builder: (context, state) => const QrPage(),
          ),
        ],
      ),

      // ── Admin routes (AdminShell) ────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: WebRoutes.admin,
            builder: (context, state) => const DashboardPage(),
            routes: [
              GoRoute(
                path: 'users',
                builder: (context, state) => const UsersPage(),
              ),
              GoRoute(
                path: 'salons',
                builder: (context, state) => const SalonsPage(),
              ),
              GoRoute(
                path: 'bookings',
                builder: (context, state) => const BookingsPage(),
              ),
              GoRoute(
                path: 'services',
                builder: (context, state) => const ServicesPage(),
              ),
              GoRoute(
                path: 'disputes',
                builder: (context, state) => const DisputesPage(),
              ),
              GoRoute(
                path: 'finance',
                builder: (context, state) => const FinancePage(),
              ),
              GoRoute(
                path: 'analytics',
                builder: (context, state) => const AnalyticsPage(),
              ),
              GoRoute(
                path: 'engine',
                builder: (context, state) => const EnginePage(),
                routes: [
                  GoRoute(
                    path: 'profiles',
                    builder: (context, state) =>
                        const EngineProfilesPage(),
                  ),
                  GoRoute(
                    path: 'categories',
                    builder: (context, state) =>
                        const EngineCategoriesPage(),
                  ),
                  GoRoute(
                    path: 'time',
                    builder: (context, state) =>
                        const EngineTimePage(),
                  ),
                ],
              ),
              GoRoute(
                path: 'outreach',
                builder: (context, state) => const OutreachPage(),
              ),
              GoRoute(
                path: 'config',
                builder: (context, state) => const ConfigPage(),
              ),
              GoRoute(
                path: 'toggles',
                builder: (context, state) => const TogglesPage(),
              ),
            ],
          ),
        ],
      ),

      // ── Business routes (BusinessShell) ──────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => BusinessShell(child: child),
        routes: [
          GoRoute(
            path: WebRoutes.negocio,
            builder: (context, state) =>
                const _Placeholder(WebRoutes.negocio),
          ),
        ],
      ),

      // ── Client routes (ClientShell) ──────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => ClientShell(child: child),
        routes: [
          GoRoute(
            path: WebRoutes.reservar,
            builder: (context, state) =>
                const _Placeholder(WebRoutes.reservar),
          ),
          GoRoute(
            path: WebRoutes.misCitas,
            builder: (context, state) =>
                const _Placeholder(WebRoutes.misCitas),
          ),
        ],
      ),
    ],
  );
});
