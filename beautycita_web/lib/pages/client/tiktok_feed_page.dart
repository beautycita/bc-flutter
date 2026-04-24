/// TikTok-backed /explorar page.
///
/// Reads rows from public.tiktok_feed_items via RPC `get_tiktok_feed` (LATAM-
/// first ordering, cursor-paginated). Renders each as a 9:16 iframe pointing
/// at the official TikTok embed player — no login, no scraping from the
/// browser. Category chips filter the feed client-side.
///
/// Seeding the table:
///   INSERT INTO tiktok_feed_items (video_id, category, creator_handle, creator_region, caption)
///   VALUES ('7385629201234567890', 'maquillaje', '@creator', 'MX', 'caption …');
/// Admins can hide items with UPDATE … SET is_visible=false.
library;

import 'dart:ui_web' as ui_web;

import 'package:beautycita_core/supabase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../../config/breakpoints.dart';

class TikTokFeedPage extends ConsumerStatefulWidget {
  const TikTokFeedPage({super.key});

  @override
  ConsumerState<TikTokFeedPage> createState() => _TikTokFeedPageState();
}

class _TikTokFeedItem {
  _TikTokFeedItem({
    required this.videoId,
    required this.category,
    this.creatorHandle,
    this.creatorRegion,
    this.caption,
    required this.fetchedAt,
  });

  final String videoId;
  final String category;
  final String? creatorHandle;
  final String? creatorRegion;
  final String? caption;
  final DateTime fetchedAt;

  factory _TikTokFeedItem.fromRow(Map<String, dynamic> row) =>
      _TikTokFeedItem(
        videoId: row['video_id'] as String,
        category: row['category'] as String,
        creatorHandle: row['creator_handle'] as String?,
        creatorRegion: row['creator_region'] as String?,
        caption: row['caption'] as String?,
        fetchedAt: DateTime.parse(row['fetched_at'] as String),
      );
}

class _CategoryDef {
  const _CategoryDef(this.label, this.value);
  final String label;
  final String? value;
}

const List<_CategoryDef> _kCategories = [
  _CategoryDef('Todo', null),
  _CategoryDef('Cabello', 'cabello'),
  _CategoryDef('Uñas', 'unas'),
  _CategoryDef('Pestañas', 'pestanas'),
  _CategoryDef('Cejas', 'cejas'),
  _CategoryDef('Maquillaje', 'maquillaje'),
  _CategoryDef('Facial', 'facial'),
  _CategoryDef('Corporal', 'corporal'),
  _CategoryDef('Novias', 'novias'),
  _CategoryDef('Hombres', 'hombres'),
];

class _TikTokFeedPageState extends ConsumerState<TikTokFeedPage> {
  final ScrollController _scrollController = ScrollController();
  final List<_TikTokFeedItem> _items = [];
  String? _selectedCategory;
  bool _isLoading = false;
  bool _hasMore = true;
  DateTime? _cursor;
  String? _errorMessage;

  static const int _pageSize = 21; // divisible by 1/2/3 column layouts

