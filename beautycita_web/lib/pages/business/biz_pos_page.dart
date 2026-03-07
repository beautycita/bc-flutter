import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:beautycita_core/models.dart' hide Provider;
import 'package:beautycita_core/supabase.dart';

import '../../config/breakpoints.dart';
import '../../providers/business_portal_provider.dart';
import '../../providers/demo_providers.dart';

// ── Providers ────────────────────────────────────────────────────────────────

/// Products for the current business.
final _businessProductsProvider =
    FutureProvider.autoDispose<List<Product>>((ref) async {
  final biz = await ref.watch(currentBusinessProvider.future);
  if (biz == null) return [];
  final bizId = biz['id'] as String;

  final rows = await BCSupabase.client
      .from(BCTables.products)
      .select()
      .eq('business_id', bizId)
      .order('category')
      .order('name');

  return (rows as List).map((r) => Product.fromJson(r as Map<String, dynamic>)).toList();
});

/// Product showcases for the current business, with joined product data.
final _businessShowcasesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final biz = await ref.watch(currentBusinessProvider.future);
  if (biz == null) return [];
  final bizId = biz['id'] as String;

  final rows = await BCSupabase.client
      .from(BCTables.productShowcases)
      .select('*, products(name, photo_url, price)')
      .eq('business_id', bizId)
      .order('created_at', ascending: false);

  return List<Map<String, dynamic>>.from(rows as List);
});

// ── Page ─────────────────────────────────────────────────────────────────────

/// Business POS management page — product catalog + showcase feed publishing.
class BizPosPage extends ConsumerWidget {
  const BizPosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bizAsync = ref.watch(currentBusinessProvider);

    return bizAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (biz) {
        if (biz == null) return const Center(child: Text('Sin negocio'));
        final posEnabled = biz['pos_enabled'] as bool? ?? false;
        if (!posEnabled) return _PosOptIn(biz: biz);
        return _PosContent(biz: biz);
      },
    );
  }
}

// ── Opt-in Card ──────────────────────────────────────────────────────────────

class _PosOptIn extends ConsumerStatefulWidget {
  const _PosOptIn({required this.biz});
  final Map<String, dynamic> biz;

  @override
  ConsumerState<_PosOptIn> createState() => _PosOptInState();
}

class _PosOptInState extends ConsumerState<_PosOptIn> {
  bool _loading = false;

