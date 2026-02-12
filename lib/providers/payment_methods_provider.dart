import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:beautycita/services/supabase_client.dart';
import 'package:beautycita/services/toast_service.dart';

class SavedCard {
  final String id;
  final String brand;
  final String last4;
  final int? expMonth;
  final int? expYear;

  const SavedCard({
    required this.id,
    required this.brand,
    required this.last4,
    this.expMonth,
    this.expYear,
  });

  factory SavedCard.fromJson(Map<String, dynamic> json) {
    return SavedCard(
      id: json['id'] as String,
      brand: json['brand'] as String? ?? 'unknown',
      last4: json['last4'] as String? ?? '****',
      expMonth: json['expMonth'] as int?,
      expYear: json['expYear'] as int?,
    );
  }

  String get displayBrand {
    return switch (brand) {
      'visa' => 'Visa',
      'mastercard' => 'Mastercard',
      'amex' => 'American Express',
      _ => brand[0].toUpperCase() + brand.substring(1),
    };
  }

  String get expiry => expMonth != null && expYear != null
      ? '${expMonth.toString().padLeft(2, '0')}/${expYear.toString().substring(2)}'
      : '';
}

class PaymentMethodsState {
  final List<SavedCard> cards;
  final bool isLoading;
  final String? error;
  final String? successMessage;

  const PaymentMethodsState({
    this.cards = const [],
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  PaymentMethodsState copyWith({
    List<SavedCard>? cards,
    bool? isLoading,
    String? error,
    String? successMessage,
  }) {
    return PaymentMethodsState(
      cards: cards ?? this.cards,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      successMessage: successMessage,
    );
  }
}

class PaymentMethodsNotifier extends StateNotifier<PaymentMethodsState> {
  PaymentMethodsNotifier() : super(const PaymentMethodsState()) {
    loadCards();
  }

  Future<Map<String, dynamic>?> _callEdge(Map<String, dynamic> body) async {
    if (!SupabaseClientService.isInitialized) return null;
    try {
      final response = await SupabaseClientService.client.functions
          .invoke('stripe-payment-methods', body: body);
      if (response.status != 200) {
        final data = response.data as Map<String, dynamic>?;
        throw Exception(data?['error'] ?? 'Error del servidor');
      }
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('PaymentMethods edge call error: $e');
      rethrow;
    }
  }

  Future<void> loadCards() async {
    state = state.copyWith(isLoading: true, error: null, successMessage: null);
    try {
      final data = await _callEdge({'action': 'list'});
      if (data == null) {
        state = state.copyWith(isLoading: false);
        return;
      }
      final cards = (data['cards'] as List?)
              ?.map((c) => SavedCard.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [];
      state = state.copyWith(cards: cards, isLoading: false);
    } catch (e) {
      final msg = ToastService.friendlyError(e);
      ToastService.showError(msg);
      state = state.copyWith(isLoading: false, error: msg);
    }
  }

  /// Creates a Setup Intent, presents Stripe PaymentSheet, then refreshes cards.
  Future<bool> addCard() async {
    state = state.copyWith(isLoading: true, error: null, successMessage: null);
    try {
      // 1. Get setup intent from backend
      final data = await _callEdge({'action': 'setup-intent'});
      if (data == null) {
        const msg = 'No se pudo conectar';
        ToastService.showError(msg);
        state = state.copyWith(isLoading: false, error: msg);
        return false;
      }

      final setupIntentSecret = data['setupIntent'] as String?;
      final ephemeralKey = data['ephemeralKey'] as String?;
      final customerId = data['customer'] as String?;

      debugPrint('[PaymentMethods] setupIntent: ${setupIntentSecret?.substring(0, 20)}...');
      debugPrint('[PaymentMethods] customerId: $customerId');
      debugPrint('[PaymentMethods] ephemeralKey: ${ephemeralKey?.substring(0, 20)}...');

      if (setupIntentSecret == null || ephemeralKey == null || customerId == null) {
        const msg = 'Respuesta incompleta del servidor';
        ToastService.showError(msg);
        state = state.copyWith(isLoading: false, error: msg);
        return false;
      }

      // 2. Init PaymentSheet in setup mode
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          setupIntentClientSecret: setupIntentSecret,
          merchantDisplayName: 'BeautyCita',
          customerId: customerId,
          customerEphemeralKeySecret: ephemeralKey,
          style: ThemeMode.system,
          returnURL: 'beautycita://stripe-redirect',
          billingDetailsCollectionConfiguration: const BillingDetailsCollectionConfiguration(
            name: CollectionMode.automatic,
            email: CollectionMode.automatic,
            address: AddressCollectionMode.automatic,
          ),
        ),
      );

      // 3. Present the sheet
      await Stripe.instance.presentPaymentSheet();

      // 4. Refresh card list
      ToastService.showSuccess('Tarjeta agregada exitosamente');
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Tarjeta agregada exitosamente',
      );
      await loadCards();
      return true;
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        state = state.copyWith(isLoading: false);
        return false;
      }
      final msg = e.error.localizedMessage ?? 'Error de Stripe';
      ToastService.showError(msg);
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    } catch (e) {
      final msg = ToastService.friendlyError(e);
      ToastService.showError(msg);
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    }
  }

  Future<void> removeCard(String paymentMethodId) async {
    state = state.copyWith(isLoading: true, error: null, successMessage: null);
    try {
      await _callEdge({
        'action': 'detach',
        'payment_method_id': paymentMethodId,
      });
      state = state.copyWith(
        cards: state.cards.where((c) => c.id != paymentMethodId).toList(),
        isLoading: false,
        successMessage: 'Tarjeta eliminada',
      );
    } catch (e) {
      final msg = ToastService.friendlyError(e);
      ToastService.showError(msg);
      state = state.copyWith(isLoading: false, error: msg);
    }
  }

  void clearMessages() {
    state = state.copyWith(error: null, successMessage: null);
  }
}

final paymentMethodsProvider =
    StateNotifierProvider<PaymentMethodsNotifier, PaymentMethodsState>((ref) {
  return PaymentMethodsNotifier();
});
