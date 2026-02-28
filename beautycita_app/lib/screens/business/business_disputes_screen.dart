import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/constants.dart';
import '../../providers/business_provider.dart';
import '../../services/supabase_client.dart';

class BusinessDisputesScreen extends ConsumerStatefulWidget {
  const BusinessDisputesScreen({super.key});

  @override
  ConsumerState<BusinessDisputesScreen> createState() =>
      _BusinessDisputesScreenState();
}

class _BusinessDisputesScreenState
    extends ConsumerState<BusinessDisputesScreen> {
  String? _statusFilter; // null = all

  @override
  Widget build(BuildContext context) {
    final disputesAsync = ref.watch(businessDisputesProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: disputesAsync.when(
        data: (disputes) {
          final filtered = _statusFilter == null
              ? disputes
              : disputes
                  .where((d) => d['status'] == _statusFilter)
                  .toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(businessDisputesProvider),
            child: ListView(
              padding: const EdgeInsets.all(AppConstants.paddingMD),
              children: [
                // Status filter chips
                Wrap(
                  spacing: 8,
                  children: [
                    _filterChip('Todas', null),
                    _filterChip('Abiertas', 'open'),
                    _filterChip('Respondidas', 'salon_responded'),
                    _filterChip('Escaladas', 'escalated'),
                    _filterChip('Resueltas', 'resolved'),
                    _filterChip('Rechazadas', 'rejected'),
                  ],
                ),
                const SizedBox(height: AppConstants.paddingMD),

                if (filtered.isEmpty)
                  _emptyState(colors)
                else
                  for (final dispute in filtered)
                    _DisputeCard(
                      dispute: dispute,
                      onTap: () =>
                          _showDisputeDetail(context, ref, dispute),
                    ),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: GoogleFonts.nunito(color: colors.error)),
        ),
      ),
    );
  }

  Widget _filterChip(String label, String? status) {
    final colors = Theme.of(context).colorScheme;
    final selected = _statusFilter == status;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _statusFilter = status),
      selectedColor: colors.primary.withValues(alpha: 0.15),
      checkmarkColor: colors.primary,
      labelStyle: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        color: selected ? colors.primary : colors.onSurface,
      ),
    );
  }

  Widget _emptyState(ColorScheme colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            Icon(Icons.gavel_rounded,
                size: 48,
                color: colors.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: AppConstants.paddingSM),
            Text(
              'Sin disputas',
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDisputeDetail(
      BuildContext context, WidgetRef ref, Map<String, dynamic> dispute) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          _DisputeDetailSheet(dispute: dispute, onChanged: () {
            ref.invalidate(businessDisputesProvider);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Oferta enviada'),
                backgroundColor: Colors.green.shade600,
              ),
            );
          }),
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
    final id = (dispute['id'] as String?)?.substring(0, 8) ?? '';

    String dateStr = '';
    if (createdAt != null) {
      final dt = DateTime.tryParse(createdAt);
      if (dt != null) dateStr = '${dt.day}/${dt.month}/${dt.year}';
    }

    return Card(
      elevation: 0,
      color: colors.surface,
      margin: const EdgeInsets.only(bottom: AppConstants.paddingSM),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        side: BorderSide(
          color: colors.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _statusColor(status).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.gavel_rounded,
              color: _statusColor(status), size: 20),
        ),
        title: Row(
          children: [
            Text(
              '#$id',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 8),
            _statusBadge(status),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              reason,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.7),
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
        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      ),
    );
  }

  Widget _statusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _statusColor(status).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _statusLabel(status),
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _statusColor(status),
        ),
      ),
    );
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.orange;
      case 'salon_responded':
        return Colors.blue;
      case 'escalated':
        return Colors.deepPurple;
      case 'resolved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'open':
        return 'Abierta';
      case 'salon_responded':
        return 'Respondida';
      case 'escalated':
        return 'Escalada';
      case 'resolved':
        return 'Resuelta';
      case 'rejected':
        return 'Rechazada';
      default:
        return status;
    }
  }
}

