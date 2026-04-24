import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

import '../../config/breakpoints.dart';
import '../../config/web_theme.dart';
import '../../providers/business_portal_provider.dart';
import '../../providers/demo_providers.dart';
import '../../widgets/web_design_system.dart';

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
              WebSectionHeader(
                label: 'Finanzas',
                title: 'Pagos',
                centered: false,
                titleSize: 28,
              ),
              const SizedBox(height: 24),

              // Revenue summary
              statsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (stats) => WebCard(
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: kWebBrandGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.payments_outlined, size: 24, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ingresos del mes', style: theme.textTheme.bodySmall?.copyWith(color: kWebTextSecondary)),
                          ShaderMask(
                            shaderCallback: (bounds) => kWebBrandGradient.createShader(bounds),
                            child: Text(
                              '\$${stats.revenueMonth.toStringAsFixed(0)} MXN',
                              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Stripe status banner
              _StripeBanner(biz: biz),
              const SizedBox(height: 16),

              // Banking section — setup banner when incomplete, summary+edit card when complete
              if (biz['banking_complete'] != true)
                _BankingBanner(biz: biz)
              else
                _BankingSummaryCard(biz: biz),
              const SizedBox(height: 24),

              // Filters
              WebSectionHeader(
                label: 'Historial',
                title: 'Transacciones',
                centered: false,
                titleSize: 20,
              ),
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

              // ── Payout History ──
              _PayoutHistorySection(ref: ref, isMobile: isMobile),
              const SizedBox(height: 24),

              // ── Commission Breakdown ──
              _CommissionBreakdownSection(ref: ref, isMobile: isMobile),
              const SizedBox(height: 24),

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
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: kWebPrimary.withValues(alpha: 0.06),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.receipt_long_outlined, size: 32, color: kWebTextHint),
                            ),
                            const SizedBox(height: 12),
                            Text('Sin transacciones', style: theme.textTheme.bodyMedium?.copyWith(color: kWebTextHint)),
                          ],
                        ),
                      ),
                    );
                  }

                  return WebCard(
                    padding: EdgeInsets.zero,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: isMobile
                          ? Column(children: [for (final p in filtered) _PaymentMobileRow(payment: p)])
                          : _PaymentsTable(payments: filtered),
                    ),
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
    final isDemo = ref.watch(isDemoProvider);
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
            if (!isDemo) ...[
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _loading ? null : _startStripeOnboarding,
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Completar'),
              ),
            ],
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
          if (!isDemo) ...[
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _loading ? null : _startStripeOnboarding,
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Configurar Stripe'),
            ),
          ],
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
    return DataTable(
      headingRowColor: WidgetStateProperty.all(kWebBackground),
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)),
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
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kWebCardBorder))),
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

// ── Payout History Section ───────────────────────────────────────────────────

class _PayoutHistorySection extends ConsumerWidget {
  const _PayoutHistorySection({required this.ref, required this.isMobile});
  final WidgetRef ref;
  final bool isMobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payoutsAsync = ref.watch(businessPayoutRecordsProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WebSectionHeader(
          label: 'Depositos',
          title: 'Historial de Pagos',
          centered: false,
          titleSize: 20,
        ),
        const SizedBox(height: 12),
        payoutsAsync.when(
          loading: () => const Center(
            child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, __) => Center(
            child: Text('Error al cargar historial', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
          ),
          data: (payouts) {
            if (payouts.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: kWebPrimary.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.account_balance_wallet_outlined, size: 28, color: kWebTextHint),
                      ),
                      const SizedBox(height: 8),
                      Text('Sin depositos registrados', style: theme.textTheme.bodySmall?.copyWith(color: kWebTextHint)),
                    ],
                  ),
                ),
              );
            }

            if (isMobile) {
              return WebCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [for (final p in payouts) _PayoutMobileRow(payout: p)],
                ),
              );
            }

            return WebCard(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(kWebBackground),
                  columns: const [
                    DataColumn(label: Text('Fecha')),
                    DataColumn(label: Text('Periodo')),
                    DataColumn(label: Text('Metodo')),
                    DataColumn(label: Text('Referencia')),
                    DataColumn(label: Text('Estado')),
                    DataColumn(label: Text('Monto'), numeric: true),
                  ],
                  rows: [for (final p in payouts) _buildPayoutRow(context, p)],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  DataRow _buildPayoutRow(BuildContext context, Map<String, dynamic> p) {
    final amount = (p['amount'] as num?)?.toDouble() ?? 0;
    final method = p['method'] as String? ?? '';
    final reference = p['reference'] as String? ?? '--';
    final status = p['status'] as String? ?? '';
    final period = p['period'] as String? ?? '--';
    final createdAt = DateTime.tryParse(p['created_at'] as String? ?? '');
    final dateStr = createdAt != null ? DateFormat('dd/MM/yy').format(createdAt) : '--';

    final statusColor = switch (status) {
      'completed' || 'paid' => const Color(0xFF4CAF50),
      'pending' => const Color(0xFFFF9800),
      'failed' => const Color(0xFFE53935),
      _ => Colors.grey,
    };

    return DataRow(cells: [
      DataCell(Text(dateStr, style: const TextStyle(fontSize: 13, fontFamily: 'monospace'))),
      DataCell(Text(period)),
      DataCell(Text(method)),
      DataCell(Text(reference, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis)),
      DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)),
          child: Text(status, style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600)),
        ),
      ),
      DataCell(Text('\$${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600))),
    ]);
  }
}

