import 'package:flutter/material.dart';
import 'package:beautycita/config/app_transitions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:beautycita_core/models.dart' hide Provider;
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/screens/feed/feed_image_viewer.dart';

class ProductDetailSheet extends StatelessWidget {
  final FeedProductTag product;
  final String salonName;

  const ProductDetailSheet({
    super.key,
    required this.product,
    required this.salonName,
  });

  static Future<void> show(
    BuildContext context, {
    required FeedProductTag product,
    required String salonName,
  }) {
    return showBurstBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProductDetailSheet(product: product, salonName: salonName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);

    return Container(
      margin: EdgeInsets.only(top: mq.size.height * 0.15),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusLG),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: AppConstants.paddingMD),
            width: AppConstants.bottomSheetDragHandleWidth,
            height: AppConstants.bottomSheetDragHandleHeight,
            decoration: BoxDecoration(
              color: palette.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(
                  AppConstants.bottomSheetDragHandleRadius),
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppConstants.screenPaddingHorizontal,
                AppConstants.paddingLG,
                AppConstants.screenPaddingHorizontal,
                AppConstants.paddingLG + mq.padding.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product photo (tap to fullscreen)
                  GestureDetector(
                    onTap: () => FeedImageViewer.open(
                      context,
                      imageUrls: [product.photoUrl],
                      title: product.name,
                    ),
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMD),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Image.network(
                          product.photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: palette.surfaceContainerHighest,
                            child: Icon(
                              Icons.image_outlined,
                              size: AppConstants.iconSizeXXL,
                              color: palette.onSurface.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppConstants.paddingLG),

                  // Brand
                  if (product.brand != null) ...[
                    Text(
                      product.brand!.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.4,
                        color: palette.primary,
                      ),
                    ),
                    const SizedBox(height: AppConstants.paddingXS),
                  ],

                  // Product name
                  Text(
                    product.name,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: palette.onSurface,
                      height: 1.2,
                    ),
                  ),

                  const SizedBox(height: AppConstants.paddingSM),

                  // Price
                  Text(
                    '\$${product.price.toStringAsFixed(2)} MXN',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: palette.primary,
                    ),
                  ),

                  const SizedBox(height: AppConstants.paddingSM),

                  // Salon name
                  Row(
                    children: [
                      Icon(
                        Icons.storefront_outlined,
                        size: 16,
                        color: palette.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: AppConstants.paddingXS),
                      Expanded(
                        child: Text(
                          salonName,
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            color: palette.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Stock indicator
                  if (!product.inStock) ...[
                    const SizedBox(height: AppConstants.paddingSM),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.paddingMD,
                        vertical: AppConstants.paddingXS,
                      ),
                      decoration: BoxDecoration(
                        color: palette.error.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusSM),
                      ),
                      child: Text(
                        'Sin existencias',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: palette.error,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: AppConstants.paddingXL),

                  // Comprar button (placeholder — wired to payment in Task 10)
                  SizedBox(
                    width: double.infinity,
                    height: AppConstants.minTouchHeight,
                    child: FilledButton.icon(
                      onPressed: product.inStock ? () {} : null,
                      icon: const Icon(Icons.shopping_bag_outlined),
                      label: Text(
                        'Comprar',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusMD),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
