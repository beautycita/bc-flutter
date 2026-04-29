// =============================================================================
// ExpressCita external-QR landing — /expresscita/:slug
// =============================================================================
// Scanning the external-door QR on a phone hits this page. We detect the
// platform and redirect to the native app via deep link, falling back to
// the appropriate store if the app isn't installed.
//
// Desktop users land on a page explaining they need the app + QR code to
// install on their phone.
// =============================================================================

import 'dart:async';
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';

class ExpressCitaLandingPage extends StatefulWidget {
  final String slug;
  const ExpressCitaLandingPage({super.key, required this.slug});

  @override
  State<ExpressCitaLandingPage> createState() => _ExpressCitaLandingPageState();
}

class _ExpressCitaLandingPageState extends State<ExpressCitaLandingPage> {
  _Platform _platform = _Platform.unknown;

  @override
  void initState() {
    super.initState();
    _platform = _detectPlatform();
    if (_platform == _Platform.android || _platform == _Platform.ios) {
      // Try deep link. If the app is installed, the OS switches away.
      // If not installed, we fall back to the store after a short delay.
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryDeepLinkThenStore());
    }
  }

  _Platform _detectPlatform() {
    final ua = web.window.navigator.userAgent.toLowerCase();
    if (ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod')) {
      return _Platform.ios;
    }
    if (ua.contains('android')) {
      return _Platform.android;
    }
    if (ua.contains('windows')) return _Platform.windows;
    if (ua.contains('mac')) return _Platform.mac;
    return _Platform.desktop;
  }

  void _tryDeepLinkThenStore() {
    final deepLink = 'beautycita://expresscita/${widget.slug}';
    web.window.location.href = deepLink;

    // After 1.5s, assume deep link failed and redirect to store.
    Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      final storeUrl = _platform == _Platform.ios
          ? 'https://apps.apple.com/mx/app/beautycita/id0000000000'
          : 'https://play.google.com/store/apps/details?id=com.beautycita.app';
      web.window.location.href = storeUrl;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_platform == _Platform.android || _platform == _Platform.ios) {
      return _MobileRedirectingView(slug: widget.slug);
    }
    // Desktop / unknown
    return _DesktopView(slug: widget.slug);
  }
}

enum _Platform { ios, android, windows, mac, desktop, unknown }

class _MobileRedirectingView extends StatelessWidget {
  final String slug;
  const _MobileRedirectingView({required this.slug});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.phone_iphone, size: 64, color: Color(0xFFEC4899)),
                const SizedBox(height: 20),
                const Text(
                  'Abriendo BeautyCita…',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Si no tienes la app instalada, te llevaremos a la tienda en unos segundos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.4),
                ),
                const SizedBox(height: 32),
                const CircularProgressIndicator(color: Color(0xFFEC4899)),
                const SizedBox(height: 32),
                TextButton(
                  onPressed: () {
                    final ua = web.window.navigator.userAgent.toLowerCase();
                    final store = ua.contains('iphone') || ua.contains('ipad')
                        ? 'https://apps.apple.com/mx/app/beautycita/id0000000000'
                        : 'https://play.google.com/store/apps/details?id=com.beautycita.app';
                    web.window.location.href = store;
                  },
                  child: const Text('Ir a la tienda manualmente'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopView extends StatelessWidget {
  final String slug;
  const _DesktopView({required this.slug});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'BeautyCita',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFEC4899),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'ExpressCita requiere la aplicacion',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'ExpressCita es la forma mas rapida de reservar una cita de belleza en Mexico. '
                  'Descarga la app en tu telefono y escanea el codigo QR nuevamente para reservar '
                  'en el salon que tiene tu preferencia o en otros cercanos con disponibilidad inmediata.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.5),
                ),
                const SizedBox(height: 32),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => web.window.location.href =
                          'https://apps.apple.com/mx/app/beautycita/id0000000000',
                      icon: const Icon(Icons.apple),
                      label: const Text('App Store'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => web.window.location.href =
                          'https://play.google.com/store/apps/details?id=com.beautycita.app',
                      icon: const Icon(Icons.android),
                      label: const Text('Google Play'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                Text(
                  'Salon ID: $slug',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
