import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import '../../config/constants.dart';
import '../../providers/business_provider.dart';
import '../../services/supabase_client.dart';

class BusinessStaffScreen extends ConsumerWidget {
  const BusinessStaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(businessStaffProvider);
    final colors = Theme.of(context).colorScheme;

    return staffAsync.when(
      data: (staff) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddStaffForm(context, ref),
            child: const Icon(Icons.person_add_rounded),
          ),
          body: staff.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline_rounded,
                          size: 48,
                          color: colors.onSurface.withValues(alpha: 0.3)),
                      const SizedBox(height: AppConstants.paddingSM),
                      Text(
                        'No hay miembros del equipo',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: colors.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: AppConstants.paddingMD),
                      ElevatedButton.icon(
                        onPressed: () => _showAddStaffForm(context, ref),
                        icon: const Icon(Icons.person_add),
                        label: const Text('Agregar'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(businessStaffProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppConstants.paddingMD),
                    itemCount: staff.length + 1,
                    itemBuilder: (context, index) {
                      if (index == staff.length) {
                        return const SizedBox(height: 80);
                      }
                      return _StaffCard(
                        staff: staff[index],
                        onTap: () =>
                            _showStaffDetail(context, ref, staff[index]),
                        onToggle: () =>
                            _toggleActive(context, ref, staff[index]),
                      );
                    },
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
      BuildContext context, WidgetRef ref, Map<String, dynamic> staff) async {
    final id = staff['id'] as String;
    final current = staff['is_active'] as bool? ?? true;
    try {
      await SupabaseClientService.client
          .from('staff')
          .update({'is_active': !current}).eq('id', id);
      ref.invalidate(businessStaffProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showAddStaffForm(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddStaffSheet(
          onSaved: () => ref.invalidate(businessStaffProvider)),
    );
  }

  void _showStaffDetail(
      BuildContext context, WidgetRef ref, Map<String, dynamic> staff) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _StaffDetailSheet(staff: staff),
    );
  }
}

// ---------------------------------------------------------------------------
// Staff card
// ---------------------------------------------------------------------------

