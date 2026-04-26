import 'package:beautycita_core/models.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:beautycita/services/supabase_client.dart';

class OrderService {
  Future<List<Order>> fetchBusinessOrders(String businessId) async {
    if (!SupabaseClientService.isInitialized) return [];
    final data = await SupabaseClientService.client
        .from(BCTables.orders)
        .select()
        .eq('business_id', businessId)
        .order('created_at', ascending: false);
    return (data as List).map((r) => Order.fromJson(r)).toList();
  }

  Future<List<Order>> fetchBuyerOrders() async {
    if (!SupabaseClientService.isInitialized) return [];
    final userId = SupabaseClientService.currentUserId;
    if (userId == null) return [];
    final data = await SupabaseClientService.client
        .from(BCTables.orders)
        .select()
        .eq('buyer_id', userId)
        .order('created_at', ascending: false);
    return (data as List).map((r) => Order.fromJson(r)).toList();
  }

  /// Atomic ship transition via mark_order_shipped RPC. Returns the
  /// claim_window_ends_at the server set, or null on failure.
  Future<DateTime?> markShipped(String orderId, String trackingNumber) async {
    if (!SupabaseClientService.isInitialized) return null;
    final res = await SupabaseClientService.client.rpc(
      'mark_order_shipped',
      params: {
        'p_order_id': orderId,
        'p_tracking_number': trackingNumber,
      },
    );
    final data = res as Map<String, dynamic>?;
    final ends = data?['claim_window_ends_at'];
    return ends is String ? DateTime.parse(ends) : null;
  }

  /// Optional ship-side "received" confirmation. Does NOT shorten claim window.
  Future<void> markDelivered(String orderId, {required String businessId}) async {
    if (!SupabaseClientService.isInitialized) return;
    await SupabaseClientService.client
        .from(BCTables.orders)
        .update({
          'status': 'delivered',
          'delivered_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', orderId)
        .eq('business_id', businessId);
  }

  /// Mint or refresh the buyer-side pickup QR. Returns cleartext token + expiry.
  Future<({String token, DateTime expiresAt})?> generatePickupQr(
      String orderId) async {
    if (!SupabaseClientService.isInitialized) return null;
    final res = await SupabaseClientService.client.functions.invoke(
      'generate-pickup-qr',
      body: {'order_id': orderId},
    );
    final data = res.data as Map<String, dynamic>?;
    if (data == null || data.containsKey('error')) return null;
    return (
      token: data['token'] as String,
      expiresAt: DateTime.parse(data['expires_at'] as String),
    );
  }

  /// Salon-side: scan a buyer's QR cleartext to mark the order delivered.
  Future<Map<String, dynamic>?> redeemPickupQr(String token) async {
    if (!SupabaseClientService.isInitialized) return null;
    final res = await SupabaseClientService.client.functions.invoke(
      'redeem-pickup-qr',
      body: {'token': token},
    );
    return res.data as Map<String, dynamic>?;
  }
}
