import 'package:beautycita/models/provider.dart';
import 'package:beautycita/services/supabase_client.dart';

class ProviderRepository {
  /// Get providers whose service_categories contain the given category.
  /// When [lat]/[lng]/[radiusKm] are provided, uses the nearby_businesses RPC
  /// for geo-sorted results. Otherwise falls back to alphabetical order.
  Future<List<Provider>> getProvidersByCategory(
    String category, {
    double? lat,
    double? lng,
    double radiusKm = 15,
    int limit = 50,
  }) async {
    if (!SupabaseClientService.isInitialized) return [];

    // Geo-filtered path: use nearby_businesses RPC
    if (lat != null && lng != null) {
      final response = await SupabaseClientService.client.rpc(
        'nearby_businesses',
        params: {
          'p_lat': lat,
          'p_lng': lng,
          'p_radius_km': radiusKm,
          'p_category': category,
        },
      );
      return (response as List)
          .take(limit)
          .map((json) => Provider.fromJson(json as Map<String, dynamic>))
          .toList();
    }

    // No geo — alphabetical fallback
    final response = await SupabaseClientService.client
        .from('businesses')
        .select()
        .contains('service_categories', [category])
        .eq('is_active', true)
        .eq('is_verified', true)
        .order('name', ascending: true)
        .limit(limit);

    return (response as List)
        .map((json) => Provider.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Search providers using the search_providers RPC function.
  Future<List<Provider>> searchProviders(String query) async {
    final response = await SupabaseClientService.client
        .rpc('search_businesses', params: {'p_query': query});

    return (response as List)
        .map((json) => Provider.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get a single provider by ID.
  Future<Provider?> getProvider(String id) async {
    final response = await SupabaseClientService.client
        .from('businesses')
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
        .from('services')
        .select()
        .eq('business_id', providerId)
        .eq('is_active', true);

    if (category != null) {
      query = query.eq('category', category);
    }

    final response = await query.order('category').order('name');

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
        .rpc('nearby_businesses', params: params);

    return (response as List)
        .map((json) => Provider.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
