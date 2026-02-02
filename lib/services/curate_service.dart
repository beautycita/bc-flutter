import 'supabase_client.dart';
import '../models/curate_result.dart';

/// Calls the curate-results edge function — the intelligence engine.
class CurateService {
  /// Fetches 3 curated result cards for the given service + location.
  Future<CurateResponse> curateResults(CurateRequest request) async {
    if (!SupabaseClientService.isInitialized) {
      throw Exception('Supabase not initialized');
    }

    final client = SupabaseClientService.client;

    final response = await client.functions.invoke(
      'curate-results',
      body: request.toJson(),
    );

    if (response.status != 200) {
      final errorBody = response.data;
      final message = errorBody is Map ? errorBody['error'] : 'Unknown error';
      throw CurateException(
        'curate-results failed (${response.status}): $message',
        statusCode: response.status,
      );
    }

    final data = response.data as Map<String, dynamic>;
    return CurateResponse.fromJson(data);
  }
}

class CurateException implements Exception {
  final String message;
  final int statusCode;

  CurateException(this.message, {this.statusCode = 0});

  @override
  String toString() => message;
}
