import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita_core/theme.dart';
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
          final isDesktop = WebBreakpoints.isDesktop(constraints.maxWidth);
          final isTablet = WebBreakpoints.isTablet(constraints.maxWidth);
          return SingleChildScrollView(
            child: Column(
              children: [
                _buildNav(context, isDesktop),
                _buildHero(context, isDesktop, isTablet),
                _buildHowItWorks(context, isDesktop),
                _buildStats(context, isDesktop),
                _buildCta(context, isDesktop),
                _buildFooter(context),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Top navigation bar ──────────────────────────────────────────────────────

  Widget _buildNav(BuildContext context, bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 80 : 24,
        vertical: 16,
      ),
      color: Colors.white,
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [_deepRose, _lightRose],
            ).createShader(bounds),
            child: Text(
              'BeautyCita',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const Spacer(),
          if (isDesktop) ...[
            TextButton(
              onPressed: () {},
              child: const Text('Para salones'),
            ),
            const SizedBox(width: 8),
          ],
          OutlinedButton(
            onPressed: () => context.go(WebRoutes.auth),
            child: const Text('Iniciar sesion'),
          ),
        ],
      ),
    );
  }

  // ── Hero section ────────────────────────────────────────────────────────────

  Widget _buildHero(BuildContext context, bool isDesktop, bool isTablet) {
    final theme = Theme.of(context);
    final horizontalPad = isDesktop ? 80.0 : 32.0;

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
          horizontal: horizontalPad,
          vertical: isDesktop ? 100 : 60,
        ),
        child: isDesktop
            ? Row(
                children: [
                  Expanded(child: _heroText(context, theme, true)),
                  const SizedBox(width: 60),
                  Expanded(child: _heroVisual(context)),
                ],
              )
            : Column(
                children: [
                  _heroText(context, theme, false),
                  const SizedBox(height: 40),
                  _heroVisual(context),
                ],
              ),
      ),
    );
  }

  Widget _heroText(BuildContext context, ThemeData theme, bool isDesktop) {
    return Column(
      crossAxisAlignment:
          isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Tu agente inteligente de belleza',
          textAlign: isDesktop ? TextAlign.start : TextAlign.center,
          style: theme.textTheme.displaySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Selecciona el servicio que quieres. BeautyCita encuentra los mejores salones cerca de ti, elige el horario perfecto, y te da 3 opciones para reservar con un solo toque.',
          textAlign: isDesktop ? TextAlign.start : TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.85),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 36),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          alignment: isDesktop ? WrapAlignment.start : WrapAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () => _launchUrl(_apkUrl),
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 16,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 16,
                ),
              ),
              child: const Text('Iniciar sesion'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app, color: _gold.withValues(alpha: 0.8), size: 18),
            const SizedBox(width: 8),
            Text(
              '4 toques. 30 segundos. Cero teclado.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _heroVisual(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Simulated phone screen showing the flow
          _flowStep(context, '1', 'Elige tu servicio', Icons.content_cut),
          const SizedBox(height: 16),
          Icon(Icons.arrow_downward_rounded,
              color: Colors.white.withValues(alpha: 0.4), size: 20),
          const SizedBox(height: 16),
          _flowStep(context, '2', 'BeautyCita busca por ti', Icons.auto_awesome),
          const SizedBox(height: 16),
          Icon(Icons.arrow_downward_rounded,
              color: Colors.white.withValues(alpha: 0.4), size: 20),
          const SizedBox(height: 16),
          _flowStep(context, '3', 'Reserva con un toque', Icons.check_circle_outline),
        ],
      ),
    );
  }

  Widget _flowStep(
      BuildContext context, String number, String label, IconData icon) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _gold,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
        Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: 28),
      ],
    );
  }

  // ── How it works section ────────────────────────────────────────────────────

  Widget _buildHowItWorks(BuildContext context, bool isDesktop) {
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
        horizontal: isDesktop ? 80 : 32,
        vertical: isDesktop ? 80 : 48,
      ),
      child: Column(
        children: [
          Text(
            'Como funciona',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'BeautyCita no es una app de reservas. Es tu agente personal de belleza.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 48),
          Wrap(
            spacing: 32,
            runSpacing: 32,
            alignment: WrapAlignment.center,
            children: items.map((item) {
              return SizedBox(
                width: isDesktop ? 260 : double.infinity,
                child: _buildFeatureCard(context, item),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context, _FeatureItem item) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
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
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
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

  // ── Stats section ───────────────────────────────────────────────────────────

  Widget _buildStats(BuildContext context, bool isDesktop) {
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
        horizontal: isDesktop ? 80 : 32,
        vertical: isDesktop ? 60 : 40,
      ),
      child: Wrap(
        spacing: 48,
        runSpacing: 32,
        alignment: WrapAlignment.spaceEvenly,
        children: stats.map((s) {
          return SizedBox(
            width: isDesktop ? 200 : 140,
            child: Column(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [_deepRose, _lightRose],
                  ).createShader(bounds),
                  child: Text(
                    s.$1,
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  s.$2,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Bottom CTA ──────────────────────────────────────────────────────────────

  Widget _buildCta(BuildContext context, bool isDesktop) {
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
        horizontal: isDesktop ? 80 : 32,
        vertical: isDesktop ? 60 : 40,
      ),
      child: Column(
        children: [
          Text(
            'Descarga BeautyCita gratis',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Disponible para Android. iOS proximamente.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () => _launchUrl(_apkUrl),
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
              textStyle: theme.textTheme.titleMedium?.copyWith(
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

  Widget _buildFooter(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
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
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tu agente inteligente de belleza',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '2026 BeautyCita. Todos los derechos reservados.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
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
