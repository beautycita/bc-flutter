import 'package:flutter/material.dart';
import 'package:beautycita/config/app_transitions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/config/fonts.dart';
import '../../config/constants.dart';
import '../../providers/admin_provider.dart';
import 'package:beautycita_core/supabase.dart';
import '../../services/supabase_client.dart';
import '../../services/toast_service.dart';

class CategoryTreeScreen extends ConsumerStatefulWidget {
  const CategoryTreeScreen({super.key});

  @override
  ConsumerState<CategoryTreeScreen> createState() =>
      _CategoryTreeScreenState();
}

class _CategoryTreeScreenState extends ConsumerState<CategoryTreeScreen> {
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = ref.watch(isSuperAdminProvider);
    if (isSuperAdmin.valueOrNull != true) {
      return const Center(child: Text('Acceso no autorizado'));
    }

    final treeAsync = ref.watch(categoryTreeProvider);
    final colors = Theme.of(context).colorScheme;

    return treeAsync.when(
      data: (nodes) => Scaffold(
        backgroundColor: Colors.transparent,
        body: _buildTree(nodes),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showCreateDialog(null, nodes),
          icon: const Icon(Icons.add),
          label: const Text('Agregar Categoria'),
          backgroundColor: colors.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: GoogleFonts.nunito(
                color: colors.onSurface.withValues(alpha: 0.5))),
      ),
    );
  }

  Widget _buildTree(List<CategoryNode> allNodes) {
    // Build parent-child map
    final roots = allNodes.where((n) => n.parentId == null).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final childrenOf = <String, List<CategoryNode>>{};
    for (final n in allNodes) {
      if (n.parentId != null) {
        childrenOf.putIfAbsent(n.parentId!, () => []);
        childrenOf[n.parentId!]!.add(n);
      }
    }
    for (final list in childrenOf.values) {
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    return ListView(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      children: [
        for (final root in roots)
          _buildNode(root, childrenOf, 0),
      ],
    );
  }

  Widget _buildNode(
    CategoryNode node,
    Map<String, List<CategoryNode>> childrenOf,
    int indent,
  ) {
    final children = childrenOf[node.id] ?? [];
    final hasChildren = children.isNotEmpty;
    final isExpanded = _expanded.contains(node.id);
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        Card(
          elevation: 0,
          color: indent == 0 ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
          margin: EdgeInsets.only(
            left: indent * 16.0,
            bottom: 4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              indent == 0
                  ? AppConstants.radiusMD
                  : AppConstants.radiusSM,
            ),
          ),
          child: InkWell(
            onTap: hasChildren
                ? () => setState(() {
                      if (isExpanded) {
                        _expanded.remove(node.id);
                      } else {
                        _expanded.add(node.id);
                      }
                    })
                : null,
            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.paddingMD,
                vertical: AppConstants.paddingSM + 2,
              ),
              child: Row(
                children: [
                  // Expand/collapse or leaf indicator
                  if (hasChildren)
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: colors.onSurface.withValues(alpha: 0.5),
                    )
                  else
                    const SizedBox(width: 20),
                  const SizedBox(width: 8),

                  // Icon
                  if (node.icon != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(node.icon!, style: const TextStyle(fontSize: 18)),
                    ),

                  // Name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          node.displayNameEs,
                          style: GoogleFonts.poppins(
                            fontSize: indent == 0 ? 15 : 14,
                            fontWeight: indent == 0
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: node.isActive
                                ? colors.onSurface
                                : colors.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        if (node.isLeaf && node.serviceType != null)
                          Text(
                            node.displayNameEs,
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              color: colors.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Active badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: node.isActive
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      node.isActive ? 'activa' : 'inactiva',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: node.isActive ? Colors.green : Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),

                  // Add subcategory button
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    color: colors.primary.withValues(alpha: 0.7),
                    onPressed: () => _showCreateDialog(node.id, []),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Agregar subcategoría',
                  ),

                  // Edit button
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: colors.onSurface.withValues(alpha: 0.5),
                    onPressed: () => _showEditDialog(node),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),

                  // Delete button
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: Colors.red.withValues(alpha: 0.6),
                    onPressed: () => _confirmDelete(node, childrenOf),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Eliminar',
                  ),
                ],
              ),
            ),
          ),
        ),

        // Children
        if (isExpanded)
          for (final child in children)
            _buildNode(child, childrenOf, indent + 1),
      ],
    );
  }

  void _showCreateDialog(String? parentId, List<CategoryNode> allNodes) {
    final nameEsCtrl = TextEditingController();
    final nameEnCtrl = TextEditingController();
    final iconCtrl = TextEditingController();
    final slugCtrl = TextEditingController();
    final colors = Theme.of(context).colorScheme;

    // Calculate depth and sort_order
    final depth = parentId == null ? 0 : 1; // simplified; real depth from parent
    // For root nodes calculate from allNodes; for children we don't have them here
    final sortOrder = 999; // will go to end

    showBurstDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        ),
        title: Text(
          parentId == null ? 'Nueva Categoría' : 'Nueva Subcategoría',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameEsCtrl,
                decoration: InputDecoration(
                  labelText: 'Nombre (ES) *',
                  labelStyle: GoogleFonts.nunito(fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameEnCtrl,
                decoration: InputDecoration(
                  labelText: 'Nombre (EN)',
                  labelStyle: GoogleFonts.nunito(fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: iconCtrl,
                      decoration: InputDecoration(
                        labelText: 'Icono (emoji)',
                        labelStyle: GoogleFonts.nunito(fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: slugCtrl,
                      decoration: InputDecoration(
                        labelText: 'Slug *',
                        labelStyle: GoogleFonts.nunito(fontSize: 13),
                        hintText: 'ej: corte_cabello',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameEsCtrl.text.trim().isEmpty || slugCtrl.text.trim().isEmpty) {
                ToastService.showError('Nombre (ES) y slug son requeridos');
                return;
              }
              try {
                await SupabaseClientService.client
                    .from(BCTables.serviceCategoriesTree)
                    .insert({
                      'parent_id': parentId,
                      'display_name_es': nameEsCtrl.text.trim(),
                      'display_name_en': nameEnCtrl.text.trim().isEmpty
                          ? nameEsCtrl.text.trim()
                          : nameEnCtrl.text.trim(),
                      'slug': slugCtrl.text.trim(),
                      'icon': iconCtrl.text.trim().isEmpty ? null : iconCtrl.text.trim(),
                      'depth': depth,
                      'sort_order': sortOrder,
                      'is_active': true,
                      'is_leaf': true,
                    });
                ref.invalidate(categoryTreeProvider);
                if (ctx.mounted) Navigator.pop(ctx);
                ToastService.showSuccess('${nameEsCtrl.text} creada');
              } catch (e, stack) {
                ToastService.showErrorWithDetails(
                    ToastService.friendlyError(e), e, stack);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: const Text('CREAR'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
      CategoryNode node, Map<String, List<CategoryNode>> childrenOf) {
    final children = childrenOf[node.id] ?? [];
    if (children.isNotEmpty) {
      ToastService.showError(
          'No se puede eliminar: tiene ${children.length} subcategorías');
      return;
    }

    showBurstDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        ),
        title: Text(
          'Eliminar categoría',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.red,
          ),
        ),
        content: Text(
          '¿Eliminar "${node.displayNameEs}"? Esta acción no se puede deshacer.',
          style: GoogleFonts.nunito(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await SupabaseClientService.client
                    .from(BCTables.serviceCategoriesTree)
                    .delete()
                    .eq('id', node.id);
                ref.invalidate(categoryTreeProvider);
                if (ctx.mounted) Navigator.pop(ctx);
                ToastService.showSuccess('${node.displayNameEs} eliminada');
              } catch (e, stack) {
                ToastService.showErrorWithDetails(
                    ToastService.friendlyError(e), e, stack);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(CategoryNode node) {
    final nameEsCtrl = TextEditingController(text: node.displayNameEs);
    final nameEnCtrl = TextEditingController(text: node.displayNameEn);
    final iconCtrl = TextEditingController(text: node.icon ?? '');
    final slugCtrl = TextEditingController(text: node.slug);
    var isActive = node.isActive;
    final colors = Theme.of(context).colorScheme;

    showBurstDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          ),
          title: Text(
            'Editar: ${node.displayNameEs}',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameEsCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nombre (ES)',
                    labelStyle: GoogleFonts.nunito(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameEnCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nombre (EN)',
                    labelStyle: GoogleFonts.nunito(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: iconCtrl,
                        decoration: InputDecoration(
                          labelText: 'Icono',
                          labelStyle: GoogleFonts.nunito(fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: slugCtrl,
                        decoration: InputDecoration(
                          labelText: 'Slug',
                          labelStyle: GoogleFonts.nunito(fontSize: 13),
                        ),
                        enabled: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Activa',
                        style: GoogleFonts.nunito(fontSize: 14)),
                    Switch(
                      value: isActive,
                      activeThumbColor: colors.primary,
                      onChanged: (v) =>
                          setDialogState(() => isActive = v),
                    ),
                  ],
                ),
                if (node.isLeaf && node.serviceType != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Text('Perfil: ',
                            style: GoogleFonts.nunito(
                                fontSize: 13,
                                color: colors.onSurface.withValues(alpha: 0.5))),
                        Text(node.displayNameEs,
                            style: GoogleFonts.nunito(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () async {
                await SupabaseClientService.client
                    .from(BCTables.serviceCategoriesTree)
                    .update({
                      'display_name_es': nameEsCtrl.text,
                      'display_name_en': nameEnCtrl.text,
                      'icon': iconCtrl.text.isEmpty ? null : iconCtrl.text,
                      'is_active': isActive,
                    }).eq('id', node.id);

                ref.invalidate(categoryTreeProvider);
                if (ctx.mounted) Navigator.pop(ctx);
                ToastService.showSuccess('${nameEsCtrl.text} guardado');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: const Text('GUARDAR'),
            ),
          ],
        ),
      ),
    );
  }
}
