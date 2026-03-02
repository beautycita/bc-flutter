import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:beautycita_core/models.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:beautycita_core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OtpType;
import 'package:url_launcher/url_launcher.dart';

import '../../config/breakpoints.dart';
import '../../data/categories.dart';
import '../../providers/booking_flow_provider.dart';
import '../../providers/curate_provider.dart';
import '../../providers/payment_provider.dart';
import '../../services/stripe_web.dart';

// ── Main page ────────────────────────────────────────────────────────────────

class ReservarPage extends ConsumerWidget {
  const ReservarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flowState = ref.watch(bookingFlowProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        // Mobile: single column with optional sticky bottom bar
        if (WebBreakpoints.isMobile(width)) {
          return Stack(
            children: [
              _ActiveStep(flowState: flowState, width: width),
              if (flowState.step != BookingStep.category)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _StickyBottomBar(flowState: flowState),
                ),
            ],
          );
        }

        // Tablet: 55/45 split
        if (WebBreakpoints.isTablet(width)) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 55,
                child: _ActiveStep(flowState: flowState, width: width),
              ),
              Expanded(
                flex: 45,
                child: _SummarySidebar(flowState: flowState),
              ),
            ],
          );
        }

        // Desktop: 60/40 split
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: _ActiveStep(flowState: flowState, width: width),
            ),
            Expanded(
              flex: 4,
              child: _SummarySidebar(flowState: flowState),
            ),
          ],
        );
      },
    );
  }
}

// ── Active step switcher ─────────────────────────────────────────────────────

class _ActiveStep extends ConsumerWidget {
  const _ActiveStep({required this.flowState, required this.width});

  final BookingFlowState flowState;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showBack = flowState.step != BookingStep.category;
    final horizontalPadding =
        WebBreakpoints.isMobile(width) ? BCSpacing.md : BCSpacing.lg;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: horizontalPadding,
        right: horizontalPadding,
        top: BCSpacing.lg,
        // Extra bottom padding on mobile when sticky bar is visible
        bottom: WebBreakpoints.isMobile(width) && showBack ? 88 : BCSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showBack)
            Padding(
              padding: const EdgeInsets.only(bottom: BCSpacing.sm),
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () =>
                    ref.read(bookingFlowProvider.notifier).goBack(),
                tooltip: 'Regresar',
              ),
            ),
          _buildStep(context),
        ],
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (flowState.step) {
      case BookingStep.category:
        return _CategoryGrid(width: width);
      case BookingStep.service:
        return _ServiceSelection(
          category: flowState.selectedCategory!,
          width: width,
        );
      case BookingStep.followUp:
        return _FollowUpStep(width: width);
      case BookingStep.results:
        return _ResultsStep(width: width);
      case BookingStep.payment:
        return _PaymentStep(width: width);
      case BookingStep.transport:
        return _TransportStep(width: width);
      case BookingStep.confirmed:
        return _ConfirmationView(width: width);
    }
  }
}

// ── Category grid ────────────────────────────────────────────────────────────

class _CategoryGrid extends ConsumerWidget {
  const _CategoryGrid({required this.width});

  final double width;

  int _crossAxisCount() {
    if (WebBreakpoints.isDesktop(width)) return 4;
    if (WebBreakpoints.isTablet(width)) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '\u00bfQu\u00e9 servicio buscas?',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: BCSpacing.lg),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: allCategories.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _crossAxisCount(),
            mainAxisSpacing: BCSpacing.md,
            crossAxisSpacing: BCSpacing.md,
            childAspectRatio: 1.0,
          ),
          itemBuilder: (context, index) {
            final category = allCategories[index];
            return _CategoryCard(
              category: category,
              onTap: () => ref
                  .read(bookingFlowProvider.notifier)
                  .selectCategory(category),
            );
          },
        ),
      ],
    );
  }
}

// ── Category card ────────────────────────────────────────────────────────────

class _CategoryCard extends StatefulWidget {
  const _CategoryCard({required this.category, required this.onTap});

