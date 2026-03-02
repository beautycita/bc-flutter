import 'package:beautycita_core/models.dart';
import 'package:beautycita_core/supabase.dart';

/// Calls the curate-results edge function and returns the engine response.
Future<CurateResponse> callCurateEngine({
  required String serviceType,
  required double lat,
  required double lng,
  Map<String, String>? followUpAnswers,
  String? userId,
}) async {
  final request = CurateRequest(
    serviceType: serviceType,
    location: LatLng(lat: lat, lng: lng),
    transportMode: 'car', // Always assume car for ranking
    followUpAnswers: followUpAnswers,
    userId: userId,
  );

  final response = await BCSupabase.client.functions.invoke(
    'curate-results',
    body: request.toJson(),
  );

  if (response.status != 200) {
    throw Exception('Error del motor: ${response.status}');
  }

  return CurateResponse.fromJson(response.data as Map<String, dynamic>);
}
