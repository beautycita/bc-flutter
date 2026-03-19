import 'package:beautycita_core/models.dart';
import 'package:beautycita/services/supabase_client.dart';

class ProductService {
  /// Fetch all products for a business, ordered by category then name.
  Future<List<Product>> fetchProducts(String businessId) async {
    if (!SupabaseClientService.isInitialized) return [];
    final client = SupabaseClientService.client;

    final data = await client
        .from('products')
        .select()
        .eq('business_id', businessId)
        .order('category')
        .order('name');

    return (data as List).map((r) => Product.fromJson(r)).toList();
  }

  /// Insert a new product and return the created record.
  Future<Product> createProduct(Product product) async {
    final client = SupabaseClientService.client;

    final result = await client
        .from('products')
        .insert(product.toJson())
        .select()
        .single();

    return Product.fromJson(result);
  }

  /// Update an existing product and return the updated record.
  Future<Product> updateProduct(Product product) async {
    final client = SupabaseClientService.client;

    final result = await client
        .from('products')
        .update(product.toJson())
        .eq('id', product.id)
        .select()
        .single();

    return Product.fromJson(result);
  }

  /// Delete a product by ID.
  Future<void> deleteProduct(String productId) async {
    if (!SupabaseClientService.isInitialized) return;
    final client = SupabaseClientService.client;

    await client.from('products').delete().eq('id', productId);
  }

  /// Toggle the in_stock flag for a product.
  Future<void> toggleStock(String productId, bool inStock) async {
    if (!SupabaseClientService.isInitialized) return;
    final client = SupabaseClientService.client;

    await client
        .from('products')
        .update({'in_stock': inStock})
        .eq('id', productId);
  }

  /// Returns true if the business has POS enabled.
  Future<bool> isPosEnabled(String businessId) async {
    if (!SupabaseClientService.isInitialized) return false;
    final client = SupabaseClientService.client;

    final result = await client
        .from('businesses')
        .select('pos_enabled')
        .eq('id', businessId)
        .single();

    return result['pos_enabled'] as bool? ?? false;
  }

  /// Enable POS for a business by setting pos_enabled = true.
  Future<void> enablePos(String businessId) async {
    if (!SupabaseClientService.isInitialized) return;
    final client = SupabaseClientService.client;

    await client
        .from('businesses')
        .update({'pos_enabled': true})
        .eq('id', businessId);
  }

  /// Disable POS for a business by setting pos_enabled = false.
  Future<void> disablePos(String businessId) async {
    if (!SupabaseClientService.isInitialized) return;
    final client = SupabaseClientService.client;

    await client
        .from('businesses')
        .update({'pos_enabled': false})
        .eq('id', businessId);
  }

  /// Record acceptance of the POS seller agreement for a specific version.
  Future<void> acceptAgreement(String businessId, String version) async {
    if (!SupabaseClientService.isInitialized) return;
    final client = SupabaseClientService.client;

    await client.from('pos_agreements').insert({
      'business_id': businessId,
      'agreement_type': 'seller',
      'agreement_version': version,
    });
  }

  /// Returns true if the business has accepted the given agreement version.
  Future<bool> isAgreementAccepted(String businessId, String version) async {
    if (!SupabaseClientService.isInitialized) return false;
    final client = SupabaseClientService.client;

    final result = await client
        .from('pos_agreements')
        .select('id')
        .eq('business_id', businessId)
        .eq('agreement_type', 'seller')
        .eq('agreement_version', version)
        .maybeSingle();

    return result != null;
  }

  /// Post a product to the inspiration feed by creating a showcase entry.
  Future<ProductShowcase> createShowcase({
    required String businessId,
    required String productId,
    String? caption,
  }) async {
    final client = SupabaseClientService.client;

    final result = await client
        .from('product_showcases')
        .insert({
          'business_id': businessId,
          'product_id': productId,
          'caption': caption,
        })
        .select()
        .single();

    return ProductShowcase.fromJson(result);
  }

  /// Fetch all showcases for a business, newest first.
  Future<List<ProductShowcase>> fetchShowcases(String businessId) async {
    if (!SupabaseClientService.isInitialized) return [];
    final client = SupabaseClientService.client;

    final data = await client
        .from('product_showcases')
        .select()
        .eq('business_id', businessId)
        .order('created_at', ascending: false);

    return (data as List).map((r) => ProductShowcase.fromJson(r)).toList();
  }

  /// Delete a showcase entry by ID.
  Future<void> deleteShowcase(String showcaseId) async {
    if (!SupabaseClientService.isInitialized) return;
    final client = SupabaseClientService.client;

    await client.from('product_showcases').delete().eq('id', showcaseId);
  }
}
