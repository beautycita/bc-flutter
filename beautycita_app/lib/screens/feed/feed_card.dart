import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/config/fonts.dart';
import 'package:beautycita_core/models.dart' hide Provider;
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/providers/feed_provider.dart';
import 'package:beautycita/screens/feed/feed_image_viewer.dart';
import 'package:beautycita/screens/feed/product_detail_sheet.dart';

class FeedCard extends ConsumerStatefulWidget {
  final FeedItem item;

  const FeedCard({super.key, required this.item});

  @override
  ConsumerState<FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends ConsumerState<FeedCard> {
  // Optimistic save state — tracks local toggle independent of server round-trip.
  late bool _isSaved;
  late int _saveCount;
  bool _showBefore = false;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.item.isSaved;
    _saveCount = widget.item.saveCount;
  }

  @override
  void didUpdateWidget(FeedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only sync from server if the user hasn't locally toggled yet.
    if (oldWidget.item.isSaved == widget.item.isSaved) {
      _isSaved = widget.item.isSaved;
    }
    if (oldWidget.item.saveCount == widget.item.saveCount) {
      _saveCount = widget.item.saveCount;
    }
  }

  Future<void> _toggleSave() async {
    HapticFeedback.lightImpact();
    final wasSaved = _isSaved;
    setState(() {
      _isSaved = !wasSaved;
      _saveCount += wasSaved ? -1 : 1;
    });

    final service = ref.read(feedServiceProvider);

    // Product showcases use the public "like" counter; everything else uses
    // the private saves/bookmarks list.
    if (widget.item.isShowcase && widget.item.hasProducts) {
      final productId = widget.item.productTags.first.productId;
      final res = await service.toggleProductLike(productId);
      if (mounted) {
        setState(() {
          _isSaved = res.liked;
          _saveCount = res.likesCount;
        });
      }
      return;
    }

    final nowSaved = await service.toggleSave(
      contentType: widget.item.type,
      contentId: widget.item.id,
    );

    // Reconcile with server result.
    if (mounted && nowSaved != !wasSaved) {
      setState(() {
        _isSaved = nowSaved;
        _saveCount = widget.item.saveCount + (nowSaved ? 1 : 0);
      });
    }

    ref
        .read(feedPaginationProvider.notifier)
        .updateSaveStatus(widget.item.id, _isSaved, _isSaved ? 1 : -1);
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    final item = widget.item;

    // Product showcase gets a dedicated layout
    if (item.isShowcase && item.hasProducts) {
      return _ProductShowcaseCard(
        item: item,
        isSaved: _isSaved,
        saveCount: _saveCount,
        onSave: _toggleSave,
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.screenPaddingHorizontal,
        vertical: AppConstants.paddingSM,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        side: BorderSide(
          color: palette.outlineVariant.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      color: palette.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Salon header row ──────────────────────────────────────────
          _SalonHeader(item: item),

          // ── Main image ───────────────────────────────────────────────
          _MainImage(
            item: item,
            showBefore: _showBefore,
            onToggleBeforeAfter: item.isBeforeAfter
                ? () => setState(() => _showBefore = !_showBefore)
                : null,
          ),

          // ── Caption ──────────────────────────────────────────────────
          if (item.caption != null && item.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.paddingMD,
                AppConstants.paddingMD,
                AppConstants.paddingMD,
                0,
              ),
              child: Text(
                item.caption!,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: palette.onSurface.withValues(alpha: 0.8),
                  height: 1.45,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // ── Product tag pills ─────────────────────────────────────────
          if (item.hasProducts)
            _ProductTagRow(
              tags: item.productTags,
              salonName: item.businessName,
              businessId: item.businessId,
            ),

          // ── Bottom action row ─────────────────────────────────────────
          _ActionRow(
            isSaved: _isSaved,
            saveCount: _saveCount,
            serviceCategory: item.serviceCategory,
            onSave: _toggleSave,
          ),
        ],
      ),
    );
  }
}

// ── Product Showcase Card ────────────────────────────────────────────────────
// Dedicated layout for product showcase feed items. Shows product image large,
// with brand, name, price overlay and a buy CTA.

class _ProductShowcaseCard extends StatelessWidget {
  final FeedItem item;
  final bool isSaved;
  final int saveCount;
  final VoidCallback onSave;

