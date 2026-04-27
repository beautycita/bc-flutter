import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/outreach_service.dart';
import '../../services/toast_service.dart';

/// Opens the unified outreach send sheet — works for single (recipientIds.length == 1)
/// and bulk sends. Returns true if a send was enqueued.
Future<bool> showOutreachSendSheet({
  required BuildContext context,
  required String recipientTable, // 'discovered_salons' | 'businesses'
  required List<String> recipientIds,
  String? recipientLabel, // shown in header (e.g. "12 salones de la pipeline")
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (_, scroll) => OutreachSendSheet(
        recipientTable: recipientTable,
        recipientIds: recipientIds,
        recipientLabel: recipientLabel,
        scrollController: scroll,
      ),
    ),
  );
  return result == true;
}

class OutreachSendSheet extends StatefulWidget {
  final String recipientTable;
  final List<String> recipientIds;
  final String? recipientLabel;
  final ScrollController scrollController;

  const OutreachSendSheet({
    super.key,
    required this.recipientTable,
    required this.recipientIds,
    this.recipientLabel,
    required this.scrollController,
  });

  @override
  State<OutreachSendSheet> createState() => _OutreachSendSheetState();
}

enum _Channel { wa, email }

class _OutreachSendSheetState extends State<OutreachSendSheet> {
  // Default to email until Treble (or another approved BSP) replaces the
  // whatsapp-web.js path. WA delivery has been blocked multiple times
  // and admins fall into a broken-looking flow if WA is the default.
  _Channel _channel = _Channel.email;
  List<OutreachTemplate> _allTemplates = [];
  OutreachTemplate? _selectedTemplate;
  EligibilityCounts? _counts;
  OutreachPreview? _preview;
  bool _loadingTemplates = true;
  bool _loadingPreview = false;
  bool _sending = false;
  String? _error;

  /// Per-send manual variables (for templates like B7-B10 with admin-entered fields).
  final Map<String, TextEditingController> _manualControllers = {};

  bool get _isSingle => widget.recipientIds.length == 1;
  bool get _isInviteContext => widget.recipientTable == 'discovered_salons';

