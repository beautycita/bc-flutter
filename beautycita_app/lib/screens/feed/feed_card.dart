import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:beautycita_core/models.dart' hide Provider;
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/providers/feed_provider.dart';
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
                ? NetworkImage(item.businessPhotoUrl!)
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

    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Main image
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Container(
                color: palette.surfaceContainerHighest,
                child: Center(
                  child: CircularProgressIndicator(
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!
                        : null,
                    strokeWidth: 2,
                    color: palette.primary,
                  ),
                ),
              );
            },
            errorBuilder: (_, _, _) => Container(
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
                    color: Colors.black.withValues(alpha: 0.65),
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
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        showBefore ? 'Ver Despues' : 'Ver Antes',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Product tag pills ─────────────────────────────────────────────────────────

class _ProductTagRow extends StatelessWidget {
  final List<FeedProductTag> tags;
  final String salonName;

  const _ProductTagRow({required this.tags, required this.salonName});

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
