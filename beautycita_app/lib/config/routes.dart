import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita/services/supabase_client.dart';
import 'package:beautycita/services/toast_service.dart';
import 'package:beautycita/screens/splash_screen.dart';
import 'package:beautycita/screens/auth_screen.dart';
import 'package:beautycita/screens/home_screen.dart';
import 'package:beautycita/screens/provider_list_screen.dart';
import 'package:beautycita/screens/provider_detail_screen.dart';
import 'package:beautycita/screens/booking_screen.dart';
import 'package:beautycita/screens/my_bookings_screen.dart';
import 'package:beautycita/screens/booking_flow_screen.dart';
import 'package:beautycita/screens/admin/admin_shell_screen.dart';
import 'package:beautycita/screens/invite_salon_screen.dart';
import 'package:beautycita/screens/invite/invite_experience_screen.dart';
import 'package:beautycita/screens/invite/invite_salon_detail_screen.dart';
import 'package:beautycita/screens/salon_onboarding_screen.dart';
import 'package:beautycita/screens/settings_screen.dart';
import 'package:beautycita/screens/chat_list_screen.dart';
import 'package:beautycita/screens/chat_conversation_screen.dart';
import 'package:beautycita/screens/chat_router_screen.dart';
import 'package:beautycita/screens/booking_detail_screen.dart';
import 'package:beautycita/screens/qr_scan_screen.dart';
import 'package:beautycita/screens/device_manager_screen.dart';
import 'package:beautycita/screens/discovered_salon_detail_screen.dart';
import 'package:beautycita/screens/virtual_studio_screen.dart';
import 'package:beautycita/screens/preferences_screen.dart';
import 'package:beautycita/screens/profile_screen.dart';
import 'package:beautycita/screens/security_screen.dart';
import 'package:beautycita/screens/payment_methods_screen.dart';
import 'package:beautycita/screens/cash_payment_screen.dart';
import 'package:beautycita/screens/cita_express_screen.dart';
import 'package:beautycita/screens/legal_screens.dart';
import 'package:beautycita/screens/business/business_shell_screen.dart';
import 'package:beautycita/screens/discovered_salon_confirm_screen.dart';
import 'package:beautycita/screens/post_registration_screen.dart';
import 'package:beautycita/screens/feed/feed_screen.dart';
import 'package:beautycita/screens/feed/saved_screen.dart';
import 'package:beautycita/screens/rp/rp_shell_screen.dart';
import 'package:beautycita/screens/rp/rp_centro_screen.dart';
import 'package:beautycita/screens/rp/rp_chat_screen.dart';
import 'package:beautycita/screens/about_screen.dart';
import 'package:beautycita/screens/help_screen.dart';
import 'package:beautycita/screens/press_screen.dart';
import 'package:beautycita/screens/system_status_screen.dart';
import 'package:beautycita/screens/report_problem_screen.dart';
import 'package:beautycita/screens/business/portfolio_capture_screen.dart';
import 'package:beautycita/screens/booking_confirmation_screen.dart';
import 'package:beautycita/screens/favorites_screen.dart';
import 'app_transitions.dart';


class AppRoutes {
  static const String splash = '/';
  static const String auth = '/auth';
  static const String home = '/home';
  static const String providers = '/providers';
  static const String providerDetail = '/provider/:id';
  static const String booking = '/booking/:providerId/:serviceId';
  static const String bookingNoService = '/booking/:providerId';
  static const String myBookings = '/my-bookings';
  static const String book = '/book';
  static const String admin = '/admin';
  static const String business = '/business';
  static const String inviteSalon = '/invite';
  static const String settings = '/settings';
  static const String salonOnboarding = '/registro';
  static const String chat = '/chat';
  static const String chatList = '/chat/list';
  static const String appointmentDetail = '/appointment/:id';
  static const String chatConversation = '/chat/:threadId';
  static const String qrScan = '/qr-scan';
  static const String devices = '/devices';
  static const String discoveredSalon = '/discovered-salon';
  static const String studio = '/studio';
  static const String preferences = '/settings/preferences';
  static const String profile = '/settings/profile';
  static const String security = '/settings/security';
  static const String paymentMethods = '/settings/payment-methods';
  static const String cashPayment = '/settings/cash-payment';
  static const String citaExpress = '/cita-express/:businessId';
  static const String discoveredSalonConfirm = '/discovered-salon-confirm';
  static const String postRegistration = '/post-registration';
  static const String legal = '/legal';
  static const String terms = '/legal'; // back-compat
  static const String privacy = '/legal'; // back-compat
  static const String cookies = '/legal'; // back-compat
  static const String feed = '/feed';
  static const String feedSaved = '/feed/saved';
  static const String rp = '/rp';
  static const String rpCentro = '/rp/centro';
  static const String rpChat = '/rp/chat';
  static const String about = '/about';
  static const String contact = '/contact';
  static const String help = '/help';
  static const String press = '/press';
  static const String systemStatus = '/system-status';
  static const String reportProblem = '/report-problem';
  static const String portfolioCapture = '/business/portfolio-capture';
  static const String favorites = '/favorites';
  static const String bookingConfirmed = '/booking-confirmed/:bookingId';


