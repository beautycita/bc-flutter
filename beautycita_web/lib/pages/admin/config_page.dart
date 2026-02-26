import 'package:beautycita_core/supabase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../config/breakpoints.dart';
import '../../providers/admin_config_provider.dart';

/// Config page — `/app/admin/config`
///
/// Key-value settings editor + API status indicators.
class ConfigPage extends ConsumerStatefulWidget {
  const ConfigPage({super.key});

  @override
  ConsumerState<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends ConsumerState<ConfigPage> {
  String? _editingId;
  final _editController = TextEditingController();

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  Future<void> _saveValue(ConfigEntry entry) async {
    if (!BCSupabase.isInitialized) return;

    final newValue = _editController.text;
    try {
      await BCSupabase.client
          .from('app_config')
          .update({
            'value': newValue,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', entry.id);

      ref.invalidate(appConfigProvider);
      ref.invalidate(apiStatusProvider);
      ref.invalidate(featureTogglesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Guardado: ${entry.key}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }

    setState(() => _editingId = null);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = WebBreakpoints.isMobile(width);
        final isDesktop = WebBreakpoints.isDesktop(width);

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16.0 : 24.0,
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(isMobile: isMobile),
              const SizedBox(height: 24),

              // API status section
              _ApiStatusSection(ref: ref, isDesktop: isDesktop),
              const SizedBox(height: 32),

              // Config table
              _ConfigTableSection(
                ref: ref,
                editingId: _editingId,
                editController: _editController,
                onStartEdit: (entry) {
                  setState(() {
                    _editingId = entry.id;
                    _editController.text = entry.value;
                  });
                },
                onSave: _saveValue,
                onCancel: () => setState(() => _editingId = null),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.isMobile});
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Configuracion',
          style: (isMobile
                  ? theme.textTheme.headlineSmall
                  : theme.textTheme.headlineMedium)
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Claves de configuracion de la aplicacion y estado de APIs externas.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

// ── API Status Section ─────────────────────────────────────────────────────

class _ApiStatusSection extends StatelessWidget {
  const _ApiStatusSection({required this.ref, required this.isDesktop});
  final WidgetRef ref;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusAsync = ref.watch(apiStatusProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Estado de APIs',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        statusAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (e, _) => Text('Error: $e'),
          data: (statuses) {
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final status in statuses)
                  _ApiStatusCard(status: status),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ApiStatusCard extends StatefulWidget {
  const _ApiStatusCard({required this.status});
  final ApiStatus status;

  @override
  State<_ApiStatusCard> createState() => _ApiStatusCardState();
}

class _ApiStatusCardState extends State<_ApiStatusCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isConnected = widget.status.isConnected;
    final dotColor =
        isConnected ? const Color(0xFF4CAF50) : const Color(0xFFE53935);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 200,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _hovering
                ? dotColor.withValues(alpha: 0.4)
                : colors.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            // Status dot
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                boxShadow: isConnected
                    ? [
                        BoxShadow(
                          color: dotColor.withValues(alpha: 0.4),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.status.name,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.status.statusText,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: dotColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Config table section ───────────────────────────────────────────────────

class _ConfigTableSection extends StatelessWidget {
  const _ConfigTableSection({
    required this.ref,
    required this.editingId,
    required this.editController,
    required this.onStartEdit,
    required this.onSave,
    required this.onCancel,
  });

  final WidgetRef ref;
  final String? editingId;
  final TextEditingController editController;
  final ValueChanged<ConfigEntry> onStartEdit;
  final ValueChanged<ConfigEntry> onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final configAsync = ref.watch(appConfigProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Claves de configuracion',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        configAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (e, _) => Text('Error: $e'),
          data: (entries) {
            if (entries.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Center(
                  child: Text(
                    'Sin entradas de configuracion',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(11),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Clave',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Text(
                            'Valor',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          child: Text(
                            'Tipo',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Text(
                            'Actualizado',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 60), // action column
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Rows
                  for (var i = 0; i < entries.length; i++)
                    _ConfigRow(
                      entry: entries[i],
                      isEven: i.isEven,
                      isEditing: editingId == entries[i].id,
                      editController: editController,
                      onStartEdit: () => onStartEdit(entries[i]),
                      onSave: () => onSave(entries[i]),
                      onCancel: onCancel,
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── Config row ─────────────────────────────────────────────────────────────

class _ConfigRow extends StatefulWidget {
  const _ConfigRow({
    required this.entry,
    required this.isEven,
    required this.isEditing,
    required this.editController,
    required this.onStartEdit,
    required this.onSave,
    required this.onCancel,
  });

  final ConfigEntry entry;
  final bool isEven;
  final bool isEditing;
  final TextEditingController editController;
  final VoidCallback onStartEdit;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  State<_ConfigRow> createState() => _ConfigRowState();
}

class _ConfigRowState extends State<_ConfigRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.isEditing ? null : widget.onStartEdit,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isEditing
                ? colors.primary.withValues(alpha: 0.06)
                : _hovering
                    ? colors.primary.withValues(alpha: 0.03)
                    : widget.isEven
                        ? colors.onSurface.withValues(alpha: 0.02)
                        : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: colors.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
          child: Row(
            children: [
              // Key
              Expanded(
                flex: 3,
                child: Text(
                  widget.entry.key,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Value
              Expanded(
                flex: 4,
                child: widget.isEditing
                    ? Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: widget.editController,
                              autofocus: true,
                              style: theme.textTheme.bodySmall,
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                              ),
                              onSubmitted: (_) => widget.onSave(),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.check, size: 16),
                            onPressed: widget.onSave,
                            color: const Color(0xFF4CAF50),
                            tooltip: 'Guardar',
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: widget.onCancel,
                            color: colors.error,
                            tooltip: 'Cancelar',
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        widget.entry.value.length > 40
                            ? '${widget.entry.value.substring(0, 40)}...'
                            : widget.entry.value,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
              // Type
              SizedBox(
                width: 60,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.entry.type,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontFamily: 'monospace',
                      color: colors.onSurface.withValues(alpha: 0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              // Updated at
              SizedBox(
                width: 100,
                child: Text(
                  widget.entry.updatedAt != null
                      ? DateFormat('d/M HH:mm')
                          .format(widget.entry.updatedAt!)
                      : '--',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
              // Edit icon
              SizedBox(
                width: 60,
                child: _hovering && !widget.isEditing
                    ? IconButton(
                        icon: Icon(
                          Icons.edit,
                          size: 16,
                          color: colors.primary,
                        ),
                        onPressed: widget.onStartEdit,
                        tooltip: 'Editar',
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
