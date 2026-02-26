import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/media_service.dart';

/// Singleton MediaService provider.
final mediaServiceProvider = Provider<MediaService>((ref) => MediaService());

/// All user media (for "Tus Medios" / BC media library tab).
final personalMediaProvider = FutureProvider<List<MediaItem>>((ref) async {
  final service = ref.read(mediaServiceProvider);
  return service.fetchAllUserMedia();
});

/// Business media (section = 'business').
final businessMediaProvider = FutureProvider<List<MediaItem>>((ref) async {
  final service = ref.read(mediaServiceProvider);
  return service.fetchMedia('business');
});

/// Chat media grouped by thread name.
final chatMediaProvider =
    FutureProvider<Map<String, List<MediaItem>>>((ref) async {
  final service = ref.read(mediaServiceProvider);
  return service.fetchChatMedia();
});
