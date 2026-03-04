import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/constants.dart';
import '../config/theme_extension.dart';

/// Success screen shown after salon owner creates their stylist account.
/// Prompts them to add a service and configure their schedule.
class PostRegistrationScreen extends ConsumerWidget {
  const PostRegistrationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bcTheme = Theme.of(context).extension<BCThemeExtension>()!;
    final onSurfaceLight =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingLG,
          ),
          child: Column(
            children: [
              const SizedBox(height: 48),

              // Celebration icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: bcTheme.goldGradientDirectional(),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                          const Color(0xFFB8860B).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.celebration_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              // Welcome text
              Text(
                'Bienvenido a BeautyCita!',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Tu cuenta de estilista esta lista.\nCompleta estos pasos para recibir reservas.',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  color: onSurfaceLight,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),

              // Step 1: Add a service
              _StepCard(
                stepNumber: '1',
                title: 'Agrega un servicio con precio',
                subtitle:
                    'Tus clientes necesitan ver que ofreces y cuanto cuesta.',
                icon: Icons.content_cut_rounded,
                buttonLabel: 'IR A SERVICIOS',
                gradient: bcTheme.goldGradientDirectional(),
                onTap: () => context.go('/business'),
              ),
              const SizedBox(height: 16),

              // Step 2: Configure schedule
              _StepCard(
                stepNumber: '2',
                title: 'Configura tu horario',
                subtitle:
                    'Ya tienes un horario predeterminado (Lun-Sab 9am-7pm). Ajustalo a tu gusto.',
                icon: Icons.calendar_month_rounded,
                buttonLabel: 'IR A CALENDARIO',
                gradient: bcTheme.goldGradientDirectional(),
                onTap: () => context.go('/business'),
              ),
              const SizedBox(height: 32),

              // Skip option
              TextButton(
                onPressed: () => context.go('/home'),
                child: Text(
                  'Hacer despues',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: onSurfaceLight,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String stepNumber;
  final String title;
  final String subtitle;
  final IconData icon;
  final String buttonLabel;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _StepCard({
    required this.stepNumber,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.buttonLabel,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  stepNumber,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(icon, size: 24, color: primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 44),
            child: Text(
              subtitle,
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 44),
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color:
                          const Color(0xFFB8860B).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  buttonLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
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