  Future<void> _activate() async {
    setState(() => _loading = true);
    try {
      await BCSupabase.client
          .from(BCTables.businesses)
          .update({'pos_enabled': true})
          .eq('id', widget.biz['id'] as String);
      ref.invalidate(currentBusinessProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDemo = ref.watch(isDemoProvider);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.storefront_outlined, size: 64,
                    color: colors.primary.withValues(alpha: 0.6)),
                const SizedBox(height: 20),
                Text(
                  'Punto de Venta',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  'Vende productos de belleza directamente desde tu perfil. '
                  'Agrega tu catalogo, administra inventario y publica '
                  'productos en el feed de inspiracion de BeautyCita.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.6),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sin comisiones adicionales.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 28),
                if (!isDemo)
                  FilledButton.icon(
                    onPressed: _loading ? null : _activate,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.rocket_launch_outlined),
                    label: const Text('Activar Punto de Venta'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 16),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Main Content ─────────────────────────────────────────────────────────────

class _PosContent extends ConsumerStatefulWidget {
  const _PosContent({required this.biz});
  final Map<String, dynamic> biz;

  @override
  ConsumerState<_PosContent> createState() => _PosContentState();
}

class _PosContentState extends ConsumerState<_PosContent> {
  final _mxnFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final productsAsync = ref.watch(_businessProductsProvider);
    final showcasesAsync = ref.watch(_businessShowcasesProvider);
    final isDemo = ref.watch(isDemoProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = WebBreakpoints.isMobile(constraints.maxWidth);
        final padding = isMobile ? 16.0 : 24.0;

        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Punto de Venta',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (!isDemo)
                    FilledButton.icon(
                      onPressed: () => _showProductDialog(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Agregar Producto'),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Stats Row ───────────────────────────────────────────────
              productsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (products) {
                  final inStock =
                      products.where((p) => p.inStock).length;
                  final showcaseCount = showcasesAsync.valueOrNull?.length ?? 0;

                  return Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      _StatChip(
                        icon: Icons.inventory_2_outlined,
                        label: 'Productos',
                        value: '${products.length}',
                        color: colors.primary,
                      ),
                      _StatChip(
                        icon: Icons.check_circle_outline,
                        label: 'En stock',
                        value: '$inStock',
                        color: const Color(0xFF4CAF50),
                      ),
                      _StatChip(
                        icon: Icons.campaign_outlined,
                        label: 'Publicaciones',
                        value: '$showcaseCount',
                        color: const Color(0xFFFF9800),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // ── Products Table ──────────────────────────────────────────
              productsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (e, _) => Center(
                  child: Text('Error al cargar productos: $e',
                      style: TextStyle(color: colors.error)),
                ),
                data: (products) {
                  if (products.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(48),
                        child: Column(
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 48,
                                color: colors.onSurface.withValues(alpha: 0.3)),
                            const SizedBox(height: 12),
                            Text(
                              'Sin productos',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Agrega tu primer producto para comenzar a vender.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
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
                    child: isMobile
                        ? Column(
                            children: [
                              for (final p in products)
                                _ProductMobileRow(
                                  product: p,
                                  mxnFormat: _mxnFormat,
                                  isDemo: isDemo,
                                  onEdit: () =>
                                      _showProductDialog(context, product: p),
                                  onDelete: () => _confirmDelete(context, p),
                                  onToggleStock: () => _toggleStock(p),
                                  onShowcase: () =>
                                      _showShowcaseDialog(context, p),
                                ),
                            ],
                          )
                        : _ProductsTable(
                            products: products,
                            mxnFormat: _mxnFormat,
                            isDemo: isDemo,
                            onEdit: (p) =>
                                _showProductDialog(context, product: p),
                            onDelete: (p) => _confirmDelete(context, p),
                            onToggleStock: _toggleStock,
                            onShowcase: (p) =>
                                _showShowcaseDialog(context, p),
                          ),
                  );
                },
              ),
              const SizedBox(height: 32),

              // ── Showcases Section ───────────────────────────────────────
              Text(
                'Publicaciones en Feed',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              showcasesAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (e, _) => Text('Error: $e',
                    style: TextStyle(color: colors.error)),
                data: (showcases) {
                  if (showcases.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.campaign_outlined,
                                size: 40,
                                color: colors.onSurface.withValues(alpha: 0.3)),
                            const SizedBox(height: 8),
                            Text(
                              'Sin publicaciones',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final s in showcases)
                        _ShowcaseCard(
                          showcase: s,
                          mxnFormat: _mxnFormat,
                          isDemo: isDemo,
                          onDelete: () => _deleteShowcase(s['id'] as String),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  void _showProductDialog(BuildContext context, {Product? product}) {
    showDialog(
      context: context,
      builder: (ctx) => _ProductFormDialog(
        bizId: widget.biz['id'] as String,
        product: product,
        onSaved: () => ref.invalidate(_businessProductsProvider),
      ),
    );
  }

  Future<void> _toggleStock(Product product) async {
    try {
      await BCSupabase.client
          .from(BCTables.products)
          .update({'in_stock': !product.inStock})
          .eq('id', product.id);
      ref.invalidate(_businessProductsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _confirmDelete(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('Eliminar "${product.name}"? Esta accion no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await BCSupabase.client
                    .from(BCTables.products)
                    .delete()
                    .eq('id', product.id);
                ref.invalidate(_businessProductsProvider);
                ref.invalidate(_businessShowcasesProvider);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showShowcaseDialog(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (ctx) => _ShowcaseFormDialog(
        bizId: widget.biz['id'] as String,
        product: product,
        onSaved: () => ref.invalidate(_businessShowcasesProvider),
      ),
    );
  }

  Future<void> _deleteShowcase(String id) async {
    try {
      await BCSupabase.client
          .from(BCTables.productShowcases)
          .delete()
          .eq('id', id);
      ref.invalidate(_businessShowcasesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// ── Stat Chip ────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Products DataTable (Desktop) ─────────────────────────────────────────────

class _ProductsTable extends StatelessWidget {
  const _ProductsTable({
    required this.products,
    required this.mxnFormat,
    required this.isDemo,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStock,
    required this.onShowcase,
  });

  final List<Product> products;
  final NumberFormat mxnFormat;
  final bool isDemo;
  final void Function(Product) onEdit;
  final void Function(Product) onDelete;
  final void Function(Product) onToggleStock;
  final void Function(Product) onShowcase;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      child: DataTable(
        headingRowColor:
            WidgetStateProperty.all(colors.surfaceContainerHighest.withValues(alpha: 0.3)),
        columns: const [
          DataColumn(label: Text('Foto')),
          DataColumn(label: Text('Nombre')),
          DataColumn(label: Text('Marca')),
          DataColumn(label: Text('Categoria')),
          DataColumn(label: Text('Precio'), numeric: true),
          DataColumn(label: Text('Stock')),
          DataColumn(label: Text('Acciones')),
        ],
        rows: [for (final p in products) _buildRow(context, p)],
      ),
    );
  }

  DataRow _buildRow(BuildContext context, Product p) {
    final categoryLabel =
        Product.categories[p.category] ?? p.category;

    return DataRow(cells: [
      DataCell(
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: p.photoUrl.isNotEmpty
              ? Image.network(
                  p.photoUrl,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 40,
                    height: 40,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image_not_supported_outlined,
                        size: 18, color: Colors.grey),
                  ),
                )
              : Container(
                  width: 40,
                  height: 40,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.image_outlined,
                      size: 18, color: Colors.grey),
                ),
        ),
      ),
      DataCell(Text(p.name, style: const TextStyle(fontWeight: FontWeight.w500))),
      DataCell(Text(p.brand ?? '--',
          style: TextStyle(color: Colors.grey.shade600))),
      DataCell(Text(categoryLabel)),
      DataCell(Text(mxnFormat.format(p.price),
          style: const TextStyle(fontWeight: FontWeight.w600))),
      DataCell(
        Switch(
          value: p.inStock,
          onChanged: isDemo ? null : (_) => onToggleStock(p),
        ),
      ),
      DataCell(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isDemo) ...[
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Editar',
                onPressed: () => onEdit(p),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 18,
                    color: Theme.of(context).colorScheme.error),
                tooltip: 'Eliminar',
                onPressed: () => onDelete(p),
              ),
              IconButton(
                icon: const Icon(Icons.campaign_outlined, size: 18),
                tooltip: 'Publicar en feed',
                onPressed: () => onShowcase(p),
              ),
            ],
          ],
        ),
      ),
    ]);
  }
}

// ── Product Mobile Row ───────────────────────────────────────────────────────

class _ProductMobileRow extends StatelessWidget {
  const _ProductMobileRow({
    required this.product,
    required this.mxnFormat,
    required this.isDemo,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStock,
    required this.onShowcase,
  });

  final Product product;
  final NumberFormat mxnFormat;
  final bool isDemo;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleStock;
  final VoidCallback onShowcase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: product.photoUrl.isNotEmpty
                ? Image.network(product.photoUrl,
                    width: 44, height: 44, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder())
                : _placeholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500)),
                Text(
                  '${Product.categories[product.category] ?? product.category}'
                  '${product.brand != null ? ' - ${product.brand}' : ''}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Text(mxnFormat.format(product.price),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          if (!isDemo) ...[
            const SizedBox(width: 8),
            Switch(
              value: product.inStock,
              onChanged: (_) => onToggleStock(),
            ),
            PopupMenuButton<String>(
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Editar')),
                const PopupMenuItem(value: 'showcase', child: Text('Publicar')),
                const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
              ],
              onSelected: (v) {
                switch (v) {
                  case 'edit':
                    onEdit();
                  case 'showcase':
                    onShowcase();
                  case 'delete':
                    onDelete();
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 44,
        height: 44,
        color: Colors.grey.shade200,
        child: const Icon(Icons.image_outlined, size: 18, color: Colors.grey),
      );
}

// ── Product Form Dialog ──────────────────────────────────────────────────────

class _ProductFormDialog extends StatefulWidget {
  const _ProductFormDialog({
    required this.bizId,
    this.product,
    required this.onSaved,
  });

  final String bizId;
  final Product? product;
  final VoidCallback onSaved;

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _photoCtrl;
  late final TextEditingController _descCtrl;
  late String _category;
  bool _saving = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _brandCtrl = TextEditingController(text: p?.brand ?? '');
    _priceCtrl = TextEditingController(
        text: p != null ? p.price.toStringAsFixed(0) : '');
    _photoCtrl = TextEditingController(text: p?.photoUrl ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _category = p?.category ?? Product.categories.keys.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _priceCtrl.dispose();
    _photoCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final data = {
      'business_id': widget.bizId,
      'name': _nameCtrl.text.trim(),
      'brand': _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
      'price': double.parse(_priceCtrl.text.trim()),
      'photo_url': _photoCtrl.text.trim(),
      'category': _category,
      'description':
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
    };

    try {
      if (_isEditing) {
        await BCSupabase.client
            .from(BCTables.products)
            .update(data)
            .eq('id', widget.product!.id);
      } else {
        await BCSupabase.client.from(BCTables.products).insert(data);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
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
    return AlertDialog(
      title: Text(_isEditing ? 'Editar Producto' : 'Nuevo Producto'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _brandCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Marca',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Categoria *',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final entry in Product.categories.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _category = v);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _priceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Precio (MXN) *',
                    border: OutlineInputBorder(),
                    prefixText: '\$ ',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Requerido';
                    final n = double.tryParse(v.trim());
                    if (n == null || n <= 0) return 'Precio invalido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _photoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL de foto *',
                    border: OutlineInputBorder(),
                    hintText: 'https://...',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descripcion',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEditing ? 'Guardar' : 'Agregar'),
        ),
      ],
    );
  }
}

// ── Showcase Form Dialog ─────────────────────────────────────────────────────

class _ShowcaseFormDialog extends StatefulWidget {
  const _ShowcaseFormDialog({
    required this.bizId,
    required this.product,
    required this.onSaved,
  });

  final String bizId;
  final Product product;
  final VoidCallback onSaved;

  @override
  State<_ShowcaseFormDialog> createState() => _ShowcaseFormDialogState();
}

class _ShowcaseFormDialogState extends State<_ShowcaseFormDialog> {
  final _captionCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    setState(() => _saving = true);
    try {
      await BCSupabase.client.from(BCTables.productShowcases).insert({
        'business_id': widget.bizId,
        'product_id': widget.product.id,
        'caption': _captionCtrl.text.trim().isEmpty
            ? null
            : _captionCtrl.text.trim(),
      });
      widget.onSaved();
      if (mounted) Navigator.pop(context);
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
    final mxn = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

    return AlertDialog(
      title: const Text('Publicar en Feed'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: widget.product.photoUrl.isNotEmpty
                        ? Image.network(widget.product.photoUrl,
                            width: 48, height: 48, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _imgPlaceholder())
                        : _imgPlaceholder(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.product.name,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        Text(mxn.format(widget.product.price),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _captionCtrl,
              decoration: const InputDecoration(
                labelText: 'Caption (opcional)',
                border: OutlineInputBorder(),
                hintText: 'Ej: Nuevo en tienda!',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _publish,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.campaign_outlined, size: 18),
          label: const Text('Publicar'),
        ),
      ],
    );
  }

  Widget _imgPlaceholder() => Container(
        width: 48,
        height: 48,
        color: Colors.grey.shade200,
        child: const Icon(Icons.image_outlined, size: 20, color: Colors.grey),
      );
}

// ── Showcase Card ────────────────────────────────────────────────────────────

class _ShowcaseCard extends StatelessWidget {
  const _ShowcaseCard({
    required this.showcase,
    required this.mxnFormat,
    required this.isDemo,
    required this.onDelete,
  });

  final Map<String, dynamic> showcase;
  final NumberFormat mxnFormat;
  final bool isDemo;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final product = showcase['products'] as Map<String, dynamic>?;
    final caption = showcase['caption'] as String?;
    final createdAt = DateTime.tryParse(showcase['created_at'] as String? ?? '');
    final dateStr = createdAt != null
        ? DateFormat('dd MMM yyyy, HH:mm', 'es').format(createdAt)
        : '--';

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Photo
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            child: (product?['photo_url'] as String?)?.isNotEmpty == true
                ? Image.network(
                    product!['photo_url'] as String,
                    width: 260,
                    height: 160,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 260,
                      height: 160,
                      color: Colors.grey.shade100,
                      child: const Icon(Icons.image_not_supported_outlined,
                          size: 32, color: Colors.grey),
                    ),
                  )
                : Container(
                    width: 260,
                    height: 160,
                    color: Colors.grey.shade100,
                    child: const Icon(Icons.image_outlined,
                        size: 32, color: Colors.grey),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product?['name'] as String? ?? 'Producto',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (product?['price'] != null)
                  Text(
                    mxnFormat.format((product!['price'] as num).toDouble()),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (caption != null && caption.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    caption,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.6),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 14,
                        color: colors.onSurface.withValues(alpha: 0.4)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        dateStr,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    if (!isDemo)
                      IconButton(
                        icon: Icon(Icons.delete_outline, size: 16,
                            color: colors.error),
                        tooltip: 'Eliminar publicacion',
                        onPressed: onDelete,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