  // Hold-to-confirm threshold: 20 recipients
  bool get _needsHold => widget.recipientIds.length > 20;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  @override
  void dispose() {
    _varRefreshTimer?.cancel();
    for (final c in _manualControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    try {
      final list = await OutreachService.listTemplates(
        recipientTable: widget.recipientTable,
        inviteOnly: _isInviteContext ? true : false,
      );
      if (!mounted) return;
      setState(() {
        _allTemplates = list;
        _loadingTemplates = false;
      });
      _refreshFromChannelOrTemplate();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar las plantillas. ${_humanizeError(e)}';
        _loadingTemplates = false;
      });
    }
  }

  List<OutreachTemplate> get _channelTemplates {
    final wa = _channel == _Channel.wa ? 'whatsapp' : 'email';
    return _allTemplates.where((t) => t.channel == wa).toList();
  }

  Future<void> _refreshFromChannelOrTemplate() async {
    // Pick first template for the active channel if none selected.
    final templates = _channelTemplates;
    if (templates.isEmpty) {
      setState(() {
        _selectedTemplate = null;
        _counts = null;
        _preview = null;
      });
      return;
    }
    final keep = _selectedTemplate != null && templates.any((t) => t.id == _selectedTemplate!.id);
    final next = keep ? _selectedTemplate! : templates.first;

    // Build manual controllers for this template
    _manualControllers.removeWhere((k, c) {
      if (!next.manualVariables.contains(k)) {
        c.dispose();
        return true;
      }
      return false;
    });
    for (final v in next.manualVariables) {
      _manualControllers.putIfAbsent(v, () => TextEditingController());
    }

    setState(() => _selectedTemplate = next);

    await _refreshCountsAndPreview();
  }

  Future<void> _refreshCountsAndPreview() async {
    if (_selectedTemplate == null) return;
    setState(() {
      _loadingPreview = true;
      _error = null;
    });
    try {
      final channelStr = _channel == _Channel.wa ? 'wa' : 'email';
      final counts = await OutreachService.countEligible(
        recipientTable: widget.recipientTable,
        recipientIds: widget.recipientIds,
        channel: channelStr,
        isInvite: _selectedTemplate!.isInvite,
      );
      final preview = await OutreachService.previewTemplate(
        templateId: _selectedTemplate!.id,
        recipientTable: widget.recipientTable,
        recipientId: widget.recipientIds.first,
        channel: channelStr,
        manualVars: _manualVars(),
      );
      if (!mounted) return;
      setState(() {
        _counts = counts;
        _preview = preview;
        _loadingPreview = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo generar la vista previa. ${_humanizeError(e)}';
        _loadingPreview = false;
      });
    }
  }

  Map<String, String> _manualVars() {
    final m = <String, String>{};
    for (final entry in _manualControllers.entries) {
      final v = entry.value.text.trim();
      if (v.isNotEmpty) m[entry.key] = v;
    }
    return m;
  }

  bool get _allManualFilled {
    if (_selectedTemplate == null) return false;
    for (final v in _selectedTemplate!.manualVariables) {
      final c = _manualControllers[v];
      if (c == null || c.text.trim().isEmpty) return false;
    }
    return true;
  }

  Future<void> _enqueueSend() async {
    if (_selectedTemplate == null || _counts == null) return;
    if (!_allManualFilled) {
      _showError('Falta completar las variables del envío.');
      return;
    }
    if (_counts!.eligible == 0) {
      _showError('Ningún destinatario es elegible (todos opt-out / cooldown / sin canal).');
      return;
    }
    setState(() => _sending = true);
    try {
      final channelStr = _channel == _Channel.wa ? 'wa' : 'email';
      final summary = await OutreachService.enqueueBulk(
        channel: channelStr,
        templateId: _selectedTemplate!.id,
        recipientTable: widget.recipientTable,
        recipientIds: widget.recipientIds,
        manualVars: _manualVars(),
      );
      if (!mounted) return;
      ToastService.showSuccess(
        _channel == _Channel.wa
            ? 'Encolados ${summary.total} mensajes WA. Entrega ~${(summary.total * 20 / 60).ceil()} min.'
            : 'Encolados ${summary.total} correos. Entrega en curso.',
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _showError('Falló el envío: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showError(String msg) {
    ToastService.showError(msg);
  }

  Future<void> _confirmAndSend() async {
    if (_selectedTemplate == null || _preview == null || _counts == null) return;
    final n = _counts!.eligible;
    final channelLabel = _channel == _Channel.wa ? 'WhatsApp' : 'correo';

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: !_sending,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Estás segura?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vas a enviar $n mensaje${n == 1 ? '' : 's'} de $channelLabel\nusando la plantilla "${_selectedTemplate!.name}".',
              ),
              const SizedBox(height: 12),
              if (_counts!.optedOut > 0 || _counts!.cooldown > 0 || _counts!.noChannel > 0)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Se omitirán:',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      if (_counts!.optedOut > 0) Text('• ${_counts!.optedOut} con opt-out'),
                      if (_counts!.cooldown > 0)
                        Text('• ${_counts!.cooldown} en cooldown 14d (invitaciones)'),
                      if (_counts!.noChannel > 0)
                        Text('• ${_counts!.noChannel} sin ${_channel == _Channel.wa ? 'WhatsApp verificado' : 'email'}'),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              const Text(
                'Se incluye footer de cumplimiento (LFPDPPP/CAN-SPAM): identificación, dirección fiscal, link de baja.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              if (_channel == _Channel.wa && n > 3) ...[
                const SizedBox(height: 8),
                Text(
                  'WhatsApp se entrega 1 mensaje cada 20s para proteger la cuenta. ETA: ~${(n * 20 / 60).ceil()} min.',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _sending ? null : () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          if (_needsHold)
            _HoldToConfirmButton(
              onConfirmed: () => Navigator.of(ctx).pop(true),
              label: 'Mantén presionado',
            )
          else
            FilledButton(
              onPressed: _sending ? null : () => Navigator.of(ctx).pop(true),
              child: const Text('Enviar'),
            ),
        ],
      ),
    );
    if (confirmed == true) await _enqueueSend();
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.all(20),
        children: [
          _buildHandle(),
          const SizedBox(height: 8),
          _buildHeader(theme),
          const SizedBox(height: 16),
          _buildChannelToggle(theme),
          const SizedBox(height: 16),
          if (_loadingTemplates)
            _buildSkeleton(theme)
          else if (_error != null && _allTemplates.isEmpty)
            _buildErrorCard(
              theme,
              _error!,
              () {
                setState(() {
                  _loadingTemplates = true;
                  _error = null;
                });
                _loadTemplates();
              },
            )
          else if (_channelTemplates.isEmpty)
            _buildEmptyTemplates(theme)
          else ...[
            _buildTemplatePicker(theme),
            const SizedBox(height: 16),
            if (_selectedTemplate != null) ...[
              _buildVariablesPanel(theme),
              const SizedBox(height: 16),
              _buildEligibilityBanner(theme),
              const SizedBox(height: 12),
              _buildPreview(theme),
              const SizedBox(height: 12),
              _buildFooterNote(theme),
              const SizedBox(height: 20),
              if (_error != null) ...[
                _buildErrorCard(theme, _error!, _refreshCountsAndPreview),
                const SizedBox(height: 12),
              ],
              _buildSendButton(theme),
              const SizedBox(height: 24),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildHandle() => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade400,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _buildHeader(ThemeData theme) {
    final n = widget.recipientIds.length;
    final label = widget.recipientLabel ??
        (_isSingle
            ? 'Enviar mensaje a 1 salón'
            : 'Enviar mensaje a $n salones');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          _isInviteContext
              ? 'Invitación · cooldown de 14 días por destinatario'
              : 'Mensaje a salones registrados · sin cooldown',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildChannelToggle(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<_Channel>(
          segments: const [
            ButtonSegment(
              value: _Channel.email,
              label: Text('Email'),
              icon: Icon(Icons.mail_outline),
            ),
            ButtonSegment(
              value: _Channel.wa,
              label: Text('WhatsApp'),
              icon: Icon(Icons.chat),
            ),
          ],
          selected: {_channel},
          onSelectionChanged: (s) {
            setState(() => _channel = s.first);
            _refreshFromChannelOrTemplate();
          },
        ),
        if (_channel == _Channel.wa) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 18, color: Color(0xFFB45309)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'WhatsApp puede fallar mientras migramos al BSP oficial. '
                    'Si el envío rebota, reintenta por email.',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSkeleton(ThemeData theme) {
    final base = theme.colorScheme.surfaceContainerHighest;
    Widget bar(double height, {double widthFraction = 1}) => FractionallySizedBox(
          widthFactor: widthFraction,
          alignment: Alignment.centerLeft,
          child: Container(
            height: height,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar(12, widthFraction: 0.3),
          bar(48),
          const SizedBox(height: 6),
          bar(12, widthFraction: 0.4),
          bar(72),
          bar(12, widthFraction: 0.25),
          bar(110),
        ],
      ),
    );
  }

  Widget _buildEmptyTemplates(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            _channel == _Channel.wa ? Icons.chat_bubble_outline : Icons.mark_email_unread_outlined,
            size: 36,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 10),
          Text(
            _channel == _Channel.wa
                ? 'No hay plantillas de WhatsApp configuradas para este destinatario.'
                : 'No hay plantillas de email configuradas para este destinatario.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Cambia de canal arriba o agrega plantillas en Sistema → Plantillas.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(ThemeData theme, String message, VoidCallback onRetry) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplatePicker(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Plantilla', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedTemplate?.id,
          isExpanded: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: _channelTemplates
              .map((t) => DropdownMenuItem(
                    value: t.id,
                    child: Text(
                      _humanTemplateName(t),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: (id) {
            if (id == null) return;
            final t = _channelTemplates.firstWhere((x) => x.id == id);
            setState(() => _selectedTemplate = t);
            _refreshFromChannelOrTemplate();
          },
        ),
      ],
    );
  }

  /// Strip noisy framework prefixes (PostgrestException, FunctionsException)
  /// so the error card stays readable. Keeps the underlying message tail
  /// for diagnosability, capped at 140 chars.
  String _humanizeError(Object e) {
    var text = e.toString();
    final colon = text.indexOf(':');
    if (colon >= 0 && colon < text.length - 1) {
      text = text.substring(colon + 1).trim();
    }
    if (text.length > 140) text = '${text.substring(0, 137)}…';
    if (text.isEmpty) return 'Error desconocido.';
    return text.endsWith('.') ? text : '$text.';
  }

  String _humanTemplateName(OutreachTemplate t) {
    final cat = (t.category ?? '').replaceAll('_', ' ');
    return '${t.name} · $cat';
  }

  Widget _buildVariablesPanel(ThemeData theme) {
    final tpl = _selectedTemplate!;
    final auto = tpl.requiredVariables;
    final manual = tpl.manualVariables;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Variables', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        if (auto.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: auto
                .map((v) => Chip(
                      label: Text('{$v}'),
                      avatar: const Icon(Icons.auto_awesome, size: 14),
                      backgroundColor: Colors.green.withValues(alpha: 0.10),
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
        if (auto.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Estas variables se reemplazan automáticamente por cada salón.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ),
        if (manual.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Variables del envío (manuales)', style: theme.textTheme.labelMedium),
          const SizedBox(height: 6),
          for (final v in manual)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: _manualControllers[v],
                decoration: InputDecoration(
                  labelText: '{$v}',
                  hintText: _hintForManualVar(v),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: v == 'summary_md' || v == 'feature_summary' ? 3 : 1,
                onChanged: (_) {
                  // Debounced refresh when user pauses
                  _scheduleVarRefresh();
                },
              ),
            ),
        ],
      ],
    );
  }

  String _hintForManualVar(String v) {
    switch (v) {
      case 'feature_title':
        return 'Ej. Recordatorio T-5min para estilistas';
      case 'feature_summary':
        return 'Resumen breve del feature';
      case 'feature_url':
        return 'https://beautycita.com/blog/...';
      case 'effective_date':
        return '1 de mayo de 2026';
      case 'summary_md':
        return '• Cambio 1\n• Cambio 2';
      case 'changelog_url':
        return 'https://beautycita.com/legal/changelog';
      case 'occasion':
        return 'El Día de las Madres';
      case 'cta':
        return 'Llamado a la acción';
      default:
        return '';
    }
  }

  Timer? _varRefreshTimer;
  void _scheduleVarRefresh() {
    _varRefreshTimer?.cancel();
    _varRefreshTimer = Timer(const Duration(milliseconds: 600), _refreshCountsAndPreview);
  }

  Widget _buildEligibilityBanner(ThemeData theme) {
    if (_counts == null) return const SizedBox.shrink();
    final c = _counts!;
    final eligibleColor = c.eligible == c.total
        ? Colors.green
        : (c.eligible == 0 ? Colors.red : Colors.orange);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: eligibleColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: eligibleColor.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.check_circle_outline, size: 18, color: eligibleColor),
            const SizedBox(width: 6),
            Text(
              '${c.eligible} de ${c.total} elegibles',
              style: TextStyle(fontWeight: FontWeight.w600, color: eligibleColor),
            ),
          ]),
          if (c.optedOut > 0 || c.cooldown > 0 || c.noChannel > 0) ...[
            const SizedBox(height: 4),
            if (c.optedOut > 0) Text('${c.optedOut} con opt-out (BAJA)'),
            if (c.cooldown > 0) Text('${c.cooldown} en cooldown 14d'),
            if (c.noChannel > 0)
              Text(
                '${c.noChannel} sin ${_channel == _Channel.wa ? 'WhatsApp verificado' : 'email'}',
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreview(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isSingle
              ? 'Vista previa'
              : 'Vista previa (primer destinatario)',
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        if (_loadingPreview)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
          )
        else if (_preview != null) ...[
          if (_preview!.subject != null && _preview!.subject!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'Asunto: ${_preview!.subject}',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black12),
            ),
            child: SelectableText(
              _preview!.body,
              style: const TextStyle(fontSize: 13, height: 1.45),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFooterNote(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, size: 18, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _channel == _Channel.wa
                  ? 'Se agrega footer LFPDPPP: identificación, dirección fiscal, "responde BAJA". Cooldown 14d en invitaciones. Throttle global: 1 msg/20s.'
                  : 'Se agrega footer LFPDPPP/CAN-SPAM: identificación, dirección fiscal, link de baja, aviso de privacidad.',
              style: const TextStyle(fontSize: 11, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton(ThemeData theme) {
    final eligible = _counts?.eligible ?? 0;
    final canSend = eligible > 0 && _selectedTemplate != null && _allManualFilled && !_sending;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: canSend ? _confirmAndSend : null,
        icon: _sending
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.send),
        label: Text(
          _sending
              ? 'Enviando...'
              : eligible == 0
                  ? 'Ningún destinatario elegible'
                  : 'Enviar a $eligible destinatario${eligible == 1 ? '' : 's'}',
        ),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ── Hold-to-confirm button (used when recipient count > 20) ─────────────────

class _HoldToConfirmButton extends StatefulWidget {
  final VoidCallback onConfirmed;
  final String label;
  const _HoldToConfirmButton({required this.onConfirmed, required this.label});

  @override
  State<_HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<_HoldToConfirmButton> {
  Timer? _ticker;
  double _progress = 0.0;
  static const _holdDurationMs = 3000;

  void _start() {
    _ticker?.cancel();
    final start = DateTime.now();
    _ticker = Timer.periodic(const Duration(milliseconds: 50), (t) {
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      setState(() => _progress = (elapsed / _holdDurationMs).clamp(0.0, 1.0));
      if (elapsed >= _holdDurationMs) {
        t.cancel();
        HapticFeedback.mediumImpact();
        widget.onConfirmed();
      }
    });
  }

  void _cancel() {
    _ticker?.cancel();
    setState(() => _progress = 0.0);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _start(),
      onTapUp: (_) => _cancel(),
      onTapCancel: _cancel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10 + 0.40 * _progress),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              _progress >= 1.0 ? '¡Enviando!' : widget.label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
