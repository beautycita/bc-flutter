import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/providers/feed_provider.dart';
import 'package:beautycita/screens/feed/feed_card.dart';

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

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _scrollController = ScrollController();
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Load first page after the first frame so providers are ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
  }

  @override
  void dispose() {
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
    // Scroll back to top on category change.
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
    final pagination = ref.watch(feedPaginationProvider);
    final selectedCategory = ref.watch(feedCategoryProvider);

    return Scaffold(
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
      ),
      body: Column(
        children: [
          // ── Category filter chips ─────────────────────────────────────
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.screenPaddingHorizontal,
              ),
              itemCount: _kCategories.length,
              separatorBuilder: (_, __) =>
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
                  onSelected: (_) => _selectCategory(value),
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
              onRefresh: _onRefresh,
              color: palette.primary,
              child: _buildBody(context, pagination),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, FeedPaginationNotifier pagination) {
    final palette = Theme.of(context).colorScheme;
    final items = pagination.items;

    // Empty + not loading = show placeholder
    if (items.isEmpty && !pagination.loading) {
      return _EmptyFeedState(onRefresh: _onRefresh);
    }

    // First load spinner
    if (items.isEmpty && pagination.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppConstants.paddingXL),
      itemCount: items.length + (pagination.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == items.length) {
          // Footer loader
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
      // Wrap in ListView so RefreshIndicator works on empty state too.
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
