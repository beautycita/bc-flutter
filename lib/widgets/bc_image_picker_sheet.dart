import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config/theme.dart';
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
        top: Radius.circular(BeautyCitaTheme.radiusXL),
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

    return Container(
      height: screenHeight * 0.75,
      decoration: const BoxDecoration(
        color: BeautyCitaTheme.backgroundWhite,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(BeautyCitaTheme.radiusXL),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: BeautyCitaTheme.spaceMD),
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
              BeautyCitaTheme.spaceLG,
              BeautyCitaTheme.spaceMD,
              BeautyCitaTheme.spaceLG,
              BeautyCitaTheme.spaceSM,
            ),
            child: Row(
              children: [
                Text(
                  'Seleccionar imagen',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: BeautyCitaTheme.textDark,
                  ),
                ),
                const Spacer(),
                if (_loading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: BeautyCitaTheme.primaryRose,
                    ),
                  ),
              ],
            ),
          ),

          // Gallery & Camera buttons
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: BeautyCitaTheme.spaceLG,
              vertical: BeautyCitaTheme.spaceSM,
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
                const SizedBox(width: BeautyCitaTheme.spaceMD),
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

          const Divider(height: BeautyCitaTheme.spaceLG),

          // "Tu biblioteca" section header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BeautyCitaTheme.spaceLG,
              0,
              BeautyCitaTheme.spaceLG,
              BeautyCitaTheme.spaceSM,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.collections_outlined,
                  size: 20,
                  color: BeautyCitaTheme.primaryRose,
                ),
                const SizedBox(width: BeautyCitaTheme.spaceXS),
                Text(
                  'Tu biblioteca',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: BeautyCitaTheme.textDark,
                  ),
                ),
              ],
            ),
          ),

          // Media library grid
          Expanded(
            child: mediaAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: BeautyCitaTheme.primaryRose,
                ),
              ),
              error: (err, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: BeautyCitaTheme.textLight.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: BeautyCitaTheme.spaceSM),
                    Text(
                      'Error al cargar medios',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        color: BeautyCitaTheme.textLight,
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
                          color: BeautyCitaTheme.textLight.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: BeautyCitaTheme.spaceMD),
                        Text(
                          'Sin imagenes todavia',
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            color: BeautyCitaTheme.textLight,
                          ),
                        ),
                        const SizedBox(height: BeautyCitaTheme.spaceXS),
                        Text(
                          'Las fotos de tu estudio virtual apareceran aqui',
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            color: BeautyCitaTheme.textLight.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    BeautyCitaTheme.spaceMD,
                    0,
                    BeautyCitaTheme.spaceMD,
                    BeautyCitaTheme.spaceLG,
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
                                color: BeautyCitaTheme.surfaceCream,
                                child: const Icon(
                                  Icons.broken_image,
                                  size: 32,
                                  color: BeautyCitaTheme.textLight,
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
                                  color: BeautyCitaTheme.primaryRose,
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
    setState(() => _loading = true);
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );

      if (file != null && mounted) {
        final bytes = await file.readAsBytes();
        HapticFeedback.lightImpact();
        Navigator.of(context).pop(BCImagePickerResult(
          bytes: bytes,
          source: BCImageSource.gallery,
        ));
      }
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

    return Material(
      color: isDisabled
          ? BeautyCitaTheme.surfaceCream.withValues(alpha: 0.5)
          : BeautyCitaTheme.surfaceCream,
      borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BeautyCitaTheme.spaceMD,
            vertical: BeautyCitaTheme.spaceMD,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: isDisabled
                    ? BeautyCitaTheme.textLight
                    : BeautyCitaTheme.primaryRose,
              ),
              const SizedBox(width: BeautyCitaTheme.spaceXS),
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDisabled
                      ? BeautyCitaTheme.textLight
                      : BeautyCitaTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
