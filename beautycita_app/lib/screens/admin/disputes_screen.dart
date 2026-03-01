import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/constants.dart';
import '../../providers/admin_provider.dart';
import '../../services/supabase_client.dart';
import '../../services/toast_service.dart';

class DisputesScreen extends ConsumerStatefulWidget {
  const DisputesScreen({super.key});

  @override
  ConsumerState<DisputesScreen> createState() => _DisputesScreenState();
}

class _DisputesScreenState extends ConsumerState<DisputesScreen> {
  String? _statusFilter;

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> disputes) {
    if (_statusFilter == null) return disputes;
    return disputes.where((d) => d['status'] == _statusFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final disputesAsync = ref.watch(adminDisputesProvider);
    final colors = Theme.of(context).colorScheme;

    return disputesAsync.when(
      data: (disputes) {
        int open = 0, salonResponded = 0, escalated = 0, resolved = 0;
        for (final d in disputes) {
          final s = d['status'] as String? ?? 'open';
          switch (s) {
            case 'open':
              open++;
            case 'salon_responded':
              salonResponded++;
            case 'escalated':
              escalated++;
            case 'resolved':
              resolved++;
          }
        }

        final filtered = _filtered(disputes);

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminDisputesProvider),
          child: ListView(
            padding: const EdgeInsets.all(AppConstants.paddingMD),
            children: [
              // Status summary chips
              Row(
                children: [
                  Expanded(
                    child: _SummaryChip(
                      label: 'Todas',
                      count: disputes.length,
                      color: colors.primary,
                      selected: _statusFilter == null,
                      onTap: () => setState(() => _statusFilter = null),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SummaryChip(
                      label: 'Abiertas',
                      count: open,
                      color: Colors.orange,
                      selected: _statusFilter == 'open',
                      onTap: () => setState(() => _statusFilter = 'open'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SummaryChip(
                      label: 'Escaladas',
                      count: escalated,
                      color: Colors.deepPurple,
                      selected: _statusFilter == 'escalated',
                      onTap: () =>
                          setState(() => _statusFilter = 'escalated'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _SummaryChip(
                      label: 'Respondidas',
                      count: salonResponded,
                      color: Colors.blue,
                      selected: _statusFilter == 'salon_responded',
                      onTap: () =>
                          setState(() => _statusFilter = 'salon_responded'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SummaryChip(
                      label: 'Resueltas',
                      count: resolved,
                      color: Colors.green,
                      selected: _statusFilter == 'resolved',
                      onTap: () =>
                          setState(() => _statusFilter = 'resolved'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(child: SizedBox()),
                ],
              ),

              const SizedBox(height: AppConstants.paddingMD),

              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.gavel_rounded,
                            size: 48,
                            color: colors.onSurface.withValues(alpha: 0.2)),
                        const SizedBox(height: 8),
                        Text('Sin disputas',
                            style: GoogleFonts.nunito(
                                color: colors.onSurface
                                    .withValues(alpha: 0.5))),
                      ],
                    ),
                  ),
                )
              else
                for (final d in filtered) ...[
                  _DisputeCard(
                    dispute: d,
                    onTap: () => _showDetail(d),
                  ),
                ],
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child:
            Text('Error: $e', style: GoogleFonts.nunito(color: colors.error)),
      ),
    );
  }

  void _showDetail(Map<String, dynamic> dispute) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DisputeDetailSheet(
        dispute: dispute,
        onChanged: () {
          ref.invalidate(adminDisputesProvider);
          ref.invalidate(adminDashStatsProvider);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary chip
// ---------------------------------------------------------------------------

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _SummaryChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? color.withValues(alpha: 0.1) : Colors.white,
      borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
            border: Border.all(
              color: selected ? color : colors.onSurface.withValues(alpha: 0.1),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dispute card
// ---------------------------------------------------------------------------

class _DisputeCard extends StatelessWidget {
  final Map<String, dynamic> dispute;
  final VoidCallback onTap;

  const _DisputeCard({required this.dispute, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = dispute['status'] as String? ?? 'open';
    final reason = dispute['reason'] as String? ?? 'Sin razon';
    final createdAt = dispute['created_at'] as String?;
    final appt = dispute['appointments'] as Map<String, dynamic>?;
    final serviceName = appt?['service_name'] as String? ?? 'Servicio';
    final businessName =
        (appt?['businesses'] as Map?)?['name'] as String? ?? '';

    String dateStr = '';
    if (createdAt != null) {
      final dt = DateTime.tryParse(createdAt)?.toLocal();
      if (dt != null) {
        dateStr = '${dt.day}/${dt.month}/${dt.year}';
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.paddingSM),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              border: Border.all(
                color: status == 'escalated'
                    ? Colors.deepPurple.withValues(alpha: 0.3)
                    : colors.onSurface.withValues(alpha: 0.08),
                width: status == 'escalated' ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                      status == 'escalated'
                          ? Icons.priority_high_rounded
                          : Icons.gavel_rounded,
                      color: _statusColor(status),
                      size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              serviceName,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colors.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _statusBadge(status),
                        ],
                      ),
                      if (businessName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          businessName,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: colors.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        reason,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          color: colors.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      if (dateStr.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          dateStr,
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            color: colors.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: colors.onSurface.withValues(alpha: 0.3), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _statusColor(status).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _statusLabel(status),
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _statusColor(status),
        ),
      ),
    );
  }

  static Color _statusColor(String status) {
    return switch (status) {
      'open' => Colors.orange,
      'salon_responded' => Colors.blue,
      'escalated' => Colors.deepPurple,
      'resolved' => Colors.green,
      'rejected' => Colors.red,
      _ => Colors.grey,
    };
  }

  static String _statusLabel(String status) {
    return switch (status) {
      'open' => 'Abierta',
      'salon_responded' => 'Respondida',
      'escalated' => 'Escalada',
      'resolved' => 'Resuelta',
      'rejected' => 'Rechazada',
      _ => status,
    };
  }
}

// ---------------------------------------------------------------------------
// Dispute detail bottom sheet — full resolution capabilities
// ---------------------------------------------------------------------------

class _DisputeDetailSheet extends StatefulWidget {
  final Map<String, dynamic> dispute;
  final VoidCallback onChanged;

  const _DisputeDetailSheet({
    required this.dispute,
    required this.onChanged,
  });

  @override
  State<_DisputeDetailSheet> createState() => _DisputeDetailSheetState();
}

class _DisputeDetailSheetState extends State<_DisputeDetailSheet> {
  String? _selectedOutcome;
  bool _refundEnabled = false;
  final _refundAmountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _refundAmountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final d = widget.dispute;
    final status = d['status'] as String? ?? 'open';
    final reason = d['reason'] as String? ?? 'Sin razon';
    final clientEvidence = d['client_evidence'] as String?;
    final stylistEvidence = d['stylist_evidence'] as String?;
    final resolution = d['resolution'] as String?;
    final resolutionNotes = d['resolution_notes'] as String?;
    final refundAmount = d['refund_amount'] as num?;
    final refundStatus = d['refund_status'] as String?;
    final canResolve = status == 'open' || status == 'salon_responded' || status == 'escalated';

    // Salon offer data
    final salonOffer = d['salon_offer'] as String?;
    final salonOfferAmount = d['salon_offer_amount'] as num?;
    final salonResponse = d['salon_response'] as String?;
    final clientAccepted = d['client_accepted'] as bool?;

    // Appointment details
    final appt = d['appointments'] as Map<String, dynamic>?;
    final serviceName = appt?['service_name'] as String? ?? '-';
    final price = appt?['price'] as num?;
    final startsAt = appt?['starts_at'] as String?;
    final clientId = d['user_id'] as String? ?? appt?['user_id'] as String?;
    final biz = appt?['businesses'] as Map<String, dynamic>?;
    final businessName = biz?['name'] as String? ?? '-';
    final businessOwnerId = biz?['owner_id'] as String?;

    String apptDate = '-';
    if (startsAt != null) {
      final dt = DateTime.tryParse(startsAt)?.toLocal();
      if (dt != null) {
        apptDate =
            '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }

    // Pre-fill refund amount with appointment price
    if (_refundAmountCtrl.text.isEmpty && price != null) {
      _refundAmountCtrl.text = price.toStringAsFixed(0);
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(AppConstants.paddingLG),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin:
                      const EdgeInsets.only(bottom: AppConstants.paddingMD),
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Disputa #${(d['id'] as String).substring(0, 8)}',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _DisputeCard._statusColor(status)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _DisputeCard._statusLabel(status),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _DisputeCard._statusColor(status),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppConstants.paddingMD),

              // Appointment info card
              _infoCard(context, 'Detalles de la Cita', [
                _infoRow('Servicio', serviceName),
                _infoRow('Negocio', businessName),
                _infoRow('Fecha', apptDate),
                if (price != null)
                  _infoRow('Precio', '\$${price.toStringAsFixed(0)} MXN'),
                if (clientId != null)
                  _infoRow('Cliente', clientId.substring(0, 8)),
              ]),

              const SizedBox(height: AppConstants.paddingSM),

              // ── Timeline: Full dispute history ──────────────────────────
              Text('Historial de la Disputa',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface.withValues(alpha: 0.5),
                  )),
              const SizedBox(height: 12),

              // 1. Client filed dispute
              _timelineCard(
                stepNumber: '1',
                title: 'Cliente reporto problema',
                color: Colors.orange,
                icon: Icons.flag_rounded,
                children: [
                  _quoteBubble(reason, 'Cliente', Colors.orange),
                  if (clientEvidence != null && clientEvidence.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.attach_file_rounded,
                            size: 14,
                            color: colors.onSurface.withValues(alpha: 0.4)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text('Evidencia adjunta',
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colors.onSurface.withValues(alpha: 0.4),
                              )),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _quoteBubble(clientEvidence, null, Colors.grey),
                  ],
                ],
              ),

              // 2. Salon offer
              if (salonOffer != null) ...[
                _timelineConnector(),
                _timelineCard(
                  stepNumber: '2',
                  title: 'Salon respondio',
                  color: Colors.blue,
                  icon: Icons.local_offer_rounded,
                  children: [
                    // Offer badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: salonOffer == 'denied'
                            ? Colors.red.withValues(alpha: 0.08)
                            : Colors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: salonOffer == 'denied'
                              ? Colors.red.withValues(alpha: 0.2)
                              : Colors.blue.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            salonOffer == 'denied'
                                ? Icons.block_rounded
                                : Icons.monetization_on_rounded,
                            size: 14,
                            color: salonOffer == 'denied'
                                ? Colors.red
                                : Colors.blue,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _offerLabel(salonOffer) +
                                (salonOfferAmount != null
                                    ? '  •  \$${salonOfferAmount.toStringAsFixed(0)} MXN'
                                    : ''),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: salonOffer == 'denied'
                                  ? Colors.red
                                  : Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (salonResponse != null &&
                        salonResponse.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _quoteBubble(salonResponse, 'Salon', Colors.blue),
                    ],
                  ],
                ),
              ],

              // 2b. Old-style business response (before offer system)
              if (stylistEvidence != null &&
                  stylistEvidence.isNotEmpty &&
                  salonOffer == null) ...[
                _timelineConnector(),
                _timelineCard(
                  stepNumber: '2',
                  title: 'Respuesta del negocio',
                  color: Colors.blue,
                  icon: Icons.store_rounded,
                  children: [
                    _quoteBubble(stylistEvidence, 'Salon', Colors.blue),
                  ],
                ),
              ],

              // 3. Client response to offer
              if (clientAccepted != null) ...[
                _timelineConnector(),
                _timelineCard(
                  stepNumber: '3',
                  title: clientAccepted!
                      ? 'Cliente acepto la oferta'
                      : 'Cliente rechazo la oferta',
                  color: clientAccepted! ? Colors.green : Colors.red,
                  icon: clientAccepted!
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: (clientAccepted! ? Colors.green : Colors.red)
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        clientAccepted!
                            ? 'Oferta aceptada — disputa resuelta'
                            : 'Oferta rechazada — escalada a admin',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              clientAccepted! ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // 4. Resolution (if resolved)
              if (resolution != null) ...[
                _timelineConnector(),
                _timelineCard(
                  stepNumber: (clientAccepted != null ? '4' : salonOffer != null ? '3' : '2'),
                  title: 'Resolucion',
                  color: Colors.green.shade700,
                  icon: Icons.gavel_rounded,
                  children: [
                    _infoRow('Resultado', _outcomeLabel(resolution)),
                    if (resolutionNotes != null &&
                        resolutionNotes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _quoteBubble(
                          resolutionNotes, 'Admin', Colors.deepPurple),
                    ],
                    if (refundAmount != null && refundAmount > 0) ...[
                      const SizedBox(height: 4),
                      _infoRow('Reembolso',
                          '\$${refundAmount.toStringAsFixed(0)} MXN'),
                      if (refundStatus != null)
                        _infoRow('Estado', refundStatus),
                    ],
                  ],
                ),
              ],

              const SizedBox(height: AppConstants.paddingSM),

              // (Resolution info is now part of the timeline above)

              // Resolution controls (for open or escalated disputes)
              if (canResolve) ...[
                const SizedBox(height: AppConstants.paddingLG),
                Text(
                    status == 'escalated'
                        ? 'Resolver Disputa Escalada'
                        : 'Resolver Disputa',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    )),
                if (status == 'escalated') ...[
                  const SizedBox(height: 4),
                  Text(
                    'El cliente rechazo la oferta del salon. Tu decides.',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: AppConstants.paddingSM),

                // Outcome selection
                Text('Resultado',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface.withValues(alpha: 0.6),
                    )),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _outcomeChip('favor_client', 'A favor del cliente',
                        Colors.green),
                    _outcomeChip('favor_provider', 'A favor del estilista',
                        Colors.blue),
                    if (status != 'escalated') ...[
                      _outcomeChip(
                          'favor_both', 'A favor de ambos', Colors.teal),
                      _outcomeChip('dismissed', 'Descartar', Colors.grey),
                    ],
                  ],
                ),

                const SizedBox(height: AppConstants.paddingMD),

                // Refund toggle
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusMD),
                    border: Border.all(
                      color: colors.onSurface.withValues(alpha: 0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: Text('Forzar reembolso',
                            style: GoogleFonts.poppins(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          status == 'escalated'
                              ? 'Reembolso desde Stripe Connect del estilista (plataforma cubre hasta \$100 USD)'
                              : 'Devolver pago al cliente via Stripe',
                          style: GoogleFonts.nunito(fontSize: 12),
                        ),
                        value: _refundEnabled,
                        onChanged: (v) =>
                            setState(() => _refundEnabled = v),
                      ),
                      if (_refundEnabled) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: TextField(
                            controller: _refundAmountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Monto a reembolsar (MXN)',
                              prefixText: '\$ ',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                    AppConstants.radiusMD),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: AppConstants.paddingSM),

                // Admin actions
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusMD),
                    border: Border.all(
                      color: colors.onSurface.withValues(alpha: 0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Acciones adicionales',
                          style: GoogleFonts.poppins(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _actionButton(
                              'Suspender cliente',
                              Icons.person_off,
                              Colors.red.shade600,
                              () => _suspendAccount(clientId, 'cliente'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _actionButton(
                              'Suspender negocio',
                              Icons.store_outlined,
                              Colors.orange.shade700,
                              () => _suspendAccount(
                                  businessOwnerId, 'negocio'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: _actionButton(
                          'Retener pagos del negocio',
                          Icons.money_off,
                          Colors.deepPurple,
                          () => _withholdPayouts(d['business_id'] as String?),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppConstants.paddingSM),

                // Notes
                TextField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Notas del admin (opcional)',
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMD),
                    ),
                  ),
                ),

                const SizedBox(height: AppConstants.paddingMD),

                // Resolve button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _selectedOutcome != null && !_saving
                            ? _resolveDispute
                            : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      disabledBackgroundColor: Colors.grey.shade300,
                      minimumSize:
                          const Size(0, AppConstants.minTouchHeight),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusLG),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(
                            'Resolver Disputa',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],

              const SizedBox(height: AppConstants.paddingXL),
            ],
          ),
        );
      },
    );
  }

  /// A full timeline card with step number, icon, title, and child content.
  Widget _timelineCard({
    required String stepNumber,
    required String title,
    required Color color,
    required IconData icon,
    required List<Widget> children,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(stepNumber,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
                        )),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(title,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface.withValues(alpha: 0.8),
                      )),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  /// Vertical connector line between timeline cards.
  Widget _timelineConnector() {
    return Padding(
      padding: const EdgeInsets.only(left: 22),
      child: Container(
        width: 2,
        height: 20,
        color: Theme.of(context)
            .colorScheme
            .onSurface
            .withValues(alpha: 0.12),
      ),
    );
  }

  /// A styled quote bubble for user/salon/admin text.
  Widget _quoteBubble(String text, String? author, Color accentColor) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: accentColor.withValues(alpha: 0.4), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (author != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(author,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: accentColor.withValues(alpha: 0.7),
                    letterSpacing: 0.5,
                  )),
            ),
          Text(text,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.8),
                height: 1.4,
              )),
        ],
      ),
    );
  }

  String _offerLabel(String offer) {
    return switch (offer) {
      'full_refund' => 'Reembolso total',
      'partial_refund' => 'Reembolso parcial',
      'denied' => 'Reembolso negado',
      _ => offer,
    };
  }

  Widget _outcomeChip(String value, String label, Color color) {
    final isSelected = _selectedOutcome == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: color.withValues(alpha: 0.15),
      labelStyle: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        color: isSelected ? color : null,
      ),
      onSelected: (_) => setState(() => _selectedOutcome = value),
    );
  }

  Widget _actionButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label,
          style: GoogleFonts.nunito(
              fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _infoCard(
      BuildContext context, String title, List<Widget> children) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(
          color: colors.onSurface.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colors.onSurface.withValues(alpha: 0.5),
              )),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: colors.onSurface.withValues(alpha: 0.5),
                )),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                )),
          ),
        ],
      ),
    );
  }

  String _outcomeLabel(String resolution) {
    return switch (resolution) {
      'favor_client' => 'A favor del cliente',
      'favor_provider' => 'A favor del estilista',
      'favor_both' => 'A favor de ambos',
      'dismissed' => 'Descartada',
      _ => resolution,
    };
  }

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  Future<void> _resolveDispute() async {
    if (_selectedOutcome == null) return;
    setState(() => _saving = true);

    try {
      final disputeId = widget.dispute['id'] as String;
      final adminId = SupabaseClientService.currentUserId;

      // Update dispute
      await SupabaseClientService.client.from('disputes').update({
        'status': 'resolved',
        'resolution': _selectedOutcome,
        'resolution_notes': _notesCtrl.text.trim().isEmpty
            ? null
            : _notesCtrl.text.trim(),
        'resolved_by': adminId,
        'resolved_at': DateTime.now().toIso8601String(),
        'refund_amount': _refundEnabled
            ? double.tryParse(_refundAmountCtrl.text) ?? 0
            : null,
        'refund_status': _refundEnabled ? 'pending' : null,
      }).eq('id', disputeId);

      // Log audit
      await adminLogAction(
        action: 'resolve_dispute',
        targetType: 'dispute',
        targetId: disputeId,
        details: {
          'resolution': _selectedOutcome,
          'was_escalated': widget.dispute['status'] == 'escalated',
          'refund_requested': _refundEnabled,
          if (_refundEnabled)
            'refund_amount': double.tryParse(_refundAmountCtrl.text) ?? 0,
        },
      );

      // If refund enabled, update the appointment payment status and process Stripe refund
      if (_refundEnabled) {
        final appointmentId =
            widget.dispute['appointment_id'] as String?;
        if (appointmentId != null) {
          await SupabaseClientService.client
              .from('appointments')
              .update({'payment_status': 'refund_pending'})
              .eq('id', appointmentId);
        }

        // Process the actual Stripe refund via edge function
        try {
          await SupabaseClientService.client.functions.invoke(
            'process-dispute-refund',
            body: {'dispute_id': disputeId},
          );
        } catch (refundErr, refundStack) {
          debugPrint('Dispute refund processing failed: $refundErr');
          ToastService.showErrorWithDetails('Disputa resuelta, pero el reembolso fallo', refundErr, refundStack);
        }
      }

      widget.onChanged();
      if (mounted) {
        Navigator.pop(context);
        ToastService.showSuccess('Disputa resuelta: ${_outcomeLabel(_selectedOutcome!)}');
      }
    } catch (e, stack) {
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _suspendAccount(String? userId, String label) async {
    if (userId == null) {
      ToastService.showWarning('ID de usuario no disponible');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Suspender $label'),
        content: Text(
            'Esto suspenderia la cuenta del $label inmediatamente. Continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Suspender',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await SupabaseClientService.client
          .from('profiles')
          .update({'status': 'suspended'})
          .eq('id', userId);

      await adminLogAction(
        action: 'suspend_account',
        targetType: 'profile',
        targetId: userId,
        details: {
          'reason': 'dispute_${widget.dispute['id']}',
          'label': label,
        },
      );

      ToastService.showSuccess('Cuenta de $label suspendida');
    } catch (e, stack) {
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
    }
  }

  Future<void> _withholdPayouts(String? businessId) async {
    if (businessId == null) {
      ToastService.showWarning('ID de negocio no disponible');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retener pagos'),
        content: const Text(
            'Esto deshabilitaria los pagos al negocio via Stripe. '
            'Los fondos se retendran hasta que se reactive manualmente. Continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple),
            child: const Text('Retener pagos',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await SupabaseClientService.client
          .from('businesses')
          .update({'stripe_payouts_enabled': false})
          .eq('id', businessId);

      await adminLogAction(
        action: 'withhold_payouts',
        targetType: 'business',
        targetId: businessId,
        details: {'reason': 'dispute_${widget.dispute['id']}'},
      );

      ToastService.showSuccess('Pagos al negocio retenidos');
    } catch (e, stack) {
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
    }
  }
}
