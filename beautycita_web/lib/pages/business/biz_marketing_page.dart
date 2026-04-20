import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';

import '../../config/web_theme.dart';
import '../../data/demo_data.dart';
import '../../providers/business_portal_provider.dart';
import '../../providers/demo_providers.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final _automatedMessagesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, bizId) async {
  if (ref.watch(isDemoProvider)) return DemoData.marketingAutomations;
  final rows = await BCSupabase.client
      .from(BCTables.automatedMessages)
      .select()
      .eq('business_id', bizId)
      .order('trigger_type');
  return List<Map<String, dynamic>>.from(rows as List);
});

final _messageLogProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, bizId) async {
  if (ref.watch(isDemoProvider)) return DemoData.marketingLog;
  final rows = await BCSupabase.client
      .from(BCTables.automatedMessageLog)
      .select()
      .eq('business_id', bizId)
      .order('sent_at', ascending: false)
      .limit(50);
  return List<Map<String, dynamic>>.from(rows as List);
});

// ── Trigger config ────────────────────────────────────────────────────────────

class _TriggerMeta {
  const _TriggerMeta({
    required this.key,
    required this.label,
    required this.description,
    required this.icon,
  });
  final String key;
  final String label;
  final String description;
  final IconData icon;
}

const _triggers = [
  _TriggerMeta(
    key: 'post_appointment',
    label: 'Post-Cita',
    description: 'Mensaje automatico despues de cada cita completada.',
    icon: Icons.check_circle_outline,
  ),
  _TriggerMeta(
    key: 'review_request',
    label: 'Solicitar Resena',
    description: 'Pide resena al cliente 24h despues de la cita.',
    icon: Icons.star_outline,
  ),
  _TriggerMeta(
    key: 'no_show_followup',
    label: 'No-Show Follow-up',
    description: 'Mensaje de re-agendamiento cuando el cliente no se presenta.',
    icon: Icons.event_busy_outlined,
  ),
  _TriggerMeta(
    key: 'birthday',
    label: 'Cumpleanos',
    description: 'Mensaje especial el dia del cumpleanos del cliente.',
    icon: Icons.cake_outlined,
  ),
  _TriggerMeta(
    key: 'inactive_client',
    label: 'Cliente Inactivo',
    description: 'Reactivar clientes que no han reservado en N dias.',
    icon: Icons.person_off_outlined,
  ),
];

// ── Page ─────────────────────────────────────────────────────────────────────

class BizMarketingPage extends ConsumerWidget {
  const BizMarketingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bizAsync = ref.watch(currentBusinessProvider);
    return bizAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (biz) {
        if (biz == null) return const Center(child: Text('Sin negocio'));
        return _MarketingContent(bizId: biz['id'] as String);
      },
    );
  }
}

// ── Content ──────────────────────────────────────────────────────────────────

class _MarketingContent extends ConsumerWidget {
  const _MarketingContent({required this.bizId});
  final String bizId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final msgsAsync = ref.watch(_automatedMessagesProvider(bizId));
    final logAsync = ref.watch(_messageLogProvider(bizId));
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page header
          Text(
            'Marketing Automatizado',
            style: theme.textTheme.titleLarge?.copyWith(
              color: kWebTextPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Configura mensajes automaticos para mantener a tus clientes comprometidos.',
            style:
                theme.textTheme.bodySmall?.copyWith(color: kWebTextHint),
          ),
          const SizedBox(height: 28),

          // Cards grid
          msgsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (msgs) {
              // Build a lookup map trigger_type → row
              final Map<String, Map<String, dynamic>> byTrigger = {
                for (final m in msgs)
                  m['trigger_type'] as String: m,
              };

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final t in _triggers)
                    _TriggerCard(
                      meta: t,
                      existing: byTrigger[t.key],
                      bizId: bizId,
                      onSaved: () =>
                          ref.invalidate(_automatedMessagesProvider(bizId)),
                    ),
                ],
              );
            },
          ),

          const SizedBox(height: 36),

          // Activity log
          Text(
            'Registro de Actividad',
            style: theme.textTheme.titleMedium?.copyWith(
              color: kWebTextPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          logAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (log) => _ActivityLog(log: log),
          ),
        ],
      ),
    );
  }
}

// ── Trigger Card ─────────────────────────────────────────────────────────────

class _TriggerCard extends ConsumerStatefulWidget {
  const _TriggerCard({
    required this.meta,
    required this.existing,
    required this.bizId,
    required this.onSaved,
  });
  final _TriggerMeta meta;
  final Map<String, dynamic>? existing;
  final String bizId;
  final VoidCallback onSaved;

  @override
  ConsumerState<_TriggerCard> createState() => _TriggerCardState();
}

class _TriggerCardState extends ConsumerState<_TriggerCard> {
  bool _expanded = false;
  bool _saving = false;
  late bool _enabled;
  late TextEditingController _templateCtrl;
  late int _delayHours;
  late String _channel;

