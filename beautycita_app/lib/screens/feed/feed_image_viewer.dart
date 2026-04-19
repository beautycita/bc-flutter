import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:beautycita/config/fonts.dart';
import 'package:beautycita/services/media_service.dart';
import 'package:beautycita/services/toast_service.dart';

/// Lightweight fullscreen image viewer for feed posts and product photos.
///
/// Supports pinch-to-zoom, swipe between images (before/after), and
/// bottom action bar with save-to-gallery and share actions.
class FeedImageViewer extends StatefulWidget {
  /// Image URLs to display. Single image or [before, after] pair.
  final List<String> imageUrls;

  /// Optional labels for each image (e.g. ['Antes', 'Despues']).
  final List<String>? labels;

  /// Index to show first.
  final int initialIndex;

  /// Title shown in app bar (e.g. salon name or product name).
  final String? title;

  const FeedImageViewer({
    super.key,
    required this.imageUrls,
    this.labels,
    this.initialIndex = 0,
    this.title,
  });

  /// Open as a fullscreen route with a fade transition.
  static void open(
    BuildContext context, {
    required List<String> imageUrls,
    List<String>? labels,
    int initialIndex = 0,
    String? title,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) =>
            FeedImageViewer(
          imageUrls: imageUrls,
          labels: labels,
          initialIndex: initialIndex,
          title: title,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<FeedImageViewer> createState() => _FeedImageViewerState();
}

class _FeedImageViewerState extends State<FeedImageViewer> {
  late PageController _pageController;
  late int _currentIndex;
  bool _isSaving = false;

  final _mediaService = MediaService();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String get _currentUrl => widget.imageUrls[_currentIndex];

  Future<void> _saveToGallery() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    HapticFeedback.lightImpact();

    final ok = await _mediaService.saveUrlToGallery(_currentUrl);
    if (mounted) {
      setState(() => _isSaving = false);
      if (ok) {
        ToastService.showSuccess('Guardado en galeria');
      }
    }
  }

  Future<void> _share() async {
    HapticFeedback.lightImpact();
    await _mediaService.shareImage(
      _currentUrl,
      text: widget.title != null ? 'Via BeautyCita - ${widget.title}' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasMultiple = widget.imageUrls.length > 1;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.scrim,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: hasMultiple
            ? Text(
                '${_currentIndex + 1} / ${widget.imageUrls.length}',
                style: GoogleFonts.nunito(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.imageUrls.length,
          onPageChanged: (i) => setState(() => _currentIndex = i),
          itemBuilder: (context, index) {
            final url = widget.imageUrls[index];
            return Stack(
              fit: StackFit.expand,
              children: [
                InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                                : null,
                            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.54),
                          ),
                        );
                      },
                      errorBuilder: (_, _, _) => Icon(
                        Icons.broken_image,
                        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.38),
                        size: 64,
                      ),
                    ),
                  ),
                ),

                // Label badge (Antes / Despues)
                if (widget.labels != null && index < widget.labels!.length)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 56,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: index == 0
                            ? Colors.orange.withValues(alpha: 0.85)
                            : Colors.green.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.labels![index],
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: Container(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.87),
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _BottomAction(
              icon: _isSaving ? Icons.hourglass_top : Icons.download,
              label: 'Guardar',
              onTap: _isSaving ? null : _saveToGallery,
            ),
            _BottomAction(
              icon: Icons.share,
              label: 'Compartir',
              onTap: _share,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _BottomAction({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = onTap != null ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.38);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.nunito(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
