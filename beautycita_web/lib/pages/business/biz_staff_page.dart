import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:beautycita_core/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../config/breakpoints.dart';
import '../../providers/business_portal_provider.dart';
import '../../widgets/aphrodite_copy_field.dart';

/// Selected staff for detail panel.
final selectedStaffProvider = StateProvider<Map<String, dynamic>?>((ref) => null);

/// Whether the detail panel is in edit mode.
final _staffEditModeProvider = StateProvider<bool>((ref) => false);

/// Business staff management page — full CRUD with avatar, portfolio, schedule
/// breaks, time-off blocks, AI bio, experience, owner auto-create.
class BizStaffPage extends ConsumerWidget {
  const BizStaffPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bizAsync = ref.watch(currentBusinessProvider);

    return bizAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (biz) {
        if (biz == null) return const Center(child: Text('Sin negocio'));
        return _StaffContent(biz: biz);
      },
    );
  }
}

class _StaffContent extends ConsumerWidget {
  const _StaffContent({required this.biz});
  final Map<String, dynamic> biz;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(businessStaffProvider);
    final selected = ref.watch(selectedStaffProvider);
    final bizId = biz['id'] as String;
    final ownerId = biz['owner_id'] as String?;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = WebBreakpoints.isDesktop(constraints.maxWidth);
        final showPanel = selected != null && isDesktop;

        return Row(
          children: [
            Expanded(
              child: staffAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(child: Text('Error al cargar staff')),
                data: (staff) => _StaffList(
                  staff: staff,
                  isDesktop: isDesktop,
                  bizId: bizId,
                  ownerId: ownerId,
                ),
              ),
            ),
            if (showPanel) ...[
              VerticalDivider(width: 1, color: Theme.of(context).colorScheme.outlineVariant),
              SizedBox(width: 480, child: _StaffDetailPanel(staff: selected, bizId: bizId)),
            ],
          ],
        );
      },
    );
  }
}

// ── Staff List ──────────────────────────────────────────────────────────────

class _StaffList extends ConsumerWidget {
  const _StaffList({
    required this.staff,
    required this.isDesktop,
    required this.bizId,
    required this.ownerId,
  });
  final List<Map<String, dynamic>> staff;
  final bool isDesktop;
  final String bizId;
  final String? ownerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // Detect if owner has a staff record
    final hasOwnerStaff = staff.any((s) => s['user_id'] == ownerId);

    return Column(
      children: [
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.outlineVariant))),
          child: Row(
            children: [
              Text('Staff', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Chip(label: Text('${staff.length}'), visualDensity: VisualDensity.compact),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddStaffDialog(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar staff'),
              ),
            ],
          ),
        ),
        // Owner profile card if no staff record exists
        if (!hasOwnerStaff && ownerId != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _CreateOwnerCard(bizId: bizId, ownerId: ownerId!),
          ),
        Expanded(
          child: staff.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outlined, size: 48, color: colors.onSurface.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text('Sin staff registrado', style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurface.withValues(alpha: 0.5))),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isDesktop ? 3 : 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: staff.length,
                  itemBuilder: (context, i) => _StaffCard(
                    staff: staff[i],
                    bizId: bizId,
                    isOwner: staff[i]['user_id'] == ownerId,
                  ),
                ),
        ),
      ],
    );
  }

  void _showAddStaffDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _AddStaffDialog(bizId: bizId),
    );
  }
}

// ── Create Owner Staff Card ─────────────────────────────────────────────────

class _CreateOwnerCard extends ConsumerStatefulWidget {
  const _CreateOwnerCard({required this.bizId, required this.ownerId});
  final String bizId;
  final String ownerId;

  @override
  ConsumerState<_CreateOwnerCard> createState() => _CreateOwnerCardState();
}

