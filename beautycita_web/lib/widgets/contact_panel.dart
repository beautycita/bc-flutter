import 'package:beautycita_core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/admin_salons_provider.dart';
import '../providers/outreach_contact_provider.dart';

// ── Channel enum ─────────────────────────────────────────────────────────────

enum ContactChannel {
  waMessage('wa_message', 'WhatsApp', Icons.chat, 'whatsapp'),
  waCall('wa_call', 'Llamada WA', Icons.phone_android, null),
  email('email', 'Email', Icons.email_outlined, 'email'),
  sms('sms', 'SMS', Icons.sms_outlined, null),
  phoneCall('phone', 'Llamada', Icons.phone, null);

  const ContactChannel(this.value, this.label, this.icon, this.templateChannel);
  final String value;
  final String label;
  final IconData icon;

  /// Used to filter outreach templates. Null means no template picker for this
  /// channel.
  final String? templateChannel;
}

// ── Outcome options ──────────────────────────────────────────────────────────

const _outcomeOptions = <String, String>{
  'interested': 'Interesado',
  'callback': 'Llamar despues',
  'not_interested': 'No interesado',
  'no_answer': 'No contesto',
  'wrong_number': 'Numero equivocado',
  'voicemail': 'Buzon de voz',
};

// ── ContactPanel ─────────────────────────────────────────────────────────────

class ContactPanel extends ConsumerStatefulWidget {
  const ContactPanel({
    required this.salon,
    required this.onClose,
    this.onSent,
    super.key,
  });

  final DiscoveredSalon salon;
  final VoidCallback onClose;
  final VoidCallback? onSent;

  @override
  ConsumerState<ContactPanel> createState() => _ContactPanelState();
}

class _ContactPanelState extends ConsumerState<ContactPanel> {
  late ContactChannel _channel;
  OutreachTemplate? _selectedTemplate;

  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  String? _selectedOutcome;

  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _channel = _availableChannels.first;
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    _notesCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  List<ContactChannel> get _availableChannels => [
        ContactChannel.waMessage,
        if (widget.salon.waStatus == 'valid') ContactChannel.waCall,
        ContactChannel.email,
        if (widget.salon.waStatus != 'valid') ContactChannel.sms,
        ContactChannel.phoneCall,
      ];

  bool get _isCallChannel =>
      _channel == ContactChannel.phoneCall ||
      _channel == ContactChannel.waCall;

  bool get _isEmailChannel => _channel == ContactChannel.email;

  bool get _hasTemplates => _channel.templateChannel != null;

  // ── Template substitution ──────────────────────────────────────────────────

  String _substituteVars(String template) {
    final s = widget.salon;
    return template
        .replaceAll('{salon_name}', s.name)
        .replaceAll('{city}', s.city ?? '')
        .replaceAll('{rating}', s.rating?.toStringAsFixed(1) ?? '')
        .replaceAll('{review_count}', '${s.reviewCount ?? 0}')
        .replaceAll('{rp_name}', 'BC Team') // TODO: get from logged-in profile
        .replaceAll('{rp_phone}', '+52 720 677 7800')
        .replaceAll('{interest_count}', '${s.interestSignals}')
        .replaceAll('{booking_system}', s.bookingSystem ?? 'ninguno');
  }

  void _onTemplateSelected(OutreachTemplate? template) {
    setState(() {
      _selectedTemplate = template;
      if (template != null) {
        _bodyCtrl.text = _substituteVars(template.bodyTemplate);
        if (_isEmailChannel && template.subject != null) {
          _subjectCtrl.text = _substituteVars(template.subject!);
        }
      }
    });
  }

  // ── Channel switch ─────────────────────────────────────────────────────────

  void _onChannelChanged(ContactChannel ch) {
    setState(() {
      _channel = ch;
      _selectedTemplate = null;
      _bodyCtrl.clear();
      _subjectCtrl.clear();
      _notesCtrl.clear();
      _durationCtrl.clear();
      _selectedOutcome = null;
    });
  }

  // ── Send / log ─────────────────────────────────────────────────────────────

