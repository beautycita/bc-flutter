// Tests for the pure (non-Supabase) surface of payment_methods_provider.
//
// The notifier wraps a Supabase edge function + Stripe PaymentSheet, both
// unavailable in unit tests. Here we pin the value types:
//   - SavedCard.fromJson + default fallbacks
//   - SavedCard.displayBrand (visa/mc/amex + capitalised fallback)
//   - SavedCard.expiry formatting
//   - PaymentMethodsState defaults + copyWith semantics
//
// Regression note: PaymentMethodsState.copyWith *always replaces* error and
// successMessage (rather than preserving the previous value). That matches
// the clearMessages() UX pattern but is easy to break — pinned below.

import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita/providers/payment_methods_provider.dart';

void main() {
  group('SavedCard.fromJson', () {
    test('parses a fully populated card', () {
      final card = SavedCard.fromJson({
        'id': 'pm_123',
        'brand': 'visa',
        'last4': '4242',
        'expMonth': 8,
        'expYear': 2028,
      });
      expect(card.id, 'pm_123');
      expect(card.brand, 'visa');
      expect(card.last4, '4242');
      expect(card.expMonth, 8);
      expect(card.expYear, 2028);
    });

    test('falls back to "unknown" brand and "****" last4 on missing fields',
        () {
      final card = SavedCard.fromJson({'id': 'pm_456'});
      expect(card.brand, 'unknown');
      expect(card.last4, '****');
      expect(card.expMonth, isNull);
      expect(card.expYear, isNull);
    });
  });

  group('SavedCard.displayBrand', () {
    SavedCard card(String brand) =>
        SavedCard(id: 'pm', brand: brand, last4: '0000');

    test('visa -> Visa', () {
      expect(card('visa').displayBrand, 'Visa');
    });

    test('mastercard -> Mastercard', () {
      expect(card('mastercard').displayBrand, 'Mastercard');
    });

    test('amex -> American Express', () {
      expect(card('amex').displayBrand, 'American Express');
    });

    test('unknown brands are title-cased (first letter upper)', () {
      expect(card('discover').displayBrand, 'Discover');
      expect(card('unknown').displayBrand, 'Unknown');
    });
  });

  group('SavedCard.expiry', () {
    test('formats MM/YY with zero-padded month', () {
      final card = SavedCard(
          id: 'pm', brand: 'visa', last4: '0000', expMonth: 3, expYear: 2029);
      expect(card.expiry, '03/29');
    });

    test('returns empty string when either field is null', () {
      expect(
        SavedCard(id: 'pm', brand: 'visa', last4: '0000', expMonth: 3).expiry,
        '',
      );
      expect(
        SavedCard(id: 'pm', brand: 'visa', last4: '0000', expYear: 2029).expiry,
        '',
      );
      expect(
        SavedCard(id: 'pm', brand: 'visa', last4: '0000').expiry,
        '',
      );
    });
  });

  group('PaymentMethodsState defaults', () {
    test('has empty cards, not loading, no messages', () {
      const state = PaymentMethodsState();
      expect(state.cards, isEmpty);
      expect(state.isLoading, false);
      expect(state.error, isNull);
      expect(state.successMessage, isNull);
    });
  });

  group('PaymentMethodsState.copyWith', () {
    test('updates cards and isLoading', () {
      const state = PaymentMethodsState();
      final cards = [
        const SavedCard(id: 'pm_1', brand: 'visa', last4: '1111'),
      ];
      final next = state.copyWith(cards: cards, isLoading: true);
      expect(next.cards, hasLength(1));
      expect(next.isLoading, true);
    });

    test('clears error on subsequent copyWith (not preserved)', () {
      // Regression: copyWith intentionally REPLACES error/successMessage
      // rather than preserving this.error. This matches the clearMessages()
      // UX: calling any state transition wipes transient messages.
      const state = PaymentMethodsState();
      final withError = state.copyWith(error: 'Network down');
      expect(withError.error, 'Network down');

      final cleared = withError.copyWith(isLoading: true);
      expect(cleared.error, isNull,
          reason: 'error is not preserved across copyWith');
      expect(cleared.isLoading, true);
    });

    test('clears successMessage on subsequent copyWith (not preserved)', () {
      const state = PaymentMethodsState();
      final withMsg = state.copyWith(successMessage: 'Tarjeta agregada');
      expect(withMsg.successMessage, 'Tarjeta agregada');

      final cleared = withMsg.copyWith(isLoading: false);
      expect(cleared.successMessage, isNull,
          reason: 'successMessage is not preserved across copyWith');
    });

    test('preserves cards when not passed', () {
      const initial = PaymentMethodsState();
      final withCards = initial.copyWith(cards: [
        const SavedCard(id: 'pm_1', brand: 'visa', last4: '1111'),
      ]);
      final next = withCards.copyWith(isLoading: true);
      expect(next.cards, hasLength(1));
      expect(next.cards.first.id, 'pm_1');
    });
  });
}
