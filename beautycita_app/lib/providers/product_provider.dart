import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/models.dart' hide Provider;
import 'package:beautycita/services/product_service.dart';
import 'package:beautycita/providers/business_provider.dart';

/// Singleton ProductService instance.
final productServiceProvider = Provider<ProductService>((ref) => ProductService());

/// All products belonging to the current user's business.
final businessProductsProvider =
    FutureProvider.autoDispose<List<Product>>((ref) async {
  final biz = await ref.watch(currentBusinessProvider.future);
  if (biz == null) return [];
  final service = ref.read(productServiceProvider);
  return service.fetchProducts(biz['id'] as String);
});

/// Whether POS is enabled for the current user's business.
/// Reads directly from the business map to avoid an extra round-trip.
final posEnabledProvider = FutureProvider.autoDispose<bool>((ref) async {
  final biz = await ref.watch(currentBusinessProvider.future);
  if (biz == null) return false;
  return biz['pos_enabled'] as bool? ?? false;
});

/// Whether the current business has accepted the POS seller agreement (v1.0).
final posAgreementProvider = FutureProvider.autoDispose<bool>((ref) async {
  final biz = await ref.watch(currentBusinessProvider.future);
  if (biz == null) return false;
  final service = ref.read(productServiceProvider);
  return service.isAgreementAccepted(biz['id'] as String, '1.0');
});

/// All product showcases (feed posts) for the current user's business.
final businessShowcasesProvider =
    FutureProvider.autoDispose<List<ProductShowcase>>((ref) async {
  final biz = await ref.watch(currentBusinessProvider.future);
  if (biz == null) return [];
  final service = ref.read(productServiceProvider);
  return service.fetchShowcases(biz['id'] as String);
});
