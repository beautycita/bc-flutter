import 'package:beautycita_core/models.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:beautycita_core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../config/breakpoints.dart';
import '../../data/categories.dart';
import '../../providers/booking_flow_provider.dart';
import '../../providers/curate_provider.dart';

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
      default:
        return Center(
          child: Padding(
            padding: const EdgeInsets.only(top: BCSpacing.xxl),
            child: Text('Step: ${flowState.step.name}'),
          ),
        );
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

    // ── Empty results (auto-switches to discovered in provider) ──
    if (response.results.isEmpty) {
      if (flowState.showingDiscovered) {
        // Task 6 will handle discovered salons. Placeholder for now.
        return Center(
          child: Padding(
            padding: const EdgeInsets.only(top: BCSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search, size: BCSpacing.iconXl,
                    color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                const SizedBox(height: BCSpacing.md),
                Text(
                  'Buscando salones descubiertos cerca de ti...',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }
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

// ── Summary sidebar (desktop/tablet) ─────────────────────────────────────────

class _SummarySidebar extends StatelessWidget {
  const _SummarySidebar({required this.flowState});

  final BookingFlowState flowState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCategory = flowState.selectedCategory != null;

    return Padding(
      padding: const EdgeInsets.all(BCSpacing.lg),
      child: Card(
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
                'Tu Reservaci\u00f3n',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: BCSpacing.md),
              Text(
                hasCategory
                    ? flowState.selectedCategory!.nameEs
                    : 'Selecciona un servicio',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: hasCategory
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
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

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            offset: const Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: BCSpacing.md,
        vertical: BCSpacing.sm,
      ),
      child: Center(
        child: Text(
          hasCategory ? flowState.selectedCategory!.nameEs : '',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