  String get _sendButtonLabel => switch (_channel) {
        ContactChannel.waMessage => 'Enviar WA',
        ContactChannel.email => 'Enviar Email',
        ContactChannel.sms => 'Enviar SMS',
        ContactChannel.waCall || ContactChannel.phoneCall =>
          'Registrar llamada',
      };

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);

    bool success = false;
    final salonId = widget.salon.id;

    switch (_channel) {
      case ContactChannel.waMessage:
        success = await OutreachContactService.sendWa(
          salonId: salonId,
          message:
              _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim(),
          templateId: _selectedTemplate?.id,
          rpName: 'BC Team',
          rpPhone: '+52 720 677 7800',
        );
      case ContactChannel.waCall:
        success = await OutreachContactService.logCall(
          salonId: salonId,
          channel: ContactChannel.waCall.value,
          notes:
              _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          outcome: _selectedOutcome,
          durationSeconds: int.tryParse(_durationCtrl.text),
        );
      case ContactChannel.email:
        if (_subjectCtrl.text.trim().isEmpty ||
            _bodyCtrl.text.trim().isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Asunto y mensaje son requeridos para email'),
              ),
            );
          }
          setState(() => _sending = false);
          return;
        }
        success = await OutreachContactService.sendEmail(
          salonId: salonId,
          subject: _subjectCtrl.text.trim(),
          message: _bodyCtrl.text.trim(),
          templateId: _selectedTemplate?.id,
          rpName: 'BC Team',
          rpPhone: '+52 720 677 7800',
        );
      case ContactChannel.sms:
        if (_bodyCtrl.text.trim().isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('El mensaje es requerido para SMS'),
              ),
            );
          }
          setState(() => _sending = false);
          return;
        }
        success = await OutreachContactService.sendSms(
          salonId: salonId,
          message: _bodyCtrl.text.trim(),
          rpName: 'BC Team',
        );
      case ContactChannel.phoneCall:
        success = await OutreachContactService.logCall(
          salonId: salonId,
          channel: ContactChannel.phoneCall.value,
          notes:
              _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          outcome: _selectedOutcome,
          durationSeconds: int.tryParse(_durationCtrl.text),
        );
    }

    if (!mounted) return;
    setState(() => _sending = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Enviado correctamente'
              : 'Error al enviar, intenta de nuevo',
        ),
        backgroundColor: success ? null : Colors.red,
      ),
    );

    if (success) {
      ref.invalidate(salonOutreachHistoryProvider(widget.salon.id));
      widget.onSent?.call();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final salon = widget.salon;

    return Container(
      width: 480,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(left: BorderSide(color: colors.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(colors, salon),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(BCSpacing.md),
              children: [
                _buildChannelSelector(colors),
                const SizedBox(height: BCSpacing.md),
                if (_hasTemplates) ...[
                  _buildTemplatePicker(colors),
                  const SizedBox(height: BCSpacing.md),
                ],
                if (_isCallChannel) ...[
                  _buildCallForm(colors),
                ] else ...[
                  _buildComposeForm(colors),
                ],
                const SizedBox(height: BCSpacing.md),
                _buildSendButton(colors),
                const SizedBox(height: BCSpacing.lg),
                _buildHistoryTimeline(colors),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(ColorScheme colors, DiscoveredSalon salon) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BCSpacing.md,
        vertical: BCSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  salon.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: BCSpacing.xs),
                Row(
                  children: [
                    if (salon.phone != null) ...[
                      Icon(Icons.phone,
                          size: 14, color: colors.onSurfaceVariant),
                      const SizedBox(width: BCSpacing.xs),
                      Text(
                        salon.phone!,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: BCSpacing.sm),
                    ],
                    _buildWaBadge(colors, salon.waStatus),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onClose,
            tooltip: 'Cerrar',
          ),
        ],
      ),
    );
  }

  Widget _buildWaBadge(ColorScheme colors, String status) {
    final (label, color) = switch (status) {
      'valid' => ('WA', const Color(0xFF16A34A)),
      'invalid' => ('WA', const Color(0xFFDC2626)),
      _ => ('WA?', const Color(0xFF9CA3AF)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  // ── Channel selector ───────────────────────────────────────────────────────

  Widget _buildChannelSelector(ColorScheme colors) {
    return Wrap(
      spacing: BCSpacing.sm,
      runSpacing: BCSpacing.sm,
      children: _availableChannels.map((ch) {
        final selected = ch == _channel;
        return ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                ch.icon,
                size: 16,
                color: selected ? colors.onPrimary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: BCSpacing.xs),
              Text(ch.label),
            ],
          ),
          selected: selected,
          onSelected: (_) => _onChannelChanged(ch),
          selectedColor: colors.primary,
          labelStyle: TextStyle(
            color: selected ? colors.onPrimary : colors.onSurfaceVariant,
            fontSize: 13,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BCSpacing.radiusSm),
          ),
        );
      }).toList(),
    );
  }

  // ── Template picker ────────────────────────────────────────────────────────

  Widget _buildTemplatePicker(ColorScheme colors) {
    final templatesAsync =
        ref.watch(outreachTemplatesProvider(_channel.templateChannel));

    return templatesAsync.when(
      loading: () => const SizedBox(
        height: 48,
        child: Center(child: LinearProgressIndicator()),
      ),
      error: (_, __) => Text(
        'Error cargando plantillas',
        style: TextStyle(color: colors.error, fontSize: 13),
      ),
      data: (templates) {
        if (templates.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Plantilla',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: BCSpacing.xs),
            DropdownButtonFormField<OutreachTemplate>(
              value: _selectedTemplate,
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: BCSpacing.sm,
                  vertical: BCSpacing.sm,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
                ),
                hintText: 'Seleccionar plantilla...',
                hintStyle:
                    TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
              ),
              items: [
                const DropdownMenuItem<OutreachTemplate>(
                  value: null,
                  child:
                      Text('Sin plantilla', style: TextStyle(fontSize: 13)),
                ),
                ...templates.map(
                  (t) => DropdownMenuItem(
                    value: t,
                    child: Text(
                      t.name,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: _onTemplateSelected,
            ),
          ],
        );
      },
    );
  }

  // ── Compose form (WA message, email, SMS) ──────────────────────────────────

  Widget _buildComposeForm(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isEmailChannel) ...[
          Text(
            'Asunto',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: BCSpacing.xs),
          TextField(
            controller: _subjectCtrl,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: BCSpacing.sm,
                vertical: BCSpacing.sm,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
              ),
              hintText: 'Asunto del correo...',
              hintStyle:
                  TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: BCSpacing.sm),
        ],
        Text(
          'Mensaje',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: BCSpacing.xs),
        TextField(
          controller: _bodyCtrl,
          maxLines: 8,
          minLines: 4,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.all(BCSpacing.sm),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
            ),
            hintText: _isEmailChannel
                ? 'Escribe tu mensaje...'
                : _channel == ContactChannel.waMessage
                    ? 'Mensaje de WhatsApp...'
                    : 'Mensaje SMS...',
            hintStyle:
                TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  // ── Call form (phone / WA call) ────────────────────────────────────────────

  Widget _buildCallForm(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Outcome
        Text(
          'Resultado',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: BCSpacing.xs),
        DropdownButtonFormField<String>(
          value: _selectedOutcome,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: BCSpacing.sm,
              vertical: BCSpacing.sm,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
            ),
            hintText: 'Seleccionar resultado...',
            hintStyle:
                TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
          ),
          items: _outcomeOptions.entries
              .map(
                (e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value, style: const TextStyle(fontSize: 13)),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _selectedOutcome = v),
        ),
        const SizedBox(height: BCSpacing.sm),
        // Duration
        Text(
          'Duracion (segundos)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: BCSpacing.xs),
        TextField(
          controller: _durationCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: BCSpacing.sm,
              vertical: BCSpacing.sm,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
            ),
            hintText: 'ej. 120',
            hintStyle:
                TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
          ),
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: BCSpacing.sm),
        // Notes
        Text(
          'Notas',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: BCSpacing.xs),
        TextField(
          controller: _notesCtrl,
          maxLines: 4,
          minLines: 2,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.all(BCSpacing.sm),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
            ),
            hintText: 'Notas de la llamada...',
            hintStyle:
                TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  // ── Send / log button ──────────────────────────────────────────────────────

  Widget _buildSendButton(ColorScheme colors) {
    final icon = _isCallChannel ? Icons.save : Icons.send;

    return FilledButton.icon(
      onPressed: _sending ? null : _send,
      icon: _sending
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.onPrimary,
              ),
            )
          : Icon(icon, size: 18),
      label: Text(_sendButtonLabel),
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
        ),
      ),
    );
  }

  // ── Contact history timeline ───────────────────────────────────────────────

  Widget _buildHistoryTimeline(ColorScheme colors) {
    final historyAsync =
        ref.watch(salonOutreachHistoryProvider(widget.salon.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history, size: 16, color: colors.onSurfaceVariant),
            const SizedBox(width: BCSpacing.xs),
            Text(
              'Historial de contacto',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: BCSpacing.sm),
        historyAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: BCSpacing.lg),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: BCSpacing.md),
            child: Text(
              'Error cargando historial',
              style: TextStyle(color: colors.error, fontSize: 13),
            ),
          ),
          data: (entries) {
            if (entries.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: BCSpacing.lg),
                child: Center(
                  child: Text(
                    'Sin historial de contacto',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }
            final visible = entries.take(10).toList();
            return Column(
              children: visible.map((entry) {
                return _HistoryEntryTile(entry: entry);
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

// ── History entry tile ───────────────────────────────────────────────────────

class _HistoryEntryTile extends StatefulWidget {
  const _HistoryEntryTile({required this.entry});
  final OutreachLogEntry entry;

  @override
  State<_HistoryEntryTile> createState() => _HistoryEntryTileState();
}

class _HistoryEntryTileState extends State<_HistoryEntryTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final entry = widget.entry;
    final relativeDate = _formatRelative(entry.sentAt);

    final preview = entry.messageText ?? entry.notes ?? '';
    final truncated =
        preview.length > 80 ? '${preview.substring(0, 80)}...' : preview;
    final hasFullContent =
        (entry.messageText != null && entry.messageText!.length > 80) ||
            entry.transcript != null;

    final isCall = entry.channel == 'phone' || entry.channel == 'wa_call';

    return Padding(
      padding: const EdgeInsets.only(bottom: BCSpacing.sm),
      child: InkWell(
        onTap:
            hasFullContent ? () => setState(() => _expanded = !_expanded) : null,
        borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
        child: Container(
          padding: const EdgeInsets.all(BCSpacing.sm),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
            border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: icon + channel + date + outcome
              Row(
                children: [
                  Icon(entry.channelIcon,
                      size: 16, color: colors.onSurfaceVariant),
                  const SizedBox(width: BCSpacing.xs),
                  Text(
                    entry.channelLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (isCall && entry.callDurationSeconds != null) ...[
                    const SizedBox(width: BCSpacing.sm),
                    Icon(Icons.timer,
                        size: 12, color: colors.onSurfaceVariant),
                    const SizedBox(width: 2),
                    Text(
                      _formatDuration(entry.callDurationSeconds!),
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (entry.outcome != null) ...[
                    _OutcomeBadge(
                        outcome: entry.outcome!, color: entry.outcomeColor),
                    const SizedBox(width: BCSpacing.sm),
                  ],
                  Text(
                    relativeDate,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              // Preview
              if (truncated.isNotEmpty) ...[
                const SizedBox(height: BCSpacing.xs),
                Text(
                  _expanded
                      ? (entry.messageText ?? entry.notes ?? '')
                      : truncated,
                  style: TextStyle(fontSize: 12, color: colors.onSurface),
                ),
              ],
              // Recording play placeholder
              if (isCall && entry.recordingUrl != null) ...[
                const SizedBox(height: BCSpacing.xs),
                Row(
                  children: [
                    Icon(Icons.play_circle_outline,
                        size: 18, color: colors.primary),
                    const SizedBox(width: BCSpacing.xs),
                    Text(
                      'Reproducir grabacion',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
              // Transcript
              if (_expanded && entry.transcript != null) ...[
                const SizedBox(height: BCSpacing.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(BCSpacing.sm),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transcripcion',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: BCSpacing.xs),
                      Text(
                        entry.transcript!,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Expand indicator
              if (hasFullContent) ...[
                const SizedBox(height: 2),
                Center(
                  child: Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ],
              // RP display name
              if (entry.rpDisplayName != null) ...[
                const SizedBox(height: BCSpacing.xs),
                Text(
                  'Por: ${entry.rpDisplayName}',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatRelative(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    if (diff.inDays < 7) return 'hace ${diff.inDays}d';
    return DateFormat('d MMM', 'es').format(dt);
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '${s}s';
    return '${m}m ${s}s';
  }
}

// ── Outcome badge ────────────────────────────────────────────────────────────

class _OutcomeBadge extends StatelessWidget {
  const _OutcomeBadge({required this.outcome, required this.color});
  final String outcome;
  final Color color;

  String get _label => switch (outcome) {
        'interested' => 'Interesado',
        'callback' => 'Callback',
        'not_interested' => 'No interesado',
        'no_answer' => 'Sin respuesta',
        'wrong_number' => 'Num. incorrecto',
        'voicemail' => 'Buzon',
        _ => outcome,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
      ),
      child: Text(
        _label,
        style:
            TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
