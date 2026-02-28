import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../config/breakpoints.dart';
import '../../providers/business_portal_provider.dart';

/// Review filter.
enum _ReviewFilter { all, recent, low }

final _reviewFilterProvider = StateProvider<_ReviewFilter>((ref) => _ReviewFilter.all);

/// Business reviews page — ratings overview + review list.
class BizReviewsPage extends ConsumerWidget {
  const BizReviewsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bizAsync = ref.watch(currentBusinessProvider);

    return bizAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (biz) {
        if (biz == null) return const Center(child: Text('Sin negocio'));
        return const _ReviewsContent();
      },
    );
  }
}

class _ReviewsContent extends ConsumerWidget {
  const _ReviewsContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final reviewsAsync = ref.watch(businessReviewsProvider);
    final statsAsync = ref.watch(businessStatsProvider);
    final filter = ref.watch(_reviewFilterProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = WebBreakpoints.isMobile(constraints.maxWidth);
        final isDesktop = WebBreakpoints.isDesktop(constraints.maxWidth);
        final padding = isMobile ? 16.0 : 24.0;

        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Text('Resenas', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 12),
                  statsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (stats) => Row(
                      children: [
                        Chip(label: Text('${stats.totalReviews}'), visualDensity: VisualDensity.compact),
                        const SizedBox(width: 8),
                        Icon(Icons.star, color: const Color(0xFFFFC107), size: 20),
                        const SizedBox(width: 4),
                        Text(stats.averageRating.toStringAsFixed(1), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Star distribution + reviews list
              reviewsAsync.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(strokeWidth: 2))),
                error: (_, __) => Center(child: Text('Error al cargar resenas', style: theme.textTheme.bodySmall?.copyWith(color: colors.error))),
                data: (reviews) {
                  if (reviews.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(48),
                        child: Column(
                          children: [
                            Icon(Icons.reviews_outlined, size: 48, color: colors.onSurface.withValues(alpha: 0.3)),
                            const SizedBox(height: 12),
                            Text('Sin resenas', style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurface.withValues(alpha: 0.5))),
                          ],
                        ),
                      ),
                    );
                  }

                  // Compute star distribution
                  final dist = <int, int>{5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
                  for (final r in reviews) {
                    final rating = (r['rating'] as num?)?.toInt() ?? 0;
                    if (rating >= 1 && rating <= 5) dist[rating] = dist[rating]! + 1;
                  }

                  // Filter
                  var filtered = reviews;
                  if (filter == _ReviewFilter.recent) {
                    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
                    filtered = reviews.where((r) {
                      final dt = DateTime.tryParse(r['created_at'] as String? ?? '');
                      return dt != null && dt.isAfter(weekAgo);
                    }).toList();
                  } else if (filter == _ReviewFilter.low) {
                    filtered = reviews.where((r) => ((r['rating'] as num?)?.toInt() ?? 5) <= 3).toList();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Star distribution chart
                      if (isDesktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 1, child: _StarDistribution(dist: dist, total: reviews.length)),
                            const SizedBox(width: 24),
                            Expanded(flex: 2, child: _FilterAndList(filtered: filtered, filter: filter)),
                          ],
                        )
                      else ...[
                        _StarDistribution(dist: dist, total: reviews.length),
                        const SizedBox(height: 24),
                        _FilterAndList(filtered: filtered, filter: filter),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Star Distribution ───────────────────────────────────────────────────────

class _StarDistribution extends StatelessWidget {
  const _StarDistribution({required this.dist, required this.total});
  final Map<int, int> dist;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Distribucion', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          for (var stars = 5; stars >= 1; stars--)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(width: 20, child: Text('$stars', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600))),
                  const Icon(Icons.star, size: 14, color: Color(0xFFFFC107)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: total > 0 ? dist[stars]! / total : 0,
                        backgroundColor: colors.outlineVariant.withValues(alpha: 0.3),
                        color: const Color(0xFFFFC107),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 24,
                    child: Text('${dist[stars]}', style: theme.textTheme.labelSmall, textAlign: TextAlign.right),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Filter and List ─────────────────────────────────────────────────────────

class _FilterAndList extends ConsumerWidget {
  const _FilterAndList({required this.filtered, required this.filter});
  final List<Map<String, dynamic>> filtered;
  final _ReviewFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter chips
        Row(
          children: [
            FilterChip(
              label: const Text('Todas'),
              selected: filter == _ReviewFilter.all,
              onSelected: (_) => ref.read(_reviewFilterProvider.notifier).state = _ReviewFilter.all,
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('Recientes'),
              selected: filter == _ReviewFilter.recent,
              onSelected: (_) => ref.read(_reviewFilterProvider.notifier).state = _ReviewFilter.recent,
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('Baja calificacion'),
              selected: filter == _ReviewFilter.low,
              onSelected: (_) => ref.read(_reviewFilterProvider.notifier).state = _ReviewFilter.low,
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text('Sin resenas en este filtro', style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurface.withValues(alpha: 0.5)))),
          )
        else
          for (final r in filtered) _ReviewCard(review: r),
      ],
    );
  }
}

// ── Review Card ─────────────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});
  final Map<String, dynamic> review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final rating = (review['rating'] as num?)?.toInt() ?? 0;
    final text = review['text'] as String? ?? review['comment'] as String? ?? '';
    final customerName = review['customer_name'] as String? ?? 'Cliente';
    final createdAt = DateTime.tryParse(review['created_at'] as String? ?? '');
    final dateStr = createdAt != null ? DateFormat('d MMM yyyy', 'es').format(createdAt) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: colors.primary.withValues(alpha: 0.12),
                child: Text(
                  customerName.isNotEmpty ? customerName[0].toUpperCase() : '?',
                  style: TextStyle(fontSize: 12, color: colors.primary, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customerName, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                    Text(dateStr, style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurface.withValues(alpha: 0.4))),
                  ],
                ),
              ),
              // Stars
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 1; i <= 5; i++)
                    Icon(
                      i <= rating ? Icons.star : Icons.star_border,
                      size: 16,
                      color: const Color(0xFFFFC107),
                    ),
                ],
              ),
            ],
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(text, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