  const _ProductShowcaseCard({
    required this.item,
    required this.isSaved,
    required this.saveCount,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    final product = item.productTags.first;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.screenPaddingHorizontal,
        vertical: AppConstants.paddingSM,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: palette.outlineVariant.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      color: palette.surface,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Product image with gradient overlay ──
          GestureDetector(
            onTap: () => ProductDetailSheet.show(
              context,
              product: product,
              salonName: item.businessName,
              businessId: item.businessId,
            ),
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: product.photoUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(
                      color: palette.surfaceContainerHighest,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, _, _) => Container(
                      color: palette.surfaceContainerHighest,
                      child: Icon(Icons.shopping_bag_outlined,
                          size: 48, color: palette.onSurface.withValues(alpha: 0.2)),
                    ),
                  ),
                  // Gradient overlay at bottom for text readability
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 120,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Price badge top-right
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: palette.primary,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '\$${product.price.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                  // Brand + name at bottom
                  Positioned(
                    bottom: 12,
                    left: 14,
                    right: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (product.brand != null)
                          Text(
                            product.brand!.toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                            ),
                          ),
                        Text(
                          product.name,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onPrimary,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Stock badge
                  if (!product.inStock)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Agotado',
                            style: GoogleFonts.poppins(
                                fontSize: 10, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onPrimary)),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Salon info + actions row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(
              children: [
                // Salon avatar
                CircleAvatar(
                  radius: 14,
                  backgroundColor: palette.primaryContainer,
                  backgroundImage: item.businessPhotoUrl != null
                      ? CachedNetworkImageProvider(item.businessPhotoUrl!)
                      : null,
                  child: item.businessPhotoUrl == null
                      ? Text(
                          item.businessName.isNotEmpty ? item.businessName[0].toUpperCase() : 'S',
                          style: GoogleFonts.poppins(
                              fontSize: 11, fontWeight: FontWeight.w700, color: palette.onPrimaryContainer),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.businessName,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: palette.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Category chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: palette.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    product.brand ?? 'Producto',
                    style: GoogleFonts.nunito(
                        fontSize: 11, fontWeight: FontWeight.w600, color: palette.onSurface.withValues(alpha: 0.6)),
                  ),
                ),
              ],
            ),
          ),

          // ── Caption if present ──
          if (item.caption != null && item.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
              child: Text(
                item.caption!,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: palette.onSurface.withValues(alpha: 0.65),
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // ── Buy + Save row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Row(
              children: [
                // Buy button
                Expanded(
                  child: GestureDetector(
                    onTap: () => ProductDetailSheet.show(
                      context,
                      product: product,
                      salonName: item.businessName,
                      businessId: item.businessId,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEC4899), Color(0xFF9333EA)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_bag_outlined, size: 16, color: Theme.of(context).colorScheme.onPrimary),
                          const SizedBox(width: 6),
                          Text(
                            'Ver Producto',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Save button
                GestureDetector(
                  onTap: onSave,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSaved
                          ? Colors.red.withValues(alpha: 0.1)
                          : palette.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      size: 20,
                      color: isSaved ? Colors.red : palette.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Salon header ─────────────────────────────────────────────────────────────

class _SalonHeader extends StatelessWidget {
  final FeedItem item;
  const _SalonHeader({required this.item});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.paddingMD,
        AppConstants.paddingMD,
        AppConstants.paddingMD,
        AppConstants.paddingSM,
      ),
      child: Row(
        children: [
          // Business avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: palette.primaryContainer,
            backgroundImage: item.businessPhotoUrl != null
                ? CachedNetworkImageProvider(item.businessPhotoUrl!)
                : null,
            child: item.businessPhotoUrl == null
                ? Text(
                    item.businessName.isNotEmpty
                        ? item.businessName[0].toUpperCase()
                        : 'B',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: palette.onPrimaryContainer,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AppConstants.paddingSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.businessName,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: palette.onSurface,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.staffName != null)
                  Text(
                    item.staffName!,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: palette.onSurface.withValues(alpha: 0.55),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Main image ────────────────────────────────────────────────────────────────

class _MainImage extends StatelessWidget {
  final FeedItem item;
  final bool showBefore;
  final VoidCallback? onToggleBeforeAfter;

  const _MainImage({
    required this.item,
    required this.showBefore,
    this.onToggleBeforeAfter,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    final imageUrl = showBefore ? item.beforeUrl! : item.afterUrl;

    return GestureDetector(
      onTap: () {
        final urls = <String>[item.afterUrl];
        final labels = <String>[];
        if (item.isBeforeAfter) {
          urls.insert(0, item.beforeUrl!);
          labels.addAll(['Antes', 'Despues']);
        }
        FeedImageViewer.open(
          context,
          imageUrls: urls,
          labels: labels.isNotEmpty ? labels : null,
          initialIndex: item.isBeforeAfter && showBefore ? 0 : (item.isBeforeAfter ? 1 : 0),
          title: item.businessName,
        );
      },
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Main image (cached)
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(
                color: palette.surfaceContainerHighest,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: palette.primary,
                  ),
                ),
              ),
              errorWidget: (_, _, _) => Container(
                color: palette.surfaceContainerHighest,
                child: Icon(
                  Icons.broken_image_outlined,
                  size: AppConstants.iconSizeXL,
                  color: palette.onSurface.withValues(alpha: 0.3),
                ),
              ),
            ),

          // Before/After toggle button
          if (item.isBeforeAfter && onToggleBeforeAfter != null)
            Positioned(
              bottom: AppConstants.paddingSM,
              left: AppConstants.paddingSM,
              child: GestureDetector(
                onTap: onToggleBeforeAfter,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.paddingMD,
                    vertical: AppConstants.paddingXS,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusFull),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        showBefore
                            ? Icons.compare_outlined
                            : Icons.compare_outlined,
                        size: 14,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        showBefore ? 'Ver Despues' : 'Ver Antes',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // "Antes" / "Despues" label
          if (item.isBeforeAfter)
            Positioned(
              top: AppConstants.paddingSM,
              right: AppConstants.paddingSM,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.paddingSM,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: showBefore
                      ? Colors.orange.withValues(alpha: 0.85)
                      : Colors.green.withValues(alpha: 0.85),
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusFull),
                ),
                child: Text(
                  showBefore ? 'Antes' : 'Despues',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onPrimary,
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

// ── Product tag pills ─────────────────────────────────────────────────────────

class _ProductTagRow extends StatelessWidget {
  final List<FeedProductTag> tags;
  final String salonName;
  final String businessId;

  const _ProductTagRow({required this.tags, required this.salonName, required this.businessId});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.paddingMD,
        AppConstants.paddingMD,
        AppConstants.paddingMD,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Productos usados',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: palette.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: AppConstants.paddingXS),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: tags.map((tag) {
                return Padding(
                  padding: const EdgeInsets.only(right: AppConstants.paddingXS),
                  child: GestureDetector(
                    onTap: () => ProductDetailSheet.show(
                      context,
                      product: tag,
                      salonName: salonName,
                      businessId: businessId,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.paddingSM,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: palette.primaryContainer.withValues(alpha: 0.5),
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusFull),
                        border: Border.all(
                          color: palette.primary.withValues(alpha: 0.25),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tag.name,
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: palette.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '\$${tag.price.toStringAsFixed(0)}',
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              color: palette.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action row ────────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  final bool isSaved;
  final int saveCount;
  final String? serviceCategory;
  final VoidCallback onSave;

  const _ActionRow({
    required this.isSaved,
    required this.saveCount,
    this.serviceCategory,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.paddingMD,
        AppConstants.paddingSM,
        AppConstants.paddingMD,
        AppConstants.paddingMD,
      ),
      child: Row(
        children: [
          // Service category chip
          if (serviceCategory != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.paddingSM,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: palette.surfaceContainerHighest,
                borderRadius:
                    BorderRadius.circular(AppConstants.radiusFull),
              ),
              child: Text(
                serviceCategory!,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: palette.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ),
            const Spacer(),
          ] else
            const Spacer(),

          // Heart/Save button with count
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSave,
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.paddingXS),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: child,
                    ),
                    child: Icon(
                      isSaved
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      key: ValueKey(isSaved),
                      size: 22,
                      color: isSaved ? Colors.red : palette.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  if (saveCount > 0) ...[
                    const SizedBox(width: 4),
                    Text(
                      '$saveCount',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: palette.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
