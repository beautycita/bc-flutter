import 'package:url_launcher/url_launcher.dart';

/// Uber deep link integration — opens the Uber app with pre-filled
/// pickup and dropoff locations. Customer books and pays on their own account.
class UberService {
  UberService();

  /// Open Uber with pre-filled pickup → salon (outbound trip).
  Future<bool> openRideToSalon({
    required double salonLat,
    required double salonLng,
    required String salonName,
    String? salonAddress,
  }) {
    return _openUber(
      pickupNickname: 'Mi ubicacion',
      dropLat: salonLat,
      dropLng: salonLng,
      dropNickname: salonName,
      dropAddress: salonAddress,
    );
  }

  /// Open Uber with pre-filled salon → home (return trip).
  Future<bool> openRideHome({
    required double salonLat,
    required double salonLng,
    required String salonName,
  }) {
    return _openUber(
      pickupLat: salonLat,
      pickupLng: salonLng,
      pickupNickname: salonName,
    );
  }

  Future<bool> _openUber({
    double? pickupLat,
    double? pickupLng,
    String? pickupNickname,
    double? dropLat,
    double? dropLng,
    String? dropNickname,
    String? dropAddress,
  }) async {
    final params = <String, String>{
      'action': 'setPickup',
    };

    // Pickup: use "my_location" if no coordinates provided
    if (pickupLat != null && pickupLng != null) {
      params['pickup[latitude]'] = pickupLat.toString();
      params['pickup[longitude]'] = pickupLng.toString();
      if (pickupNickname != null) {
        params['pickup[nickname]'] = pickupNickname;
      }
    }

    // Dropoff
    if (dropLat != null && dropLng != null) {
      params['dropoff[latitude]'] = dropLat.toString();
      params['dropoff[longitude]'] = dropLng.toString();
      if (dropNickname != null) {
        params['dropoff[nickname]'] = dropNickname;
      }
      if (dropAddress != null) {
        params['dropoff[formatted_address]'] = dropAddress;
      }
    }

    // Universal link — works whether Uber app is installed or not.
    // If installed: opens app directly. If not: redirects to app store.
    final uri = Uri.https('m.uber.com', '/ul/', params);

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
