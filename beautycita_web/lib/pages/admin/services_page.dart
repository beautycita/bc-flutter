import 'package:beautycita_core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/breakpoints.dart';
import '../../providers/admin_services_provider.dart';

/// Admin service catalog page — tree view + editor.
///
/// Layout:
/// - Left panel: expandable tree with category/subcategory/item hierarchy
/// - Right panel: editor for selected item (name, description, price range, duration)
/// - Actions: add category, add subcategory, add item, delete, reorder
class ServicesPage extends ConsumerWidget {
  const ServicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treeAsync = ref.watch(serviceTreeProvider);
    final selectedId = ref.watch(selectedServiceNodeProvider);

    return treeAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (tree) {
        final selectedNode =
            selectedId != null ? tree.findById(selectedId) : null;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = WebBreakpoints.isDesktop(constraints.maxWidth);

            if (isDesktop) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tree panel
                  SizedBox(
                    width: 380,
                    child: _TreePanel(tree: tree, selectedId: selectedId),
                  ),
                  VerticalDivider(width: 1),
                  // Editor panel
                  Expanded(
                    child: selectedNode != null
                        ? _EditorPanel(node: selectedNode)
                        : _EmptyEditor(),
                  ),
                ],
              );
            }

            // Tablet/mobile: stacked, or show editor as overlay
            if (selectedNode != null) {
              return _EditorPanel(
                node: selectedNode,
                showBackButton: true,
                onBack: () => ref
                    .read(selectedServiceNodeProvider.notifier)
                    .state = null,
              );
            }

            return _TreePanel(tree: tree, selectedId: selectedId);
          },
        );
      },
    );
  }
}

// ── Tree Panel ───────────────────────────────────────────────────────────────

