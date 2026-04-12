import 'package:flutter/material.dart';
import 'package:beautycita/config/app_transitions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/providers/favorites_provider.dart';
import 'package:beautycita/services/supabase_client.dart';
import 'package:beautycita/models/provider.dart' as models;
import '../widgets/empty_state.dart';

/// Provider that fetches full business data for the user's favorited salons.
final _favoriteSalonsProvider =
    FutureProvider<List<models.Provider>>((ref) async {
  final favoriteIds = ref.watch(favoritesProvider);
  if (favoriteIds.isEmpty) return [];

  final userId = SupabaseClientService.currentUserId;
  if (userId == null) return [];

  final response = await SupabaseClientService.client
      .from('businesses')
      .select()
      .inFilter('id', favoriteIds.toList());

  return (response as List)
      .map((json) => models.Provider.fromJson(json))
      .toList();
});

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salonsAsync = ref.watch(_favoriteSalonsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Mis Favoritos',
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: salonsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            color: colorScheme.primary,
            strokeWidth: 3,
          ),
        ),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48,
                  color: colorScheme.error),
              const SizedBox(height: AppConstants.paddingMD),
              Text('Error al cargar favoritos',
                  style: textTheme.titleMedium),
              const SizedBox(height: AppConstants.paddingMD),
              TextButton(
                onPressed: () => ref.invalidate(_favoriteSalonsProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (salons) {
          if (salons.isEmpty) {
            return const EmptyState(
              icon: Icons.favorite_outline,
              message: 'Sin favoritos\nGuarda tus salones preferidos tocando el corazon.',
            );
          }

          return BcStaggeredList(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenPaddingHorizontal,
              vertical: AppConstants.screenPaddingVertical,
            ),
            children: [
              for (int i = 0; i < salons.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i < salons.length - 1
                        ? AppConstants.cardSpacing
                        : 0,
                  ),
                  child: _FavoriteSalonCard(
                    salon: salons[i],
                    onTap: () => context.push('/provider/${salons[i].id}'),
                    onBook: () =>
                        context.push('/booking/${salons[i].id}'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FavoriteSalonCard extends ConsumerWidget {
  final models.Provider salon;
  final VoidCallback onTap;
  final VoidCallback onBook;

  const _FavoriteSalonCard({
    required this.salon,
    required this.onTap,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isFav = ref.watch(favoritesProvider).contains(salon.id);

    return Card(
      elevation: AppConstants.elevationLow,
      shadowColor: colorScheme.primary.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      ),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Container(
                    width: AppConstants.avatarSizeLG,
                    height: AppConstants.avatarSizeLG,
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusSM),
                      color: colorScheme.primary.withValues(alpha: 0.1),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: salon.photoUrl != null && salon.photoUrl!.isNotEmpty
                        ? Image.network(
                            salon.photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Center(
                              child: Text(
                                salon.name.substring(0, 1).toUpperCase(),
                                style: textTheme.titleLarge?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              salon.name.substring(0, 1).toUpperCase(),
                              style: textTheme.titleLarge?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: AppConstants.paddingMD),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          salon.name,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppConstants.paddingXS),
                        // Rating
                        if (salon.rating != null && salon.rating! > 0)
                          Row(
                            children: [
                              ...List.generate(5, (index) {
                                final pos = index + 1;
                                IconData icon;
                                if (salon.rating! >= pos) {
                                  icon = Icons.star_rounded;
                                } else if (salon.rating! >= pos - 0.5) {
                                  icon = Icons.star_half_rounded;
                                } else {
                                  icon = Icons.star_outline_rounded;
                                }
                                return Icon(icon,
                                    size: 14,
                                    color: colorScheme.secondary);
                              }),
                              const SizedBox(width: 4),
                              Text(
                                salon.rating!.toStringAsFixed(1),
                                style: textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                ' (${salon.reviewsCount})',
                                style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: AppConstants.paddingXS),
                        // Address
                        if (salon.address != null)
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: 14,
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.5)),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '${salon.address}, ${salon.city}',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  // Heart toggle
                  IconButton(
                    icon: Icon(
                      isFav
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: isFav
                          ? Colors.redAccent
                          : colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    onPressed: () {
                      ref
                          .read(favoritesProvider.notifier)
                          .toggle(salon.id);
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.paddingSM),
              // Reservar button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onBook,
                  style: ElevatedButton.styleFrom(
                    minimumSize:
                        const Size(0, AppConstants.minTouchHeight),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusSM),
                    ),
                  ),
                  child: const Text('Reservar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
