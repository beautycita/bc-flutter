import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:beautycita/models/provider.dart' as models;
import 'package:beautycita/providers/provider_provider.dart';
import 'package:beautycita/config/theme.dart';
import 'package:beautycita/config/constants.dart';

class ProviderListScreen extends ConsumerWidget {
  final String category;
  final String? subcategory;
  final Color categoryColor;

  const ProviderListScreen({
    super.key,
    required this.category,
    this.subcategory,
    this.categoryColor = BeautyCitaTheme.primaryRose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providersAsync = ref.watch(providersByCategoryProvider(category));
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: BeautyCitaTheme.backgroundWhite,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          subcategory ?? category,
          style: textTheme.titleLarge?.copyWith(
            color: categoryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: BeautyCitaTheme.backgroundWhite,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  categoryColor.withOpacity(0.0),
                  categoryColor.withOpacity(0.3),
                  categoryColor.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ),
      ),
      body: providersAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            color: BeautyCitaTheme.primaryRose,
            strokeWidth: 3,
          ),
        ),
        error: (error, stack) => _ErrorState(
          onRetry: () => ref.invalidate(providersByCategoryProvider(category)),
          categoryColor: categoryColor,
        ),
        data: (providers) {
          if (providers.isEmpty) {
            return _EmptyState(
              category: category,
              categoryColor: categoryColor,
            );
          }

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenPaddingHorizontal,
              vertical: AppConstants.screenPaddingVertical,
            ),
            itemCount: providers.length,
            itemBuilder: (context, index) {
              final provider = providers[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < providers.length - 1
                      ? AppConstants.cardSpacing
                      : 0,
                ),
                child: _ProviderCard(
                  provider: provider,
                  categoryColor: categoryColor,
                  category: category,
                  onTap: () => context.push('/provider/${provider.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Provider Card
// ---------------------------------------------------------------------------

class _ProviderCard extends StatelessWidget {
  final models.Provider provider;
  final Color categoryColor;
  final String category;
  final VoidCallback onTap;

  const _ProviderCard({
    required this.provider,
    required this.categoryColor,
    required this.category,
    required this.onTap,
  });

  Future<void> _launchPhone(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchWhatsApp(String number) async {
    final cleaned = number.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: BeautyCitaTheme.elevationCard,
      shadowColor: categoryColor.withOpacity(0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
      ),
      color: BeautyCitaTheme.backgroundWhite,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
        splashColor: categoryColor.withOpacity(0.08),
        highlightColor: categoryColor.withOpacity(0.04),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
            border: Border(
              left: BorderSide(
                color: categoryColor,
                width: 4,
              ),
            ),
          ),
          padding: const EdgeInsets.all(BeautyCitaTheme.spaceMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Name + Verified badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Provider photo or placeholder
                  _ProviderAvatar(
                    photoUrl: provider.photoUrl,
                    name: provider.name,
                    categoryColor: categoryColor,
                  ),
                  const SizedBox(width: BeautyCitaTheme.spaceMD),

                  // Name, rating, address
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name row
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                provider.name,
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: BeautyCitaTheme.textDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (provider.isVerified) ...[
                              const SizedBox(width: BeautyCitaTheme.spaceXS),
                              Icon(
                                Icons.verified,
                                color: categoryColor,
                                size: AppConstants.iconSizeSM,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: BeautyCitaTheme.spaceXS),

                        // Rating row
                        _RatingRow(
                          rating: provider.rating,
                          reviewsCount: provider.reviewsCount,
                          accentColor: categoryColor,
                        ),
                        const SizedBox(height: BeautyCitaTheme.spaceXS),

                        // Address
                        if (provider.address != null &&
                            provider.address!.isNotEmpty)
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: AppConstants.iconSizeSM - 4,
                                color: BeautyCitaTheme.textLight,
                              ),
                              const SizedBox(width: BeautyCitaTheme.spaceXS),
                              Flexible(
                                child: Text(
                                  '${provider.address}, ${provider.city}',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: BeautyCitaTheme.textLight,
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
                ],
              ),

              const SizedBox(height: BeautyCitaTheme.spaceMD),

              // Row 2: Service category chips
              if (provider.serviceCategories.isNotEmpty)
                Wrap(
                  spacing: BeautyCitaTheme.spaceSM,
                  runSpacing: BeautyCitaTheme.spaceXS,
                  children: provider.serviceCategories.map((cat) {
                    final isCurrentCategory =
                        cat.toLowerCase() == category.toLowerCase();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.paddingSM + 2,
                        vertical: AppConstants.paddingXS,
                      ),
                      decoration: BoxDecoration(
                        color: isCurrentCategory
                            ? categoryColor.withOpacity(0.15)
                            : BeautyCitaTheme.surfaceCream,
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusSM),
                        border: Border.all(
                          color: isCurrentCategory
                              ? categoryColor.withOpacity(0.4)
                              : BeautyCitaTheme.dividerLight,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: textTheme.labelSmall?.copyWith(
                          color: isCurrentCategory
                              ? categoryColor
                              : BeautyCitaTheme.textLight,
                          fontWeight: isCurrentCategory
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                    );
                  }).toList(),
                ),

              // Row 3: Contact actions
              if (provider.phone != null || provider.whatsapp != null) ...[
                const SizedBox(height: BeautyCitaTheme.spaceMD),
                Divider(
                  height: 1,
                  color: BeautyCitaTheme.dividerLight,
                ),
                const SizedBox(height: BeautyCitaTheme.spaceSM),
                Row(
                  children: [
                    // Phone number text
                    if (provider.phone != null) ...[
                      Icon(
                        Icons.phone_outlined,
                        size: AppConstants.iconSizeSM - 2,
                        color: BeautyCitaTheme.textLight,
                      ),
                      const SizedBox(width: BeautyCitaTheme.spaceXS),
                      Expanded(
                        child: Text(
                          provider.phone!,
                          style: textTheme.bodySmall?.copyWith(
                            color: BeautyCitaTheme.textLight,
                          ),
                        ),
                      ),
                    ] else
                      const Spacer(),

                    // Action buttons
                    if (provider.whatsapp != null)
                      _ContactButton(
                        icon: Icons.chat_outlined,
                        color: const Color(0xFF25D366),
                        tooltip: 'WhatsApp',
                        onTap: () => _launchWhatsApp(provider.whatsapp!),
                      ),
                    if (provider.whatsapp != null && provider.phone != null)
                      const SizedBox(width: BeautyCitaTheme.spaceSM),
                    if (provider.phone != null)
                      _ContactButton(
                        icon: Icons.phone,
                        color: categoryColor,
                        tooltip: 'Llamar',
                        onTap: () => _launchPhone(provider.phone!),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Provider Avatar
// ---------------------------------------------------------------------------

class _ProviderAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final Color categoryColor;

  const _ProviderAvatar({
    required this.photoUrl,
    required this.name,
    required this.categoryColor,
  });

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppConstants.avatarSizeLG,
      height: AppConstants.avatarSizeLG,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        color: categoryColor.withOpacity(0.1),
      ),
      clipBehavior: Clip.antiAlias,
      child: photoUrl != null && photoUrl!.isNotEmpty
          ? Image.network(
              photoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _AvatarFallback(
                initials: _initials,
                color: categoryColor,
              ),
            )
          : _AvatarFallback(
              initials: _initials,
              color: categoryColor,
            ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String initials;
  final Color color;

  const _AvatarFallback({
    required this.initials,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rating Row (star icons)
// ---------------------------------------------------------------------------

class _RatingRow extends StatelessWidget {
  final double? rating;
  final int reviewsCount;
  final Color accentColor;

  const _RatingRow({
    required this.rating,
    required this.reviewsCount,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (rating == null || rating == 0) {
      return Text(
        'Sin calificaciones',
        style: textTheme.bodySmall?.copyWith(
          color: BeautyCitaTheme.textLight,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Row(
      children: [
        // Star icons
        ...List.generate(5, (index) {
          final starPosition = index + 1;
          IconData icon;
          if (rating! >= starPosition) {
            icon = Icons.star_rounded;
          } else if (rating! >= starPosition - 0.5) {
            icon = Icons.star_half_rounded;
          } else {
            icon = Icons.star_outline_rounded;
          }
          return Icon(
            icon,
            size: AppConstants.iconSizeSM - 2,
            color: BeautyCitaTheme.secondaryGold,
          );
        }),

        const SizedBox(width: BeautyCitaTheme.spaceXS),

        // Rating number
        Text(
          rating!.toStringAsFixed(1),
          style: textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: BeautyCitaTheme.textDark,
          ),
        ),

        const SizedBox(width: BeautyCitaTheme.spaceXS),

        // Review count
        Text(
          '($reviewsCount)',
          style: textTheme.labelSmall?.copyWith(
            color: BeautyCitaTheme.textLight,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Contact Button (phone / whatsapp)
// ---------------------------------------------------------------------------

class _ContactButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ContactButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.radiusSM),
          child: SizedBox(
            width: AppConstants.iconTouchTarget,
            height: AppConstants.iconTouchTarget,
            child: Icon(
              icon,
              color: color,
              size: AppConstants.iconSizeMD,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty State
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final String category;
  final Color categoryColor;

  const _EmptyState({
    required this.category,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.screenPaddingHorizontal * 2,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: AppConstants.avatarSizeXL,
              height: AppConstants.avatarSizeXL,
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.store_outlined,
                size: AppConstants.iconSizeXL,
                color: categoryColor.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: BeautyCitaTheme.spaceLG),
            Text(
              'No hay salones disponibles\npara esta categoria',
              style: textTheme.titleMedium?.copyWith(
                color: BeautyCitaTheme.textLight,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: BeautyCitaTheme.spaceSM),
            Text(
              'Pronto agregaremos mas opciones en $category.',
              style: textTheme.bodySmall?.copyWith(
                color: BeautyCitaTheme.textLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error State
// ---------------------------------------------------------------------------

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  final Color categoryColor;

  const _ErrorState({
    required this.onRetry,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.screenPaddingHorizontal * 2,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: AppConstants.avatarSizeXL,
              height: AppConstants.avatarSizeXL,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: AppConstants.iconSizeXL,
                color: Colors.red.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: BeautyCitaTheme.spaceLG),
            Text(
              AppConstants.errorGeneric,
              style: textTheme.titleMedium?.copyWith(
                color: BeautyCitaTheme.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: BeautyCitaTheme.spaceSM),
            Text(
              'Verifica tu conexion e intenta de nuevo.',
              style: textTheme.bodySmall?.copyWith(
                color: BeautyCitaTheme.textLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: BeautyCitaTheme.spaceXL),
            SizedBox(
              width: 200,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: categoryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(200, AppConstants.minTouchHeight),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusLG),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
