/// Dart wrapper around Stripe.js for Flutter web payments.
///
/// Uses `dart:js_interop` and `dart:js_interop_unsafe` to call
/// Stripe.js methods loaded via `<script src="https://js.stripe.com/v3/">`.
///
/// This file only compiles on web targets — that is fine because it is
/// only used by the web project.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Grab the global `Stripe` constructor from `window`.
JSFunction get _stripeConstructor =>
    globalContext.getProperty<JSFunction>('Stripe'.toJS);

/// Lightweight interop wrapper around Stripe.js.
///
/// Usage:
/// ```dart
/// final stripe = StripeWeb('pk_test_...');
/// stripe.mountPaymentElement('pi_..._secret_...', 'payment-element');
/// final error = await stripe.confirmPayment('https://beautycita.com/reservar');
/// stripe.dispose();
/// ```
class StripeWeb {
  late final JSObject _stripe;
  JSObject? _elements;
  JSObject? _paymentElement;

  /// Create a Stripe instance with the given publishable key.
  StripeWeb(String publishableKey) {
    _stripe = _stripeConstructor.callAsConstructor<JSObject>(
      publishableKey.toJS,
    );
  }

  /// Create a Stripe Elements instance bound to [clientSecret] and mount the
  /// Payment Element into the DOM node whose id is [containerId].
  ///
  /// The container must already exist in the DOM when this is called.
  /// For Flutter web, use an `HtmlElementView` to embed a `<div>` with the
  /// given id before calling this method.
  void mountPaymentElement(String clientSecret, String containerId) {
    // stripe.elements({ clientSecret: '...' })
    final options = <String, Object?>{'clientSecret': clientSecret}.jsify();
    _elements = _stripe.callMethod<JSObject>('elements'.toJS, options);

    // elements.create('payment')
    _paymentElement =
        _elements!.callMethod<JSObject>('create'.toJS, 'payment'.toJS);

    // paymentElement.mount('#container-id')
    _paymentElement!.callMethod<JSAny?>('mount'.toJS, '#$containerId'.toJS);
  }

  /// Confirm the payment using the currently mounted Payment Element.
  ///
  /// [returnUrl] is the page Stripe redirects to if a redirect is needed
  /// (e.g. 3-D Secure). Pass `redirect: 'if_required'` so that simple card
  /// payments complete without a redirect.
  ///
  /// Returns `null` on success, or an error message string on failure.
  Future<String?> confirmPayment(String returnUrl) async {
    if (_elements == null) {
      return 'Payment element not mounted. Call mountPaymentElement first.';
    }

    final confirmOptions = <String, Object?>{
      'elements': _elements,
      'confirmParams': <String, Object?>{'return_url': returnUrl},
      'redirect': 'if_required',
    }.jsify();

    final JSObject result = await (_stripe
            .callMethod<JSPromise<JSObject>>('confirmPayment'.toJS, confirmOptions))
        .toDart;

    // The result object is { error?: { message: string } } or
    // { paymentIntent: { status: string } }
    final error = result['error'];
    if (error != null) {
      final errorObj = error as JSObject;
      final message = errorObj['message'];
      if (message != null) {
        return (message as JSString).toDart;
      }
      return 'Payment failed with unknown error.';
    }

    return null; // Success
  }

  /// Unmount and clean up the payment element.
  void dispose() {
    if (_paymentElement != null) {
      _paymentElement!.callMethod<JSAny?>('destroy'.toJS);
      _paymentElement = null;
    }
    _elements = null;
  }
}
