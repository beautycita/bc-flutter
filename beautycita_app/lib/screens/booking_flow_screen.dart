import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/constants.dart';
import '../providers/booking_flow_provider.dart';
import '../widgets/cinematic_question_text.dart';
import 'follow_up_question_screen.dart';
import 'result_cards_screen.dart';
import 'confirmation_screen.dart';
import 'email_verification_screen.dart';

class BookingFlowScreen extends ConsumerWidget {
  const BookingFlowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookingFlowProvider);

    // If state reset to categorySelect, pop back to home
    if (state.step == BookingFlowStep.categorySelect) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.pop();
      });
      return const SizedBox.shrink();
    }

    return switch (state.step) {
      BookingFlowStep.followUpQuestions => const FollowUpQuestionScreen(),
      BookingFlowStep.subcategorySelect => const SizedBox.shrink(),
      BookingFlowStep.loading => _LoadingView(
          serviceName: state.serviceName ?? '',
        ),
      BookingFlowStep.results => const ResultCardsScreen(),
      BookingFlowStep.confirmation => const ConfirmationScreen(),
      BookingFlowStep.booking => _LoadingView(
          serviceName: 'Reservando tu cita...',
        ),
      BookingFlowStep.emailVerification => EmailVerificationScreen(
          onComplete: (email) {
            ref.read(bookingFlowProvider.notifier).advanceFromEmail(hasEmail: true);
          },
          onSkip: () {
            ref.read(bookingFlowProvider.notifier).advanceFromEmail(hasEmail: false);
          },
        ),
      BookingFlowStep.booked => const ConfirmationScreen(),
      BookingFlowStep.error => _ErrorView(
          error: state.error ?? 'Error desconocido',
          onRetry: () =>
              ref.read(bookingFlowProvider.notifier).goBack(),
        ),
      BookingFlowStep.categorySelect => const SizedBox.shrink(),
    };
  }
}

class _LoadingView extends StatelessWidget {
  final String serviceName;

  const _LoadingView({required this.serviceName});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: palette.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CinematicQuestionText(
              text: 'Buscando las mejores opciones...',
              fontSize: 24,
            ),
            const SizedBox(height: AppConstants.paddingLG),
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: palette.primary,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: AppConstants.paddingSM),
            Text(
              serviceName,
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: palette.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: palette.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: palette.onSurface, size: 24),
          onPressed: onRetry,
        ),
      ),
      body: Center(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppConstants.paddingLG),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: palette.primary,
              ),
              const SizedBox(height: AppConstants.paddingLG),
              Text(
                'No pudimos encontrar resultados',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: palette.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.paddingSM),
              Text(
                error,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: palette.onSurface.withValues(alpha: 0.5),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.paddingXL),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Intentar de nuevo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
