import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/models/provider.dart' as models;
import 'package:beautycita/repositories/provider_repository.dart';

/// Repository provider for ProviderRepository.
final providerRepositoryProvider = Provider<ProviderRepository>((ref) {
  return ProviderRepository();
});

/// Providers by category, fetched via getProvidersByCategory.
final providersByCategoryProvider =
    FutureProvider.family<List<models.Provider>, String>(
  (ref, category) async {
    final repository = ref.watch(providerRepositoryProvider);
    return repository.getProvidersByCategory(category);
  },
);

/// Single provider detail by ID.
final providerDetailProvider =
    FutureProvider.family<models.Provider?, String>(
  (ref, id) async {
    final repository = ref.watch(providerRepositoryProvider);
    return repository.getProvider(id);
  },
);

/// Provider services for a given provider, optionally filtered by category.
/// Parameter is a record of (providerId, category).
final providerServicesProvider =
    FutureProvider.family<List<models.ProviderService>, (String, String?)>(
  (ref, params) async {
    final (providerId, category) = params;
    final repository = ref.watch(providerRepositoryProvider);
    return repository.getProviderServices(providerId, category: category);
  },
);
