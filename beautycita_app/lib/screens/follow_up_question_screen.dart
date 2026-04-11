import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/constants.dart';
import '../models/follow_up_question.dart';
import '../providers/booking_flow_provider.dart';
import '../widgets/booking_flow_background.dart';
import '../widgets/cinematic_question_text.dart';
import '../widgets/parallax_tilt.dart';

class FollowUpQuestionScreen extends ConsumerWidget {
  const FollowUpQuestionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookingFlowProvider);
    final notifier = ref.read(bookingFlowProvider.notifier);
    final question = state.currentQuestion;

    if (question == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final categoryId =
        categoryIdFromServiceType(state.serviceType ?? '') ?? 'nails';
    // Derive accent color from category palette or use primary
    final palette = Theme.of(context).colorScheme;

    final progress = state.followUpQuestions.length > 1
        ? '${state.currentQuestionIndex + 1}/${state.followUpQuestions.length}'
        : null;

    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: BookingFlowBackground(
        categoryId: categoryId,
        accentColor: palette.primary,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top bar: back + progress ──
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 24),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                      ),
                      onPressed: () => notifier.goBack(),
                    ),
                    const Spacer(),
                    if (progress != null)
                      Text(
                        progress,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),

              // ── Progress bar ──
              if (state.followUpQuestions.length > 1)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.paddingLG, vertical: 8),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0,
                      end: (state.currentQuestionIndex + 1) /
                          state.followUpQuestions.length,
                    ),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    builder: (context, value, _) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(1.5),
                        child: LinearProgressIndicator(
                          value: value,
                          minHeight: 3,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.08),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white),
                        ),
                      );
                    },
                  ),
                ),

              // ── Question text (upper-middle) ──
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.paddingLG,
                  vertical: AppConstants.paddingMD,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, animation) {
                    final slideIn = Tween<Offset>(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: slideIn,
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(question.questionKey),
                    child: CinematicQuestionText(
                      text: question.questionTextEs,
                      fontSize: 26,
                      primaryColor: Colors.white,
                      accentColor: Colors.white70,
                    ),
                  ),
                ),
              ),

              // ── Spacer to push options into bottom zone ──
              SizedBox(height: mq.size.height * 0.05),

              // ── Options/answers in bottom ~55% ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.paddingLG,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, animation) {
                      final slideIn = Tween<Offset>(
                        begin: const Offset(0.04, 0),
                        end: Offset.zero,
                      ).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: slideIn,
                          child: child,
                        ),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey('answers_${question.questionKey}'),
                      child: _buildAnswerWidget(question, notifier),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerWidget(
      FollowUpQuestion question, BookingFlowNotifier notifier) {
    switch (question.answerType) {
      case 'visual_cards':
        return _VisualCardsAnswer(
          options: question.options ?? [],
          onSelect: (value) =>
              notifier.answerFollowUp(question.questionKey, value),
        );
      case 'yes_no':
        return _YesNoAnswer(
          onSelect: (value) =>
              notifier.answerFollowUp(question.questionKey, value),
        );
      case 'date_picker':
        return _DatePickerAnswer(
          onSelect: (value) =>
              notifier.answerFollowUp(question.questionKey, value),
        );
      default:
        return const Center(child: Text('Tipo de pregunta desconocido'));
    }
  }
}

class _VisualCardsAnswer extends StatelessWidget {
  final List<FollowUpOption> options;
  final void Function(String value) onSelect;

  const _VisualCardsAnswer({
    required this.options,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = options.length <= 3 ? options.length : 2;

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: AppConstants.paddingMD,
        mainAxisSpacing: AppConstants.paddingMD,
        childAspectRatio: 1.0,
      ),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final option = options[index];
        return ParallaxTilt(
          intensity: 8,
          perspectiveScale: 0.02,
          child: _OptionCard(
            label: option.labelEs,
            imageUrl: option.imageUrl,
            onTap: () => onSelect(option.value),
          ),
        );
      },
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final VoidCallback onTap;

  const _OptionCard({
    required this.label,
    this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingMD,
              vertical: AppConstants.paddingSM,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.3,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

class _YesNoAnswer extends StatelessWidget {
  final void Function(String value) onSelect;

  const _YesNoAnswer({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: AppConstants.paddingXL),
        Row(
          children: [
            Expanded(
              child: _BigButton(
                label: 'Si',
                icon: Icons.check_circle_outline,
                onTap: () => onSelect('yes'),
              ),
            ),
            const SizedBox(width: AppConstants.paddingMD),
            Expanded(
              child: _BigButton(
                label: 'No',
                icon: Icons.cancel_outlined,
                onTap: () => onSelect('no'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BigButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _BigButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.white),
            const SizedBox(height: AppConstants.paddingSM),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DatePickerAnswer extends StatelessWidget {
  final void Function(String value) onSelect;

  const _DatePickerAnswer({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    // Show date picker immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showPicker(context);
    });

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today, size: 48, color: Colors.white),
          const SizedBox(height: AppConstants.paddingMD),
          Text(
            'Selecciona una fecha',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: AppConstants.paddingLG),
          ElevatedButton(
            onPressed: () => _showPicker(context),
            child: const Text('Elegir fecha'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPicker(BuildContext context) async {
    final palette = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 14)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('es', 'MX'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: palette.primary,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && context.mounted) {
      onSelect(picked.toIso8601String().substring(0, 10));
    }
  }
}
