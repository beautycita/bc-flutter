import 'package:beautycita_core/models.dart';
import 'package:beautycita_core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/breakpoints.dart';
import '../../data/categories.dart';
import '../../providers/booking_flow_provider.dart';

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
