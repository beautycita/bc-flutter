import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Minimal web outreach send dialog. Opens from the bulk-action bar on
/// admin/salons (Registered + Discovered tabs). Mobile has the full sheet
/// with preview + variables; web is the slim path that handles the common
/// cases (cold invites, registered nudges) without manual vars.
Future<bool> showOutreachSendDialog({
  required BuildContext context,
  required String recipientTable, // 'discovered_salons' | 'businesses'
  required List<String> recipientIds,
}) async {
  if (recipientIds.length > 100) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Máximo 100 destinatarios. Hay ${recipientIds.length} seleccionados.')),
    );
    return false;
  }
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => _OutreachSendDialog(
      recipientTable: recipientTable,
      recipientIds: recipientIds,
    ),
  );
  return result == true;
}

class _OutreachSendDialog extends StatefulWidget {
  final String recipientTable;
  final List<String> recipientIds;
  const _OutreachSendDialog({required this.recipientTable, required this.recipientIds});

  @override
  State<_OutreachSendDialog> createState() => _OutreachSendDialogState();
}

class _OutreachSendDialogState extends State<_OutreachSendDialog> {
  String _channel = 'email';
  List<Map<String, dynamic>> _templates = [];
  String? _selectedTemplateId;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  bool get _isInviteContext => widget.recipientTable == 'discovered_salons';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Supabase.instance.client
          .from('outreach_templates')
          .select('id, name, channel, subject, category, recipient_table, is_invite, manual_variables')
          .eq('is_active', true)
          .order('sort_order');
      _templates = (res as List)
          .cast<Map<String, dynamic>>()
          .where((t) {
            final rt = t['recipient_table'] as String?;
            if (rt != null && rt != 'both' && rt != widget.recipientTable) return false;
            if (_isInviteContext && (t['is_invite'] as bool?) != true) return false;
            if (!_isInviteContext && (t['is_invite'] as bool?) == true) return false;
            // Web-slim: skip templates with manual vars (mobile only, until web grows the inputs).
            final mv = (t['manual_variables'] as List?)?.cast<String>() ?? const [];
            if (mv.isNotEmpty) return false;
            return true;
          })
          .toList();
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = 'No se pudieron cargar plantillas: $e';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredTemplates {
    final ch = _channel == 'wa' ? 'whatsapp' : 'email';
    return _templates.where((t) => t['channel'] == ch).toList();
  }

  Future<void> _send() async {
    if (_selectedTemplateId == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'outreach-bulk-send',
        body: {
          'action': 'enqueue',
          'channel': _channel,
          'template_id': _selectedTemplateId,
          'recipient_table': widget.recipientTable,
          'recipient_ids': widget.recipientIds,
          'manual_vars': {},
        },
      );
      if (res.status != 200) {
        final err = res.data is Map ? res.data['error'] : 'Error desconocido';
        throw Exception(err);
      }
      if (!mounted) return;
      final n = (res.data as Map)['total'] ?? widget.recipientIds.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_channel == 'wa'
              ? 'Encolados $n mensajes WA. Entrega ~${(n * 20 / 60).ceil()} min.'
              : 'Encolados $n correos. Entrega en curso.'),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = 'Falló el envío: $e';
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.recipientIds.length;
    return AlertDialog(
      title: Text('Enviar mensaje a $n salón${n == 1 ? "" : "es"}'),
      content: SizedBox(
        width: 480,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isInviteContext
                        ? 'Invitación · cooldown 14 días por salón'
                        : 'Salones registrados · sin cooldown',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'wa', label: Text('WhatsApp'), icon: Icon(Icons.chat)),
                      ButtonSegment(value: 'email', label: Text('Email'), icon: Icon(Icons.mail_outline)),
                    ],
                    selected: {_channel},
                    onSelectionChanged: (s) => setState(() {
                      _channel = s.first;
                      _selectedTemplateId = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  if (_filteredTemplates.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Sin plantillas para este canal.'),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _selectedTemplateId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Plantilla',
                        border: OutlineInputBorder(),
                      ),
                      items: _filteredTemplates
                          .map((t) => DropdownMenuItem<String>(
                                value: t['id'] as String,
                                child: Text(
                                  '${t['name']} · ${t['category'] ?? "general"}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedTemplateId = v),
                    ),
                  const SizedBox(height: 12),
                  Container(
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
                            _channel == 'wa'
                                ? 'Footer LFPDPPP + 14d cooldown + throttle 1/20s.'
                                : 'Footer LFPDPPP/CAN-SPAM + opt-out + identidad fiscal.',
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: (_sending || _selectedTemplateId == null) ? null : _send,
          icon: _sending
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send, size: 18),
          label: Text(_sending ? 'Enviando...' : 'Enviar'),
        ),
      ],
    );
  }
}
