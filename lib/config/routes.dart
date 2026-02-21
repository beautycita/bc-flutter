import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
import 'package:beautycita/screens/salon_onboarding_screen.dart';
import 'package:beautycita/screens/settings_screen.dart';
import 'package:beautycita/screens/chat_list_screen.dart';
import 'package:beautycita/screens/chat_conversation_screen.dart';
import 'package:beautycita/screens/chat_router_screen.dart';
import 'package:beautycita/screens/booking_detail_screen.dart';
import 'package:beautycita/screens/qr_scan_screen.dart';
import 'package:beautycita/screens/device_manager_screen.dart';
import 'package:beautycita/screens/discovered_salon_detail_screen.dart';
import 'package:beautycita/screens/invite_salon_screen.dart' show DiscoveredSalon;
import 'package:beautycita/screens/virtual_studio_screen.dart';
import 'package:beautycita/screens/media_manager_screen.dart';
import 'package:beautycita/screens/preferences_screen.dart';
import 'package:beautycita/screens/profile_screen.dart';
import 'package:beautycita/screens/security_screen.dart';
import 'package:beautycita/screens/payment_methods_screen.dart';
import 'package:beautycita/screens/appearance_screen.dart';
import 'package:beautycita/screens/btc_wallet_screen.dart';
import 'package:beautycita/screens/cash_payment_screen.dart';
import 'package:beautycita/screens/business/business_shell_screen.dart';


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
  static const String mediaManager = '/media-manager';
  static const String preferences = '/settings/preferences';
  static const String profile = '/settings/profile';
  static const String security = '/settings/security';
  static const String paymentMethods = '/settings/payment-methods';
  static const String appearance = '/settings/appearance';
  static const String btcWallet = '/settings/btc-wallet';
  static const String cashPayment = '/settings/cash-payment';


  static final GoRouter router = GoRouter(
    initialLocation: splash,
    debugLogDiagnostics: false,
    routes: [
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
      GoRoute(
        path: home,
        name: 'home',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final tween = Tween(begin: const Offset(0.0, 1.0), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeInOutCubic));
            return SlideTransition(
              position: animation.drive(tween),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
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
              : const Color(0xFFC2185B);
          return CustomTransitionPage(
            key: state.pageKey,
            child: ProviderListScreen(
              category: category,
              subcategory: subcategory,
              categoryColor: color,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final tween = Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeInOutCubic));
              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/provider/:id',
        name: 'provider-detail',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return CustomTransitionPage(
            key: state.pageKey,
            child: ProviderDetailScreen(providerId: id),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final tween = Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeInOutCubic));
              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/booking/:providerId/:serviceId',
        name: 'booking',
        pageBuilder: (context, state) {
          final providerId = state.pathParameters['providerId']!;
          final serviceId = state.pathParameters['serviceId'];
          return CustomTransitionPage(
            key: state.pageKey,
            child: BookingScreen(
              providerId: providerId,
              serviceId: serviceId,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final tween = Tween(begin: const Offset(0.0, 1.0), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeInOutCubic));
              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/booking/:providerId',
        name: 'booking-no-service',
        pageBuilder: (context, state) {
          final providerId = state.pathParameters['providerId']!;
          return CustomTransitionPage(
            key: state.pageKey,
            child: BookingScreen(providerId: providerId),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final tween = Tween(begin: const Offset(0.0, 1.0), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeInOutCubic));
              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/book',
        name: 'book',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const BookingFlowScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final tween = Tween(begin: const Offset(0.0, 1.0), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeInOutCubic));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: '/my-bookings',
        name: 'my-bookings',
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            key: state.pageKey,
            child: const MyBookingsScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final tween = Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeInOutCubic));
              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/appointment/:id',
        name: 'appointment-detail',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return CustomTransitionPage(
            key: state.pageKey,
            child: BookingDetailScreen(bookingId: id),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final tween = Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeInOutCubic));
              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: admin,
        name: 'admin',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const AdminShellScreen(),
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
      GoRoute(
        path: business,
        name: 'business',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const BusinessShellScreen(),
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
      GoRoute(
        path: inviteSalon,
        name: 'invite',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const InviteSalonScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final tween = Tween(begin: const Offset(0.0, 1.0), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeInOutCubic));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: settings,
        name: 'settings',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SettingsScreen(),
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
      GoRoute(
        path: '/qr-scan',
        name: 'qr-scan',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const QrScanScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween(begin: const Offset(0.0, 1.0), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeInOutCubic))
                  .animate(animation),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: salonOnboarding,
        name: 'registro',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: SalonOnboardingScreen(
            refCode: state.uri.queryParameters['ref'],
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final tween = Tween(begin: const Offset(0.0, 1.0), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeInOutCubic));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: chat,
        name: 'chat',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ChatRouterScreen(),
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
      GoRoute(
        path: chatList,
        name: 'chat-list',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ChatListScreen(),
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
      GoRoute(
        path: chatConversation,
        name: 'chat-conversation',
        pageBuilder: (context, state) {
          final threadId = state.pathParameters['threadId']!;
          return CustomTransitionPage(
            key: state.pageKey,
            child: ChatConversationScreen(threadId: threadId),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final tween = Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeInOutCubic));
              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: studio,
        name: 'studio',
        pageBuilder: (context, state) {
          final tabParam = state.uri.queryParameters['tab'];
          const tabIds = ['hair_color', 'hairstyle', 'headshot', 'face_swap'];
          final initialTab = tabParam != null ? tabIds.indexOf(tabParam).clamp(0, 3) : 0;
          return CustomTransitionPage(
            key: state.pageKey,
            child: VirtualStudioScreen(initialTab: initialTab),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final tween = Tween(begin: const Offset(0.0, 1.0), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeInOutCubic));
              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: discoveredSalon,
        name: 'discovered-salon',
        pageBuilder: (context, state) {
          final salon = state.extra as DiscoveredSalon;
          return CustomTransitionPage(
            key: state.pageKey,
            child: DiscoveredSalonDetailScreen(salon: salon),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final tween = Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeInOutCubic));
              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: devices,
        name: 'devices',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const DeviceManagerScreen(),
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
      GoRoute(
        path: mediaManager,
        name: 'media-manager',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const MediaManagerScreen(),
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
      GoRoute(
        path: preferences,
        name: 'preferences',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const PreferencesScreen(),
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
      GoRoute(
        path: profile,
        name: 'profile',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ProfileScreen(),
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
      GoRoute(
        path: paymentMethods,
        name: 'payment-methods',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const PaymentMethodsScreen(),
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
      GoRoute(
        path: security,
        name: 'security',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SecurityScreen(),
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
      GoRoute(
        path: appearance,
        name: 'appearance',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const AppearanceScreen(),
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
      GoRoute(
        path: btcWallet,
        name: 'btc-wallet',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const BtcWalletScreen(),
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
      GoRoute(
        path: cashPayment,
        name: 'cash-payment',
        pageBuilder: (context, state) {
          final data = state.extra as CashPaymentData?;
          return CustomTransitionPage(
            key: state.pageKey,
            child: CashPaymentScreen(data: data),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final tween = Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeInOutCubic));
              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
          );
        },
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
