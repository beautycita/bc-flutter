import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:beautycita/services/supabase_client.dart';

class ProfileState {
  final String? avatarUrl;
  final String? fullName;
  final String? homeAddress;
  final double? homeLat;
  final double? homeLng;
  final bool isLoading;
  final String? error;

  const ProfileState({
    this.avatarUrl,
    this.fullName,
    this.homeAddress,
    this.homeLat,
    this.homeLng,
    this.isLoading = false,
    this.error,
  });

  ProfileState copyWith({
    String? avatarUrl,
    String? fullName,
    String? homeAddress,
    double? homeLat,
    double? homeLng,
    bool? isLoading,
    String? error,
  }) {
    return ProfileState(
      avatarUrl: avatarUrl ?? this.avatarUrl,
      fullName: fullName ?? this.fullName,
      homeAddress: homeAddress ?? this.homeAddress,
      homeLat: homeLat ?? this.homeLat,
      homeLng: homeLng ?? this.homeLng,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  ProfileNotifier() : super(const ProfileState()) {
    load();
  }

  Future<void> load() async {
    if (!SupabaseClientService.isInitialized) return;
    final userId = SupabaseClientService.currentUserId;
    if (userId == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final client = SupabaseClientService.client;
      final data = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data != null) {
        state = ProfileState(
          avatarUrl: data['avatar_url'] as String?,
          fullName: data['full_name'] as String?,
          homeAddress: data['home_address'] as String?,
          homeLat: (data['home_lat'] as num?)?.toDouble(),
          homeLng: (data['home_lng'] as num?)?.toDouble(),
        );
      } else {
        state = const ProfileState();
      }
    } catch (e) {
      debugPrint('ProfileNotifier.load error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateFullName(String name) async {
    if (!SupabaseClientService.isInitialized) return;
    final userId = SupabaseClientService.currentUserId;
    if (userId == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      await SupabaseClientService.client
          .from('profiles')
          .upsert({'id': userId, 'full_name': name});
      state = state.copyWith(fullName: name, isLoading: false);
    } catch (e) {
      debugPrint('ProfileNotifier.updateFullName error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateAvatar(String url) async {
    if (!SupabaseClientService.isInitialized) return;
    final userId = SupabaseClientService.currentUserId;
    if (userId == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      await SupabaseClientService.client
          .from('profiles')
          .upsert({'id': userId, 'avatar_url': url});
      state = state.copyWith(avatarUrl: url, isLoading: false);
    } catch (e) {
      debugPrint('ProfileNotifier.updateAvatar error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<String?> uploadAvatar(Uint8List bytes, String fileName) async {
    if (!SupabaseClientService.isInitialized) return null;
    final userId = SupabaseClientService.currentUserId;
    if (userId == null) return null;

    try {
      final path = '$userId/$fileName';
      final contentType = fileName.endsWith('.png') ? 'image/png' : 'image/jpeg';
      await SupabaseClientService.client.storage
          .from('avatars')
          .uploadBinary(path, bytes, fileOptions: FileOptions(upsert: true, contentType: contentType));
      final url = SupabaseClientService.client.storage
          .from('avatars')
          .getPublicUrl(path);
      await updateAvatar(url);
      return url;
    } catch (e) {
      debugPrint('ProfileNotifier.uploadAvatar error: $e');
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<void> updateHomeLocation({
    required String address,
    required double lat,
    required double lng,
  }) async {
    if (!SupabaseClientService.isInitialized) return;
    final userId = SupabaseClientService.currentUserId;
    if (userId == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      await SupabaseClientService.client.from('profiles').upsert({
        'id': userId,
        'home_address': address,
        'home_lat': lat,
        'home_lng': lng,
      });
      state = state.copyWith(
        homeAddress: address,
        homeLat: lat,
        homeLng: lng,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('ProfileNotifier.updateHomeLocation error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> updateUsername(String username) async {
    if (!SupabaseClientService.isInitialized) return false;
    final userId = SupabaseClientService.currentUserId;
    if (userId == null) return false;

    state = state.copyWith(isLoading: true, error: null);
    try {
      await SupabaseClientService.client
          .from('profiles')
          .upsert({'id': userId, 'username': username});
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      debugPrint('ProfileNotifier.updateUsername error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> checkUsernameAvailable(String username) async {
    if (!SupabaseClientService.isInitialized) return false;
    try {
      final data = await SupabaseClientService.client
          .from('profiles')
          .select('id')
          .eq('username', username)
          .maybeSingle();
      if (data == null) return true;
      // If it's the current user's own username, it's available
      final userId = SupabaseClientService.currentUserId;
      return data['id'] == userId;
    } catch (e) {
      debugPrint('ProfileNotifier.checkUsernameAvailable error: $e');
      return false;
    }
  }
}

final profileProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  return ProfileNotifier();
});

