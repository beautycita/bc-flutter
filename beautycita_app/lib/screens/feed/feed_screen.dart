import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita/config/fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/providers/feed_provider.dart';
import 'package:beautycita/screens/feed/feed_card.dart';
import 'package:beautycita/widgets/lobby_music_pill.dart';

// Feed category labels. null value means "all".
const _kCategories = <(String, String?)>[
  ('Todo', null),
  ('Cabello', 'cabello'),
  ('Unas', 'unas'),
  ('Pestanas', 'pestanas'),
  ('Cejas', 'cejas'),
  ('Maquillaje', 'maquillaje'),
  ('Facial', 'facial'),
  ('Corporal', 'corporal'),
  ('Novias', 'novias'),
];

// YouTube Shorts hashtag per category (null = default/all).
// Spanish hashtags surface Latin American creators — relatable to our audience.
// Accent-free: YT hashtag URLs don't handle ñ/accents reliably.
const _kVideoHashtags = <String?, String>{
  null: 'cambiodelook',
  'cabello': 'cortedecabello',
  'unas': 'unasacrilicas',
  'pestanas': 'extensionesdepestanas',
  'cejas': 'disenocejas',
  'maquillaje': 'maquillajetutorial',
  'facial': 'cuidadodelapiel',
  'corporal': 'tratamientocorporal',
  'novias': 'maquillajedenovia',
};

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  bool _loadingMore = false;
  late TabController _tabController;

  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _tabIndex = _tabController.index);
      }
    });
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadInitial() {
    final category = ref.read(feedCategoryProvider);
    ref.read(feedPaginationProvider.notifier).loadInitial(category: category);
  }

  void _onScroll() {
    if (_loadingMore) return;
    final threshold = _scrollController.position.maxScrollExtent - 400;
    if (_scrollController.position.pixels >= threshold) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    await ref.read(feedPaginationProvider.notifier).loadMore();
    if (mounted) setState(() => _loadingMore = false);
  }

  Future<void> _onRefresh() async {
    final category = ref.read(feedCategoryProvider);
    await ref
        .read(feedPaginationProvider.notifier)
        .loadInitial(category: category);
  }

  void _selectCategory(String? category) {
    ref.read(feedCategoryProvider.notifier).state = category;
    ref
        .read(feedPaginationProvider.notifier)
        .loadInitial(category: category);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;

    return LobbyMusicPillScope(
      child: Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Explorar',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_border_rounded),
            tooltip: 'Guardados',
            onPressed: () => context.push('/feed/saved'),
          ),
          const SizedBox(width: AppConstants.paddingXS),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          labelColor: palette.primary,
          unselectedLabelColor: palette.onSurface.withValues(alpha: 0.5),
          indicatorColor: palette.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.play_circle_outline_rounded), text: 'Video'),
            Tab(icon: Icon(Icons.photo_library_outlined), text: 'Fotos'),
          ],
        ),
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          // Tab 1: Video (WebView with YouTube Shorts beauty content)
          _VideoFeedTab(
            isDark: Theme.of(context).brightness == Brightness.dark,
          ),

          // Tab 2: Fotos (native portfolio feed)
          _PhotosFeedTab(
            scrollController: _scrollController,
            onRefresh: _onRefresh,
            onSelectCategory: _selectCategory,
          ),
        ],
      ),
      ),
    );
  }
}

// ── Video Feed Tab (WebView) ──────────────────────────────────────────────────
// Pre-creates one WebView per category so switching is instant.

class _VideoFeedTab extends StatefulWidget {
  final bool isDark;
  const _VideoFeedTab({this.isDark = false});

  @override
  State<_VideoFeedTab> createState() => _VideoFeedTabState();
}

