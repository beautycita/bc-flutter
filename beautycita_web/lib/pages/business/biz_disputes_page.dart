import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:beautycita_core/theme.dart';

import '../../config/breakpoints.dart';
import '../../providers/business_portal_provider.dart';

/// Selected dispute for detail panel.
final selectedDisputeProvider =
    StateProvider<Map<String, dynamic>?>((ref) => null);

/// Status filter for disputes list.
final disputeStatusFilterProvider = StateProvider<String?>((ref) => null);

/// Business disputes page — list with status filter, detail panel with offer workflow.
class BizDisputesPage extends ConsumerWidget {
  const BizDisputesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bizAsync = ref.watch(currentBusinessProvider);

    return bizAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (biz) {
        if (biz == null) return const Center(child: Text('Sin negocio'));
        return const _DisputesContent();
      },
    );
  }
}

class _DisputesContent extends ConsumerWidget {
  const _DisputesContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disputesAsync = ref.watch(businessDisputesProvider);
    final selected = ref.watch(selectedDisputeProvider);
    final statusFilter = ref.watch(disputeStatusFilterProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = WebBreakpoints.isDesktop(constraints.maxWidth);
        final showPanel = selected != null && isDesktop;

        return Row(
          children: [
            Expanded(
              child: disputesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) =>
                    const Center(child: Text('Error al cargar disputas')),
                data: (disputes) {
                  var filtered = disputes;
                  if (statusFilter != null) {
                    filtered = disputes
                        .where((d) => d['status'] == statusFilter)
                        .toList();
                  }
                  return _DisputesList(
                      disputes: filtered, allCount: disputes.length);
                },
              ),
            ),
            if (showPanel) ...[
              VerticalDivider(
                  width: 1,
                  color: Theme.of(context).colorScheme.outlineVariant),
              SizedBox(
                  width: 420,
                  child: _DisputeDetailPanel(dispute: selected)),
            ],
          ],
        );
      },
    );
  }
}

// ── Disputes List ───────────────────────────────────────────────────────────

class _DisputesList extends ConsumerWidget {
  const _DisputesList({required this.disputes, required this.allCount});
  final List<Map<String, dynamic>> disputes;
  final int allCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final statusFilter = ref.watch(disputeStatusFilterProvider);

    return Column(
      children: [
        // Header
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: colors.outlineVariant))),
          child: Row(
            children: [
              Text('Disputas',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Chip(
                  label: Text('$allCount'),
                  visualDensity: VisualDensity.compact),
            ],
          ),
        ),
        // Filter chips
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: colors.outlineVariant.withValues(alpha: 0.5)))),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final s in [
                null,
                'open',
                'salon_responded',
                'escalated',
                'resolved',
                'rejected'
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(s == null ? 'Todas' : _statusLabel(s)),
                    selected: statusFilter == s,
                    onSelected: (_) => ref
                        .read(disputeStatusFilterProvider.notifier)
                        .state = s,
                  ),
                ),
            ],
          ),
        ),
        // List
        Expanded(
          child: disputes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.gavel_outlined,
                          size: 48,
                          color: colors.onSurface.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text('Sin disputas',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color:
                                  colors.onSurface.withValues(alpha: 0.5))),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: disputes.length,
                  separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: colors.outlineVariant.withValues(alpha: 0.3)),
                  itemBuilder: (_, i) =>
                      _DisputeRow(dispute: disputes[i]),
                ),
        ),
      ],
    );
  }
}

String _statusLabel(String status) {
  return switch (status) {
    'open' => 'Abierta',
    'salon_responded' => 'Respondida',
    'escalated' => 'Escalada',
    'resolved' => 'Resuelta',
    'rejected' => 'Rechazada',
    'under_review' => 'En revision',
    _ => status,
  };
}

