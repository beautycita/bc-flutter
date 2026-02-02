import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../providers/booking_flow_provider.dart';
import 'transport_selection.dart';
import 'follow_up_question_screen.dart';
import 'result_cards_screen.dart';
import 'confirmation_screen.dart';

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
      BookingFlowStep.transportSelect ||
      BookingFlowStep.subcategorySelect =>
        const TransportSelection(),
      BookingFlowStep.loading => _LoadingView(
          serviceName: state.serviceName ?? '',
        ),
      BookingFlowStep.results => const ResultCardsScreen(),
      BookingFlowStep.confirmation => const ConfirmationScreen(),
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
    return Scaffold(
      backgroundColor: BeautyCitaTheme.surfaceCream,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: BeautyCitaTheme.primaryRose,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: BeautyCitaTheme.spaceLG),
            Text(
              'Buscando las mejores opciones...',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: BeautyCitaTheme.textDark,
              ),
            ),
            const SizedBox(height: BeautyCitaTheme.spaceSM),
            Text(
              serviceName,
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: BeautyCitaTheme.textLight,
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
    return Scaffold(
      backgroundColor: BeautyCitaTheme.surfaceCream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: BeautyCitaTheme.textDark),
          onPressed: onRetry,
        ),
      ),
      body: Center(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: BeautyCitaTheme.spaceLG),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: BeautyCitaTheme.primaryRose,
              ),
              const SizedBox(height: BeautyCitaTheme.spaceLG),
              Text(
                'No pudimos encontrar resultados',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: BeautyCitaTheme.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: BeautyCitaTheme.spaceSM),
              Text(
                error,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: BeautyCitaTheme.textLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: BeautyCitaTheme.spaceXL),
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
