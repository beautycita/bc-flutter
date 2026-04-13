import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/constants.dart';
import '../models/follow_up_question.dart';
import '../providers/booking_flow_provider.dart';
import '../widgets/booking_flow_background.dart';
import '../widgets/cinematic_question_text.dart';


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

              // ── Spacer: push chips to bottom (thumb-reachable) ──
              const Spacer(),

              // ── Bottom zone: chips (thumb-reachable, bottom 55%) ──
              SizedBox(
                height: mq.size.height * 0.55,
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
    if (options.isEmpty) {
      return Center(
        child: Text(
          'Sin opciones disponibles',
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 24),
      children: options.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _OptionCard(
            label: option.labelEs,
            value: option.value,
            onTap: () => onSelect(option.value),
          )
              .animate()
              .fadeIn(duration: 350.ms, delay: (80 * index).ms)
              .slideX(
                begin: 0.08,
                end: 0,
                duration: 350.ms,
                delay: (80 * index).ms,
                curve: Curves.easeOutCubic,
              ),
        );
      }).toList(),
    );
  }
}

/// Full-width glass card for follow-up question options.
/// Renders as a proper visual card (not a tiny chip) with icon + label.
class _OptionCard extends StatefulWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _OptionCard({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  State<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<_OptionCard> {
  bool _isPressed = false;

  static const _optionIcons = <String, IconData>{
    // Lash styles
    'natural': Icons.spa,
    'dramatico': Icons.auto_awesome,
    'extremo': Icons.whatshot,
    'mega_volumen': Icons.layers,
    'gatita': Icons.visibility,
    'hollywood': Icons.star_rounded,
    'muneca': Icons.face_retouching_natural,
    // Body zones
    'piernas_completas': Icons.accessibility_new_rounded,
    'media_pierna': Icons.airline_seat_legroom_normal_rounded,
    'axilas': Icons.back_hand,
    'bikini': Icons.water_drop,
    'brazos': Icons.fitness_center,
    'espalda': Icons.accessibility,
    'facial': Icons.face,
    'cuerpo_completo': Icons.person_rounded,
    // Correction types
    'cubrir_canas': Icons.color_lens,
    'corregir_tono': Icons.tune,
    'cambio_radical': Icons.auto_fix_high,
    // Event types
    'boda': Icons.favorite_rounded,
    'xv_anos': Icons.cake,
    'graduacion': Icons.school,
    'cena': Icons.restaurant,
    'otro': Icons.celebration,
    // Editorial types
    'moda': Icons.checkroom,
    'beauty': Icons.face_retouching_natural,
    'artistico': Icons.palette,
    // Location
    'en_salon': Icons.storefront,
    'a_domicilio': Icons.home,
    // Lip effects
    'definido': Icons.edit,
    'rubor': Icons.gradient,
    // Model count
    '1': Icons.person,
    '2_3': Icons.group,
    '4_plus': Icons.groups,
  };

  @override
  Widget build(BuildContext context) {
    final icon = _optionIcons[widget.value] ?? Icons.auto_awesome;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: _isPressed ? Curves.easeIn : Curves.elasticOut,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _isPressed
                  ? [
                      Colors.white.withValues(alpha: 0.28),
                      Colors.white.withValues(alpha: 0.18),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.16),
                      Colors.white.withValues(alpha: 0.08),
                    ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Icon(icon, size: 22, color: Colors.white.withValues(alpha: 0.9)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  widget.label,
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.4),
                size: 22,
              ),
            ],
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

class _BigButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _BigButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_BigButton> createState() => _BigButtonState();
}

class _BigButtonState extends State<_BigButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 250),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn, reverseCurve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.5),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                palette.primary.withValues(alpha: 0.18),
                Colors.white.withValues(alpha: 0.04),
              ],
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.20), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Icon(widget.icon, size: 26, color: Colors.white.withValues(alpha: 0.9)),
              ),
              const SizedBox(height: AppConstants.paddingSM),
              Text(
                widget.label,
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ],
          ),
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
