/// Photo Studio — a suite of visually impactful photo management widgets
/// for the BeautyCita web app.
///
/// Exports:
///   - [BeforeAfterSlider] — dramatic before/after comparison
///   - [PhotoMasonryGrid] — Pinterest-style masonry photo grid
///   - [PhotoLightbox] — full-screen photo viewer overlay
///   - [PortfolioBuilder] — live portfolio page builder/preview
///   - [PhotoUploader] — drag-and-drop upload with progress
///   - [PhotoEditor] — lightweight in-browser photo adjustments
library;

import 'dart:math' as math;

import 'package:beautycita_core/theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../config/breakpoints.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  DESIGN TOKENS (from design spec)
// ═══════════════════════════════════════════════════════════════════════════════

/// Warm-minimal theme tokens extracted from the approved design spec.
/// These are used throughout every widget in this file.
abstract final class _Tok {
  static const Color bg = Color(0xFFFFFAF5);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFF0EBE6);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textHint = Color(0xFF999999);

  /// Brand gradient used on handles, CTAs, and focus accents.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEC4899), Color(0xFF9333EA), Color(0xFF3B82F6)],
  );

  /// Same gradient as a list of colors for painting/shaders.
  static const List<Color> brandColors = [
    Color(0xFFEC4899),
    Color(0xFF9333EA),
    Color(0xFF3B82F6),
  ];

  static const double cardRadius = 16.0;
  static const Duration hoverDuration = Duration(milliseconds: 200);
  static const Duration fastAnim = Duration(milliseconds: 300);
  static const Duration medAnim = Duration(milliseconds: 500);

  static BoxShadow get cardShadow => BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 10,
        offset: const Offset(0, 2),
      );

  static BoxShadow get hoverShadow => BoxShadow(
        color: Colors.black.withValues(alpha: 0.08),
        blurRadius: 20,
        offset: const Offset(0, 6),
      );

  static BoxShadow glowShadow(Color c) => BoxShadow(
        color: c.withValues(alpha: 0.35),
        blurRadius: 24,
        spreadRadius: 2,
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
//  1. BEFORE / AFTER SLIDER
// ═══════════════════════════════════════════════════════════════════════════════

/// A dramatic before/after comparison widget with a draggable vertical
/// divider that reveals one image over the other.
///
/// On first mount, the divider auto-animates from 0.2 to 0.5 (a smooth
/// "reveal" effect), then the user takes over via drag.
///
/// Labels "Antes" and "Despues" float on semi-transparent overlays.
class BeforeAfterSlider extends StatefulWidget {
  const BeforeAfterSlider({
    required this.beforeImage,
    required this.afterImage,
    this.height = 420,
    this.borderRadius = _Tok.cardRadius,
    this.autoReveal = true,
    this.beforeLabel = 'Antes',
    this.afterLabel = 'Despues',
    super.key,
  });

  /// Network URL for the "before" image (shown on the left).
  final String beforeImage;

  /// Network URL for the "after" image (shown on the right).
  final String afterImage;

  /// Fixed height of the comparison viewport.
  final double height;

  /// Corner radius for the outer container.
  final double borderRadius;

  /// Whether to play the auto-reveal animation on first view.
  final bool autoReveal;

  /// Label displayed on the left (before) side.
  final String beforeLabel;

  /// Label displayed on the right (after) side.
  final String afterLabel;

  @override
  State<BeforeAfterSlider> createState() => _BeforeAfterSliderState();
}

class _BeforeAfterSliderState extends State<BeforeAfterSlider>
    with SingleTickerProviderStateMixin {
  /// Position of the divider as a fraction of the total width (0.0 – 1.0).
  double _split = 0.2;

  late final AnimationController _revealCtrl;
  late final Animation<double> _revealAnim;
  bool _userTookOver = false;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _revealAnim = Tween(begin: 0.15, end: 0.5).animate(
      CurvedAnimation(parent: _revealCtrl, curve: Curves.easeOutCubic),
    )..addListener(() {
        if (!_userTookOver) setState(() => _split = _revealAnim.value);
      });

    if (widget.autoReveal) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _revealCtrl.forward();
      });
    } else {
      _split = 0.5;
    }
  }

  @override
  void dispose() {
    _revealCtrl.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d, double maxWidth) {
    if (!_userTookOver) {
      _userTookOver = true;
      _revealCtrl.stop();
    }
    setState(() {
      _split = (_split + d.delta.dx / maxWidth).clamp(0.02, 0.98);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final divX = w * _split;

          return ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: SizedBox(
              height: widget.height,
              width: w,
              child: Stack(
                children: [
                  // ── After image (full width, behind) ──────────────
                  Positioned.fill(
                    child: _FadeInNetworkImage(
                      url: widget.afterImage,
                      fit: BoxFit.cover,
                    ),
                  ),

                  // ── Before image (clipped to left of divider) ─────
                  Positioned.fill(
                    child: ClipRect(
                      clipper: _LeftClipper(divX),
                      child: _FadeInNetworkImage(
                        url: widget.beforeImage,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                  // ── "Antes" label ─────────────────────────────────
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: _FloatingLabel(widget.beforeLabel),
                  ),

                  // ── "Despues" label ───────────────────────────────
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: _FloatingLabel(widget.afterLabel),
                  ),

                  // ── Divider handle ────────────────────────────────
                  Positioned(
                    left: divX - 20,
                    top: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onHorizontalDragUpdate: (d) => _onDragUpdate(d, w),
                      child: _DividerHandle(hovering: _hovering),
                    ),
                  ),

                  // ── Full-width drag detector ──────────────────────
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragUpdate: (d) => _onDragUpdate(d, w),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Clips a child to only show the left portion up to [splitX] pixels.
class _LeftClipper extends CustomClipper<Rect> {
  _LeftClipper(this.splitX);
  final double splitX;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, splitX, size.height);

  @override
  bool shouldReclip(_LeftClipper old) => old.splitX != splitX;
}

/// The glowing vertical divider handle with a gradient line and grabber.
class _DividerHandle extends StatelessWidget {
  const _DividerHandle({required this.hovering});
  final bool hovering;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      child: Center(
        child: AnimatedContainer(
          duration: _Tok.hoverDuration,
          width: hovering ? 4 : 3,
          decoration: BoxDecoration(
            gradient: _Tok.brandGradient,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: _Tok.brandColors[1].withValues(alpha: hovering ? 0.5 : 0.25),
                blurRadius: hovering ? 16 : 8,
                spreadRadius: hovering ? 2 : 0,
              ),
            ],
          ),
          child: Center(
            child: AnimatedContainer(
              duration: _Tok.hoverDuration,
              width: hovering ? 36 : 30,
              height: hovering ? 36 : 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _Tok.brandGradient,
                boxShadow: [
                  BoxShadow(
                    color: _Tok.brandColors[1].withValues(alpha: 0.4),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: const Icon(
                Icons.drag_handle_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Semi-transparent floating label pill.
class _FloatingLabel extends StatelessWidget {
  const _FloatingLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(BCSpacing.radiusFull),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  2. PHOTO MASONRY GRID
// ═══════════════════════════════════════════════════════════════════════════════

/// Data model for a single photo tile in the masonry grid.
class PhotoTile {
  const PhotoTile({
    required this.id,
    required this.imageUrl,
    required this.aspectRatio,
    this.salonName,
    this.serviceType,
    this.date,
    this.stylist,
    this.beforeImageUrl,
  });

  final String id;
  final String imageUrl;

  /// Width / height. Determines the tile height: tileWidth / aspectRatio.
  final double aspectRatio;

  final String? salonName;
  final String? serviceType;
  final String? date;
  final String? stylist;

  /// If non-null, a before/after toggle is available in the lightbox.
  final String? beforeImageUrl;
}

/// Pinterest-style masonry photo grid with staggered fade-in, hover overlays,
/// shimmer placeholders, and infinite scroll.
///
/// Columns: 3 on desktop, 2 on tablet, 1 on mobile.
class PhotoMasonryGrid extends StatefulWidget {
  const PhotoMasonryGrid({
    required this.photos,
    this.onLoadMore,
    this.hasMore = false,
    this.isLoading = false,
    this.spacing = 12,
    super.key,
  });

  /// Current list of photos to display.
  final List<PhotoTile> photos;

  /// Called when the user scrolls near the bottom. Fetch more photos here.
  final VoidCallback? onLoadMore;

  /// Whether more photos are available to load.
  final bool hasMore;

  /// Whether a load operation is currently in progress.
  final bool isLoading;

  /// Gap between tiles.
  final double spacing;

  @override
  State<PhotoMasonryGrid> createState() => _PhotoMasonryGridState();
}

class _PhotoMasonryGridState extends State<PhotoMasonryGrid> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!widget.hasMore || widget.isLoading) return;
    final maxScroll = _scrollCtrl.position.maxScrollExtent;
    final current = _scrollCtrl.position.pixels;
    if (current >= maxScroll - 300) {
      widget.onLoadMore?.call();
    }
  }

  int _columnCount(double width) {
    if (WebBreakpoints.isDesktop(width)) return 3;
    if (WebBreakpoints.isTablet(width)) return 2;
    return 1;
  }

  /// Distributes photos into columns using a shortest-column-first algorithm,
  /// which produces the most visually balanced layout.
  List<List<_TileEntry>> _distribute(int cols) {
    final columns = List.generate(cols, (_) => <_TileEntry>[]);
    final heights = List.filled(cols, 0.0);

    for (var i = 0; i < widget.photos.length; i++) {
      // Find the shortest column.
      var shortest = 0;
      for (var c = 1; c < cols; c++) {
        if (heights[c] < heights[shortest]) shortest = c;
      }
      columns[shortest].add(_TileEntry(photo: widget.photos[i], index: i));
      heights[shortest] += 1.0 / widget.photos[i].aspectRatio;
    }
    return columns;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = _columnCount(constraints.maxWidth);
        final distributed = _distribute(cols);
        final tileWidth =
            (constraints.maxWidth - (widget.spacing * (cols - 1))) / cols;

        return SingleChildScrollView(
          controller: _scrollCtrl,
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var c = 0; c < cols; c++) ...[
                    if (c > 0) SizedBox(width: widget.spacing),
                    Expanded(
                      child: Column(
                        children: [
                          for (final entry in distributed[c])
                            Padding(
                              padding:
                                  EdgeInsets.only(bottom: widget.spacing),
                              child: _MasonryTile(
                                entry: entry,
                                width: tileWidth,
                                allPhotos: widget.photos,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),

              // Loading indicator / Load more
              if (widget.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (widget.hasMore)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: _GradientButton(
                    label: 'Cargar mas',
                    icon: Icons.expand_more_rounded,
                    onTap: widget.onLoadMore,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TileEntry {
  const _TileEntry({required this.photo, required this.index});
  final PhotoTile photo;
  final int index;
}

/// A single masonry tile with shimmer loading, hover overlay, and staggered
/// fade-in animation.
class _MasonryTile extends StatefulWidget {
  const _MasonryTile({
    required this.entry,
    required this.width,
    required this.allPhotos,
  });

  final _TileEntry entry;
  final double width;
  final List<PhotoTile> allPhotos;

  @override
  State<_MasonryTile> createState() => _MasonryTileState();
}

class _MasonryTileState extends State<_MasonryTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final photo = widget.entry.photo;
    final tileHeight = widget.width / photo.aspectRatio;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _openLightbox(context),
        child: AnimatedContainer(
          duration: _Tok.hoverDuration,
          transform: Matrix4.identity()
            ..translateByDouble(0.0, _hovering ? -4.0 : 0.0, 0.0, 0.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_Tok.cardRadius),
            boxShadow: [_hovering ? _Tok.hoverShadow : _Tok.cardShadow],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_Tok.cardRadius),
            child: SizedBox(
              width: widget.width,
              height: tileHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ── Image with shimmer placeholder ────────────
                  _FadeInNetworkImage(
                    url: photo.imageUrl,
                    fit: BoxFit.cover,
                  ),

                  // ── Scale effect on hover ─────────────────────
                  AnimatedScale(
                    scale: _hovering ? 1.05 : 1.0,
                    duration: _Tok.hoverDuration,
                    child: const SizedBox.expand(),
                  ),

                  // ── Hover overlay ─────────────────────────────
                  AnimatedOpacity(
                    opacity: _hovering ? 1.0 : 0.0,
                    duration: _Tok.hoverDuration,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.6),
                          ],
                          stops: const [0.4, 1.0],
                        ),
                      ),
                      alignment: Alignment.bottomLeft,
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (photo.salonName != null)
                            Text(
                              photo.salonName!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          if (photo.serviceType != null)
                            Text(
                              photo.serviceType!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: 50 * widget.entry.index),
          duration: _Tok.medAnim,
          curve: Curves.easeOut,
        )
        .slideY(
          begin: 0.08,
          end: 0,
          delay: Duration(milliseconds: 50 * widget.entry.index),
          duration: _Tok.medAnim,
          curve: Curves.easeOut,
        );
  }

  void _openLightbox(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      useSafeArea: false,
      builder: (_) => PhotoLightbox(
        photos: widget.allPhotos,
        initialIndex:
            widget.allPhotos.indexWhere((p) => p.id == widget.entry.photo.id),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  3. PHOTO LIGHTBOX
// ═══════════════════════════════════════════════════════════════════════════════

/// Full-screen photo viewer overlay with blur backdrop, left/right navigation,
/// swipe gesture support, detail panel, and before/after toggle.
///
/// Opens with a radial burst scale-in animation.
class PhotoLightbox extends StatefulWidget {
  const PhotoLightbox({
    required this.photos,
    this.initialIndex = 0,
    super.key,
  });

  final List<PhotoTile> photos;
  final int initialIndex;

  @override
  State<PhotoLightbox> createState() => _PhotoLightboxState();
}

class _PhotoLightboxState extends State<PhotoLightbox>
    with SingleTickerProviderStateMixin {
  late int _index;
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  bool _showBefore = false;
  final _focusNode = FocusNode();

  PhotoTile get _current => widget.photos[_index];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.photos.length - 1);
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnim = Tween(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _fadeAnim = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _ctrl.forward();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _navigate(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.photos.length) return;
    setState(() {
      _index = next;
      _showBefore = false;
    });
  }

  Future<void> _close() async {
    await _ctrl.reverse();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape) _close();
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) _navigate(-1);
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) _navigate(1);
        }
      },
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnim.value,
            child: child,
          );
        },
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              // ── Backdrop: dark + blur ──────────────────────────
              GestureDetector(
                onTap: _close,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.85),
                ),
              ),

              // ── Photo + details ───────────────────────────────
              Center(
                child: AnimatedBuilder(
                  animation: _scaleAnim,
                  builder: (context, child) => Transform.scale(
                    scale: _scaleAnim.value,
                    child: child,
                  ),
                  child: GestureDetector(
                    onHorizontalDragEnd: (d) {
                      final v = d.primaryVelocity ?? 0;
                      if (v > 200) _navigate(-1);
                      if (v < -200) _navigate(1);
                    },
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: size.width * 0.85,
                        maxHeight: size.height * 0.88,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Photo
                          Flexible(
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(_Tok.cardRadius),
                              child: _FadeInNetworkImage(
                                url: _showBefore &&
                                        _current.beforeImageUrl != null
                                    ? _current.beforeImageUrl!
                                    : _current.imageUrl,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Details panel
                          _LightboxDetails(
                            photo: _current,
                            showBefore: _showBefore,
                            onToggleBefore: _current.beforeImageUrl != null
                                ? () =>
                                    setState(() => _showBefore = !_showBefore)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Left arrow ────────────────────────────────────
              if (_index > 0)
                Positioned(
                  left: 24,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _NavArrow(
                      icon: Icons.chevron_left_rounded,
                      onTap: () => _navigate(-1),
                    ),
                  ),
                ),

              // ── Right arrow ───────────────────────────────────
              if (_index < widget.photos.length - 1)
                Positioned(
                  right: 24,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _NavArrow(
                      icon: Icons.chevron_right_rounded,
                      onTap: () => _navigate(1),
                    ),
                  ),
                ),

              // ── Close button ──────────────────────────────────
              Positioned(
                top: 24,
                right: 24,
                child: _NavArrow(
                  icon: Icons.close_rounded,
                  onTap: _close,
                ),
              ),

              // ── Counter ───────────────────────────────────────
              Positioned(
                top: 28,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(BCSpacing.radiusFull),
                    ),
                    child: Text(
                      '${_index + 1} / ${widget.photos.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Details panel shown below the lightbox photo.
class _LightboxDetails extends StatelessWidget {
  const _LightboxDetails({
    required this.photo,
    required this.showBefore,
    this.onToggleBefore,
  });

  final PhotoTile photo;
  final bool showBefore;
  final VoidCallback? onToggleBefore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(BCSpacing.radiusSm),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                if (photo.salonName != null)
                  _DetailChip(
                    icon: Icons.storefront_outlined,
                    text: photo.salonName!,
                  ),
                if (photo.serviceType != null)
                  _DetailChip(
                    icon: Icons.content_cut_outlined,
                    text: photo.serviceType!,
                  ),
                if (photo.stylist != null)
                  _DetailChip(
                    icon: Icons.person_outline_rounded,
                    text: photo.stylist!,
                  ),
                if (photo.date != null)
                  _DetailChip(
                    icon: Icons.calendar_today_outlined,
                    text: photo.date!,
                  ),
              ],
            ),
          ),
          if (onToggleBefore != null) ...[
            const SizedBox(width: 16),
            _BeforeAfterToggle(
              showBefore: showBefore,
              onTap: onToggleBefore!,
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Toggle pill for switching between before/after images in the lightbox.
class _BeforeAfterToggle extends StatelessWidget {
  const _BeforeAfterToggle({
    required this.showBefore,
    required this.onTap,
  });

  final bool showBefore;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: _Tok.hoverDuration,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: showBefore ? null : _Tok.brandGradient,
          color: showBefore ? Colors.white.withValues(alpha: 0.15) : null,
          borderRadius: BorderRadius.circular(BCSpacing.radiusFull),
          border: Border.all(
            color: showBefore
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Text(
          showBefore ? 'Ver Despues' : 'Ver Antes',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

/// A circular navigation arrow button used in the lightbox.
class _NavArrow extends StatefulWidget {
  const _NavArrow({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_NavArrow> createState() => _NavArrowState();
}

class _NavArrowState extends State<_NavArrow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: _Tok.hoverDuration,
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hovering
                ? Colors.white.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.1),
            border: Border.all(
              color: Colors.white.withValues(alpha: _hovering ? 0.4 : 0.15),
            ),
          ),
          child: Icon(
            widget.icon,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  4. PORTFOLIO BUILDER
// ═══════════════════════════════════════════════════════════════════════════════

/// Data model for portfolio builder salon information.
class PortfolioSalonData {
  const PortfolioSalonData({
    required this.name,
    this.slug = '',
    this.tagline = '',
    this.phone = '',
    this.address = '',
    this.rating = 0,
    this.reviewCount = 0,
    this.coverPhotoUrl,
    this.logoUrl,
    this.servicePhotos = const [],
    this.staffPhotos = const [],
    this.services = const [],
    this.hours = const {},
  });

  final String name;
  final String slug;
  final String tagline;
  final String phone;
  final String address;
  final double rating;
  final int reviewCount;
  final String? coverPhotoUrl;
  final String? logoUrl;
  final List<String> servicePhotos;
  final List<PortfolioStaff> staffPhotos;
  final List<String> services;

  /// Day name -> hours string, e.g. {'Lunes': '9:00 - 18:00'}
  final Map<String, String> hours;
}

/// A single staff member in the portfolio.
class PortfolioStaff {
  const PortfolioStaff({
    required this.name,
    this.role = '',
    this.photoUrl,
  });
  final String name;
  final String role;
  final String? photoUrl;
}

/// The five available portfolio themes.
enum PortfolioTheme {
  portfolio('Portfolio', Icons.auto_awesome_outlined),
  teamBuilder('Equipo', Icons.groups_outlined),
  storefront('Vitrina', Icons.storefront_outlined),
  gallery('Galeria', Icons.photo_library_outlined),
  local('Local', Icons.place_outlined);

  const PortfolioTheme(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// A live portfolio page builder with split-view editing.
///
/// Left side: controls (theme selector, cover photo uploader, photo grid with
/// drag-to-reorder, staff slots, auto-populated business info).
/// Right side: live preview that updates instantly.
///
/// Theme changes use a diagonal slash transition.
class PortfolioBuilder extends StatefulWidget {
  const PortfolioBuilder({
    required this.salon,
    this.onPublish,
    this.onCoverPhotoChanged,
    this.onServicePhotosChanged,
    super.key,
  });

  final PortfolioSalonData salon;

  /// Called when the user taps "Publicar".
  final VoidCallback? onPublish;

  /// Called when the user picks a new cover photo.
  final ValueChanged<PlatformFile>? onCoverPhotoChanged;

  /// Called when the service photo list changes (reorder, add, remove).
  final ValueChanged<List<String>>? onServicePhotosChanged;

  @override
  State<PortfolioBuilder> createState() => _PortfolioBuilderState();
}

class _PortfolioBuilderState extends State<PortfolioBuilder>
    with SingleTickerProviderStateMixin {
  PortfolioTheme _theme = PortfolioTheme.portfolio;
  late List<String> _photos;

  // Diagonal slash transition
  late final AnimationController _slashCtrl;
  late final Animation<double> _slashAnim;
  PortfolioTheme? _pendingTheme;

  @override
  void initState() {
    super.initState();
    _photos = List.of(widget.salon.servicePhotos);
    _slashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slashAnim = CurvedAnimation(parent: _slashCtrl, curve: Curves.easeInOut);
    _slashCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          if (_pendingTheme != null) _theme = _pendingTheme!;
          _pendingTheme = null;
        });
        _slashCtrl.reset();
      }
    });
  }

  @override
  void dispose() {
    _slashCtrl.dispose();
    super.dispose();
  }

  void _switchTheme(PortfolioTheme t) {
    if (t == _theme || _slashCtrl.isAnimating) return;
    _pendingTheme = t;
    _slashCtrl.forward();
  }

  void _reorderPhoto(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _photos.removeAt(oldIndex);
      _photos.insert(newIndex, item);
    });
    widget.onServicePhotosChanged?.call(_photos);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = WebBreakpoints.isMobile(screenWidth);

    if (isMobile) {
      return Column(
        children: [
          _buildControls(context),
          const Divider(height: 1),
          SizedBox(
            height: 600,
            child: _buildPreview(context),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Controls panel (left) ──────────────────────────────
        SizedBox(
          width: 360,
          child: _buildControls(context),
        ),

        // ── Divider ────────────────────────────────────────────
        Container(width: 1, color: _Tok.border),

        // ── Preview panel (right) ──────────────────────────────
        Expanded(child: _buildPreview(context)),
      ],
    );
  }

  Widget _buildControls(BuildContext context) {
    return Container(
      color: _Tok.bg,
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section label
            _SectionLabel('TEMA'),
            const SizedBox(height: 12),

            // Theme selector row
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: PortfolioTheme.values.map((t) {
                final selected = t == _theme;
                return _ThemeChip(
                  theme: t,
                  selected: selected,
                  onTap: () => _switchTheme(t),
                );
              }).toList(),
            ),

            const SizedBox(height: 32),
            _SectionLabel('FOTO DE PORTADA'),
            const SizedBox(height: 12),

            // Cover photo uploader
            _CoverPhotoSlot(
              currentUrl: widget.salon.coverPhotoUrl,
              onPick: () async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.image,
                  allowMultiple: false,
                );
                if (result != null && result.files.isNotEmpty) {
                  widget.onCoverPhotoChanged?.call(result.files.first);
                }
              },
            ),

            const SizedBox(height: 32),
            _SectionLabel('FOTOS DE SERVICIOS'),
            const SizedBox(height: 12),

            // Reorderable photo grid
            if (_photos.isEmpty)
              const _EmptyPhotoSlot()
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: _photos.length,
                onReorder: _reorderPhoto,
                proxyDecorator: (child, index, animation) {
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) => Material(
                      color: Colors.transparent,
                      elevation: 8,
                      borderRadius: BorderRadius.circular(BCSpacing.radiusSm),
                      child: child,
                    ),
                    child: child,
                  );
                },
                itemBuilder: (context, i) {
                  return _ReorderablePhotoTile(
                    key: ValueKey(_photos[i]),
                    url: _photos[i],
                    index: i,
                    onRemove: () {
                      setState(() => _photos.removeAt(i));
                      widget.onServicePhotosChanged?.call(_photos);
                    },
                  );
                },
              ),

            const SizedBox(height: 32),
            _SectionLabel('EQUIPO'),
            const SizedBox(height: 12),

            // Staff slots
            if (widget.salon.staffPhotos.isEmpty)
              Text(
                'Sin equipo configurado',
                style: TextStyle(
                  color: _Tok.textHint,
                  fontSize: 14,
                ),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: widget.salon.staffPhotos.map((s) {
                  return _StaffSlot(staff: s);
                }).toList(),
              ),

            const SizedBox(height: 32),
            _SectionLabel('INFORMACION DEL NEGOCIO'),
            const SizedBox(height: 12),

            // Auto-populated info
            _InfoRow(Icons.storefront_outlined, widget.salon.name),
            if (widget.salon.tagline.isNotEmpty)
              _InfoRow(Icons.format_quote_outlined, widget.salon.tagline),
            if (widget.salon.phone.isNotEmpty)
              _InfoRow(Icons.phone_outlined, widget.salon.phone),
            if (widget.salon.address.isNotEmpty)
              _InfoRow(Icons.place_outlined, widget.salon.address),

            const SizedBox(height: 40),

            // Publicar CTA
            SizedBox(
              width: double.infinity,
              child: _GradientButton(
                label: 'Publicar',
                icon: Icons.rocket_launch_outlined,
                onTap: widget.onPublish,
                large: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    return Stack(
      children: [
        // ── Current theme preview ───────────────────────────────
        Container(
          color: _Tok.bg,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: _PortfolioPreview(
              salon: widget.salon,
              theme: _theme,
              photos: _photos,
            ),
          ),
        ),

        // ── Diagonal slash overlay (during transition) ──────────
        if (_slashCtrl.isAnimating)
          AnimatedBuilder(
            animation: _slashAnim,
            builder: (context, _) {
              return CustomPaint(
                size: Size.infinite,
                painter: _DiagonalSlashPainter(
                  progress: _slashAnim.value,
                  colors: _Tok.brandColors,
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Small label like "TEMA" above a section.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => _Tok.brandGradient.createShader(bounds),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Theme selector chip.
class _ThemeChip extends StatefulWidget {
  const _ThemeChip({
    required this.theme,
    required this.selected,
    required this.onTap,
  });
  final PortfolioTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ThemeChip> createState() => _ThemeChipState();
}

class _ThemeChipState extends State<_ThemeChip> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: _Tok.hoverDuration,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: widget.selected ? _Tok.brandGradient : null,
            color: widget.selected
                ? null
                : (_hovering
                    ? _Tok.border
                    : _Tok.card),
            borderRadius: BorderRadius.circular(BCSpacing.radiusFull),
            border: widget.selected
                ? null
                : Border.all(color: _Tok.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.theme.icon,
                size: 16,
                color: widget.selected ? Colors.white : _Tok.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                widget.theme.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: widget.selected ? Colors.white : _Tok.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Slot for the cover photo with upload action.
class _CoverPhotoSlot extends StatefulWidget {
  const _CoverPhotoSlot({this.currentUrl, required this.onPick});
  final String? currentUrl;
  final VoidCallback onPick;

  @override
  State<_CoverPhotoSlot> createState() => _CoverPhotoSlotState();
}

class _CoverPhotoSlotState extends State<_CoverPhotoSlot> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPick,
        child: AnimatedContainer(
          duration: _Tok.hoverDuration,
          height: 160,
          decoration: BoxDecoration(
            color: _Tok.card,
            borderRadius: BorderRadius.circular(BCSpacing.radiusSm),
            border: Border.all(
              color: _hovering ? _Tok.brandColors[1] : _Tok.border,
              width: _hovering ? 2 : 1,
            ),
            image: widget.currentUrl != null
                ? DecorationImage(
                    image: NetworkImage(widget.currentUrl!),
                    fit: BoxFit.cover,
                    colorFilter: _hovering
                        ? ColorFilter.mode(
                            Colors.black.withValues(alpha: 0.3),
                            BlendMode.darken,
                          )
                        : null,
                  )
                : null,
          ),
          child: Center(
            child: AnimatedOpacity(
              opacity: widget.currentUrl == null || _hovering ? 1 : 0,
              duration: _Tok.hoverDuration,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 32,
                    color: widget.currentUrl != null
                        ? Colors.white
                        : _Tok.textHint,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.currentUrl != null ? 'Cambiar foto' : 'Subir foto',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: widget.currentUrl != null
                          ? Colors.white
                          : _Tok.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty state for the photo grid.
class _EmptyPhotoSlot extends StatelessWidget {
  const _EmptyPhotoSlot();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        border: Border.all(color: _Tok.border),
        borderRadius: BorderRadius.circular(BCSpacing.radiusSm),
      ),
      child: Center(
        child: Text(
          'Sin fotos de servicios',
          style: TextStyle(color: _Tok.textHint, fontSize: 14),
        ),
      ),
    );
  }
}

/// A single tile in the reorderable photo grid, with drag handle and remove.
class _ReorderablePhotoTile extends StatelessWidget {
  const _ReorderablePhotoTile({
    required this.url,
    required this.index,
    required this.onRemove,
    super.key,
  });

  final String url;
  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: _Tok.card,
          borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
          border: Border.all(color: _Tok.border),
        ),
        child: Row(
          children: [
            // Drag handle
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(
                  Icons.drag_indicator_rounded,
                  size: 20,
                  color: _Tok.textHint,
                ),
              ),
            ),

            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                url,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 40,
                  height: 40,
                  color: _Tok.border,
                  child: const Icon(Icons.broken_image_outlined, size: 18),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Index label
            Text(
              'Foto ${index + 1}',
              style: const TextStyle(fontSize: 13, color: _Tok.textSecondary),
            ),

            const Spacer(),

            // Remove button
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, size: 18),
              splashRadius: 18,
              color: _Tok.textHint,
              tooltip: 'Eliminar',
            ),
          ],
        ),
      ),
    );
  }
}

/// A staff member slot in the controls panel.
class _StaffSlot extends StatelessWidget {
  const _StaffSlot({required this.staff});
  final PortfolioStaff staff;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundImage:
              staff.photoUrl != null ? NetworkImage(staff.photoUrl!) : null,
          backgroundColor: _Tok.border,
          child: staff.photoUrl == null
              ? const Icon(Icons.person_outline_rounded,
                  size: 24, color: _Tok.textHint)
              : null,
        ),
        const SizedBox(height: 6),
        Text(
          staff.name,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        if (staff.role.isNotEmpty)
          Text(
            staff.role,
            style: const TextStyle(fontSize: 11, color: _Tok.textHint),
          ),
      ],
    );
  }
}

/// Auto-populated info row in the controls panel.
class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _Tok.brandColors[1].withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: _Tok.brandColors[1]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: _Tok.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// The live portfolio preview (right side of the builder).
class _PortfolioPreview extends StatelessWidget {
  const _PortfolioPreview({
    required this.salon,
    required this.theme,
    required this.photos,
  });

  final PortfolioSalonData salon;
  final PortfolioTheme theme;
  final List<String> photos;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // URL preview bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _Tok.card,
              borderRadius: BorderRadius.circular(BCSpacing.radiusFull),
              border: Border.all(color: _Tok.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, size: 14, color: _Tok.textHint),
                const SizedBox(width: 8),
                Text(
                  'beautycita.com/p/${salon.slug.isEmpty ? 'mi-salon' : salon.slug}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: _Tok.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Cover photo
          if (salon.coverPhotoUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(_Tok.cardRadius),
              child: SizedBox(
                height: 200,
                width: double.infinity,
                child: _FadeInNetworkImage(
                  url: salon.coverPhotoUrl!,
                  fit: BoxFit.cover,
                ),
              ),
            )
          else
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: _Tok.brandGradient,
                borderRadius: BorderRadius.circular(_Tok.cardRadius),
              ),
              child: const Center(
                child: Icon(
                  Icons.photo_camera_outlined,
                  size: 48,
                  color: Colors.white54,
                ),
              ),
            ),

          const SizedBox(height: 24),

          // Salon name + info
          Text(
            salon.name.isEmpty ? 'Mi Salon' : salon.name,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: _Tok.textPrimary,
            ),
          ),
          if (salon.tagline.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              salon.tagline,
              style: const TextStyle(fontSize: 16, color: _Tok.textSecondary),
            ),
          ],
          if (salon.rating > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                ...List.generate(5, (i) {
                  final full = i < salon.rating.floor();
                  final half =
                      i == salon.rating.floor() && salon.rating % 1 >= 0.5;
                  return Icon(
                    full
                        ? Icons.star_rounded
                        : half
                            ? Icons.star_half_rounded
                            : Icons.star_outline_rounded,
                    size: 18,
                    color: const Color(0xFFFFA726),
                  );
                }),
                const SizedBox(width: 6),
                Text(
                  '${salon.rating.toStringAsFixed(1)} (${salon.reviewCount})',
                  style:
                      const TextStyle(fontSize: 13, color: _Tok.textSecondary),
                ),
              ],
            ),
          ],

          const SizedBox(height: 32),

          // Service photos grid preview
          if (photos.isNotEmpty) ...[
            _SectionLabel('SERVICIOS'),
            const SizedBox(height: 16),
            _buildPhotoGrid(),
          ],

          // Staff section (if team or portfolio theme)
          if (salon.staffPhotos.isNotEmpty &&
              (theme == PortfolioTheme.teamBuilder ||
                  theme == PortfolioTheme.portfolio)) ...[
            const SizedBox(height: 32),
            _SectionLabel('EQUIPO'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 20,
              runSpacing: 16,
              children: salon.staffPhotos.map((s) {
                return _StaffSlot(staff: s);
              }).toList(),
            ),
          ],

          // Hours (if storefront or local theme)
          if (salon.hours.isNotEmpty &&
              (theme == PortfolioTheme.storefront ||
                  theme == PortfolioTheme.local)) ...[
            const SizedBox(height: 32),
            _SectionLabel('HORARIO'),
            const SizedBox(height: 16),
            ...salon.hours.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key,
                          style: const TextStyle(
                              fontSize: 14, color: _Tok.textSecondary)),
                      Text(e.value,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _Tok.textPrimary)),
                    ],
                  ),
                )),
          ],

          // Contact (if local theme)
          if (theme == PortfolioTheme.local &&
              salon.address.isNotEmpty) ...[
            const SizedBox(height: 32),
            _SectionLabel('UBICACION'),
            const SizedBox(height: 16),
            _InfoRow(Icons.place_outlined, salon.address),
            if (salon.phone.isNotEmpty)
              _InfoRow(Icons.phone_outlined, salon.phone),
          ],

          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid() {
    final cols = photos.length <= 2 ? photos.length : 3;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: photos.map((url) {
        final itemWidth =
            (700.0 - (10.0 * (cols - 1))) / cols;
        return ClipRRect(
          borderRadius: BorderRadius.circular(BCSpacing.radiusSm),
          child: SizedBox(
            width: itemWidth.clamp(100, 300),
            height: itemWidth.clamp(100, 300),
            child: _FadeInNetworkImage(url: url, fit: BoxFit.cover),
          ),
        );
      }).toList(),
    );
  }
}

