import 'package:beautycita/models/provider.dart';
import 'package:beautycita/services/supabase_client.dart';

class ProviderRepository {
  /// Get providers whose service_categories contain the given category,
  /// ordered by rating descending.
  Future<List<Provider>> getProvidersByCategory(String category) async {
    final response = await SupabaseClientService.client
        .from('providers')
        .select()
        .contains('service_categories', [category])
        .order('rating', ascending: false);

    return (response as List)
        .map((json) => Provider.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Search providers using the search_providers RPC function.
  Future<List<Provider>> searchProviders(String query) async {
    final response = await SupabaseClientService.client
        .rpc('search_providers', params: {'search_query': query});

    return (response as List)
        .map((json) => Provider.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get a single provider by ID.
  Future<Provider?> getProvider(String id) async {
    final response = await SupabaseClientService.client
        .from('providers')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Provider.fromJson(response);
  }

  /// Get services for a provider, optionally filtered by category.
  Future<List<ProviderService>> getProviderServices(
    String providerId, {
    String? category,
  }) async {
    var query = SupabaseClientService.client
        .from('provider_services')
        .select()
        .eq('provider_id', providerId);

    if (category != null) {
      query = query.eq('category', category);
    }

    final response = await query.order('category').order('service_name');

    return (response as List)
        .map((json) => ProviderService.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get nearby providers using the nearby_providers RPC function.
  Future<List<Provider>> getNearbyProviders(
    double lat,
    double lng, {
    double radiusKm = 10,
    String? category,
  }) async {
    final params = <String, dynamic>{
      'p_lat': lat,
      'p_lng': lng,
      'p_radius_km': radiusKm,
    };

    if (category != null) {
      params['p_category'] = category;
    }

    final response = await SupabaseClientService.client
        .rpc('nearby_providers', params: params);

    return (response as List)
        .map((json) => Provider.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