class _VideoFeedTabState extends State<_VideoFeedTab>
    with AutomaticKeepAliveClientMixin {
  static const _kUserAgent =
      'Mozilla/5.0 (Linux; Android 14; SM-S911U) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  // Only the currently-selected category has a live WebView. Switching
  // categories disposes the previous controller and spins up a new one.
  // Pre-loading all 9 hashtag pages (old behavior) ran ~270 auto-playing
  // shorts in parallel — crushing the phone and stealing battery. Lazy-load
  // trades a ~1s category-switch load for actual usability.
  WebViewController? _controller;
  String? _currentCategoryValue; // the category key currently loaded
  bool _loading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadCategoryAt(0);
  }

  void _loadCategoryAt(int index) {
    final (_, value) = _kCategories[index];
    if (_currentCategoryValue == value && _controller != null) return;

    // Dispose previous controller so its WebView stops eating cycles.
    _controller = null;
    setState(() {
      _currentCategoryValue = value;
      _loading = true;
    });

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _loading = false);
            if (widget.isDark) {
              _controller?.runJavaScript(
                "document.documentElement.style.cssText += "
                "'background-color: #121212 !important; "
                "color: #E0E0E0 !important;';"
                "document.body.style.cssText += "
                "'background-color: #121212 !important; "
                "color: #E0E0E0 !important;';",
              );
            }
          },
          onNavigationRequest: (request) {
            final url = request.url;
            if (url.contains('youtube.com') ||
                url.contains('ytimg.com') ||
                url.contains('googlevideo.com') ||
                url.contains('google.com')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      )
      ..setUserAgent(_kUserAgent)
      ..loadRequest(_urlForCategory(value));

    setState(() => _controller = controller);
  }

  static Uri _urlForCategory(String? category) {
    final hashtag = _kVideoHashtags[category] ?? 'beautytransformation';
    return Uri.parse('https://www.youtube.com/hashtag/$hashtag/shorts');
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final palette = Theme.of(context).colorScheme;

    const double topClip = 50;

    return Column(
      children: [
        const SizedBox(height: AppConstants.paddingSM),

        // ── Category chips ──────────────────────────────────────────
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenPaddingHorizontal,
            ),
            itemCount: _kCategories.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: AppConstants.paddingXS),
            itemBuilder: (context, index) {
              final (label, _) = _kCategories[index];
              final isSelected = _selectedIndex == index;
              return ChoiceChip(
                label: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? palette.onPrimary
                        : palette.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                selected: isSelected,
                onSelected: (_) {
                  setState(() => _selectedIndex = index);
                  _loadCategoryAt(index);
                },
                selectedColor: palette.primary,
                backgroundColor: palette.surfaceContainerHighest,
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.paddingSM,
                ),
                showCheckmark: false,
              );
            },
          ),
        ),

        const SizedBox(height: AppConstants.paddingSM),

        // ── Single live WebView (lazy-loaded on category change) ───
        Expanded(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              if (_controller != null)
                Positioned(
                  top: -topClip,
                  left: 0,
                  right: 0,
                  bottom: -topClip,
                  // Key by category so Flutter tears down + rebuilds the
                  // widget on switch — guaranteed clean unload.
                  child: WebViewWidget(
                    key: ValueKey(_currentCategoryValue ?? '__todo__'),
                    controller: _controller!,
                  ),
                ),
              if (_loading)
                Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: palette.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Cargando videos...',
                          style: GoogleFonts.nunito(
                            color: palette.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Photos Feed Tab (existing native feed) ────────────────────────────────────

class _PhotosFeedTab extends ConsumerWidget {
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final void Function(String?) onSelectCategory;

  const _PhotosFeedTab({
    required this.scrollController,
    required this.onRefresh,
    required this.onSelectCategory,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).colorScheme;
    final pagination = ref.watch(feedPaginationProvider);
    final selectedCategory = ref.watch(feedCategoryProvider);

    return Column(
      children: [
        const SizedBox(height: AppConstants.paddingSM),

        // ── Category filter chips ───────────────────────────────────────
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenPaddingHorizontal,
            ),
            itemCount: _kCategories.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: AppConstants.paddingXS),
            itemBuilder: (context, index) {
              final (label, value) = _kCategories[index];
              final isSelected = selectedCategory == value;
              return ChoiceChip(
                label: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? palette.onPrimary
                        : palette.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                selected: isSelected,
                onSelected: (_) => onSelectCategory(value),
                selectedColor: palette.primary,
                backgroundColor: palette.surfaceContainerHighest,
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.paddingSM,
                ),
                showCheckmark: false,
              );
            },
          ),
        ),

        const SizedBox(height: AppConstants.paddingSM),

        // ── Feed list ─────────────────────────────────────────────────
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            color: palette.primary,
            child: _buildBody(context, pagination, palette),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    FeedPaginationNotifier pagination,
    ColorScheme palette,
  ) {
    final items = pagination.items;

    if (items.isEmpty && !pagination.loading) {
      return _EmptyFeedState(onRefresh: onRefresh);
    }

    if (items.isEmpty && pagination.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppConstants.paddingXL),
      itemCount: items.length + (pagination.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == items.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppConstants.paddingLG,
            ),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: palette.primary,
              ),
            ),
          );
        }
        return FeedCard(key: ValueKey(items[index].id), item: items[index]);
      },
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyFeedState extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _EmptyFeedState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;

    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.explore_outlined,
                size: AppConstants.iconSizeXXL,
                color: palette.onSurface.withValues(alpha: 0.25),
              ),
              const SizedBox(height: AppConstants.paddingMD),
              Text(
                'Sin contenido aun',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: palette.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: AppConstants.paddingXS),
              Text(
                'Pronto aparecera inspiracion\nde salones cerca de ti.',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: palette.onSurface.withValues(alpha: 0.4),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.paddingXL),
              TextButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  'Intentar de nuevo',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
