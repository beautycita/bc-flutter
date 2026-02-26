import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/services/btcpay_service.dart';
import 'package:beautycita/services/supabase_client.dart';
import 'package:beautycita/services/toast_service.dart';

class BtcWalletState {
  final bool isLoading;
  final bool totpEnabled;
  final String? otpauthUri;
  final String? totpSecret;
  final String? currentAddress;
  final DateTime? addressCreatedAt;
  final double confirmedBtc;
  final double pendingBtc;
  final List<BtcDeposit> deposits;
  final BtcPrice? price;
  final String? error;
  final String? successMessage;

  const BtcWalletState({
    this.isLoading = false,
    this.totpEnabled = false,
    this.otpauthUri,
    this.totpSecret,
    this.currentAddress,
    this.addressCreatedAt,
    this.confirmedBtc = 0,
    this.pendingBtc = 0,
    this.deposits = const [],
    this.price,
    this.error,
    this.successMessage,
  });

  BtcWalletState copyWith({
    bool? isLoading,
    bool? totpEnabled,
    String? otpauthUri,
    bool clearOtpauth = false,
    String? totpSecret,
    bool clearTotpSecret = false,
    String? currentAddress,
    DateTime? addressCreatedAt,
    double? confirmedBtc,
    double? pendingBtc,
    List<BtcDeposit>? deposits,
    BtcPrice? price,
    String? error,
    String? successMessage,
  }) {
    return BtcWalletState(
      isLoading: isLoading ?? this.isLoading,
      totpEnabled: totpEnabled ?? this.totpEnabled,
      otpauthUri: clearOtpauth ? null : (otpauthUri ?? this.otpauthUri),
      totpSecret: clearTotpSecret ? null : (totpSecret ?? this.totpSecret),
      currentAddress: currentAddress ?? this.currentAddress,
      addressCreatedAt: addressCreatedAt ?? this.addressCreatedAt,
      confirmedBtc: confirmedBtc ?? this.confirmedBtc,
      pendingBtc: pendingBtc ?? this.pendingBtc,
      deposits: deposits ?? this.deposits,
      price: price ?? this.price,
      error: error,
      successMessage: successMessage,
    );
  }

  double get balanceMxn {
    if (price == null || price!.mxn <= 0) return 0;
    return confirmedBtc * price!.mxn;
  }
}

class BtcWalletNotifier extends StateNotifier<BtcWalletState> {
  Timer? _priceTimer;

  BtcWalletNotifier() : super(const BtcWalletState());

  Future<Map<String, dynamic>?> _callEdge(Map<String, dynamic> body) async {
    if (!SupabaseClientService.isInitialized) {
      debugPrint('btc-wallet: Supabase not initialized');
      return null;
    }
    final action = body['action'] ?? 'unknown';
    debugPrint('btc-wallet: calling action=$action');
    try {
      final response = await SupabaseClientService.client.functions
          .invoke('btc-wallet', body: body)
          .timeout(const Duration(seconds: 15));
      debugPrint('btc-wallet: action=$action status=${response.status}');
      final data = response.data as Map<String, dynamic>?;
      if (response.status != 200) {
        throw Exception(data?['error'] ?? 'Error del servidor (${response.status})');
      }
      return data;
    } catch (e) {
      debugPrint('btc-wallet: action=$action ERROR: $e');
      rethrow;
    }
  }

  /// Load everything on screen open
  Future<void> init() async {
    state = state.copyWith(isLoading: true, error: null);

    // Fetch price + TOTP status + wallet data in parallel
    final results = await Future.wait([
      BTCPayService.getPrice(),
      _callEdge({'action': 'totp_status'}).catchError((e) {
        debugPrint('btc-wallet init: totp_status failed: $e');
        return null;
      }),
      _callEdge({'action': 'get_wallet'}).catchError((e) {
        debugPrint('btc-wallet init: get_wallet failed: $e');
        return null;
      }),
    ]);

    final price = results[0] as BtcPrice?;
    final totpData = results[1] as Map<String, dynamic>?;
    final walletData = results[2] as Map<String, dynamic>?;

    List<BtcDeposit> deposits = [];
    try {
      deposits = (walletData?['deposits'] as List?)
              ?.map((d) => BtcDeposit.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [];
    } catch (e) {
      debugPrint('btc-wallet init: deposit parsing error: $e');
    }

    debugPrint('btc-wallet init: totpData=$totpData, walletData keys=${walletData?.keys}');

    if (totpData == null && walletData == null) {
      debugPrint('btc-wallet init: BOTH edge calls failed');
      ToastService.showError('Error cargando billetera — verifica tu conexion');
    }

    state = state.copyWith(
      isLoading: false,
      price: price,
      totpEnabled: totpData?['enabled'] == true,
      currentAddress: walletData?['current_address'] as String?,
      addressCreatedAt: walletData?['address_created_at'] != null
          ? DateTime.tryParse(walletData!['address_created_at'] as String)
          : null,
      confirmedBtc: (walletData?['confirmed_btc'] as num?)?.toDouble() ?? 0,
      pendingBtc: (walletData?['pending_btc'] as num?)?.toDouble() ?? 0,
      deposits: deposits,
    );

    // Start price polling every 30s
    _priceTimer?.cancel();
    _priceTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshPrice());
  }

