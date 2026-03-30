import 'package:beautycita_core/supabase.dart';
import 'package:beautycita_core/theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../providers/admin_bookings_provider.dart';

/// Detail panel content for a selected booking in the admin bookings page.
class BookingDetailContent extends StatefulWidget {
  const BookingDetailContent({
    required this.booking,
    this.onChanged,
    super.key,
  });

  final AdminBooking booking;
  final VoidCallback? onChanged;

  @override
  State<BookingDetailContent> createState() => _BookingDetailContentState();
}

class _BookingDetailContentState extends State<BookingDetailContent> {
  bool _isProcessing = false;

  AdminBooking get booking => widget.booking;

  /// Cancel booking with typed confirmation.
  Future<void> _cancelBooking() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmCancelDialog(),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await BCSupabase.client.from(BCTables.appointments).update({
        'status': 'cancelled',
        'cancelled_at': now,
        'cancelled_by': 'admin',
        'updated_at': now,
      }).eq('id', booking.id);

      // If payment was made, trigger refund via edge function
      if (booking.paymentStatus == 'paid') {
        try {
          // Create a dispute-like record or call refund directly
          // First check if there's an existing dispute for this appointment
          final disputes = await BCSupabase.client
              .from(BCTables.disputes)
              .select('id')
              .eq('appointment_id', booking.id)
              .limit(1);

          if ((disputes as List).isNotEmpty) {
            await BCSupabase.client.functions.invoke(
              'process-dispute-refund',
              body: {'dispute_id': disputes[0]['id']},
            );
          } else {
            // Update payment status to refund_pending for manual processing
            await BCSupabase.client.from(BCTables.appointments).update({
              'payment_status': 'refund_pending',
            }).eq('id', booking.id);
          }
        } catch (refundErr) {
          debugPrint('Refund after cancel failed: $refundErr');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Reserva cancelada, pero el reembolso fallo: $refundErr'),
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }

      widget.onChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reserva cancelada')),
        );
      }

      // Fire-and-forget: notify customer + stylist of cancellation
      BCSupabase.client.functions.invoke(
        'cancel-notification',
        body: {'appointment_id': booking.id},
      ).then((_) {}).catchError((e) { debugPrint('[Cancel] Notification error: $e'); });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cancelar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Refund without cancellation.
  Future<void> _processRefund() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Procesar reembolso'),
        content: Text(
          'Se procesara un reembolso para la reserva #${booking.shortId}. '
          'La reserva NO sera cancelada. Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reembolsar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      // Check for existing dispute linked to this appointment
      final disputes = await BCSupabase.client
          .from(BCTables.disputes)
          .select('id')
          .eq('appointment_id', booking.id)
          .limit(1);

      if ((disputes as List).isNotEmpty) {
        // Mark dispute for refund and invoke edge function
        await BCSupabase.client.from(BCTables.disputes).update({
          'refund_status': 'pending',
        }).eq('id', disputes[0]['id']);

        await BCSupabase.client.functions.invoke(
          'process-dispute-refund',
          body: {'dispute_id': disputes[0]['id']},
        );
      } else {
        // No dispute exists -- mark appointment for refund pending
        await BCSupabase.client.from(BCTables.appointments).update({
          'payment_status': 'refund_pending',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', booking.id);
      }

      widget.onChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reembolso procesado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al reembolsar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dateFormat = DateFormat('d MMM yyyy, HH:mm', 'es');
    final currencyFormat = NumberFormat.currency(
      locale: 'es_MX',
      symbol: r'$',
      decimalDigits: 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Status header ───────────────────────────────────────────────
        Center(
          child: Column(
            children: [
              _StatusIcon(status: booking.status),
              const SizedBox(height: BCSpacing.sm),
              _StatusBadge(status: booking.status, large: true),
              const SizedBox(height: BCSpacing.xs),
              Text(
                'ID: ${booking.shortId}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.5),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: BCSpacing.lg),
        const Divider(),
        const SizedBox(height: BCSpacing.md),

        // ── Service details ─────────────────────────────────────────────
        _SectionTitle(title: 'Servicio'),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.content_cut,
          label: 'Servicio',
          value: booking.service,
        ),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.schedule,
          label: 'Fecha y hora',
          value: dateFormat.format(booking.dateTime),
        ),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.timer_outlined,
          label: 'Duracion',
          value: '${booking.durationMinutes} min',
        ),
        if (booking.notes != null && booking.notes!.isNotEmpty) ...[
          const SizedBox(height: BCSpacing.sm),
          _InfoRow(
            icon: Icons.notes,
            label: 'Notas',
            value: booking.notes!,
          ),
        ],

        const SizedBox(height: BCSpacing.lg),
        const Divider(),
        const SizedBox(height: BCSpacing.md),

        // ── Client info ─────────────────────────────────────────────────
        _SectionTitle(title: 'Cliente'),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.person_outline,
          label: 'Nombre',
          value: booking.clientName,
        ),
        if (booking.clientId != null) ...[
          const SizedBox(height: BCSpacing.sm),
          _InfoRow(
            icon: Icons.fingerprint,
            label: 'ID',
            value: booking.clientId!.length > 8
                ? '${booking.clientId!.substring(0, 8)}...'
                : booking.clientId!,
          ),
        ],

        const SizedBox(height: BCSpacing.lg),
        const Divider(),
        const SizedBox(height: BCSpacing.md),

        // ── Salon info ──────────────────────────────────────────────────
        _SectionTitle(title: 'Salon'),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.store_outlined,
          label: 'Nombre',
          value: booking.salonName,
        ),
        if (booking.salonId != null) ...[
          const SizedBox(height: BCSpacing.sm),
          _InfoRow(
            icon: Icons.fingerprint,
            label: 'ID',
            value: booking.salonId!.length > 8
                ? '${booking.salonId!.substring(0, 8)}...'
                : booking.salonId!,
          ),
        ],

        const SizedBox(height: BCSpacing.lg),
        const Divider(),
        const SizedBox(height: BCSpacing.md),

        // ── Payment info ────────────────────────────────────────────────
        _SectionTitle(title: 'Pago'),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.attach_money,
          label: 'Monto',
          value: currencyFormat.format(booking.amount),
        ),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.payment,
          label: 'Metodo',
          value: _paymentMethodLabel(booking.paymentMethod),
        ),
        const SizedBox(height: BCSpacing.sm),
        Row(
          children: [
            Icon(Icons.receipt_long, size: 16,
                color: colors.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: BCSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estado de pago',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  _PaymentStatusBadge(status: booking.paymentStatus),
                ],
              ),
            ),
          ],
        ),
        if (booking.paymentIntentId != null) ...[
          const SizedBox(height: BCSpacing.sm),
          _InfoRow(
            icon: Icons.tag,
            label: 'Intent ID',
            value: booking.paymentIntentId!,
          ),
        ],

        const SizedBox(height: BCSpacing.lg),
        const Divider(),
        const SizedBox(height: BCSpacing.md),

        // ── Timeline ────────────────────────────────────────────────────
        _SectionTitle(title: 'Timeline'),
        const SizedBox(height: BCSpacing.sm),
        _TimelineEntry(
          label: 'Creada',
          dateTime: booking.createdAt,
          isFirst: true,
          isActive: true,
        ),
        if (booking.confirmedAt != null)
          _TimelineEntry(
            label: 'Confirmada',
            dateTime: booking.confirmedAt!,
            isActive: true,
          ),
        if (booking.completedAt != null)
          _TimelineEntry(
            label: 'Completada',
            dateTime: booking.completedAt!,
            isActive: true,
            isLast: booking.cancelledAt == null,
          ),
        if (booking.cancelledAt != null)
          _TimelineEntry(
            label: 'Cancelada',
            dateTime: booking.cancelledAt!,
            isActive: true,
            isLast: true,
            isError: true,
          ),
        if (booking.confirmedAt == null &&
            booking.completedAt == null &&
            booking.cancelledAt == null)
          _TimelineEntry(
            label: 'Esperando confirmacion',
            dateTime: null,
            isLast: true,
            isActive: false,
          ),

        const SizedBox(height: BCSpacing.lg),
        const Divider(),
        const SizedBox(height: BCSpacing.md),

        // ── Admin actions ───────────────────────────────────────────────
        _SectionTitle(title: 'Acciones'),
        const SizedBox(height: BCSpacing.sm),

        if (booking.status == 'pending' || booking.status == 'confirmed') ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isProcessing ? null : _cancelBooking,
              icon: _isProcessing
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.error,
                      ),
                    )
                  : Icon(Icons.cancel_outlined, size: 18,
                      color: colors.error),
              label: Text('Cancelar reserva',
                  style: TextStyle(color: colors.error)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.error),
              ),
            ),
          ),
          const SizedBox(height: BCSpacing.sm),
        ],

        if (booking.paymentStatus == 'paid') ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isProcessing ? null : _processRefund,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.undo, size: 18),
              label: const Text('Reembolsar'),
            ),
          ),
          const SizedBox(height: BCSpacing.sm),
        ],

      ],
    );
  }

  String _paymentMethodLabel(String? method) {
    return switch (method) {
      'card' => 'Tarjeta',
      'cash' => 'Efectivo',
      'transfer' => 'Transferencia',
      _ => method ?? 'No especificado',
    };
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: colors.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: BCSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodySmall,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      'pending' => (Icons.hourglass_empty, Colors.orange),
      'confirmed' => (Icons.check_circle_outline, Colors.blue),
      'completed' => (Icons.task_alt, Colors.green),
      'cancelled' => (Icons.cancel_outlined, Colors.red),
      'no_show' => (Icons.person_off, Colors.grey),
      _ => (Icons.help_outline, Colors.grey),
    };

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 28, color: color),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, this.large = false});
  final String status;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _statusInfo(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 12 : 8,
        vertical: large ? 4 : 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(BCSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: large ? 13 : 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

(String, Color) _statusInfo(String status) {
  return switch (status) {
    'pending' => ('Pendiente', Colors.orange),
    'confirmed' => ('Confirmada', Colors.blue),
    'completed' => ('Completada', Colors.green),
    'cancelled' => ('Cancelada', Colors.red),
    'no_show' => ('No asistio', Colors.grey),
    _ => (status, Colors.grey),
  };
}

class _PaymentStatusBadge extends StatelessWidget {
  const _PaymentStatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'paid' => ('Pagado', Colors.green),
      'pending' => ('Pendiente', Colors.orange),
      'refunded' => ('Reembolsado', Colors.blue),
      'failed' => ('Fallido', Colors.red),
      _ => (status, Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(BCSpacing.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.label,
    required this.dateTime,
    this.isFirst = false,
    this.isLast = false,
    this.isActive = false,
    this.isError = false,
  });

  final String label;
  final DateTime? dateTime;
  final bool isFirst;
  final bool isLast;
  final bool isActive;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dateFormat = DateFormat('d MMM, HH:mm', 'es');
    final dotColor = isError
        ? Colors.red
        : isActive
            ? Colors.green
            : colors.onSurface.withValues(alpha: 0.3);

    return Padding(
      padding: const EdgeInsets.only(left: BCSpacing.md),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Timeline line + dot
            SizedBox(
              width: 20,
              child: Column(
                children: [
                  if (!isFirst)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: colors.outlineVariant,
                      ),
                    ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dotColor,
                      border: Border.all(
                        color: dotColor,
                        width: 2,
                      ),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: colors.outlineVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: BCSpacing.sm),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: BCSpacing.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: isError ? Colors.red : null,
                      ),
                    ),
                    if (dateTime != null)
                      Text(
                        dateFormat.format(dateTime!),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Confirmation dialog that requires typing "CANCELAR" to proceed.
class _ConfirmCancelDialog extends StatefulWidget {
  @override
  State<_ConfirmCancelDialog> createState() => _ConfirmCancelDialogState();
}

class _ConfirmCancelDialogState extends State<_ConfirmCancelDialog> {
  final _controller = TextEditingController();
  bool _canConfirm = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cancelar reserva'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Esta accion es irreversible. Si el pago fue realizado, '
            'se procesara un reembolso automaticamente.',
          ),
          const SizedBox(height: 16),
          const Text(
            'Escribe CANCELAR para confirmar:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'CANCELAR',
            ),
            onChanged: (v) {
              setState(() => _canConfirm = v.trim() == 'CANCELAR');
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Volver'),
        ),
        FilledButton(
          onPressed: _canConfirm ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: const Text('Cancelar reserva'),
        ),
      ],
    );
  }
}
