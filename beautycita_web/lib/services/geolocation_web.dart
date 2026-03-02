/// Browser Geolocation API wrapper using dart:js_interop.
///
/// Requests the user's current position via `navigator.geolocation`.
/// Returns `(lat, lng)` on success, throws a Spanish-language error message
/// on denial or failure.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Get the user's current location via the browser Geolocation API.
/// Returns (latitude, longitude) or throws a [String] error on denial/failure.
Future<(double lat, double lng)> getWebLocation() async {
  final completer = Completer<(double, double)>();

  final navigator = globalContext['navigator'] as JSObject;
  final geolocation = navigator['geolocation'] as JSObject;

  geolocation.callMethod(
    'getCurrentPosition'.toJS,
    ((JSObject position) {
      final coords = position['coords'] as JSObject;
      final lat = (coords['latitude'] as JSNumber).toDartDouble;
      final lng = (coords['longitude'] as JSNumber).toDartDouble;
      completer.complete((lat, lng));
    }).toJS,
    ((JSObject error) {
      final code = (error['code'] as JSNumber).toDartInt;
      final message = switch (code) {
        1 => 'Permiso de ubicacion denegado',
        2 => 'Ubicacion no disponible',
        3 => 'Tiempo de espera agotado',
        _ => 'Error de ubicacion desconocido',
      };
      completer.completeError(message);
    }).toJS,
  );

  return completer.future;
}
