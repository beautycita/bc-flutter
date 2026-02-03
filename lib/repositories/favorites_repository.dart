import 'package:beautycita/services/supabase_client.dart';

class FavoritesRepository {
  /// Fetch all business IDs the current user has favorited.
  Future<Set<String>> getFavoriteBusinessIds() async {
    final userId = SupabaseClientService.currentUserId;
    if (userId == null) return {};

    final response = await SupabaseClientService.client
        .from('favorites')
        .select('business_id')
        .eq('user_id', userId);

    return (response as List)
        .map((row) => row['business_id'] as String)
        .toSet();
  }

  /// Add a business to the current user's favorites.
  Future<void> addFavorite(String businessId) async {
    final userId = SupabaseClientService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    await SupabaseClientService.client.from('favorites').insert({
      'user_id': userId,
      'business_id': businessId,
    });
  }

  /// Remove a business from the current user's favorites.
  Future<void> removeFavorite(String businessId) async {
    final userId = SupabaseClientService.currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    await SupabaseClientService.client
        .from('favorites')
        .delete()
        .eq('user_id', userId)
        .eq('business_id', businessId);
  }
}
