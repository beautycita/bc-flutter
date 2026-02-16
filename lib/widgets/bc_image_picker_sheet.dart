import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config/constants.dart';
import '../providers/media_provider.dart';
import '../services/media_service.dart';

/// Source of the selected image.
enum BCImageSource {
  /// Selected from device gallery.
  gallery,

  /// Captured with device camera.
  camera,

  /// Selected from user's BC media library.
  library,
}

/// Result returned from the BC image picker.
class BCImagePickerResult {
  /// The image bytes.
  final Uint8List bytes;

  /// Where the image came from.
  final BCImageSource source;

  /// Original URL if selected from library.
  final String? sourceUrl;

  const BCImagePickerResult({
    required this.bytes,
    required this.source,
    this.sourceUrl,
  });
}

/// Shows the BC image picker as a modal bottom sheet.
/// Returns [BCImagePickerResult] if user selects an image, null if dismissed.
Future<BCImagePickerResult?> showBCImagePicker({
  required BuildContext context,
  required WidgetRef ref,
}) {
  return showModalBottomSheet<BCImagePickerResult>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppConstants.radiusXL),
      ),
    ),
    builder: (ctx) => _BCImagePickerBody(ref: ref),
  );
}

class _BCImagePickerBody extends StatefulWidget {
  final WidgetRef ref;

  const _BCImagePickerBody({required this.ref});

  @override
  State<_BCImagePickerBody> createState() => _BCImagePickerBodyState();
}

class _BCImagePickerBodyState extends State<_BCImagePickerBody> {
  final ImagePicker _picker = ImagePicker();
  bool _loading = false;
  String? _selectedLibraryId;

  @override
  Widget build(BuildContext context) {
    final mediaAsync = widget.ref.watch(personalMediaProvider);
    final screenHeight = MediaQuery.of(context).size.height;
    final primary = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceLight = onSurface.withValues(alpha: 0.5);
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return Container(
      height: screenHeight * 0.75,
      decoration: BoxDecoration(
        color: scaffoldBg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusXL),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: AppConstants.paddingMD),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.paddingLG,
              AppConstants.paddingMD,
              AppConstants.paddingLG,
              AppConstants.paddingSM,
            ),
            child: Row(
              children: [
                Text(
                  'Seleccionar imagen',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
                ),
                const Spacer(),
                if (_loading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primary,
                    ),
                  ),
              ],
            ),
          ),

          // Gallery & Camera buttons
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingLG,
              vertical: AppConstants.paddingSM,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.photo_library_outlined,
                    label: 'Galeria',
                    onTap: _loading ? null : _pickFromGallery,
                  ),
                ),
                const SizedBox(width: AppConstants.paddingMD),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.camera_alt_outlined,
                    label: 'Camara',
                    onTap: _loading ? null : _pickFromCamera,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: AppConstants.paddingLG),

          // "Tu biblioteca" section header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.paddingLG,
              0,
              AppConstants.paddingLG,
              AppConstants.paddingSM,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.collections_outlined,
                  size: 20,
                  color: primary,
                ),
                const SizedBox(width: AppConstants.paddingXS),
                Text(
                  'Tu biblioteca',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
                ),
              ],
            ),
          ),

          // Media library grid
          Expanded(
            child: mediaAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: primary,
                ),
              ),
              error: (err, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: onSurfaceLight.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: AppConstants.paddingSM),
                    Text(
                      'Error al cargar medios',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        color: onSurfaceLight,
                      ),
                    ),
                  ],
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          size: 64,
                          color: onSurfaceLight.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: AppConstants.paddingMD),
                        Text(
                          'Sin imagenes todavia',
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            color: onSurfaceLight,
                          ),
                        ),
                        const SizedBox(height: AppConstants.paddingXS),
                        Text(
                          'Las fotos de tu estudio virtual apareceran aqui',
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            color: onSurfaceLight.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppConstants.paddingMD,
                    0,
                    AppConstants.paddingMD,
                    AppConstants.paddingLG,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isSelected = _selectedLibraryId == item.id;

                    return GestureDetector(
                      onTap: _loading ? null : () => _selectLibraryItem(item),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Thumbnail
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              item.thumbnailUrl ?? item.url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: surface,
                                child: Icon(
                                  Icons.broken_image,
                                  size: 32,
                                  color: onSurfaceLight,
                                ),
                              ),
                            ),
                          ),

                          // Selection overlay
                          if (isSelected)
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: primary,
                                  width: 3,
                                ),
                              ),
                            ),

                          // Loading overlay for selected item
                          if (isSelected && _loading)
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.black45,
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),

                          // Source badge
                          if (item.toolLabel != null && !isSelected)
                            Positioned(
                              bottom: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.toolLabel!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    debugPrint('BCImagePicker: _pickFromGallery called');
    setState(() => _loading = true);
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );
      debugPrint('BCImagePicker: picked file = ${file?.path}');

      if (file != null && mounted) {
        final bytes = await file.readAsBytes();
        debugPrint('BCImagePicker: read ${bytes.length} bytes');
        if (!mounted) {
          debugPrint('BCImagePicker: not mounted after readAsBytes');
          return;
        }
        HapticFeedback.lightImpact();
        debugPrint('BCImagePicker: popping with result');
        Navigator.of(context).pop(BCImagePickerResult(
          bytes: bytes,
          source: BCImageSource.gallery,
        ));
      } else {
        debugPrint('BCImagePicker: file null or not mounted');
      }
    } catch (e) {
      debugPrint('BCImagePicker: gallery error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickFromCamera() async {
    setState(() => _loading = true);
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
        preferredCameraDevice: CameraDevice.front,
      );

      if (file != null && mounted) {
        final bytes = await file.readAsBytes();
        HapticFeedback.lightImpact();
        Navigator.of(context).pop(BCImagePickerResult(
          bytes: bytes,
          source: BCImageSource.camera,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectLibraryItem(MediaItem item) async {
    setState(() {
      _loading = true;
      _selectedLibraryId = item.id;
    });

    try {
      final response = await http.get(Uri.parse(item.url));
      if (response.statusCode == 200 && mounted) {
        HapticFeedback.lightImpact();
        Navigator.of(context).pop(BCImagePickerResult(
          bytes: response.bodyBytes,
          source: BCImageSource.library,
          sourceUrl: item.url,
        ));
      } else if (mounted) {
        _showError('No se pudo descargar la imagen');
        setState(() {
          _loading = false;
          _selectedLibraryId = null;
        });
      }
    } catch (e) {
      if (mounted) {
        _showError('Error al cargar imagen');
        setState(() {
          _loading = false;
          _selectedLibraryId = null;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
      ),
    );
  }
}

/// Action button for Gallery/Camera selection.
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;
    final primary = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceLight = onSurface.withValues(alpha: 0.5);

    return Material(
      color: isDisabled
          ? surface.withValues(alpha: 0.5)
          : surface,
      borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingMD,
            vertical: AppConstants.paddingMD,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: isDisabled
                    ? onSurfaceLight
                    : primary,
              ),
              const SizedBox(width: AppConstants.paddingXS),
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDisabled
                      ? onSurfaceLight
                      : onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
