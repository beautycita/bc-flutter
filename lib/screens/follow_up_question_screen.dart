import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../models/follow_up_question.dart';
import '../providers/booking_flow_provider.dart';

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

    final progress = state.followUpQuestions.length > 1
        ? '${state.currentQuestionIndex + 1}/${state.followUpQuestions.length}'
        : null;

    return Scaffold(
      backgroundColor: BeautyCitaTheme.surfaceCream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: BeautyCitaTheme.textDark),
          onPressed: () => notifier.goBack(),
        ),
        actions: [
          if (progress != null)
            Center(
              child: Padding(
                padding:
                    const EdgeInsets.only(right: BeautyCitaTheme.spaceMD),
                child: Text(
                  progress,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: BeautyCitaTheme.textLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BeautyCitaTheme.spaceLG,
            vertical: BeautyCitaTheme.spaceMD,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                question.questionTextEs,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: BeautyCitaTheme.textDark,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: BeautyCitaTheme.spaceXL),
              Expanded(
                child: _buildAnswerWidget(question, notifier),
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
        crossAxisSpacing: BeautyCitaTheme.spaceMD,
        mainAxisSpacing: BeautyCitaTheme.spaceMD,
        childAspectRatio: 1.0,
      ),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final option = options[index];
        return _OptionCard(
          label: option.labelEs,
          imageUrl: option.imageUrl,
          onTap: () => onSelect(option.value),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
          boxShadow: [
            BoxShadow(
              color: BeautyCitaTheme.primaryRose.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (imageUrl != null) ...[
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(BeautyCitaTheme.radiusSmall),
                child: Image.network(
                  imageUrl!,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder(),
                ),
              ),
              const SizedBox(height: BeautyCitaTheme.spaceSM),
            ] else ...[
              _placeholder(),
              const SizedBox(height: BeautyCitaTheme.spaceSM),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: BeautyCitaTheme.spaceSM),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: BeautyCitaTheme.textDark,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: BeautyCitaTheme.primaryRose.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.auto_awesome,
        color: BeautyCitaTheme.primaryRose,
        size: 28,
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
        const SizedBox(height: BeautyCitaTheme.spaceXL),
        Row(
          children: [
            Expanded(
              child: _BigButton(
                label: 'Sí',
                icon: Icons.check_circle_outline,
                onTap: () => onSelect('yes'),
              ),
            ),
            const SizedBox(width: BeautyCitaTheme.spaceMD),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
          boxShadow: [
            BoxShadow(
              color: BeautyCitaTheme.primaryRose.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: BeautyCitaTheme.primaryRose),
            const SizedBox(height: BeautyCitaTheme.spaceSM),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: BeautyCitaTheme.textDark,
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
          const Icon(Icons.calendar_today,
              size: 48, color: BeautyCitaTheme.primaryRose),
          const SizedBox(height: BeautyCitaTheme.spaceMD),
          Text(
            'Selecciona una fecha',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: BeautyCitaTheme.textLight,
            ),
          ),
          const SizedBox(height: BeautyCitaTheme.spaceLG),
          ElevatedButton(
            onPressed: () => _showPicker(context),
            child: const Text('Elegir fecha'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPicker(BuildContext context) async {
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
                  primary: BeautyCitaTheme.primaryRose,
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