/// Diagonal slash painter for theme transitions in the portfolio builder.
class _DiagonalSlashPainter extends CustomPainter {
  _DiagonalSlashPainter({required this.progress, required this.colors});
  final double progress;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    // The slash expands from top-right to bottom-left as progress goes 0->1.
    final slashWidth = size.width * 0.15;
    final offset = progress * (size.width + size.height + slashWidth);

    final path = Path()
      ..moveTo(offset - slashWidth, 0)
      ..lineTo(offset, 0)
      ..lineTo(offset - size.height, size.height)
      ..lineTo(offset - size.height - slashWidth, size.height)
      ..close();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colors[0].withValues(alpha: 0.7),
          colors[1].withValues(alpha: 0.5),
          colors[2].withValues(alpha: 0.3),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_DiagonalSlashPainter old) => old.progress != progress;
}

// ═══════════════════════════════════════════════════════════════════════════════
//  5. PHOTO UPLOADER
// ═══════════════════════════════════════════════════════════════════════════════

/// Represents a single file being uploaded.
class UploadItem {
  UploadItem({
    required this.file,
    this.thumbnailBytes,
    this.progress = 0.0,
    this.status = UploadStatus.pending,
    this.errorMessage,
  });

  final PlatformFile file;

  /// Bytes for a local thumbnail preview (if available from the picker).
  final Uint8List? thumbnailBytes;

