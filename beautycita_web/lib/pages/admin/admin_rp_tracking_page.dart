import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/web_theme.dart';
import '../../providers/admin_rp_tracking_provider.dart';

/// Admin RP Tracking page — per-RP performance table with sortable columns.
///
/// Queries profiles with role='rp' and joins rp_assignments to compute
/// conversion metrics. Desktop-first DataTable layout.
class AdminRpTrackingPage extends ConsumerWidget {
  const AdminRpTrackingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rpAsync = ref.watch(adminRpTrackingProvider);
    final sort = ref.watch(rpSortProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageHeader(rpAsync: rpAsync, ref: ref),
          const SizedBox(height: 24),
          rpAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => _ErrorCard(error: '$e'),
            data: (rps) => _RpTable(rps: rps, sort: sort, ref: ref),
          ),
        ],
      ),
    );
  }
}

// ── Page header ───────────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.rpAsync, required this.ref});

  final AsyncValue<List<RpPerformance>> rpAsync;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = rpAsync.valueOrNull?.length ?? 0;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Seguimiento de RPs',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: kWebTextPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count representantes · Métricas de conversión',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: kWebTextSecondary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_outlined),
          tooltip: 'Actualizar',
          onPressed: () => ref.invalidate(adminRpTrackingProvider),
          color: kWebTextSecondary,
        ),
      ],
    );
  }
}

// ── Error card ────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.error),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              error,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colors.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ── RP table ──────────────────────────────────────────────────────────────────

class _RpTable extends StatelessWidget {
  const _RpTable({
    required this.rps,
    required this.sort,
    required this.ref,
  });

  final List<RpPerformance> rps;
  final RpSort sort;
  final WidgetRef ref;

  List<RpPerformance> _sorted() {
    final list = List<RpPerformance>.from(rps);
    list.sort((a, b) {
      int cmp;
      switch (sort.column) {
        case 'name':
          cmp = a.fullName.compareTo(b.fullName);
        case 'assigned':
          cmp = a.assigned.compareTo(b.assigned);
        case 'converted':
          cmp = a.converted.compareTo(b.converted);
        case 'rate':
          cmp = a.conversionRate.compareTo(b.conversionRate);
        case 'days':
          cmp = a.daysActive.compareTo(b.daysActive);
        default:
          cmp = a.converted.compareTo(b.converted);
      }
      return sort.ascending ? cmp : -cmp;
    });
    return list;
  }

  void _toggleSort(String column) {
    final notifier = ref.read(rpSortProvider.notifier);
    if (sort.column == column) {
      notifier.state = sort.copyWith(ascending: !sort.ascending);
    } else {
      notifier.state = sort.copyWith(column: column, ascending: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = _sorted();

    if (rps.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 80),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.people_outline,
                size: 64,
                color: kWebTextHint.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 16),
              Text(
                'No hay representantes asignados',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: kWebTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Asigna el rol "rp" a usuarios para verlos aquí',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: kWebTextHint,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: kWebSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kWebCardBorder),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
              kWebBackground.withValues(alpha: 0.5)),
          dataRowMinHeight: 48,
          dataRowMaxHeight: 56,
          columnSpacing: 24,
          horizontalMargin: 20,
          columns: [
            _col('RP', 'name'),
            _col('Asignados', 'assigned'),
            _col('Convertidos', 'converted'),
            _col('Tasa', 'rate'),
            _col('Días activo', 'days'),
          ],
          rows: sorted.map((rp) => _buildRow(context, rp)).toList(),
        ),
      ),
    );
  }

  DataColumn _col(String label, String column) {
    final isActive = sort.column == column;
    return DataColumn(
      label: InkWell(
        onTap: () => _toggleSort(column),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: isActive ? kWebPrimary : kWebTextSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isActive
                  ? (sort.ascending
                      ? Icons.arrow_upward
                      : Icons.arrow_downward)
                  : Icons.unfold_more,
              size: 14,
              color: isActive ? kWebPrimary : kWebTextHint,
            ),
          ],
        ),
      ),
    );
  }

  DataRow _buildRow(BuildContext context, RpPerformance rp) {
    final theme = Theme.of(context);
    final rate = rp.conversionRate;
    final rateColor = rate >= 0.5
        ? Colors.green[700]!
        : rate >= 0.25
            ? Colors.orange[700]!
            : Colors.red[700]!;

    return DataRow(cells: [
      // Name + avatar
      DataCell(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: kWebPrimary.withValues(alpha: 0.1),
              backgroundImage: rp.avatarUrl != null
                  ? NetworkImage(rp.avatarUrl!)
                  : null,
              child: rp.avatarUrl == null
                  ? Text(
                      rp.fullName.isNotEmpty
                          ? rp.fullName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: kWebPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              rp.fullName,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      DataCell(Text('${rp.assigned}',
          style: theme.textTheme.bodySmall)),
      DataCell(Text('${rp.converted}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.green[700],
            fontWeight: FontWeight.w500,
          ))),
      DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: rateColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${(rate * 100).toStringAsFixed(1)}%',
            style: TextStyle(
              color: rateColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      DataCell(Text('${rp.daysActive} días',
          style: theme.textTheme.bodySmall?.copyWith(
            color: kWebTextSecondary,
          ))),
    ]);
  }
}
