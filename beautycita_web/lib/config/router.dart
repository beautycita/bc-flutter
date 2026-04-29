import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita_core/supabase.dart';

import '../providers/auth_provider.dart';

import '../pages/admin/admin_chat_page.dart';
import '../pages/admin/admin_intelligence_page.dart';
import '../pages/admin/admin_intelligence_users_page.dart';
import '../pages/admin/admin_notification_templates_page.dart';
import '../pages/admin/admin_rp_tracking_page.dart';
import '../pages/admin/admin_tax_reports_page.dart';
import '../pages/admin/analytics_page.dart';
import '../pages/admin/bookings_page.dart';
import '../pages/admin/orders_page.dart';
import '../pages/admin/config_page.dart';
import '../pages/admin/dashboard_page.dart';
import '../pages/admin/disputes_page.dart';
import '../pages/admin/finance_dashboard_page.dart';
import '../pages/admin/finance_page.dart';
import '../pages/admin/operations_dashboard_page.dart';
import '../pages/admin/services_page.dart';
import '../pages/admin/engine_categories_page.dart';
import '../pages/admin/engine_page.dart';
import '../pages/admin/engine_profiles_page.dart';
import '../pages/admin/engine_time_page.dart';
import '../pages/admin/outreach_page.dart';
import '../pages/admin/applications_page.dart';
import '../pages/admin/salons_page.dart';
import '../pages/admin/toggles_page.dart';
import '../pages/admin/users_page.dart';
import '../pages/business/biz_analytics_page.dart';
import '../pages/business/biz_banking_page.dart';
import '../pages/business/biz_portfolio_page.dart';
import '../pages/business/biz_calendar_page.dart';
import '../pages/business/biz_calendar_sync_page.dart';
import '../pages/business/biz_clients_page.dart';
import '../pages/business/biz_dashboard_page.dart';
import '../pages/business/biz_disputes_page.dart';
import '../pages/business/biz_gift_cards_page.dart';
import '../pages/business/biz_marketing_page.dart';
import '../pages/business/biz_orders_page.dart';
import '../pages/business/biz_payments_page.dart';
import '../pages/business/biz_services_page.dart';
import '../pages/business/biz_qr_program_page.dart';
import '../pages/business/biz_reviews_page.dart';
import '../pages/business/biz_pos_page.dart';
import '../pages/business/biz_settings_page.dart';
import '../pages/business/biz_staff_page.dart';
import '../pages/client/cuenta_page.dart';
import '../pages/client/feed_page.dart';
import '../pages/client/tiktok_feed_page.dart';
import '../pages/client/invite_page.dart';
import '../pages/client/mis_citas_page.dart';
import '../pages/client/reservar_page.dart';
import '../pages/public/invite_public_page.dart';
import '../pages/public/porque_page.dart';
import '../pages/public/privacidad_page.dart';
import '../pages/public/directory_national_page.dart';
import '../pages/public/directory_state_page.dart';
import '../pages/public/directory_city_page.dart';
import '../pages/public/salon_page.dart';
import '../pages/public/qr_registro_page.dart';
import '../pages/public/expresscita_landing_page.dart';
import '../pages/public/terminos_page.dart';
import '../pages/auth/callback_page.dart';
import '../pages/auth/google_calendar_callback_page.dart';
import '../pages/auth/forgot_page.dart';
import '../pages/auth/login_page.dart';
import '../pages/auth/qr_page.dart';
import '../pages/auth/register_page.dart';
import '../pages/auth/verify_page.dart';
import '../pages/error/not_found_page.dart';
import '../pages/landing_page.dart';
import '../pages/registrar_page.dart';
import '../pages/registro_page.dart';
import '../pages/support/soporte_page.dart';
import '../shells/admin_shell.dart';
import '../shells/business_shell.dart';
import '../shells/client_shell.dart';
import '../shells/demo_shell.dart';

// ── Route paths ──────────────────────────────────────────────────────────────

