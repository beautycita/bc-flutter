import 'package:beautycita_core/theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../providers/admin_disputes_provider.dart';

/// Detail panel content for a selected dispute.
///
/// Shows dispute info, linked booking, client/salon info,
/// resolution workflow, and status timeline.
class DisputeDetailContent extends StatefulWidget {
  const DisputeDetailContent({required this.dispute, super.key});
  final Dispute dispute;

  @override
  State<DisputeDetailContent> createState() => _DisputeDetailContentState();
}

class _DisputeDetailContentState extends State<DisputeDetailContent> {
  String? _resolutionDecision;
  final _notesController = TextEditingController();
  final _refundAmountController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    _refundAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final d = widget.dispute;
    final dateFmt = DateFormat('d MMM yyyy, HH:mm', 'es');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Status badge ──────────────────────────────────────────────────
        _StatusChip(status: d.status, label: d.statusLabel),
        const SizedBox(height: BCSpacing.lg),

        // ── Dispute info ──────────────────────────────────────────────────
        _SectionTitle('Informacion de la disputa'),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow('Tipo', d.typeLabel),
        _InfoRow('Monto', '\$${d.amount.toStringAsFixed(2)} MXN'),
        _InfoRow('Fecha', dateFmt.format(d.filedAt)),
        if (d.bookingRef != null) _InfoRow('Reserva', d.bookingRef!),
        const SizedBox(height: BCSpacing.sm),
        Text(
          'Descripcion:',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: BCSpacing.xs),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(BCSpacing.sm),
          decoration: BoxDecoration(
            color: colors.onSurface.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
          ),
          child: Text(
            d.description.isNotEmpty ? d.description : 'Sin descripcion',
            style: theme.textTheme.bodySmall,
          ),
        ),
        if (d.evidence != null) ...[
          const SizedBox(height: BCSpacing.sm),
          Text(
            'Evidencia:',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: BCSpacing.xs),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(BCSpacing.sm),
            decoration: BoxDecoration(
              color: colors.onSurface.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
            ),
            child: Text(d.evidence!, style: theme.textTheme.bodySmall),
          ),
        ],

        const SizedBox(height: BCSpacing.lg),
        const Divider(),
        const SizedBox(height: BCSpacing.md),

        // ── Client & Salon info ──────────────────────────────────────────
        _SectionTitle('Partes involucradas'),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow('Cliente', d.clientName),
        _InfoRow('Salon', d.salonName),

        // ── Salon offer section ──────────────────────────────────────────
        if (d.salonOffer != null) ...[
          const SizedBox(height: BCSpacing.lg),
          const Divider(),
          const SizedBox(height: BCSpacing.md),
          _SectionTitle('Oferta del salon'),
          const SizedBox(height: BCSpacing.sm),
          _InfoRow('Tipo de oferta', d.salonOfferLabel),
          if (d.salonOfferAmount != null)
            _InfoRow('Monto ofrecido',
                '\$${d.salonOfferAmount!.toStringAsFixed(2)} MXN'),
          if (d.salonResponse != null && d.salonResponse!.isNotEmpty) ...[
            const SizedBox(height: BCSpacing.sm),
            Text(
              'Explicacion del salon:',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: BCSpacing.xs),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(BCSpacing.sm),
              decoration: BoxDecoration(
                color: colors.onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
              ),
              child: Text(d.salonResponse!, style: theme.textTheme.bodySmall),
            ),
          ],
          if (d.salonOfferedAt != null)
            _InfoRow('Oferta enviada', dateFmt.format(d.salonOfferedAt!)),
        ],

        // ── Client response to offer ────────────────────────────────────
        if (d.clientAccepted != null) ...[
          const SizedBox(height: BCSpacing.sm),
          _InfoRow(
            'Respuesta cliente',
            d.clientAccepted! ? 'Acepto la oferta' : 'Rechazo la oferta',
          ),
          if (d.clientRespondedAt != null)
            _InfoRow('Respondio', dateFmt.format(d.clientRespondedAt!)),
        ],

        // ── Escalation info ──────────────────────────────────────────────
        if (d.status == 'escalated') ...[
          const SizedBox(height: BCSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(BCSpacing.sm),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE7F6),
              borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
              border: Border.all(color: const Color(0xFF7C4DFF).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.priority_high_rounded,
                    color: Color(0xFF7C4DFF), size: 18),
                const SizedBox(width: BCSpacing.xs),
                Expanded(
                  child: Text(
                    'Cliente rechazo la oferta del salon. Requiere decision administrativa.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF4A148C),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (d.escalatedAt != null)
            _InfoRow('Escalada', dateFmt.format(d.escalatedAt!)),
        ],

        const SizedBox(height: BCSpacing.lg),
        const Divider(),
        const SizedBox(height: BCSpacing.md),

        // ── Resolution workflow ──────────────────────────────────────────
        if (d.status == 'open' || d.status == 'reviewing' || d.status == 'escalated') ...[
          _SectionTitle('Resolucion'),
          const SizedBox(height: BCSpacing.sm),

          // "Revisar" button (only if status is open)
          if (d.status == 'open') ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  // TODO: Update status to 'reviewing'
                },
                icon: const Icon(Icons.visibility),
                label: const Text('Marcar en revision'),
              ),
            ),
            const SizedBox(height: BCSpacing.md),
          ],

          // Resolution form
          Text(
            'Decision',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: BCSpacing.xs),
          DropdownButtonFormField<String>(
            initialValue: _resolutionDecision,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Seleccionar decision',
            ),
            items: const [
              DropdownMenuItem(
                value: 'refund_full',
                child: Text('Reembolso total'),
              ),
              DropdownMenuItem(
                value: 'refund_partial',
                child: Text('Reembolso parcial'),
              ),
              DropdownMenuItem(
                value: 'reject',
                child: Text('Rechazar disputa'),
              ),
            ],
            onChanged: (v) => setState(() => _resolutionDecision = v),
          ),

          if (_resolutionDecision == 'refund_partial') ...[
            const SizedBox(height: BCSpacing.md),
            TextField(
              controller: _refundAmountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Monto de reembolso',
                prefixText: '\$ ',
                suffixText: 'MXN',
                border: OutlineInputBorder(),
              ),
            ),
          ],

          const SizedBox(height: BCSpacing.md),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notas de resolucion',
              hintText: 'Explicacion de la decision...',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: BCSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _resolutionDecision != null
                  ? () {
                      // TODO: Execute resolution
                    }
                  : null,
              icon: const Icon(Icons.gavel),
              label: const Text('Resolver'),
            ),
          ),

          const SizedBox(height: BCSpacing.lg),
          const Divider(),
          const SizedBox(height: BCSpacing.md),
        ],

        // ── Resolution result (if resolved/rejected) ────────────────────
        if (d.status == 'resolved' || d.status == 'rejected') ...[
          _SectionTitle('Resultado'),
          const SizedBox(height: BCSpacing.sm),
          if (d.resolutionDecision != null)
            _InfoRow(
              'Decision',
              switch (d.resolutionDecision) {
                'refund_full' => 'Reembolso total',
                'refund_partial' => 'Reembolso parcial',
                'reject' => 'Rechazada',
                _ => d.resolutionDecision!,
              },
            ),
          if (d.refundAmount != null)
            _InfoRow(
              'Monto reembolsado',
              '\$${d.refundAmount!.toStringAsFixed(2)} MXN',
            ),
          if (d.resolutionNotes != null && d.resolutionNotes!.isNotEmpty) ...[
            const SizedBox(height: BCSpacing.sm),
            Text(
              'Notas:',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: BCSpacing.xs),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(BCSpacing.sm),
              decoration: BoxDecoration(
                color: colors.onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
              ),
              child: Text(
                d.resolutionNotes!,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
          if (d.resolvedAt != null)
            _InfoRow('Resuelto', dateFmt.format(d.resolvedAt!)),

          const SizedBox(height: BCSpacing.lg),
          const Divider(),
          const SizedBox(height: BCSpacing.md),
        ],

        // ── Timeline ────────────────────────────────────────────────────
        _SectionTitle('Historial'),
        const SizedBox(height: BCSpacing.sm),
        if (d.timeline.isEmpty)
          Text(
            'Sin historial de cambios',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.4),
            ),
          )
        else
          for (final entry in d.timeline) ...[
            _TimelineEntry(entry: entry),
            if (entry != d.timeline.last) const SizedBox(height: BCSpacing.sm),
          ],

        const SizedBox(height: BCSpacing.lg),
      ],
    );
  }
}

