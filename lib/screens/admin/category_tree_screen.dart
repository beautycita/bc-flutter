import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../providers/admin_provider.dart';
import '../../services/supabase_client.dart';

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
    final treeAsync = ref.watch(categoryTreeProvider);

    return treeAsync.when(
      data: (nodes) => _buildTree(nodes),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: GoogleFonts.nunito(color: BeautyCitaTheme.textLight)),
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
      padding: const EdgeInsets.all(BeautyCitaTheme.spaceMD),
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

    return Column(
      children: [
        Card(
          elevation: 0,
          color: indent == 0 ? Colors.white : Colors.white.withValues(alpha: 0.7),
          margin: EdgeInsets.only(
            left: indent * 16.0,
            bottom: 4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              indent == 0
                  ? BeautyCitaTheme.radiusMedium
                  : BeautyCitaTheme.radiusSmall,
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
            borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BeautyCitaTheme.spaceMD,
                vertical: BeautyCitaTheme.spaceSM + 2,
              ),
              child: Row(
                children: [
                  // Expand/collapse or leaf indicator
                  if (hasChildren)
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: BeautyCitaTheme.textLight,
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
                                ? BeautyCitaTheme.textDark
                                : BeautyCitaTheme.textLight,
                          ),
                        ),
                        if (node.isLeaf && node.serviceType != null)
                          Text(
                            node.serviceType!,
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              color: BeautyCitaTheme.textLight,
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

                  // Edit button
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: BeautyCitaTheme.textLight,
                    onPressed: () => _showEditDialog(node),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
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

  void _showEditDialog(CategoryNode node) {
    final nameEsCtrl = TextEditingController(text: node.displayNameEs);
    final nameEnCtrl = TextEditingController(text: node.displayNameEn);
    final iconCtrl = TextEditingController(text: node.icon ?? '');
    final slugCtrl = TextEditingController(text: node.slug);
    var isActive = node.isActive;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
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
                          labelText: 'Ícono',
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
                      activeColor: BeautyCitaTheme.primaryRose,
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
                                color: BeautyCitaTheme.textLight)),
                        Text(node.serviceType!,
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
                    .from('service_categories_tree')
                    .update({
                      'display_name_es': nameEsCtrl.text,
                      'display_name_en': nameEnCtrl.text,
                      'icon': iconCtrl.text.isEmpty ? null : iconCtrl.text,
                      'is_active': isActive,
                    }).eq('id', node.id);

                ref.invalidate(categoryTreeProvider);
                if (ctx.mounted) Navigator.pop(ctx);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${nameEsCtrl.text} guardado'),
                      backgroundColor: BeautyCitaTheme.primaryRose,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: BeautyCitaTheme.primaryRose,
                foregroundColor: Colors.white,
              ),
              child: const Text('GUARDAR'),
            ),
          ],
        ),
      ),
    );
  }
}