  /// Upload progress from 0.0 to 1.0.
  double progress;

  /// Current status of this upload.
  UploadStatus status;

  /// Error message if status is [UploadStatus.error].
  String? errorMessage;

  String get displayName => file.name;
}

enum UploadStatus { pending, uploading, success, error }

/// A delightful drag-and-drop upload experience with gradient animations,
/// thumbnail previews, progress bars, and action buttons.
///
/// This widget manages the visual UX only. The actual upload logic
/// (network calls, storage) is handled by the parent via callbacks.
class PhotoUploader extends StatefulWidget {
  const PhotoUploader({
    this.items = const [],
    this.onFilesSelected,
    this.onRemove,
    this.onCrop,
    this.onRotate,
    this.maxFiles = 20,
    this.acceptedExtensions = const ['jpg', 'jpeg', 'png', 'webp'],
    super.key,
  });

  /// Current list of upload items (managed by parent).
  final List<UploadItem> items;

  /// Called when the user selects files via the picker.
  final ValueChanged<List<PlatformFile>>? onFilesSelected;

  /// Called when the user removes a file.
  final ValueChanged<int>? onRemove;

  /// Called when the user taps crop on a file.
  final ValueChanged<int>? onCrop;

  /// Called when the user taps rotate on a file.
  final ValueChanged<int>? onRotate;