// ── Helper widgets ───────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: BCSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.label});
  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (status) {
      'open' => (const Color(0xFFFFF3E0), const Color(0xFFE65100)),
      'salon_responded' => (const Color(0xFFE3F2FD), const Color(0xFF1565C0)),
      'escalated' => (const Color(0xFFEDE7F6), const Color(0xFF4A148C)),
      'reviewing' => (const Color(0xFFE3F2FD), const Color(0xFF1565C0)),
      'resolved' => (const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
      'rejected' => (const Color(0xFFFFEBEE), const Color(0xFFC62828)),
      _ => (Colors.grey.shade100, Colors.grey.shade700),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({required this.entry});
  final DisputeTimelineEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dateFmt = DateFormat('d MMM, HH:mm', 'es');

    final statusLabel = switch (entry.status) {
      'open' => 'Disputa abierta',
      'salon_responded' => 'Salon respondio',
      'escalated' => 'Escalada a admin',
      'reviewing' => 'En revision',
      'resolved' => 'Resuelta',
      'rejected' => 'Rechazada',
      _ => entry.status,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.primary,
          ),
        ),
        const SizedBox(width: BCSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    statusLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    dateFmt.format(entry.timestamp),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
              if (entry.actorName != null)
                Text(
                  'por ${entry.actorName}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              if (entry.note != null && entry.note!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  entry.note!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
