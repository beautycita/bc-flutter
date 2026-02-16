import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/constants.dart';
import '../../providers/admin_provider.dart';
import '../../services/supabase_client.dart';

class NotificationTemplatesScreen extends ConsumerStatefulWidget {
  const NotificationTemplatesScreen({super.key});

  @override
  ConsumerState<NotificationTemplatesScreen> createState() =>
      _NotificationTemplatesScreenState();
}

class _NotificationTemplatesScreenState
    extends ConsumerState<NotificationTemplatesScreen> {
  String? _editingId;
  final _bodyCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _bodyCtrl.dispose();
    _subjectCtrl.dispose();
    super.dispose();
  }

  IconData _channelIcon(String channel) {
    switch (channel) {
      case 'push':
        return Icons.notifications;
      case 'whatsapp':
        return Icons.chat;
      case 'sms':
        return Icons.sms;
      case 'email':
        return Icons.email;
      default:
        return Icons.message;
    }
  }

  Color _channelColor(String channel) {
    switch (channel) {
      case 'push':
        return Colors.blue;
      case 'whatsapp':
        return Colors.green;
      case 'sms':
        return Colors.orange;
      case 'email':
        return Colors.purple;
      default:
        return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(notificationTemplatesProvider);
    final colors = Theme.of(context).colorScheme;

    return templatesAsync.when(
      data: (templates) {
        // Group by event_type
        final groups = <String, List<NotificationTemplate>>{};
        for (final t in templates) {
          groups.putIfAbsent(t.eventType, () => []);
          groups[t.eventType]!.add(t);
        }
        final events = groups.keys.toList()..sort();

        return ListView.builder(
          padding: const EdgeInsets.all(AppConstants.paddingMD),
          itemCount: events.length,
          itemBuilder: (context, i) {
            final event = events[i];
            final items = groups[event]!;
            return _EventGroup(
              eventType: event,
              templates: items,
              editingId: _editingId,
              onTapEdit: (t) {
                setState(() {
                  _editingId = t.id;
                  _subjectCtrl.text = t.subjectEs ?? '';
                  _bodyCtrl.text = t.bodyEs;
                });
              },
              onSave: (t) => _saveTemplate(t),
              onCancel: () => setState(() => _editingId = null),
              bodyCtrl: _bodyCtrl,
              subjectCtrl: _subjectCtrl,
              saving: _saving,
              channelIcon: _channelIcon,
              channelColor: _channelColor,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: GoogleFonts.nunito(
                color: colors.onSurface.withValues(alpha: 0.5))),
      ),
    );
  }

  Future<void> _saveTemplate(NotificationTemplate t) async {
    setState(() => _saving = true);
    try {
      await SupabaseClientService.client
          .from('notification_templates')
          .update({
            'subject_es': _subjectCtrl.text.isEmpty
                ? null
                : _subjectCtrl.text,
            'body_es': _bodyCtrl.text,
          }).eq('id', t.id);

      ref.invalidate(notificationTemplatesProvider);
      if (mounted) {
        setState(() => _editingId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Plantilla guardada'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _EventGroup extends StatelessWidget {
  final String eventType;
  final List<NotificationTemplate> templates;
  final String? editingId;
  final ValueChanged<NotificationTemplate> onTapEdit;
  final ValueChanged<NotificationTemplate> onSave;
  final VoidCallback onCancel;
  final TextEditingController bodyCtrl;
  final TextEditingController subjectCtrl;
  final bool saving;
  final IconData Function(String) channelIcon;
  final Color Function(String) channelColor;

  const _EventGroup({
    required this.eventType,
    required this.templates,
    required this.editingId,
    required this.onTapEdit,
    required this.onSave,
    required this.onCancel,
    required this.bodyCtrl,
    required this.subjectCtrl,
    required this.saving,
    required this.channelIcon,
    required this.channelColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      ),
      margin: const EdgeInsets.only(bottom: AppConstants.paddingSM),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eventType.replaceAll('_', ' ').toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.primary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            ...templates.map((t) {
              final isEditing = editingId == t.id;
              return Column(
                children: [
                  InkWell(
                    onTap: isEditing ? null : () => onTapEdit(t),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(channelIcon(t.channel),
                              size: 18, color: channelColor(t.channel)),
                          const SizedBox(width: 8),
                          Text(
                            t.channel.toUpperCase(),
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: channelColor(t.channel),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              t.bodyEs,
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                color: colors.onSurface,
                              ),
                              maxLines: isEditing ? null : 1,
                              overflow:
                                  isEditing ? null : TextOverflow.ellipsis,
                            ),
                          ),
                          if (!isEditing)
                            Icon(Icons.edit_outlined,
                                size: 16,
                                color: colors.onSurface.withValues(alpha: 0.5)),
                        ],
                      ),
                    ),
                  ),
                  if (isEditing) ...[
                    const SizedBox(height: 8),
                    if (t.channel == 'email')
                      TextField(
                        controller: subjectCtrl,
                        decoration: InputDecoration(
                          labelText: 'Asunto',
                          labelStyle: GoogleFonts.nunito(fontSize: 13),
                          isDense: true,
                        ),
                      ),
                    if (t.channel == 'email')
                      const SizedBox(height: 8),
                    TextField(
                      controller: bodyCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Cuerpo',
                        labelStyle: GoogleFonts.nunito(fontSize: 13),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Variables: {{user_name}}, {{salon_name}}, {{service}}, {{date}}, {{time}}',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: onCancel,
                          child: const Text('CANCELAR'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: saving ? null : () => onSave(t),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(80, 36),
                          ),
                          child: saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                            Colors.white),
                                  ),
                                )
                              : const Text('GUARDAR'),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}
