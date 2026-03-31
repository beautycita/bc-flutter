import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';

/// Opens the image editor (crop + optional watermark) and returns the edited file.
///
/// Parameters:
/// - [imageFile]           Source file to edit.
/// - [watermarkText]       Text to stamp (e.g. salon name or "BeautyCita").
///                         If null, the watermark toggle is hidden.
/// - [showWatermarkOption] Whether to show the watermark checkbox (default true).
/// - [initialAspect]       Starting aspect-ratio preset.
///
/// Returns null if the user cancels.
Future<File?> editImage(
  BuildContext context, {
  required File imageFile,
  String? watermarkText,
  bool showWatermarkOption = true,
  CropAspectRatioPreset initialAspect = CropAspectRatioPreset.original,
}) async {
  // 1. Open the cropper
  final croppedFile = await ImageCropper().cropImage(
    sourcePath: imageFile.path,
    maxWidth: 2048,
    maxHeight: 2048,
    compressQuality: 90,
    compressFormat: ImageCompressFormat.jpg,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: 'Editar imagen',
        toolbarColor: const Color(0xFF9333EA),
        toolbarWidgetColor: Colors.white,
        activeControlsWidgetColor: const Color(0xFFEC4899),
        initAspectRatio: initialAspect,
        lockAspectRatio: false,
        showCropGrid: true,
        backgroundColor: Colors.black,
        aspectRatioPresets: [
          CropAspectRatioPreset.original,
          CropAspectRatioPreset.square,
          CropAspectRatioPreset.ratio4x3,
          CropAspectRatioPreset.ratio16x9,
        ],
      ),
      IOSUiSettings(
        title: 'Editar imagen',
        doneButtonTitle: 'Listo',
        cancelButtonTitle: 'Cancelar',
        resetAspectRatioEnabled: true,
        aspectRatioLockEnabled: false,
        rotateButtonsHidden: false,
        minimumAspectRatio: 0.1,
        aspectRatioPresets: [
          CropAspectRatioPreset.original,
          CropAspectRatioPreset.square,
          CropAspectRatioPreset.ratio4x3,
          CropAspectRatioPreset.ratio16x9,
        ],
      ),
    ],
  );

  if (croppedFile == null) return null;

  File resultFile = File(croppedFile.path);

  // 2. Show watermark option dialog if requested
  if (showWatermarkOption && watermarkText != null && context.mounted) {
    final addWatermark = await _showWatermarkDialog(context, watermarkText);
    if (addWatermark == null) {
      // User cancelled the dialog entirely — cancel the edit
      return null;
    }
    if (addWatermark) {
      final watermarked = await _applyWatermark(resultFile, watermarkText);
      if (watermarked != null) resultFile = watermarked;
    }
  }

  return resultFile;
}

/// Same as [editImage] but accepts raw bytes instead of a File.
/// Writes bytes to a temp file first, then delegates.
Future<File?> editImageFromBytes(
  BuildContext context, {
  required Uint8List bytes,
  String? watermarkText,
  bool showWatermarkOption = true,
  CropAspectRatioPreset initialAspect = CropAspectRatioPreset.original,
}) async {
  final dir = await getTemporaryDirectory();
  final tmp = File(
    '${dir.path}/bc_edit_${DateTime.now().millisecondsSinceEpoch}.jpg',
  );
  await tmp.writeAsBytes(bytes);
  return editImage(
    context,
    imageFile: tmp,
    watermarkText: watermarkText,
    showWatermarkOption: showWatermarkOption,
    initialAspect: initialAspect,
  );
}

// ---------------------------------------------------------------------------
// Watermark dialog
// ---------------------------------------------------------------------------

/// Returns true to add watermark, false to skip, null to cancel the whole edit.
Future<bool?> _showWatermarkDialog(
  BuildContext context,
  String watermarkText,
) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _WatermarkDialog(watermarkText: watermarkText),
  );
}

class _WatermarkDialog extends StatefulWidget {
  final String watermarkText;

  const _WatermarkDialog({required this.watermarkText});

  @override
  State<_WatermarkDialog> createState() => _WatermarkDialogState();
}

class _WatermarkDialogState extends State<_WatermarkDialog> {
  bool _addWatermark = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Marca de agua',
        style: GoogleFonts.poppins(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Agrega una marca de agua discreta con el nombre de tu salon.',
            style: GoogleFonts.nunito(fontSize: 14, color: onSurface.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _addWatermark,
            onChanged: (v) => setState(() => _addWatermark = v ?? false),
            title: Text(
              '"${widget.watermarkText}"',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: onSurface,
              ),
            ),
            subtitle: Text(
              'Semitransparente, esquina inferior derecha',
              style: GoogleFonts.nunito(fontSize: 12, color: onSurface.withValues(alpha: 0.5)),
            ),
            activeColor: primary,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(
            'Cancelar',
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: primary),
          onPressed: () => Navigator.pop(context, _addWatermark),
          child: Text(
            'Guardar',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Watermark rendering
// ---------------------------------------------------------------------------

/// Draws a nearly-invisible watermark in the bottom-right corner of [source].
Future<File?> _applyWatermark(File source, String text) async {
  try {
    final bytes = await source.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final w = image.width.toDouble();
    final h = image.height.toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, w, h),
    );

    // Draw the source image
    canvas.drawImage(image, Offset.zero, Paint());

    // Watermark text paint — 8% opacity
    final fontSize = (w * 0.025).clamp(12.0, 32.0);
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: Colors.white.withValues(alpha: 0.08),
          fontWeight: FontWeight.w600,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 2,
              offset: const Offset(1, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w * 0.4);

    final padding = fontSize * 0.6;
    final dx = w - textPainter.width - padding;
    final dy = h - textPainter.height - padding;
    textPainter.paint(canvas, Offset(dx, dy));

    final picture = recorder.endRecording();
    final resultImage = await picture.toImage(image.width, image.height);
    final byteData =
        await resultImage.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return source;

    final dir = await getTemporaryDirectory();
    final outFile = File(
      '${dir.path}/bc_wm_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await outFile.writeAsBytes(byteData.buffer.asUint8List());
    return outFile;
  } catch (_) {
    // If watermark fails for any reason, return original
    return source;
  }
}
