import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita/config/fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/constants.dart';
import '../../providers/business_provider.dart';
import 'package:beautycita_core/supabase.dart';
import '../../services/supabase_client.dart';
import '../../services/toast_service.dart';
import '../../widgets/bc_image_editor.dart';

class PortfolioCaptureScreen extends ConsumerStatefulWidget {
  final String? staffId;
  final String? appointmentId;

  const PortfolioCaptureScreen({
    super.key,
    this.staffId,
    this.appointmentId,
  });

  @override
  ConsumerState<PortfolioCaptureScreen> createState() =>
      _PortfolioCaptureScreenState();
}

class _PortfolioCaptureScreenState
    extends ConsumerState<PortfolioCaptureScreen> {
  final _picker = ImagePicker();
  final _captionController = TextEditingController();

  File? _beforePhoto;
  File? _afterPhoto;
  bool _beforeSkipped = false;
  bool _saving = false;

  String? _selectedCategory;
  String? _selectedStaffId;
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _staffList = [];
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _selectedStaffId = widget.staffId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final biz = ref.read(currentBusinessProvider).value;
    if (biz == null) return;
    final businessId = biz['id'] as String;
    final userId = SupabaseClientService.currentUserId;
    final ownerId = biz['owner_id'] as String?;

    setState(() {
      _isOwner = userId != null && userId == ownerId;
    });

    try {
      final servicesRes = await SupabaseClientService.client
          .from(BCTables.services)
          .select('id, name, category')
          .eq('business_id', businessId)
          .eq('is_active', true)
          .order('name');
      final staffRes = await SupabaseClientService.client
          .from(BCTables.staff)
          .select('id, first_name, last_name, user_id')
          .eq('business_id', businessId)
          .eq('is_active', true)
          .order('first_name');

      if (!mounted) return;
      setState(() {
        _services = List<Map<String, dynamic>>.from(servicesRes);
        _staffList = List<Map<String, dynamic>>.from(staffRes);
      });
    } catch (e) {
      if (mounted) {
        ToastService.showError('Error cargando datos: $e');
      }
    }
  }

  Future<void> _takePhoto({required bool isBefore}) async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (picked == null || !mounted) return;

      // Get salon name for watermark
      final biz = ref.read(currentBusinessProvider).value;
      final salonName = biz?['name'] as String? ?? 'BeautyCita';

      final edited = await editImage(
        context,
        imageFile: File(picked.path),
        watermarkText: salonName,
        showWatermarkOption: true,
      );
      if (edited == null || !mounted) return;

      setState(() {
        if (isBefore) {
          _beforePhoto = edited;
          _beforeSkipped = false;
        } else {
          _afterPhoto = edited;
        }
      });
    } catch (e) {
      if (mounted) ToastService.showError('Error al abrir la camara');
    }
  }

  void _skipBefore() {
    setState(() {
      _beforePhoto = null;
      _beforeSkipped = true;
    });
  }

  void _removePhoto({required bool isBefore}) {
    setState(() {
      if (isBefore) {
        _beforePhoto = null;
        _beforeSkipped = false;
      } else {
        _afterPhoto = null;
      }
    });
  }

  bool get _canSave =>
      !_saving && (_beforePhoto != null || _afterPhoto != null);

  Future<void> _save() async {
    if (!_canSave) return;
    final biz = ref.read(currentBusinessProvider).value;
    if (biz == null) return;
    final businessId = biz['id'] as String;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    setState(() => _saving = true);

    try {
      String? beforeUrl;
      String? afterUrl;

      if (_beforePhoto != null) {
        final path = '$businessId/portfolio/${timestamp}_before.jpg';
        await SupabaseClientService.client.storage
            .from('staff-media')
            .upload(path, _beforePhoto!);
        beforeUrl = SupabaseClientService.client.storage
            .from('staff-media')
            .getPublicUrl(path);
      }

      if (_afterPhoto != null) {
        final path = '$businessId/portfolio/${timestamp}_after.jpg';
        await SupabaseClientService.client.storage
            .from('staff-media')
            .upload(path, _afterPhoto!);
        afterUrl = SupabaseClientService.client.storage
            .from('staff-media')
            .getPublicUrl(path);
      }

      await SupabaseClientService.client.from(BCTables.portfolioPhotos).insert({
        'business_id': businessId,
        'staff_id': _selectedStaffId,
        'before_url': beforeUrl,
        'after_url': afterUrl,
        'caption': _captionController.text.trim().isEmpty
            ? null
            : _captionController.text.trim(),
        'service_category': _selectedCategory,
      });

      if (!mounted) return;
      ToastService.showSuccess('Foto guardada en portafolio');
      context.pop();
    } catch (e) {
      if (mounted) {
        ToastService.showError('Error al guardar: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Portafolio — Nueva Foto',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.paddingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Photo slots
              if (isLandscape)
                Row(
                  children: [
                    Expanded(
                        child: _PhotoSlot(
                      label: 'ANTES',
                      photo: _beforePhoto,
                      skipped: _beforeSkipped,
                      onTake: () => _takePhoto(isBefore: true),
                      onRemove: () => _removePhoto(isBefore: true),
                      onSkip: _skipBefore,
                    )),
                    const SizedBox(width: AppConstants.paddingMD),
                    Expanded(
                        child: _PhotoSlot(
                      label: 'DESPUÉS',
                      photo: _afterPhoto,
                      skipped: false,
                      onTake: () => _takePhoto(isBefore: false),
                      onRemove: () => _removePhoto(isBefore: false),
                    )),
                  ],
                )
              else
                Column(
                  children: [
                    _PhotoSlot(
                      label: 'ANTES',
                      photo: _beforePhoto,
                      skipped: _beforeSkipped,
                      onTake: () => _takePhoto(isBefore: true),
                      onRemove: () => _removePhoto(isBefore: true),
                      onSkip: _skipBefore,
                    ),
                    const SizedBox(height: AppConstants.paddingMD),
                    _PhotoSlot(
                      label: 'DESPUÉS',
                      photo: _afterPhoto,
                      skipped: false,
                      onTake: () => _takePhoto(isBefore: false),
                      onRemove: () => _removePhoto(isBefore: false),
                    ),
                  ],
                ),

              const SizedBox(height: AppConstants.paddingLG),

              // Caption
              TextField(
                controller: _captionController,
                maxLength: 200,
                style: GoogleFonts.nunito(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Descripción (opcional)',
                  labelStyle: GoogleFonts.nunito(fontSize: 14),
                  hintText: 'Ej: Balayage rubio cenizo',
                  hintStyle: GoogleFonts.nunito(
                      fontSize: 14, color: colors.onSurface.withValues(alpha: 0.4)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),

              const SizedBox(height: AppConstants.paddingMD),

              // Service category dropdown
              if (_services.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Categoría de servicio',
                    labelStyle: GoogleFonts.nunito(fontSize: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  style: GoogleFonts.nunito(
                      fontSize: 14, color: colors.onSurface),
                  items: _services
                      .map((s) => s['category'] as String?)
                      .whereType<String>()
                      .toSet()
                      .map((cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(cat),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v),
                ),

              if (_isOwner && _staffList.isNotEmpty) ...[
                const SizedBox(height: AppConstants.paddingMD),
                DropdownButtonFormField<String>(
                  initialValue: _selectedStaffId,
                  decoration: InputDecoration(
                    labelText: 'Estilista',
                    labelStyle: GoogleFonts.nunito(fontSize: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  style: GoogleFonts.nunito(
                      fontSize: 14, color: colors.onSurface),
                  items: _staffList
                      .map((s) => DropdownMenuItem(
                            value: s['id'] as String,
                            child:
                                Text('${s['first_name'] ?? ''} ${s['last_name'] ?? ''}'.trim().isEmpty ? 'Staff' : '${s['first_name'] ?? ''} ${s['last_name'] ?? ''}'.trim()),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedStaffId = v),
                ),
              ],

              const SizedBox(height: AppConstants.paddingLG),

              // Save button
              SizedBox(
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: _canSave
                        ? const LinearGradient(colors: [
                            Color(0xFFEC4899),
                            Color(0xFF9333EA),
                            Color(0xFF3B82F6),
                          ])
                        : null,
                    color: _canSave ? null : colors.onSurface.withValues(alpha: 0.12),
                  ),
                  child: MaterialButton(
                    onPressed: _canSave ? _save : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: _saving
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: colors.onPrimary,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            'Guardar en Portafolio',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color:
                                  _canSave ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.38),
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: AppConstants.paddingMD),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Photo slot widget
// ---------------------------------------------------------------------------

class _PhotoSlot extends StatelessWidget {
  final String label;
  final File? photo;
  final bool skipped;
  final VoidCallback onTake;
  final VoidCallback onRemove;
  final VoidCallback? onSkip;

  const _PhotoSlot({
    required this.label,
    required this.photo,
    required this.skipped,
    required this.onTake,
    required this.onRemove,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: photo != null
              ? colors.primary.withValues(alpha: 0.3)
              : skipped
                  ? const Color(0xFFBDBDBD)
                  : colors.onSurface.withValues(alpha: 0.15),
          width: photo != null ? 2 : 1,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: photo != null
          ? _buildPhotoPreview(context)
          : skipped
              ? _buildSkipped(context)
              : _buildEmpty(context, colors),
    );
  }

  Widget _buildPhotoPreview(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Image.file(photo!, fit: BoxFit.cover),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colors.onSurface.withValues(alpha: 0.54),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.onPrimary,
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colors.onSurface.withValues(alpha: 0.54),
                shape: BoxShape.circle,
              ),
              child:
                  Icon(Icons.close_rounded, size: 18, color: colors.onPrimary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkipped(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_off_rounded, size: 36, color: Color(0xFFBDBDBD)),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFBDBDBD),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Cliente no desea foto',
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: const Color(0xFFBDBDBD),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onTake,
            child: Text(
              'Tomar de todos modos',
              style: GoogleFonts.nunito(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, ColorScheme colors) {
    return InkWell(
      onTap: onTake,
      borderRadius: BorderRadius.circular(16),
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: colors.onSurface.withValues(alpha: 0.2),
          radius: 16,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.camera_alt_rounded,
                  size: 40, color: colors.onSurface.withValues(alpha: 0.3)),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tomar foto',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: colors.onSurface.withValues(alpha: 0.4),
                ),
              ),
              if (onSkip != null) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  child: Text(
                    'Cliente no desea foto',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: const Color(0xFFEF5350),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dashed border painter
// ---------------------------------------------------------------------------

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(radius),
      ));

    const dashWidth = 8.0;
    const dashSpace = 5.0;
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
