import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:beautycita_core/theme.dart';

import '../../config/breakpoints.dart';
import '../../widgets/web_chat_panel.dart';

class SoportePage extends ConsumerWidget {
  const SoportePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = WebBreakpoints.isDesktop(width);
    final isMobile = WebBreakpoints.isMobile(width);
    final isAuthenticated = BCSupabase.isInitialized && BCSupabase.isAuthenticated;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // ── Top bar ──
          _SoporteTopBar(isMobile: isMobile),
          const Divider(height: 1),

          // ── Content ──
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? BCSpacing.md : BCSpacing.xl,
                      vertical: BCSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Text(
                          'Soporte BeautyCita',
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: BCSpacing.xs),
                        Text(
                          'Estamos aqui para ayudarte',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: BCSpacing.xl),

                        // Desktop: two columns | Mobile: stacked
                        if (isDesktop || !isMobile)
                          _DesktopLayout(isAuthenticated: isAuthenticated)
                        else
                          _MobileLayout(isAuthenticated: isAuthenticated),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Top navigation bar ───────────────────────────────────────────────────────

class _SoporteTopBar extends StatelessWidget {
  final bool isMobile;

  const _SoporteTopBar({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAuthenticated =
        BCSupabase.isInitialized && BCSupabase.isAuthenticated;

    return Container(
      color: theme.colorScheme.surface,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? BCSpacing.md : BCSpacing.xl,
        vertical: BCSpacing.md,
      ),
      child: Row(
        children: [
          // Logo / brand
          InkWell(
            onTap: () => context.go('/'),
            borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
            child: Text(
              'BeautyCita',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Spacer(),
          // Auth button
          if (!isAuthenticated)
            OutlinedButton(
              onPressed: () => context.go('/auth'),
              child: const Text('Iniciar sesion'),
            )
          else
            TextButton.icon(
              onPressed: () {
                // Go back to appropriate portal
                context.go('/');
              },
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Volver'),
            ),
        ],
      ),
    );
  }
}

// ── Desktop layout: two columns ──────────────────────────────────────────────

class _DesktopLayout extends StatelessWidget {
  final bool isAuthenticated;

  const _DesktopLayout({required this.isAuthenticated});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 700,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // FAQ column (40%)
          const Expanded(
            flex: 4,
            child: _FaqSection(),
          ),
          const SizedBox(width: BCSpacing.xl),
          // Chat column (60%)
          Expanded(
            flex: 6,
            child: isAuthenticated
                ? const WebChatPanel()
                : const _LoginPromptCard(),
          ),
        ],
      ),
    );
  }
}

// ── Mobile layout: stacked ───────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  final bool isAuthenticated;

  const _MobileLayout({required this.isAuthenticated});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FaqSection(),
        const SizedBox(height: BCSpacing.xl),
        SizedBox(
          height: 500,
          child: isAuthenticated
              ? const WebChatPanel()
              : const _LoginPromptCard(),
        ),
      ],
    );
  }
}

// ── FAQ Section ──────────────────────────────────────────────────────────────

class _FaqSection extends StatelessWidget {
  const _FaqSection();

  static const _faqs = <({String q, String a})>[
    (
      q: 'Que es BeautyCita?',
      a: 'BeautyCita es un agente inteligente de reservas de belleza. '
          'Seleccionas el servicio que necesitas y en menos de 30 segundos '
          'te muestra las 3 mejores opciones cerca de ti, listas para reservar con un solo toque.',
    ),
    (
      q: 'Como reservo una cita?',
      a: 'Abre la app, elige la categoria de servicio (cabello, unas, etc.), '
          'selecciona el servicio especifico, y el motor inteligente te muestra '
          '3 opciones. Toca "Reservar" en la que prefieras. 4-6 toques, cero teclado.',
    ),
    (
      q: 'Cuanto cuesta usar BeautyCita?',
      a: 'Para clientes es 100% gratis. Los salones pagan una comision del 3% '
          'por cada reserva completada a traves de la plataforma.',
    ),
    (
      q: 'Como registro mi salon?',
      a: 'El registro toma 60 segundos. Puedes hacerlo desde la app web '
          '(beautycita.com) o por WhatsApp. Solo necesitas nombre del negocio, '
          'direccion y servicios que ofreces.',
    ),
    (
      q: 'Que metodos de pago aceptan?',
      a: 'Aceptamos tarjeta de credito/debito (via Stripe), efectivo en el salon, '
          'y Bitcoin. El metodo de pago se confirma al momento de reservar.',
    ),
    (
      q: 'Como cancelo una cita?',
      a: 'Puedes cancelar hasta 24 horas antes de tu cita sin ningun cargo. '
          'Ve a "Mis Citas" en la app y selecciona la opcion de cancelar.',
    ),
    (
      q: 'Mi salon no aparece, que hago?',
      a: 'Puedes recomendar tu salon favorito usando la opcion "Recomienda tu salon" '
          'en la app. Le enviaremos una invitacion por WhatsApp para que se registre.',
    ),
    (
      q: 'Es seguro dar mis datos?',
      a: 'Si. Usamos autenticacion biometrica (huella o rostro), no almacenamos '
          'contrasenas, y toda la comunicacion esta encriptada. Tu informacion '
          'personal nunca se comparte con terceros.',
    ),
    (
      q: 'BeautyCita esta disponible en mi ciudad?',
      a: 'Actualmente estamos disponibles en varias ciudades de Mexico y '
          'Estados Unidos. Si tu ciudad aun no tiene salones registrados, '
          'puedes recomendar salones locales para acelerar la expansion.',
    ),
    (
      q: 'Como contacto a soporte?',
      a: 'Estas en el lugar correcto. Usa el chat de Eros IA para respuestas '
          'instantaneas, o cambia a Soporte Humano para hablar con nuestro equipo.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.help_outline_rounded,
                size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: BCSpacing.sm),
            Text(
              'Preguntas Frecuentes',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: BCSpacing.md),
        ..._faqs.map((faq) => _FaqTile(question: faq.q, answer: faq.a)),
      ],
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: BCSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: BCSpacing.md),
          childrenPadding: const EdgeInsets.fromLTRB(
            BCSpacing.md,
            0,
            BCSpacing.md,
            BCSpacing.md,
          ),
          title: Text(
            question,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          children: [
            Text(
              answer,
              style: theme.textTheme.bodySmall?.copyWith(
                color:
                    theme.colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Login prompt ─────────────────────────────────────────────────────────────

class _LoginPromptCard extends StatelessWidget {
  const _LoginPromptCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(BCSpacing.radiusSm),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(BCSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 48,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: BCSpacing.md),
              Text(
                'Inicia sesion para chatear',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: BCSpacing.sm),
              Text(
                'Nuestro agente Eros y el equipo de soporte estan listos para ayudarte.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: BCSpacing.lg),
              ElevatedButton(
                onPressed: () => context.go('/auth'),
                child: const Text('Iniciar sesion'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
