import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:beautycita/services/supabase_client.dart';
import 'package:beautycita/services/toast_service.dart';
import 'package:beautycita/services/places_service.dart';

class ProfileState {
  final String? avatarUrl;
  final String? fullName;
  final String? homeAddress;
  final double? homeLat;
  final double? homeLng;
  final String? phone;
  final bool phoneVerified;
  final DateTime? birthday;
  final String? gender;
  final bool isLoading;
  final String? error;

  const ProfileState({
    this.avatarUrl,
    this.fullName,
    this.homeAddress,
    this.homeLat,
    this.homeLng,
    this.phone,
    this.phoneVerified = false,
    this.birthday,
    this.gender,
    this.isLoading = false,
    this.error,
  });

  bool get hasVerifiedPhone => phone != null && phone!.isNotEmpty && phoneVerified;

  ProfileState copyWith({
    String? avatarUrl,
    String? fullName,
    String? homeAddress,
    double? homeLat,
    double? homeLng,
    String? phone,
    bool? phoneVerified,
    DateTime? birthday,
    bool clearBirthday = false,
    String? gender,
    bool clearGender = false,
    bool? isLoading,
    String? error,
  }) {
    return ProfileState(
      avatarUrl: avatarUrl ?? this.avatarUrl,
      fullName: fullName ?? this.fullName,
      homeAddress: homeAddress ?? this.homeAddress,
      homeLat: homeLat ?? this.homeLat,
      homeLng: homeLng ?? this.homeLng,
      phone: phone ?? this.phone,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      birthday: clearBirthday ? null : (birthday ?? this.birthday),
      gender: clearGender ? null : (gender ?? this.gender),
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  DateTime? _lastOtpSend;

  ProfileNotifier() : super(const ProfileState()) {
    load();
  }

  /// Returns true if Supabase is initialized and user is authenticated.
  /// Shows an error toast if not ready.
  bool _ensureReady(String method) {
    if (!SupabaseClientService.isInitialized) {
      debugPrint('ProfileNotifier.$method: Supabase not initialized');
      ToastService.showError('Sin conexion — intenta de nuevo');
      return false;
    }
    if (SupabaseClientService.currentUserId == null) {
      debugPrint('ProfileNotifier.$method: userId is null');
      ToastService.showError('Sesion no activa — reinicia la app');
      return false;
    }
    return true;
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
        DateTime? birthday;
        final bdayStr = data['birthday'] as String?;
        if (bdayStr != null) {
          birthday = DateTime.tryParse(bdayStr);
        }

        state = ProfileState(
          avatarUrl: data['avatar_url'] as String?,
          fullName: data['full_name'] as String?,
          homeAddress: data['home_address'] as String?,
          homeLat: (data['home_lat'] as num?)?.toDouble(),
          homeLng: (data['home_lng'] as num?)?.toDouble(),
          phone: data['phone'] as String?,
          phoneVerified: data['phone_verified_at'] != null,
          birthday: birthday,
          gender: data['gender'] as String?,
        );
      } else {
        state = const ProfileState();
      }
    } catch (e) {
      debugPrint('ProfileNotifier.load error: $e');
      final msg = ToastService.friendlyError(e);
      ToastService.showError(msg);
      state = state.copyWith(isLoading: false, error: msg);
    }
  }

