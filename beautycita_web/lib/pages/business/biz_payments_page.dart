import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/breakpoints.dart';
import '../../providers/business_portal_provider.dart';

/// Date range filter for payments.
enum _DateRange { thisWeek, thisMonth, allTime }

/// Method filter for payments.
enum _MethodFilter { all, card, cash, transfer }

final _dateRangeProvider = StateProvider<_DateRange>((ref) => _DateRange.thisMonth);
final _methodFilterProvider = StateProvider<_MethodFilter>((ref) => _MethodFilter.all);

/// Business payments page — revenue summary + Stripe + filtered transactions.
class BizPaymentsPage extends ConsumerWidget {
  const BizPaymentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bizAsync = ref.watch(currentBusinessProvider);

    return bizAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (biz) {
        if (biz == null) return const Center(child: Text('Sin negocio'));
        return _PaymentsContent(biz: biz);
      },
    );
  }
}

class _PaymentsContent extends ConsumerWidget {
  const _PaymentsContent({required this.biz});
  final Map<String, dynamic> biz;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final paymentsAsync = ref.watch(businessPaymentsProvider);
    final statsAsync = ref.watch(businessStatsProvider);
    final dateRange = ref.watch(_dateRangeProvider);
    final methodFilter = ref.watch(_methodFilterProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = WebBreakpoints.isMobile(constraints.maxWidth);
        final padding = isMobile ? 16.0 : 24.0;

        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pagos', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 24),

              // Revenue summary
              statsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (stats) => Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.primary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.payments_outlined, size: 32, color: colors.primary),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ingresos del mes', style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurface.withValues(alpha: 0.6))),
                          Text('\$${stats.revenueMonth.toStringAsFixed(0)} MXN', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, color: colors.primary)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Stripe status banner
              _StripeBanner(biz: biz),
              const SizedBox(height: 24),

              // Filters
              Text('Transacciones', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Date range
                  ChoiceChip(label: const Text('Esta semana'), selected: dateRange == _DateRange.thisWeek, onSelected: (_) => ref.read(_dateRangeProvider.notifier).state = _DateRange.thisWeek),
                  ChoiceChip(label: const Text('Este mes'), selected: dateRange == _DateRange.thisMonth, onSelected: (_) => ref.read(_dateRangeProvider.notifier).state = _DateRange.thisMonth),
                  ChoiceChip(label: const Text('Todo'), selected: dateRange == _DateRange.allTime, onSelected: (_) => ref.read(_dateRangeProvider.notifier).state = _DateRange.allTime),
                  const SizedBox(width: 16),
                  // Method filter
                  FilterChip(label: const Text('Tarjeta'), selected: methodFilter == _MethodFilter.card, onSelected: (v) => ref.read(_methodFilterProvider.notifier).state = v ? _MethodFilter.card : _MethodFilter.all),
                  FilterChip(label: const Text('Efectivo'), selected: methodFilter == _MethodFilter.cash, onSelected: (v) => ref.read(_methodFilterProvider.notifier).state = v ? _MethodFilter.cash : _MethodFilter.all),
                  FilterChip(label: const Text('Transferencia'), selected: methodFilter == _MethodFilter.transfer, onSelected: (v) => ref.read(_methodFilterProvider.notifier).state = v ? _MethodFilter.transfer : _MethodFilter.all),
                ],
              ),
              const SizedBox(height: 16),

              paymentsAsync.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(strokeWidth: 2))),
                error: (_, __) => Center(child: Text('Error al cargar pagos', style: theme.textTheme.bodySmall?.copyWith(color: colors.error))),
                data: (payments) {
                  // Apply filters
                  var filtered = payments;

                  // Date range filter
                  final now = DateTime.now();
                  if (dateRange == _DateRange.thisWeek) {
                    final weekStart = now.subtract(Duration(days: now.weekday - 1));
                    final cutoff = DateTime(weekStart.year, weekStart.month, weekStart.day);
                    filtered = filtered.where((p) {
                      final dt = DateTime.tryParse(p['created_at'] as String? ?? '');
                      return dt != null && dt.isAfter(cutoff);
                    }).toList();
                  } else if (dateRange == _DateRange.thisMonth) {
                    final cutoff = DateTime(now.year, now.month, 1);
                    filtered = filtered.where((p) {
                      final dt = DateTime.tryParse(p['created_at'] as String? ?? '');
                      return dt != null && dt.isAfter(cutoff);
                    }).toList();
                  }

                  // Method filter
                  if (methodFilter != _MethodFilter.all) {
                    final methodStr = switch (methodFilter) {
                      _MethodFilter.card => 'card',
                      _MethodFilter.cash => 'cash',
                      _MethodFilter.transfer => 'transfer',
                      _MethodFilter.all => '',
                    };
                    filtered = filtered.where((p) => (p['method'] as String? ?? '') == methodStr).toList();
                  }

                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 48, color: colors.onSurface.withValues(alpha: 0.3)),
                            const SizedBox(height: 12),
                            Text('Sin transacciones', style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurface.withValues(alpha: 0.5))),
                          ],
                        ),
                      ),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: isMobile
                        ? Column(children: [for (final p in filtered) _PaymentMobileRow(payment: p)])
                        : _PaymentsTable(payments: filtered),
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