  @override
  void initState() {
    super.initState();
    _loadNext();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 600) {
      _loadNext();
    }
  }

  Future<void> _loadNext() async {
    if (_isLoading || !_hasMore) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await BCSupabase.client.rpc('get_tiktok_feed', params: {
        'p_category': _selectedCategory,
        'p_cursor': _cursor?.toIso8601String(),
        'p_limit': _pageSize,
      });
      final rows = (res as List).cast<Map<String, dynamic>>();
      if (rows.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _items.addAll(rows.map(_TikTokFeedItem.fromRow));
        _cursor = _items.last.fetchedAt;
        _isLoading = false;
        if (rows.length < _pageSize) _hasMore = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'No pudimos cargar el feed. $e';
        _isLoading = false;
      });
    }
  }

  void _selectCategory(String? category) {
    if (category == _selectedCategory) return;
    setState(() {
      _selectedCategory = category;
      _items.clear();
      _cursor = null;
      _hasMore = true;
      _errorMessage = null;
    });
    _loadNext();
  }

  int _colsFor(double width) {
    if (width >= WebBreakpoints.desktop) return 3;
    if (width >= WebBreakpoints.compact) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, c) {
        final cols = _colsFor(c.maxWidth);
        final horizontalPad = c.maxWidth >= WebBreakpoints.desktop ? 48.0 : 16.0;

        return Scaffold(
          backgroundColor: cs.surface,
          body: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: _Header(horizontalPad: horizontalPad),
              ),
              SliverToBoxAdapter(
                child: _CategoryChipsBar(
                  current: _selectedCategory,
                  onSelect: _selectCategory,
                  horizontalPad: horizontalPad,
                ),
              ),
              if (_errorMessage != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPad,
                      vertical: 24,
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: cs.error),
                    ),
                  ),
                ),
              if (_items.isEmpty && !_isLoading && _errorMessage == null)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(),
                ),
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPad,
                  vertical: 16,
                ),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 9 / 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _TikTokCard(item: _items[index]),
                    childCount: _items.length,
                  ),
                ),
              ),
              if (_isLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              if (!_hasMore && _items.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'Has visto todo lo que tenemos, por ahora.',
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.5),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 48)),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.horizontalPad});
  final double horizontalPad;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPad, 32, horizontalPad, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explorar',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tendencias de belleza de creadoras hispanas.',
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChipsBar extends StatelessWidget {
  const _CategoryChipsBar({
    required this.current,
    required this.onSelect,
    required this.horizontalPad,
  });

  final String? current;
  final ValueChanged<String?> onSelect;
  final double horizontalPad;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: horizontalPad),
        itemCount: _kCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = _kCategories[i];
          final selected = cat.value == current;
          return ChoiceChip(
            label: Text(cat.label),
            selected: selected,
            onSelected: (_) => onSelect(cat.value),
            backgroundColor: cs.surfaceContainerHighest,
            selectedColor: cs.primary,
            labelStyle: TextStyle(
              color: selected ? cs.onPrimary : cs.onSurface,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
            side: BorderSide(
              color: selected
                  ? cs.primary
                  : cs.onSurface.withValues(alpha: 0.1),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.movie_outlined, size: 64, color: cs.primary),
            const SizedBox(height: 16),
            Text(
              'Todavía no hay videos curados.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Estamos cargando el feed. Vuelve pronto.',
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual TikTok card — registers a unique platform-view factory that
/// creates an iframe pointing at TikTok's official embed player.
class _TikTokCard extends StatefulWidget {
  const _TikTokCard({required this.item});
  final _TikTokFeedItem item;

  @override
  State<_TikTokCard> createState() => _TikTokCardState();
}

class _TikTokCardState extends State<_TikTokCard> {
  late final String _viewType;
  static final Set<String> _registeredViewTypes = {};

  @override
  void initState() {
    super.initState();
    _viewType = 'tiktok-embed-${widget.item.videoId}';
    if (_registeredViewTypes.add(_viewType)) {
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
        final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
        iframe.src = 'https://www.tiktok.com/embed/v2/${widget.item.videoId}';
        iframe.allow =
            'autoplay; clipboard-write; encrypted-media; fullscreen; picture-in-picture';
        iframe.setAttribute('allowfullscreen', '');
        iframe.setAttribute('loading', 'lazy');
        iframe.setAttribute('referrerpolicy', 'strict-origin-when-cross-origin');
        iframe.style.border = '0';
        iframe.style.width = '100%';
        iframe.style.height = '100%';
        iframe.style.borderRadius = '16px';
        iframe.style.backgroundColor = '#000';
        return iframe;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: cs.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: HtmlElementView(viewType: _viewType),
            ),
            if (widget.item.creatorHandle != null)
              Positioned(
                left: 12,
                bottom: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.item.creatorHandle!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (widget.item.creatorRegion != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            widget.item.creatorRegion!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
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