abstract final class WebRoutes {
  // Public
  static const String home = '/';
  static const String porqueBc = '/porque-beautycita';

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
  static const String adminApplications = '/admin/applications';
  static const String adminBookings = '/admin/bookings';
  static const String adminOrders = '/admin/orders';
  static const String adminServices = '/admin/services';
  static const String adminDisputes = '/admin/disputes';
  static const String adminFinance = '/admin/finance';
  static const String adminAnalytics = '/admin/analytics';
  static const String adminEngine = '/admin/engine';
  static const String adminEngineProfiles = '/admin/engine/profiles';
  static const String adminEngineCategories = '/admin/engine/categories';
  static const String adminEngineTime = '/admin/engine/time';
  static const String adminOutreach = '/admin/outreach';
  static const String adminFinanceDashboard = '/admin/finance-dashboard';
  static const String adminOperations = '/admin/operations';
  static const String adminConfig = '/admin/config';
  static const String adminToggles = '/admin/toggles';
  static const String adminTaxReports = '/admin/tax-reports';
  static const String adminRpTracking = '/admin/rp-tracking';
  static const String adminNotificationTemplates = '/admin/notification-templates';
  static const String adminChat = '/admin/chat';
  static const String adminIntelligence = '/admin/intelligence';
  static const String adminIntelligenceUsers = '/admin/intelligence/users';

  // Business
  static const String negocio = '/negocio';
  static const String negocioCalendar = '/negocio/calendar';
  static const String negocioServices = '/negocio/services';
  static const String negocioStaff = '/negocio/staff';
  static const String negocioPayments = '/negocio/payments';
  static const String negocioSettings = '/negocio/settings';
  static const String negocioDisputes = '/negocio/disputes';
  static const String negocioQr = '/negocio/qr';
  static const String negocioReviews = '/negocio/reviews';
  static const String negocioCalendarSync = '/negocio/calendar-sync';
  static const String negocioPos = '/negocio/pos';
  static const String negocioClients = '/negocio/clients';
  static const String negocioMarketing = '/negocio/marketing';
  static const String negocioGiftCards = '/negocio/gift-cards';
  static const String negocioAnalytics = '/negocio/analytics';
  static const String negocioOrders = '/negocio/orders';
  static const String negocioBanking = '/negocio/banking';
  static const String negocioPortfolio = '/negocio/portfolio';

  // Client
  static const String explorar = '/explorar';
  static const String reservar = '/reservar';
  static const String invitar = '/client/invitar';
  static const String misCitas = '/mis-citas';
  static const String cuenta = '/cuenta';

  // Public invite
  static const String invitarPublic = '/invitar';

  // Demo (read-only business portal preview)
  static const String demo = '/demo';
  static const String demoCalendar = '/demo/calendar';
  static const String demoServices = '/demo/services';
  static const String demoStaff = '/demo/staff';
  static const String demoPayments = '/demo/payments';
  static const String demoSettings = '/demo/settings';
  static const String demoDisputes = '/demo/disputes';
  static const String demoQr = '/demo/qr';
  static const String demoReviews = '/demo/reviews';
  static const String demoCalendarSync = '/demo/calendar-sync';
  static const String demoPos = '/demo/pos';

  // Public
  static const String soporte = '/soporte';
  static const String registrar = '/registrar';
  static const String terminos = '/terminos';
  static const String privacidad = '/privacidad';
}

/// Map user role → correct portal route.
String routeForRole(String? role) {
  switch (role) {
    case 'admin':
    case 'superadmin':
      return WebRoutes.admin;
    case 'stylist':
    case 'business':
      return WebRoutes.negocio;
    default:
      return WebRoutes.reservar;
  }
}

