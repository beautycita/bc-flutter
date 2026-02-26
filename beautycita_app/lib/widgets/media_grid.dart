import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../services/media_service.dart';
import 'media_viewer.dart';

/// Groups media items by date and displays as a grid of thumbnails.
class MediaGrid extends StatelessWidget {
  final List<MediaItem> items;
  final void Function(MediaItem item)? onShare;
  final void Function(MediaItem item)? onDelete;
  final void Function(MediaItem item)? onSaveToGallery;

  const MediaGrid({
    super.key,
    required this.items,
    this.onShare,
    this.onDelete,
    this.onSaveToGallery,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: BeautyCitaTheme.textLight.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'Sin medios todavia',
              style: GoogleFonts.nunito(
                fontSize: 16,
                color: BeautyCitaTheme.textLight,
              ),
            ),
          ],
        ),
      );
    }

    // Group by date
    final groups = _groupByDate(items);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: groups.length,
      itemBuilder: (context, groupIndex) {
        final group = groups[groupIndex];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Text(
                group.label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: BeautyCitaTheme.textDark,
                ),
              ),
            ),
            // Grid of thumbnails
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 3,
                mainAxisSpacing: 3,
              ),
              itemCount: group.items.length,
              itemBuilder: (context, index) {
                final item = group.items[index];
                // Find global index for viewer
                final globalIndex = items.indexOf(item);
                return _Thumbnail(
                  item: item,
                  onTap: () => _openViewer(context, globalIndex),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _openViewer(BuildContext context, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MediaViewer(
          items: items,
          initialIndex: index,
          onShare: onShare,
          onDelete: onDelete,
          onSaveToGallery: onSaveToGallery,
        ),
      ),
    );
  }

  List<_DateGroup> _groupByDate(List<MediaItem> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));

    final groups = <String, List<MediaItem>>{};
    final groupOrder = <String>[];

    for (final item in items) {
      final date = DateTime(
        item.createdAt.year,
        item.createdAt.month,
        item.createdAt.day,
      );

      String label;
      if (date == today) {
        label = 'Hoy';
      } else if (date == yesterday) {
        label = 'Ayer';
      } else if (date.isAfter(thisWeekStart)) {
        label = 'Esta semana';
      } else {
        label = DateFormat('MMMM yyyy', 'es').format(item.createdAt);
      }

      if (!groups.containsKey(label)) {
        groups[label] = [];
        groupOrder.add(label);
      }
      groups[label]!.add(item);
    }

    return groupOrder
        .map((label) => _DateGroup(label: label, items: groups[label]!))
        .toList();
  }
}

class _DateGroup {
  final String label;
  final List<MediaItem> items;

  const _DateGroup({required this.label, required this.items});
}

/// Individual thumbnail in the grid.
class _Thumbnail extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;

  const _Thumbnail({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.network(
              item.thumbnailUrl ?? item.url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: BeautyCitaTheme.surfaceCream,
                child: const Icon(Icons.broken_image, size: 32),
              ),
            ),
          ),
          // Source badge
          if (item.toolLabel != null)
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.toolLabel!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Horizontal media row for chat media grouping (by thread).
class ChatMediaSection extends StatelessWidget {
  final String threadLabel;
  final List<MediaItem> items;
  final void Function(MediaItem)? onShare;
  final void Function(MediaItem)? onDelete;
  final void Function(MediaItem)? onSaveToGallery;

  const ChatMediaSection({
    super.key,
    required this.threadLabel,
    required this.items,
    this.onShare,
    this.onDelete,
    this.onSaveToGallery,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              if (threadLabel == 'Afrodita') ...[
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFB300), Color(0xFFFFD54F)],
                    ),
                  ),
                  child: const Center(
                    child: Text('A', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                threadLabel,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: BeautyCitaTheme.textDark,
                ),
              ),
              const Spacer(),
              Text(
                '${items.length}',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: BeautyCitaTheme.textLight,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MediaViewer(
                        items: items,
                        initialIndex: index,
                        onShare: onShare,
                        onDelete: onDelete,
                        onSaveToGallery: onSaveToGallery,
                      ),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 100,
                      height: 100,
                      child: Image.network(
                        item.thumbnailUrl ?? item.url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: BeautyCitaTheme.surfaceCream,
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