  Future<void> updateFullName(String name) async {
    if (!_ensureReady('updateFullName')) return;
    final userId = SupabaseClientService.currentUserId!;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final rows = await SupabaseClientService.client
          .from('profiles')
          .update({'full_name': name})
          .eq('id', userId)
          .select('id');
      if ((rows as List).isEmpty) {
        throw Exception('No se pudo actualizar — perfil no encontrado');
      }
      state = state.copyWith(fullName: name, isLoading: false);
    } catch (e) {
      debugPrint('ProfileNotifier.updateFullName error: $e');
      final msg = ToastService.friendlyError(e);
      ToastService.showError(msg);
      state = state.copyWith(isLoading: false, error: msg);
    }
  }

  Future<void> updateAvatar(String url) async {
    if (!_ensureReady('updateAvatar')) return;
    final userId = SupabaseClientService.currentUserId!;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final rows = await SupabaseClientService.client
          .from('profiles')
          .update({'avatar_url': url})
          .eq('id', userId)
          .select('id');
      if ((rows as List).isEmpty) {
        throw Exception('No se pudo actualizar — perfil no encontrado');
      }
      state = state.copyWith(avatarUrl: url, isLoading: false);
    } catch (e) {
      debugPrint('ProfileNotifier.updateAvatar error: $e');
      final msg = ToastService.friendlyError(e);
      ToastService.showError(msg);
      state = state.copyWith(isLoading: false, error: msg);
    }
  }

  Future<String?> uploadAvatar(Uint8List bytes, String fileName) async {
    debugPrint('ProfileNotifier.uploadAvatar: called with ${bytes.length} bytes, fileName=$fileName');
    if (!SupabaseClientService.isInitialized) {
      debugPrint('ProfileNotifier.uploadAvatar: Supabase not initialized');
      return null;
    }
    final userId = SupabaseClientService.currentUserId;
    if (userId == null) {
      debugPrint('ProfileNotifier.uploadAvatar: userId is null');
      return null;
    }
    debugPrint('ProfileNotifier.uploadAvatar: userId=$userId');

    try {
      final path = '$userId/$fileName';
      final contentType = fileName.endsWith('.png') ? 'image/png' : 'image/jpeg';
      debugPrint('ProfileNotifier.uploadAvatar: uploading to avatars/$path');
      await SupabaseClientService.client.storage
          .from('avatars')
          .uploadBinary(path, bytes, fileOptions: FileOptions(upsert: true, contentType: contentType));
      debugPrint('ProfileNotifier.uploadAvatar: upload success');
      final baseUrl = SupabaseClientService.client.storage
          .from('avatars')
          .getPublicUrl(path);
      // Add cache-busting query param to ensure new image loads
      final url = '$baseUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('ProfileNotifier.uploadAvatar: publicUrl=$url');
      await updateAvatar(url);
      debugPrint('ProfileNotifier.uploadAvatar: updateAvatar complete, state.avatarUrl=${state.avatarUrl}');
      return url;
    } catch (e) {
      debugPrint('ProfileNotifier.uploadAvatar error: $e');
      final msg = ToastService.friendlyError(e);
      ToastService.showError(msg);
      state = state.copyWith(error: msg);
      return null;
    }
  }

  Future<void> updateHomeLocation({
    required String address,
    required double lat,
    required double lng,
  }) async {
    if (!_ensureReady('updateHomeLocation')) return;
    final userId = SupabaseClientService.currentUserId!;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final rows = await SupabaseClientService.client.from('profiles').update({
        'home_address': address,
        'home_lat': lat,
        'home_lng': lng,
      }).eq('id', userId).select('id');
      if ((rows as List).isEmpty) {
        throw Exception('No se pudo actualizar — perfil no encontrado');
      }
      state = state.copyWith(
        homeAddress: address,
        homeLat: lat,
        homeLng: lng,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('ProfileNotifier.updateHomeLocation error: $e');
      final msg = ToastService.friendlyError(e);
      ToastService.showError(msg);
      state = state.copyWith(isLoading: false, error: msg);
    }
  }

  /// Save phone number to profile (unverified). Returns true on success.
  Future<bool> updatePhone(String phone) async {
    if (!_ensureReady('updatePhone')) return false;
    final userId = SupabaseClientService.currentUserId!;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final rows = await SupabaseClientService.client.from('profiles').update({
        'phone': phone,
        'phone_verified_at': null,
      }).eq('id', userId).select('id');
      if ((rows as List).isEmpty) {
        throw Exception('No se pudo actualizar — perfil no encontrado');
      }
      state = state.copyWith(phone: phone, phoneVerified: false, isLoading: false);
      return true;
    } catch (e) {
      debugPrint('ProfileNotifier.updatePhone error: $e');
      final msg = ToastService.friendlyError(e);
      ToastService.showError(msg);
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    }
  }

  /// Send OTP to the saved phone number via phone-verify edge function.
  Future<bool> sendPhoneOtp() async {
    if (!SupabaseClientService.isInitialized) return false;
    final phone = state.phone;
    if (phone == null || phone.isEmpty) return false;

    // Rate limit: 30 second cooldown between OTP sends
    final now = DateTime.now();
    if (_lastOtpSend != null && now.difference(_lastOtpSend!) < const Duration(seconds: 30)) {
      state = state.copyWith(error: 'Espera 30 segundos antes de reenviar el codigo');
      return false;
    }
    _lastOtpSend = now;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await SupabaseClientService.client.functions.invoke(
        'phone-verify',
        body: {'action': 'send-code', 'phone': phone},
      );
      final data = res.data as Map<String, dynamic>?;
      if (data == null || data['sent'] != true) {
        throw Exception(data?['error'] ?? 'No se pudo enviar el codigo');
      }
      debugPrint('OTP sent via ${data['channel']}');
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      debugPrint('ProfileNotifier.sendPhoneOtp error: $e');
      final msg = ToastService.friendlyError(e);
      ToastService.showError(msg);
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    }
  }

  /// Verify phone OTP via phone-verify edge function.
  Future<bool> verifyPhoneOtp(String otp) async {
    if (!SupabaseClientService.isInitialized) return false;
    final phone = state.phone;
    if (phone == null) return false;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await SupabaseClientService.client.functions.invoke(
        'phone-verify',
        body: {'action': 'verify-code', 'phone': phone, 'code': otp},
      );
      final data = res.data as Map<String, dynamic>?;
      if (data == null || data['verified'] != true) {
        throw Exception(data?['error'] ?? 'Codigo incorrecto');
      }
      state = state.copyWith(phoneVerified: true, isLoading: false);
      return true;
    } catch (e) {
      debugPrint('ProfileNotifier.verifyPhoneOtp error: $e');
      final msg = ToastService.friendlyError(e);
      ToastService.showError(msg);
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    }
  }

  Future<void> updateBirthday(DateTime? birthday) async {
    if (!_ensureReady('updateBirthday')) return;
    final userId = SupabaseClientService.currentUserId!;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final rows = await SupabaseClientService.client.from('profiles').update({
        'birthday': birthday?.toIso8601String().split('T').first,
      }).eq('id', userId).select('id');
      if ((rows as List).isEmpty) {
        throw Exception('No se pudo actualizar — perfil no encontrado');
      }
      if (birthday != null) {
        state = state.copyWith(birthday: birthday, isLoading: false);
      } else {
        state = state.copyWith(clearBirthday: true, isLoading: false);
      }
    } catch (e) {
      debugPrint('ProfileNotifier.updateBirthday error: $e');
      final msg = ToastService.friendlyError(e);
      ToastService.showError(msg);
      state = state.copyWith(isLoading: false, error: msg);
    }
  }

  Future<void> updateGender(String? gender) async {
    if (!_ensureReady('updateGender')) return;
    final userId = SupabaseClientService.currentUserId!;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final rows = await SupabaseClientService.client.from('profiles').update({
        'gender': gender,
      }).eq('id', userId).select('id');
      if ((rows as List).isEmpty) {
        throw Exception('No se pudo actualizar — perfil no encontrado');
      }
      if (gender != null) {
        state = state.copyWith(gender: gender, isLoading: false);
      } else {
        state = state.copyWith(clearGender: true, isLoading: false);
      }
    } catch (e) {
      debugPrint('ProfileNotifier.updateGender error: $e');
      final msg = ToastService.friendlyError(e);
      ToastService.showError(msg);
      state = state.copyWith(isLoading: false, error: msg);
    }
  }

  Future<bool> updateUsername(String username) async {
    if (!_ensureReady('updateUsername')) return false;
    final userId = SupabaseClientService.currentUserId!;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final rows = await SupabaseClientService.client
          .from('profiles')
          .update({'username': username})
          .eq('id', userId)
          .select('id');
      if ((rows as List).isEmpty) {
        throw Exception('No se pudo actualizar — perfil no encontrado');
      }
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      debugPrint('ProfileNotifier.updateUsername error: $e');
      final msg = ToastService.friendlyError(e);
      ToastService.showError(msg);
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    }
  }

  Future<bool> checkUsernameAvailable(String username) async {
    if (!SupabaseClientService.isInitialized) return false;
    try {
      // Use RPC function that bypasses RLS to check all usernames
      final result = await SupabaseClientService.client
          .rpc('check_username_available', params: {'username_to_check': username});
      return result == true;
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

/// Session-only temporary location override for search.
/// Resets when app restarts. Used instead of GPS for booking search.
final tempSearchLocationProvider = StateProvider<PlaceLocation?>((ref) => null);
