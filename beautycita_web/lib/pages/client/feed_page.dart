import 'dart:convert';

import 'package:beautycita_core/models.dart' hide Provider;
import 'package:beautycita_core/supabase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../config/breakpoints.dart';
import '../../config/web_theme.dart';
import '../../widgets/web_design_system.dart';

// ── Feed Page ─────────────────────────────────────────────────────────────────

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  final ScrollController _scrollController = ScrollController();
  final List<FeedItem> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 0;
  String? _selectedCategory;
  static const int _pageSize = 20;

  // Categories shown in the filter sidebar / chips
  static const List<String> _categories = [
    'Cabello',
    'Unas',
    'Maquillaje',
    'Cejas y Pestanas',
    'Cuidado de Piel',
    'Depilacion',
    'Masajes',
    'Novias',
  ];

  @override
  void initState() {
    super.initState();
    _loadFeed();
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
        _scrollController.position.maxScrollExtent - 400) {
      _loadFeed();
    }
  }

  Future<void> _loadFeed() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    try {
      final baseUrl = dotenv.env['SUPABASE_URL'] ?? '';
      final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
      final uri = Uri.parse('$baseUrl/functions/v1/feed-public');

      final body = <String, dynamic>{
        'page': _page,
        'page_size': _pageSize,
      };
      if (_selectedCategory != null) {
        body['category'] = _selectedCategory;
      }

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'apikey': anonKey,
        'Authorization': 'Bearer ${BCSupabase.isAuthenticated ? BCSupabase.client.auth.currentSession?.accessToken ?? anonKey : anonKey}',
      };

      final response = await http.post(uri, headers: headers, body: jsonEncode(body));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawItems = data['items'] as List? ?? data as List? ?? [];
        final newItems = rawItems
            .map((e) => FeedItem.fromJson(e as Map<String, dynamic>))
            .toList();

        if (mounted) {
          setState(() {
            _items.addAll(newItems);
            _page++;
            _hasMore = newItems.length >= _pageSize;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onCategorySelected(String? category) {
    if (category == _selectedCategory) return;
    setState(() {
      _selectedCategory = category;
      _items.clear();
      _page = 0;
      _hasMore = true;
    });
    _loadFeed();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (WebBreakpoints.isDesktop(width)) {
          return _buildDesktop(context);
        } else if (WebBreakpoints.isTablet(width)) {
          return _buildTablet(context);
        } else {
          return _buildMobile(context);
        }
      },
    );
  }

  // ── Desktop: sidebar + masonry grid ───────────────────────────────────────

  Widget _buildDesktop(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left sidebar — category filters
        SizedBox(
          width: 260,
          child: _CategorySidebar(
            categories: _categories,
            selected: _selectedCategory,
            onSelected: _onCategorySelected,
          ),
        ),
        Container(
          width: 1,
          color: kWebCardBorder,
        ),
        // Main masonry area
        Expanded(
          child: _buildMasonryArea(context, columnCount: 4),
        ),
      ],
    );
  }

  // ── Tablet: chips + 2-3 col grid ─────────────────────────────────────────

  Widget _buildTablet(BuildContext context) {
    return Column(
      children: [
        _CategoryChips(
          categories: _categories,
          selected: _selectedCategory,
          onSelected: _onCategorySelected,
        ),
        Expanded(child: _buildMasonryArea(context, columnCount: 3)),
      ],
    );
  }

  // ── Mobile: chips + single col ────────────────────────────────────────────

  Widget _buildMobile(BuildContext context) {
    return Column(
      children: [
        _CategoryChips(
          categories: _categories,
          selected: _selectedCategory,
          onSelected: _onCategorySelected,
        ),
        Expanded(child: _buildMasonryArea(context, columnCount: 1)),
      ],
    );
  }

  // ── Masonry grid ──────────────────────────────────────────────────────────

  Widget _buildMasonryArea(BuildContext context, {required int columnCount}) {
    if (_items.isEmpty && _isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: kWebPrimary),
      );
    }

    if (_items.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: kWebPrimary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.photo_library_outlined,
                  size: 40, color: kWebTextHint),
            ),
            const SizedBox(height: 16),
            const Text(
              'No hay publicaciones todavia',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: kWebTextSecondary,
                fontFamily: 'system-ui',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Las fotos de salones apareceran aqui',
              style: TextStyle(
                fontSize: 14,
                color: kWebTextHint,
                fontFamily: 'system-ui',
              ),
            ),
          ],
        ),
      );
    }

    // Distribute items into columns for masonry effect
    final columns = List.generate(columnCount, (_) => <int>[]);
    for (var i = 0; i < _items.length; i++) {
      columns[i % columnCount].add(i);
    }

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      child: StaggeredFadeIn(
        staggerDelay: const Duration(milliseconds: 60),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var col = 0; col < columnCount; col++) ...[
                if (col > 0) const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      for (final idx in columns[col])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _FeedCard(
                            item: _items[idx],
                            onTap: () => _showDetail(context, _items[idx]),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(color: kWebPrimary),
              ),
            ),
          if (!_hasMore && _items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Has visto todo',
                  style: TextStyle(
                    fontSize: 13,
                    color: kWebTextHint,
                    fontFamily: 'system-ui',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Detail dialog ─────────────────────────────────────────────────────────

  void _showDetail(BuildContext context, FeedItem item) {
    showDialog(
      context: context,
      builder: (ctx) => _FeedDetailDialog(item: item),
    );
  }
}

// ── Category Sidebar (desktop) ──────────────────────────────────────────────

class _CategorySidebar extends StatelessWidget {
  const _CategorySidebar({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kWebSurface,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        children: [
          // Section header with gradient label
          ShaderMask(
            shaderCallback: (bounds) =>
                kWebBrandGradient.createShader(bounds),
            child: const Text(
              'EXPLORAR',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
                color: Colors.white,
                fontFamily: 'system-ui',
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Inspiracion y tendencias',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: kWebTextSecondary,
              fontFamily: 'system-ui',
            ),
          ),
          const SizedBox(height: 24),
          // "All" option
          _SidebarItem(
            label: 'Todo',
            isActive: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final cat in categories)
            _SidebarItem(
              label: cat,
              isActive: selected == cat,
              onTap: () => onSelected(cat),
            ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isActive
                ? kWebPrimary.withValues(alpha: 0.08)
                : _hovered
                    ? kWebCardBorder.withValues(alpha: 0.5)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              // Gradient accent bar for active
              if (widget.isActive)
                Container(
                  width: 3,
                  height: 18,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    gradient: kWebBrandGradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              if (!widget.isActive)
                const SizedBox(width: 13),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      widget.isActive ? FontWeight.w600 : FontWeight.w400,
                  color: widget.isActive ? kWebPrimary : kWebTextPrimary,
                  fontFamily: 'system-ui',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Category Chips (tablet / mobile) ────────────────────────────────────────

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _FilterChip(
            label: 'Todo',
            isActive: selected == null,
            onTap: () => onSelected(null),
            theme: theme,
          ),
          for (final cat in categories)
            _FilterChip(
              label: cat,
              isActive: selected == cat,
              onTap: () => onSelected(cat),
              theme: theme,
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatefulWidget {
  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.theme,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              gradient: widget.isActive ? kWebBrandGradient : null,
              color: widget.isActive
                  ? null
                  : _hovered
                      ? kWebCardBorder
                      : kWebSurface,
              borderRadius: BorderRadius.circular(999),
              border: widget.isActive
                  ? null
                  : Border.all(color: kWebCardBorder),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    widget.isActive ? FontWeight.w600 : FontWeight.w500,
                color: widget.isActive ? Colors.white : kWebTextPrimary,
                fontFamily: 'system-ui',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Feed Card ───────────────────────────────────────────────────────────────

class _FeedCard extends StatefulWidget {
  const _FeedCard({required this.item, required this.onTap});

  final FeedItem item;
  final VoidCallback onTap;

  @override
  State<_FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<_FeedCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: kWebSurface,
            border: Border.all(color: kWebCardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hovered ? 0.06 : 0.03),
                blurRadius: _hovered ? 16 : 10,
                offset: Offset(0, _hovered ? 6 : 2),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: _hovered ? 0.04 : 0.02),
                blurRadius: _hovered ? 30 : 20,
                offset: Offset(0, _hovered ? 10 : 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image with overlay
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: item.isBeforeAfter ? 2.0 : 0.85,
                    child: item.isBeforeAfter
                        ? Row(
                            children: [
                              Expanded(
                                child: Image.network(
                                  item.beforeUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _imagePlaceholder(),
                                ),
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Image.network(
                                  item.afterUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _imagePlaceholder(),
                                ),
                              ),
                            ],
                          )
                        : Image.network(
                            item.afterUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) =>
                                _imagePlaceholder(),
                          ),
                  ),
                  // Gradient overlay with names
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 32, 12, 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.businessName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'system-ui',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (item.staffName != null)
                            Text(
                              item.staffName!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontFamily: 'system-ui',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Before/After badge with gradient
                  if (item.isBeforeAfter)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: kWebBrandGradient,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Antes / Despues',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'system-ui',
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              // Caption + tags + save count
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.caption != null && item.caption!.isNotEmpty) ...[
                      Text(
                        item.caption!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: kWebTextPrimary,
                          height: 1.5,
                          fontFamily: 'system-ui',
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                    ],
                    // Product tags
                    if (item.hasProducts)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final tag in item.productTags.take(3))
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: kWebSecondary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                tag.name,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: kWebSecondary,
                                  fontFamily: 'system-ui',
                                ),
                              ),
                            ),
                          if (item.productTags.length > 3)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: kWebCardBorder,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '+${item.productTags.length - 3}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: kWebTextHint,
                                  fontFamily: 'system-ui',
                                ),
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    // Save count
                    Row(
                      children: [
                        Icon(
                          item.isSaved
                              ? Icons.favorite
                              : Icons.favorite_border_outlined,
                          size: 16,
                          color: item.isSaved
                              ? kWebPrimary
                              : kWebTextHint,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${item.saveCount}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: kWebTextHint,
                            fontFamily: 'system-ui',
                          ),
                        ),
                        const Spacer(),
                        if (item.serviceCategory != null)
                          Text(
                            item.serviceCategory!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: kWebTextHint,
                              fontStyle: FontStyle.italic,
                              fontFamily: 'system-ui',
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: kWebCardBorder,
      child: const Center(
        child: Icon(Icons.image_outlined, size: 48, color: kWebTextHint),
      ),
    );
  }
}

// ── Feed Detail Dialog ──────────────────────────────────────────────────────

class _FeedDetailDialog extends StatelessWidget {
  const _FeedDetailDialog({required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final dialogWidth = width > 900 ? 800.0 : width * 0.9;
    final currencyFormat =
        NumberFormat.currency(locale: 'es_MX', symbol: '\$');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image section
              if (item.isBeforeAfter)
                SizedBox(
                  height: 400,
                  child: Row(
                    children: [
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(item.beforeUrl!, fit: BoxFit.cover),
                            Positioned(
                              bottom: 8,
                              left: 8,
                              child: _badge(theme, 'Antes'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(item.afterUrl, fit: BoxFit.cover),
                            Positioned(
                              bottom: 8,
                              left: 8,
                              child: _badge(theme, 'Despues'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 500),
                  child: Image.network(
                    item.afterUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),

              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Business info row
                    Row(
                      children: [
                        if (item.businessPhotoUrl != null)
                          CircleAvatar(
                            radius: 20,
                            backgroundImage:
                                NetworkImage(item.businessPhotoUrl!),
                          )
                        else
                          CircleAvatar(
                            radius: 20,
                            backgroundColor:
                                theme.colorScheme.primaryContainer,
                            child: Icon(Icons.store,
                                size: 20,
                                color:
                                    theme.colorScheme.onPrimaryContainer),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.businessName,
                                style:
                                    theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (item.staffName != null)
                                Text(
                                  item.staffName!,
                                  style:
                                      theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Save indicator
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.isSaved
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: item.isSaved
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.outline,
                            ),
                            const SizedBox(width: 4),
                            Text('${item.saveCount}',
                                style: theme.textTheme.bodyMedium),
                          ],
                        ),
                      ],
                    ),

                    if (item.caption != null &&
                        item.caption!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(item.caption!, style: theme.textTheme.bodyMedium),
                    ],

                    if (item.serviceCategory != null) ...[
                      const SizedBox(height: 12),
                      Chip(
                        label: Text(item.serviceCategory!),
                        backgroundColor:
                            theme.colorScheme.surfaceContainerLow,
                        side: BorderSide.none,
                      ),
                    ],

                    // Product tags with details
                    if (item.hasProducts) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Productos utilizados',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final tag in item.productTags)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _ProductRow(
                            tag: tag,
                            currencyFormat: currencyFormat,
                          ),
                        ),
                    ],

                    const SizedBox(height: 20),

                    // Close button
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cerrar'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(ThemeData theme, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        gradient: kWebBrandGradient,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFamily: 'system-ui',
        ),
      ),
    );
  }
}

// ── Product Row (detail dialog) ─────────────────────────────────────────────

class _ProductRow extends StatefulWidget {
  const _ProductRow({
    required this.tag,
    required this.currencyFormat,
  });

  final FeedProductTag tag;
  final NumberFormat currencyFormat;

  @override
  State<_ProductRow> createState() => _ProductRowState();
}

class _ProductRowState extends State<_ProductRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tag = widget.tag;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _hovered
              ? theme.colorScheme.surfaceContainerHighest
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                tag.photoUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 48,
                  height: 48,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(Icons.shopping_bag_outlined,
                      size: 24, color: theme.colorScheme.outline),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tag.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (tag.brand != null)
                    Text(
                      tag.brand!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  widget.currencyFormat.format(tag.price),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (!tag.inStock)
                  Text(
                    'Agotado',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