class _CreateOwnerCardState extends ConsumerState<_CreateOwnerCard> {
  bool _creating = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.person_add_outlined, size: 24, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Crear mi perfil de estilista', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                Text('Agrega tu perfil al equipo para recibir citas', style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurface.withValues(alpha: 0.5))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _creating ? null : _create,
            child: _creating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Crear'),
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    setState(() => _creating = true);
    try {
      final profile = await BCSupabase.client
          .from(BCTables.profiles)
          .select('full_name, username, avatar_url, phone')
          .eq('id', widget.ownerId)
          .maybeSingle();

      final fullName = profile?['full_name'] as String? ?? profile?['username'] as String? ?? 'Dueno';
      final parts = fullName.split(' ');
      final firstName = parts.first;
      final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      await BCSupabase.client.from(BCTables.staff).insert({
        'business_id': widget.bizId,
        'user_id': widget.ownerId,
        'first_name': firstName,
        'last_name': lastName,
        'avatar_url': profile?['avatar_url'],
        'phone': profile?['phone'],
        'is_active': true,
        'sort_order': -1,
      });

      ref.invalidate(businessStaffProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil creado')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }
}

// ── Add Staff Dialog ────────────────────────────────────────────────────────

class _AddStaffDialog extends ConsumerStatefulWidget {
  const _AddStaffDialog({required this.bizId});
  final String bizId;

  @override
  ConsumerState<_AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends ConsumerState<_AddStaffDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _expCtrl = TextEditingController(text: '0');
  final _bioCtrl = TextEditingController();
  String _role = 'estilista';
  bool _saving = false;

  // Avatar
  PlatformFile? _avatarFile;

  // Portfolio
  final List<PlatformFile> _portfolioFiles = [];

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _expCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  String get _expLabel {
    final v = int.tryParse(_expCtrl.text) ?? 0;
    if (v == 0) return 'Principiante';
    if (v == 1) return '1 ano';
    return '$v anos';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
              child: Row(
                children: [
                  Text('Agregar staff', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            const Divider(),
            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar picker
                      Center(
                        child: GestureDetector(
                          onTap: _pickAvatar,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundColor: colors.primary.withValues(alpha: 0.12),
                                backgroundImage: _avatarFile?.bytes != null ? MemoryImage(_avatarFile!.bytes!) : null,
                                child: _avatarFile == null
                                    ? Icon(Icons.person, size: 40, color: colors.primary.withValues(alpha: 0.4))
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: colors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.camera_alt, size: 14, color: colors.onPrimary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Names
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _firstNameCtrl,
                              decoration: const InputDecoration(labelText: 'Nombre'),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _lastNameCtrl,
                              decoration: const InputDecoration(labelText: 'Apellido'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneCtrl,
                        decoration: const InputDecoration(labelText: 'Telefono'),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(labelText: 'Rol'),
                              value: _role,
                              items: const [
                                DropdownMenuItem(value: 'estilista', child: Text('Estilista')),
                                DropdownMenuItem(value: 'barbero', child: Text('Barbero')),
                                DropdownMenuItem(value: 'masajista', child: Text('Masajista')),
                                DropdownMenuItem(value: 'manicurista', child: Text('Manicurista')),
                                DropdownMenuItem(value: 'esteticista', child: Text('Esteticista')),
                                DropdownMenuItem(value: 'recepcionista', child: Text('Recepcionista')),
                              ],
                              onChanged: (v) => setState(() => _role = v ?? 'estilista'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 100,
                            child: TextFormField(
                              controller: _expCtrl,
                              decoration: InputDecoration(labelText: 'Exp. (anos)', helperText: _expLabel),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly, _MaxValueFormatter(50)],
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // AI Bio
                      AphroditeCopyField(
                        controller: _bioCtrl,
                        label: 'Biografia',
                        hint: 'Escribe o genera una biografia...',
                        fieldType: 'staff_bio',
                        icon: Icons.auto_awesome_outlined,
                        context: {
                          'name': _firstNameCtrl.text,
                          'role': _role,
                        },
                        autoGenerate: false,
                      ),
                      const SizedBox(height: 16),
                      // Portfolio
                      Text('Portfolio', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 80,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final f in _portfolioFiles)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: f.bytes != null
                                          ? Image.memory(f.bytes!, width: 80, height: 80, fit: BoxFit.cover)
                                          : Container(width: 80, height: 80, color: colors.surfaceContainerHighest),
                                    ),
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: GestureDetector(
                                        onTap: () => setState(() => _portfolioFiles.remove(f)),
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(color: colors.error, shape: BoxShape.circle),
                                          child: Icon(Icons.close, size: 12, color: colors.onError),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            GestureDetector(
                              onTap: _pickPortfolio,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: colors.outlineVariant, style: BorderStyle.solid),
                                ),
                                child: Icon(Icons.add_photo_alternate_outlined, color: colors.onSurface.withValues(alpha: 0.3)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
            // Actions
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Crear'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _avatarFile = result.files.first);
    }
  }

  Future<void> _pickPortfolio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result != null) {
      setState(() => _portfolioFiles.addAll(result.files));
    }
  }

  Future<String?> _uploadFile(Uint8List bytes, String path) async {
    try {
      await BCSupabase.client.storage.from('staff-media').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );
      return BCSupabase.client.storage.from('staff-media').getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final staffId = DateTime.now().millisecondsSinceEpoch.toString();

      // Upload avatar
      String? avatarUrl;
      if (_avatarFile?.bytes != null) {
        avatarUrl = await _uploadFile(
          _avatarFile!.bytes!,
          '${widget.bizId}/avatars/$staffId.jpg',
        );
      }

      // Upload portfolio
      final portfolioUrls = <String>[];
      for (var i = 0; i < _portfolioFiles.length; i++) {
        if (_portfolioFiles[i].bytes != null) {
          final url = await _uploadFile(
            _portfolioFiles[i].bytes!,
            '${widget.bizId}/portfolio/${staffId}_$i.jpg',
          );
          if (url != null) portfolioUrls.add(url);
        }
      }

      await BCSupabase.client.from(BCTables.staff).insert({
        'business_id': widget.bizId,
        'first_name': _firstNameCtrl.text.trim(),
        'last_name': _lastNameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'role': _role,
        'experience_years': int.tryParse(_expCtrl.text.trim()) ?? 0,
        'bio': _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
        'avatar_url': avatarUrl,
        'portfolio_urls': portfolioUrls,
        'is_active': true,
      });

      ref.invalidate(businessStaffProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Staff Card ──────────────────────────────────────────────────────────────

class _StaffCard extends ConsumerStatefulWidget {
  const _StaffCard({required this.staff, required this.bizId, this.isOwner = false});
  final Map<String, dynamic> staff;
  final String bizId;
  final bool isOwner;

  @override
  ConsumerState<_StaffCard> createState() => _StaffCardState();
}

class _StaffCardState extends ConsumerState<_StaffCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final s = widget.staff;
    final firstName = s['first_name'] as String? ?? '';
    final lastName = s['last_name'] as String? ?? '';
    final name = '$firstName $lastName'.trim();
    final displayName = name.isEmpty ? (s['name'] as String? ?? '') : name;
    final role = s['role'] as String? ?? 'Estilista';
    final isActive = s['is_active'] as bool? ?? true;
    final rating = (s['average_rating'] as num?)?.toDouble() ?? (s['rating'] as num?)?.toDouble();
    final avatar = s['avatar_url'] as String?;
    final expYears = s['experience_years'] as int?;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          ref.read(selectedStaffProvider.notifier).state = s;
          ref.read(_staffEditModeProvider.notifier).state = false;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _hovering ? colors.primary.withValues(alpha: 0.3) : colors.outlineVariant),
            boxShadow: _hovering ? [BoxShadow(color: colors.primary.withValues(alpha: 0.06), blurRadius: 8)] : null,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: colors.primary.withValues(alpha: 0.12),
                backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                child: avatar == null ? Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?', style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold)) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(displayName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        if (widget.isOwner) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('Dueno', style: TextStyle(fontSize: 10, color: colors.primary, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [role, if (expYears != null && expYears > 0) '${expYears}a exp'].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurface.withValues(alpha: 0.5)),
                    ),
                    if (rating != null && rating > 0) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 13, color: Color(0xFFFFC107)),
                          const SizedBox(width: 2),
                          Text(rating.toStringAsFixed(1), style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _toggleActive(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF4CAF50).withValues(alpha: 0.1) : colors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? 'Activo' : 'Inactivo',
                    style: TextStyle(fontSize: 11, color: isActive ? const Color(0xFF4CAF50) : colors.error, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleActive(Map<String, dynamic> s) async {
    final id = s['id'] as String?;
    if (id == null) return;
    final current = s['is_active'] as bool? ?? true;
    try {
      await BCSupabase.client.from(BCTables.staff).update({'is_active': !current}).eq('id', id);
      ref.invalidate(businessStaffProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// ── Staff Detail Panel ──────────────────────────────────────────────────────

class _StaffDetailPanel extends ConsumerWidget {
  const _StaffDetailPanel({required this.staff, required this.bizId});
  final Map<String, dynamic> staff;
  final String bizId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditing = ref.watch(_staffEditModeProvider);
    if (isEditing) {
      return _StaffEditForm(staff: staff, bizId: bizId);
    }
    return _StaffReadView(staff: staff, bizId: bizId);
  }
}

// ── Staff Read View ─────────────────────────────────────────────────────────

class _StaffReadView extends ConsumerWidget {
  const _StaffReadView({required this.staff, required this.bizId});
  final Map<String, dynamic> staff;
  final String bizId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final staffId = staff['id'] as String? ?? '';
    final firstName = staff['first_name'] as String? ?? '';
    final lastName = staff['last_name'] as String? ?? '';
    final name = '$firstName $lastName'.trim();
    final displayName = name.isEmpty ? (staff['name'] as String? ?? '') : name;
    final role = staff['role'] as String? ?? '';
    final phone = staff['phone'] as String? ?? '';
    final email = staff['email'] as String? ?? '';
    final isActive = staff['is_active'] as bool? ?? true;
    final expYears = staff['experience_years'] as int?;
    final bio = staff['bio'] as String?;
    final avatar = staff['avatar_url'] as String?;
    final portfolioUrls = (staff['portfolio_urls'] as List?)?.cast<String>() ?? [];
    final avgRating = (staff['average_rating'] as num?)?.toDouble();
    final totalReviews = staff['total_reviews'] as int?;

    final scheduleAsync = ref.watch(staffScheduleProvider(staffId));
    final servicesAsync = ref.watch(staffServicesProvider(staffId));
    final blocksAsync = ref.watch(staffBlocksProvider(staffId));

    return Container(
      color: colors.surface,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.outlineVariant))),
            child: Row(
              children: [
                Expanded(child: Text(displayName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => ref.read(_staffEditModeProvider.notifier).state = true,
                  tooltip: 'Editar',
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => ref.read(selectedStaffProvider.notifier).state = null,
                  tooltip: 'Cerrar',
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar + basic info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: colors.primary.withValues(alpha: 0.12),
                        backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                        child: avatar == null ? Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?', style: TextStyle(fontSize: 24, color: colors.primary, fontWeight: FontWeight.bold)) : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (role.isNotEmpty) _InfoRow(icon: Icons.badge_outlined, label: role),
                            if (expYears != null && expYears > 0) _InfoRow(icon: Icons.work_history_outlined, label: expYears == 1 ? '1 ano de experiencia' : '$expYears anos de experiencia'),
                            if (phone.isNotEmpty) _InfoRow(icon: Icons.phone_outlined, label: phone),
                            if (email.isNotEmpty) _InfoRow(icon: Icons.email_outlined, label: email),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _InfoRow(
                    icon: isActive ? Icons.check_circle_outline : Icons.cancel_outlined,
                    label: isActive ? 'Activo' : 'Inactivo',
                    color: isActive ? const Color(0xFF4CAF50) : colors.error,
                  ),

                  // Performance stats
                  if (avgRating != null || totalReviews != null) ...[
                    const SizedBox(height: BCSpacing.md),
                    Text('Rendimiento', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: BCSpacing.sm),
                    Row(
                      children: [
                        if (avgRating != null && avgRating > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFC107).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, size: 16, color: Color(0xFFFFC107)),
                                const SizedBox(width: 4),
                                Text(avgRating.toStringAsFixed(1), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        if (avgRating != null && avgRating > 0) const SizedBox(width: 8),
                        if (totalReviews != null && totalReviews > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.reviews_outlined, size: 16, color: colors.primary),
                                const SizedBox(width: 4),
                                Text('$totalReviews resenas', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],

                  // Bio
                  if (bio != null && bio.isNotEmpty) ...[
                    const SizedBox(height: BCSpacing.md),
                    Text('Biografia', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: BCSpacing.xs),
                    Text(bio, style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurface.withValues(alpha: 0.7))),
                  ],

                  // Portfolio
                  if (portfolioUrls.isNotEmpty) ...[
                    const SizedBox(height: BCSpacing.md),
                    Text('Portfolio', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: BCSpacing.sm),
                    SizedBox(
                      height: 100,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final url in portfolioUrls)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(url, width: 100, height: 100, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(width: 100, height: 100, color: colors.surfaceContainerHighest, child: const Icon(Icons.broken_image_outlined)),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: BCSpacing.lg),

                  // Schedule
                  Text('Horario semanal', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: BCSpacing.sm),
                  scheduleAsync.when(
                    loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                    error: (_, __) => const Text('Error al cargar horario'),
                    data: (schedule) => _WeeklyScheduleGrid(schedule: schedule),
                  ),
                  const SizedBox(height: BCSpacing.lg),

                  // Time-off blocks
                  Text('Tiempo libre', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: BCSpacing.sm),
                  blocksAsync.when(
                    loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                    error: (_, __) => const Text('Error al cargar bloques'),
                    data: (blocks) {
                      if (blocks.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text('Sin tiempo libre programado', style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurface.withValues(alpha: 0.5))),
                        );
                      }
                      return Column(
                        children: [
                          for (final b in blocks) _TimeOffRow(block: b),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: BCSpacing.lg),

                  // Services
                  Text('Servicios asignados', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: BCSpacing.sm),
                  servicesAsync.when(
                    loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                    error: (_, __) => const Text('Error al cargar servicios'),
                    data: (services) {
                      if (services.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text('Sin servicios asignados', style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurface.withValues(alpha: 0.5))),
                        );
                      }
                      return Column(
                        children: [for (final ss in services) _AssignedServiceRow(staffService: ss)],
                      );
                    },
                  ),
                  const SizedBox(height: BCSpacing.xl),

                  // Delete button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmDelete(context, ref),
                      icon: Icon(Icons.delete_outline, size: 18, color: colors.error),
                      label: Text('Eliminar staff', style: TextStyle(color: colors.error)),
                      style: OutlinedButton.styleFrom(side: BorderSide(color: colors.error.withValues(alpha: 0.3))),
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

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    final firstName = staff['first_name'] as String? ?? '';
    final lastName = staff['last_name'] as String? ?? '';
    final name = '$firstName $lastName'.trim();
    final displayName = name.isEmpty ? (staff['name'] as String? ?? 'este staff') : name;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar staff'),
        content: Text('Seguro que desea eliminar a $displayName?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await BCSupabase.client.from(BCTables.staff).delete().eq('id', staff['id'] as String);
                ref.invalidate(businessStaffProvider);
                ref.read(selectedStaffProvider.notifier).state = null;
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

// ── Time Off Row ────────────────────────────────────────────────────────────

class _TimeOffRow extends StatelessWidget {
  const _TimeOffRow({required this.block});
  final Map<String, dynamic> block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final reason = block['reason'] as String? ?? 'other';
    final start = DateTime.tryParse(block['starts_at'] as String? ?? '');
    final end = DateTime.tryParse(block['ends_at'] as String? ?? '');

    final (IconData icon, String label) = switch (reason) {
      'lunch' => (Icons.restaurant_rounded, 'Almuerzo'),
      'day_off' => (Icons.event_busy_rounded, 'Dia libre'),
      'vacation' => (Icons.beach_access_rounded, 'Vacaciones'),
      _ => (Icons.block_rounded, 'Bloqueado'),
    };

    String dateStr = '';
    if (start != null && end != null) {
      dateStr = '${start.day}/${start.month} ${start.hour}:${start.minute.toString().padLeft(2, '0')} - '
          '${end.day}/${end.month} ${end.hour}:${end.minute.toString().padLeft(2, '0')}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 8),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(child: Text(dateStr, style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurface.withValues(alpha: 0.5), fontFamily: 'monospace'))),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, this.color});
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 8),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: c, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Staff Edit Form ─────────────────────────────────────────────────────────

class _StaffEditForm extends ConsumerStatefulWidget {
  const _StaffEditForm({required this.staff, required this.bizId});
  final Map<String, dynamic> staff;
  final String bizId;

  @override
  ConsumerState<_StaffEditForm> createState() => _StaffEditFormState();
}

class _StaffEditFormState extends ConsumerState<_StaffEditForm> {
  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _expCtrl;
  late TextEditingController _bioCtrl;
  late String _role;
  late bool _isActive;
  bool _saving = false;

  // Schedule state: 0-indexed (0=Mon ... 6=Sun)
  List<_DaySchedule>? _schedule;
  bool _scheduleModified = false;

  // Service assignment state
  Set<String> _assignedServiceIds = {};

  @override
  void initState() {
    super.initState();
    final s = widget.staff;
    final firstName = s['first_name'] as String? ?? '';
    final lastName = s['last_name'] as String? ?? '';
    _firstNameCtrl = TextEditingController(text: firstName.isEmpty ? (s['name'] as String? ?? '') : firstName);
    _lastNameCtrl = TextEditingController(text: lastName);
    _phoneCtrl = TextEditingController(text: s['phone'] as String? ?? '');
    _emailCtrl = TextEditingController(text: s['email'] as String? ?? '');
    _expCtrl = TextEditingController(text: (s['experience_years'] as int?)?.toString() ?? '0');
    _bioCtrl = TextEditingController(text: s['bio'] as String? ?? '');
    _role = s['role'] as String? ?? 'estilista';
    _isActive = s['is_active'] as bool? ?? true;

    _loadSchedule();
    _loadServices();
  }

  void _loadSchedule() {
    final staffId = widget.staff['id'] as String? ?? '';
    final scheduleAsync = ref.read(staffScheduleProvider(staffId));
    final data = scheduleAsync.valueOrNull ?? [];

    _schedule = List.generate(7, (i) {
      final dow = i; // 0-indexed to match provider (day_of_week)
      // Provider stores day_of_week 1-7, we use 0-6 internally for display
      final match = data.where((s) => s['day_of_week'] == i + 1).toList();
      if (match.isNotEmpty) {
        final s = match.first;
        final rawBreaks = s['breaks'] as List<dynamic>? ?? [];
        final breaks = rawBreaks
            .map((b) => _BreakWindow(
                  start: _parseTimeStr(b['start'] as String?),
                  end: _parseTimeStr(b['end'] as String?),
                ))
            .toList();
        return _DaySchedule(
          dayIndex: dow,
          isAvailable: s['is_available'] as bool? ?? true,
          startTime: _parseTimeStr(s['start_time'] as String?),
          endTime: _parseTimeStr(s['end_time'] as String?),
          breaks: breaks,
        );
      }
      return _DaySchedule(
        dayIndex: dow,
        isAvailable: false,
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 18, minute: 0),
      );
    });
  }

  TimeOfDay _parseTimeStr(String? s) {
    if (s == null) return const TimeOfDay(hour: 9, minute: 0);
    final parts = s.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _loadServices() {
    final staffId = widget.staff['id'] as String? ?? '';
    final servicesAsync = ref.read(staffServicesProvider(staffId));
    final assigned = servicesAsync.valueOrNull ?? [];
    _assignedServiceIds = assigned.map((s) => s['service_id'] as String).toSet();
  }

  String get _expLabel {
    final v = int.tryParse(_expCtrl.text) ?? 0;
    if (v == 0) return 'Principiante';
    if (v == 1) return '1 ano';
    return '$v anos';
  }

  /// Smart auto-lunch: look at previous day's break time.
  /// If Mon has a 15:00-16:00 break, Tue's auto-lunch defaults to 15:00-16:00.
  _BreakWindow _smartAutoLunch(int dayIndex) {
    // Look backwards to find the nearest configured day with a break
    for (var offset = 1; offset <= 7; offset++) {
      final prevIdx = (dayIndex - offset + 7) % 7;
      final prevDay = _schedule![prevIdx];
      if (prevDay.isAvailable && prevDay.breaks.isNotEmpty) {
        final prevBreak = prevDay.breaks.first;
        return _BreakWindow(start: prevBreak.start, end: prevBreak.end);
      }
    }
    // Default: 14:00-15:00
    return const _BreakWindow(
      start: TimeOfDay(hour: 14, minute: 0),
      end: TimeOfDay(hour: 15, minute: 0),
    );
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _expCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final allServicesAsync = ref.watch(businessServicesProvider);
    final staffId = widget.staff['id'] as String? ?? '';
    final blocksAsync = ref.watch(staffBlocksProvider(staffId));
    final dayNames = ['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom'];

    return Container(
      color: colors.surface,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.outlineVariant))),
            child: Row(
              children: [
                Expanded(child: Text('Editar staff', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
                TextButton(
                  onPressed: () => ref.read(_staffEditModeProvider.notifier).state = false,
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Profile fields ──
                  Row(
                    children: [
                      Expanded(child: TextFormField(controller: _firstNameCtrl, decoration: const InputDecoration(labelText: 'Nombre'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextFormField(controller: _lastNameCtrl, decoration: const InputDecoration(labelText: 'Apellido'))),
                    ],
                  ),
                  const SizedBox(height: BCSpacing.md),
                  TextFormField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Telefono'), keyboardType: TextInputType.phone),
                  const SizedBox(height: BCSpacing.md),
                  TextFormField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: BCSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Rol'),
                          value: _role,
                          items: const [
                            DropdownMenuItem(value: 'estilista', child: Text('Estilista')),
                            DropdownMenuItem(value: 'barbero', child: Text('Barbero')),
                            DropdownMenuItem(value: 'masajista', child: Text('Masajista')),
                            DropdownMenuItem(value: 'manicurista', child: Text('Manicurista')),
                            DropdownMenuItem(value: 'esteticista', child: Text('Esteticista')),
                            DropdownMenuItem(value: 'recepcionista', child: Text('Recepcionista')),
                          ],
                          onChanged: (v) => setState(() => _role = v ?? 'estilista'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 110,
                        child: TextFormField(
                          controller: _expCtrl,
                          decoration: InputDecoration(labelText: 'Exp. (anos)', helperText: _expLabel),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, _MaxValueFormatter(50)],
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: BCSpacing.sm),
                  SwitchListTile(
                    title: const Text('Activo'),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: BCSpacing.md),

                  // ── AI Bio ──
                  AphroditeCopyField(
                    controller: _bioCtrl,
                    label: 'Biografia',
                    hint: 'Escribe o genera una biografia...',
                    fieldType: 'staff_bio',
                    icon: Icons.auto_awesome_outlined,
                    context: {
                      'name': _firstNameCtrl.text,
                      'role': _role,
                      'experience': _expCtrl.text,
                    },
                    autoGenerate: false,
                  ),
                  const SizedBox(height: BCSpacing.lg),

                  // ── Schedule editor ──
                  Text('Horario semanal', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: BCSpacing.sm),
                  if (_schedule != null)
                    for (var i = 0; i < 7; i++) ...[
                      _DayScheduleRow(
                        dayName: dayNames[i],
                        schedule: _schedule![i],
                        onChanged: (s) {
                          setState(() {
                            _schedule![i] = s;
                            _scheduleModified = true;
                          });
                        },
                        onAddBreak: () {
                          setState(() {
                            final smartBreak = _smartAutoLunch(i);
                            _schedule![i] = _schedule![i].copyWith(
                              breaks: [..._schedule![i].breaks, smartBreak],
                            );
                            _scheduleModified = true;
                          });
                        },
                        onRemoveBreak: (bi) {
                          setState(() {
                            final newBreaks = List<_BreakWindow>.from(_schedule![i].breaks)..removeAt(bi);
                            _schedule![i] = _schedule![i].copyWith(breaks: newBreaks);
                            _scheduleModified = true;
                          });
                        },
                        onBreakChanged: (bi, bw) {
                          setState(() {
                            final newBreaks = List<_BreakWindow>.from(_schedule![i].breaks);
                            newBreaks[bi] = bw;
                            _schedule![i] = _schedule![i].copyWith(breaks: newBreaks);
                            _scheduleModified = true;
                          });
                        },
                      ),
                    ],
                  const SizedBox(height: BCSpacing.lg),

                  // ── Time-off blocks ──
                  Row(
                    children: [
                      Text('Tiempo libre', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _showAddTimeOff(context, staffId),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Agregar'),
                      ),
                    ],
                  ),
                  blocksAsync.when(
                    loading: () => const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)),
                    error: (_, __) => const Text('Error'),
                    data: (blocks) {
                      if (blocks.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text('Sin bloques', style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurface.withValues(alpha: 0.5))),
                        );
                      }
                      return Column(
                        children: [
                          for (final b in blocks)
                            _TimeOffEditRow(
                              block: b,
                              onDelete: () async {
                                await BCSupabase.client.from(BCTables.staffScheduleBlocks).delete().eq('id', b['id'] as String);
                                ref.invalidate(staffBlocksProvider(staffId));
                              },
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: BCSpacing.lg),

                  // ── Service assignment ──
                  Row(
                    children: [
                      Text('Servicios asignados', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _showAssignServicesDialog(context, staffId),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Asignar'),
                      ),
                    ],
                  ),
                  allServicesAsync.when(
                    loading: () => const CircularProgressIndicator(strokeWidth: 2),
                    error: (_, __) => const Text('Error'),
                    data: (allServices) {
                      final assigned = allServices.where((s) => _assignedServiceIds.contains(s['id'] as String)).toList();
                      if (assigned.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text('Sin servicios', style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurface.withValues(alpha: 0.5))),
                        );
                      }
                      return Column(
                        children: [
                          for (final svc in assigned)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(svc['name'] as String? ?? '', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
                              subtitle: Text('\$${(svc['price'] as num?)?.toStringAsFixed(0) ?? '0'} · ${svc['duration_minutes']}min', style: theme.textTheme.labelSmall),
                              trailing: IconButton(
                                icon: Icon(Icons.remove_circle_outline, color: colors.error, size: 18),
                                onPressed: () {
                                  setState(() => _assignedServiceIds.remove(svc['id'] as String));
                                },
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: BCSpacing.lg),

                  // ── Save ──
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Guardar cambios'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAssignServicesDialog(BuildContext context, String staffId) async {
    final bizServices = await ref.read(businessServicesProvider.future);
    final currentAssigned = await ref.read(staffServicesProvider(staffId).future);
    final assignedIds = currentAssigned.map((s) => s['service_id'] as String).toSet();
    final available = bizServices.where((s) => !assignedIds.contains(s['id'])).toList();

    if (available.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Todos los servicios ya estan asignados')));
      }
      return;
    }

    final selected = <String>{};
    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Asignar servicios'),
          content: SizedBox(
            width: 400,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final svc in available)
                  CheckboxListTile(
                    dense: true,
                    title: Text(svc['name'] as String? ?? ''),
                    subtitle: Text('\$${(svc['price'] as num?)?.toStringAsFixed(0) ?? '0'} · ${svc['duration_minutes']}min'),
                    value: selected.contains(svc['id'] as String),
                    onChanged: (v) {
                      setDialogState(() {
                        if (v == true) {
                          selected.add(svc['id'] as String);
                        } else {
                          selected.remove(svc['id'] as String);
                        }
                      });
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: selected.isEmpty
                  ? null
                  : () {
                      setState(() => _assignedServiceIds.addAll(selected));
                      Navigator.pop(ctx);
                    },
              child: const Text('Asignar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddTimeOff(BuildContext context, String staffId) async {
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay startTime = const TimeOfDay(hour: 14, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 15, minute: 0);
    String reason = 'day_off';

    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final showTimePickers = reason == 'lunch' || reason == 'other';
          final showDateRange = reason == 'vacation' || reason == 'other';

          return AlertDialog(
            title: const Text('Agregar tiempo libre'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: reason,
                    decoration: const InputDecoration(labelText: 'Razon'),
                    items: const [
                      DropdownMenuItem(value: 'lunch', child: Text('Almuerzo')),
                      DropdownMenuItem(value: 'day_off', child: Text('Dia libre')),
                      DropdownMenuItem(value: 'vacation', child: Text('Vacaciones')),
                      DropdownMenuItem(value: 'other', child: Text('Otro')),
                    ],
                    onChanged: (v) => setDialogState(() => reason = v ?? 'day_off'),
                  ),
                  const SizedBox(height: 12),
                  if (reason != 'lunch')
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () async {
                              final d = await showDatePicker(context: ctx, initialDate: startDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                              if (d != null) setDialogState(() => startDate = d);
                            },
                            child: Text('Desde: ${startDate.day}/${startDate.month}/${startDate.year}'),
                          ),
                        ),
                        if (showDateRange)
                          Expanded(
                            child: TextButton(
                              onPressed: () async {
                                final d = await showDatePicker(context: ctx, initialDate: endDate, firstDate: startDate, lastDate: startDate.add(const Duration(days: 365)));
                                if (d != null) setDialogState(() => endDate = d);
                              },
                              child: Text('Hasta: ${endDate.day}/${endDate.month}/${endDate.year}'),
                            ),
                          ),
                      ],
                    ),
                  if (showTimePickers) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () async {
                              final t = await showTimePicker(context: ctx, initialTime: startTime);
                              if (t != null) {
                                setDialogState(() {
                                  startTime = t;
                                  if (reason == 'lunch') {
                                    endTime = TimeOfDay(hour: t.hour + 1, minute: t.minute);
                                  }
                                });
                              }
                            },
                            child: Text('Hora inicio: ${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')}'),
                          ),
                        ),
                        Expanded(
                          child: TextButton(
                            onPressed: () async {
                              final t = await showTimePicker(context: ctx, initialTime: endTime);
                              if (t != null) setDialogState(() => endTime = t);
                            },
                            child: Text('Hora fin: ${endTime.hour}:${endTime.minute.toString().padLeft(2, '0')}'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  DateTime startsAt;
                  DateTime endsAt;

                  if (reason == 'lunch') {
                    startsAt = DateTime(startDate.year, startDate.month, startDate.day, startTime.hour, startTime.minute);
                    endsAt = DateTime(startDate.year, startDate.month, startDate.day, endTime.hour, endTime.minute);
                  } else if (reason == 'day_off') {
                    startsAt = DateTime(startDate.year, startDate.month, startDate.day, 0, 0);
                    endsAt = DateTime(startDate.year, startDate.month, startDate.day, 23, 59);
                  } else {
                    startsAt = DateTime(startDate.year, startDate.month, startDate.day, startTime.hour, startTime.minute);
                    endsAt = DateTime(endDate.year, endDate.month, endDate.day, endTime.hour, endTime.minute);
                  }

                  try {
                    await BCSupabase.client.from(BCTables.staffScheduleBlocks).insert({
                      'staff_id': staffId,
                      'reason': reason,
                      'starts_at': startsAt.toIso8601String(),
                      'ends_at': endsAt.toIso8601String(),
                    });
                    ref.invalidate(staffBlocksProvider(staffId));
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final staffId = widget.staff['id'] as String;
    try {
      // Update staff record
      await BCSupabase.client.from(BCTables.staff).update({
        'first_name': _firstNameCtrl.text.trim(),
        'last_name': _lastNameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'role': _role,
        'is_active': _isActive,
        'experience_years': int.tryParse(_expCtrl.text.trim()) ?? 0,
        'bio': _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
      }).eq('id', staffId);

      // Upsert schedule (all 7 days)
      if (_schedule != null) {
        final rows = _schedule!.map((day) => {
          'staff_id': staffId,
          'day_of_week': day.dayIndex + 1, // DB uses 1-7
          'is_available': day.isAvailable,
          'start_time': _formatTime(day.startTime),
          'end_time': _formatTime(day.endTime),
          'breaks': day.breaks
              .map((b) => {'start': _formatTime(b.start), 'end': _formatTime(b.end)})
              .toList(),
        }).toList();

        await BCSupabase.client
            .from(BCTables.staffSchedules)
            .upsert(rows, onConflict: 'staff_id,day_of_week');
      }

      // Update service assignments: delete all, re-insert
      await BCSupabase.client.from(BCTables.staffServices).delete().eq('staff_id', staffId);
      if (_assignedServiceIds.isNotEmpty) {
        final serviceRows = _assignedServiceIds.map((svcId) => {
          'staff_id': staffId,
          'service_id': svcId,
        }).toList();
        await BCSupabase.client.from(BCTables.staffServices).insert(serviceRows);
      }

      ref.invalidate(businessStaffProvider);
      ref.invalidate(staffScheduleProvider(staffId));
      ref.invalidate(staffServicesProvider(staffId));
      if (mounted) {
        ref.read(_staffEditModeProvider.notifier).state = false;
        // Update the selected staff in panel
        final updated = await BCSupabase.client.from(BCTables.staff).select().eq('id', staffId).maybeSingle();
        if (updated != null) {
          ref.read(selectedStaffProvider.notifier).state = updated;
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardado')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Day Schedule Model ──────────────────────────────────────────────────────

class _DaySchedule {
  final int dayIndex;
  final bool isAvailable;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final List<_BreakWindow> breaks;

  const _DaySchedule({
    required this.dayIndex,
    required this.isAvailable,
    required this.startTime,
    required this.endTime,
    this.breaks = const [],
  });

  _DaySchedule copyWith({
    bool? isAvailable,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    List<_BreakWindow>? breaks,
  }) =>
      _DaySchedule(
        dayIndex: dayIndex,
        isAvailable: isAvailable ?? this.isAvailable,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        breaks: breaks ?? this.breaks,
      );
}

class _BreakWindow {
  final TimeOfDay start;
  final TimeOfDay end;
  const _BreakWindow({required this.start, required this.end});
}

// ── Day Schedule Row (Edit) ─────────────────────────────────────────────────

class _DayScheduleRow extends StatelessWidget {
  const _DayScheduleRow({
    required this.dayName,
    required this.schedule,
    required this.onChanged,
    required this.onAddBreak,
    required this.onRemoveBreak,
    required this.onBreakChanged,
  });
  final String dayName;
  final _DaySchedule schedule;
  final ValueChanged<_DaySchedule> onChanged;
  final VoidCallback onAddBreak;
  final void Function(int index) onRemoveBreak;
  final void Function(int index, _BreakWindow bw) onBreakChanged;

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.2))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 40,
                child: Text(dayName, style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
              ),
              SizedBox(
                width: 48,
                child: Switch(
                  value: schedule.isAvailable,
                  onChanged: (v) => onChanged(schedule.copyWith(isAvailable: v)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              if (schedule.isAvailable) ...[
                const SizedBox(width: 4),
                _TimeDropdown(
                  value: _fmt(schedule.startTime),
                  onChanged: (v) {
                    final parts = v.split(':');
                    onChanged(schedule.copyWith(startTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]))));
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Text('-', style: theme.textTheme.bodySmall),
                ),
                _TimeDropdown(
                  value: _fmt(schedule.endTime),
                  onChanged: (v) {
                    final parts = v.split(':');
                    onChanged(schedule.copyWith(endTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]))));
                  },
                ),
                const Spacer(),
                Tooltip(
                  message: 'Agregar descanso',
                  child: IconButton(
                    icon: Icon(Icons.free_breakfast_rounded, size: 16, color: colors.onSurface.withValues(alpha: 0.4)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onAddBreak,
                  ),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text('Descanso', style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurface.withValues(alpha: 0.4), fontStyle: FontStyle.italic)),
                ),
            ],
          ),
          // Break rows
          if (schedule.isAvailable)
            for (var bi = 0; bi < schedule.breaks.length; bi++)
              Padding(
                padding: const EdgeInsets.only(left: 88, top: 4),
                child: Row(
                  children: [
                    Icon(Icons.free_breakfast_rounded, size: 12, color: colors.onSurface.withValues(alpha: 0.3)),
                    const SizedBox(width: 4),
                    _TimeDropdown(
                      value: _fmt(schedule.breaks[bi].start),
                      onChanged: (v) {
                        final parts = v.split(':');
                        onBreakChanged(bi, _BreakWindow(
                          start: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
                          end: schedule.breaks[bi].end,
                        ));
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Text('-', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
                    ),
                    _TimeDropdown(
                      value: _fmt(schedule.breaks[bi].end),
                      onChanged: (v) {
                        final parts = v.split(':');
                        onBreakChanged(bi, _BreakWindow(
                          start: schedule.breaks[bi].start,
                          end: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
                        ));
                      },
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => onRemoveBreak(bi),
                      child: Icon(Icons.close, size: 14, color: colors.error),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

// ── Time Off Edit Row ───────────────────────────────────────────────────────

class _TimeOffEditRow extends StatelessWidget {
  const _TimeOffEditRow({required this.block, required this.onDelete});
  final Map<String, dynamic> block;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final reason = block['reason'] as String? ?? 'other';
    final start = DateTime.tryParse(block['starts_at'] as String? ?? '');
    final end = DateTime.tryParse(block['ends_at'] as String? ?? '');

    final (IconData icon, String label) = switch (reason) {
      'lunch' => (Icons.restaurant_rounded, 'Almuerzo'),
      'day_off' => (Icons.event_busy_rounded, 'Dia libre'),
      'vacation' => (Icons.beach_access_rounded, 'Vacaciones'),
      _ => (Icons.block_rounded, 'Bloqueado'),
    };

    String dateStr = '';
    if (start != null && end != null) {
      dateStr = '${start.day}/${start.month} ${start.hour}:${start.minute.toString().padLeft(2, '0')} - '
          '${end.day}/${end.month} ${end.hour}:${end.minute.toString().padLeft(2, '0')}';
    }

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 18, color: colors.onSurface.withValues(alpha: 0.5)),
      title: Text(label, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(dateStr, style: theme.textTheme.labelSmall?.copyWith(fontFamily: 'monospace')),
      trailing: IconButton(
        icon: Icon(Icons.delete_outline, color: colors.error, size: 18),
        onPressed: onDelete,
      ),
    );
  }
}

// ── Time Dropdown ───────────────────────────────────────────────────────────

class _TimeDropdown extends StatelessWidget {
  const _TimeDropdown({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final times = <String>[];
    for (var h = 6; h <= 22; h++) {
      times.add('${h.toString().padLeft(2, '0')}:00');
      times.add('${h.toString().padLeft(2, '0')}:30');
    }

    return DropdownButton<String>(
      value: times.contains(value) ? value : times.first,
      items: [for (final t in times) DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')))],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      underline: const SizedBox.shrink(),
      isDense: true,
    );
  }
}

// ── Weekly Schedule Grid (Read-only) ────────────────────────────────────────

class _WeeklyScheduleGrid extends StatelessWidget {
  const _WeeklyScheduleGrid({required this.schedule});
  final List<Map<String, dynamic>> schedule;

  static const _dayNames = ['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final Map<int, Map<String, dynamic>> byDay = {};
    for (final s in schedule) {
      final dow = s['day_of_week'] as int? ?? 0;
      byDay[dow] = s;
    }

    return Column(
      children: [
        for (var i = 1; i <= 7; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.3))),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(_dayNames[i - 1], style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 12),
                    if (byDay[i] != null && (byDay[i]!['is_available'] as bool? ?? true))
                      Text(
                        '${byDay[i]!['start_time'] ?? '09:00'} - ${byDay[i]!['end_time'] ?? '18:00'}',
                        style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                      )
                    else
                      Text('Descanso', style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurface.withValues(alpha: 0.4), fontStyle: FontStyle.italic)),
                  ],
                ),
                // Show breaks
                if (byDay[i] != null)
                  for (final b in (byDay[i]!['breaks'] as List<dynamic>? ?? []))
                    Padding(
                      padding: const EdgeInsets.only(left: 52, top: 2),
                      child: Row(
                        children: [
                          Icon(Icons.free_breakfast_rounded, size: 12, color: colors.onSurface.withValues(alpha: 0.3)),
                          const SizedBox(width: 4),
                          Text(
                            '${b['start'] ?? ''} - ${b['end'] ?? ''}',
                            style: theme.textTheme.labelSmall?.copyWith(fontFamily: 'monospace', color: colors.onSurface.withValues(alpha: 0.5)),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Assigned Service Row ────────────────────────────────────────────────────

class _AssignedServiceRow extends StatelessWidget {
  const _AssignedServiceRow({required this.staffService});
  final Map<String, dynamic> staffService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final svc = staffService['services'] as Map<String, dynamic>? ?? {};
    final name = svc['name'] as String? ?? 'Servicio';
    final price = (svc['price'] as num?)?.toDouble() ?? 0;
    final duration = (svc['duration_minutes'] as num?)?.toInt() ?? 0;
    final overridePrice = staffService['override_price'] as num? ?? staffService['custom_price'] as num?;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
                Text('${duration}min', style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurface.withValues(alpha: 0.4))),
              ],
            ),
          ),
          if (overridePrice != null)
            Text('\$${overridePrice.toStringAsFixed(0)}', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: colors.primary))
          else
            Text('\$${price.toStringAsFixed(0)}', style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurface.withValues(alpha: 0.5))),
        ],
      ),
    );
  }
}

// ── MaxValueFormatter ───────────────────────────────────────────────────────

class _MaxValueFormatter extends TextInputFormatter {
  final int max;
  _MaxValueFormatter(this.max);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final val = int.tryParse(newValue.text);
    if (val == null || val > max) return oldValue;
    return newValue;
  }
}
