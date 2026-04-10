import 'package:flutter/material.dart';
import 'package:beautycita_core/theme.dart';

import '../../config/breakpoints.dart';

/// Shared split-panel layout for all auth pages.
///
/// **Desktop (>= 800px):** Left half = brand panel, right half = centered form.
/// **Mobile (< 800px):** Brand strip at top, form below.
class AuthLayout extends StatelessWidget {
  final Widget formContent;
  const AuthLayout({super.key, required this.formContent});

  static const _lilacAccent = Color(0xFFC8A2C8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          if (WebBreakpoints.isMobile(w)) {
            return _mobileLayout(context);
          }
          if (WebBreakpoints.isTablet(w)) {
            return _tabletLayout(context);
          }
          return _desktopLayout(context);
        },
      ),
    );
  }

  Widget _desktopLayout(BuildContext context) {
    return Row(
      children: [
        // ── Left: brand panel ─────────────────────────────────────────────
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF8A6B8A), Color(0xFFC8A2C8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: BCSpacing.xl),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) => Opacity(
                    opacity: t,
                    child: Transform.scale(
                      scale: 0.9 + 0.1 * t,
                      child: child,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Colors.white, _lilacAccent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: Text(
                          'BeautyCita',
                          style: Theme.of(context)
                              .textTheme
                              .displayMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tu agente inteligente de belleza',
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '4 toques. 30 segundos. Cero teclado.',
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Right: form content ───────────────────────────────────────────
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(BCSpacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: formContent,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tabletLayout(BuildContext context) {
    return Row(
      children: [
        // ── Left: narrow brand panel ──────────────────────────────────────
        Expanded(
          flex: 2,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF8A6B8A), Color(0xFFC8A2C8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: BCSpacing.lg),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) => Opacity(
                    opacity: t,
                    child: Transform.scale(
                      scale: 0.9 + 0.1 * t,
                      child: child,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Colors.white, _lilacAccent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: Text(
                          'BeautyCita',
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tu agente inteligente de belleza',
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Right: form content ───────────────────────────────────────────
        Expanded(
          flex: 3,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(BCSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: formContent,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _mobileLayout(BuildContext context) {
    return Column(
      children: [
        // ── Top: brand strip ──────────────────────────────────────────────
        Container(
          width: double.infinity,
          height: 120,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF8A6B8A), Color(0xFFC8A2C8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.white, _lilacAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: Text(
                    'BeautyCita',
                    style:
                        Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tu agente inteligente de belleza',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                ),
              ],
            ),
          ),
        ),

        // ── Below: form content ───────────────────────────────────────────
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(BCSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: formContent,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
