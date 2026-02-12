import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:beautycita/services/toast_service.dart';
import '../services/uber_service.dart';
import 'booking_flow_provider.dart';

// ---------------------------------------------------------------------------
// Uber Link State
// ---------------------------------------------------------------------------

class UberLinkState {
  final bool isLinked;
  final bool isLoading;
  final String? error;
  final bool justLinked;

  const UberLinkState({
    this.isLinked = false,
    this.isLoading = false,
    this.error,
    this.justLinked = false,
  });

  UberLinkState copyWith({
    bool? isLinked,
    bool? isLoading,
    String? error,
    bool? justLinked,
  }) {
    return UberLinkState(
      isLinked: isLinked ?? this.isLinked,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      justLinked: justLinked ?? this.justLinked,
    );
  }
}

// ---------------------------------------------------------------------------
// Uber Link Notifier
// ---------------------------------------------------------------------------

class UberLinkNotifier extends StateNotifier<UberLinkState> {
  final UberService _uberService;

  UberLinkNotifier(this._uberService) : super(const UberLinkState()) {
    checkStatus();
  }

  Future<void> checkStatus() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final linked = await _uberService.isLinked();
      state = state.copyWith(isLinked: linked, isLoading: false);
    } catch (e) {
      debugPrint('Uber status check error: $e');
      final msg = ToastService.friendlyError(e);
      ToastService.showError(msg);
      state = state.copyWith(isLoading: false, error: msg);
    }
  }

  Future<void> initiateLink() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final url = _uberService.buildAuthUrl();
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) {
        const msg = 'No se pudo abrir el navegador';
        ToastService.showError(msg);
        state = state.copyWith(isLoading: false, error: msg);
      } else {
        // Keep loading state — will resolve when callback arrives
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      debugPrint('Uber link initiate error: $e');
      final msg = ToastService.friendlyError(e);
      ToastService.showError(msg);
      state = state.copyWith(isLoading: false, error: msg);
    }
  }

  Future<void> handleCallback(String code) async {
    debugPrint('[UberLink] handleCallback called with code: ${code.substring(0, 8)}...');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final success = await _uberService.linkAccount(code);
      debugPrint('[UberLink] linkAccount result: $success');
      if (success) {
        state = state.copyWith(
          isLinked: true,
          isLoading: false,
          justLinked: true,
        );
        // Clear justLinked flag after a brief delay
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          state = state.copyWith(justLinked: false);
        }
      } else {
        const msg = 'No se pudo vincular Uber';
        ToastService.showError(msg);
        state = state.copyWith(isLoading: false, error: msg);
      }
    } catch (e) {
      debugPrint('Uber callback error: $e');
      final msg = ToastService.friendlyError(e);
      ToastService.showError(msg);
      state = state.copyWith(isLoading: false, error: msg);
    }
  }

  Future<void> unlink() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final success = await _uberService.unlinkAccount();
      if (success) {
        state = state.copyWith(isLinked: false, isLoading: false);
      } else {
        const msg = 'No se pudo desvincular Uber';
        ToastService.showError(msg);
        state = state.copyWith(isLoading: false, error: msg);
      }
    } catch (e) {
      debugPrint('Uber unlink error: $e');
      final msg = ToastService.friendlyError(e);
      ToastService.showError(msg);
      state = state.copyWith(isLoading: false, error: msg);
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final uberLinkProvider =
    StateNotifierProvider<UberLinkNotifier, UberLinkState>((ref) {
  final uberService = ref.watch(uberServiceProvider);
  return UberLinkNotifier(uberService);
});
