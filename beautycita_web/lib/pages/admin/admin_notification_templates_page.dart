import 'package:beautycita_core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../config/web_theme.dart';
import '../../providers/admin_notification_templates_provider.dart';

/// Admin Notification Templates page.
///
/// Lists all templates from the notification_templates table, grouped by
/// event_type. Each template has editable ES/EN text fields and a save button.
/// Desktop-first layout: two-column form (ES | EN) per template.
class AdminNotificationTemplatesPage extends ConsumerWidget {
  const AdminNotificationTemplatesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(adminNotificationTemplatesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageHeader(ref: ref),
          const SizedBox(height: 24),
          templatesAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => _ErrorCard(error: '$e'),
            data: (templates) => _TemplateList(templates: templates),
          ),
        ],
      ),
    );
  }
}

// ── Page header ───────────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Plantillas de Notificaciones',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: kWebTextPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Plantillas ES/EN por tipo de evento · Edita y guarda individualmente',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: kWebTextSecondary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_outlined),
          tooltip: 'Actualizar',
          onPressed: () =>
              ref.invalidate(adminNotificationTemplatesProvider),
          color: kWebTextSecondary,
        ),
      ],
    );
  }
}

// ── Error card ────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.error),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              error,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colors.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Template list — grouped by event_type ─────────────────────────────────────

class _TemplateList extends StatelessWidget {
  const _TemplateList({required this.templates});
  final List<NotificationTemplate> templates;

  @override
  Widget build(BuildContext context) {
    if (templates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 80),
          child: Text(
            'No hay plantillas configuradas',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: kWebTextSecondary,
                ),
          ),
        ),
      );
    }

    // Group by event_type (first word before '_' for visual section headers)
    final grouped = <String, List<NotificationTemplate>>{};
    for (final t in templates) {
      final group = _groupLabel(t.eventType);
      grouped.putIfAbsent(group, () => []).add(t);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries.map((entry) {
        return _TemplateGroup(
          groupLabel: entry.key,
          templates: entry.value,
        );
      }).toList(),
    );
  }

  String _groupLabel(String eventType) {
    // e.g. "booking_confirmed" → "booking"
    final parts = eventType.split('_');
    return parts.first.toUpperCase();
  }
}

class _TemplateGroup extends StatelessWidget {
  const _TemplateGroup({
    required this.groupLabel,
    required this.templates,
  });

  final String groupLabel;
  final List<NotificationTemplate> templates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  gradient: kWebBrandGradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                groupLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: kWebTextPrimary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        ...templates.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TemplateCard(template: t),
            )),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ── Individual template card ──────────────────────────────────────────────────

class _TemplateCard extends ConsumerStatefulWidget {
  const _TemplateCard({required this.template});
  final NotificationTemplate template;

  @override
  ConsumerState<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends ConsumerState<_TemplateCard> {
  late final TextEditingController _esCtrl;
  late final TextEditingController _enCtrl;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _esCtrl = TextEditingController(
        text: widget.template.templateEs ?? '');
    _enCtrl = TextEditingController(
        text: widget.template.templateEn ?? '');
    _esCtrl.addListener(_markDirty);
    _enCtrl.addListener(_markDirty);
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _esCtrl.dispose();
    _enCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref.read(templateSaveProvider.notifier).save(
          widget.template.id,
          _esCtrl.text.trim().isEmpty ? null : _esCtrl.text.trim(),
          _enCtrl.text.trim().isEmpty ? null : _enCtrl.text.trim(),
        );
    if (mounted) setState(() => _dirty = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final saveState = ref.watch(templateSaveProvider);
    final isSaving = saveState.savingId == widget.template.id;
    final hasError = saveState.errorId == widget.template.id;
    final wasSaved = saveState.savedIds.contains(widget.template.id) &&
        !_dirty &&
        !isSaving;
    final dateFormat = DateFormat('d MMM yy HH:mm', 'es');

    return Container(
      decoration: BoxDecoration(
        color: kWebSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _dirty
              ? kWebPrimary.withValues(alpha: 0.4)
              : kWebCardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: kWebPrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.template.eventType,
                    style: TextStyle(
                      color: kWebPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'actualizado ${dateFormat.format(widget.template.updatedAt)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: kWebTextHint,
                  ),
                ),
                const Spacer(),
                // Save button
                if (isSaving)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (wasSaved)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 16, color: Colors.green[700]),
                      const SizedBox(width: 4),
                      Text(
                        'Guardado',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  )
                else if (hasError)
                  Tooltip(
                    message: 'Error al guardar. Reintenta.',
                    child: Icon(Icons.error_outline,
                        size: 18, color: theme.colorScheme.error),
                  )
                else
                  FilledButton(
                    onPressed: _dirty ? _save : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: kWebPrimary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Guardar',
                        style: TextStyle(fontSize: 13)),
                  ),
              ],
            ),
          ),

          const Divider(height: 1, color: kWebCardBorder),

          // Text fields — two-column on desktop
          Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(builder: (context, constraints) {
              final useColumns = constraints.maxWidth >= 700;
              if (useColumns) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: _TemplateField(
                      label: 'Español (ES)',
                      controller: _esCtrl,
                      flag: '🇲🇽',
                    )),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _TemplateField(
                      label: 'English (EN)',
                      controller: _enCtrl,
                      flag: '🇺🇸',
                    )),
                  ],
                );
              }
              return Column(
                children: [
                  _TemplateField(
                    label: 'Español (ES)',
                    controller: _esCtrl,
                    flag: '🇲🇽',
                  ),
                  const SizedBox(height: 12),
                  _TemplateField(
                    label: 'English (EN)',
                    controller: _enCtrl,
                    flag: '🇺🇸',
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _TemplateField extends StatelessWidget {
  const _TemplateField({
    required this.label,
    required this.controller,
    required this.flag,
  });

  final String label;
  final TextEditingController controller;
  final String flag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: kWebTextSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: 4,
          style: theme.textTheme.bodySmall?.copyWith(
            color: kWebTextPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Texto de la plantilla...',
            hintStyle: theme.textTheme.bodySmall?.copyWith(
              color: kWebTextHint,
            ),
            filled: true,
            fillColor: kWebBackground,
            contentPadding: const EdgeInsets.all(BCSpacing.sm),
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(BCSpacing.radiusXs),
              borderSide:
                  const BorderSide(color: kWebCardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(BCSpacing.radiusXs),
              borderSide:
                  const BorderSide(color: kWebCardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(BCSpacing.radiusXs),
              borderSide:
                  const BorderSide(color: kWebPrimary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
