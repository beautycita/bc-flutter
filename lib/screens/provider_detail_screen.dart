import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:beautycita/models/provider.dart' as models;
import 'package:beautycita/providers/provider_provider.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/config/palettes.dart';
import '../config/theme_extension.dart';

class ProviderDetailScreen extends ConsumerWidget {
  final String providerId;

  const ProviderDetailScreen({
    super.key,
    required this.providerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providerAsync = ref.watch(providerDetailProvider(providerId));
    final servicesAsync =
        ref.watch(providerServicesProvider((providerId, null)));
    final colorScheme = Theme.of(context).colorScheme;

    return providerAsync.when(
      loading: () => Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: colorScheme.primary,
          ),
        ),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingLG),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: AppConstants.paddingMD),
                Text(
                  'No se pudo cargar el proveedor',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.paddingSM),
                Text(
                  error.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.paddingLG),
                ElevatedButton(
                  onPressed: () =>
                      ref.invalidate(providerDetailProvider(providerId)),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (provider) {
        if (provider == null) {
          return Scaffold(
            appBar: AppBar(leading: const BackButton()),
            body: const Center(
              child: Text('Proveedor no encontrado'),
            ),
          );
        }

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // -- SliverAppBar with provider photo --
              _buildSliverAppBar(context, provider),

              // -- Body content --
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.paddingMD,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppConstants.paddingMD),

                      // Name, rating, verified badge
                      _buildHeader(context, provider),

                      const SizedBox(height: AppConstants.paddingLG),

                      // Address
                      if (provider.address != null)
                        _buildAddressSection(context, provider),

                      // Contact buttons
                      if (provider.phone != null || provider.whatsapp != null)
                        _buildContactSection(context, provider),

                      // Social media links
                      if (provider.instagramHandle != null ||
                          provider.facebookUrl != null ||
                          provider.website != null)
                        _buildSocialSection(context, provider),

                      // Business hours
                      if (provider.hours != null &&
                          provider.hours!.isNotEmpty)
                        _buildHoursSection(context, provider),

                      // Services header
                      const SizedBox(height: AppConstants.paddingLG),
                      Text(
                        'Servicios',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: colorScheme.onSurface,
                                ),
                      ),
                      const SizedBox(height: AppConstants.paddingSM),
                    ],
                  ),
                ),
              ),

              // -- Services list --
              _buildServicesList(context, servicesAsync),

              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: AppConstants.paddingXXL),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // SliverAppBar
  // ---------------------------------------------------------------------------
  Widget _buildSliverAppBar(BuildContext context, models.Provider provider) {
    final colorScheme = Theme.of(context).colorScheme;

    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: colorScheme.primary,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: provider.photoUrl != null
            ? Image.network(
                provider.photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _buildGradientPlaceholder(context, provider.name),
              )
            : _buildGradientPlaceholder(context, provider.name),
      ),
    );
  }

  Widget _buildGradientPlaceholder(BuildContext context, String name) {
    final ext = Theme.of(context).extension<BCThemeExtension>()!;

    return Container(
      decoration: BoxDecoration(
        gradient: ext.primaryGradient,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.store_rounded,
              size: 64,
              color: Colors.white70,
            ),
            const SizedBox(height: AppConstants.paddingSM),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppConstants.paddingLG),
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header: name, rating, verified
  // ---------------------------------------------------------------------------
  Widget _buildHeader(BuildContext context, models.Provider provider) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name row with verified badge
        Row(
          children: [
            Expanded(
              child: Text(
                provider.name,
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            if (provider.isVerified)
              Container(
                margin: const EdgeInsets.only(left: AppConstants.paddingSM),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.paddingSM,
                  vertical: AppConstants.paddingXS,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusSM),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Verificado',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),

        const SizedBox(height: AppConstants.paddingSM),

        // Rating and review count
        Row(
          children: [
            ..._buildStarIcons(context, provider.rating ?? 0),
            const SizedBox(width: AppConstants.paddingSM),
            Text(
              provider.rating != null
                  ? provider.rating!.toStringAsFixed(1)
                  : '0.0',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.secondary,
              ),
            ),
            const SizedBox(width: AppConstants.paddingXS),
            Text(
              '(${provider.reviewsCount} ${provider.reviewsCount == 1 ? 'resena' : 'resenas'})',
              style: textTheme.bodySmall,
            ),
          ],
        ),

        // Business category chip
        if (provider.businessCategory != null) ...[
          const SizedBox(height: AppConstants.paddingSM),
          Chip(
            label: Text(provider.businessCategory!),
            backgroundColor: colorScheme.surface,
            side: BorderSide.none,
            padding: EdgeInsets.zero,
            labelStyle: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildStarIcons(BuildContext context, double rating) {
    final colorScheme = Theme.of(context).colorScheme;
    final stars = <Widget>[];
    for (int i = 1; i <= 5; i++) {
      if (rating >= i) {
        stars.add(Icon(Icons.star, size: 20, color: colorScheme.secondary));
      } else if (rating >= i - 0.5) {
        stars.add(Icon(Icons.star_half, size: 20, color: colorScheme.secondary));
      } else {
        stars.add(Icon(Icons.star_border, size: 20, color: Colors.grey.shade300));
      }
    }
    return stars;
  }

  // ---------------------------------------------------------------------------
  // Address section
  // ---------------------------------------------------------------------------
  Widget _buildAddressSection(BuildContext context, models.Provider provider) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.paddingMD),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.location_on_outlined,
            color: colorScheme.primary,
            size: 22,
          ),
          const SizedBox(width: AppConstants.paddingSM),
          Expanded(
            child: Text(
              '${provider.address}, ${provider.city}, ${provider.state}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Contact section: phone + WhatsApp
  // ---------------------------------------------------------------------------
  Widget _buildContactSection(BuildContext context, models.Provider provider) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.paddingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contacto',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppConstants.paddingSM),
          Row(
            children: [
              if (provider.phone != null)
                Expanded(
                  child: _ContactButton(
                    icon: Icons.phone_outlined,
                    label: 'Llamar',
                    onTap: () => _launchUrl('tel:${provider.phone}'),
                  ),
                ),
              if (provider.phone != null && provider.whatsapp != null)
                const SizedBox(width: AppConstants.paddingSM),
              if (provider.whatsapp != null)
                Expanded(
                  child: _ContactButton(
                    icon: Icons.chat_outlined,
                    label: 'WhatsApp',
                    color: kWhatsAppGreen,
                    onTap: () => _launchUrl(
                      'https://wa.me/${provider.whatsapp}',
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Social media section
  // ---------------------------------------------------------------------------
  Widget _buildSocialSection(BuildContext context, models.Provider provider) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.paddingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Redes sociales',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppConstants.paddingSM),
          Wrap(
            spacing: AppConstants.paddingSM,
            runSpacing: AppConstants.paddingSM,
            children: [
              if (provider.instagramHandle != null)
                _SocialChip(
                  icon: Icons.camera_alt_outlined,
                  label: '@${provider.instagramHandle}',
                  onTap: () => _launchUrl(
                    'https://instagram.com/${provider.instagramHandle}',
                  ),
                ),
              if (provider.facebookUrl != null)
                _SocialChip(
                  icon: Icons.facebook_outlined,
                  label: 'Facebook',
                  onTap: () => _launchUrl(provider.facebookUrl!),
                ),
              if (provider.website != null)
                _SocialChip(
                  icon: Icons.language_outlined,
                  label: 'Sitio web',
                  onTap: () => _launchUrl(provider.website!),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Business hours section
  // ---------------------------------------------------------------------------
  Widget _buildHoursSection(BuildContext context, models.Provider provider) {
    final hours = provider.hours!;
    final colorScheme = Theme.of(context).colorScheme;

    // Ordered days in Spanish
    const dayOrder = [
      'lunes',
      'martes',
      'miercoles',
      'jueves',
      'viernes',
      'sabado',
      'domingo',
    ];
    const dayLabels = {
      'lunes': 'Lunes',
      'martes': 'Martes',
      'miercoles': 'Miercoles',
      'jueves': 'Jueves',
      'viernes': 'Viernes',
      'sabado': 'Sabado',
      'domingo': 'Domingo',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.paddingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Horario',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppConstants.paddingSM),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppConstants.paddingMD),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius:
                  BorderRadius.circular(AppConstants.radiusSM),
            ),
            child: Column(
              children: dayOrder.map((day) {
                final value = hours[day];
                final label = dayLabels[day] ?? day;
                String timeText;

                if (value == null || value == 'cerrado') {
                  timeText = 'Cerrado';
                } else if (value is Map) {
                  final open = value['open'] ?? '';
                  final close = value['close'] ?? '';
                  timeText = '$open - $close';
                } else {
                  timeText = value.toString();
                }

                final isClosed =
                    value == null || value == 'cerrado';

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppConstants.paddingXS,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isClosed
                              ? colorScheme.onSurface.withValues(alpha: 0.5)
                              : colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        timeText,
                        style: TextStyle(
                          fontSize: 14,
                          color: isClosed
                              ? colorScheme.onSurface.withValues(alpha: 0.5)
                              : colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Services list
  // ---------------------------------------------------------------------------
  Widget _buildServicesList(
    BuildContext context,
    AsyncValue<List<models.ProviderService>> servicesAsync,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return servicesAsync.when(
      loading: () => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLG),
          child: Center(
            child: CircularProgressIndicator(
              color: colorScheme.primary,
            ),
          ),
        ),
      ),
      error: (error, _) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLG),
          child: Center(
            child: Text(
              'Error al cargar servicios: $error',
              style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5)),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      data: (services) {
        if (services.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.paddingLG),
              child: Center(
                child: Text(
                  'No hay servicios disponibles',
                  style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5)),
                ),
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final service = services[index];
              return _ServiceCard(
                service: service,
                onBook: () {
                  context.push('/booking/$providerId/${service.id}');
                },
              );
            },
            childCount: services.length,
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // URL launcher helper
  // ---------------------------------------------------------------------------
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// =============================================================================
// Private helper widgets
// =============================================================================

class _ContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _ContactButton({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = color ?? Theme.of(context).colorScheme.primary;

    return Material(
      color: buttonColor.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppConstants.radiusSM),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppConstants.paddingMD,
            horizontal: AppConstants.paddingSM,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: buttonColor, size: 20),
              const SizedBox(width: AppConstants.paddingSM),
              Text(
                label,
                style: TextStyle(
                  color: buttonColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SocialChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ActionChip(
      avatar: Icon(icon, size: 18, color: colorScheme.primary),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: colorScheme.surface,
      side: BorderSide.none,
      labelStyle: TextStyle(
        fontSize: 13,
        color: colorScheme.onSurface,
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final models.ProviderService service;
  final VoidCallback onBook;

  const _ServiceCard({
    required this.service,
    required this.onBook,
  });

  String _formatPrice() {
    if (service.priceMin == null && service.priceMax == null) {
      return 'Consultar precio';
    }

    final min = service.priceMin;
    final max = service.priceMax;

    if (min != null && max != null && min != max) {
      return '\$${min.toInt()} - \$${max.toInt()} MXN';
    } else if (min != null) {
      return '\$${min.toInt()} MXN';
    } else if (max != null) {
      return '\$${max.toInt()} MXN';
    }

    return 'Consultar precio';
  }

  String _formatDuration() {
    final minutes = service.durationMinutes;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remaining = minutes % 60;
      if (remaining == 0) {
        return '${hours}h';
      }
      return '${hours}h ${remaining}min';
    }
    return '${minutes} min';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMD,
        vertical: AppConstants.paddingXS,
      ),
      child: Card(
        elevation: AppConstants.elevationLow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingMD),
          child: Row(
            children: [
              // Service info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.serviceName,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppConstants.paddingXS),
                    Text(
                      '${service.category} / ${service.subcategory}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: AppConstants.paddingSM),
                    Row(
                      children: [
                        Text(
                          _formatPrice(),
                          style: textTheme.titleSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: AppConstants.paddingMD),
                        Icon(
                          Icons.schedule,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(),
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: AppConstants.paddingSM),

              // Book button
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  onPressed: onBook,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.paddingMD,
                    ),
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
