import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/models.dart' hide Provider;
import 'package:beautycita/services/order_service.dart';
import 'package:beautycita/providers/business_provider.dart';

final orderServiceProvider = Provider<OrderService>((ref) => OrderService());

/// Orders for the current business (salon owner view).
final businessOrdersProvider =
    FutureProvider.autoDispose<List<Order>>((ref) async {
  final biz = await ref.watch(currentBusinessProvider.future);
  if (biz == null) return [];
  final service = ref.read(orderServiceProvider);
  return service.fetchBusinessOrders(biz['id'] as String);
});

/// Orders for the current authenticated user (buyer view).
final buyerOrdersProvider =
    FutureProvider.autoDispose<List<Order>>((ref) async {
  final service = ref.read(orderServiceProvider);
  return service.fetchBuyerOrders();
});
