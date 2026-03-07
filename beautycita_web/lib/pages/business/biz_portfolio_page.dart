import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../config/breakpoints.dart';
import '../../providers/business_portal_provider.dart';
import '../../providers/demo_providers.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

/// Portfolio settings for the current business.
final _portfolioSettingsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final biz = await ref.watch(currentBusinessProvider.future);
  if (biz == null) return null;
  final bizId = biz['id'] as String;

  final response = await BCSupabase.client
      .from('portfolio_settings')
      .select()
      .eq('business_id', bizId)
      .maybeSingle();

  return response;
});

/// Portfolio photos for the current business.
final _portfolioPhotosProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final biz = await ref.watch(currentBusinessProvider.future);
  if (biz == null) return [];
  final bizId = biz['id'] as String;

  final response = await BCSupabase.client
      .from('portfolio_photos')
      .select('*, staff(first_name, last_name, avatar_url)')
      .eq('business_id', bizId)
      .order('sort_order')
      .order('created_at', ascending: false);

  return List<Map<String, dynamic>>.from(response as List);
});

/// Currently selected photo (for detail panel).
final _selectedPhotoProvider = StateProvider<Map<String, dynamic>?>((ref) => null);

/// Staff filter for photo grid (null = all).
final _photoStaffFilterProvider = StateProvider<String?>((ref) => null);

/// Grid vs list view toggle.
final _photoViewGridProvider = StateProvider<bool>((ref) => true);

// ── Main Page ─────────────────────────────────────────────────────────────────

/// Portfolio management page — desktop-first, two-column layout.
///
/// Left column (400px): portfolio settings + per-staff bios.
/// Right column (flex): photo management grid + stats.
class BizPortfolioPage extends ConsumerWidget {
  const BizPortfolioPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bizAsync = ref.watch(currentBusinessProvider);

    return bizAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (biz) {
        if (biz == null) return const Center(child: Text('Sin negocio'));
        return _PortfolioContent(biz: biz);
      },
    );
  }
}

class _PortfolioContent extends ConsumerWidget {
  const _PortfolioContent({required this.biz});
  final Map<String, dynamic> biz;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = WebBreakpoints.isDesktop(constraints.maxWidth);

