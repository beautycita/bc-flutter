import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:beautycita_core/theme.dart';
import 'package:beautycita_core/models.dart';

import '../../config/breakpoints.dart';
import '../../data/categories.dart';
import '../../providers/business_portal_provider.dart';
import '../../widgets/aphrodite_copy_field.dart';

/// Selected service for detail panel.
final selectedServiceProvider =
    StateProvider<Map<String, dynamic>?>((ref) => null);

/// Business services management page.
class BizServicesPage extends ConsumerWidget {
  const BizServicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bizAsync = ref.watch(currentBusinessProvider);
    return bizAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (biz) {
        if (biz == null) return const Center(child: Text('Sin negocio'));
        return _ServicesContent(bizId: biz['id'] as String);
      },
    );
  }
}

class _ServicesContent extends ConsumerWidget {
  const _ServicesContent({required this.bizId});
  final String bizId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(businessServicesProvider);
    final selected = ref.watch(selectedServiceProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = WebBreakpoints.isDesktop(constraints.maxWidth);
        final showPanel = selected != null && isDesktop;

        return Row(
          children: [
            Expanded(
              child: servicesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) =>
                    const Center(child: Text('Error al cargar servicios')),
                data: (services) => _ServicesList(
                  services: services,
                  bizId: bizId,
                  isDesktop: isDesktop,
                ),
              ),
            ),
            if (showPanel) ...[
              VerticalDivider(
                  width: 1,
                  color: Theme.of(context).colorScheme.outlineVariant),
              SizedBox(
                width: 420,
                child: _ServiceDetailPanel(service: selected, bizId: bizId),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ── Services List ───────────────────────────────────────────────────────────

class _ServicesList extends ConsumerWidget {
  const _ServicesList(
      {required this.services, required this.bizId, required this.isDesktop});
  final List<Map<String, dynamic>> services;
  final String bizId;
  final bool isDesktop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // Group by category
    final Map<String, List<Map<String, dynamic>>> byCategory = {};
    for (final s in services) {
      final cat = s['category'] as String? ?? 'Sin categoria';
      byCategory.putIfAbsent(cat, () => []).add(s);
    }

    // Match category IDs to display names
    String categoryLabel(String cat) {
      final match = allCategories
          .where((c) => c.id == cat || c.nameEs == cat)
          .firstOrNull;
      if (match != null) return '${match.icon}  ${match.nameEs}';
      return cat;
    }

    return Column(
      children: [
        // Header
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: colors.outlineVariant))),
          child: Row(
            children: [
              Text('Servicios',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Chip(
                  label: Text('${services.length}'),
                  visualDensity: VisualDensity.compact),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => _showBatchAddDialog(context, ref, bizId),
                icon: const Icon(Icons.playlist_add, size: 18),
                label: const Text('Agregar varios'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => ref
                    .read(selectedServiceProvider.notifier)
                    .state = {'_new': true, 'business_id': bizId},
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar'),
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: services.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.spa_outlined,
                          size: 48,
                          color: colors.onSurface.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text('Sin servicios registrados',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color:
                                  colors.onSurface.withValues(alpha: 0.5))),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () =>
                            _showBatchAddDialog(context, ref, bizId),
                        icon: const Icon(Icons.playlist_add, size: 18),
                        label: const Text('Agregar servicios por categoria'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    for (final category in byCategory.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, top: 8),
                        child: Text(
                          categoryLabel(category.key),
                          style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.primary),
                        ),
                      ),
                      if (isDesktop)
                        GridView.count(
                          crossAxisCount: 3,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 2.8,
                          children: [
                            for (final s in category.value)
                              _ServiceCard(service: s)
                          ],
                        )
                      else
                        Column(
                          children: [
                            for (final s in category.value)
                              Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _ServiceCard(service: s))
                          ],
                        ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

// ── Service Card ────────────────────────────────────────────────────────────

class _ServiceCard extends ConsumerStatefulWidget {
  const _ServiceCard({required this.service});
  final Map<String, dynamic> service;

  @override
  ConsumerState<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends ConsumerState<_ServiceCard> {
  bool _hovering = false;

  Future<void> _toggleActive() async {
    final id = widget.service['id'] as String?;
    if (id == null) return;
    final current = widget.service['is_active'] as bool? ?? true;
    try {
      await BCSupabase.client
          .from(BCTables.services)
          .update({'is_active': !current}).eq('id', id);
      ref.invalidate(businessServicesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final s = widget.service;
    final name = s['name'] as String? ?? '';
    final subcategory = s['subcategory'] as String? ?? '';
    final price = (s['price'] as num?)?.toDouble() ?? 0;
    final duration = (s['duration_minutes'] as num?)?.toInt() ?? 0;
    final buffer = (s['buffer_minutes'] as num?)?.toInt() ?? 0;
    final depositRequired = s['deposit_required'] as bool? ?? false;
    final depositPct =
        (s['deposit_percentage'] as num?)?.toDouble() ?? 0;
    final isActive = s['is_active'] as bool? ?? true;

    // Build subtitle parts
    final parts = <String>[];
    if (subcategory.isNotEmpty) {
      // Resolve subcategory display name
      String subLabel = subcategory;
      for (final cat in allCategories) {
        final match =
            cat.subcategories.where((sc) => sc.id == subcategory).firstOrNull;
        if (match != null) {
          subLabel = match.nameEs;
          break;
        }
      }
      parts.add(subLabel);
    }
    parts.add('${duration}min');
    if (buffer > 0) parts.add('+${buffer}min buffer');
    parts.add('\$${price.toStringAsFixed(0)}');
    if (depositRequired && depositPct > 0) {
      parts.add('${depositPct.toStringAsFixed(0)}% deposito');
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => ref.read(selectedServiceProvider.notifier).state = s,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: _hovering
                    ? colors.primary.withValues(alpha: 0.3)
                    : colors.outlineVariant),
            boxShadow: _hovering
                ? [
                    BoxShadow(
                        color: colors.primary.withValues(alpha: 0.06),
                        blurRadius: 8)
                  ]
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(name,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(parts.join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                colors.onSurface.withValues(alpha: 0.5)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _toggleActive(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                        : colors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? 'Activo' : 'Inactivo',
                    style: TextStyle(
                        fontSize: 11,
                        color: isActive
                            ? const Color(0xFF4CAF50)
                            : colors.error,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Service Detail Panel ────────────────────────────────────────────────────

class _ServiceDetailPanel extends ConsumerStatefulWidget {
  const _ServiceDetailPanel({required this.service, required this.bizId});
  final Map<String, dynamic> service;
  final String bizId;

  @override
  ConsumerState<_ServiceDetailPanel> createState() =>
      _ServiceDetailPanelState();
}

class _ServiceDetailPanelState extends ConsumerState<_ServiceDetailPanel> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _durationCtrl;
  late TextEditingController _bufferCtrl;
  late TextEditingController _depositPctCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _customCategoryCtrl;
  bool _isActive = true;
  bool _depositRequired = false;
  bool _saving = false;

  // Category picker state
  ServiceCategory? _selectedCategory;
  ServiceSubcategory? _selectedSubcategory;
  bool _isCustomCategory = false;

  bool get _isNew => widget.service['_new'] == true;

  @override
  void initState() {
    super.initState();
    _initFields();
  }

  @override
  void didUpdateWidget(covariant _ServiceDetailPanel old) {
    super.didUpdateWidget(old);
    if (old.service['id'] != widget.service['id'] ||
        old.service['_new'] != widget.service['_new']) {
      _initFields();
    }
  }

  void _initFields() {
    final s = widget.service;
    _nameCtrl = TextEditingController(text: s['name'] as String? ?? '');
    _priceCtrl = TextEditingController(
        text: ((s['price'] as num?)?.toStringAsFixed(0) ?? ''));
    _durationCtrl = TextEditingController(
        text: ((s['duration_minutes'] as num?)?.toString() ?? ''));
    _bufferCtrl = TextEditingController(
        text: ((s['buffer_minutes'] as num?)?.toString() ?? '0'));
    _depositPctCtrl = TextEditingController(
        text: ((s['deposit_percentage'] as num?)?.toString() ?? '0'));
    _descCtrl =
        TextEditingController(text: s['description'] as String? ?? '');
    _customCategoryCtrl = TextEditingController();
    _isActive = s['is_active'] as bool? ?? true;
    _depositRequired = s['deposit_required'] as bool? ?? false;

    // Resolve category/subcategory from stored values
    final storedCat = s['category'] as String? ?? '';
    final storedSub = s['subcategory'] as String? ?? '';

    _selectedCategory = null;
    _selectedSubcategory = null;
    _isCustomCategory = false;

    if (storedCat.isNotEmpty) {
      final match = allCategories
          .where((c) => c.id == storedCat || c.nameEs == storedCat)
          .firstOrNull;
      if (match != null) {
        _selectedCategory = match;
        if (storedSub.isNotEmpty) {
          _selectedSubcategory = match.subcategories
              .where((sc) => sc.id == storedSub || sc.nameEs == storedSub)
              .firstOrNull;
        }
      } else {
        // Custom category
        _isCustomCategory = true;
        _customCategoryCtrl.text = storedCat;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _durationCtrl.dispose();
    _bufferCtrl.dispose();
    _depositPctCtrl.dispose();
    _descCtrl.dispose();
    _customCategoryCtrl.dispose();
    super.dispose();
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar servicio'),
        content:
            Text('Seguro que desea eliminar "${widget.service['name']}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await BCSupabase.client
                    .from(BCTables.services)
                    .delete()
                    .eq('id', widget.service['id'] as String);
                ref.invalidate(businessServicesProvider);
                ref.read(selectedServiceProvider.notifier).state = null;
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final categoryValue = _isCustomCategory
        ? _customCategoryCtrl.text.trim()
        : (_selectedCategory?.id ?? '');
    final subcategoryValue = _selectedSubcategory?.id ?? '';

    final data = {
      'business_id': widget.bizId,
      'name': _nameCtrl.text.trim(),
      'category': categoryValue,
      'subcategory': subcategoryValue,
      'price': double.tryParse(_priceCtrl.text) ?? 0,
      'duration_minutes': int.tryParse(_durationCtrl.text) ?? 60,
      'buffer_minutes': int.tryParse(_bufferCtrl.text) ?? 0,
      'deposit_required': _depositRequired,
      'deposit_percentage':
          _depositRequired ? (double.tryParse(_depositPctCtrl.text) ?? 0) : 0,
      'description': _descCtrl.text.trim(),
      'is_active': _isActive,
    };

    try {
      if (_isNew) {
        await BCSupabase.client.from(BCTables.services).insert(data);
      } else {
        await BCSupabase.client
            .from(BCTables.services)
            .update(data)
            .eq('id', widget.service['id'] as String);
      }
      ref.invalidate(businessServicesProvider);
      if (mounted) ref.read(selectedServiceProvider.notifier).state = null;
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
    final colors = theme.colorScheme;

    return Container(
      color: colors.surface,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: colors.outlineVariant))),
            child: Row(
              children: [
                Expanded(
                    child: Text(
                        _isNew ? 'Nuevo servicio' : 'Editar servicio',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600))),
                IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => ref
                        .read(selectedServiceProvider.notifier)
                        .state = null),
              ],
            ),
          ),
          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Category Picker ──
                    _buildCategoryPicker(theme, colors),
                    const SizedBox(height: BCSpacing.md),

                    // ── Subcategory Chips ──
                    if (_selectedCategory != null) ...[
                      _buildSubcategoryChips(theme, colors),
                      const SizedBox(height: BCSpacing.md),
                    ],

                    // ── Custom Category ──
                    if (_isCustomCategory) ...[
                      TextFormField(
                        controller: _customCategoryCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de categoria personalizada',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: BCSpacing.sm),
                      _buildCustomCategorySuggestions(colors),
                      const SizedBox(height: BCSpacing.md),
                    ],

                    // ── Name ──
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del servicio',
                        prefixIcon: Icon(Icons.spa_outlined),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: BCSpacing.md),

                    // ── Price + Duration ──
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Precio', prefixText: '\$ '),
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Requerido' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _durationCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Duracion (min)'),
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Requerido' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: BCSpacing.md),

                    // ── Buffer ──
                    TextFormField(
                      controller: _bufferCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Buffer entre citas (min)',
                        helperText:
                            'Tiempo de preparacion entre citas',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: BCSpacing.md),

                    // ── Deposit Toggle ──
                    SwitchListTile(
                      title: const Text('Requiere deposito'),
                      subtitle: const Text(
                          'El cliente debe pagar un porcentaje al reservar'),
                      value: _depositRequired,
                      onChanged: (v) =>
                          setState(() => _depositRequired = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (_depositRequired) ...[
                      const SizedBox(height: BCSpacing.sm),
                      TextFormField(
                        controller: _depositPctCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Porcentaje de deposito',
                          suffixText: '%',
                          helperText: 'Ej: 30 = 30% del precio',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Requerido';
                          final n = double.tryParse(v);
                          if (n == null || n <= 0 || n > 100) {
                            return 'Ingrese un valor entre 1 y 100';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: BCSpacing.md),

                    // ── Description (Aphrodite) ──
                    AphroditeCopyField(
                      controller: _descCtrl,
                      label: 'Descripcion',
                      hint: 'Describe el servicio...',
                      icon: Icons.description_outlined,
                      fieldType: 'service_description',
                      context: {
                        'service_name': _nameCtrl.text,
                        'category': _selectedCategory?.nameEs ?? '',
                        'subcategory': _selectedSubcategory?.nameEs ?? '',
                      },
                      autoGenerate: false,
                    ),
                    const SizedBox(height: BCSpacing.md),

                    // ── Active Toggle ──
                    SwitchListTile(
                      title: const Text('Activo'),
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: BCSpacing.lg),

                    // ── Save ──
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_isNew ? 'Crear' : 'Guardar'),
                    ),
                    if (!_isNew) ...[
                      const SizedBox(height: BCSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _confirmDelete,
                          icon: Icon(Icons.delete_outline,
                              size: 18, color: colors.error),
                          label: Text('Eliminar servicio',
                              style: TextStyle(color: colors.error)),
                          style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                  color: colors.error.withValues(alpha: 0.3))),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Category Dropdown ─────────────────────────────────────────────────────

  Widget _buildCategoryPicker(ThemeData theme, ColorScheme colors) {
    // Build items: all categories + "Otro"
    final items = <DropdownMenuItem<String>>[];
    for (final cat in allCategories) {
      items.add(DropdownMenuItem(
        value: cat.id,
        child: Row(
          children: [
            Text(cat.icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(cat.nameEs),
          ],
        ),
      ));
    }
    items.add(const DropdownMenuItem(
      value: '_otro',
      child: Row(
        children: [
          Icon(Icons.add_circle_outline, size: 16),
          SizedBox(width: 8),
          Text('Otro'),
        ],
      ),
    ));

    String? currentValue;
    if (_isCustomCategory) {
      currentValue = '_otro';
    } else if (_selectedCategory != null) {
      currentValue = _selectedCategory!.id;
    }

    return DropdownButtonFormField<String>(
      value: currentValue,
      decoration: const InputDecoration(
        labelText: 'Categoria',
        prefixIcon: Icon(Icons.category_outlined),
      ),
      items: items,
      onChanged: (val) {
        setState(() {
          if (val == '_otro') {
            _isCustomCategory = true;
            _selectedCategory = null;
            _selectedSubcategory = null;
          } else if (val != null) {
            _isCustomCategory = false;
            _selectedCategory =
                allCategories.where((c) => c.id == val).firstOrNull;
            _selectedSubcategory = null;
          }
        });
      },
      validator: (v) {
        if (v == null && !_isCustomCategory) return 'Seleccione una categoria';
        return null;
      },
    );
  }

  // ── Subcategory Chips ─────────────────────────────────────────────────────

  Widget _buildSubcategoryChips(ThemeData theme, ColorScheme colors) {
    final subs = _selectedCategory!.subcategories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Subcategoria',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: colors.onSurface.withValues(alpha: 0.6))),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final sub in subs)
              ChoiceChip(
                label: Text(sub.nameEs),
                selected: _selectedSubcategory?.id == sub.id,
                onSelected: (sel) {
                  setState(() {
                    _selectedSubcategory = sel ? sub : null;
                    // If subcategory has no items, keep name field editable
                    // If it has items, auto-fill name from the first item or leave blank
                  });
                },
              ),
          ],
        ),
      ],
    );
  }

  // ── Custom Category Suggestions ───────────────────────────────────────────

  Widget _buildCustomCategorySuggestions(ColorScheme colors) {
    const suggestions = [
      'Depilacion Laser',
      'Microblading',
      'Tatuaje',
      'Medicina Estetica',
      'Quiropractica',
      'Nutricion',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in suggestions)
          ActionChip(
            label: Text(s, style: const TextStyle(fontSize: 12)),
            onPressed: () {
              _customCategoryCtrl.text = s;
              setState(() {});
            },
            backgroundColor: colors.primaryContainer.withValues(alpha: 0.3),
          ),
      ],
    );
  }
}

// ── Batch Add Dialog ──────────────────────────────────────────────────────

void _showBatchAddDialog(
    BuildContext context, WidgetRef ref, String bizId) {
  showDialog(
    context: context,
    builder: (ctx) => _BatchAddDialog(bizId: bizId),
  );
}

class _BatchAddDialog extends ConsumerStatefulWidget {
  const _BatchAddDialog({required this.bizId});
  final String bizId;

  @override
  ConsumerState<_BatchAddDialog> createState() => _BatchAddDialogState();
}

class _BatchAddDialogState extends ConsumerState<_BatchAddDialog> {
  ServiceCategory? _category;
  ServiceSubcategory? _subcategory;
  final Set<String> _selectedItemIds = {};
  bool _saving = false;

  // Default values for batch
  final _priceCtrl = TextEditingController(text: '300');
  final _durationCtrl = TextEditingController(text: '60');

  @override
  void dispose() {
    _priceCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _batchSave() async {
    if (_selectedItemIds.isEmpty) return;
    setState(() => _saving = true);

    // Gather selected items with their info
    final items = <Map<String, dynamic>>[];
    if (_subcategory != null && _subcategory!.items != null) {
      for (final item in _subcategory!.items!) {
        if (_selectedItemIds.contains(item.id)) {
          items.add({
            'business_id': widget.bizId,
            'name': item.nameEs,
            'category': _category!.id,
            'subcategory': _subcategory!.id,
            'service_type': item.serviceType,
            'price': double.tryParse(_priceCtrl.text) ?? 300,
            'duration_minutes': int.tryParse(_durationCtrl.text) ?? 60,
            'buffer_minutes': 0,
            'deposit_required': false,
            'deposit_percentage': 0,
            'is_active': true,
          });
        }
      }
    } else if (_subcategory != null) {
      // Subcategory without items — create one service with subcategory name
      items.add({
        'business_id': widget.bizId,
        'name': _subcategory!.nameEs,
        'category': _category!.id,
        'subcategory': _subcategory!.id,
        'price': double.tryParse(_priceCtrl.text) ?? 300,
        'duration_minutes': int.tryParse(_durationCtrl.text) ?? 60,
        'buffer_minutes': 0,
        'deposit_required': false,
        'deposit_percentage': 0,
        'is_active': true,
      });
    }

    if (items.isEmpty) {
      setState(() => _saving = false);
      return;
    }

    try {
      await BCSupabase.client.from(BCTables.services).insert(items);
      ref.invalidate(businessServicesProvider);
      if (mounted) Navigator.of(context).pop();
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
    final colors = theme.colorScheme;

    return AlertDialog(
      title: const Text('Agregar servicios por categoria'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Step 1: Category
              Text('1. Selecciona categoria',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final cat in allCategories)
                    ChoiceChip(
                      avatar: Text(cat.icon, style: const TextStyle(fontSize: 14)),
                      label: Text(cat.nameEs),
                      selected: _category?.id == cat.id,
                      onSelected: (sel) {
                        setState(() {
                          _category = sel ? cat : null;
                          _subcategory = null;
                          _selectedItemIds.clear();
                        });
                      },
                    ),
                ],
              ),

              if (_category != null) ...[
                const SizedBox(height: 16),
                Text('2. Selecciona subcategoria',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final sub in _category!.subcategories)
                      ChoiceChip(
                        label: Text(sub.nameEs),
                        selected: _subcategory?.id == sub.id,
                        onSelected: (sel) {
                          setState(() {
                            _subcategory = sel ? sub : null;
                            _selectedItemIds.clear();
                            // Auto-select all items if subcategory has items
                            if (sel && sub.items != null) {
                              for (final item in sub.items!) {
                                _selectedItemIds.add(item.id);
                              }
                            }
                          });
                        },
                      ),
                  ],
                ),
              ],

              if (_subcategory != null &&
                  _subcategory!.items != null &&
                  _subcategory!.items!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('3. Selecciona servicios',
                        style: theme.textTheme.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedItemIds.length ==
                              _subcategory!.items!.length) {
                            _selectedItemIds.clear();
                          } else {
                            for (final item in _subcategory!.items!) {
                              _selectedItemIds.add(item.id);
                            }
                          }
                        });
                      },
                      child: Text(_selectedItemIds.length ==
                              _subcategory!.items!.length
                          ? 'Deseleccionar todo'
                          : 'Seleccionar todo'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in _subcategory!.items!)
                      FilterChip(
                        label: Text(item.nameEs),
                        selected: _selectedItemIds.contains(item.id),
                        onSelected: (sel) {
                          setState(() {
                            if (sel) {
                              _selectedItemIds.add(item.id);
                            } else {
                              _selectedItemIds.remove(item.id);
                            }
                          });
                        },
                      ),
                  ],
                ),
              ],

              if (_subcategory != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text('Valores por defecto',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _priceCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Precio', prefixText: '\$ '),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _durationCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Duracion (min)'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Puedes editar el precio y duracion de cada servicio despues',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.5)),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _saving ||
                  (_subcategory == null ||
                      (_subcategory!.items != null &&
                          _selectedItemIds.isEmpty))
              ? null
              : _batchSave,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_selectedItemIds.isEmpty && _subcategory?.items == null
                  ? 'Agregar 1'
                  : 'Agregar ${_selectedItemIds.isEmpty ? 1 : _selectedItemIds.length}'),
        ),
      ],
    );
  }
}
