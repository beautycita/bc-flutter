import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:beautycita/services/btcpay_service.dart';
import 'package:beautycita/services/toast_service.dart';

/// State for BTCPay invoice flow
class BTCPayState {
  final bool isLoading;
  final BTCPayInvoice? invoice;
  final String? error;
  final String? successMessage;

  const BTCPayState({
    this.isLoading = false,
    this.invoice,
    this.error,
    this.successMessage,
  });

  BTCPayState copyWith({
    bool? isLoading,
    BTCPayInvoice? invoice,
    String? error,
    String? successMessage,
  }) {
    return BTCPayState(
      isLoading: isLoading ?? this.isLoading,
      invoice: invoice ?? this.invoice,
      error: error,
      successMessage: successMessage,
    );
  }
}

/// Provider for BTCPay invoice creation and checkout flow
class BTCPayNotifier extends StateNotifier<BTCPayState> {
  BTCPayNotifier() : super(const BTCPayState());

  /// Create a Bitcoin invoice and open checkout
  Future<bool> createAndOpenInvoice({
    required String serviceId,
    required String scheduledAt,
    String? staffId,
    String paymentType = 'full',
  }) async {
    state = state.copyWith(isLoading: true, error: null, successMessage: null);

    try {
      final invoice = await BTCPayService.createInvoice(
        serviceId: serviceId,
        scheduledAt: scheduledAt,
        staffId: staffId,
        paymentType: paymentType,
      );

      state = state.copyWith(
        isLoading: false,
        invoice: invoice,
      );

      // Open checkout in browser
      final checkoutUrl = Uri.parse(invoice.checkoutLink);
      if (await canLaunchUrl(checkoutUrl)) {
        await launchUrl(
          checkoutUrl,
          mode: LaunchMode.externalApplication,
        );
        return true;
      } else {
        throw Exception('Could not open Bitcoin checkout');
      }
    } catch (e) {
      final msg = ToastService.friendlyError(e);
      state = state.copyWith(
        isLoading: false,
        error: msg,
      );
      debugPrint('BTCPayNotifier.createAndOpenInvoice error: $e');
      return false;
    }
  }

  /// Clear state
  void reset() {
    state = const BTCPayState();
  }

  /// Clear messages
  void clearMessages() {
    state = state.copyWith(error: null, successMessage: null);
  }
}

final btcpayProvider = StateNotifierProvider<BTCPayNotifier, BTCPayState>((ref) {
  return BTCPayNotifier();
});