  final ServiceCategory category;
  final VoidCallback onTap;

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        child: Card(
          elevation: _hovering ? BCSpacing.elevationMedium : BCSpacing.elevationLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BCSpacing.radiusMd),
          ),
          color: widget.category.color.withValues(alpha: 0.1),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(BCSpacing.radiusMd),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.category.icon,
                  style: const TextStyle(fontSize: 40),
                ),
                const SizedBox(height: BCSpacing.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: BCSpacing.sm,
                  ),
                  child: Text(
                    widget.category.nameEs,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Service selection (subcategory chips + service items) ────────────────────

class _ServiceSelection extends ConsumerStatefulWidget {
  const _ServiceSelection({required this.category, required this.width});

  final ServiceCategory category;
  final double width;

  @override
  ConsumerState<_ServiceSelection> createState() => _ServiceSelectionState();
}

class _ServiceSelectionState extends ConsumerState<_ServiceSelection> {
  int _selectedSubIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subs = widget.category.subcategories;
    final selectedSub = subs[_selectedSubIndex];
    final hasItems = selectedSub.items != null && selectedSub.items!.isNotEmpty;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Column(
        key: ValueKey('service_selection_${widget.category.id}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: emoji + category name ──
          Text(
            '${widget.category.icon} ${widget.category.nameEs}',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: BCSpacing.lg),

          // ── Subcategory chips ──
          Wrap(
            spacing: BCSpacing.sm,
            runSpacing: BCSpacing.sm,
            children: [
              for (int i = 0; i < subs.length; i++)
                ChoiceChip(
                  label: Text(subs[i].nameEs),
                  selected: i == _selectedSubIndex,
                  selectedColor:
                      widget.category.color.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: i == _selectedSubIndex
                        ? widget.category.color
                        : theme.colorScheme.onSurface,
                    fontWeight: i == _selectedSubIndex
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                  side: BorderSide(
                    color: i == _selectedSubIndex
                        ? widget.category.color
                        : theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(BCSpacing.radiusFull),
                  ),
                  onSelected: (selected) {
                    if (!selected) return;
                    final tappedSub = subs[i];
                    final tappedHasItems = tappedSub.items != null &&
                        tappedSub.items!.isNotEmpty;

                    if (!tappedHasItems) {
                      // Leaf subcategory — act as direct service selection
                      ref
                          .read(bookingFlowProvider.notifier)
                          .selectService(
                            tappedSub,
                            ServiceItem(
                              id: tappedSub.id,
                              subcategoryId: tappedSub.id,
                              nameEs: tappedSub.nameEs,
                              serviceType: tappedSub.id,
                            ),
                          );
                    } else {
                      setState(() => _selectedSubIndex = i);
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: BCSpacing.lg),

          // ── Service items list (only if selected sub has items) ──
          if (hasItems)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: selectedSub.items!.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 48),
              itemBuilder: (context, index) {
                final item = selectedSub.items![index];
                return ListTile(
                  leading: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: widget.category.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(
                    item.nameEs,
                    style: theme.textTheme.bodyLarge,
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.4),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: BCSpacing.sm,
                    vertical: BCSpacing.xs,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(BCSpacing.radiusXs),
                  ),
                  onTap: () => ref
                      .read(bookingFlowProvider.notifier)
                      .selectService(selectedSub, item),
                );
              },
            ),

          // ── Hint for leaf subcategories ──
          if (!hasItems)
            Padding(
              padding: const EdgeInsets.only(top: BCSpacing.md),
              child: Text(
                'Toca "${selectedSub.nameEs}" para continuar',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface
                      .withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Follow-up questions step ─────────────────────────────────────────────────

class _FollowUpStep extends ConsumerStatefulWidget {
  const _FollowUpStep({required this.width});

  final double width;

  @override
  ConsumerState<_FollowUpStep> createState() => _FollowUpStepState();
}

class _FollowUpStepState extends ConsumerState<_FollowUpStep> {
  List<FollowUpQuestion>? _questions;
  bool _loading = true;
  String? _error;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    final flowState = ref.read(bookingFlowProvider);
    final serviceType = flowState.selectedService?.serviceType;
    if (serviceType == null) {
      _skipToResults();
      return;
    }

    try {
      // Check if this service type has follow-up questions
      final profile = await BCSupabase.client
          .from('service_profiles')
          .select('max_follow_up_questions')
          .eq('service_type', serviceType)
          .maybeSingle();

      final maxQuestions =
          profile?['max_follow_up_questions'] as int? ?? 0;

      if (maxQuestions == 0) {
        _skipToResults();
        return;
      }

      // Fetch the actual questions
      final rows = await BCSupabase.client
          .from('follow_up_questions')
          .select()
          .eq('service_type', serviceType)
          .order('question_order');

      final parsed = (rows as List<dynamic>)
          .map((r) =>
              FollowUpQuestion.fromJson(r as Map<String, dynamic>))
          .toList();

      if (parsed.isEmpty) {
        _skipToResults();
        return;
      }

      if (!mounted) return;
      setState(() {
        _questions = parsed;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _skipToResults() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(bookingFlowProvider.notifier).skipFollowUps();
      }
    });
  }

  bool get _allRequiredAnswered {
    if (_questions == null) return false;
    final answers = ref.read(bookingFlowProvider).followUpAnswers;
    return _questions!.every(
        (q) => !q.isRequired || answers.containsKey(q.questionKey));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Watch to re-render when answers change
    final flowState = ref.watch(bookingFlowProvider);

    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: BCSpacing.xxl),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: BCSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: BCSpacing.iconXl,
                  color: theme.colorScheme.error),
              const SizedBox(height: BCSpacing.md),
              Text(
                'Error cargando preguntas',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: BCSpacing.sm),
              TextButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _fetchQuestions();
                },
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final questions = _questions!;
    final current = questions[_currentIndex];
    final answers = flowState.followUpAnswers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Progress indicator ──
        Text(
          'Pregunta ${_currentIndex + 1} de ${questions.length}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: BCSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
          child: LinearProgressIndicator(
            value: (_currentIndex + 1) / questions.length,
            minHeight: 4,
          ),
        ),
        const SizedBox(height: BCSpacing.lg),

        // ── Question text ──
        Text(
          current.questionTextEs,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: BCSpacing.lg),

        // ── Answer input (varies by type) ──
        _buildAnswerInput(current, answers, theme),
        const SizedBox(height: BCSpacing.xl),

        // ── Navigation buttons ──
        Row(
          children: [
            if (_currentIndex > 0)
              OutlinedButton(
                onPressed: () => setState(() => _currentIndex--),
                child: const Text('Anterior'),
              ),
            const Spacer(),
            if (_currentIndex < questions.length - 1)
              FilledButton(
                onPressed: answers.containsKey(current.questionKey)
                    ? () => setState(() => _currentIndex++)
                    : null,
                child: const Text('Siguiente'),
              ),
            if (_currentIndex == questions.length - 1)
              FilledButton(
                onPressed: _allRequiredAnswered
                    ? () => ref
                        .read(bookingFlowProvider.notifier)
                        .submitFollowUps()
                    : null,
                child: const Text('Continuar'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnswerInput(
    FollowUpQuestion question,
    Map<String, String> answers,
    ThemeData theme,
  ) {
    switch (question.answerType) {
      case 'visual_cards':
        return _buildVisualCards(question, answers, theme);
      case 'yes_no':
        return _buildYesNo(question, answers, theme);
      case 'date_picker':
        return _buildDatePicker(question, answers, theme);
      default:
        return Text('Tipo de pregunta desconocido: ${question.answerType}');
    }
  }

  Widget _buildVisualCards(
    FollowUpQuestion question,
    Map<String, String> answers,
    ThemeData theme,
  ) {
    final options = question.options ?? [];
    if (options.isEmpty) {
      return const Text('Sin opciones disponibles.');
    }
    final selected = answers[question.questionKey];
    final crossAxisCount = WebBreakpoints.isDesktop(widget.width) ? 4 : 2;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: options.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: BCSpacing.md,
        crossAxisSpacing: BCSpacing.md,
        childAspectRatio: 0.9,
      ),
      itemBuilder: (context, index) {
        final option = options[index];
        final isSelected = selected == option.value;
        return _VisualOptionCard(
          option: option,
          isSelected: isSelected,
          onTap: () {
            ref
                .read(bookingFlowProvider.notifier)
                .answerFollowUp(question.questionKey, option.value);
          },
        );
      },
    );
  }

  Widget _buildYesNo(
    FollowUpQuestion question,
    Map<String, String> answers,
    ThemeData theme,
  ) {
    final selected = answers[question.questionKey];
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: BCSpacing.largeTouchHeight,
            child: selected == 'yes'
                ? FilledButton(
                    onPressed: () => ref
                        .read(bookingFlowProvider.notifier)
                        .answerFollowUp(question.questionKey, 'yes'),
                    child: const Text('S\u00ed',
                        style: TextStyle(fontSize: 18)),
                  )
                : OutlinedButton(
                    onPressed: () => ref
                        .read(bookingFlowProvider.notifier)
                        .answerFollowUp(question.questionKey, 'yes'),
                    child: const Text('S\u00ed',
                        style: TextStyle(fontSize: 18)),
                  ),
          ),
        ),
        const SizedBox(width: BCSpacing.md),
        Expanded(
          child: SizedBox(
            height: BCSpacing.largeTouchHeight,
            child: selected == 'no'
                ? FilledButton(
                    onPressed: () => ref
                        .read(bookingFlowProvider.notifier)
                        .answerFollowUp(question.questionKey, 'no'),
                    child: const Text('No',
                        style: TextStyle(fontSize: 18)),
                  )
                : OutlinedButton(
                    onPressed: () => ref
                        .read(bookingFlowProvider.notifier)
                        .answerFollowUp(question.questionKey, 'no'),
                    child: const Text('No',
                        style: TextStyle(fontSize: 18)),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker(
    FollowUpQuestion question,
    Map<String, String> answers,
    ThemeData theme,
  ) {
    final selected = answers[question.questionKey];
    final hasDate = selected != null && selected.isNotEmpty;
    return SizedBox(
      height: BCSpacing.largeTouchHeight,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: now.add(const Duration(days: 1)),
            firstDate: now,
            lastDate: now.add(const Duration(days: 365)),
            locale: const Locale('es', 'MX'),
          );
          if (picked != null) {
            final formatted =
                '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
            ref
                .read(bookingFlowProvider.notifier)
                .answerFollowUp(question.questionKey, formatted);
          }
        },
        icon: const Icon(Icons.calendar_today),
        label: Text(
          hasDate ? selected : 'Seleccionar fecha',
          style: TextStyle(
            fontSize: 16,
            fontWeight: hasDate ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ── Visual option card ──────────────────────────────────────────────────────

class _VisualOptionCard extends StatefulWidget {
  const _VisualOptionCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final FollowUpOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_VisualOptionCard> createState() => _VisualOptionCardState();
}

class _VisualOptionCardState extends State<_VisualOptionCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        child: Card(
          elevation: _hovering
              ? BCSpacing.elevationMedium
              : BCSpacing.elevationLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BCSpacing.radiusMd),
            side: widget.isSelected
                ? BorderSide(
                    color: theme.colorScheme.primary,
                    width: 2.5,
                  )
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(BCSpacing.radiusMd),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.option.imageUrl != null) ...[
                  Expanded(
                    flex: 3,
                    child: Image.network(
                      widget.option.imageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.image_not_supported_outlined,
                        size: BCSpacing.iconLg,
                      ),
                    ),
                  ),
                  const SizedBox(height: BCSpacing.sm),
                ],
                Expanded(
                  flex: widget.option.imageUrl != null ? 1 : 2,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: BCSpacing.sm,
                      ),
                      child: Text(
                        widget.option.labelEs,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: widget.isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: widget.isSelected
                              ? theme.colorScheme.primary
                              : null,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Results step (curate engine call + result cards) ─────────────────────────

class _ResultsStep extends ConsumerStatefulWidget {
  const _ResultsStep({required this.width});

  final double width;

  @override
  ConsumerState<_ResultsStep> createState() => _ResultsStepState();
}

class _ResultsStepState extends ConsumerState<_ResultsStep> {
  bool _callTriggered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerEngineCallIfNeeded();
    });
  }

  void _triggerEngineCallIfNeeded() {
    if (_callTriggered) return;
    final flowState = ref.read(bookingFlowProvider);
    if (!flowState.isLoading || flowState.curateResponse != null) return;

    // Check location
    if (flowState.userLat == null || flowState.userLng == null) {
      ref.read(bookingFlowProvider.notifier).setError(
        'location_missing',
      );
      return;
    }

    _callTriggered = true;
    _callEngine(flowState);
  }

  Future<void> _callEngine(BookingFlowState flowState) async {
    try {
      final response = await callCurateEngine(
        serviceType: flowState.selectedService!.serviceType,
        lat: flowState.userLat!,
        lng: flowState.userLng!,
        followUpAnswers: flowState.followUpAnswers.isNotEmpty
            ? flowState.followUpAnswers
            : null,
        userId: BCSupabase.currentUserId,
      );
      if (!mounted) return;
      ref.read(bookingFlowProvider.notifier).setCurateResponse(response);
    } catch (e) {
      if (!mounted) return;
      ref.read(bookingFlowProvider.notifier).setError(e.toString());
    }
  }

  void _retry() {
    setState(() => _callTriggered = false);
    ref.read(bookingFlowProvider.notifier).setLoading(true);
    ref.read(bookingFlowProvider.notifier).setError(null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerEngineCallIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flowState = ref.watch(bookingFlowProvider);

    // ── Location missing ──
    if (flowState.error == 'location_missing') {
      return _buildLocationMissing(theme);
    }

    // ── Error state ──
    if (flowState.error != null && flowState.error != 'location_missing') {
      return _buildError(theme, flowState.error!);
    }

    // ── Loading state ──
    if (flowState.isLoading || flowState.curateResponse == null) {
      return _buildLoadingSkeleton(theme);
    }

    final response = flowState.curateResponse!;

    // ── Discovered salons view (empty results fallback OR user tapped "Ver más") ──
    if (flowState.showingDiscovered) {
      return _DiscoveredSalonsList(
        hasResults: response.results.isNotEmpty,
      );
    }

    // ── Results display ──
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mejores opciones para ti',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: BCSpacing.lg),
        for (final result in response.results)
          Padding(
            padding: const EdgeInsets.only(bottom: BCSpacing.md),
            child: _ResultCardWidget(
              result: result,
              width: widget.width,
              onReservar: () =>
                  ref.read(bookingFlowProvider.notifier).selectResult(result),
            ),
          ),
        const SizedBox(height: BCSpacing.sm),
        Center(
          child: TextButton(
            onPressed: () =>
                ref.read(bookingFlowProvider.notifier).showDiscovered(),
            child: Text(
              'Ver mas salones cerca de ti',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationMissing(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: BCSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off,
                size: BCSpacing.iconXl,
                color: theme.colorScheme.error.withValues(alpha: 0.7)),
            const SizedBox(height: BCSpacing.md),
            Text(
              'Necesitamos tu ubicacion para encontrar salones cercanos',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: BCSpacing.lg),
            FilledButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.my_location),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(ThemeData theme, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: BCSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: BCSpacing.iconXl, color: theme.colorScheme.error),
            const SizedBox(height: BCSpacing.md),
            Text(
              'Error buscando salones',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: BCSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: BCSpacing.xl),
              child: Text(
                error,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: BCSpacing.lg),
            FilledButton(
              onPressed: _retry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Buscando las mejores opciones...',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: BCSpacing.lg),
        for (int i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: BCSpacing.md),
            child: _SkeletonCard(),
          ),
      ],
    );
  }
}

// ── Skeleton card (loading placeholder) ──────────────────────────────────────

class _SkeletonCard extends StatefulWidget {
  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.08, end: 0.18).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final opacity = _animation.value;
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BCSpacing.radiusMd),
          ),
          child: Padding(
            padding: const EdgeInsets.all(BCSpacing.md),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Photo placeholder
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: opacity),
                        borderRadius:
                            BorderRadius.circular(BCSpacing.radiusSm),
                      ),
                    ),
                    const SizedBox(width: BCSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name placeholder
                          Container(
                            height: 20,
                            width: 180,
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: opacity),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: BCSpacing.sm),
                          // Rating placeholder
                          Container(
                            height: 16,
                            width: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: opacity),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: BCSpacing.sm),
                          // Service placeholder
                          Container(
                            height: 16,
                            width: 150,
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: opacity),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: BCSpacing.sm),
                          // Slot placeholder
                          Container(
                            height: 16,
                            width: 200,
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: opacity),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: BCSpacing.md),
                // Button placeholder
                Container(
                  height: BCSpacing.minTouchHeight,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: opacity),
                    borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Result card ──────────────────────────────────────────────────────────────

class _ResultCardWidget extends StatefulWidget {
  const _ResultCardWidget({
    required this.result,
    required this.width,
    required this.onReservar,
  });

  final ResultCard result;
  final double width;
  final VoidCallback onReservar;

  @override
  State<_ResultCardWidget> createState() => _ResultCardWidgetState();
}

class _ResultCardWidgetState extends State<_ResultCardWidget> {
  bool _hovering = false;

  static const _goldColor = Color(0xFFFFB300);

  String _formatSlotDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      // Format: "mar 4, 2:00 PM" style in Spanish
      final dayFormat = DateFormat('MMM d', 'es');
      final timeFormat = DateFormat('h:mm a', 'es');
      return '${dayFormat.format(dt)}, ${timeFormat.format(dt)}';
    } catch (_) {
      return isoString;
    }
  }

  String _formatPrice(double price, String currency) {
    if (currency.toUpperCase() == 'MXN') {
      return '\$${price.toStringAsFixed(0)} MXN';
    }
    return '\$${price.toStringAsFixed(0)} $currency';
  }

  String _formatDaysAgo(int days) {
    if (days == 0) return 'hoy';
    if (days == 1) return 'hace 1 dia';
    return 'hace $days dias';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = widget.result;
    final isMobile = WebBreakpoints.isMobile(widget.width);
    final photoSize = isMobile ? 90.0 : 120.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        child: Card(
          elevation: _hovering
              ? BCSpacing.elevationMedium
              : BCSpacing.elevationLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BCSpacing.radiusMd),
          ),
          child: Padding(
            padding: const EdgeInsets.all(BCSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top row: photo + details ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Salon photo
                    _buildPhoto(result.business, photoSize, theme),
                    const SizedBox(width: BCSpacing.md),
                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Salon name + rating row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  result.business.name,
                                  style:
                                      theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: BCSpacing.sm),
                              _buildRating(result.staff, theme),
                            ],
                          ),
                          const SizedBox(height: BCSpacing.xs),

                          // Stylist
                          _buildInfoRow(
                            Icons.person_outline,
                            _buildStylistText(result.staff),
                            theme,
                          ),
                          const SizedBox(height: BCSpacing.xs),

                          // Service
                          _buildInfoRow(
                            Icons.content_cut,
                            result.service.name,
                            theme,
                          ),
                          const SizedBox(height: BCSpacing.xs),

                          // Slot + duration
                          _buildInfoRow(
                            Icons.calendar_today_outlined,
                            '${_formatSlotDate(result.slot.startsAt)} \u00b7 ${result.service.durationMinutes} min',
                            theme,
                          ),
                          const SizedBox(height: BCSpacing.xs),

                          // Travel
                          _buildInfoRow(
                            Icons.directions_car_outlined,
                            '${result.transport.durationMin} min \u00b7 ${result.transport.distanceKm.toStringAsFixed(1)} km',
                            theme,
                          ),
                          const SizedBox(height: BCSpacing.sm),

                          // Price
                          Text(
                            _formatPrice(
                              result.service.price,
                              result.service.currency,
                            ),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // ── Review snippet ──
                if (result.reviewSnippet != null &&
                    !result.reviewSnippet!.isFallback) ...[
                  const Divider(height: BCSpacing.lg),
                  _buildReviewSnippet(result.reviewSnippet!, theme),
                ],

                const SizedBox(height: BCSpacing.md),

                // ── RESERVAR button ──
                SizedBox(
                  width: double.infinity,
                  height: BCSpacing.minTouchHeight,
                  child: FilledButton(
                    onPressed: widget.onReservar,
                    child: const Text(
                      'RESERVAR',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoto(
      BusinessInfo business, double size, ThemeData theme) {
    if (business.photoUrl != null && business.photoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(BCSpacing.radiusSm),
        child: Image.network(
          business.photoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _buildPhotoPlaceholder(size, theme),
        ),
      );
    }
    return _buildPhotoPlaceholder(size, theme);
  }

  Widget _buildPhotoPlaceholder(double size, ThemeData theme) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(BCSpacing.radiusSm),
      ),
      child: Icon(
        Icons.storefront_outlined,
        size: size * 0.4,
        color: theme.colorScheme.primary.withValues(alpha: 0.4),
      ),
    );
  }

  Widget _buildRating(StaffInfo staff, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 18, color: _goldColor),
        const SizedBox(width: 2),
        Text(
          staff.rating.toStringAsFixed(1),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: _goldColor,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          '(${staff.totalReviews})',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  String _buildStylistText(StaffInfo staff) {
    final buffer = StringBuffer(staff.name);
    if (staff.experienceYears != null && staff.experienceYears! > 0) {
      buffer.write(' \u00b7 ${staff.experienceYears} a\u00f1os exp');
    }
    return buffer.toString();
  }

  Widget _buildInfoRow(IconData icon, String text, ThemeData theme) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        const SizedBox(width: BCSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewSnippet(ReviewSnippet snippet, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '\u201c${snippet.text}\u201d',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontStyle: FontStyle.italic,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (snippet.authorName != null || snippet.daysAgo != null) ...[
          const SizedBox(height: BCSpacing.xs),
          Text(
            [
              if (snippet.authorName != null) '\u2014 ${snippet.authorName}',
              if (snippet.daysAgo != null)
                _formatDaysAgo(snippet.daysAgo!),
            ].join(', '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Discovered salons list (WhatsApp-style invite) ───────────────────────────

class _DiscoveredSalonsList extends ConsumerStatefulWidget {
  const _DiscoveredSalonsList({required this.hasResults});

  /// Whether there are curated results the user can go back to.
  final bool hasResults;

  @override
  ConsumerState<_DiscoveredSalonsList> createState() =>
      _DiscoveredSalonsListState();
}

class _DiscoveredSalonsListState extends ConsumerState<_DiscoveredSalonsList> {
  static const _waGreen = Color(0xFF25D366);

  bool _loading = true;
  String? _error;
  final Set<String> _invitedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchDiscovered());
  }

  Future<void> _fetchDiscovered() async {
    if (!mounted) return;

    final existing = ref.read(bookingFlowProvider).discoveredSalons;
    if (existing.isNotEmpty) {
      setState(() => _loading = false);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await BCSupabase.client
          .from('discovered_salons')
          .select(
              'id, business_name, location_address, phone, whatsapp_verified, categories, feature_image_url, rating_average, rating_count')
          .not('phone', 'is', null)
          .order('rating_count', ascending: false)
          .limit(25);

      if (!mounted) return;

      final salons = (response as List).cast<Map<String, dynamic>>();
      ref.read(bookingFlowProvider.notifier).setDiscoveredSalons(salons);
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _inviteSalon(String salonId) async {
    if (_invitedIds.contains(salonId)) return;

    try {
      await BCSupabase.client.functions.invoke(
        'outreach-discovered-salon',
        body: {
          'salon_id': salonId,
          'invited_by': BCSupabase.client.auth.currentUser?.id,
        },
      );
    } catch (_) {
      // Silently mark as invited even on error — edge function may not exist yet.
    }

    if (!mounted) return;
    setState(() => _invitedIds.add(salonId));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final salons = ref.watch(bookingFlowProvider).discoveredSalons;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Back button (only if curated results exist) ──
        if (widget.hasResults) ...[
          TextButton.icon(
            onPressed: () =>
                ref.read(bookingFlowProvider.notifier).hideDiscovered(),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Volver a resultados'),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: BCSpacing.md),
        ],

        // ── Header ──
        Text(
          'Estos salones aun no estan en BeautyCita',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: BCSpacing.xs),
        Text(
          '\u00a1Invitalos y recibe beneficios!',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const Divider(height: BCSpacing.xl),

        // ── Content ──
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.only(top: BCSpacing.xxl),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_error != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: BCSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      size: BCSpacing.iconXl,
                      color: theme.colorScheme.error),
                  const SizedBox(height: BCSpacing.md),
                  Text(
                    'No se pudieron cargar los salones',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: BCSpacing.md),
                  FilledButton(
                    onPressed: _fetchDiscovered,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          )
        else if (salons.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: BCSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.storefront_outlined,
                      size: BCSpacing.iconXl,
                      color: theme.colorScheme.primary.withValues(alpha: 0.4)),
                  const SizedBox(height: BCSpacing.md),
                  Text(
                    'No encontramos salones descubiertos por ahora',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: salons.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 64),
            itemBuilder: (context, index) =>
                _buildSalonRow(salons[index], theme),
          ),
      ],
    );
  }

  Widget _buildSalonRow(Map<String, dynamic> salon, ThemeData theme) {
    final salonId = salon['id']?.toString() ?? '';
    final name = salon['business_name'] as String? ?? 'Sin nombre';
    final address = salon['location_address'] as String?;
    final imageUrl = salon['feature_image_url'] as String?;
    final waVerified = salon['whatsapp_verified'] as bool? ?? false;
    final ratingAvg = (salon['rating_average'] as num?)?.toDouble();
    final ratingCount = salon['rating_count'] as int? ?? 0;
    final invited = _invitedIds.contains(salonId);

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: BCSpacing.sm,
        horizontal: BCSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Photo / Avatar ──
          _buildAvatar(name, imageUrl, theme),
          const SizedBox(width: BCSpacing.md),

          // ── Info ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + WhatsApp badge
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (waVerified) ...[
                      const SizedBox(width: BCSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _waGreen.withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(BCSpacing.radiusXs),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, size: 12, color: _waGreen),
                            const SizedBox(width: 2),
                            Text(
                              'WhatsApp',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: _waGreen,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),

                // Address
                if (address != null && address.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          size: 14,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          address,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                // Rating
                if (ratingAvg != null && ratingCount > 0) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 14, color: Color(0xFFFFB300)),
                      const SizedBox(width: 2),
                      Text(
                        '${ratingAvg.toStringAsFixed(1)} ($ratingCount rese\u00f1as)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: BCSpacing.sm),

          // ── Invite button ──
          invited
              ? Text(
                  'Invitacion enviada \u2713',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _waGreen,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : OutlinedButton(
                  onPressed: () => _inviteSalon(salonId),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _waGreen,
                    side: const BorderSide(color: _waGreen),
                    padding: const EdgeInsets.symmetric(
                      horizontal: BCSpacing.md,
                      vertical: BCSpacing.xs,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Invitar',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String name, String? imageUrl, ThemeData theme) {
    const size = 48.0;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(imageUrl),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    }

    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

// ── Payment step ─────────────────────────────────────────────────────────────

class _PaymentStep extends ConsumerStatefulWidget {
  const _PaymentStep({required this.width});

  final double width;

  @override
  ConsumerState<_PaymentStep> createState() => _PaymentStepState();
}

class _PaymentStepState extends ConsumerState<_PaymentStep> {
  bool _isAuthenticated = false;
  bool _creatingIntent = false;
  bool _confirmingPayment = false;
  String? _clientSecret;
  String? _paymentIntentId;
  String? _error;
  StripeWeb? _stripe;
  String? _stripeContainerId;
  bool _elementMounted = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  @override
  void dispose() {
    _stripe?.dispose();
    super.dispose();
  }

  void _checkAuth() {
    final user = BCSupabase.client.auth.currentUser;
    _isAuthenticated = user != null;
    if (_isAuthenticated) {
      _initPayment();
    }
  }

  void _onAuthSuccess() {
    if (!mounted) return;
    setState(() {
      _isAuthenticated = true;
    });
    _initPayment();
  }

  Future<void> _initPayment() async {
    if (_clientSecret != null) return; // Already created
    setState(() {
      _creatingIntent = true;
      _error = null;
    });

    try {
      final flowState = ref.read(bookingFlowProvider);
      final result = flowState.selectedResult!;
      final user = BCSupabase.client.auth.currentUser!;

      final intentResult = await createWebPaymentIntent(
        serviceId: result.service.id,
        businessId: result.business.id,
        staffId: result.staff.id,
        scheduledAt: result.slot.startsAt,
        amountCents: (result.service.price * 100).round(),
        userId: user.id,
      );

      if (!mounted) return;

      final clientSecret = intentResult['client_secret'] as String?;
      final paymentIntentId = intentResult['payment_intent_id'] as String? ??
          intentResult['id'] as String?;

      if (clientSecret == null || clientSecret.isEmpty) {
        throw Exception('No se obtuvo client_secret del servidor');
      }

      setState(() {
        _clientSecret = clientSecret;
        _paymentIntentId = paymentIntentId;
        _creatingIntent = false;
      });

      // Mount Stripe element after frame renders
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mountStripeElement();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _creatingIntent = false;
        _error = e.toString();
      });
    }
  }

  void _mountStripeElement() {
    if (_clientSecret == null || _elementMounted) return;

    final stripeKey = dotenv.env['STRIPE_PUBLIC_KEY'] ?? '';
    if (stripeKey.isEmpty) {
      setState(() => _error = 'Stripe key not configured');
      return;
    }

    _stripe = StripeWeb(stripeKey);
    final containerId = _stripeContainerId;
    if (containerId == null) return;

    try {
      _stripe!.mountPaymentElement(_clientSecret!, containerId);
      setState(() => _elementMounted = true);
    } catch (e) {
      setState(() => _error = 'Error montando formulario de pago: $e');
    }
  }

  Future<void> _confirmPayment() async {
    if (_stripe == null || !_elementMounted) return;

    setState(() {
      _confirmingPayment = true;
      _error = null;
    });

    try {
      final returnUrl =
          '${Uri.base.origin}/reservar?payment_status=success';
      final errorMsg = await _stripe!.confirmPayment(returnUrl);

      if (errorMsg != null) {
        if (!mounted) return;
        setState(() {
          _confirmingPayment = false;
          _error = errorMsg;
        });
        return;
      }

      // Payment succeeded — create appointment
      final flowState = ref.read(bookingFlowProvider);
      final result = flowState.selectedResult!;
      final user = BCSupabase.client.auth.currentUser!;

      final appointmentId = await createAppointment(
        userId: user.id,
        businessId: result.business.id,
        staffId: result.staff.id,
        serviceId: result.service.id,
        serviceName: result.service.name,
        serviceType:
            flowState.selectedService?.serviceType ?? result.service.id,
        startsAt: result.slot.startsAt,
        endsAt: result.slot.endsAt,
        price: result.service.price,
        paymentIntentId: _paymentIntentId ?? '',
      );

      if (!mounted) return;
      ref.read(bookingFlowProvider.notifier).setBookingConfirmed(appointmentId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _confirmingPayment = false;
        _error = e.toString();
      });
    }
  }

  String _formatSlotDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      final dayFormat = DateFormat('EEEE d MMMM', 'es');
      final timeFormat = DateFormat('h:mm a', 'es');
      return '${dayFormat.format(dt)}, ${timeFormat.format(dt)}';
    } catch (_) {
      return isoString;
    }
  }

  String _formatPrice(double price, String currency) {
    if (currency.toUpperCase() == 'MXN') {
      return '\$${price.toStringAsFixed(0)} MXN';
    }
    return '\$${price.toStringAsFixed(0)} $currency';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flowState = ref.watch(bookingFlowProvider);
    final result = flowState.selectedResult;

    if (result == null) {
      return const Center(child: Text('Sin resultado seleccionado'));
    }

    final isMobile = WebBreakpoints.isMobile(widget.width);

    // On desktop, show summary and payment side by side
    if (!isMobile) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildBookingSummary(result, theme)),
          const SizedBox(width: BCSpacing.lg),
          Expanded(child: _buildPaymentSection(result, theme)),
        ],
      );
    }

    // On mobile, stack vertically
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBookingSummary(result, theme),
        const Divider(height: BCSpacing.xl),
        _buildPaymentSection(result, theme),
      ],
    );
  }

  Widget _buildBookingSummary(ResultCard result, ThemeData theme) {
    final flowState = ref.read(bookingFlowProvider);
    final category = flowState.selectedCategory;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BCSpacing.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.all(BCSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Resumen de tu cita',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: BCSpacing.lg),

            // Category
            if (category != null)
              _summaryRow(
                icon: Icons.category_outlined,
                label: category.nameEs,
                theme: theme,
              ),

            // Service
            _summaryRow(
              icon: Icons.content_cut,
              label: result.service.name,
              theme: theme,
            ),

            // Salon
            _summaryRow(
              icon: Icons.storefront_outlined,
              label: result.business.name,
              theme: theme,
              subtitle: result.business.address,
            ),

            // Stylist
            _summaryRow(
              icon: Icons.person_outline,
              label: result.staff.name,
              theme: theme,
            ),

            // Date/Time
            _summaryRow(
              icon: Icons.calendar_today_outlined,
              label: _formatSlotDate(result.slot.startsAt),
              theme: theme,
            ),

            // Duration
            _summaryRow(
              icon: Icons.timer_outlined,
              label: '${result.service.durationMinutes} minutos',
              theme: theme,
            ),

            const Divider(height: BCSpacing.xl),

            // Price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _formatPrice(result.service.price, result.service.currency),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow({
    required IconData icon,
    required String label,
    required ThemeData theme,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BCSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(width: BCSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection(ResultCard result, ThemeData theme) {
    if (!_isAuthenticated) {
      return _PhoneVerification(onSuccess: _onAuthSuccess);
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BCSpacing.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.all(BCSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Pago',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: BCSpacing.lg),

            // Error
            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(BCSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(BCSpacing.radiusSm),
                  border: Border.all(
                    color: theme.colorScheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        size: 20, color: theme.colorScheme.error),
                    const SizedBox(width: BCSpacing.sm),
                    Expanded(
                      child: Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: BCSpacing.md),
            ],

            // Loading state while creating PaymentIntent
            if (_creatingIntent) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: BCSpacing.xl),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: BCSpacing.md),
                      Text('Preparando formulario de pago...'),
                    ],
                  ),
                ),
              ),
            ],

            // Stripe Payment Element
            if (_clientSecret != null && !_creatingIntent) ...[
              _StripeElementContainer(
                onContainerReady: (containerId) {
                  _stripeContainerId = containerId;
                  // Mount after a brief delay to ensure DOM is ready
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (mounted) _mountStripeElement();
                  });
                },
              ),
              const SizedBox(height: BCSpacing.lg),
              SizedBox(
                width: double.infinity,
                height: BCSpacing.minTouchHeight,
                child: FilledButton(
                  onPressed:
                      _confirmingPayment || !_elementMounted ? null : _confirmPayment,
                  child: _confirmingPayment
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Confirmar y Pagar \u2014 ${_formatPrice(result.service.price, result.service.currency)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],

            // Retry button on error when no client secret
            if (_error != null && _clientSecret == null && !_creatingIntent) ...[
              const SizedBox(height: BCSpacing.md),
              Center(
                child: FilledButton(
                  onPressed: _initPayment,
                  child: const Text('Reintentar'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Stripe Element Container (HtmlElementView wrapper) ───────────────────────

class _StripeElementContainer extends StatefulWidget {
  const _StripeElementContainer({required this.onContainerReady});

  final ValueChanged<String> onContainerReady;

  @override
  State<_StripeElementContainer> createState() =>
      _StripeElementContainerState();
}

class _StripeElementContainerState extends State<_StripeElementContainer> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    // Unique view type per instance
    _viewType =
        'stripe-payment-element-${DateTime.now().millisecondsSinceEpoch}';
    final containerId = 'payment-element-container';

    // Register the platform view factory
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) {
        final div = html.DivElement();
        div.id = containerId;
        div.style.minHeight = '300px';
        return div;
      },
    );

    // Notify parent of the container ID
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onContainerReady(containerId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 350,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}

// ── Phone verification widget ────────────────────────────────────────────────

class _PhoneVerification extends StatefulWidget {
  const _PhoneVerification({required this.onSuccess});

  final VoidCallback onSuccess;

  @override
  State<_PhoneVerification> createState() => _PhoneVerificationState();
}

class _PhoneVerificationState extends State<_PhoneVerification> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpSent = false;
  bool _loading = false;
  String? _error;
  int _resendCountdown = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  String get _fullPhoneNumber {
    final raw = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    // If user already typed country code, don't double-add
    if (raw.startsWith('52')) return '+$raw';
    return '+52$raw';
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) timer.cancel();
      });
    });
  }

  Future<void> _sendOtp() async {
    final phone = _fullPhoneNumber;
    if (phone.length < 12) {
      setState(() => _error = 'Ingresa un numero valido de 10 digitos');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await BCSupabase.client.auth.signInWithOtp(phone: phone);
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _loading = false;
      });
      _startResendTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Error enviando codigo: $e';
      });
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Ingresa el codigo de 6 digitos');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await BCSupabase.client.auth.verifyOTP(
        phone: _fullPhoneNumber,
        token: code,
        type: OtpType.sms,
      );
      if (!mounted) return;
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Codigo incorrecto o expirado';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BCSpacing.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.all(BCSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.phone_android,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: BCSpacing.sm),
                Text(
                  'Verifica tu numero para continuar',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: BCSpacing.xs),
            Text(
              'Te enviaremos un codigo por SMS',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: BCSpacing.lg),

            // Error
            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(BCSpacing.sm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(BCSpacing.radiusSm),
                ),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
              const SizedBox(height: BCSpacing.md),
            ],

            // Phone input
            if (!_otpSent) ...[
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Numero de celular',
                  prefixText: '+52 ',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  hintText: '33 1234 5678',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(BCSpacing.radiusSm),
                  ),
                ),
                onSubmitted: (_) => _sendOtp(),
              ),
              const SizedBox(height: BCSpacing.lg),
              SizedBox(
                width: double.infinity,
                height: BCSpacing.minTouchHeight,
                child: FilledButton(
                  onPressed: _loading ? null : _sendOtp,
                  child: _loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Enviar codigo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],

            // OTP input
            if (_otpSent) ...[
              Text(
                'Codigo enviado a $_fullPhoneNumber',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: BCSpacing.md),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  labelText: 'Codigo de verificacion',
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(BCSpacing.radiusSm),
                  ),
                ),
                onSubmitted: (_) => _verifyOtp(),
              ),
              const SizedBox(height: BCSpacing.lg),
              SizedBox(
                width: double.infinity,
                height: BCSpacing.minTouchHeight,
                child: FilledButton(
                  onPressed: _loading ? null : _verifyOtp,
                  child: _loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Verificar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: BCSpacing.md),

              // Resend button
              Center(
                child: _resendCountdown > 0
                    ? Text(
                        'Reenviar codigo en ${_resendCountdown}s',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      )
                    : TextButton(
                        onPressed: _loading ? null : _sendOtp,
                        child: Text(
                          'Reenviar codigo',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Transport step ───────────────────────────────────────────────────────────

class _TransportStep extends ConsumerStatefulWidget {
  const _TransportStep({required this.width});

  final double width;

  @override
  ConsumerState<_TransportStep> createState() => _TransportStepState();
}

class _TransportStepState extends ConsumerState<_TransportStep> {
  String? _selected;
  bool _saving = false;

  Future<void> _selectTransport(String mode) async {
    if (_saving) return;

    setState(() {
      _selected = mode;
      _saving = true;
    });

    try {
      final flowState = ref.read(bookingFlowProvider);
      if (flowState.bookingId != null) {
        await BCSupabase.client
            .from('appointments')
            .update({'transport_mode': mode})
            .eq('id', flowState.bookingId!);
      }

      ref.read(bookingFlowProvider.notifier).setTransportMode(mode);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar transporte: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = WebBreakpoints.isMobile(widget.width);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '\u00bfC\u00f3mo llegar\u00e1s?',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: BCSpacing.sm),
        Text(
          'Selecciona tu medio de transporte',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: BCSpacing.lg),
        if (_saving && _selected != null)
          const Padding(
            padding: EdgeInsets.only(bottom: BCSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          ),
        _buildTransportCards(theme, isMobile),
      ],
    );
  }

  Widget _buildTransportCards(ThemeData theme, bool isMobile) {
    final cards = [
      _TransportOption(
        icon: Icons.directions_car,
        label: 'En mi carro',
        mode: 'car',
        selected: _selected == 'car',
        onTap: () => _selectTransport('car'),
        theme: theme,
      ),
      _TransportOption(
        icon: Icons.local_taxi,
        label: 'Uber',
        subtitle: 'Pr\u00f3ximamente: programar viaje autom\u00e1tico',
        mode: 'uber',
        selected: _selected == 'uber',
        onTap: () => _selectTransport('uber'),
        theme: theme,
      ),
      _TransportOption(
        icon: Icons.directions_bus,
        label: 'Transporte P\u00fablico',
        mode: 'transit',
        selected: _selected == 'transit',
        onTap: () => _selectTransport('transit'),
        theme: theme,
      ),
    ];

    if (isMobile) {
      return Column(
        children: cards
            .map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: BCSpacing.md),
                  child: c,
                ))
            .toList(),
      );
    }

    return Row(
      children: cards
          .map((c) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: BCSpacing.sm,
                  ),
                  child: c,
                ),
              ))
          .toList(),
    );
  }
}

