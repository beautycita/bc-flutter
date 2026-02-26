import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../pages/admin/dashboard_page.dart';
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
  static const String auth = '/app/auth';
  static const String register = '/app/auth/register';
  static const String verify = '/app/auth/verify';
  static const String callback = '/app/auth/callback';
  static const String forgot = '/app/auth/forgot';
  static const String qr = '/app/auth/qr';

  // Admin
  static const String admin = '/app/admin';
  static const String adminUsers = '/app/admin/users';
  static const String adminSalons = '/app/admin/salons';
  static const String adminBookings = '/app/admin/bookings';
  static const String adminServices = '/app/admin/services';
  static const String adminDisputes = '/app/admin/disputes';
  static const String adminFinance = '/app/admin/finance';
  static const String adminAnalytics = '/app/admin/analytics';
  static const String adminEngine = '/app/admin/engine';
  static const String adminEngineProfiles = '/app/admin/engine/profiles';
  static const String adminEngineCategories = '/app/admin/engine/categories';
  static const String adminEngineTime = '/app/admin/engine/time';
  static const String adminOutreach = '/app/admin/outreach';
  static const String adminConfig = '/app/admin/config';
  static const String adminToggles = '/app/admin/toggles';

  // Business
  static const String negocio = '/app/negocio';

  // Client
  static const String reservar = '/app/reservar';
  static const String misCitas = '/app/mis-citas';
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

    // Redirect logic
    redirect: (context, state) {
      // TODO: Wire to actual auth state from Supabase.
      // ignore: dead_code
      const isAuthenticated = false;
      final isAuthRoute = state.matchedLocation.startsWith('/app/auth');

      if (!isAuthenticated && !isAuthRoute) {
        return WebRoutes.auth;
      }
      // ignore: dead_code
      if (isAuthenticated && isAuthRoute) {
        // Phase 1 default; role-based redirect later
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
                builder: (context, state) =>
                    const _Placeholder(WebRoutes.adminUsers),
              ),
              GoRoute(
                path: 'salons',
                builder: (context, state) =>
                    const _Placeholder(WebRoutes.adminSalons),
              ),
              GoRoute(
                path: 'bookings',
                builder: (context, state) =>
                    const _Placeholder(WebRoutes.adminBookings),
              ),
              GoRoute(
                path: 'services',
                builder: (context, state) =>
                    const _Placeholder(WebRoutes.adminServices),
              ),
              GoRoute(
                path: 'disputes',
                builder: (context, state) =>
                    const _Placeholder(WebRoutes.adminDisputes),
              ),
              GoRoute(
                path: 'finance',
                builder: (context, state) =>
                    const _Placeholder(WebRoutes.adminFinance),
              ),
              GoRoute(
                path: 'analytics',
                builder: (context, state) =>
                    const _Placeholder(WebRoutes.adminAnalytics),
              ),
              GoRoute(
                path: 'engine',
                builder: (context, state) =>
                    const _Placeholder(WebRoutes.adminEngine),
                routes: [
                  GoRoute(
                    path: 'profiles',
                    builder: (context, state) =>
                        const _Placeholder(WebRoutes.adminEngineProfiles),
                  ),
                  GoRoute(
                    path: 'categories',
                    builder: (context, state) =>
                        const _Placeholder(WebRoutes.adminEngineCategories),
                  ),
                  GoRoute(
                    path: 'time',
                    builder: (context, state) =>
                        const _Placeholder(WebRoutes.adminEngineTime),
                  ),
                ],
              ),
              GoRoute(
                path: 'outreach',
                builder: (context, state) =>
                    const _Placeholder(WebRoutes.adminOutreach),
              ),
              GoRoute(
                path: 'config',
                builder: (context, state) =>
                    const _Placeholder(WebRoutes.adminConfig),
              ),
              GoRoute(
                path: 'toggles',
                builder: (context, state) =>
                    const _Placeholder(WebRoutes.adminToggles),
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
