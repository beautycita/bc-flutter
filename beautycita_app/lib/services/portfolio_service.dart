import 'package:flutter/foundation.dart';
import 'package:beautycita_core/beautycita_core.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'supabase_client.dart';

class PortfolioService {
  // ---------------------------------------------------------------------------
  // Upload
  // ---------------------------------------------------------------------------

  /// Uploads before/after images to storage and creates a portfolio_photos row.
  /// [beforeBytes] is optional (null for 'after_only' type).
  static Future<PortfolioPhoto> uploadPhoto({
    required String businessId,
    String? staffId,
    Uint8List? beforeBytes,
    required Uint8List afterBytes,
    required String photoType,
    String? serviceCategory,
    String? caption,
    Map<String, dynamic>? productTags,
    String? appointmentId,
  }) async {
    final client = SupabaseClientService.client;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final basePath = 'portfolio/$businessId/$ts';

    String? beforeUrl;

    if (beforeBytes != null) {
      final beforePath = '${basePath}_before.jpg';
      await client.storage
          .from('staff-media')
          .uploadBinary(
            beforePath,
            beforeBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      beforeUrl = client.storage.from('staff-media').getPublicUrl(beforePath);
    }

    final afterPath = '${basePath}_after.jpg';
    await client.storage
        .from('staff-media')
        .uploadBinary(
          afterPath,
          afterBytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    final afterUrl = client.storage.from('staff-media').getPublicUrl(afterPath);

    final row = <String, dynamic>{
      'business_id': businessId,
      'staff_id': staffId,
      'before_url': beforeUrl,
      'after_url': afterUrl,
      'photo_type': photoType,
      'service_category': serviceCategory,
      'caption': caption,
      'product_tags': productTags,
      'appointment_id': appointmentId,
      'is_visible': true,
      'sort_order': 0,
    };

    final result = await client
        .from('portfolio_photos')
        .insert(row)
        .select()
        .single();

    return PortfolioPhoto.fromJson(result);
  }

  // ---------------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------------

  /// Deletes storage objects for the photo, then removes the DB row.
  static Future<void> deletePhoto(String photoId) async {
    final client = SupabaseClientService.client;

    // Fetch the row first to get the storage paths.
    final row = await client
        .from('portfolio_photos')
        .select('before_url, after_url')
        .eq('id', photoId)
        .maybeSingle();

    if (row != null) {
      final pathsToDelete = <String>[];

      final beforeUrl = row['before_url'] as String?;
      final afterUrl = row['after_url'] as String?;

      if (beforeUrl != null) {
        final storagePath = _storagePathFromUrl(beforeUrl, 'staff-media');
        if (storagePath != null) pathsToDelete.add(storagePath);
      }
      if (afterUrl != null) {
        final storagePath = _storagePathFromUrl(afterUrl, 'staff-media');
        if (storagePath != null) pathsToDelete.add(storagePath);
      }

      if (pathsToDelete.isNotEmpty) {
        try {
          await client.storage.from('staff-media').remove(pathsToDelete);
        } catch (e) {
          // Storage delete failure should not block DB row removal.
          debugPrint('PortfolioService.deletePhoto: storage remove error: $e');
        }
      }
    }

    await client.from('portfolio_photos').delete().eq('id', photoId);
  }

  // ---------------------------------------------------------------------------
  // Update
  // ---------------------------------------------------------------------------

  /// Updates mutable fields on a portfolio_photos row.
  static Future<void> updatePhoto(
    String photoId, {
    String? caption,
    Map<String, dynamic>? productTags,
    bool? isVisible,
    int? sortOrder,
  }) async {
    final updates = <String, dynamic>{};
    if (caption != null) updates['caption'] = caption;
    if (productTags != null) updates['product_tags'] = productTags;
    if (isVisible != null) updates['is_visible'] = isVisible;
    if (sortOrder != null) updates['sort_order'] = sortOrder;

    if (updates.isEmpty) return;

    await SupabaseClientService.client
        .from('portfolio_photos')
        .update(updates)
        .eq('id', photoId);
  }

  // ---------------------------------------------------------------------------
  // Reorder
  // ---------------------------------------------------------------------------

  /// Bulk-updates sort_order for a list of photo IDs.
  /// The index position in [photoIds] becomes the new sort_order value.
  static Future<void> reorderPhotos(
    String businessId,
    List<String> photoIds,
  ) async {
    final client = SupabaseClientService.client;

    // Fire updates in parallel — one per photo.
    await Future.wait(
      photoIds.asMap().entries.map((entry) {
        return client
            .from('portfolio_photos')
            .update({'sort_order': entry.key})
            .eq('id', entry.value)
            .eq('business_id', businessId);
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // Config
  // ---------------------------------------------------------------------------

  /// Writes portfolio config fields to the businesses table.
  static Future<void> updateConfig(
    String businessId,
    PortfolioConfig config,
  ) async {
    await SupabaseClientService.client
        .from('businesses')
        .update(config.toJson())
        .eq('id', businessId);
  }

  // ---------------------------------------------------------------------------
  // Agreements
  // ---------------------------------------------------------------------------

  /// Inserts an acceptance record into portfolio_agreements.
  static Future<void> acceptAgreement(
    String businessId,
    String type,
    String version,
  ) async {
    final userId = SupabaseClientService.currentUserId;
    await SupabaseClientService.client.from('portfolio_agreements').insert(<String, dynamic>{
      'business_id': businessId,
      'agreement_type': type,
      'agreement_version': version,
      'accepted_by': userId,
    });
  }

  /// Returns true if the business has accepted the given agreement type+version.
  static Future<bool> hasAcceptedAgreement(
    String businessId,
    String type,
    String version,
  ) async {
    final result = await SupabaseClientService.client
        .from('portfolio_agreements')
        .select('id')
        .eq('business_id', businessId)
        .eq('agreement_type', type)
        .eq('agreement_version', version)
        .maybeSingle();

    return result != null;
  }

  // ---------------------------------------------------------------------------
  // Image processing
  // ---------------------------------------------------------------------------

  /// Auto-corrects an image: normalizes levels, slight saturation boost,
  /// and auto white balance. Returns JPEG-encoded bytes.
  static Future<Uint8List> autoCorrectImage(Uint8List bytes) async {
    return compute(_autoCorrectSync, bytes);
  }

  /// Scores each image by sharpness (Laplacian variance) and returns
  /// the index of the sharpest one.
  static Future<int> selectBestImage(List<Uint8List> images) async {
    if (images.isEmpty) return 0;
    if (images.length == 1) return 0;
    return compute(_selectBestSync, images);
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Extracts the storage path from a Supabase public URL.
  /// e.g. "https://…/storage/v1/object/public/staff-media/portfolio/…"
  /// → "portfolio/…"
  static String? _storagePathFromUrl(String url, String bucket) {
    try {
      final marker = '/object/public/$bucket/';
      final idx = url.indexOf(marker);
      if (idx == -1) return null;
      return url.substring(idx + marker.length);
    } catch (_) {
      return null;
    }
  }
}

// ---------------------------------------------------------------------------
// Isolate-safe sync functions (top-level for compute())
// ---------------------------------------------------------------------------

Uint8List _autoCorrectSync(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;

  // --- Auto white balance (gray world assumption) ---
  double sumR = 0, sumG = 0, sumB = 0;
  final pixelCount = decoded.width * decoded.height;

  for (final pixel in decoded) {
    sumR += pixel.r;
    sumG += pixel.g;
    sumB += pixel.b;
  }

  final avgR = sumR / pixelCount;
  final avgG = sumG / pixelCount;
  final avgB = sumB / pixelCount;
  final avgGray = (avgR + avgG + avgB) / 3;

  final scaleR = avgGray / avgR.clamp(1, double.infinity);
  final scaleG = avgGray / avgG.clamp(1, double.infinity);
  final scaleB = avgGray / avgB.clamp(1, double.infinity);

  // Apply white balance and build histogram for auto-levels.
  // We collect per-channel min/max after white balance to normalize.
  final adjusted = img.Image(width: decoded.width, height: decoded.height);

  int minR = 255, maxR = 0;
  int minG = 255, maxG = 0;
  int minB = 255, maxB = 0;

  for (final pixel in decoded) {
    final r = (pixel.r * scaleR).round().clamp(0, 255);
    final g = (pixel.g * scaleG).round().clamp(0, 255);
    final b = (pixel.b * scaleB).round().clamp(0, 255);
    adjusted.setPixelRgb(pixel.x, pixel.y, r, g, b);
    if (r < minR) minR = r;
    if (r > maxR) maxR = r;
    if (g < minG) minG = g;
    if (g > maxG) maxG = g;
    if (b < minB) minB = b;
    if (b > maxB) maxB = b;
  }

  // --- Auto-levels (normalize histogram per channel) ---
  final leveled = img.Image(width: adjusted.width, height: adjusted.height);

  final rangeR = (maxR - minR).clamp(1, 255);
  final rangeG = (maxG - minG).clamp(1, 255);
  final rangeB = (maxB - minB).clamp(1, 255);

  for (final pixel in adjusted) {
    final r = (((pixel.r - minR) / rangeR) * 255).round().clamp(0, 255);
    final g = (((pixel.g - minG) / rangeG) * 255).round().clamp(0, 255);
    final b = (((pixel.b - minB) / rangeB) * 255).round().clamp(0, 255);
    leveled.setPixelRgb(pixel.x, pixel.y, r, g, b);
  }

  // --- Saturation boost (+10%) via HSL ---
  final saturated = img.adjustColor(leveled, saturation: 1.1);

  return Uint8List.fromList(img.encodeJpg(saturated, quality: 92));
}

int _selectBestSync(List<Uint8List> images) {
  int bestIndex = 0;
  double bestScore = -1;

  for (int i = 0; i < images.length; i++) {
    final score = _laplacianVariance(images[i]);
    if (score > bestScore) {
      bestScore = score;
      bestIndex = i;
    }
  }

  return bestIndex;
}

/// Computes the Laplacian variance of an image as a sharpness score.
/// Higher variance = sharper image.
double _laplacianVariance(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return 0;

  // Convert to grayscale for the convolution.
  final gray = img.grayscale(decoded);

  final w = gray.width;
  final h = gray.height;

  // Laplacian kernel: [0,1,0 / 1,-4,1 / 0,1,0]
  // Skip the 1-pixel border.
  double sum = 0;
  double sumSq = 0;
  int count = 0;

  for (int y = 1; y < h - 1; y++) {
    for (int x = 1; x < w - 1; x++) {
      final center = gray.getPixel(x, y).r.toDouble();
      final top    = gray.getPixel(x, y - 1).r.toDouble();
      final bottom = gray.getPixel(x, y + 1).r.toDouble();
      final left   = gray.getPixel(x - 1, y).r.toDouble();
      final right  = gray.getPixel(x + 1, y).r.toDouble();

      final lap = top + bottom + left + right - 4 * center;
      sum += lap;
      sumSq += lap * lap;
      count++;
    }
  }

  if (count == 0) return 0;
  final mean = sum / count;
  return (sumSq / count) - (mean * mean); // variance
}