Color _statusColor(String status) {
  return switch (status) {
    'open' => const Color(0xFFFF9800),
    'salon_responded' => const Color(0xFF2196F3),
    'escalated' => const Color(0xFF9C27B0),
    'resolved' => const Color(0xFF4CAF50),
    'rejected' => const Color(0xFFE53935),
    'under_review' => const Color(0xFF2196F3),
    _ => Colors.grey,
  };
}

class _DisputeRow extends ConsumerStatefulWidget {
  const _DisputeRow({required this.dispute});
  final Map<String, dynamic> dispute;

  @override
  ConsumerState<_DisputeRow> createState() => _DisputeRowState();
}

class _DisputeRowState extends ConsumerState<_DisputeRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final d = widget.dispute;
    final reason = d['reason'] as String? ?? 'Sin motivo';
    final status = d['status'] as String? ?? '';
    final createdAt = DateTime.tryParse(d['created_at'] as String? ?? '');
    final dateStr =
        createdAt != null ? DateFormat('dd/MM/yy').format(createdAt) : '--';
    final amount = (d['amount'] as num?)?.toDouble();

    final sColor = _statusColor(status);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => ref.read(selectedDisputeProvider.notifier).state = d,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          color: _hovering
              ? colors.primary.withValues(alpha: 0.04)
              : Colors.transparent,
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: sColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reason,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(dateStr,
                        style: theme.textTheme.labelSmall?.copyWith(
                            color:
                                colors.onSurface.withValues(alpha: 0.4))),
                  ],
                ),
              ),
              if (amount != null) ...[
                const SizedBox(width: 8),
                Text('\$${amount.toStringAsFixed(0)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: sColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(
                      fontSize: 11,
                      color: sColor,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Dispute Detail Panel ────────────────────────────────────────────────────

class _DisputeDetailPanel extends ConsumerStatefulWidget {
  const _DisputeDetailPanel({required this.dispute});
  final Map<String, dynamic> dispute;

  @override
  ConsumerState<_DisputeDetailPanel> createState() =>
      _DisputeDetailPanelState();
}

class _DisputeDetailPanelState extends ConsumerState<_DisputeDetailPanel> {
  final _responseCtrl = TextEditingController();
  final _partialAmountCtrl = TextEditingController();
  String? _offerType; // 'full_refund', 'partial_refund', 'denied'
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _initFromDispute();
  }

  @override
  void didUpdateWidget(covariant _DisputeDetailPanel old) {
    super.didUpdateWidget(old);
    if (old.dispute['id'] != widget.dispute['id']) {
      _initFromDispute();
    }
  }

  void _initFromDispute() {
    _responseCtrl.clear();
    _partialAmountCtrl.clear();
    _offerType = null;

    // If there's already an offer, pre-fill
    final existingOffer = widget.dispute['salon_offer'] as String?;
    if (existingOffer != null && existingOffer.isNotEmpty) {
      _offerType = existingOffer;
      final offerAmount =
          (widget.dispute['salon_offer_amount'] as num?)?.toDouble();
      if (offerAmount != null && offerAmount > 0) {
        _partialAmountCtrl.text = offerAmount.toStringAsFixed(0);
      }
    }
  }

  @override
  void dispose() {
    _responseCtrl.dispose();
    _partialAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitOffer() async {
    if (_offerType == null) return;
    final text = _responseCtrl.text.trim();
    if (text.isEmpty && _offerType == 'denied') {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Escribe una respuesta')));
      return;
    }
    setState(() => _submitting = true);

    try {
      final updateData = <String, dynamic>{
        'salon_offer': _offerType,
        'business_response': text,
        'salon_responded_at': DateTime.now().toIso8601String(),
      };

      if (_offerType == 'partial_refund') {
        final amt = double.tryParse(_partialAmountCtrl.text) ?? 0;
        updateData['salon_offer_amount'] = amt;
        updateData['status'] = 'salon_responded';
      } else if (_offerType == 'full_refund') {
        // Auto-resolve with favor_client
        updateData['status'] = 'resolved';
        updateData['resolution'] = 'favor_client';
        updateData['resolved_at'] = DateTime.now().toIso8601String();
        updateData['salon_offer_amount'] =
            (widget.dispute['amount'] as num?)?.toDouble() ?? 0;
      } else {
        // denied
        updateData['status'] = 'salon_responded';
        updateData['salon_offer_amount'] = 0;
      }

      await BCSupabase.client
          .from(BCTables.disputes)
          .update(updateData)
          .eq('id', widget.dispute['id'] as String);

      // Send notification to client (best-effort)
      final customerId = widget.dispute['customer_id'] as String?;
      if (customerId != null) {
        try {
          await BCSupabase.client.from('notifications').insert({
            'user_id': customerId,
            'type': 'dispute_response',
            'title': 'Respuesta a tu disputa',
            'body': _offerType == 'full_refund'
                ? 'El salon ha aceptado un reembolso completo.'
                : _offerType == 'partial_refund'
                    ? 'El salon ha ofrecido un reembolso parcial.'
                    : 'El salon ha respondido a tu disputa.',
            'data': {'dispute_id': widget.dispute['id']},
          });
        } catch (_) {
          // Notification table may not exist yet
        }
      }

      ref.invalidate(businessDisputesProvider);
      if (mounted) {
        _responseCtrl.clear();
        ref.read(selectedDisputeProvider.notifier).state = null;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Respuesta enviada')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final d = widget.dispute;
    final reason = d['reason'] as String? ?? '';
    final description = d['description'] as String? ?? '';
    final status = d['status'] as String? ?? '';
    final amount = (d['amount'] as num?)?.toDouble();
    final createdAt = DateTime.tryParse(d['created_at'] as String? ?? '');
    final businessResponse = d['business_response'] as String?;
    final salonOffer = d['salon_offer'] as String?;
    final salonOfferAmount =
        (d['salon_offer_amount'] as num?)?.toDouble();
    final salonRespondedAt =
        DateTime.tryParse(d['salon_responded_at'] as String? ?? '');
    final clientAccepted = d['client_accepted'] as bool?;
    final clientRespondedAt =
        DateTime.tryParse(d['client_responded_at'] as String? ?? '');
    final resolution = d['resolution'] as String?;
    final resolvedAt =
        DateTime.tryParse(d['resolved_at'] as String? ?? '');
    final adminNotes = d['admin_notes'] as String?;
    final refundAmount =
        (d['refund_amount'] as num?)?.toDouble();
    final refundStatus = d['refund_status'] as String?;

    final hasPreviousOffer = salonOffer != null && salonOffer.isNotEmpty;
    final canRespond = status == 'open' && !hasPreviousOffer;

    return Container(
      color: colors.surface,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: colors.outlineVariant))),
            child: Row(
              children: [
                Expanded(
                    child: Text('Detalle de disputa',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600))),
                IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => ref
                        .read(selectedDisputeProvider.notifier)
                        .state = null),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Escalation banner
                  if (status == 'escalated') ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFF9C27B0).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFF9C27B0)
                                .withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 18, color: Color(0xFF9C27B0)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Escalada — En revision por administrador',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF9C27B0)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Title + status
                  Text(reason,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(status)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_statusLabel(status),
                            style: TextStyle(
                                fontSize: 12,
                                color: _statusColor(status),
                                fontWeight: FontWeight.w600)),
                      ),
                      if (createdAt != null) ...[
                        const SizedBox(width: 8),
                        Text(
                            DateFormat('dd/MM/yyyy HH:mm')
                                .format(createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurface
                                    .withValues(alpha: 0.5))),
                      ],
                    ],
                  ),
                  if (amount != null) ...[
                    const SizedBox(height: 4),
                    Text('Monto: \$${amount.toStringAsFixed(0)}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 16),

                  // Client description
                  if (description.isNotEmpty) ...[
                    Text('Descripcion del cliente',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child:
                          Text(description, style: theme.textTheme.bodySmall),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Previous offer display
                  if (hasPreviousOffer) ...[
                    _PreviousOfferCard(
                      offerType: salonOffer,
                      offerAmount: salonOfferAmount,
                      responseText: businessResponse,
                      respondedAt: salonRespondedAt,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Client acceptance/rejection
                  if (clientAccepted != null) ...[
                    _ClientResponseCard(
                      accepted: clientAccepted,
                      respondedAt: clientRespondedAt,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Resolution card
                  if (status == 'resolved' && resolution != null) ...[
                    _ResolutionCard(
                      resolution: resolution,
                      refundAmount: refundAmount,
                      refundStatus: refundStatus,
                      resolvedAt: resolvedAt,
                      adminNotes: adminNotes,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Offer Form (only for open disputes with no prior offer) ──
                  if (canRespond) ...[
                    const Divider(),
                    const SizedBox(height: 12),
                    Text('Responder',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),

                    // Offer type chips
                    Text('Tipo de oferta',
                        style: theme.textTheme.labelMedium?.copyWith(
                            color:
                                colors.onSurface.withValues(alpha: 0.6))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          avatar: const Icon(Icons.money_off,
                              size: 16, color: Color(0xFF4CAF50)),
                          label: const Text('Reembolso completo'),
                          selected: _offerType == 'full_refund',
                          onSelected: (sel) => setState(() =>
                              _offerType = sel ? 'full_refund' : null),
                        ),
                        ChoiceChip(
                          avatar: const Icon(Icons.attach_money,
                              size: 16, color: Color(0xFFFF9800)),
                          label: const Text('Reembolso parcial'),
                          selected: _offerType == 'partial_refund',
                          onSelected: (sel) => setState(() =>
                              _offerType = sel ? 'partial_refund' : null),
                        ),
                        ChoiceChip(
                          avatar: const Icon(Icons.block,
                              size: 16, color: Color(0xFFE53935)),
                          label: const Text('Rechazar'),
                          selected: _offerType == 'denied',
                          onSelected: (sel) => setState(
                              () => _offerType = sel ? 'denied' : null),
                        ),
                      ],
                    ),

                    // Partial refund amount
                    if (_offerType == 'partial_refund') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _partialAmountCtrl,
                        decoration: InputDecoration(
                          labelText: 'Monto del reembolso',
                          prefixText: '\$ ',
                          helperText: amount != null
                              ? 'Monto original: \$${amount.toStringAsFixed(0)}'
                              : null,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],

                    // Full refund info
                    if (_offerType == 'full_refund') ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50)
                              .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFF4CAF50)
                                  .withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                size: 16, color: Color(0xFF4CAF50)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Se reembolsara \$${(amount ?? 0).toStringAsFixed(0)} al cliente y la disputa se resolvera automaticamente.',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _responseCtrl,
                      decoration: InputDecoration(
                        hintText: _offerType == 'denied'
                            ? 'Explica por que rechazas la disputa...'
                            : 'Mensaje adicional (opcional)...',
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: BCSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _submitting || _offerType == null
                                ? null
                                : _submitOffer,
                        style: _offerType == 'full_refund'
                            ? ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50))
                            : _offerType == 'denied'
                                ? ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color(0xFFE53935))
                                : null,
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : Text(_offerType == 'full_refund'
                                ? 'Reembolsar y resolver'
                                : _offerType == 'partial_refund'
                                    ? 'Enviar oferta'
                                    : _offerType == 'denied'
                                        ? 'Rechazar disputa'
                                        : 'Selecciona tipo de oferta'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Previous Offer Card ─────────────────────────────────────────────────────

class _PreviousOfferCard extends StatelessWidget {
  const _PreviousOfferCard({
    required this.offerType,
    this.offerAmount,
    this.responseText,
    this.respondedAt,
  });
  final String? offerType;
  final double? offerAmount;
  final String? responseText;
  final DateTime? respondedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final offerLabel = switch (offerType) {
      'full_refund' => 'Reembolso completo',
      'partial_refund' => 'Reembolso parcial',
      'denied' => 'Rechazada',
      _ => offerType ?? '',
    };
    final offerColor = switch (offerType) {
      'full_refund' => const Color(0xFF4CAF50),
      'partial_refund' => const Color(0xFFFF9800),
      'denied' => const Color(0xFFE53935),
      _ => Colors.grey,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: colors.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Tu oferta',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: offerColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(offerLabel,
                    style: TextStyle(
                        fontSize: 11,
                        color: offerColor,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          if (offerAmount != null && offerAmount! > 0) ...[
            const SizedBox(height: 4),
            Text('Monto: \$${offerAmount!.toStringAsFixed(0)}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ],
          if (responseText != null && responseText!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(responseText!, style: theme.textTheme.bodySmall),
          ],
          if (respondedAt != null) ...[
            const SizedBox(height: 4),
            Text(
                DateFormat('dd/MM/yyyy HH:mm').format(respondedAt!),
                style: theme.textTheme.labelSmall?.copyWith(
                    color:
                        colors.onSurface.withValues(alpha: 0.4))),
          ],
        ],
      ),
    );
  }
}

// ── Client Response Card ────────────────────────────────────────────────────

class _ClientResponseCard extends StatelessWidget {
  const _ClientResponseCard({
    required this.accepted,
    this.respondedAt,
  });
  final bool accepted;
  final DateTime? respondedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        accepted ? const Color(0xFF4CAF50) : const Color(0xFFE53935);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            accepted ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  accepted
                      ? 'Cliente acepto la oferta'
                      : 'Cliente rechazo la oferta',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color),
                ),
                if (respondedAt != null)
                  Text(
                      DateFormat('dd/MM/yyyy HH:mm')
                          .format(respondedAt!),
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: color.withValues(alpha: 0.7))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Resolution Card ─────────────────────────────────────────────────────────

class _ResolutionCard extends StatelessWidget {
  const _ResolutionCard({
    required this.resolution,
    this.refundAmount,
    this.refundStatus,
    this.resolvedAt,
    this.adminNotes,
  });
  final String resolution;
  final double? refundAmount;
  final String? refundStatus;
  final DateTime? resolvedAt;
  final String? adminNotes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final resolutionLabel = switch (resolution) {
      'favor_client' => 'A favor del cliente',
      'favor_business' => 'A favor del negocio',
      'mutual' => 'Acuerdo mutuo',
      _ => resolution,
    };

    final resolutionColor = switch (resolution) {
      'favor_client' => const Color(0xFFFF9800),
      'favor_business' => const Color(0xFF4CAF50),
      'mutual' => const Color(0xFF2196F3),
      _ => Colors.grey,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_outlined,
                  size: 18, color: Color(0xFF4CAF50)),
              const SizedBox(width: 8),
              Text('Resolucion',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: resolutionColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Text(resolutionLabel,
                style: TextStyle(
                    fontSize: 12,
                    color: resolutionColor,
                    fontWeight: FontWeight.w600)),
          ),
          if (refundAmount != null && refundAmount! > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Reembolso: \$${refundAmount!.toStringAsFixed(0)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                if (refundStatus != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: refundStatus == 'completed'
                          ? const Color(0xFF4CAF50)
                              .withValues(alpha: 0.1)
                          : const Color(0xFFFF9800)
                              .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      refundStatus == 'completed'
                          ? 'Completado'
                          : 'Pendiente',
                      style: TextStyle(
                        fontSize: 10,
                        color: refundStatus == 'completed'
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFFF9800),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (adminNotes != null && adminNotes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Nota del administrador:',
                style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.5))),
            const SizedBox(height: 2),
            Text(adminNotes!, style: theme.textTheme.bodySmall),
          ],
          if (resolvedAt != null) ...[
            const SizedBox(height: 8),
            Text(
                'Resuelto: ${DateFormat('dd/MM/yyyy HH:mm').format(resolvedAt!)}',
                style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.4))),
          ],
        ],
      ),
    );
  }
}
