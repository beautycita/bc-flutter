import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/breakpoints.dart';
import '../config/router.dart';

/// Public landing page — what visitors see at beautycita.com.
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  static const _apkUrl =
      'https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/apk/beautycita.apk';

  static const _deepRose = Color(0xFF990033);
  static const _lightRose = Color(0xFFC2185B);
  static const _gold = Color(0xFFFFB300);
  static const _cream = Color(0xFFFFF8F0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final isDesktop = WebBreakpoints.isDesktop(w);
          final isMobile = w < 600;
          // Horizontal padding scales: 16 mobile, 32 tablet, 80 desktop
          final hPad = isMobile ? 16.0 : (isDesktop ? 80.0 : 32.0);
          return SingleChildScrollView(
            child: Column(
              children: [
                _buildNav(context, isDesktop, isMobile, hPad),
                _buildHero(context, isDesktop, isMobile, hPad),
                _buildHowItWorks(context, isDesktop, isMobile, hPad),
                _buildAppPreview(context, isDesktop, isMobile, hPad),
                _buildStats(context, isDesktop, isMobile, hPad, w),
                _buildCta(context, isDesktop, isMobile, hPad),
                _buildFooter(context, isMobile),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Top navigation bar ──────────────────────────────────────────────────────

  Widget _buildNav(
      BuildContext context, bool isDesktop, bool isMobile, double hPad) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [_deepRose, _lightRose],
            ).createShader(bounds),
            child: Text(
              'BeautyCita',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 18 : null,
                  ),
            ),
          ),
          const Spacer(),
          if (isDesktop) ...[
            TextButton(
              onPressed: () => context.go(WebRoutes.demo),
              child: const Text('Para salones'),
            ),
            const SizedBox(width: 8),
          ],
          OutlinedButton(
            onPressed: () => context.go(WebRoutes.auth),
            style: isMobile
                ? OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  )
                : null,
            child: const Text('Iniciar sesion'),
          ),
        ],
      ),
    );
  }

  // ── Hero section ────────────────────────────────────────────────────────────

  Widget _buildHero(
      BuildContext context, bool isDesktop, bool isMobile, double hPad) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF660033), _deepRose, _lightRose],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: hPad,
          vertical: isDesktop ? 100 : (isMobile ? 32 : 60),
        ),
        child: isDesktop
            ? Row(
                children: [
                  Expanded(
                      child: _heroText(context, theme, isDesktop, isMobile)),
                  const SizedBox(width: 60),
                  Expanded(child: _heroVisual(context, isMobile)),
                ],
              )
            : Column(
                children: [
                  _heroText(context, theme, isDesktop, isMobile),
                  const SizedBox(height: 32),
                  _heroVisual(context, isMobile),
                ],
              ),
      ),
    );
  }

  Widget _heroText(
      BuildContext context, ThemeData theme, bool isDesktop, bool isMobile) {
    return Column(
      crossAxisAlignment:
          isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Tu agente inteligente de belleza',
          textAlign: isDesktop ? TextAlign.start : TextAlign.center,
          style: isMobile
              ? theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                )
              : theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
        ),
        const SizedBox(height: 16),
        Text(
          'Selecciona el servicio que quieres. BeautyCita encuentra los mejores salones cerca de ti, elige el horario perfecto, y te da 3 opciones para reservar con un solo toque.',
          textAlign: isDesktop ? TextAlign.start : TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.85),
            height: 1.5,
            fontSize: isMobile ? 14 : null,
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          alignment: isDesktop ? WrapAlignment.start : WrapAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () => _launchUrl(_apkUrl),
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black87,
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 20 : 28,
                  vertical: isMobile ? 12 : 16,
                ),
              ),
              icon: const Icon(Icons.download_rounded, size: 20),
              label: const Text('Descarga la App'),
            ),
            OutlinedButton(
              onPressed: () => context.go(WebRoutes.auth),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white70),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 20 : 28,
                  vertical: isMobile ? 12 : 16,
                ),
              ),
              child: const Text('Iniciar sesion'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app,
                color: _gold.withValues(alpha: 0.8), size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '4 toques. 30 segundos. Cero teclado.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _heroVisual(BuildContext context, bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _flowStep(context, '1', 'Elige tu servicio', Icons.content_cut,
              isMobile),
          const SizedBox(height: 12),
          Icon(Icons.arrow_downward_rounded,
              color: Colors.white.withValues(alpha: 0.4), size: 18),
          const SizedBox(height: 12),
          _flowStep(context, '2', 'BeautyCita busca por ti',
              Icons.auto_awesome, isMobile),
          const SizedBox(height: 12),
          Icon(Icons.arrow_downward_rounded,
              color: Colors.white.withValues(alpha: 0.4), size: 18),
          const SizedBox(height: 12),
          _flowStep(context, '3', 'Reserva con un toque',
              Icons.check_circle_outline, isMobile),
        ],
      ),
    );
  }

  Widget _flowStep(BuildContext context, String number, String label,
      IconData icon, bool isMobile) {
    return Row(
      children: [
        Container(
          width: isMobile ? 30 : 36,
          height: isMobile ? 30 : 36,
          decoration: BoxDecoration(
            color: _gold,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 14 : 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: isMobile ? 14 : null,
                ),
          ),
        ),
        Icon(icon,
            color: Colors.white.withValues(alpha: 0.6),
            size: isMobile ? 22 : 28),
      ],
    );
  }

  // ── How it works section ────────────────────────────────────────────────────

  Widget _buildHowItWorks(
      BuildContext context, bool isDesktop, bool isMobile, double hPad) {
    final theme = Theme.of(context);
    final items = [
      _FeatureItem(
        icon: Icons.spa_outlined,
        title: 'Empieza por el servicio',
        description:
            'Corte, color, unas, pestanas, facial... cada servicio tiene su propia inteligencia para encontrar el mejor resultado.',
      ),
      _FeatureItem(
        icon: Icons.psychology_outlined,
        title: 'Inteligencia que aprende',
        description:
            'El motor analiza ubicacion, trafico, horarios, calificaciones y tus preferencias para darte las 3 mejores opciones.',
      ),
      _FeatureItem(
        icon: Icons.bolt_outlined,
        title: 'Reserva instantanea',
        description:
            'Sin buscar. Sin comparar. Sin calendario. Un toque y tu cita queda confirmada con el salon perfecto.',
      ),
      _FeatureItem(
        icon: Icons.local_taxi_outlined,
        title: 'Transporte incluido',
        description:
            'Elige entre manejar, Uber o transporte publico. En modo Uber, se agenda ida y vuelta automaticamente.',
      ),
    ];

    return Container(
      width: double.infinity,
      color: _cream,
      padding: EdgeInsets.symmetric(
        horizontal: hPad,
        vertical: isDesktop ? 80 : (isMobile ? 32 : 48),
      ),
      child: Column(
        children: [
          Text(
            'Como funciona',
            style: (isMobile
                    ? theme.textTheme.titleLarge
                    : theme.textTheme.headlineMedium)
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'BeautyCita no es una app de reservas. Es tu agente personal de belleza.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: isMobile ? 13 : null,
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: isMobile ? 12 : 32,
            runSpacing: isMobile ? 12 : 32,
            alignment: WrapAlignment.center,
            children: items.map((item) {
              return SizedBox(
                width: isDesktop ? 260 : double.infinity,
                child: _buildFeatureCard(context, item, isMobile),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
      BuildContext context, _FeatureItem item, bool isMobile) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: isMobile
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _lightRose.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: _lightRose, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _lightRose.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: _lightRose, size: 28),
                ),
                const SizedBox(height: 16),
                Text(
                  item.title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  item.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    height: 1.5,
                  ),
                ),
              ],
            ),
    );
  }

  // ── App preview carousel ────────────────────────────────────────────────────

  static const _screenshots = [
    'assets/screenshots/01_home.png',
    'assets/screenshots/02_subcategory.png',
    'assets/screenshots/03_service_flow.png',
    'assets/screenshots/04_categories_scroll.png',
    'assets/screenshots/05_settings.png',
    'assets/screenshots/06_security.png',
    'assets/screenshots/07_preferences.png',
    'assets/screenshots/08_unas.png',
  ];

  static const _screenshotLabels = [
    'Categorias',
    'Subcategoria',
    'Servicios',
    'Mas categorias',
    'Ajustes',
    'Seguridad',
    'Preferencias',
    'Pestanas y cejas',
  ];

  Widget _buildAppPreview(
      BuildContext context, bool isDesktop, bool isMobile, double hPad) {
    final theme = Theme.of(context);
    final cardH = isMobile ? 340.0 : (isDesktop ? 480.0 : 400.0);
    final cardW = cardH * 0.487; // ~9:19 phone ratio

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        vertical: isDesktop ? 80 : (isMobile ? 32 : 48),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: Column(
              children: [
                Text(
                  'Conoce la app',
                  style: (isMobile
                          ? theme.textTheme.titleLarge
                          : theme.textTheme.headlineMedium)
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Asi se ve BeautyCita en tu telefono',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: isMobile ? 13 : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: cardH + 32, // card + label
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: hPad),
              itemCount: _screenshots.length,
              separatorBuilder: (_, __) =>
                  SizedBox(width: isMobile ? 12 : 20),
              itemBuilder: (context, index) {
                return Column(
                  children: [
                    Container(
                      width: cardW,
                      height: cardH,
                      decoration: BoxDecoration(
                        color: _cream,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        _screenshots[index],
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _screenshotLabels[index],
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats section ───────────────────────────────────────────────────────────

  Widget _buildStats(BuildContext context, bool isDesktop, bool isMobile,
      double hPad, double viewportWidth) {
    final theme = Theme.of(context);
    final stats = [
      ('30,000+', 'Salones descubiertos'),
      ('200ms', 'Tiempo de respuesta'),
      ('30 seg', 'De inicio a reserva'),
      ('4', 'Toques maximo'),
    ];

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: hPad,
        vertical: isDesktop ? 60 : (isMobile ? 24 : 40),
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : (isDesktop ? 48 : 24),
          vertical: isMobile ? 20 : (isDesktop ? 40 : 28),
        ),
        decoration: BoxDecoration(
          color: _cream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: viewportWidth < 500
            ? Column(
                children: stats
                    .map((s) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: _statItem(theme, s.$1, s.$2, true),
                        ))
                    .toList(),
              )
            : isMobile
                ? Wrap(
                    spacing: 0,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    children: stats.map((s) {
                      return SizedBox(
                        width:
                            (viewportWidth - hPad * 2 - 24) / 2,
                        child: _statItem(theme, s.$1, s.$2, isMobile),
                      );
                    }).toList(),
                  )
                : Row(
                    children: stats
                        .map((s) => Expanded(
                            child: _statItem(theme, s.$1, s.$2, isMobile)))
                        .toList(),
                  ),
      ),
    );
  }

  Widget _statItem(
      ThemeData theme, String value, String label, bool isMobile) {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [_deepRose, _lightRose],
          ).createShader(bounds),
          child: Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 22 : null,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: isMobile ? 11 : null,
          ),
        ),
      ],
    );
  }

  // ── Bottom CTA ──────────────────────────────────────────────────────────────

  Widget _buildCta(
      BuildContext context, bool isDesktop, bool isMobile, double hPad) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF660033), _deepRose],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: hPad,
        vertical: isDesktop ? 60 : (isMobile ? 32 : 40),
      ),
      child: Column(
        children: [
          Text(
            'Descarga BeautyCita gratis',
            textAlign: TextAlign.center,
            style: (isMobile
                    ? theme.textTheme.titleLarge
                    : theme.textTheme.headlineMedium)
                ?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Disponible para Android. iOS proximamente.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: isMobile ? 13 : null,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _launchUrl(_apkUrl),
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: Colors.black87,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 24 : 32,
                vertical: isMobile ? 14 : 18,
              ),
              textStyle: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            icon: const Icon(Icons.android, size: 22),
            label: const Text('Descargar APK'),
          ),
        ],
      ),
    );
  }

  // ── Footer ──────────────────────────────────────────────────────────────────

  Widget _buildFooter(BuildContext context, bool isMobile) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: const Color(0xFF1A1A1A),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: isMobile ? 24 : 32,
      ),
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.white, _gold],
            ).createShader(bounds),
            child: Text(
              'BeautyCita',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 18 : null,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tu agente inteligente de belleza',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _footerLink(context, 'Clientes', WebRoutes.reservar),
              _footerLink(context, 'Salones', WebRoutes.demo),
              _footerLink(context, 'Soporte', WebRoutes.soporte),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '2026 BeautyCita. Todos los derechos reservados.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: isMobile ? 11 : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerLink(BuildContext context, String label, String route) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go(route),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
              ),
        ),
      ),
    );
  }

  void _launchUrl(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

class _FeatureItem {
  final IconData icon;
  final String title;
  final String description;

  _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}