// ── Router provider ──────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: WebRoutes.home,
    debugLogDiagnostics: kDebugMode,

    // Redirect logic — wired to live Supabase auth state.
    // Role-based: admin→/admin, stylist→/negocio, customer→/reservar.
    redirect: (context, state) async {
      final path = state.matchedLocation;

      final isPublicRoute = path == '/' ||
          path.startsWith('/auth') ||
          path == '/soporte' ||
          path == '/terminos' ||
          path == '/privacidad' ||
          path == WebRoutes.porqueBc ||
          path.startsWith('/demo') ||
          path.startsWith('/explorar') ||
          path.startsWith('/reservar') ||
          path.startsWith('/registro') ||
          path.startsWith('/expresscita') ||
          path == '/registrar' ||
          path == '/invitar' ||
          path.startsWith('/salon');

      // If Supabase never initialized (offline, failed, etc.),
      // only allow public routes — redirect protected routes to /auth
      // where the login page will show an appropriate error.
      if (!BCSupabase.isInitialized) {
        if (!isPublicRoute) return WebRoutes.auth;
        return null;
      }

      final isAuthenticated = BCSupabase.isAuthenticated;

      if (!isAuthenticated && !isPublicRoute) {
        return WebRoutes.auth;
      }

      // Redirect unverified email users to verify page (skip for public routes + verify page itself)
      if (isAuthenticated && !isPublicRoute && !path.startsWith('/auth/verify')) {
        final user = BCSupabase.client.auth.currentUser;
        if (user != null && user.emailConfirmedAt == null && user.email != null) {
          return WebRoutes.verify;
        }
      }

      // Authenticated user on auth page → send to correct portal by role
      // (but allow `/` and `/soporte` — those are viewable when logged in)
      if (isAuthenticated && path.startsWith('/auth')) {
        // Let unverified-email users stay on the verify page
        if (path == '/auth/verify') {
          final user = BCSupabase.client.auth.currentUser;
          if (user != null && user.emailConfirmedAt == null && user.email != null) {
            return null; // stay on verify page
          }
        }
        final role = await ref.read(authProvider.notifier).getUserRole();
        return routeForRole(role);
      }

      // Block non-admin from admin routes — always re-verify role from DB
      if (isAuthenticated && path.startsWith('/admin')) {
        final role = await ref.read(authProvider.notifier).getUserRole(forceRefresh: true);
        if (role != 'admin' && role != 'superadmin') {
          return routeForRole(role);
        }
      }

      // Block non-business from business routes — always re-verify role from DB
      if (isAuthenticated && path.startsWith('/negocio')) {
        final role = await ref.read(authProvider.notifier).getUserRole(forceRefresh: true);
        if (role != 'stylist' && role != 'business' &&
            role != 'admin' && role != 'superadmin') {
          return routeForRole(role);
        }
      }

      return null;
    },

    // 404 handler
    errorBuilder: (context, state) => const NotFoundPage(),

    routes: [
      // ── Landing page (public, no shell) ────────────────────────────────
      GoRoute(
        path: WebRoutes.home,
        builder: (context, state) => const LandingPage(),
      ),

      // ── Why BeautyCita (public, no shell) ──────────────────────────────
      GoRoute(
        path: WebRoutes.porqueBc,
        builder: (context, state) => const PorQuePage(),
      ),

      // ── Support page (public, no shell) ────────────────────────────────
      GoRoute(
        path: WebRoutes.soporte,
        builder: (context, state) => const SoportePage(),
      ),

      // ── Terms of service (public, no shell) ───────────────────────────
      GoRoute(
        path: WebRoutes.terminos,
        builder: (context, state) => const TerminosPage(),
      ),

      // ── Privacy policy (public, no shell) ─────────────────────────────
      GoRoute(
        path: WebRoutes.privacidad,
        builder: (context, state) => const PrivacidadPage(),
      ),

      // ── Salon self-registration search (public, no shell) ──────────────
      GoRoute(
        path: WebRoutes.registrar,
        builder: (context, state) => const RegistrarPage(),
      ),

      // ── Salon registration with pre-fill (public, no shell) ───────────
      GoRoute(
        path: '/registro/:salonId',
        builder: (context, state) => RegistroPage(
          salonId: state.pathParameters['salonId'] ?? '',
        ),
      ),

      // ── Public invite page (no shell, no auth) ────────────────────────
      GoRoute(
        path: WebRoutes.invitarPublic,
        builder: (context, state) => const InvitePublicPage(),
      ),

      // ── Salon directory (public, no shell) ────────────────────────────
      GoRoute(
        path: '/salones',
        builder: (context, state) => const DirectoryNationalPage(),
        routes: [
          GoRoute(
            path: ':stateSlug',
            builder: (context, state) => DirectoryStatePage(
              stateSlug: state.pathParameters['stateSlug'] ?? '',
            ),
            routes: [
              GoRoute(
                path: ':citySlug',
                builder: (context, state) => DirectoryCityPage(
                  stateSlug: state.pathParameters['stateSlug'] ?? '',
                  citySlug: state.pathParameters['citySlug'] ?? '',
                ),
              ),
            ],
          ),
        ],
      ),

      // ── Public salon page (no shell, no auth) ─────────────────────────
      GoRoute(
        path: '/salon/:slug',
        builder: (context, state) => SalonPage(
          slug: state.pathParameters['slug'] ?? '',
        ),
      ),

      // ── QR free-tier registration (public, no shell, no auth) ─────────
      GoRoute(
        path: '/registro/:slug',
        builder: (context, state) => QrRegistroPage(
          slug: state.pathParameters['slug'] ?? '',
        ),
      ),

      // ── ExpressCita landing (public, app-gate + platform-aware redirect)
      GoRoute(
        path: '/expresscita/:slug',
        builder: (context, state) => ExpressCitaLandingPage(
          slug: state.pathParameters['slug'] ?? '',
        ),
      ),

      // ── Stripe Connect return URLs ───────────────────────────────────────
      // Stripe redirects here after the hosted onboarding flow finishes
      // (complete) or is abandoned (refresh). Just bounce back to the
      // payments tab; the dashboard's currentBusinessProvider re-fetches
      // and the new charges/payouts flags surface naturally.
      GoRoute(
        path: '/stripe/complete',
        redirect: (_, __) => WebRoutes.negocioPayments,
      ),
      GoRoute(
        path: '/stripe/refresh',
        redirect: (_, __) => WebRoutes.negocioPayments,
      ),

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
            path: 'google-calendar-callback',
            builder: (context, state) =>
                const GoogleCalendarCallbackPage(),
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
                path: 'applications',
                builder: (context, state) => const ApplicationsPage(),
              ),
              GoRoute(
                path: 'bookings',
                builder: (context, state) => const BookingsPage(),
              ),
              GoRoute(
                path: 'orders',
                builder: (context, state) => const OrdersPage(),
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
                path: 'finance-dashboard',
                builder: (context, state) =>
                    const FinanceDashboardPage(),
              ),
              GoRoute(
                path: 'operations',
                builder: (context, state) =>
                    const OperationsDashboardPage(),
              ),
              GoRoute(
                path: 'config',
                builder: (context, state) => const ConfigPage(),
              ),
              GoRoute(
                path: 'toggles',
                builder: (context, state) => const TogglesPage(),
              ),
              GoRoute(
                path: 'tax-reports',
                builder: (context, state) => const AdminTaxReportsPage(),
              ),
              GoRoute(
                path: 'rp-tracking',
                builder: (context, state) => const AdminRpTrackingPage(),
              ),
              GoRoute(
                path: 'notification-templates',
                builder: (context, state) =>
                    const AdminNotificationTemplatesPage(),
              ),
              GoRoute(
                path: 'chat',
                builder: (context, state) => const AdminChatPage(),
              ),
              GoRoute(
                path: 'intelligence',
                builder: (context, state) =>
                    const AdminIntelligencePage(),
                routes: [
                  GoRoute(
                    path: 'users',
                    builder: (context, state) =>
                        const AdminIntelligenceUsersPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // ── Demo routes (DemoShell — read-only, no auth) ────────────────────
      ShellRoute(
        builder: (context, state, child) => DemoShell(child: child),
        routes: [
          GoRoute(
            path: WebRoutes.demo,
            builder: (context, state) => const BizDashboardPage(),
            routes: [
              GoRoute(
                path: 'calendar',
                builder: (context, state) => const BizCalendarPage(),
              ),
              GoRoute(
                path: 'services',
                builder: (context, state) => const BizServicesPage(),
              ),
              GoRoute(
                path: 'staff',
                builder: (context, state) => const BizStaffPage(),
              ),
              GoRoute(
                path: 'payments',
                builder: (context, state) => const BizPaymentsPage(),
              ),
              GoRoute(
                path: 'settings',
                builder: (context, state) => const BizSettingsPage(),
              ),
              GoRoute(
                path: 'disputes',
                builder: (context, state) => const BizDisputesPage(),
              ),
              GoRoute(
                path: 'qr',
                builder: (context, state) => const BizQrProgramPage(),
              ),
              GoRoute(
                path: 'reviews',
                builder: (context, state) => const BizReviewsPage(),
              ),
              GoRoute(
                path: 'calendar-sync',
                builder: (context, state) => const BizCalendarSyncPage(),
              ),
              GoRoute(
                path: 'pos',
                builder: (context, state) => const BizPosPage(),
              ),
              GoRoute(
                path: 'clients',
                builder: (context, state) => const BizClientsPage(),
              ),
              GoRoute(
                path: 'marketing',
                builder: (context, state) => const BizMarketingPage(),
              ),
              GoRoute(
                path: 'gift-cards',
                builder: (context, state) => const BizGiftCardsPage(),
              ),
              GoRoute(
                path: 'analytics',
                builder: (context, state) => const BizAnalyticsPage(),
              ),
              GoRoute(
                path: 'orders',
                builder: (context, state) => const BizOrdersPage(),
              ),
              GoRoute(
                path: 'banking',
                builder: (context, state) => const BizBankingPage(),
              ),
              GoRoute(
                path: 'portfolio',
                builder: (context, state) => const BizPortfolioPage(),
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
            builder: (context, state) => const BizDashboardPage(),
            routes: [
              GoRoute(
                path: 'calendar',
                builder: (context, state) => const BizCalendarPage(),
              ),
              GoRoute(
                path: 'services',
                builder: (context, state) => const BizServicesPage(),
              ),
              GoRoute(
                path: 'staff',
                builder: (context, state) => const BizStaffPage(),
              ),
              GoRoute(
                path: 'payments',
                builder: (context, state) => const BizPaymentsPage(),
              ),
              GoRoute(
                path: 'settings',
                builder: (context, state) => const BizSettingsPage(),
              ),
              GoRoute(
                path: 'disputes',
                builder: (context, state) => const BizDisputesPage(),
              ),
              GoRoute(
                path: 'qr',
                builder: (context, state) => const BizQrProgramPage(),
              ),
              GoRoute(
                path: 'reviews',
                builder: (context, state) => const BizReviewsPage(),
              ),
              GoRoute(
                path: 'calendar-sync',
                builder: (context, state) => const BizCalendarSyncPage(),
              ),
              GoRoute(
                path: 'pos',
                builder: (context, state) => const BizPosPage(),
              ),
              GoRoute(
                path: 'clients',
                builder: (context, state) => const BizClientsPage(),
              ),
              GoRoute(
                path: 'marketing',
                builder: (context, state) => const BizMarketingPage(),
              ),
              GoRoute(
                path: 'gift-cards',
                builder: (context, state) => const BizGiftCardsPage(),
              ),
              GoRoute(
                path: 'analytics',
                builder: (context, state) => const BizAnalyticsPage(),
              ),
              GoRoute(
                path: 'orders',
                builder: (context, state) => const BizOrdersPage(),
              ),
              GoRoute(
                path: 'banking',
                builder: (context, state) => const BizBankingPage(),
              ),
              GoRoute(
                path: 'portfolio',
                builder: (context, state) => const BizPortfolioPage(),
              ),
            ],
          ),
        ],
      ),

      // ── Client routes (ClientShell) ──────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => ClientShell(child: child),
        routes: [
          GoRoute(
            path: WebRoutes.explorar,
            builder: (context, state) => const TikTokFeedPage(),
          ),
          GoRoute(
            path: '/explorar/legacy',
            builder: (context, state) => const FeedPage(),
          ),
          GoRoute(
            path: WebRoutes.reservar,
            builder: (context, state) => const ReservarPage(),
          ),
          GoRoute(
            path: WebRoutes.invitar,
            builder: (context, state) =>
                InvitePage(serviceType: state.extra as String?),
          ),
          GoRoute(
            path: WebRoutes.misCitas,
            builder: (context, state) => const MisCitasPage(),
          ),
          GoRoute(
            path: WebRoutes.cuenta,
            builder: (context, state) => const CuentaPage(),
          ),
        ],
      ),
    ],
  );
});