  Future<void> _refreshPrice() async {
    final price = await BTCPayService.getPrice();
    if (price != null && mounted) {
      state = state.copyWith(price: price);
    }
  }

  /// Begin 2FA setup — returns otpauth URI for QR code
  Future<bool> setupTotp() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _callEdge({'action': 'totp_setup'});
      if (data == null) {
        state = state.copyWith(isLoading: false, error: 'Sin conexion');
        return false;
      }
      state = state.copyWith(
        isLoading: false,
        otpauthUri: data['otpauth_uri'] as String?,
        totpSecret: data['secret'] as String?,
      );
      return true;
    } catch (e) {
      final msg = ToastService.friendlyError(e);
      ToastService.showError(msg);
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    }
  }

  /// Verify 2FA setup with 6-digit code
  Future<bool> verifyTotp(String code) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _callEdge({'action': 'totp_verify', 'code': code});
      if (data?['success'] == true) {
        state = state.copyWith(
          isLoading: false,
          totpEnabled: true,
          clearOtpauth: true,
          clearTotpSecret: true,
          successMessage: '2FA activado correctamente',
        );
        ToastService.showSuccess('2FA activado correctamente');
        return true;
      }
      state = state.copyWith(isLoading: false, error: data?['error'] as String?);
      return false;
    } catch (e) {
      final msg = ToastService.friendlyError(e);
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    }
  }

  /// Generate new deposit address (requires TOTP code)
  Future<bool> generateAddress(String totpCode) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _callEdge({
        'action': 'generate_address',
        'code': totpCode,
      });
      if (data == null) {
        state = state.copyWith(isLoading: false, error: 'Sin conexion');
        return false;
      }
      final address = data['address'] as String?;
      if (address != null) {
        state = state.copyWith(
          isLoading: false,
          currentAddress: address,
          addressCreatedAt: DateTime.now(),
          successMessage: 'Direccion generada',
        );
        ToastService.showSuccess('Direccion generada');
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        error: data['error'] as String? ?? 'Error desconocido',
      );
      return false;
    } catch (e) {
      final msg = ToastService.friendlyError(e);
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    }
  }

  /// Withdraw BTC to external address (requires TOTP code)
  Future<Map<String, dynamic>?> withdraw({
    required String destination,
    required double amountBtc,
    required String totpCode,
    bool sendAll = false,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _callEdge({
        'action': 'withdraw',
        'destination': destination,
        'amount_btc': amountBtc,
        'code': totpCode,
        'send_all': sendAll,
      });
      if (data == null) {
        state = state.copyWith(isLoading: false, error: 'Sin conexion');
        return null;
      }
      if (data['success'] == true) {
        ToastService.showSuccess('Retiro enviado: ${data['txid']?.toString().substring(0, 12)}...');
        await refreshAll();
        return data;
      }
      final error = data['error'] as String? ?? 'Error desconocido';
      state = state.copyWith(isLoading: false, error: error);
      return null;
    } catch (e) {
      final msg = ToastService.friendlyError(e);
      state = state.copyWith(isLoading: false, error: msg);
      return null;
    }
  }

  /// Refresh wallet data + price. On manual refresh, also sync deposits from BTCPay.
  Future<void> refreshAll({bool syncDeposits = true}) async {
    state = state.copyWith(isLoading: true);

    // Sync deposits from BTCPay first (fire-and-forget if slow)
    if (syncDeposits) {
      _callEdge({'action': 'sync_deposits'}).catchError((_) => null);
      // Give it a moment, then fetch wallet data
      await Future.delayed(const Duration(milliseconds: 500));
    }

    final results = await Future.wait([
      BTCPayService.getPrice(),
      _callEdge({'action': 'get_wallet'}).catchError((_) => null),
    ]);

    final price = results[0] as BtcPrice?;
    final walletData = results[1] as Map<String, dynamic>?;
    List<BtcDeposit> deposits = state.deposits;
    try {
      deposits = (walletData?['deposits'] as List?)
              ?.map((d) => BtcDeposit.fromJson(d as Map<String, dynamic>))
              .toList() ??
          state.deposits;
    } catch (e) {
      debugPrint('btc-wallet refreshAll: deposit parsing error: $e');
    }

    state = state.copyWith(
      isLoading: false,
      price: price ?? state.price,
      currentAddress: walletData?['current_address'] as String? ?? state.currentAddress,
      confirmedBtc: (walletData?['confirmed_btc'] as num?)?.toDouble() ?? state.confirmedBtc,
      pendingBtc: (walletData?['pending_btc'] as num?)?.toDouble() ?? state.pendingBtc,
      deposits: deposits,
    );
  }

  @override
  void dispose() {
    _priceTimer?.cancel();
    super.dispose();
  }
}

final btcWalletProvider =
    StateNotifierProvider.autoDispose<BtcWalletNotifier, BtcWalletState>((ref) {
  final notifier = BtcWalletNotifier();
  ref.onDispose(() => notifier.dispose());
  return notifier;
});

/// Standalone price provider for quick access elsewhere
final btcPriceProvider = FutureProvider.autoDispose<BtcPrice?>((ref) async {
  return BTCPayService.getPrice();
});