class _PayoutMobileRow extends StatelessWidget {
  const _PayoutMobileRow({required this.payout});
  final Map<String, dynamic> payout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = (payout['amount'] as num?)?.toDouble() ?? 0;
    final status = payout['status'] as String? ?? '';
    final method = payout['method'] as String? ?? '';
    final period = payout['period'] as String? ?? '';
    final reference = payout['reference'] as String? ?? '';
    final createdAt = DateTime.tryParse(payout['created_at'] as String? ?? '');
    final dateStr = createdAt != null ? DateFormat('dd/MM HH:mm').format(createdAt) : '--';

    final statusColor = switch (status) {
      'completed' || 'paid' => const Color(0xFF4CAF50),
      'pending' => const Color(0xFFFF9800),
      'failed' => const Color(0xFFE53935),
      _ => Colors.grey,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kWebCardBorder))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateStr, style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
                Text('$method · $period', style: theme.textTheme.labelSmall?.copyWith(color: kWebTextSecondary)),
                if (reference.isNotEmpty)
                  Text(reference, style: theme.textTheme.labelSmall?.copyWith(color: kWebTextHint, fontFamily: 'monospace')),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\$${amount.toStringAsFixed(2)}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)),
                child: Text(status, style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Commission Breakdown Section ─────────────────────────────────────────────

class _CommissionBreakdownSection extends ConsumerWidget {
  const _CommissionBreakdownSection({required this.ref, required this.isMobile});
  final WidgetRef ref;
  final bool isMobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commissionsAsync = ref.watch(businessCommissionRecordsProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WebSectionHeader(
          label: 'Comisiones',
          title: 'Desglose de Comisiones',
          centered: false,
          titleSize: 20,
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Transacciones en red BeautyCita (el cliente paga via la plataforma): 3% de cargo de procesamiento + retenciones fiscales que BC enteras al SAT. Transacciones fuera de red (tus propios clientes pagando en efectivo, terminal propio, etc. que tu registras en BC para tus controles): 0% de cargo, sin retencion. Tu responsabilidad reportar esas al SAT.',
            style: theme.textTheme.bodySmall?.copyWith(color: kWebTextHint),
          ),
        ),
        const SizedBox(height: 12),
        commissionsAsync.when(
          loading: () => const Center(
            child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, __) => Center(
            child: Text('Error al cargar comisiones', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
          ),
          data: (commissions) {
            if (commissions.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: kWebSecondary.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.pie_chart_outline, size: 28, color: kWebTextHint),
                      ),
                      const SizedBox(height: 8),
                      Text('Sin comisiones — aun no te hemos enviado clientes', style: theme.textTheme.bodySmall?.copyWith(color: kWebTextHint)),
                    ],
                  ),
                ),
              );
            }

            if (isMobile) {
              return WebCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [for (final c in commissions) _CommissionMobileRow(commission: c)],
                ),
              );
            }

            return WebCard(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(kWebBackground),
                  columns: const [
                    DataColumn(label: Text('Fecha')),
                    DataColumn(label: Text('Servicio')),
                    DataColumn(label: Text('Base'), numeric: true),
                    DataColumn(label: Text('Tasa')),
                    DataColumn(label: Text('Comision'), numeric: true),
                  ],
                  rows: [for (final c in commissions) _buildCommissionRow(context, c)],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  DataRow _buildCommissionRow(BuildContext context, Map<String, dynamic> c) {
    final baseAmount = (c['base_amount'] as num?)?.toDouble() ?? 0;
    final rate = (c['rate'] as num?)?.toDouble() ?? 0;
    final commission = (c['commission_amount'] as num?)?.toDouble() ?? 0;
    final serviceName = c['service_name'] as String? ?? '--';
    final createdAt = DateTime.tryParse(c['created_at'] as String? ?? '');
    final dateStr = createdAt != null ? DateFormat('dd/MM/yy').format(createdAt) : '--';

    return DataRow(cells: [
      DataCell(Text(dateStr, style: const TextStyle(fontSize: 13, fontFamily: 'monospace'))),
      DataCell(Text(serviceName, overflow: TextOverflow.ellipsis)),
      DataCell(Text('\$${baseAmount.toStringAsFixed(2)}')),
      DataCell(Text('${(rate * 100).toStringAsFixed(1)}%')),
      DataCell(Text('\$${commission.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600))),
    ]);
  }
}

class _CommissionMobileRow extends StatelessWidget {
  const _CommissionMobileRow({required this.commission});
  final Map<String, dynamic> commission;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseAmount = (commission['base_amount'] as num?)?.toDouble() ?? 0;
    final rate = (commission['rate'] as num?)?.toDouble() ?? 0;
    final commissionAmt = (commission['commission_amount'] as num?)?.toDouble() ?? 0;
    final serviceName = commission['service_name'] as String? ?? '--';
    final createdAt = DateTime.tryParse(commission['created_at'] as String? ?? '');
    final dateStr = createdAt != null ? DateFormat('dd/MM').format(createdAt) : '--';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kWebCardBorder))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(serviceName, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('$dateStr · Base: \$${baseAmount.toStringAsFixed(0)} · ${(rate * 100).toStringAsFixed(1)}%',
                    style: theme.textTheme.labelSmall?.copyWith(color: kWebTextSecondary)),
              ],
            ),
          ),
          Text('\$${commissionAmt.toStringAsFixed(2)}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: kWebSecondary)),
        ],
      ),
    );
  }
}