  static final GoRouter router = GoRouter(
    navigatorKey: ToastService.navigatorKey,
    initialLocation: splash,
    debugLogDiagnostics: false,
    routes: [
      // ── Splash: keep fade ──
      GoRoute(
        path: splash,
        name: 'splash',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SplashScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      // ── Auth: keep as-is ──
      GoRoute(
        path: auth,
        name: 'auth',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const AuthScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final tween = Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeInOutCubic));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        ),
      ),
      // ── Main navigation: BC sweep transition ──
      GoRoute(
        path: home,
        name: 'home',
        pageBuilder: (context, state) => bcSweepPage(
          key: state.pageKey,
          child: const HomeScreen(),
        ),
      ),
      GoRoute(
        path: providers,
        name: 'providers',
        pageBuilder: (context, state) {
          final category = state.uri.queryParameters['category'] ?? '';
          final subcategory = state.uri.queryParameters['subcategory'];
          final colorValue = state.uri.queryParameters['color'];
          final color = colorValue != null
              ? Color(int.parse(colorValue))
              : const Color(0xFF660033);
          return bcSweepPage(
            key: state.pageKey,
            child: ProviderListScreen(
              category: category,
              subcategory: subcategory,
              categoryColor: color,
            ),
          );
        },
      ),
      GoRoute(
        path: '/provider/:id',
        name: 'provider-detail',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return bcSweepPage(
            key: state.pageKey,
            child: ProviderDetailScreen(providerId: id),
          );
        },
      ),
      GoRoute(
        path: '/booking/:providerId/:serviceId',
        name: 'booking',
        pageBuilder: (context, state) {
          final providerId = state.pathParameters['providerId']!;
          final serviceId = state.pathParameters['serviceId'];
          return bcSweepPage(
            key: state.pageKey,
            child: BookingScreen(
              providerId: providerId,
              serviceId: serviceId,
            ),
          );
        },
      ),
      GoRoute(
        path: '/booking/:providerId',
        name: 'booking-no-service',
        pageBuilder: (context, state) {
          final providerId = state.pathParameters['providerId']!;
          return bcSweepPage(
            key: state.pageKey,
            child: BookingScreen(providerId: providerId),
          );
        },
      ),
      GoRoute(
        path: '/book',
        name: 'book',
        pageBuilder: (context, state) => bcSweepPage(
          key: state.pageKey,
          child: const BookingFlowScreen(),
        ),
      ),
      GoRoute(
        path: '/my-bookings',
        name: 'my-bookings',
        pageBuilder: (context, state) {
          return bcSweepPage(
            key: state.pageKey,
            child: const MyBookingsScreen(),
          );
        },
      ),
      GoRoute(
        path: '/appointment/:id',
        name: 'appointment-detail',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return bcSweepPage(
            key: state.pageKey,
            child: BookingDetailScreen(bookingId: id),
          );
        },
      ),
      GoRoute(
        path: admin,
        name: 'admin',
        pageBuilder: (context, state) => bcSweepPage(
          key: state.pageKey,
          child: const AdminShellScreen(),
        ),
      ),
      GoRoute(
        path: rp,
        name: 'rp',
        pageBuilder: (context, state) => bcSweepPage(
          key: state.pageKey,
          child: const RPShellScreen(),
        ),
      ),
      GoRoute(
        path: rpCentro,
        name: 'rp-centro',
        pageBuilder: (context, state) {
          final salon = state.extra as Map<String, dynamic>;
          return bcSweepPage(
            key: state.pageKey,
            child: RPCentroScreen(salon: salon),
          );
        },
      ),
      GoRoute(
        path: rpChat,
        name: 'rp-chat',
        pageBuilder: (context, state) {
          final args = state.extra as Map<String, dynamic>;
          return bcSweepPage(
            key: state.pageKey,
            child: RPChatScreen(
              salon: args['salon'] as Map<String, dynamic>,
              channel: args['channel'] as String,
            ),
          );
        },
      ),
      GoRoute(
        path: business,
        name: 'business',
        redirect: (context, state) async {
          final userId = SupabaseClientService.currentUserId;
          if (userId == null) return home;
          final biz = await SupabaseClientService.client
              .from('businesses')
              .select('id')
              .eq('owner_id', userId)
              .maybeSingle();
          if (biz == null) return home;
          return null; // allow access
        },
        pageBuilder: (context, state) => bcSweepPage(
          key: state.pageKey,
          child: const BusinessShellScreen(),
        ),
      ),
      GoRoute(
        path: inviteSalon,
        name: 'invite',
        pageBuilder: (context, state) {
          final serviceType = state.extra as String?;
          return bcSweepPage(
            key: state.pageKey,
            child: InviteExperienceScreen(serviceType: serviceType),
          );
        },
      ),
      GoRoute(
        path: '/invite/detail',
        name: 'invite-detail',
        pageBuilder: (context, state) => bcSweepPage(
          key: state.pageKey,
          child: const InviteSalonDetailScreen(),
        ),
      ),
      GoRoute(
        path: settings,
        name: 'settings',
        pageBuilder: (context, state) => bcSweepPage(
          key: state.pageKey,
          child: const SettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/qr-scan',
        name: 'qr-scan',
        pageBuilder: (context, state) => bcSweepPage(
          key: state.pageKey,
          child: const QrScanScreen(),
        ),
      ),
      GoRoute(
        path: salonOnboarding,
        name: 'registro',
        pageBuilder: (context, state) => bcSweepPage(
          key: state.pageKey,
          child: SalonOnboardingScreen(
            refCode: state.uri.queryParameters['ref'],
          ),
        ),
      ),
      GoRoute(
        path: chat,
        name: 'chat',
        pageBuilder: (context, state) => bcSweepPage(
          key: state.pageKey,
          child: const ChatRouterScreen(),
        ),
      ),
      GoRoute(
        path: chatList,
        name: 'chat-list',
        pageBuilder: (context, state) => bcSweepPage(
          key: state.pageKey,
          child: const ChatListScreen(),
        ),
      ),
      GoRoute(
        path: chatConversation,
        name: 'chat-conversation',
        pageBuilder: (context, state) {
          final threadId = state.pathParameters['threadId']!;
          return bcSweepPage(
            key: state.pageKey,
            child: ChatConversationScreen(threadId: threadId),
          );
        },
      ),
      GoRoute(
        path: studio,
        name: 'studio',
        pageBuilder: (context, state) {
          final tabParam = state.uri.queryParameters['tab'];
          const tabIds = ['hair_color', 'hairstyle', 'headshot', 'look_swap'];
          final initialTab = tabParam != null ? tabIds.indexOf(tabParam).clamp(0, 3) : 0;
          return bcSweepPage(
            key: state.pageKey,
            child: VirtualStudioScreen(initialTab: initialTab),
          );
        },
      ),
      GoRoute(
        path: discoveredSalon,
        name: 'discovered-salon',
        pageBuilder: (context, state) {
          final salon = state.extra as DiscoveredSalon;
          return bcSweepPage(
            key: state.pageKey,
            child: DiscoveredSalonDetailScreen(salon: salon),
          );
        },
      ),
      GoRoute(
        path: devices,
        name: 'devices',
        pageBuilder: (context, state) => bcSweepPage(
          key: state.pageKey,
          child: const DeviceManagerScreen(),
        ),
      ),
      GoRoute(
        path: preferences,
        name: 'preferences',
        pageBuilder: (context, state) => bcSweepPage(
          key: state.pageKey,
          child: const PreferencesScreen(),
        ),
      ),
      GoRoute(
        path: profile,
        name: 'profile',
        pageBuilder: (context, state) => bcSweepPage(
          key: state.pageKey,
          child: const ProfileScreen(),
        ),
      ),
      GoRoute(
        path: paymentMethods,
        name: 'payment-methods',
        pageBuilder: (context, state) => bcSweepPage(
          key: state.pageKey,
          child: const PaymentMethodsScreen(),
        ),
      ),
      GoRoute(
        path: security,
        name: 'security',
        pageBuilder: (context, state) => bcSweepPage(
          key: state.pageKey,
          child: const SecurityScreen(),
        ),
      ),
      GoRoute(
        path: cashPayment,
        name: 'cash-payment',
        pageBuilder: (context, state) {
          final data = state.extra as CashPaymentData?;
          return bcSweepPage(
            key: state.pageKey,
            child: CashPaymentScreen(data: data),
          );
        },
      ),
      GoRoute(
        path: legal,
        name: 'legal',
        pageBuilder: (context, state) => bcSweepPage(
          key: state.pageKey,
          child: const TermsAndPolicyScreen(),
        ),
      ),
      GoRoute(
        path: '/cita-express/:businessId',
        name: 'cita-express',
        pageBuilder: (context, state) {
          final businessId = state.pathParameters['businessId']!;
          return bcSweepPage(
            key: state.pageKey,
            child: CitaExpressScreen(businessId: businessId),
          );
        },
      ),
      GoRoute(
        path: discoveredSalonConfirm,
        name: 'discovered-salon-confirm',
        pageBuilder: (context, state) {
          final salonData = state.extra as Map<String, dynamic>;
          return bcSweepPage(
            key: state.pageKey,
            child: DiscoveredSalonConfirmScreen(salonData: salonData),
          );
        },
      ),
      // ── Post-registration: keep fade ──
      GoRoute(
        path: postRegistration,
        name: 'post-registration',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const PostRegistrationScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: feed,
        name: 'feed',
        pageBuilder: (context, state) => bcSweepPage(
          key: state.pageKey,
          child: const FeedScreen(),
        ),
      ),
      GoRoute(
        path: feedSaved,
        name: 'feed-saved',
        pageBuilder: (context, state) => bcSweepPage(
          key: state.pageKey,
          child: const SavedScreen(),
        ),
      ),
      // ── Informational screens (built, not yet linked in navigation) ──
      GoRoute(
        path: about,
        name: 'about',
        pageBuilder: (context, state) => bcSweepPage(
          key: state.pageKey,
          child: const AboutScreen(),
        ),
      ),
      GoRoute(
        path: contact,
        name: 'contact',
        redirect: (_, _) => help,
      ),
      GoRoute(
        path: help,
        name: 'help',
        pageBuilder: (context, state) => bcSweepPage(
          key: state.pageKey,
          child: const HelpScreen(),
        ),
      ),
      GoRoute(
        path: press,
        name: 'press',
        pageBuilder: (context, state) => bcSweepPage(
          key: state.pageKey,
          child: const PressScreen(),
        ),
      ),
      GoRoute(
        path: systemStatus,
        name: 'system-status',
        pageBuilder: (context, state) => bcSweepPage(
          key: state.pageKey,
          child: const SystemStatusScreen(),
        ),
      ),
      GoRoute(
        path: reportProblem,
        name: 'report-problem',
        pageBuilder: (context, state) => bcSweepPage(
          key: state.pageKey,
          child: const ReportProblemScreen(),
        ),
      ),
      GoRoute(
        path: portfolioCapture,
        name: 'portfolio-capture',
        pageBuilder: (context, state) {
          final staffId = state.uri.queryParameters['staffId'];
          final appointmentId = state.uri.queryParameters['appointmentId'];
          return bcSweepPage(
            key: state.pageKey,
            child: PortfolioCaptureScreen(
              staffId: staffId,
              appointmentId: appointmentId,
            ),
          );
        },
      ),
      GoRoute(
        path: '/booking-confirmed/:bookingId',
        name: 'booking-confirmed',
        pageBuilder: (context, state) {
          final bookingId = state.pathParameters['bookingId']!;
          return bcSweepPage(
            key: state.pageKey,
            child: BookingConfirmationScreen(bookingId: bookingId),
          );
        },
      ),
      GoRoute(
        path: favorites,
        name: 'favorites',
        pageBuilder: (context, state) => bcSweepPage(
          key: state.pageKey,
          child: const FavoritesScreen(),
        ),
      ),
    ],
    errorPageBuilder: (context, state) => MaterialPage(
      key: state.pageKey,
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text('Pagina no encontrada',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(state.uri.toString(),
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => context.go(splash),
                child: const Text('Volver al inicio'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  AppRoutes._();
}
