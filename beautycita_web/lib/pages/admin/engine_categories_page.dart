import 'package:beautycita_core/supabase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/breakpoints.dart';
import '../../config/router.dart';
import '../../providers/admin_engine_provider.dart';

/// Engine categories page — `/app/admin/engine/categories`
///
/// Tree view of categories -> subcategories -> items.
/// Each node shows name, sort order, active status.
/// Inline edit, add/delete, reorder.
class EngineCategoriesPage extends ConsumerStatefulWidget {
  const EngineCategoriesPage({super.key});

  @override
  ConsumerState<EngineCategoriesPage> createState() =>
      _EngineCategoriesPageState();
}

class _EngineCategoriesPageState
    extends ConsumerState<EngineCategoriesPage> {
  String? _editingId;
  final _editController = TextEditingController();

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  Future<void> _toggleActive(CategoryNode node) async {
    if (!BCSupabase.isInitialized) return;
    try {
      await BCSupabase.client
          .from('service_categories_tree')
          .update({'is_active': !node.isActive})
          .eq('id', node.id);
      ref.invalidate(categoryTreeProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _rename(String id, String newName) async {
    if (!BCSupabase.isInitialized || newName.trim().isEmpty) return;
    try {
      await BCSupabase.client
          .from('service_categories_tree')
          .update({'name': newName.trim()})
          .eq('id', id);
      ref.invalidate(categoryTreeProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al renombrar: $e')),
        );
      }
    }
    setState(() => _editingId = null);
  }

  Future<void> _reorder(String id, int newSortOrder) async {
    if (!BCSupabase.isInitialized) return;
    try {
      await BCSupabase.client
          .from('service_categories_tree')
          .update({'sort_order': newSortOrder})
          .eq('id', id);
      ref.invalidate(categoryTreeProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al reordenar: $e')),
        );
      }
    }
  }

  Future<void> _delete(String id) async {
    if (!BCSupabase.isInitialized) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar categoria'),
        content: const Text(
            'Se eliminara esta categoria y todas sus subcategorias. Continuar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await BCSupabase.client
          .from('service_categories_tree')
          .delete()
          .eq('id', id);
      ref.invalidate(categoryTreeProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    }
  }

  Future<void> _addChild(String? parentId) async {
    if (!BCSupabase.isInitialized) return;

    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            parentId == null ? 'Nueva categoria' : 'Nueva subcategoria'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nombre',
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(ctx).pop(nameController.text),
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    nameController.dispose();

    if (name == null || name.trim().isEmpty) return;

    try {
      await BCSupabase.client.from('service_categories_tree').insert({
        'name': name.trim(),
        'parent_id': parentId,
        'sort_order': 0,
        'is_active': true,
      });
      ref.invalidate(categoryTreeProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final treeAsync = ref.watch(categoryTreeProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = WebBreakpoints.isMobile(width);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Breadcrumb(isMobile: isMobile),
            const Divider(height: 1),
            // Add root button
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16.0 : 24.0,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Text(
                    'Arbol de categorias',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () => _addChild(null),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nueva categoria'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: treeAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (roots) {
                  if (roots.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.account_tree,
                            size: 48,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Sin categorias. Crea la primera.',
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 8.0 : 16.0,
                      vertical: 8,
                    ),
                    children: [
                      for (final root in roots)
                        _TreeNodeWidget(
                          node: root,
                          depth: 0,
                          editingId: _editingId,
                          editController: _editController,
                          onStartEdit: (id, name) {
                            setState(() {
                              _editingId = id;
                              _editController.text = name;
                            });
                          },
                          onRename: _rename,
                          onToggleActive: _toggleActive,
                          onReorder: _reorder,
                          onDelete: _delete,
                          onAddChild: _addChild,
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Breadcrumb ─────────────────────────────────────────────────────────────

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.isMobile});
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16.0 : 24.0,
        vertical: 12,
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => context.go(WebRoutes.adminEngine),
            child: Text(
              'Motor',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.primary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.chevron_right,
              size: 18,
              color: colors.onSurface.withValues(alpha: 0.4),
            ),
          ),
          Text(
            'Categorias',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tree node widget ───────────────────────────────────────────────────────

class _TreeNodeWidget extends StatefulWidget {
  const _TreeNodeWidget({
    required this.node,
    required this.depth,
    required this.editingId,
    required this.editController,
    required this.onStartEdit,
    required this.onRename,
    required this.onToggleActive,
    required this.onReorder,
    required this.onDelete,
    required this.onAddChild,
  });

  final CategoryNode node;
  final int depth;
  final String? editingId;
  final TextEditingController editController;
  final void Function(String id, String name) onStartEdit;
  final Future<void> Function(String id, String name) onRename;
  final Future<void> Function(CategoryNode node) onToggleActive;
  final Future<void> Function(String id, int sortOrder) onReorder;
  final Future<void> Function(String id) onDelete;
  final Future<void> Function(String? parentId) onAddChild;

  @override
  State<_TreeNodeWidget> createState() => _TreeNodeWidgetState();
}

class _TreeNodeWidgetState extends State<_TreeNodeWidget> {
  bool _expanded = true;
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isEditing = widget.editingId == widget.node.id;
    final hasChildren = widget.node.children.isNotEmpty;
    final indent = 24.0 * widget.depth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: Container(
            padding: EdgeInsets.only(
              left: indent + 8,
              right: 8,
              top: 6,
              bottom: 6,
            ),
            decoration: BoxDecoration(
              color: _hovering
                  ? colors.primary.withValues(alpha: 0.04)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                // Expand/collapse button
                if (hasChildren)
                  InkWell(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Icon(
                      _expanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      size: 20,
                      color: colors.onSurface.withValues(alpha: 0.5),
                    ),
                  )
                else
                  const SizedBox(width: 20),
                const SizedBox(width: 8),

                // Active status indicator
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: widget.node.isActive
                        ? const Color(0xFF4CAF50)
                        : colors.onSurface.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),

                // Name or edit field
                Expanded(
                  child: isEditing
                      ? TextField(
                          controller: widget.editController,
                          autofocus: true,
                          style: theme.textTheme.bodyMedium,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                          ),
                          onSubmitted: (v) =>
                              widget.onRename(widget.node.id, v),
                        )
                      : GestureDetector(
                          onDoubleTap: () => widget.onStartEdit(
                              widget.node.id, widget.node.name),
                          child: Text(
                            widget.node.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: widget.depth == 0
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: widget.node.isActive
                                  ? null
                                  : colors.onSurface
                                      .withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                ),

                // Sort order badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#${widget.node.sortOrder}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),

                // Action buttons (visible on hover)
                if (_hovering) ...[
                  const SizedBox(width: 4),
                  // Move up
                  _SmallIconButton(
                    icon: Icons.arrow_upward,
                    tooltip: 'Subir',
                    onTap: () => widget.onReorder(
                        widget.node.id, widget.node.sortOrder - 1),
                  ),
                  // Move down
                  _SmallIconButton(
                    icon: Icons.arrow_downward,
                    tooltip: 'Bajar',
                    onTap: () => widget.onReorder(
                        widget.node.id, widget.node.sortOrder + 1),
                  ),
                  // Toggle active
                  _SmallIconButton(
                    icon: widget.node.isActive
                        ? Icons.visibility
                        : Icons.visibility_off,
                    tooltip: widget.node.isActive
                        ? 'Desactivar'
                        : 'Activar',
                    onTap: () => widget.onToggleActive(widget.node),
                  ),
                  // Add child
                  _SmallIconButton(
                    icon: Icons.add,
                    tooltip: 'Agregar hijo',
                    onTap: () => widget.onAddChild(widget.node.id),
                  ),
                  // Delete
                  _SmallIconButton(
                    icon: Icons.delete_outline,
                    tooltip: 'Eliminar',
                    color: colors.error,
                    onTap: () => widget.onDelete(widget.node.id),
                  ),
                ],
              ],
            ),
          ),
        ),
        // Children
        if (_expanded && hasChildren)
          for (final child in widget.node.children)
            _TreeNodeWidget(
              node: child,
              depth: widget.depth + 1,
              editingId: widget.editingId,
              editController: widget.editController,
              onStartEdit: widget.onStartEdit,
              onRename: widget.onRename,
              onToggleActive: widget.onToggleActive,
              onReorder: widget.onReorder,
              onDelete: widget.onDelete,
              onAddChild: widget.onAddChild,
            ),
      ],
    );
  }
}

// ── Small icon button ──────────────────────────────────────────────────────

class _SmallIconButton extends StatelessWidget {
  const _SmallIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 16,
            color: color ?? colors.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}
