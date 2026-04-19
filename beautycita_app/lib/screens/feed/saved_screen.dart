import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/config/fonts.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/providers/feed_provider.dart';

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).colorScheme;
    final savedAsync = ref.watch(savedItemsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Guardados',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.onSurface,
          ),
        ),
        centerTitle: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: savedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          onRetry: () => ref.invalidate(savedItemsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return _EmptySavedState();
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(savedItemsProvider),
            color: palette.primary,
            child: GridView.builder(
              padding: const EdgeInsets.all(AppConstants.screenPaddingHorizontal),
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppConstants.paddingSM,
                mainAxisSpacing: AppConstants.paddingSM,
                childAspectRatio: 0.85,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) =>
                  _SavedItemCard(item: items[index]),
            ),
          );
        },
      ),
    );
  }
}

// ── Saved item card ───────────────────────────────────────────────────────────

class _SavedItemCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _SavedItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    final contentType = item['content_type'] as String? ?? '';
    final contentId = item['content_id'] as String? ?? '';

    final (IconData typeIcon, String typeLabel, Color typeColor) =
        switch (contentType) {
      'photo' => (Icons.photo_camera_outlined, 'Foto', palette.primary),
      'showcase' => (Icons.collections_outlined, 'Showcase', palette.secondary),
      'product' => (
          Icons.shopping_bag_outlined,
          'Producto',
          palette.tertiary
        ),
      _ => (Icons.bookmark_outlined, contentType, palette.primary),
    };

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        side: BorderSide(
          color: palette.outlineVariant.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      color: palette.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(typeIcon, color: typeColor, size: 26),
            ),
            const SizedBox(height: AppConstants.paddingSM),
            Text(
              typeLabel,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.onSurface,
              ),
            ),
            const SizedBox(height: AppConstants.paddingXS),
            Text(
              contentId.length > 12
                  ? '${contentId.substring(0, 12)}...'
                  : contentId,
              style: GoogleFonts.nunito(
                fontSize: 11,
                color: palette.onSurface.withValues(alpha: 0.4),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptySavedState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border_rounded,
              size: AppConstants.iconSizeXXL,
              color: palette.onSurface.withValues(alpha: 0.25),
            ),
            const SizedBox(height: AppConstants.paddingMD),
            Text(
              'Nada guardado aun',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: palette.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: AppConstants.paddingXS),
            Text(
              'Toca el corazon en cualquier\npublicacion para guardarla aqui.',
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: palette.onSurface.withValues(alpha: 0.4),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: AppConstants.iconSizeLG,
              color: palette.error,
            ),
            const SizedBox(height: AppConstants.paddingMD),
            Text(
              'Error al cargar',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: palette.onSurface,
              ),
            ),
            const SizedBox(height: AppConstants.paddingLG),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                'Reintentar',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
