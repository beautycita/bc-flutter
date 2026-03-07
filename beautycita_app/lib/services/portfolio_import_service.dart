import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'supabase_client.dart';

/// Imports portfolio photos from external sources:
/// 1. discovered_salons.portfolio_images — scraped image URLs
/// 2. Manual bulk upload — user-selected gallery images
class PortfolioImportService {
  /// Imports photos from the discovered_salons record matched to this business.
  /// Returns the number of photos successfully imported.
  static Future<int> importFromDiscoveredSalon(String businessId) async {
    final client = SupabaseClientService.client;

    // Find the discovered_salons record linked to this business
    final discovered = await client
        .from('discovered_salons')
        .select('portfolio_images, photo_url')
        .eq('registered_business_id', businessId)
        .maybeSingle();

    if (discovered == null) return 0;

    final List<String> imageUrls = [];

    // Collect portfolio_images array
    final portfolioImages = discovered['portfolio_images'];
    if (portfolioImages is List) {
      for (final url in portfolioImages) {
        if (url is String && url.isNotEmpty) imageUrls.add(url);
      }
    }

    // Also include the primary photo_url if present
    final photoUrl = discovered['photo_url'] as String?;
    if (photoUrl != null && photoUrl.isNotEmpty && !imageUrls.contains(photoUrl)) {
      imageUrls.insert(0, photoUrl);
    }

    if (imageUrls.isEmpty) return 0;

    int imported = 0;
    final ts = DateTime.now().millisecondsSinceEpoch;

    for (int i = 0; i < imageUrls.length; i++) {
      try {
        // Download the image
        final response = await http.get(Uri.parse(imageUrls[i]));
        if (response.statusCode != 200) continue;

        final bytes = response.bodyBytes;
        if (bytes.isEmpty) continue;

        // Upload to Supabase storage
        final storagePath = 'portfolio/$businessId/${ts}_import_$i.jpg';
        await client.storage
            .from('staff-media')
            .uploadBinary(
              storagePath,
              Uint8List.fromList(bytes),
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );

        final publicUrl = client.storage.from('staff-media').getPublicUrl(storagePath);

        // Create portfolio_photos row — starts hidden until owner reviews
        await client.from('portfolio_photos').insert(<String, dynamic>{
          'business_id': businessId,
          'after_url': publicUrl,
          'photo_type': 'after_only',
          'is_visible': false,
          'sort_order': imported,
          'caption': null,
        });

        imported++;
      } catch (e) {
        // Skip failed images, continue with the rest
        continue;
      }
    }

    return imported;
  }

  /// Uploads multiple images from device gallery as portfolio photos.
  /// All start as hidden (is_visible = false) until owner reviews.
  /// Returns the number of photos successfully uploaded.
  static Future<int> bulkUploadFromGallery(
    String businessId,
    List<Uint8List> images,
  ) async {
    final client = SupabaseClientService.client;
    final ts = DateTime.now().millisecondsSinceEpoch;
    int uploaded = 0;

    for (int i = 0; i < images.length; i++) {
      try {
        final storagePath = 'portfolio/$businessId/${ts}_gallery_$i.jpg';
        await client.storage
            .from('staff-media')
            .uploadBinary(
              storagePath,
              images[i],
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );

        final publicUrl = client.storage.from('staff-media').getPublicUrl(storagePath);

        await client.from('portfolio_photos').insert(<String, dynamic>{
          'business_id': businessId,
          'after_url': publicUrl,
          'photo_type': 'after_only',
          'is_visible': false,
          'sort_order': uploaded,
        });

        uploaded++;
      } catch (e) {
        continue;
      }
    }

    return uploaded;
  }

  /// Checks if there's a discovered_salons record with images for this business.
  static Future<bool> hasDiscoveredImages(String businessId) async {
    final result = await SupabaseClientService.client
        .from('discovered_salons')
        .select('portfolio_images, photo_url')
        .eq('registered_business_id', businessId)
        .maybeSingle();

    if (result == null) return false;

    final images = result['portfolio_images'];
    if (images is List && images.isNotEmpty) return true;

    final photoUrl = result['photo_url'] as String?;
    return photoUrl != null && photoUrl.isNotEmpty;
  }
}
