import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:beautycita_core/models.dart';
import '../../config/constants.dart';
import '../../data/categories.dart';
import '../../providers/business_provider.dart';
import '../../services/supabase_client.dart';
import '../../widgets/aphrodite_copy_field.dart';

class BusinessServicesScreen extends ConsumerWidget {
  const BusinessServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(businessServicesProvider);
    final colors = Theme.of(context).colorScheme;

    return servicesAsync.when(
      data: (services) {
        // Group by category
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final s in services) {
          final cat = s['category'] as String? ?? 'General';
          grouped.putIfAbsent(cat, () => []).add(s);
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showServiceForm(context, ref, null),
            child: const Icon(Icons.add_rounded),
          ),
          body: services.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.design_services_outlined,
                          size: 48,
                          color: colors.onSurface.withValues(alpha: 0.3)),
                      const SizedBox(height: AppConstants.paddingSM),
                      Text(
                        'No hay servicios registrados',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: colors.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Toca + para agregar tu primer servicio',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: colors.onSurface.withValues(alpha: 0.35),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(businessServicesProvider);
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(AppConstants.paddingMD),
                    children: [
                      for (final entry in grouped.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(
                              top: AppConstants.paddingMD,
                              bottom: AppConstants.paddingSM),
                          child: Text(
                            entry.key.toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color:
                                  colors.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                        for (final service in entry.value)
                          _ServiceCard(
                            service: service,
                            onEdit: () =>
                                _showServiceForm(context, ref, service),
                            onToggle: () =>
                                _toggleActive(context, ref, service),
                            onDelete: () =>
                                _deleteService(context, ref, service),
                          ),
                      ],
                      const SizedBox(height: 80), // FAB clearance
                    ],
                  ),
                ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: GoogleFonts.nunito(color: colors.error)),
      ),
    );
  }

  Future<void> _toggleActive(
      BuildContext context, WidgetRef ref, Map<String, dynamic> service) async {
    final id = service['id'] as String;
    final current = service['is_active'] as bool? ?? true;
    try {
      await SupabaseClientService.client
          .from('services')
          .update({'is_active': !current}).eq('id', id);
      ref.invalidate(businessServicesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteService(
      BuildContext context, WidgetRef ref, Map<String, dynamic> service) async {
    final id = service['id'] as String;
    final name = service['name'] as String? ?? 'Servicio';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar servicio'),
        content: Text('Seguro que quieres eliminar "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Eliminar',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await SupabaseClientService.client
          .from('services')
          .delete()
          .eq('id', id);
      ref.invalidate(businessServicesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Servicio eliminado')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showServiceForm(
      BuildContext context, WidgetRef ref, Map<String, dynamic>? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ServiceFormSheet(
        existing: existing,
        onSaved: () => ref.invalidate(businessServicesProvider),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final Map<String, dynamic> service;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _ServiceCard({
    required this.service,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = service['name'] as String? ?? 'Servicio';
    final price = (service['price'] as num?)?.toDouble() ?? 0;
    final duration = service['duration_minutes'] as int? ?? 0;
    final buffer = service['buffer_minutes'] as int? ?? 0;
    final isActive = service['is_active'] as bool? ?? true;
    final depositReq = service['deposit_required'] as bool? ?? false;
    final depositPct = (service['deposit_percentage'] as num?)?.toInt() ?? 0;

    final subcategory = service['subcategory'] as String?;

    final subtitleParts = <String>[];
    if (subcategory != null && subcategory.isNotEmpty) {
      subtitleParts.add(subcategory);
    }
    subtitleParts.add('${duration}min');
    if (buffer > 0) subtitleParts.add('+${buffer}min buffer');
    subtitleParts.add('\$${price.toStringAsFixed(0)} MXN');
    if (depositReq) subtitleParts.add('Dep: $depositPct%');

    return Card(
      elevation: 0,
      color: colors.surface,
      margin: const EdgeInsets.only(bottom: AppConstants.paddingSM),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        side: BorderSide(
          color: colors.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: ListTile(
        onTap: onEdit,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isActive
                ? colors.primary.withValues(alpha: 0.1)
                : colors.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppConstants.radiusSM),
          ),
          child: Icon(
            Icons.design_services_rounded,
            color: isActive
                ? colors.primary
                : colors.onSurface.withValues(alpha: 0.3),
            size: 22,
          ),
        ),
        title: Text(
          name,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isActive
                ? colors.onSurface
                : colors.onSurface.withValues(alpha: 0.4),
          ),
        ),
        subtitle: Text(
          subtitleParts.join(' • '),
          style: GoogleFonts.nunito(
            fontSize: 12,
            color: colors.onSurface.withValues(alpha: 0.5),
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'toggle':
                onToggle();
              case 'delete':
                onDelete();
            }
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'toggle',
              child: Text(isActive ? 'Desactivar' : 'Activar'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Eliminar', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceFormSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;

  const _ServiceFormSheet({
    this.existing,
    required this.onSaved,
  });

  @override
  ConsumerState<_ServiceFormSheet> createState() => _ServiceFormSheetState();
}

class _ServiceFormSheetState extends ConsumerState<_ServiceFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _bufferCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _depositPctCtrl;
  late final TextEditingController _otherCategoryCtrl;

  ServiceCategory? _selectedCategory;
  ServiceSubcategory? _selectedSubcategory;
  ServiceItem? _selectedItem;
  bool _isOtro = false;
  late bool _depositRequired;
  bool _saving = false;

  static const _otherSuggestions = [
    'Depilación Láser',
    'Tratamiento Capilar',
    'Masaje Linfático',
    'Microblading',
    'Limpieza Facial',
    'Uñas Acrílicas',
    'Extensiones de Cabello',
    'Blanqueamiento',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.existing?['name'] as String? ?? '');
    _priceCtrl = TextEditingController(
        text: (widget.existing?['price'] as num?)?.toString() ?? '');
    _durationCtrl = TextEditingController(
        text: (widget.existing?['duration_minutes'] as int?)?.toString() ?? '');
    _bufferCtrl = TextEditingController(
        text: (widget.existing?['buffer_minutes'] as int?)?.toString() ?? '0');
    _descCtrl = TextEditingController(
        text: widget.existing?['description'] as String? ?? '');
    _depositPctCtrl = TextEditingController(
        text:
            (widget.existing?['deposit_percentage'] as num?)?.toString() ?? '0');
    _otherCategoryCtrl = TextEditingController();
    _depositRequired = widget.existing?['deposit_required'] as bool? ?? false;

    // Restore category/subcategory/item from existing service
    if (widget.existing != null) {
      final rawCat = widget.existing!['category'] as String? ?? '';
      final rawSub = widget.existing!['subcategory'] as String?;
      final rawType = widget.existing!['service_type'] as String?;

      if (rawCat == 'Servicios Especiales' || rawCat == 'Otro') {
        _isOtro = true;
        _otherCategoryCtrl.text = rawSub ?? rawCat;
      } else {
        // Match by nameEs
        for (final cat in allCategories) {
          if (cat.nameEs == rawCat || cat.id == rawCat) {
            _selectedCategory = cat;
            if (rawSub != null) {
              for (final sub in cat.subcategories) {
                if (sub.nameEs == rawSub || sub.id == rawSub) {
                  _selectedSubcategory = sub;
                  if (rawType != null && sub.items != null) {
                    for (final item in sub.items!) {
                      if (item.serviceType == rawType || item.id == rawType) {
                        _selectedItem = item;
                        break;
                      }
                    }
                  }
                  break;
                }
              }
            }
            break;
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _durationCtrl.dispose();
    _bufferCtrl.dispose();
    _descCtrl.dispose();
    _depositPctCtrl.dispose();
    _otherCategoryCtrl.dispose();
    super.dispose();
  }

  InputDecoration _styledInput(
    String label, {
    String? prefixText,
    String? suffixText,
    String? helperText,
  }) {
    final colors = Theme.of(context).colorScheme;
    final gray = colors.onSurface.withValues(alpha: 0.12);
    return InputDecoration(
      labelText: label,
      prefixText: prefixText,
      suffixText: suffixText,
      helperText: helperText,
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        borderSide: BorderSide(color: gray, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        borderSide: BorderSide(color: gray.withValues(alpha: 0.06), width: 1),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEdit = widget.existing != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppConstants.paddingLG,
        AppConstants.paddingLG,
        AppConstants.paddingLG,
        MediaQuery.of(context).viewInsets.bottom + AppConstants.paddingLG,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppConstants.paddingMD),
                decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              isEdit ? 'Editar Servicio' : 'Nuevo Servicio',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: AppConstants.paddingMD),
            TextField(
              controller: _nameCtrl,
              decoration: _styledInput('Nombre'),
            ),
            const SizedBox(height: AppConstants.paddingSM),
            // ── Category dropdown ───────────────────────────────────
            DropdownButtonFormField<String>(
              value: _isOtro
                  ? '__otro__'
                  : _selectedCategory?.id,
              decoration: _styledInput('Categoria *'),
              items: [
                for (final cat in allCategories)
                  DropdownMenuItem(
                    value: cat.id,
                    child: Text('${cat.icon} ${cat.nameEs}'),
                  ),
                const DropdownMenuItem(
                  value: '__otro__',
                  child: Text('Otro'),
                ),
              ],
              onChanged: (v) {
                setState(() {
                  _selectedSubcategory = null;
                  _selectedItem = null;
                  if (v == '__otro__') {
                    _isOtro = true;
                    _selectedCategory = null;
                  } else {
                    _isOtro = false;
                    _otherCategoryCtrl.clear();
                    _selectedCategory = allCategories
                        .where((c) => c.id == v)
                        .firstOrNull;
                  }
                });
              },
            ),
            const SizedBox(height: AppConstants.paddingSM),

            // ── "Otro" custom category name + suggestion chips ────
            if (_isOtro) ...[
              TextField(
                controller: _otherCategoryCtrl,
                decoration: _styledInput('Nombre de la categoria *'),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final s in _otherSuggestions)
                    ActionChip(
                      label: Text(s, style: const TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        setState(() => _otherCategoryCtrl.text = s);
                      },
                    ),
                ],
              ),
              const SizedBox(height: AppConstants.paddingSM),
            ],

            // ── Subcategory chips (required) ──────────────────────
            if (_selectedCategory != null) ...[
              Text('Subcategoria *',
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final sub in _selectedCategory!.subcategories)
                    ChoiceChip(
                      label: Text(sub.nameEs),
                      selected: _selectedSubcategory?.id == sub.id,
                      onSelected: (_) {
                        setState(() {
                          _selectedSubcategory = sub;
                          _selectedItem = null;
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: AppConstants.paddingSM),
            ],

            // ── Service item chips (required when items exist) ────
            if (_selectedSubcategory?.items != null &&
                _selectedSubcategory!.items!.isNotEmpty) ...[
              Text('Tipo de servicio *',
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final item in _selectedSubcategory!.items!)
                    ChoiceChip(
                      label: Text(item.nameEs),
                      selected: _selectedItem?.id == item.id,
                      onSelected: (_) {
                        setState(() => _selectedItem = item);
                      },
                    ),
                ],
              ),
              const SizedBox(height: AppConstants.paddingSM),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _styledInput('Precio (MXN)',
                        prefixText: '\$ '),
                  ),
                ),
                const SizedBox(width: AppConstants.paddingSM),
                Expanded(
                  child: TextField(
                    controller: _durationCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _styledInput('Duracion (min)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingSM),
            Focus(
              onFocusChange: (hasFocus) {
                if (hasFocus && _bufferCtrl.text == '0') {
                  _bufferCtrl.clear();
                } else if (!hasFocus && _bufferCtrl.text.trim().isEmpty) {
                  _bufferCtrl.text = '0';
                }
              },
              child: TextField(
                controller: _bufferCtrl,
                keyboardType: TextInputType.number,
                decoration: _styledInput('Descanso entre citas (min)'),
              ),
            ),
            const SizedBox(height: AppConstants.paddingSM),
            AphroditeCopyField(
              controller: _descCtrl,
              label: 'Descripcion (opcional)',
              hint: 'Describe este servicio para tus clientes...',
              icon: Icons.description_outlined,
              fieldType: 'service_description',
              maxLines: 2,
              autoGenerate: widget.existing == null,
              context: {
                'service_name': _nameCtrl.text.trim(),
                'category': _isOtro
                    ? _otherCategoryCtrl.text.trim()
                    : (_selectedCategory?.nameEs ?? ''),
                'subcategory': _selectedSubcategory?.nameEs ?? '',
                'price': _priceCtrl.text.trim(),
                'duration': '${_durationCtrl.text.trim()} min',
              },
            ),
            const SizedBox(height: AppConstants.paddingMD),

            // Deposit section
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                border: Border.all(
                  color: colors.onSurface.withValues(alpha: 0.08),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text('Requiere deposito',
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    subtitle: Text(
                        'Cobrar deposito al reservar este servicio',
                        style: GoogleFonts.nunito(fontSize: 12)),
                    value: _depositRequired,
                    onChanged: (v) =>
                        setState(() => _depositRequired = v),
                    activeTrackColor: colors.primary,
                  ),
                  if (_depositRequired) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: TextField(
                        controller: _depositPctCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _styledInput('Porcentaje de deposito',
                            suffixText: '%'),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppConstants.paddingLG),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEdit ? 'Guardar' : 'Agregar'),
            ),
            const SizedBox(height: AppConstants.paddingSM),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim());
    final duration = int.tryParse(_durationCtrl.text.trim());

    if (name.isEmpty || price == null || duration == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos requeridos')),
      );
      return;
    }

    // Validate category selection
    if (!_isOtro && _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una categoria')),
      );
      return;
    }
    if (_isOtro && _otherCategoryCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe el nombre de la categoria')),
      );
      return;
    }
    if (!_isOtro && _selectedSubcategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una subcategoria')),
      );
      return;
    }
    if (!_isOtro &&
        _selectedSubcategory?.items != null &&
        _selectedSubcategory!.items!.isNotEmpty &&
        _selectedItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona el tipo de servicio')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final biz = await ref.read(currentBusinessProvider.future);
      if (biz == null) throw Exception('No business found');

      final String savedCategory;
      final String? savedSubcategory;
      final String? savedServiceType;

      if (_isOtro) {
        savedCategory = 'Servicios Especiales';
        savedSubcategory = _otherCategoryCtrl.text.trim();
        savedServiceType = null;
      } else {
        savedCategory = _selectedCategory!.nameEs;
        savedSubcategory = _selectedSubcategory!.nameEs;
        savedServiceType = _selectedItem?.serviceType;
      }

      final data = {
        'business_id': biz['id'],
        'name': name,
        'category': savedCategory,
        'subcategory': savedSubcategory,
        'service_type': savedServiceType,
        'price': price,
        'duration_minutes': duration,
        'buffer_minutes': int.tryParse(_bufferCtrl.text.trim()) ?? 0,
        'description': _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        'deposit_required': _depositRequired,
        'deposit_percentage': _depositRequired
            ? (int.tryParse(_depositPctCtrl.text.trim()) ?? 0)
            : 0,
        'is_active': true,
      };

      if (widget.existing != null) {
        await SupabaseClientService.client
            .from('services')
            .update(data)
            .eq('id', widget.existing!['id'] as String);
      } else {
        await SupabaseClientService.client.from('services').insert(data);
      }

      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
