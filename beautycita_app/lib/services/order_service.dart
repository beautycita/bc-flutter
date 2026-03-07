import 'package:beautycita_core/models.dart';
import 'package:beautycita/services/supabase_client.dart';

class OrderService {
  /// Fetch orders for a business (salon owner view), newest first.
  Future<List<Order>> fetchBusinessOrders(String businessId) async {
    if (!SupabaseClientService.isInitialized) return [];
    final data = await SupabaseClientService.client
        .from('orders')
        .select()
        .eq('business_id', businessId)
        .order('created_at', ascending: false);

    return (data as List).map((r) => Order.fromJson(r)).toList();
  }

  /// Fetch orders for the current authenticated buyer, newest first.
  Future<List<Order>> fetchBuyerOrders() async {
    if (!SupabaseClientService.isInitialized) return [];
    final userId = SupabaseClientService.currentUserId;
    if (userId == null) return [];

    final data = await SupabaseClientService.client
        .from('orders')
        .select()
        .eq('buyer_id', userId)
        .order('created_at', ascending: false);

    return (data as List).map((r) => Order.fromJson(r)).toList();
  }

  /// Mark an order as shipped.
  Future<void> markShipped(String orderId) async {
    if (!SupabaseClientService.isInitialized) return;
    await SupabaseClientService.client
        .from('orders')
        .update({
          'status': 'shipped',
          'shipped_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', orderId);
  }

  /// Mark an order as delivered.
  Future<void> markDelivered(String orderId) async {
    if (!SupabaseClientService.isInitialized) return;
    await SupabaseClientService.client
        .from('orders')
        .update({
          'status': 'delivered',
          'delivered_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', orderId);
  }
}