  /// Maximum number of files allowed.
  final int maxFiles;

  /// Accepted file extensions.
  final List<String> acceptedExtensions;

  @override
  State<PhotoUploader> createState() => _PhotoUploaderState();
}

class _PhotoUploaderState extends State<PhotoUploader> {
  bool _dragging = false;

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      widget.onFilesSelected?.call(result.files);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Dropzone ─────────────────────────────────────────────
        _Dropzone(
          dragging: _dragging,
          onDragEnter: () => setState(() => _dragging = true),
          onDragLeave: () => setState(() => _dragging = false),
          onTap: _pickFiles,
          itemCount: widget.items.length,
          maxFiles: widget.maxFiles,
        ),

        // ── Upload grid ──────────────────────────────────────────
        if (widget.items.isNotEmpty) ...[
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth > WebBreakpoints.compact ? 4 : 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < widget.items.length; i++)
                    SizedBox(
                      width: (constraints.maxWidth - 12 * (cols - 1)) / cols,
                      child: _UploadTile(
                        item: widget.items[i],
                        index: i,
                        onRemove: () => widget.onRemove?.call(i),
                        onCrop: () => widget.onCrop?.call(i),
                        onRotate: () => widget.onRotate?.call(i),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

/// The large dashed-border dropzone area.
class _Dropzone extends StatefulWidget {
  const _Dropzone({
    required this.dragging,
    required this.onDragEnter,
    required this.onDragLeave,
    required this.onTap,
    required this.itemCount,
    required this.maxFiles,
  });

  final bool dragging;
  final VoidCallback onDragEnter;
  final VoidCallback onDragLeave;
  final VoidCallback onTap;
  final int itemCount;
  final int maxFiles;

  @override
  State<_Dropzone> createState() => _DropzoneState();
}

class _DropzoneState extends State<_Dropzone>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void didUpdateWidget(_Dropzone old) {
    super.didUpdateWidget(old);
    if (widget.dragging && !old.dragging) {
      _pulseCtrl.repeat(reverse: true);
    } else if (!widget.dragging && old.dragging) {
      _pulseCtrl.forward().then((_) => _pulseCtrl.reset());
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.maxFiles - widget.itemCount;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: remaining > 0 ? widget.onTap : null,
        child: AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (context, child) {
            final pulseScale =
                widget.dragging ? 1.0 + (_pulseCtrl.value * 0.02) : 1.0;
            return Transform.scale(scale: pulseScale, child: child);
          },
          child: AnimatedContainer(
            duration: _Tok.hoverDuration,
            height: 180,
            decoration: BoxDecoration(
              color: widget.dragging
                  ? _Tok.brandColors[1].withValues(alpha: 0.04)
                  : _Tok.card,
              borderRadius: BorderRadius.circular(_Tok.cardRadius),
              border: Border.all(
                color:
                    widget.dragging ? _Tok.brandColors[1] : _Tok.border,
                width: widget.dragging ? 2 : 1,
              ),
            ),
            child: CustomPaint(
              painter: _DashedBorderPainter(
                color: widget.dragging
                    ? _Tok.brandColors[1]
                    : _Tok.border,
                radius: _Tok.cardRadius,
                dashLength: 8,
                gapLength: 5,
                strokeWidth: widget.dragging ? 2 : 1.5,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: _Tok.fastAnim,
                      child: widget.dragging
                          ? ShaderMask(
                              key: const ValueKey('drop'),
                              shaderCallback: (bounds) =>
                                  _Tok.brandGradient.createShader(bounds),
                              child: const Icon(
                                Icons.file_download_outlined,
                                size: 40,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              key: const ValueKey('upload'),
                              Icons.cloud_upload_outlined,
                              size: 40,
                              color: _Tok.textHint,
                            ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.dragging
                          ? 'Suelta aqui'
                          : remaining > 0
                              ? 'Arrastra fotos aqui o haz clic para seleccionar'
                              : 'Limite alcanzado ($remaining de ${widget.maxFiles})',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: widget.dragging
                            ? _Tok.brandColors[1]
                            : _Tok.textSecondary,
                      ),
                    ),
                    if (!widget.dragging && remaining > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'JPG, PNG, WEBP — max ${widget.maxFiles} fotos',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _Tok.textHint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dashed border painter for the dropzone.
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.dashLength,
    required this.gapLength,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double dashLength;
  final double gapLength;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dashLength).clamp(0.0, metric.length);
        final segment = metric.extractPath(distance, end);
        canvas.drawPath(segment, paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

/// A single uploaded photo tile with thumbnail, progress, and action buttons.
class _UploadTile extends StatefulWidget {
  const _UploadTile({
    required this.item,
    required this.index,
    required this.onRemove,
    required this.onCrop,
    required this.onRotate,
  });

  final UploadItem item;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onCrop;
  final VoidCallback onRotate;

  @override
  State<_UploadTile> createState() => _UploadTileState();
}

class _UploadTileState extends State<_UploadTile>
    with SingleTickerProviderStateMixin {
  bool _hovering = false;
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );
  }

  @override
  void didUpdateWidget(_UploadTile old) {
    super.didUpdateWidget(old);
    if (widget.item.status == UploadStatus.error &&
        old.item.status != UploadStatus.error) {
      _shakeCtrl.forward().then((_) => _shakeCtrl.reset());
    }
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isError = widget.item.status == UploadStatus.error;
    final isSuccess = widget.item.status == UploadStatus.success;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedBuilder(
        animation: _shakeAnim,
        builder: (context, child) {
          final shake =
              isError ? math.sin(_shakeAnim.value * math.pi * 4) * 4 : 0.0;
          return Transform.translate(
            offset: Offset(shake, 0),
            child: child,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BCSpacing.radiusSm),
            border: Border.all(
              color: isError
                  ? Colors.red
                  : isSuccess
                      ? Colors.green.withValues(alpha: 0.5)
                      : _Tok.border,
              width: isError ? 2 : 1,
            ),
            color: _Tok.card,
          ),
          child: Column(
            children: [
              // Thumbnail area
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(BCSpacing.radiusSm - 1),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Image preview
                      if (widget.item.thumbnailBytes != null)
                        Image.memory(
                          widget.item.thumbnailBytes!,
                          fit: BoxFit.cover,
                        )
                      else
                        Container(
                          color: _Tok.border,
                          child: const Icon(
                            Icons.image_outlined,
                            size: 32,
                            color: _Tok.textHint,
                          ),
                        ),

                      // Success check overlay
                      if (isSuccess)
                        AnimatedOpacity(
                          opacity: 1.0,
                          duration: _Tok.fastAnim,
                          child: Container(
                            color: Colors.green.withValues(alpha: 0.2),
                            child: Center(
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Hover actions
                      if (_hovering && !isSuccess)
                        Container(
                          color: Colors.black.withValues(alpha: 0.4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _SmallIconBtn(
                                Icons.crop_outlined,
                                widget.onCrop,
                                'Recortar',
                              ),
                              const SizedBox(width: 8),
                              _SmallIconBtn(
                                Icons.rotate_right_outlined,
                                widget.onRotate,
                                'Rotar',
                              ),
                              const SizedBox(width: 8),
                              _SmallIconBtn(
                                Icons.delete_outline_rounded,
                                widget.onRemove,
                                'Eliminar',
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Progress bar
              if (widget.item.status == UploadStatus.uploading)
                _GradientProgressBar(progress: widget.item.progress),

              // File name
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(
                  widget.item.displayName,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _Tok.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: _Tok.fastAnim)
            .scale(begin: const Offset(0.9, 0.9), duration: _Tok.fastAnim),
      ),
    );
  }
}

/// A small circular icon button used inside the upload tile hover overlay.
class _SmallIconBtn extends StatelessWidget {
  const _SmallIconBtn(this.icon, this.onTap, this.tooltip);
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

/// Thin gradient progress bar.
class _GradientProgressBar extends StatelessWidget {
  const _GradientProgressBar({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 3,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Container(
                height: 3,
                color: _Tok.border,
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 3,
                width: constraints.maxWidth * progress.clamp(0, 1),
                decoration: const BoxDecoration(gradient: _Tok.brandGradient),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  6. PHOTO EDITOR
// ═══════════════════════════════════════════════════════════════════════════════

/// Preset aspect ratios for the crop tool.
enum CropRatio {
  free('Libre', null),
  square('1:1', 1.0),
  photo4x3('4:3', 4.0 / 3.0),
  wide16x9('16:9', 16.0 / 9.0);

  const CropRatio(this.label, this.value);
  final String label;
  final double? value;
}

/// Lightweight in-browser photo editor with brightness, contrast, saturation,
/// crop, rotate, and flip controls.
///
/// Uses CSS filter-based preview for 60fps performance:
/// `filter: brightness(X) contrast(Y) saturate(Z)`
/// rendered via [ColorFiltered] and [Transform] in Flutter.
class PhotoEditor extends StatefulWidget {
  const PhotoEditor({
    required this.imageUrl,
    this.onApply,
    this.onCancel,
    super.key,
  });

  /// URL of the image to edit.
  final String imageUrl;

  /// Called with the final adjustment values when the user taps "Aplicar".
  final ValueChanged<PhotoAdjustments>? onApply;

  /// Called when the user taps "Cancelar".
  final VoidCallback? onCancel;

  @override
  State<PhotoEditor> createState() => _PhotoEditorState();
}

/// Holds all adjustment values from the photo editor.
class PhotoAdjustments {
  const PhotoAdjustments({
    this.brightness = 1.0,
    this.contrast = 1.0,
    this.saturation = 1.0,
    this.rotation = 0,
    this.flipH = false,
    this.flipV = false,
    this.cropRatio = CropRatio.free,
  });

  /// 0.0 = black, 1.0 = normal, 2.0 = max bright.
  final double brightness;

  /// 0.0 = grey, 1.0 = normal, 2.0 = max contrast.
  final double contrast;

  /// 0.0 = desaturated, 1.0 = normal, 2.0 = max saturated.
  final double saturation;

  /// Number of 90-degree clockwise rotations (0-3).
  final int rotation;

  final bool flipH;
  final bool flipV;
  final CropRatio cropRatio;
}

class _PhotoEditorState extends State<PhotoEditor> {
  double _brightness = 1.0;
  double _contrast = 1.0;
  double _saturation = 1.0;
  int _rotation = 0; // 0, 1, 2, 3 (multiples of 90 degrees)
  bool _flipH = false;
  bool _flipV = false;
  CropRatio _cropRatio = CropRatio.free;

  void _reset() {
    setState(() {
      _brightness = 1.0;
      _contrast = 1.0;
      _saturation = 1.0;
      _rotation = 0;
      _flipH = false;
      _flipV = false;
      _cropRatio = CropRatio.free;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = WebBreakpoints.isMobile(screenWidth);

    if (isMobile) {
      return Column(
        children: [
          Expanded(child: _buildPreview()),
          _buildControls(isMobile: true),
        ],
      );
    }

    return Row(
      children: [
        // ── Preview (left, larger) ──────────────────────────────
        Expanded(
          flex: 3,
          child: _buildPreview(),
        ),

        // ── Controls (right sidebar) ────────────────────────────
        SizedBox(
          width: 320,
          child: _buildControls(isMobile: false),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    // Build the color matrix for brightness/contrast/saturation.
    // This approximates CSS filter: brightness() contrast() saturate()
    // using a 5x4 color matrix applied via ColorFilter.matrix.
    final matrix = _buildColorMatrix(_brightness, _contrast, _saturation);

    Widget image = ColorFiltered(
      colorFilter: ColorFilter.matrix(matrix),
      child: _FadeInNetworkImage(
        url: widget.imageUrl,
        fit: BoxFit.contain,
      ),
    );

    // Apply rotation
    if (_rotation != 0) {
      image = Transform.rotate(
        angle: _rotation * math.pi / 2,
        child: image,
      );
    }

    // Apply flip
    if (_flipH || _flipV) {
      image = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..scaleByDouble(_flipH ? -1.0 : 1.0, _flipV ? -1.0 : 1.0, 1.0, 1.0),
        child: image,
      );
    }

    // Crop ratio overlay
    return Container(
      color: _Tok.textPrimary,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: AspectRatio(
          aspectRatio:
              _cropRatio.value ?? 4.0 / 3.0, // Default aspect for free
          child: ClipRRect(
            borderRadius: BorderRadius.circular(BCSpacing.radiusSm),
            child: Stack(
              fit: StackFit.expand,
              children: [
                image,
                // Crop overlay grid lines
                if (_cropRatio != CropRatio.free)
                  CustomPaint(
                    painter: _CropGridPainter(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls({required bool isMobile}) {
    return Container(
      color: _Tok.bg,
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Adjustments ─────────────────────────────────────
            _SectionLabel('AJUSTES'),
            const SizedBox(height: 16),

            _EditorSlider(
              label: 'Brillo',
              icon: Icons.brightness_6_outlined,
              value: _brightness,
              min: 0.0,
              max: 2.0,
              onChanged: (v) => setState(() => _brightness = v),
            ),
            const SizedBox(height: 12),

            _EditorSlider(
              label: 'Contraste',
              icon: Icons.contrast_outlined,
              value: _contrast,
              min: 0.0,
              max: 2.0,
              onChanged: (v) => setState(() => _contrast = v),
            ),
            const SizedBox(height: 12),

            _EditorSlider(
              label: 'Saturacion',
              icon: Icons.palette_outlined,
              value: _saturation,
              min: 0.0,
              max: 2.0,
              onChanged: (v) => setState(() => _saturation = v),
            ),

            const SizedBox(height: 28),
            _SectionLabel('TRANSFORMAR'),
            const SizedBox(height: 16),

            // Rotate + Flip row
            Row(
              children: [
                _EditorIconButton(
                  icon: Icons.rotate_left_outlined,
                  label: '-90',
                  onTap: () => setState(() => _rotation = (_rotation - 1) % 4),
                ),
                const SizedBox(width: 8),
                _EditorIconButton(
                  icon: Icons.rotate_right_outlined,
                  label: '+90',
                  onTap: () => setState(() => _rotation = (_rotation + 1) % 4),
                ),
                const SizedBox(width: 16),
                _EditorIconButton(
                  icon: Icons.flip_outlined,
                  label: 'H',
                  active: _flipH,
                  onTap: () => setState(() => _flipH = !_flipH),
                ),
                const SizedBox(width: 8),
                _EditorIconButton(
                  icon: Icons.flip_outlined,
                  label: 'V',
                  active: _flipV,
                  rotateIcon: true,
                  onTap: () => setState(() => _flipV = !_flipV),
                ),
              ],
            ),

            const SizedBox(height: 28),
            _SectionLabel('RECORTE'),
            const SizedBox(height: 16),

            // Crop ratio chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: CropRatio.values.map((r) {
                final selected = r == _cropRatio;
                return GestureDetector(
                  onTap: () => setState(() => _cropRatio = r),
                  child: AnimatedContainer(
                    duration: _Tok.hoverDuration,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: selected ? _Tok.brandGradient : null,
                      color: selected ? null : _Tok.card,
                      borderRadius:
                          BorderRadius.circular(BCSpacing.radiusFull),
                      border: selected
                          ? null
                          : Border.all(color: _Tok.border),
                    ),
                    child: Text(
                      r.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : _Tok.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 32),

            // Reset link
            Center(
              child: GestureDetector(
                onTap: _reset,
                child: Text(
                  'Restablecer',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _Tok.brandColors[1],
                    decoration: TextDecoration.underline,
                    decorationColor: _Tok.brandColors[1],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onCancel,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _Tok.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(BCSpacing.radiusSm),
                      ),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _Tok.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GradientButton(
                    label: 'Aplicar',
                    icon: Icons.check_rounded,
                    large: true,
                    onTap: () {
                      widget.onApply?.call(PhotoAdjustments(
                        brightness: _brightness,
                        contrast: _contrast,
                        saturation: _saturation,
                        rotation: _rotation,
                        flipH: _flipH,
                        flipV: _flipV,
                        cropRatio: _cropRatio,
                      ));
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a 5x4 color matrix combining brightness, contrast, and saturation.
  ///
  /// CSS equivalent: `filter: brightness(b) contrast(c) saturate(s)`
  ///
  /// The matrix is row-major: [R, G, B, A, offset] x 4 rows.
  List<double> _buildColorMatrix(
      double brightness, double contrast, double saturation) {
    // Brightness: multiply all color channels.
    final b = brightness;

    // Contrast: offset + scale around 0.5.
    final c = contrast;
    final cOff = (1.0 - c) / 2.0 * 255.0;

    // Saturation: blend with luminance.
    final s = saturation;
    const lr = 0.2126;
    const lg = 0.7152;
    const lb = 0.0722;
    final sr = (1.0 - s) * lr;
    final sg = (1.0 - s) * lg;
    final sb = (1.0 - s) * lb;

    // Combined: brightness * contrast * saturation
    // First saturation matrix, then multiply by contrast, then brightness.
    return <double>[
      b * c * (sr + s), b * c * sg, b * c * sb, 0, cOff * b,
      b * c * sr, b * c * (sg + s), b * c * sb, 0, cOff * b,
      b * c * sr, b * c * sg, b * c * (sb + s), 0, cOff * b,
      0, 0, 0, 1, 0,
    ];
  }
}

/// A labeled slider for the photo editor with icon and value display.
class _EditorSlider extends StatelessWidget {
  const _EditorSlider({
    required this.label,
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final percent = ((value - min) / (max - min) * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: _Tok.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _Tok.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              '$percent%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _Tok.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: _Tok.brandColors[1],
            inactiveTrackColor: _Tok.border,
            thumbColor: _Tok.brandColors[1],
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            overlayColor: _Tok.brandColors[1].withValues(alpha: 0.12),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// Small icon button for rotate/flip actions.
class _EditorIconButton extends StatefulWidget {
  const _EditorIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.rotateIcon = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool rotateIcon;

  @override
  State<_EditorIconButton> createState() => _EditorIconButtonState();
}

class _EditorIconButtonState extends State<_EditorIconButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: _Tok.hoverDuration,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.active
                ? _Tok.brandColors[1].withValues(alpha: 0.12)
                : _hovering
                    ? _Tok.border
                    : _Tok.card,
            borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
            border: Border.all(
              color: widget.active ? _Tok.brandColors[1] : _Tok.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.rotate(
                angle: widget.rotateIcon ? math.pi / 2 : 0,
                child: Icon(
                  widget.icon,
                  size: 18,
                  color: widget.active
                      ? _Tok.brandColors[1]
                      : _Tok.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.active
                      ? _Tok.brandColors[1]
                      : _Tok.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rule-of-thirds crop grid overlay.
class _CropGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 0.5;

    // Vertical lines (thirds)
    canvas.drawLine(
      Offset(size.width / 3, 0),
      Offset(size.width / 3, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 2 / 3, 0),
      Offset(size.width * 2 / 3, size.height),
      paint,
    );

    // Horizontal lines (thirds)
    canvas.drawLine(
      Offset(0, size.height / 3),
      Offset(size.width, size.height / 3),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height * 2 / 3),
      Offset(size.width, size.height * 2 / 3),
      paint,
    );

    // Corner brackets
    final bracketPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const bracketLen = 16.0;
    final corners = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ];

    for (final corner in corners) {
      final xDir = corner.dx == 0 ? 1.0 : -1.0;
      final yDir = corner.dy == 0 ? 1.0 : -1.0;

      canvas.drawLine(
        corner,
        Offset(corner.dx + bracketLen * xDir, corner.dy),
        bracketPaint,
      );
      canvas.drawLine(
        corner,
        Offset(corner.dx, corner.dy + bracketLen * yDir),
        bracketPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SHARED UTILITIES
// ═══════════════════════════════════════════════════════════════════════════════

/// Network image with shimmer placeholder and smooth fade-in.
class _FadeInNetworkImage extends StatelessWidget {
  const _FadeInNetworkImage({
    required this.url,
    this.fit = BoxFit.cover,
  });

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) {
          // Image loaded — fade it in
          return AnimatedOpacity(
            opacity: 1.0,
            duration: _Tok.fastAnim,
            child: child,
          );
        }
        // Shimmer placeholder
        return Container(
          color: _Tok.border.withValues(alpha: 0.3),
        )
            .animate(onPlay: (ctrl) => ctrl.repeat())
            .shimmer(
              duration: const Duration(milliseconds: 1200),
              color: Colors.white.withValues(alpha: 0.3),
            );
      },
      errorBuilder: (_, __, ___) => Container(
        color: _Tok.border,
        child: const Center(
          child: Icon(
            Icons.broken_image_outlined,
            size: 32,
            color: _Tok.textHint,
          ),
        ),
      ),
    );
  }
}

/// Gradient-filled CTA button used across multiple widgets.
class _GradientButton extends StatefulWidget {
  const _GradientButton({
    required this.label,
    this.icon,
    this.onTap,
    this.large = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool large;

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: _Tok.hoverDuration,
          padding: EdgeInsets.symmetric(
            horizontal: widget.large ? 24 : 18,
            vertical: widget.large ? 16 : 10,
          ),
          transform: Matrix4.identity()
            ..scaleByDouble(_hovering ? 1.02 : 1.0, _hovering ? 1.02 : 1.0, 1.0, 1.0),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: _Tok.brandGradient,
            borderRadius: BorderRadius.circular(BCSpacing.radiusMd),
            boxShadow: _hovering
                ? [_Tok.glowShadow(_Tok.brandColors[1])]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18, color: Colors.white),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: widget.large ? 15 : 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