// ---------------------------------------------------------------------------
// Dispute detail bottom sheet — with salon offer form
// ---------------------------------------------------------------------------

class _DisputeDetailSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> dispute;
  final VoidCallback onChanged;

  const _DisputeDetailSheet({
    required this.dispute,
    required this.onChanged,
  });

  @override
  ConsumerState<_DisputeDetailSheet> createState() =>
      _DisputeDetailSheetState();
}

class _DisputeDetailSheetState extends ConsumerState<_DisputeDetailSheet> {
  final _responseCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String? _selectedOffer; // 'full_refund', 'partial_refund', 'denied'
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _responseCtrl.text =
        widget.dispute['stylist_evidence'] as String? ?? '';
    // Pre-fill amount from appointment price if available
    final appt = widget.dispute['appointments'] as Map<String, dynamic>?;
    final price = appt?['price'] as num?;
    if (price != null) {
      _amountCtrl.text = price.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _responseCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dispute = widget.dispute;
    final status = dispute['status'] as String? ?? 'open';
    final reason = dispute['reason'] as String? ?? '';
    final clientEvidence = dispute['client_evidence'] as String? ?? '';
    final resolution = dispute['resolution'] as String?;
    final isOpen = status == 'open';

    // Salon offer data (for past-open states)
    final salonOffer = dispute['salon_offer'] as String?;
    final salonOfferAmount = dispute['salon_offer_amount'] as num?;
    final salonResponse = dispute['salon_response'] as String?;

    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final keyboardOpen = keyboardHeight > 0;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: DraggableScrollableSheet(
        initialChildSize: keyboardOpen ? 0.95 : 0.8,
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

              Text(
                'Detalle de Disputa',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: AppConstants.paddingMD),

              // Info rows
              _infoRow('Estado', _DisputeCard._statusLabel(status),
                  _DisputeCard._statusColor(status)),
              _infoRow(
                  'ID', (dispute['id'] as String?)?.substring(0, 8) ?? ''),
              if (dispute['appointment_id'] != null)
                _infoRow('Cita',
                    (dispute['appointment_id'] as String).substring(0, 8)),

              const SizedBox(height: AppConstants.paddingMD),

              // Reason
              _sectionLabel('Razon del cliente'),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  reason.isEmpty ? 'Sin razon proporcionada' : reason,
                  style: GoogleFonts.nunito(fontSize: 14),
                ),
              ),