// ── Banking Setup Banner ───────────────────────────────────────────────────

/// Banking summary card shown once banking setup is complete.
/// Displays masked CLABE + bank + beneficiary + an Editar button that routes
/// to /negocio/banking. The banking page itself fires the payout-lock modal
/// when the user attempts to change sensitive fields.
class _BankingSummaryCard extends ConsumerWidget {
  const _BankingSummaryCard({required this.biz});
  final Map<String, dynamic> biz;

  String _maskClabe(String? clabe) {
    if (clabe == null || clabe.length < 4) return '••••';
    return '••••${clabe.substring(clabe.length - 4)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bizId = biz['id'] as String;
    final holdAsync = ref.watch(activePayoutHoldProvider(bizId));
    final clabe = biz['clabe'] as String?;
    final bankName = (biz['bank_name'] as String?)?.trim().isNotEmpty == true ? biz['bank_name'] as String : '—';
    final beneficiary = (biz['beneficiary_name'] as String?)?.trim().isNotEmpty == true ? biz['beneficiary_name'] as String : '—';

    final hasHold = holdAsync.maybeWhen(data: (v) => v, orElse: () => false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasHold)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE65100).withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pagos detenidos', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFFE65100))),
                      const SizedBox(height: 2),
                      Text(
                        'Detectamos un cambio reciente en tus datos de pago. Un administrador revisara la nueva informacion antes de reanudar los pagos. 24-72 h habiles.',
                        style: theme.textTheme.labelSmall?.copyWith(color: const Color(0xFF5D4037)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kWebSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kWebCardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: kWebPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance, size: 20, color: kWebPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cuenta bancaria', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      '$bankName · ${_maskClabe(clabe)} · $beneficiary',
                      style: theme.textTheme.labelSmall?.copyWith(color: kWebTextSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => context.go('/negocio/banking'),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Editar'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BankingBanner extends StatelessWidget {
  const _BankingBanner({required this.biz});
  final Map<String, dynamic> biz;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            kWebPrimary.withValues(alpha: 0.06),
            kWebSecondary.withValues(alpha: 0.06),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kWebPrimary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: kWebBrandGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.account_balance, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configura tu cuenta bancaria',
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Registra tu CLABE y sube tu INE para recibir depositos.',
                  style: theme.textTheme.labelSmall?.copyWith(color: kWebTextSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => context.go('/negocio/banking'),
            child: const Text('Configurar'),
          ),
        ],
      ),
    );
  }
}