        if (isDesktop) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column — fixed 400px
              SizedBox(
                width: 400,
                child: _LeftColumn(biz: biz),
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              // Right column — flex
              Expanded(
                child: _RightColumn(biz: biz),
              ),
            ],
          );
        }

        // Mobile / tablet: stack vertically
        return SingleChildScrollView(
          child: Column(
            children: [
              _LeftColumn(biz: biz),
              Divider(
                height: 1,
                thickness: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              SizedBox(
                height: 800,
                child: _RightColumn(biz: biz),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Left Column ───────────────────────────────────────────────────────────────

class _LeftColumn extends ConsumerWidget {
  const _LeftColumn({required this.biz});
  final Map<String, dynamic> biz;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // Section header
        _SectionHeader(
          icon: Icons.web_outlined,
          title: 'Portafolio',
          subtitle: 'Configura tu presencia publica',
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _PortfolioSettingsPanel(biz: biz),
              const SizedBox(height: 20),
              _TeamBiosPanel(biz: biz),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Portfolio Settings Panel ──────────────────────────────────────────────────

class _PortfolioSettingsPanel extends ConsumerStatefulWidget {
  const _PortfolioSettingsPanel({required this.biz});
  final Map<String, dynamic> biz;

  @override
  ConsumerState<_PortfolioSettingsPanel> createState() =>
      _PortfolioSettingsPanelState();
}

class _PortfolioSettingsPanelState
    extends ConsumerState<_PortfolioSettingsPanel> {
  final _slugController = TextEditingController();
  final _bioController = TextEditingController();
  final _taglineController = TextEditingController();

  bool _isPublic = true;
  String _theme = 'classic';
  bool _saving = false;
  bool _initialized = false;

  static const _themes = [
    ('classic', 'Clasico'),
    ('modern', 'Moderno'),
    ('minimal', 'Minimal'),
    ('bold', 'Audaz'),
  ];

  @override
  void dispose() {
    _slugController.dispose();
    _bioController.dispose();
    _taglineController.dispose();
    super.dispose();
  }

  void _initFromData(Map<String, dynamic>? data) {
    if (_initialized) return;
    _initialized = true;
    _isPublic = (data?['is_public'] as bool?) ?? true;
    _theme = (data?['theme'] as String?) ?? 'classic';
    _slugController.text = (data?['slug'] as String?) ??
        (widget.biz['name'] as String? ?? '')
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
            .replaceAll(RegExp(r'-+$'), '');
    _bioController.text = (data?['bio'] as String?) ?? '';
    _taglineController.text = (data?['tagline'] as String?) ?? '';
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final bizId = widget.biz['id'] as String;
      final payload = {
        'business_id': bizId,
        'is_public': _isPublic,
        'theme': _theme,
        'slug': _slugController.text.trim(),
        'bio': _bioController.text.trim(),
        'tagline': _taglineController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await BCSupabase.client
          .from('portfolio_settings')
          .upsert(payload, onConflict: 'business_id');

      ref.invalidate(_portfolioSettingsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuracion guardada')),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final settingsAsync = ref.watch(_portfolioSettingsProvider);
    final isDemo = ref.watch(isDemoProvider);

    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        _initFromData(data);

        return _Panel(
          title: 'Configuracion del portafolio',
          icon: Icons.tune_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Public/Private toggle
              Row(
                children: [
                  Icon(
                    _isPublic ? Icons.public : Icons.lock_outline,
                    size: 20,
                    color: _isPublic ? colors.primary : colors.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Visibilidad publica',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _isPublic
                              ? 'Tu portafolio es visible para clientes'
                              : 'Portafolio oculto al publico',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isPublic,
                    onChanged: isDemo ? null : (v) => setState(() => _isPublic = v),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Theme selector
              Text(
                'Tema visual',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (key, label) in _themes)
                    _ThemeChip(
                      label: label,
                      selected: _theme == key,
                      onTap: isDemo ? null : () => setState(() => _theme = key),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Slug editor
              Text(
                'URL de tu portafolio',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _slugController,
                enabled: !isDemo,
                decoration: InputDecoration(
                  hintText: 'mi-salon',
                  prefixText: 'beautycita.com/p/',
                  prefixStyle: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.45),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
                style: theme.textTheme.bodyMedium,
                onChanged: (v) {
                  // Sanitize slug on input
                  final clean = v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]'), '-');
                  if (clean != v) {
                    _slugController.text = clean;
                    _slugController.selection = TextSelection.fromPosition(
                      TextPosition(offset: clean.length),
                    );
                  }
                },
              ),
              const SizedBox(height: 4),
              Text(
                'Solo letras minusculas, numeros y guiones',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(height: 20),

              // Tagline
              Text(
                'Eslogan',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _taglineController,
                enabled: !isDemo,
                maxLength: 80,
                decoration: InputDecoration(
                  hintText: 'Tu transformacion, nuestra pasion',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                  counterText: '',
                ),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),

              // Bio
              Text(
                'Descripcion del salon',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _bioController,
                enabled: !isDemo,
                maxLines: 5,
                maxLength: 600,
                decoration: InputDecoration(
                  hintText: 'Cuéntale a tus clientes sobre tu salon, especialidades y filosofia de trabajo...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
                  alignLabelWithHint: true,
                ),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),

              // Save button
              if (!isDemo)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Guardar configuracion'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Team Bios Panel ───────────────────────────────────────────────────────────

class _TeamBiosPanel extends ConsumerWidget {
  const _TeamBiosPanel({required this.biz});
  final Map<String, dynamic> biz;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(businessStaffProvider);
    final isDemo = ref.watch(isDemoProvider);

    return _Panel(
      title: 'Bios del equipo',
      icon: Icons.people_outlined,
      child: staffAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Text('Error al cargar staff'),
        data: (staff) {
          if (staff.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Agrega staff para configurar sus bios',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ),
            );
          }
          return Column(
            children: [
              for (final member in staff) ...[
                _StaffBioCard(staff: member, isDemo: isDemo),
                if (member != staff.last) const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _StaffBioCard extends ConsumerStatefulWidget {
  const _StaffBioCard({required this.staff, required this.isDemo});
  final Map<String, dynamic> staff;
  final bool isDemo;

  @override
  ConsumerState<_StaffBioCard> createState() => _StaffBioCardState();
}

class _StaffBioCardState extends ConsumerState<_StaffBioCard> {
  late final TextEditingController _bioCtrl;
  late final TextEditingController _specialtiesCtrl;
  bool _saving = false;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _bioCtrl = TextEditingController(
      text: widget.staff['bio'] as String? ?? '',
    );
    final specialties = widget.staff['specialties'];
    _specialtiesCtrl = TextEditingController(
      text: specialties is List
          ? specialties.join(', ')
          : (specialties as String? ?? ''),
    );
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    _specialtiesCtrl.dispose();
    super.dispose();
  }

  String get _displayName {
    final first = widget.staff['first_name'] as String? ?? '';
    final last = widget.staff['last_name'] as String? ?? '';
    return '$first $last'.trim();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final specialties = _specialtiesCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      await BCSupabase.client.from(BCTables.staff).update({
        'bio': _bioCtrl.text.trim(),
        'specialties': specialties,
      }).eq('id', widget.staff['id'] as String);

      ref.invalidate(businessStaffProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bio de $_displayName guardada')),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final avatarUrl = widget.staff['avatar_url'] as String?;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          // Header row — always visible
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    backgroundColor: colors.primary.withValues(alpha: 0.12),
                    child: avatarUrl == null
                        ? Text(
                            _displayName.isNotEmpty
                                ? _displayName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: colors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _displayName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: colors.onSurface.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),

          // Expanded bio editor
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  Text(
                    'Bio',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _bioCtrl,
                    enabled: !widget.isDemo,
                    maxLines: 4,
                    maxLength: 400,
                    decoration: InputDecoration(
                      hintText: 'Describe la experiencia y pasion de este estilista...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(10),
                      isDense: true,
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),

                  Text(
                    'Especialidades (separadas por coma)',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _specialtiesCtrl,
                    enabled: !widget.isDemo,
                    decoration: InputDecoration(
                      hintText: 'Corte, Color, Peinados de boda',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      isDense: true,
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),

                  // Specialty tags preview
                  if (_specialtiesCtrl.text.trim().isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _specialtiesCtrl.text
                          .split(',')
                          .map((s) => s.trim())
                          .where((s) => s.isNotEmpty)
                          .map(
                            (tag) => Chip(
                              label: Text(tag),
                              visualDensity: VisualDensity.compact,
                              labelStyle: theme.textTheme.labelSmall,
                              backgroundColor: colors.primary.withValues(alpha: 0.08),
                              side: BorderSide(color: colors.primary.withValues(alpha: 0.2)),
                              padding: EdgeInsets.zero,
                            ),
                          )
                          .toList(),
                    ),

                  if (!widget.isDemo) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Guardar bio'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Right Column ──────────────────────────────────────────────────────────────

class _RightColumn extends ConsumerWidget {
  const _RightColumn({required this.biz});
  final Map<String, dynamic> biz;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // Toolbar
        _PhotoToolbar(biz: biz),
        // Photo grid / list
        Expanded(child: _PhotoGrid(biz: biz)),
      ],
    );
  }
}

// ── Photo Toolbar ─────────────────────────────────────────────────────────────

class _PhotoToolbar extends ConsumerStatefulWidget {
  const _PhotoToolbar({required this.biz});
  final Map<String, dynamic> biz;

  @override
  ConsumerState<_PhotoToolbar> createState() => _PhotoToolbarState();
}

class _PhotoToolbarState extends ConsumerState<_PhotoToolbar> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _uploading = true);
    try {
      final bizId = widget.biz['id'] as String;
      int uploaded = 0;

      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null) continue;

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final path = 'portfolio/$bizId/${timestamp}_${file.name}';

        await BCSupabase.client.storage
            .from('staff-media')
            .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: false));

        final publicUrl = BCSupabase.client.storage
            .from('staff-media')
            .getPublicUrl(path);

        await BCSupabase.client.from('portfolio_photos').insert({
          'business_id': bizId,
          'url': publicUrl,
          'storage_path': path,
          'caption': '',
          'is_before_after': false,
          'is_visible': true,
          'sort_order': timestamp,
        });

        uploaded++;
      }

      ref.invalidate(_portfolioPhotosProvider);

      if (mounted && uploaded > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$uploaded foto${uploaded > 1 ? 's' : ''} subida${uploaded > 1 ? 's' : ''}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isGrid = ref.watch(_photoViewGridProvider);
    final staffAsync = ref.watch(businessStaffProvider);
    final currentFilter = ref.watch(_photoStaffFilterProvider);
    final isDemo = ref.watch(isDemoProvider);

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        children: [
          Text(
            'Fotos del portafolio',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 12),

          // Photo count chip
          Consumer(
            builder: (context, ref, _) {
              final photosAsync = ref.watch(_portfolioPhotosProvider);
              final count = photosAsync.valueOrNull?.length ?? 0;
              return Chip(
                label: Text('$count'),
                visualDensity: VisualDensity.compact,
              );
            },
          ),

          const Spacer(),

          // Staff filter dropdown
          staffAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (staff) {
              if (staff.isEmpty) return const SizedBox.shrink();
              return Container(
                height: 34,
                margin: const EdgeInsets.only(right: 8),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: currentFilter,
                    isDense: true,
                    borderRadius: BorderRadius.circular(8),
                    hint: const Text('Todos'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Todos'),
                      ),
                      for (final s in staff)
                        DropdownMenuItem<String?>(
                          value: s['id'] as String,
                          child: Text(
                            '${s['first_name'] ?? ''} ${s['last_name'] ?? ''}'.trim(),
                          ),
                        ),
                    ],
                    onChanged: (v) =>
                        ref.read(_photoStaffFilterProvider.notifier).state = v,
                  ),
                ),
              );
            },
          ),

          // Grid/List toggle
          IconButton(
            icon: Icon(
              isGrid ? Icons.grid_view : Icons.view_list_outlined,
              size: 20,
              color: colors.onSurface.withValues(alpha: 0.7),
            ),
            tooltip: isGrid ? 'Vista lista' : 'Vista cuadricula',
            onPressed: () =>
                ref.read(_photoViewGridProvider.notifier).state = !isGrid,
          ),

          // Upload button
          if (!isDemo) ...[
            const SizedBox(width: 4),
            ElevatedButton.icon(
              onPressed: _uploading ? null : _pickAndUpload,
              icon: _uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined, size: 18),
              label: Text(_uploading ? 'Subiendo...' : 'Subir fotos'),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Photo Grid ────────────────────────────────────────────────────────────────

class _PhotoGrid extends ConsumerWidget {
  const _PhotoGrid({required this.biz});
  final Map<String, dynamic> biz;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photosAsync = ref.watch(_portfolioPhotosProvider);
    final isGrid = ref.watch(_photoViewGridProvider);
    final staffFilter = ref.watch(_photoStaffFilterProvider);
    final selected = ref.watch(_selectedPhotoProvider);

    return photosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (photos) {
        // Apply staff filter
        final filtered = staffFilter != null
            ? photos.where((p) => p['staff_id'] == staffFilter).toList()
            : photos;

        if (filtered.isEmpty) {
          return _EmptyPhotos(isFiltered: staffFilter != null);
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final showDetail = selected != null;
            final availableWidth =
                showDetail ? constraints.maxWidth - 360 : constraints.maxWidth;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photo grid/list
                SizedBox(
                  width: availableWidth,
                  child: Column(
                    children: [
                      // Stats bar
                      _StatsBar(photos: photos, biz: biz),
                      // Content
                      Expanded(
                        child: isGrid
                            ? _GridView(photos: filtered)
                            : _ListView(photos: filtered),
                      ),
                    ],
                  ),
                ),

                // Detail panel
                if (showDetail) ...[
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  SizedBox(
                    width: 360,
                    child: _PhotoDetailPanel(photo: selected, biz: biz),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

// ── Stats Bar ─────────────────────────────────────────────────────────────────

class _StatsBar extends ConsumerWidget {
  const _StatsBar({required this.photos, required this.biz});
  final List<Map<String, dynamic>> photos;
  final Map<String, dynamic> biz;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final staffAsync = ref.watch(businessStaffProvider);

    // Count photos per staff
    final Map<String, int> perStaff = {};
    for (final p in photos) {
      final sid = p['staff_id'] as String?;
      if (sid != null) perStaff[sid] = (perStaff[sid] ?? 0) + 1;
    }

    final visible = photos.where((p) => p['is_visible'] == true).length;
    final beforeAfter = photos.where((p) => p['is_before_after'] == true).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(bottom: BorderSide(color: colors.outlineVariant, width: 0.5)),
      ),
      child: Row(
        children: [
          _StatChip(label: 'Total', value: '${photos.length}', icon: Icons.photo_library_outlined),
          const SizedBox(width: 12),
          _StatChip(label: 'Visibles', value: '$visible', icon: Icons.visibility_outlined),
          const SizedBox(width: 12),
          _StatChip(label: 'Antes/Despues', value: '$beforeAfter', icon: Icons.compare_outlined),
          const Spacer(),
          // Per-staff count badges
          staffAsync.maybeWhen(
            data: (staff) => Row(
              children: [
                for (final s in staff)
                  if (perStaff.containsKey(s['id'] as String))
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _StaffPhotoCount(
                        staff: s,
                        count: perStaff[s['id'] as String]!,
                      ),
                    ),
              ],
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: colors.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: 4),
        Text(
          value,
          style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

class _StaffPhotoCount extends StatelessWidget {
  const _StaffPhotoCount({required this.staff, required this.count});
  final Map<String, dynamic> staff;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final name = '${staff['first_name'] ?? ''}'.trim();
    final avatarUrl = staff['avatar_url'] as String?;

    return Tooltip(
      message: '$name: $count fotos',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            backgroundColor: colors.primary.withValues(alpha: 0.12),
            child: avatarUrl == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(fontSize: 10, color: colors.primary),
                  )
                : null,
          ),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── Grid View ─────────────────────────────────────────────────────────────────

class _GridView extends ConsumerWidget {
  const _GridView({required this.photos});
  final List<Map<String, dynamic>> photos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: photos.length,
      itemBuilder: (context, i) => _PhotoCard(photo: photos[i]),
    );
  }
}

class _PhotoCard extends ConsumerStatefulWidget {
  const _PhotoCard({required this.photo});
  final Map<String, dynamic> photo;

  @override
  ConsumerState<_PhotoCard> createState() => _PhotoCardState();
}

class _PhotoCardState extends ConsumerState<_PhotoCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selected = ref.watch(_selectedPhotoProvider);
    final isSelected = selected?['id'] == widget.photo['id'];
    final url = widget.photo['url'] as String?;
    final caption = widget.photo['caption'] as String? ?? '';
    final isBeforeAfter = widget.photo['is_before_after'] == true;
    final isVisible = widget.photo['is_visible'] != false;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          final current = ref.read(_selectedPhotoProvider);
          ref.read(_selectedPhotoProvider.notifier).state =
              current?['id'] == widget.photo['id'] ? null : widget.photo;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? colors.primary
                  : _hovering
                      ? colors.primary.withValues(alpha: 0.4)
                      : colors.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
            color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Column(
              children: [
                // Thumbnail
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (url != null)
                        Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: colors.onSurface.withValues(alpha: 0.3),
                            ),
                          ),
                        )
                      else
                        Center(
                          child: Icon(
                            Icons.image_outlined,
                            color: colors.onSurface.withValues(alpha: 0.3),
                          ),
                        ),

                      // Before/After badge
                      if (isBeforeAfter)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.tertiary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Antes/Despues',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.onTertiary,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ),

                      // Hidden badge
                      if (!isVisible)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
                              Icons.visibility_off,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),

                      // Hover overlay
                      if (_hovering && !isSelected)
                        Container(
                          color: colors.primary.withValues(alpha: 0.08),
                        ),
                    ],
                  ),
                ),

                // Caption strip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  color: colors.surface,
                  child: Text(
                    caption.isNotEmpty ? caption : 'Sin descripcion',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: caption.isNotEmpty
                          ? colors.onSurface.withValues(alpha: 0.8)
                          : colors.onSurface.withValues(alpha: 0.35),
                      fontStyle:
                          caption.isEmpty ? FontStyle.italic : FontStyle.normal,
                    ),
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

// ── List View ─────────────────────────────────────────────────────────────────

class _ListView extends ConsumerWidget {
  const _ListView({required this.photos});
  final List<Map<String, dynamic>> photos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: photos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final p = photos[i];
        final url = p['url'] as String?;
        final caption = p['caption'] as String? ?? '';
        final isBeforeAfter = p['is_before_after'] == true;
        final isVisible = p['is_visible'] != false;
        final selected = ref.watch(_selectedPhotoProvider);
        final isSelected = selected?['id'] == p['id'];

        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            final current = ref.read(_selectedPhotoProvider);
            ref.read(_selectedPhotoProvider.notifier).state =
                current?['id'] == p['id'] ? null : p;
          },
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? colors.primary : colors.outlineVariant,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: url != null
                        ? Image.network(url, fit: BoxFit.cover)
                        : Container(color: colors.surfaceContainerHighest),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    caption.isNotEmpty ? caption : 'Sin descripcion',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: caption.isNotEmpty
                          ? colors.onSurface.withValues(alpha: 0.85)
                          : colors.onSurface.withValues(alpha: 0.4),
                      fontStyle:
                          caption.isEmpty ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (isBeforeAfter)
                  Chip(
                    label: const Text('A/D'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: colors.tertiary.withValues(alpha: 0.15),
                    labelStyle: theme.textTheme.labelSmall?.copyWith(
                      color: colors.tertiary,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                if (!isVisible)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.visibility_off_outlined,
                      size: 16,
                      color: colors.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Photo Detail Panel ────────────────────────────────────────────────────────

class _PhotoDetailPanel extends ConsumerStatefulWidget {
  const _PhotoDetailPanel({required this.photo, required this.biz});
  final Map<String, dynamic> photo;
  final Map<String, dynamic> biz;

  @override
  ConsumerState<_PhotoDetailPanel> createState() => _PhotoDetailPanelState();
}

class _PhotoDetailPanelState extends ConsumerState<_PhotoDetailPanel> {
  late final TextEditingController _captionCtrl;
  late final TextEditingController _productTagsCtrl;
  late bool _isBeforeAfter;
  late bool _isVisible;
  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _captionCtrl = TextEditingController(
      text: widget.photo['caption'] as String? ?? '',
    );
    final tags = widget.photo['product_tags'];
    _productTagsCtrl = TextEditingController(
      text: tags is List ? tags.join(', ') : (tags as String? ?? ''),
    );
    _isBeforeAfter = widget.photo['is_before_after'] == true;
    _isVisible = widget.photo['is_visible'] != false;
  }

  @override
  void didUpdateWidget(_PhotoDetailPanel old) {
    super.didUpdateWidget(old);
    if (old.photo['id'] != widget.photo['id']) {
      _captionCtrl.text = widget.photo['caption'] as String? ?? '';
      final tags = widget.photo['product_tags'];
      _productTagsCtrl.text =
          tags is List ? tags.join(', ') : (tags as String? ?? '');
      _isBeforeAfter = widget.photo['is_before_after'] == true;
      _isVisible = widget.photo['is_visible'] != false;
    }
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    _productTagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final tags = _productTagsCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      await BCSupabase.client.from('portfolio_photos').update({
        'caption': _captionCtrl.text.trim(),
        'product_tags': tags,
        'is_before_after': _isBeforeAfter,
        'is_visible': _isVisible,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.photo['id'] as String);

      ref.invalidate(_portfolioPhotosProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto actualizada')),
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

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar foto'),
        content: const Text('Esta accion no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      // Remove from storage
      final path = widget.photo['storage_path'] as String?;
      if (path != null) {
        await BCSupabase.client.storage.from('staff-media').remove([path]);
      }

      // Remove from DB
      await BCSupabase.client
          .from('portfolio_photos')
          .delete()
          .eq('id', widget.photo['id'] as String);

      ref.read(_selectedPhotoProvider.notifier).state = null;
      ref.invalidate(_portfolioPhotosProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final url = widget.photo['url'] as String?;
    final isDemo = ref.watch(isDemoProvider);

    return Column(
      children: [
        // Panel header
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.outlineVariant)),
          ),
          child: Row(
            children: [
              Text(
                'Detalle de foto',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () =>
                    ref.read(_selectedPhotoProvider.notifier).state = null,
                tooltip: 'Cerrar',
              ),
            ],
          ),
        ),

        // Scrollable content
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Full preview
              if (url != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio: 1.2,
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: colors.surfaceContainerHighest,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: colors.onSurface.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Caption
              Text(
                'Descripcion',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _captionCtrl,
                enabled: !isDemo,
                maxLines: 3,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText: 'Describe el trabajo realizado...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(10),
                  isDense: true,
                ),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 14),

              // Product tags
              Text(
                'Productos usados (separados por coma)',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _productTagsCtrl,
                enabled: !isDemo,
                decoration: InputDecoration(
                  hintText: 'Kerastase, Olaplex, L\'Oreal',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                ),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 14),

              // Toggles
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Antes y despues',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Muestra badge especial',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isBeforeAfter,
                    onChanged: isDemo
                        ? null
                        : (v) => setState(() => _isBeforeAfter = v),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Visible al publico',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Aparece en tu portafolio',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isVisible,
                    onChanged: isDemo
                        ? null
                        : (v) => setState(() => _isVisible = v),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Action buttons
              if (!isDemo) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Guardar cambios'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _deleting ? null : _delete,
                    icon: _deleting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Eliminar foto'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.error,
                      side: BorderSide(color: colors.error.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyPhotos extends StatelessWidget {
  const _EmptyPhotos({required this.isFiltered});
  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 56,
            color: colors.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            isFiltered
                ? 'Sin fotos para este estilista'
                : 'Sin fotos en el portafolio',
            style: theme.textTheme.titleSmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isFiltered
                ? 'Sube fotos y asignalas a este estilista'
                : 'Usa el boton "Subir fotos" para empezar',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared UI Helpers ─────────────────────────────────────────────────────────

/// Section header bar at the top of a column.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Card container with title and icon used for settings sections.
class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(bottom: BorderSide(color: colors.outlineVariant)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 17, color: colors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Panel body
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Visual chip for theme selection.
class _ThemeChip extends StatefulWidget {
  const _ThemeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<_ThemeChip> createState() => _ThemeChipState();
}

class _ThemeChipState extends State<_ThemeChip> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: widget.selected
                ? colors.primary
                : _hovering
                    ? colors.primary.withValues(alpha: 0.08)
                    : colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.selected
                  ? colors.primary
                  : colors.outlineVariant,
            ),
          ),
          child: Text(
            widget.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: widget.selected
                  ? colors.onPrimary
                  : colors.onSurface.withValues(alpha: 0.8),
              fontWeight:
                  widget.selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