              if (clientEvidence.isNotEmpty) ...[
                const SizedBox(height: AppConstants.paddingMD),
                _sectionLabel('Evidencia del cliente'),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(clientEvidence,
                      style: GoogleFonts.nunito(fontSize: 14)),
                ),
              ],

              const SizedBox(height: AppConstants.paddingMD),

              // Show salon's previous offer if already submitted
              if (salonOffer != null) ...[
                _sectionLabel('Tu oferta'),
                const SizedBox(height: 4),
                _offerSummaryCard(
                    salonOffer, salonOfferAmount, salonResponse, colors),
                const SizedBox(height: AppConstants.paddingMD),
              ],

              // Offer form (only for open disputes)
              if (isOpen) ...[
                _sectionLabel('Tu oferta de resolucion'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _offerChip('full_refund', 'Reembolso total',
                        Colors.green),
                    _offerChip('partial_refund', 'Reembolso parcial',
                        Colors.orange),
                    _offerChip('denied', 'Negar reembolso', Colors.red),
                  ],
                ),
                if (_selectedOffer == 'partial_refund') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Monto a reembolsar (MXN)',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusMD),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _responseCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Explica tu decision...',
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMD),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _selectedOffer != null && !_saving
                            ? _submitOffer
                            : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
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
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(
                            'Enviar Oferta',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],

              if (resolution != null) ...[
                const SizedBox(height: AppConstants.paddingMD),
                _sectionLabel('Resolucion'),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.green.withValues(alpha: 0.2)),
                  ),
                  child: Text(resolution,
                      style: GoogleFonts.nunito(fontSize: 14)),
                ),
              ],

              const SizedBox(height: AppConstants.paddingXL),
            ],
          ),
        );
      },
      ),
    );
  }

  Widget _offerChip(String value, String label, Color color) {
    final isSelected = _selectedOffer == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: color.withValues(alpha: 0.15),
      labelStyle: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        color: isSelected ? color : null,
      ),
      onSelected: (_) => setState(() => _selectedOffer = value),
    );
  }

  Widget _offerSummaryCard(String offerType, num? amount, String? response,
      ColorScheme colors) {
    final offerLabel = switch (offerType) {
      'full_refund' => 'Reembolso total',
      'partial_refund' => 'Reembolso parcial',
      'denied' => 'Reembolso negado',
      _ => offerType,
    };
    final offerColor = switch (offerType) {
      'full_refund' => Colors.green,
      'partial_refund' => Colors.orange,
      'denied' => Colors.red,
      _ => Colors.grey,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: offerColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: offerColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_offer_rounded, size: 16, color: offerColor),
              const SizedBox(width: 6),
              Text(offerLabel,
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: offerColor)),
            ],
          ),
          if (offerType == 'partial_refund' && amount != null) ...[
            const SizedBox(height: 4),
            Text('\$${amount.toStringAsFixed(0)} MXN',
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w700)),
          ],
          if (response != null && response.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(response, style: GoogleFonts.nunito(fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, [Color? valueColor]) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
        color: Theme.of(context)
            .colorScheme
            .onSurface
            .withValues(alpha: 0.4),
      ),
    );
  }

  Future<void> _submitOffer() async {
    if (_selectedOffer == null) return;

    final responseText = _responseCtrl.text.trim();
    if (responseText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe una explicacion')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final disputeId = widget.dispute['id'] as String;
      final now = DateTime.now().toIso8601String();

      final updateData = <String, dynamic>{
        'salon_offer': _selectedOffer,
        'salon_response': responseText,
        'salon_offered_at': now,
        'stylist_evidence': responseText,
      };

      if (_selectedOffer == 'full_refund') {
        // Auto-resolve: full refund — look up price from the appointment
        final apptId = widget.dispute['appointment_id'] as String?;
        double price = 0;
        if (apptId != null) {
          try {
            final apptRow = await SupabaseClientService.client
                .from('appointments')
                .select('price')
                .eq('id', apptId)
                .maybeSingle();
            price = (apptRow?['price'] as num?)?.toDouble() ?? 0;
          } catch (_) {}
        }
        updateData['status'] = 'resolved';
        updateData['resolution'] = 'favor_client';
        updateData['refund_amount'] = price;
        updateData['refund_status'] = 'pending';
        updateData['resolved_at'] = now;
        updateData['salon_offer_amount'] = price;
      } else if (_selectedOffer == 'partial_refund') {
        final amount = double.tryParse(_amountCtrl.text) ?? 0;
        if (amount <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ingresa un monto valido')),
          );
          setState(() => _saving = false);
          return;
        }
        updateData['status'] = 'salon_responded';
        updateData['salon_offer_amount'] = amount;
      } else {
        // denied
        updateData['status'] = 'salon_responded';
      }

      await SupabaseClientService.client
          .from('disputes')
          .update(updateData)
          .eq('id', disputeId);

      // Notify client (in-app notification) — non-blocking
      final clientId = widget.dispute['user_id'] as String?;
      if (clientId != null) {
        SupabaseClientService.client.from('notifications').insert({
          'user_id': clientId,
          'title': 'Respuesta a tu disputa',
          'body': _selectedOffer == 'full_refund'
              ? 'El salon acepto un reembolso total. Tu disputa fue resuelta.'
              : 'El salon respondio a tu disputa. Revisa la oferta.',
          'channel': 'in_app',
        }).then((_) {}).catchError((_) {});
      }

      widget.onChanged();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