  static const _channels = ['whatsapp', 'push', 'email'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _enabled = e?['enabled'] as bool? ?? false;
    _templateCtrl =
        TextEditingController(text: e?['template'] as String? ?? '');
    _delayHours = (e?['delay_hours'] as num?)?.toInt() ?? 0;
    _channel = e?['channel'] as String? ?? 'whatsapp';
  }

  @override
  void dispose() {
    _templateCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final payload = {
        'business_id': widget.bizId,
        'trigger_type': widget.meta.key,
        'enabled': _enabled,
        'template': _templateCtrl.text,
        'delay_hours': _delayHours,
        'channel': _channel,
      };

      if (widget.existing != null) {
        await BCSupabase.client
            .from(BCTables.automatedMessages)
            .update(payload)
            .eq('id', widget.existing!['id'].toString());
      } else {
        await BCSupabase.client
            .from(BCTables.automatedMessages)
            .insert(payload);
      }

      widget.onSaved();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Guardado')));
        setState(() => _expanded = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: kWebSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _enabled
              ? kWebPrimary.withValues(alpha: 0.3)
              : kWebCardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: kWebPrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(widget.meta.icon,
                      size: 18, color: kWebPrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.meta.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: kWebTextPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        widget.meta.description,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: kWebTextHint),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                  activeColor: kWebPrimary,
                ),
              ],
            ),
          ),

          // Expand/collapse toggle
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: kWebCardBorder)),
              ),
              child: Row(
                children: [
                  Text(
                    _expanded ? 'Ocultar editor' : 'Editar plantilla',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: kWebTextSecondary),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_outlined
                        : Icons.keyboard_arrow_down_outlined,
                    size: 18,
                    color: kWebTextHint,
                  ),
                ],
              ),
            ),
          ),

          // Expanded editor — animated
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Template
                        Text(
                          'Mensaje',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: kWebTextSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _templateCtrl,
                          maxLines: 4,
                          decoration: _inputDec(
                              theme,
                              'Hola {nombre}, gracias por tu visita en {negocio}...'),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: kWebTextPrimary),
                        ),
                        const SizedBox(height: 12),

                        // Delay + channel row
                        Row(
                          children: [
                            // Delay hours
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Retraso (horas)',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: kWebTextSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<int>(
                                    value: _delayHours,
                                    items: [0, 1, 2, 4, 8, 12, 24, 48, 72]
                                        .map((h) => DropdownMenuItem(
                                            value: h,
                                            child: Text('$h h')))
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _delayHours = v ?? 0),
                                    decoration: _inputDec(theme, ''),
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(color: kWebTextPrimary),
                                    isDense: true,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Channel
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Canal',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: kWebTextSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    value: _channel,
                                    items: _channels
                                        .map((ch) => DropdownMenuItem(
                                            value: ch, child: Text(ch)))
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _channel = v ?? 'whatsapp'),
                                    decoration: _inputDec(theme, ''),
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(color: kWebTextPrimary),
                                    isDense: true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Save
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _saving ? null : _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: kWebPrimary,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Guardar',
                                    style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDec(ThemeData theme, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          theme.textTheme.bodySmall?.copyWith(color: kWebTextHint),
      filled: true,
      fillColor: kWebBackground,
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kWebCardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kWebCardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kWebPrimary, width: 1.5),
      ),
    );
  }
}

// ── Activity Log ─────────────────────────────────────────────────────────────

class _ActivityLog extends StatelessWidget {
  const _ActivityLog({required this.log});
  final List<Map<String, dynamic>> log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (log.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: kWebSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kWebCardBorder),
        ),
        child: Center(
          child: Text(
            'Aun no hay mensajes enviados',
            style:
                theme.textTheme.bodyMedium?.copyWith(color: kWebTextHint),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: kWebSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kWebCardBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Header row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: kWebBackground,
              child: Row(
                children: [
                  _LogHeader(theme, 'Trigger', flex: 2),
                  _LogHeader(theme, 'Cliente', flex: 2),
                  _LogHeader(theme, 'Canal', flex: 1),
                  _LogHeader(theme, 'Estado', flex: 1),
                  _LogHeader(theme, 'Enviado', flex: 2),
                ],
              ),
            ),
            const Divider(height: 1, color: kWebCardBorder),
            for (int i = 0; i < log.length; i++) ...[
              if (i > 0)
                const Divider(height: 1, color: kWebCardBorder),
              _LogRow(entry: log[i], theme: theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _LogHeader(ThemeData theme, String label, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: kWebTextHint,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry, required this.theme});
  final Map<String, dynamic> entry;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    String fmtDate(dynamic v) {
      if (v == null) return '-';
      try {
        final d = DateTime.parse(v.toString()).toLocal();
        return '${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        return v.toString();
      }
    }

    final status = entry['status'] as String? ?? 'sent';
    final statusColor =
        status == 'failed' ? Colors.red.shade600 : Colors.green.shade600;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              entry['trigger_type'] as String? ?? '-',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: kWebTextSecondary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              entry['client_name'] as String? ?? '-',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: kWebTextPrimary),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              entry['channel'] as String? ?? '-',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: kWebTextHint),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                status,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              fmtDate(entry['sent_at']),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: kWebTextHint),
            ),
          ),
        ],
      ),
    );
  }
}