class _StaffCard extends StatelessWidget {
  final Map<String, dynamic> staff;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  const _StaffCard({
    required this.staff,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final firstName = staff['first_name'] as String? ?? '';
    final lastName = staff['last_name'] as String? ?? '';
    final name = '$firstName $lastName'.trim();
    final rating = (staff['average_rating'] as num?)?.toDouble() ?? 0;
    final reviews = staff['total_reviews'] as int? ?? 0;
    final isActive = staff['is_active'] as bool? ?? true;
    final experience = staff['experience_years'] as int? ?? 0;
    final avatarUrl = staff['avatar_url'] as String?;

    String expLabel;
    if (experience == 0) {
      expLabel = 'Principiante';
    } else if (experience == 1) {
      expLabel = '1 ano exp.';
    } else {
      expLabel = '${experience}a exp.';
    }

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
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: isActive
              ? colors.primary.withValues(alpha: 0.1)
              : colors.onSurface.withValues(alpha: 0.05),
          backgroundImage:
              avatarUrl != null && avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
          child: avatarUrl == null || avatarUrl.isEmpty
              ? Text(
                  firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    color: isActive
                        ? colors.primary
                        : colors.onSurface.withValues(alpha: 0.3),
                  ),
                )
              : null,
        ),
        title: Text(
          name.isNotEmpty ? name : 'Sin nombre',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isActive
                ? colors.onSurface
                : colors.onSurface.withValues(alpha: 0.4),
          ),
        ),
        subtitle: Row(
          children: [
            if (rating > 0) ...[
              const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
              const SizedBox(width: 2),
              Text(
                '${rating.toStringAsFixed(1)} ($reviews)',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              expLabel,
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        trailing: Switch(
          value: isActive,
          onChanged: (_) => onToggle(),
          activeTrackColor: colors.primary,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add staff bottom sheet
// ---------------------------------------------------------------------------

class _AddStaffSheet extends ConsumerStatefulWidget {
  final VoidCallback onSaved;
  const _AddStaffSheet({required this.onSaved});

  @override
  ConsumerState<_AddStaffSheet> createState() => _AddStaffSheetState();
}

class _AddStaffSheetState extends ConsumerState<_AddStaffSheet> {
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _expCtrl = TextEditingController(text: '0');
  final _bioCtrl = TextEditingController();
  bool _saving = false;
  File? _avatarFile;
  final List<File> _portfolioFiles = [];
  final _picker = ImagePicker();

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _phoneCtrl.dispose();
    _expCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  String get _expDisplayLabel {
    final v = int.tryParse(_expCtrl.text) ?? 0;
    if (v == 0) return 'Principiante';
    if (v == 1) return '1 ano';
    return '$v anos';
  }

  Future<void> _pickAvatar() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _avatarFile = File(picked.path));
    }
  }

  Future<void> _pickPortfolioImages() async {
    final picked = await _picker.pickMultiImage(
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (picked.isNotEmpty) {
      setState(() {
        _portfolioFiles.addAll(picked.map((x) => File(x.path)));
      });
    }
  }

  Future<String?> _uploadFile(File file, String path) async {
    final bytes = await file.readAsBytes();
    await SupabaseClientService.client.storage
        .from('staff-media')
        .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));
    final publicUrl = SupabaseClientService.client.storage
        .from('staff-media')
        .getPublicUrl(path);
    return publicUrl;
  }

  InputDecoration _styledInput(
    String label, {
    Widget? prefixIcon,
    bool isDense = false,
    bool alignLabelWithHint = false,
    String? hintText,
  }) {
    final colors = Theme.of(context).colorScheme;
    final gray = colors.onSurface.withValues(alpha: 0.12);
    return InputDecoration(
      labelText: label,
      prefixIcon: prefixIcon,
      isDense: isDense,
      alignLabelWithHint: alignLabelWithHint,
      hintText: hintText,
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

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
              AppConstants.paddingLG,
              AppConstants.paddingLG,
              AppConstants.paddingLG,
              MediaQuery.of(context).viewInsets.bottom + AppConstants.paddingLG,
            ),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin:
                      const EdgeInsets.only(bottom: AppConstants.paddingMD),
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Agregar Miembro',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: AppConstants.paddingMD),

              // Avatar picker
              Center(
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor:
                            colors.primary.withValues(alpha: 0.1),
                        backgroundImage: _avatarFile != null
                            ? FileImage(_avatarFile!)
                            : null,
                        child: _avatarFile == null
                            ? Icon(Icons.person_rounded,
                                size: 40,
                                color: colors.primary
                                    .withValues(alpha: 0.4))
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Foto de perfil',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: colors.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),

              const SizedBox(height: AppConstants.paddingMD),

              // Name fields
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _firstCtrl,
                      decoration: _styledInput('Nombre', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _lastCtrl,
                      decoration: _styledInput('Apellido', isDense: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.paddingSM),

              // Phone
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: _styledInput('Telefono',
                    prefixIcon: const Icon(Icons.phone_rounded, size: 20)),
              ),
              const SizedBox(height: AppConstants.paddingSM),

              // Experience (number only, 0-50)
              Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _expCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        _MaxValueFormatter(50),
                      ],
                      onChanged: (_) => setState(() {}),
                      decoration: _styledInput('Exp. (anos)', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _expDisplayLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.paddingSM),

              // Bio / autobiography
              TextField(
                controller: _bioCtrl,
                maxLines: 3,
                maxLength: 500,
                decoration: _styledInput('Autobiografia',
                    alignLabelWithHint: true,
                    hintText:
                        'Cuenta un poco sobre ti, tu experiencia y estilo...'),
              ),

              const SizedBox(height: AppConstants.paddingMD),

              // Portfolio images
              Text(
                'PORTAFOLIO',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: colors.onSurface.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 90,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    // Existing portfolio thumbnails
                    for (var i = 0; i < _portfolioFiles.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                _portfolioFiles[i],
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () {
                                  setState(
                                      () => _portfolioFiles.removeAt(i));
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close,
                                      size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Add button
                    GestureDetector(
                      onTap: _pickPortfolioImages,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: colors.onSurface.withValues(alpha: 0.12),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_rounded,
                                size: 28,
                                color: colors.onSurface
                                    .withValues(alpha: 0.3)),
                            const SizedBox(height: 4),
                            Text(
                              'Agregar',
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                color: colors.onSurface
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                    : const Text('Agregar'),
              ),
              const SizedBox(height: AppConstants.paddingMD),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    final first = _firstCtrl.text.trim();
    if (first.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre es requerido')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final biz = await ref.read(currentBusinessProvider.future);
      if (biz == null) throw Exception('No business found');

      final bizId = biz['id'] as String;
      final staffId = DateTime.now().millisecondsSinceEpoch.toString();

      // Upload avatar if selected
      String? avatarUrl;
      if (_avatarFile != null) {
        avatarUrl = await _uploadFile(
          _avatarFile!,
          '$bizId/avatars/$staffId.jpg',
        );
      }

      // Upload portfolio images
      final portfolioUrls = <String>[];
      for (var i = 0; i < _portfolioFiles.length; i++) {
        final url = await _uploadFile(
          _portfolioFiles[i],
          '$bizId/portfolio/${staffId}_$i.jpg',
        );
        if (url != null) portfolioUrls.add(url);
      }

      await SupabaseClientService.client.from('staff').insert({
        'business_id': bizId,
        'first_name': first,
        'last_name': _lastCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty
            ? null
            : _phoneCtrl.text.trim(),
        'experience_years': int.tryParse(_expCtrl.text.trim()) ?? 0,
        'bio': _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
        'avatar_url': avatarUrl,
        'portfolio_urls': portfolioUrls,
        'is_active': true,
      });

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

// Formatter that limits numeric input to a max value
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

// ---------------------------------------------------------------------------
// Staff detail sheet (editable schedule, services, time-off)
// ---------------------------------------------------------------------------

class _StaffDetailSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> staff;
  const _StaffDetailSheet({required this.staff});

  @override
  ConsumerState<_StaffDetailSheet> createState() => _StaffDetailSheetState();
}

class _StaffDetailSheetState extends ConsumerState<_StaffDetailSheet> {
  static const _dayNames = ['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom'];

  // Local schedule state: list of 7 days
  List<_DaySchedule>? _schedule;
  bool _scheduleModified = false;
  bool _savingSchedule = false;

  String get _expLabel {
    final v = int.tryParse(_expCtrl.text) ?? 0;
    if (v == 0) return 'Principiante';
    if (v == 1) return '1 ano';
    return '$v anos';
  }

  // Profile editing
  late final TextEditingController _firstCtrl;
  late final TextEditingController _lastCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _expCtrl;
  bool _savingProfile = false;

  @override
  void initState() {
    super.initState();
    _firstCtrl = TextEditingController(
        text: widget.staff['first_name'] as String? ?? '');
    _lastCtrl = TextEditingController(
        text: widget.staff['last_name'] as String? ?? '');
    _phoneCtrl =
        TextEditingController(text: widget.staff['phone'] as String? ?? '');
    _expCtrl = TextEditingController(
        text: (widget.staff['experience_years'] as int?)?.toString() ?? '0');
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _phoneCtrl.dispose();
    _expCtrl.dispose();
    super.dispose();
  }

  void _initScheduleFromData(List<Map<String, dynamic>> data) {
    if (_schedule != null) return;
    _schedule = List.generate(7, (day) {
      final match = data.where((s) => s['day_of_week'] == day).toList();
      if (match.isNotEmpty) {
        final s = match.first;
        return _DaySchedule(
          id: s['id'] as String?,
          dayOfWeek: day,
          isAvailable: s['is_available'] as bool? ?? false,
          startTime: _parseTime(s['start_time'] as String?),
          endTime: _parseTime(s['end_time'] as String?),
        );
      }
      return _DaySchedule(
        dayOfWeek: day,
        isAvailable: false,
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 18, minute: 0),
      );
    });
  }

  TimeOfDay _parseTime(String? s) {
    if (s == null) return const TimeOfDay(hour: 9, minute: 0);
    final parts = s.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final staffId = widget.staff['id'] as String;
    final firstName = widget.staff['first_name'] as String? ?? '';
    final lastName = widget.staff['last_name'] as String? ?? '';
    final name = '$firstName $lastName'.trim();

    final scheduleAsync = ref.watch(staffScheduleProvider(staffId));
    final servicesAsync = ref.watch(staffServicesProvider(staffId));
    final blocksAsync = ref.watch(staffBlocksProvider(staffId));

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(AppConstants.paddingLG),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin:
                      const EdgeInsets.only(bottom: AppConstants.paddingMD),
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ---------- Profile section ----------
              Text(
                name,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: AppConstants.paddingSM),
              _buildProfileSection(context, staffId),

              const SizedBox(height: AppConstants.paddingLG),

              // ---------- Schedule section ----------
              _sectionHeader('HORARIO SEMANAL'),
              const SizedBox(height: AppConstants.paddingSM),
              scheduleAsync.when(
                data: (data) {
                  _initScheduleFromData(data);
                  return _buildScheduleEditor(context, staffId);
                },
                loading: () => const Center(
                    child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                )),
                error: (e, _) => Text('Error: $e'),
              ),

              const SizedBox(height: AppConstants.paddingLG),

              // ---------- Assigned services ----------
              _sectionHeader('SERVICIOS ASIGNADOS'),
              const SizedBox(height: AppConstants.paddingSM),
              servicesAsync.when(
                data: (services) =>
                    _buildServicesSection(context, ref, staffId, services),
                loading: () => const Center(
                    child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                )),
                error: (e, _) => Text('Error: $e'),
              ),

              const SizedBox(height: AppConstants.paddingLG),

              // ---------- Time off ----------
              _sectionHeader('TIEMPO LIBRE'),
              const SizedBox(height: AppConstants.paddingSM),
              blocksAsync.when(
                data: (blocks) =>
                    _buildTimeOffSection(context, ref, staffId, blocks),
                loading: () => const Center(
                    child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                )),
                error: (e, _) => Text('Error: $e'),
              ),

              const SizedBox(height: AppConstants.paddingLG),

              // ---------- Performance ----------
              _sectionHeader('RENDIMIENTO'),
              const SizedBox(height: AppConstants.paddingSM),
              _buildPerformance(context),

              const SizedBox(height: AppConstants.paddingXL),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String label) {
    final colors = Theme.of(context).colorScheme;
    return Text(
      label,
      style: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: colors.onSurface.withValues(alpha: 0.4),
      ),
    );
  }

  // ---- Profile ----

  Widget _buildProfileSection(BuildContext context, String staffId) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        side: BorderSide(color: colors.onSurface.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _firstCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Nombre', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _lastCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Apellido', isDense: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Telefono', isDense: true),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _expCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _MaxValueFormatter(50),
                    ],
                    decoration: const InputDecoration(
                        labelText: 'Exp. (anos)', isDense: true),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _expLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _savingProfile ? null : () => _saveProfile(staffId),
              child: _savingProfile
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Guardar Perfil'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile(String staffId) async {
    setState(() => _savingProfile = true);
    try {
      await SupabaseClientService.client.from('staff').update({
        'first_name': _firstCtrl.text.trim(),
        'last_name': _lastCtrl.text.trim(),
        'phone':
            _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'experience_years': int.tryParse(_expCtrl.text.trim()) ?? 0,
      }).eq('id', staffId);
      ref.invalidate(businessStaffProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  // ---- Schedule editor ----

  Widget _buildScheduleEditor(BuildContext context, String staffId) {
    final colors = Theme.of(context).colorScheme;
    if (_schedule == null) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        side: BorderSide(color: colors.onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < 7; i++) ...[
            if (i > 0) const Divider(height: 1),
            _buildDayRow(context, i),
          ],
          if (_scheduleModified) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton(
                onPressed:
                    _savingSchedule ? null : () => _saveSchedule(staffId),
                child: _savingSchedule
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Guardar Horario'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDayRow(BuildContext context, int dayIndex) {
    final colors = Theme.of(context).colorScheme;
    final day = _schedule![dayIndex];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              _dayNames[dayIndex],
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: day.isAvailable
                    ? colors.onSurface
                    : colors.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Switch(
              value: day.isAvailable,
              onChanged: (v) {
                setState(() {
                  _schedule![dayIndex] = day.copyWith(isAvailable: v);
                  _scheduleModified = true;
                });
              },
              activeTrackColor: colors.primary,
            ),
          ),
          if (day.isAvailable) ...[
            _timeTap(
              context,
              day.startTime,
              (t) {
                setState(() {
                  _schedule![dayIndex] = day.copyWith(startTime: t);
                  _scheduleModified = true;
                });
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('-',
                  style: GoogleFonts.nunito(
                      color: colors.onSurface.withValues(alpha: 0.4))),
            ),
            _timeTap(
              context,
              day.endTime,
              (t) {
                setState(() {
                  _schedule![dayIndex] = day.copyWith(endTime: t);
                  _scheduleModified = true;
                });
              },
            ),
          ] else
            Text(
              'No disponible',
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.3),
              ),
            ),
        ],
      ),
    );
  }

  Widget _timeTap(
      BuildContext context, TimeOfDay time, ValueChanged<TimeOfDay> onPicked) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked != null) onPicked(picked);
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          _formatTime(time),
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.primary,
          ),
        ),
      ),
    );
  }

  Future<void> _saveSchedule(String staffId) async {
    if (_schedule == null) return;
    setState(() => _savingSchedule = true);

    try {
      // Upsert all 7 days (unique on staff_id + day_of_week)
      final rows = _schedule!.map((day) => {
        'staff_id': staffId,
        'day_of_week': day.dayOfWeek,
        'is_available': day.isAvailable,
        'start_time': _formatTime(day.startTime),
        'end_time': _formatTime(day.endTime),
      }).toList();

      await SupabaseClientService.client
          .from('staff_schedules')
          .upsert(rows, onConflict: 'staff_id,day_of_week');

      // Keep _schedule as-is (it has correct values the user set)
      // Just clear the modified flag
      _scheduleModified = false;
      // Invalidate provider so next open gets fresh IDs
      ref.invalidate(staffScheduleProvider(staffId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Horario guardado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingSchedule = false);
    }
  }

  // ---- Assigned services ----

  Widget _buildServicesSection(BuildContext context, WidgetRef ref,
      String staffId, List<Map<String, dynamic>> assignedRaw) {
    final colors = Theme.of(context).colorScheme;
    final assigned = assignedRaw;

    return Card(
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        side: BorderSide(color: colors.onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          if (assigned.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppConstants.paddingMD),
              child: Text(
                'Sin servicios asignados',
                style: GoogleFonts.nunito(
                    color: colors.onSurface.withValues(alpha: 0.5)),
              ),
            )
          else
            for (final s in assigned)
              ListTile(
                dense: true,
                title: Text(
                  (s['services'] as Map?)?['name'] as String? ?? 'Servicio',
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: s['custom_price'] != null
                    ? Text(
                        'Precio custom: \$${(s['custom_price'] as num).toStringAsFixed(0)}',
                        style: GoogleFonts.nunito(fontSize: 12))
                    : null,
                trailing: IconButton(
                  icon: Icon(Icons.remove_circle_outline,
                      color: colors.error, size: 20),
                  onPressed: () async {
                    try {
                      await SupabaseClientService.client
                          .from('staff_services')
                          .delete()
                          .eq('id', s['id'] as String);
                      ref.invalidate(staffServicesProvider(staffId));
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                ),
              ),
          const Divider(height: 1),
          TextButton.icon(
            onPressed: () => _showAssignServicesDialog(context, ref, staffId),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Asignar Servicios'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAssignServicesDialog(
      BuildContext context, WidgetRef ref, String staffId) async {
    final bizServices = await ref.read(businessServicesProvider.future);
    final assigned = await ref.read(staffServicesProvider(staffId).future);
    final assignedIds =
        assigned.map((s) => s['service_id'] as String).toSet();

    final available =
        bizServices.where((s) => !assignedIds.contains(s['id'])).toList();

    if (available.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Todos los servicios ya estan asignados')),
        );
      }
      return;
    }

    final selected = <String>{};

    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text('Asignar Servicios',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: available.map((svc) {
                    final id = svc['id'] as String;
                    final name = svc['name'] as String? ?? '';
                    return CheckboxListTile(
                      dense: true,
                      title: Text(name,
                          style: GoogleFonts.nunito(fontSize: 14)),
                      value: selected.contains(id),
                      onChanged: (v) {
                        setDialogState(() {
                          if (v == true) {
                            selected.add(id);
                          } else {
                            selected.remove(id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () async {
                          for (final svcId in selected) {
                            await SupabaseClientService.client
                                .from('staff_services')
                                .insert({
                              'staff_id': staffId,
                              'service_id': svcId,
                            });
                          }
                          ref.invalidate(staffServicesProvider(staffId));
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                  child: const Text('Asignar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---- Time off ----

  Widget _buildTimeOffSection(BuildContext context, WidgetRef ref,
      String staffId, List<Map<String, dynamic>> blocks) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        side: BorderSide(color: colors.onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          if (blocks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppConstants.paddingMD),
              child: Text(
                'Sin tiempo libre programado',
                style: GoogleFonts.nunito(
                    color: colors.onSurface.withValues(alpha: 0.5)),
              ),
            )
          else
            for (final b in blocks) ...[
              ListTile(
                dense: true,
                leading: Icon(
                  _blockIcon(b['reason'] as String?),
                  size: 20,
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
                title: Text(
                  _blockLabel(b['reason'] as String?),
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  _blockDateRange(b),
                  style: GoogleFonts.nunito(fontSize: 12),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: colors.error, size: 20),
                  onPressed: () async {
                    try {
                      await SupabaseClientService.client
                          .from('staff_schedule_blocks')
                          .delete()
                          .eq('id', b['id'] as String);
                      ref.invalidate(staffBlocksProvider(staffId));
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          const Divider(height: 1),
          TextButton.icon(
            onPressed: () =>
                _showAddTimeOff(context, ref, staffId),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Agregar Tiempo Libre'),
          ),
        ],
      ),
    );
  }

  IconData _blockIcon(String? reason) {
    switch (reason) {
      case 'lunch':
        return Icons.restaurant_rounded;
      case 'day_off':
        return Icons.event_busy_rounded;
      case 'vacation':
        return Icons.beach_access_rounded;
      default:
        return Icons.block_rounded;
    }
  }

  String _blockLabel(String? reason) {
    switch (reason) {
      case 'lunch':
        return 'Almuerzo';
      case 'day_off':
        return 'Dia libre';
      case 'vacation':
        return 'Vacaciones';
      default:
        return 'Bloqueado';
    }
  }

  String _blockDateRange(Map<String, dynamic> b) {
    final start = DateTime.tryParse(b['starts_at'] as String? ?? '');
    final end = DateTime.tryParse(b['ends_at'] as String? ?? '');
    if (start == null || end == null) return '';
    return '${start.day}/${start.month} ${start.hour}:${start.minute.toString().padLeft(2, '0')} - '
        '${end.day}/${end.month} ${end.hour}:${end.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showAddTimeOff(
      BuildContext context, WidgetRef ref, String staffId) async {
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 18, minute: 0);
    String reason = 'day_off';

    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppConstants.paddingLG,
                AppConstants.paddingLG,
                AppConstants.paddingLG,
                MediaQuery.of(ctx).viewInsets.bottom + AppConstants.paddingLG,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Agregar Tiempo Libre',
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: reason,
                      decoration:
                          const InputDecoration(labelText: 'Razon'),
                      items: const [
                        DropdownMenuItem(
                            value: 'lunch', child: Text('Almuerzo')),
                        DropdownMenuItem(
                            value: 'day_off', child: Text('Dia libre')),
                        DropdownMenuItem(
                            value: 'vacation', child: Text('Vacaciones')),
                        DropdownMenuItem(
                            value: 'other', child: Text('Otro')),
                      ],
                      onChanged: (v) =>
                          setSheetState(() => reason = v ?? 'day_off'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _dateTile(ctx, 'Inicio', startDate, (d) {
                            setSheetState(() => startDate = d);
                          }),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _dateTile(ctx, 'Fin', endDate, (d) {
                            setSheetState(() => endDate = d);
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _timeTile(ctx, 'Hora inicio', startTime,
                              (t) {
                            setSheetState(() => startTime = t);
                          }),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _timeTile(ctx, 'Hora fin', endTime, (t) {
                            setSheetState(() => endTime = t);
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        final biz =
                            await ref.read(currentBusinessProvider.future);
                        if (biz == null) return;
                        final startsAt = DateTime(
                          startDate.year,
                          startDate.month,
                          startDate.day,
                          startTime.hour,
                          startTime.minute,
                        );
                        final endsAt = DateTime(
                          endDate.year,
                          endDate.month,
                          endDate.day,
                          endTime.hour,
                          endTime.minute,
                        );
                        await SupabaseClientService.client
                            .from('staff_schedule_blocks')
                            .insert({
                          'business_id': biz['id'],
                          'staff_id': staffId,
                          'starts_at': startsAt.toIso8601String(),
                          'ends_at': endsAt.toIso8601String(),
                          'reason': reason,
                        });
                        ref.invalidate(staffBlocksProvider(staffId));
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Guardar'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _dateTile(BuildContext context, String label, DateTime value,
      ValueChanged<DateTime> onPicked) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime.now().subtract(const Duration(days: 1)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) onPicked(picked);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
              color: colors.onSurface.withValues(alpha: 0.15)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: colors.onSurface.withValues(alpha: 0.5))),
            Text('${value.day}/${value.month}/${value.year}',
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _timeTile(BuildContext context, String label, TimeOfDay value,
      ValueChanged<TimeOfDay> onPicked) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: value,
        );
        if (picked != null) onPicked(picked);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
              color: colors.onSurface.withValues(alpha: 0.15)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: colors.onSurface.withValues(alpha: 0.5))),
            Text(_formatTime(value),
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ---- Performance ----

  Widget _buildPerformance(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final rating =
        (widget.staff['average_rating'] as num?)?.toDouble() ?? 0;
    final reviews = widget.staff['total_reviews'] as int? ?? 0;

    return Card(
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        side: BorderSide(color: colors.onSurface.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        child: Row(
          children: [
            _statBubble(context, Icons.star_rounded, Colors.amber,
                rating.toStringAsFixed(1), 'Rating'),
            const SizedBox(width: 16),
            _statBubble(context, Icons.rate_review_rounded, colors.primary,
                reviews.toString(), 'Resenas'),
          ],
        ),
      ),
    );
  }

  Widget _statBubble(BuildContext context, IconData icon, Color color,
      String value, String label) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w700)),
        Text(label,
            style: GoogleFonts.nunito(
                fontSize: 11,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5))),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Day schedule model
// ---------------------------------------------------------------------------

class _DaySchedule {
  final String? id;
  final int dayOfWeek;
  final bool isAvailable;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  const _DaySchedule({
    this.id,
    required this.dayOfWeek,
    required this.isAvailable,
    required this.startTime,
    required this.endTime,
  });

  _DaySchedule copyWith({
    bool? isAvailable,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
  }) {
    return _DaySchedule(
      id: id,
      dayOfWeek: dayOfWeek,
      isAvailable: isAvailable ?? this.isAvailable,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}