class _TransportOption extends StatelessWidget {
  const _TransportOption({
    required this.icon,
    required this.label,
    required this.mode,
    required this.selected,
    required this.onTap,
    required this.theme,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String mode;
  final bool selected;
  final VoidCallback onTap;
  final ThemeData theme;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BCSpacing.radiusMd),
        side: BorderSide(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outline.withValues(alpha: 0.2),
          width: selected ? 2.5 : 1,
        ),
      ),
      elevation: selected ? BCSpacing.elevationMedium : BCSpacing.elevationLow,
      child: InkWell(
        borderRadius: BorderRadius.circular(BCSpacing.radiusMd),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 120),
          padding: const EdgeInsets.all(BCSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(height: BCSpacing.sm),
              Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: BCSpacing.xs),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Confirmation view ────────────────────────────────────────────────────────

class _ConfirmationView extends ConsumerWidget {
  const _ConfirmationView({required this.width});

  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final flowState = ref.watch(bookingFlowProvider);
    final result = flowState.selectedResult;
    final isMobile = WebBreakpoints.isMobile(width);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: BCSpacing.xl),

            // Animated checkmark
            Icon(
              Icons.check_circle,
              size: 80,
              color: const Color(0xFF4CAF50),
            )
                .animate()
                .scale(
                  begin: const Offset(0, 0),
                  end: const Offset(1, 1),
                  duration: 500.ms,
                  curve: Curves.elasticOut,
                )
                .fade(duration: 300.ms),