// ── Stripe Status Banner ────────────────────────────────────────────────────

class _StripeBanner extends ConsumerStatefulWidget {
  const _StripeBanner({required this.biz});
  final Map<String, dynamic> biz;

  @override
  ConsumerState<_StripeBanner> createState() => _StripeBannerState();
}

class _StripeBannerState extends ConsumerState<_StripeBanner> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final stripeId = widget.biz['stripe_account_id'] as String?;
    final chargesEnabled = widget.biz['stripe_charges_enabled'] as bool? ?? false;
    final payoutsEnabled = widget.biz['stripe_payouts_enabled'] as bool? ?? false;
    final isOnboarded = widget.biz['stripe_onboarded'] as bool? ?? false;

    // Fully connected
    if (stripeId != null && isOnboarded && chargesEnabled && payoutsEnabled) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Stripe conectado', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: const Color(0xFF4CAF50))),
                  Text('Cobros y pagos habilitados', style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurface.withValues(alpha: 0.5))),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Partially connected (has account but missing capabilities)
    if (stripeId != null && isOnboarded) {
      final issues = <String>[];
      if (!chargesEnabled) issues.add('cobros');
      if (!payoutsEnabled) issues.add('pagos');

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFF9800).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber, color: Color(0xFFFF9800), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Stripe parcialmente configurado', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: const Color(0xFFFF9800))),
                  Text('Falta habilitar: ${issues.join(', ')}', style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurface.withValues(alpha: 0.5))),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _loading ? null : _startStripeOnboarding,
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Completar'),
            ),
          ],
        ),
      );
    }

    // Not connected
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9800).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Color(0xFFFF9800), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stripe no configurado', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: const Color(0xFFFF9800))),
                Text('Configura tu cuenta de Stripe para recibir pagos.', style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurface.withValues(alpha: 0.5))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _loading ? null : _startStripeOnboarding,
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Configurar Stripe'),
          ),
        ],
      ),
    );
  }

  Future<void> _startStripeOnboarding() async {
    setState(() => _loading = true);
    try {
      final response = await BCSupabase.client.functions.invoke(
        'stripe-onboarding',
        body: {'business_id': widget.biz['id']},
      );
      final data = response.data as Map<String, dynamic>?;
      final url = data?['url'] as String?;
      if (url != null && mounted) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ── Payments Table ──────────────────────────────────────────────────────────

class _PaymentsTable extends StatelessWidget {
  const _PaymentsTable({required this.payments});
  final List<Map<String, dynamic>> payments;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DataTable(
      headingRowColor: WidgetStateProperty.all(colors.surfaceContainerHighest.withValues(alpha: 0.3)),
      columns: const [
        DataColumn(label: Text('Fecha')),
        DataColumn(label: Text('Metodo')),
        DataColumn(label: Text('Estado')),
        DataColumn(label: Text('Monto'), numeric: true),
      ],
      rows: [
        for (final p in payments) _buildRow(context, p),
      ],
    );
  }

  DataRow _buildRow(BuildContext context, Map<String, dynamic> p) {
    final amount = (p['amount'] as num?)?.toDouble() ?? 0;
    final method = p['method'] as String? ?? '';
    final status = p['status'] as String? ?? '';
    final createdAt = DateTime.tryParse(p['created_at'] as String? ?? '');
    final dateStr = createdAt != null ? DateFormat('dd/MM/yy HH:mm').format(createdAt) : '--';

    final statusColor = switch (status) {
      'completed' || 'paid' => const Color(0xFF4CAF50),
      'pending' => const Color(0xFFFF9800),
      'refunded' => const Color(0xFF2196F3),
      'failed' => const Color(0xFFE53935),
      _ => Colors.grey,
    };

    final methodLabel = switch (method) {
      'card' => 'Tarjeta',
      'cash' => 'Efectivo',
      'transfer' => 'Transferencia',
      _ => method,
    };

    return DataRow(cells: [
      DataCell(Text(dateStr, style: const TextStyle(fontSize: 13, fontFamily: 'monospace'))),
      DataCell(Text(methodLabel)),
      DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Text(status, style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600)),
        ),
      ),
      DataCell(Text('\$${amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600))),
    ]);
  }
}

// ── Mobile Payment Row ──────────────────────────────────────────────────────

class _PaymentMobileRow extends StatelessWidget {
  const _PaymentMobileRow({required this.payment});
  final Map<String, dynamic> payment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
    final status = payment['status'] as String? ?? '';
    final method = payment['method'] as String? ?? '';
    final createdAt = DateTime.tryParse(payment['created_at'] as String? ?? '');
    final dateStr = createdAt != null ? DateFormat('dd/MM HH:mm').format(createdAt) : '--';

    final methodLabel = switch (method) {
      'card' => 'Tarjeta',
      'cash' => 'Efectivo',
      'transfer' => 'Transferencia',
      _ => method,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.3)))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateStr, style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
                Text('$methodLabel · $status', style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurface.withValues(alpha: 0.5))),
              ],
            ),
          ),
          Text('\$${amount.toStringAsFixed(0)}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