class _TreePanel extends ConsumerWidget {
  const _TreePanel({required this.tree, required this.selectedId});
  final ServiceTree tree;
  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ColoredBox(
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with add button
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: BCSpacing.md,
              vertical: BCSpacing.sm,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: colors.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.account_tree, size: 20, color: colors.primary),
                const SizedBox(width: BCSpacing.sm),
                Expanded(
                  child: Text(
                    'Catalogo de Servicios',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                PopupMenuButton<int>(
                  icon: Icon(Icons.add, color: colors.primary),
                  tooltip: 'Agregar',
                  onSelected: (level) {
                    // TODO: Add new category/subcategory/item
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 0,
                      child: Text('Nueva categoria'),
                    ),
                    const PopupMenuItem(
                      value: 1,
                      child: Text('Nueva subcategoria'),
                    ),
                    const PopupMenuItem(
                      value: 2,
                      child: Text('Nuevo servicio'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tree content
          Expanded(
            child: tree.roots.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(BCSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.category_outlined,
                            size: 48,
                            color: colors.onSurface.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: BCSpacing.md),
                          Text(
                            'Sin categorias',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colors.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: BCSpacing.sm),
                          Text(
                            'Agrega tu primera categoria para comenzar',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurface.withValues(alpha: 0.4),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: BCSpacing.sm),
                    children: [
                      for (final root in tree.roots)
                        _TreeNodeWidget(node: root, depth: 0),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Tree Node Widget ─────────────────────────────────────────────────────────

class _TreeNodeWidget extends ConsumerWidget {
  const _TreeNodeWidget({required this.node, required this.depth});
  final ServiceTreeNode node;
  final int depth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selectedId = ref.watch(selectedServiceNodeProvider);
    final expandedIds = ref.watch(expandedServiceNodesProvider);
    final isSelected = selectedId == node.id;
    final isExpanded = expandedIds.contains(node.id);
    final hasChildren = node.children.isNotEmpty;

    final (IconData icon, Color iconColor) = switch (node.level) {
      0 => (Icons.folder, const Color(0xFFFF9800)),
      1 => (Icons.folder_open, const Color(0xFF2196F3)),
      _ => (Icons.spa, const Color(0xFF4CAF50)),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Node row
        _HoverableRow(
          isSelected: isSelected,
          onTap: () {
            ref.read(selectedServiceNodeProvider.notifier).state = node.id;
          },
          child: Padding(
            padding: EdgeInsets.only(
              left: BCSpacing.md + (depth * 24.0),
              right: BCSpacing.sm,
              top: BCSpacing.xs,
              bottom: BCSpacing.xs,
            ),
            child: Row(
              children: [
                // Expand/collapse toggle
                SizedBox(
                  width: 28,
                  height: 28,
                  child: hasChildren
                      ? IconButton(
                          icon: Icon(
                            isExpanded
                                ? Icons.expand_more
                                : Icons.chevron_right,
                            size: 18,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            final updated =
                                Set<String>.from(expandedIds);
                            if (isExpanded) {
                              updated.remove(node.id);
                            } else {
                              updated.add(node.id);
                            }
                            ref
                                .read(
                                    expandedServiceNodesProvider.notifier)
                                .state = updated;
                          },
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: 4),
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: BCSpacing.sm),
                Expanded(
                  child: Text(
                    node.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: node.level < 2
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected
                          ? colors.primary
                          : colors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Count badge for categories
                if (hasChildren)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.onSurface.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${node.children.length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color:
                            colors.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                // Reorder handles
                IconButton(
                  icon: Icon(Icons.drag_handle,
                      size: 16,
                      color: colors.onSurface.withValues(alpha: 0.3)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  onPressed: () {
                    // TODO: Reorder via up/down or drag
                  },
                  tooltip: 'Reordenar',
                ),
              ],
            ),
          ),
        ),

        // Children (if expanded)
        if (isExpanded && hasChildren)
          for (final child in node.children)
            _TreeNodeWidget(node: child, depth: depth + 1),
      ],
    );
  }
}

// ── Hoverable Row ────────────────────────────────────────────────────────────

class _HoverableRow extends StatefulWidget {
  const _HoverableRow({
    required this.isSelected,
    required this.onTap,
    required this.child,
  });
  final bool isSelected;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_HoverableRow> createState() => _HoverableRowState();
}

class _HoverableRowState extends State<_HoverableRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    Color bgColor;
    if (widget.isSelected) {
      bgColor = colors.primary.withValues(alpha: 0.08);
    } else if (_hovering) {
      bgColor = colors.onSurface.withValues(alpha: 0.04);
    } else {
      bgColor = Colors.transparent;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            border: widget.isSelected
                ? Border(
                    left: BorderSide(color: colors.primary, width: 3),
                  )
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ── Editor Panel ─────────────────────────────────────────────────────────────

class _EditorPanel extends StatefulWidget {
  const _EditorPanel({
    required this.node,
    this.showBackButton = false,
    this.onBack,
  });
  final ServiceTreeNode node;
  final bool showBackButton;
  final VoidCallback? onBack;

  @override
  State<_EditorPanel> createState() => _EditorPanelState();
}

class _EditorPanelState extends State<_EditorPanel> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _minPriceController;
  late TextEditingController _maxPriceController;
  late TextEditingController _durationController;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void didUpdateWidget(covariant _EditorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.id != widget.node.id) {
      _initControllers();
    }
  }

  void _initControllers() {
    _nameController = TextEditingController(text: widget.node.name);
    _descController =
        TextEditingController(text: widget.node.description ?? '');
    _minPriceController = TextEditingController(
      text: widget.node.minPrice?.toStringAsFixed(0) ?? '',
    );
    _maxPriceController = TextEditingController(
      text: widget.node.maxPrice?.toStringAsFixed(0) ?? '',
    );
    _durationController = TextEditingController(
      text: widget.node.defaultDurationMinutes?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final node = widget.node;

    final (IconData levelIcon, Color levelColor) = switch (node.level) {
      0 => (Icons.folder, const Color(0xFFFF9800)),
      1 => (Icons.folder_open, const Color(0xFF2196F3)),
      _ => (Icons.spa, const Color(0xFF4CAF50)),
    };

    return ColoredBox(
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: BCSpacing.md,
              vertical: BCSpacing.sm,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: colors.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                if (widget.showBackButton) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 20),
                    onPressed: widget.onBack,
                    tooltip: 'Volver',
                  ),
                  const SizedBox(width: BCSpacing.xs),
                ],
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: levelColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(levelIcon, size: 18, color: levelColor),
                ),
                const SizedBox(width: BCSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Editar ${node.levelLabel}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'ID: ${node.id.substring(0, 8)}...',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.4),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                // Delete button
                IconButton(
                  icon: Icon(Icons.delete_outline, color: colors.error),
                  tooltip: 'Eliminar',
                  onPressed: () {
                    // TODO: Confirm and delete
                  },
                ),
              ],
            ),
          ),

          // Editor form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(BCSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  _FormField(
                    label: 'Nombre',
                    child: TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: 'Nombre del ${node.levelLabel.toLowerCase()}',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: BCSpacing.lg),

                  // Description
                  _FormField(
                    label: 'Descripcion',
                    child: TextField(
                      controller: _descController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Descripcion opcional',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: BCSpacing.lg),

                  // Price range (only for services)
                  if (node.level == 2) ...[
                    Text(
                      'Rango de precios (MXN)',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: BCSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minPriceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Minimo',
                              prefixText: '\$ ',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: BCSpacing.md),
                        Text(
                          '—',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.3),
                          ),
                        ),
                        const SizedBox(width: BCSpacing.md),
                        Expanded(
                          child: TextField(
                            controller: _maxPriceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Maximo',
                              prefixText: '\$ ',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: BCSpacing.lg),

                    // Duration
                    _FormField(
                      label: 'Duracion predeterminada',
                      child: TextField(
                        controller: _durationController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'ej. 45',
                          suffixText: 'minutos',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: BCSpacing.lg),
                  ],

                  // Sort order
                  _FormField(
                    label: 'Orden',
                    child: Text(
                      '${node.sortOrder}',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: BCSpacing.xl),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        // TODO: Save changes to Supabase
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar cambios'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty Editor ─────────────────────────────────────────────────────────────

class _EmptyEditor extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.touch_app_outlined,
            size: 48,
            color: colors.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(height: BCSpacing.md),
          Text(
            'Selecciona un elemento',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: BCSpacing.xs),
          Text(
            'Elige una categoria, subcategoria o servicio\npara ver y editar sus detalles',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.3),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Reusable form field ──────────────────────────────────────────────────────

class _FormField extends StatelessWidget {
  const _FormField({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: BCSpacing.sm),
        child,
      ],
    );
  }
}