            const SizedBox(height: BCSpacing.lg),

            Text(
              '\u00a1Reservaci\u00f3n confirmada!',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: BCSpacing.sm),

            // Booking ID
            if (flowState.bookingId != null)
              Text(
                'ID: ${flowState.bookingId!.length > 8 ? flowState.bookingId!.substring(0, 8) : flowState.bookingId!}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),

            const SizedBox(height: BCSpacing.lg),

            // Summary card
            if (result != null) _buildSummaryCard(theme, flowState, result),

            const SizedBox(height: BCSpacing.lg),

            // WhatsApp contact button
            if (result != null && result.business.whatsapp != null)
              Padding(
                padding: const EdgeInsets.only(bottom: BCSpacing.md),
                child: SizedBox(
                  width: double.infinity,
                  height: BCSpacing.minTouchHeight,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
                    label: const Text('Contactar sal\u00f3n'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF25D366)),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(BCSpacing.radiusSm),
                      ),
                    ),
                    onPressed: () {
                      final phone =
                          result.business.whatsapp!.replaceAll(RegExp(r'[^\d]'), '');
                      launchUrl(Uri.parse('https://wa.me/$phone'));
                    },
                  ),
                ),
              ),

            // Action buttons
            if (isMobile)
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: BCSpacing.minTouchHeight,
                    child: FilledButton(
                      onPressed: () => context.go('/mis-citas'),
                      child: const Text(
                        'Ver mis citas',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: BCSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    height: BCSpacing.minTouchHeight,
                    child: OutlinedButton(
                      onPressed: () =>
                          ref.read(bookingFlowProvider.notifier).reset(),
                      child: const Text(
                        'Hacer otra reservaci\u00f3n',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: BCSpacing.minTouchHeight,
                      child: OutlinedButton(
                        onPressed: () =>
                            ref.read(bookingFlowProvider.notifier).reset(),
                        child: const Text(
                          'Hacer otra reservaci\u00f3n',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: BCSpacing.md),
                  Expanded(
                    child: SizedBox(
                      height: BCSpacing.minTouchHeight,
                      child: FilledButton(
                        onPressed: () => context.go('/mis-citas'),
                        child: const Text(
                          'Ver mis citas',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: BCSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    ThemeData theme,
    BookingFlowState flowState,
    ResultCard result,
  ) {
    final slot = result.slot;
    final startTime = slot.startTime;
    final formattedDate = DateFormat('EEEE d MMMM, yyyy', 'es').format(startTime);
    final formattedTime = DateFormat('h:mm a').format(startTime);
    final price = result.service.price;
    final currency = result.service.currency.toUpperCase();

    String transportLabel;
    switch (flowState.transportMode) {
      case 'car':
        transportLabel = 'En mi carro';
      case 'uber':
        transportLabel = 'Uber';
      case 'transit':
        transportLabel = 'Transporte P\u00fablico';
      default:
        transportLabel = flowState.transportMode ?? '—';
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BCSpacing.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.all(BCSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: BCSpacing.md),
            _summaryRow(theme, 'Servicio', result.service.name),
            _summaryRow(theme, 'Sal\u00f3n', result.business.name),
            _summaryRow(theme, 'Fecha', formattedDate),
            _summaryRow(theme, 'Hora', formattedTime),
            _summaryRow(
              theme,
              'Precio',
              '\$${price.toStringAsFixed(2)} $currency',
            ),
            _summaryRow(theme, 'Transporte', transportLabel),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BCSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Summary sidebar (desktop/tablet) ─────────────────────────────────────────

class _SummarySidebar extends StatelessWidget {
  const _SummarySidebar({required this.flowState});

  final BookingFlowState flowState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCategory = flowState.selectedCategory != null;
    final hasService = flowState.selectedService != null;
    final hasFollowUps = flowState.followUpAnswers.isNotEmpty;
    final hasResult = flowState.selectedResult != null;
    final primaryColor = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.all(BCSpacing.lg),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BCSpacing.radiusMd),
        ),
        elevation: BCSpacing.elevationLow,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(BCSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header (always visible) ──
              Row(
                children: [
                  Icon(
                    Icons.event_note_rounded,
                    color: primaryColor,
                    size: BCSpacing.iconMd,
                  ),
                  const SizedBox(width: BCSpacing.sm),
                  Text(
                    'Tu Reservaci\u00f3n',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),

              // ── Empty state ──
              if (!hasCategory)
                Padding(
                  padding: const EdgeInsets.only(top: BCSpacing.lg),
                  child: Text(
                    'Selecciona un servicio para comenzar',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ),

              // ── Category row ──
              _SidebarAnimatedSection(
                visible: hasCategory,
                child: _SidebarRow(
                  icon: Text(
                    flowState.selectedCategory?.icon ?? '',
                    style: const TextStyle(fontSize: 20),
                  ),
                  label: flowState.selectedCategory?.nameEs ?? '',
                  labelStyle: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // ── Service row ──
              _SidebarAnimatedSection(
                visible: hasService,
                child: Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: Text(
                    hasService
                        ? '${flowState.selectedSubcategory?.nameEs ?? ''}'
                            ' > ${flowState.selectedService!.nameEs}'
                        : '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),

              // ── Follow-up preferences ──
              _SidebarAnimatedSection(
                visible: hasFollowUps,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: BCSpacing.sm),
                    Divider(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.1),
                    ),
                    const SizedBox(height: BCSpacing.sm),
                    _SidebarRow(
                      icon: Icon(
                        Icons.tune_rounded,
                        size: 18,
                        color: theme.colorScheme.secondary,
                      ),
                      label: 'Preferencias',
                      labelStyle: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: BCSpacing.xs),
                    ...flowState.followUpAnswers.entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(
                          left: 28,
                          bottom: BCSpacing.xs,
                        ),
                        child: Text(
                          '${_humanizeKey(entry.key)}: ${entry.value}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Selected result details ──
              _SidebarAnimatedSection(
                visible: hasResult,
                child: Builder(
                  builder: (context) {
                    if (!hasResult) return const SizedBox.shrink();
                    final result = flowState.selectedResult!;
                    final startTime = result.slot.startTime;
                    final dayFormat = DateFormat('EEE d MMM', 'es');
                    final timeFormat = DateFormat('h:mm a', 'es');

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: BCSpacing.sm),
                        Divider(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.1),
                        ),
                        const SizedBox(height: BCSpacing.sm),

                        // Salon name
                        _SidebarRow(
                          icon: Icon(
                            Icons.store_rounded,
                            size: 18,
                            color: theme.colorScheme.secondary,
                          ),
                          label: result.business.name,
                          labelStyle: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: BCSpacing.xs),

                        // Stylist
                        _SidebarRow(
                          icon: Icon(
                            Icons.person_rounded,
                            size: 18,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                          label: result.staff.name,
                        ),
                        const SizedBox(height: BCSpacing.xs),

                        // Rating
                        _SidebarRow(
                          icon: Icon(
                            Icons.star_rounded,
                            size: 18,
                            color: Colors.amber.shade700,
                          ),
                          label:
                              '${result.staff.rating.toStringAsFixed(1)} '
                              '(${result.staff.totalReviews})',
                        ),
                        const SizedBox(height: BCSpacing.xs),

                        // Date & time
                        _SidebarRow(
                          icon: Icon(
                            Icons.calendar_today_rounded,
                            size: 18,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                          label:
                              '${dayFormat.format(startTime)}, '
                              '${timeFormat.format(startTime)}',
                        ),
                        const SizedBox(height: BCSpacing.xs),

                        // Duration
                        _SidebarRow(
                          icon: Icon(
                            Icons.timer_outlined,
                            size: 18,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                          label:
                              '${result.service.durationMinutes} min',
                        ),

                        // ── Price ──
                        const SizedBox(height: BCSpacing.md),
                        Divider(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.1),
                        ),
                        const SizedBox(height: BCSpacing.md),
                        Row(
                          children: [
                            Icon(
                              Icons.payments_rounded,
                              size: 22,
                              color: theme.colorScheme.secondary,
                            ),
                            const SizedBox(width: BCSpacing.sm),
                            Text(
                              '\$${result.service.price.toStringAsFixed(0)} '
                              '${result.service.currency}',
                              style:
                                  theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Converts a follow-up key like "nail_length" to "Nail length".
  static String _humanizeKey(String key) {
    if (key.isEmpty) return key;
    final spaced = key.replaceAll('_', ' ');
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}

/// Animated section that smoothly reveals/hides content in the sidebar.
class _SidebarAnimatedSection extends StatelessWidget {
  const _SidebarAnimatedSection({
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: visible ? 1.0 : 0.0,
        child: visible ? child : const SizedBox.shrink(),
      ),
    );
  }
}

/// A simple icon + label row used throughout the sidebar.
class _SidebarRow extends StatelessWidget {
  const _SidebarRow({
    required this.icon,
    required this.label,
    this.labelStyle,
  });

  final Widget icon;
  final String label;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 22, child: Center(child: icon)),
        const SizedBox(width: BCSpacing.sm - 2),
        Expanded(
          child: Text(
            label,
            style: labelStyle ??
                theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
          ),
        ),
      ],
    );
  }
}

// ── Sticky bottom bar (mobile only) ─────────────────────────────────────────

class _StickyBottomBar extends StatelessWidget {
  const _StickyBottomBar({required this.flowState});

  final BookingFlowState flowState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCategory = flowState.selectedCategory != null;
    final hasService = flowState.selectedService != null;
    final hasResult = flowState.selectedResult != null;
    final isPaymentStep = flowState.step == BookingStep.payment;
    final showBar =
        flowState.step.index > BookingStep.category.index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      height: showBar ? 72 : 0,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: showBar
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  offset: const Offset(0, -2),
                  blurRadius: 8,
                ),
              ]
            : [],
      ),
      child: showBar
          ? Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BCSpacing.md,
                vertical: BCSpacing.sm,
              ),
              child: Row(
                children: [
                  // ── Left: compact summary ──
                  Expanded(
                    child: _buildLeftSummary(
                      theme,
                      hasCategory: hasCategory,
                      hasService: hasService,
                      hasResult: hasResult,
                    ),
                  ),

                  // ── Right: action button (payment step only) ──
                  if (isPaymentStep && hasResult)
                    FilledButton(
                      onPressed: null, // Handled by the payment step itself
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: BCSpacing.lg,
                          vertical: BCSpacing.sm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(BCSpacing.radiusSm),
                        ),
                      ),
                      child: Text(
                        'Pagar \$${flowState.selectedResult!.service.price.toStringAsFixed(0)}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildLeftSummary(
    ThemeData theme, {
    required bool hasCategory,
    required bool hasService,
    required bool hasResult,
  }) {
    if (hasResult) {
      // Show price when a result is selected
      final result = flowState.selectedResult!;
      return Row(
        children: [
          Text(
            flowState.selectedCategory?.icon ?? '',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(width: BCSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  result.business.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '\$${result.service.price.toStringAsFixed(0)} '
                  '${result.service.currency}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (hasService) {
      return Row(
        children: [
          Text(
            flowState.selectedCategory?.icon ?? '',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(width: BCSpacing.sm),
          Expanded(
            child: Text(
              flowState.selectedService!.nameEs,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    if (hasCategory) {
      return Row(
        children: [
          Text(
            flowState.selectedCategory!.icon,
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(width: BCSpacing.sm),
          Expanded(
            child: Text(
              flowState.selectedCategory!.nameEs,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}
