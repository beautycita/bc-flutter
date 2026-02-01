import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita/screens/splash_screen.dart';
import 'package:beautycita/screens/auth_screen.dart';
import 'package:beautycita/screens/home_screen.dart';
import 'package:beautycita/screens/provider_list_screen.dart';
import 'package:beautycita/screens/provider_detail_screen.dart';
import 'package:beautycita/screens/booking_screen.dart';
import 'package:beautycita/screens/my_bookings_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String auth = '/auth';
  static const String home = '/home';
  static const String providers = '/providers';
  static const String providerDetail = '/provider/:id';
  static const String booking = '/booking/:providerId/:serviceId';
  static const String bookingNoService = '/booking/:providerId';
  static const String myBookings = '/my-bookings';

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
    ],
    errorPageBuilder: (context, state) => MaterialPage(
      key: state.pageKey,
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Color(0xFFC2185B)),
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
