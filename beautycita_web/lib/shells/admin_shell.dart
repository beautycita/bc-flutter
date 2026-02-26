import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/breakpoints.dart';
import '../widgets/admin_sidebar.dart';

// ── Sidebar state ─────────────────────────────────────────────────────────────

/// Persists sidebar expanded/collapsed preference across navigation.
/// true = expanded (240px), false = collapsed (64px).
final sidebarExpandedProvider = StateProvider<bool>((ref) => true);

// ── Admin Shell ───────────────────────────────────────────────────────────────

/// Persistent layout wrapper for all `/app/admin/*` routes.
///
/// Responsive behavior:
/// - >1200px (desktop): full sidebar (240px) with icons + labels
/// - 800-1200px (tablet): collapsed sidebar (64px) with icons only, tooltips
/// - <800px (mobile): no sidebar, hamburger drawer overlay
///
/// Keyboard shortcuts:
/// - `/` — focus search placeholder
/// - `Esc` — close drawer / dismiss overlays
class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchFocusNode = FocusNode();
  final _shellFocusNode = FocusNode();

  static const double _expandedWidth = 240;
  static const double _collapsedWidth = 64;
  static const _animDuration = Duration(milliseconds: 200);

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _shellFocusNode.dispose();
    super.dispose();
  }

  /// Handle global keyboard shortcuts at the shell level.
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // "/" — focus search
    if (event.logicalKey == LogicalKeyboardKey.slash) {
      // Only if no text field is currently focused
      final primary = FocusManager.instance.primaryFocus;
      if (primary == null || primary == _shellFocusNode) {
        _searchFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
    }

    // Esc — close drawer or unfocus
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
        Navigator.of(context).pop();
        return KeyEventResult.handled;
      }
      // Unfocus search if focused
      if (_searchFocusNode.hasFocus) {
        _searchFocusNode.unfocus();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _navigate(String route) {
    // Close drawer if open (mobile)
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final isExpanded = ref.watch(sidebarExpandedProvider);

    return Focus(
      focusNode: _shellFocusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isDesktop = WebBreakpoints.isDesktop(width);
          final isTablet = WebBreakpoints.isTablet(width);
          final isMobile = WebBreakpoints.isMobile(width);

          // On tablet, force collapsed. On desktop, use user preference.
          final effectiveExpanded = isDesktop ? isExpanded : false;
          final sidebarWidth = effectiveExpanded ? _expandedWidth : _collapsedWidth;

          if (isMobile) {
            return _buildMobileLayout();
          }

          return _buildDesktopLayout(
            sidebarWidth: sidebarWidth,
            isExpanded: effectiveExpanded,
            showToggle: isDesktop,
            isTablet: isTablet,
          );
        },
      ),
    );
  }

  /// Mobile: Scaffold with hamburger + drawer.
  Widget _buildMobileLayout() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          tooltip: 'Menu',
        ),
        title: Text(
          'BeautyCita Admin',
          style: theme.textTheme.titleMedium?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Search placeholder
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _searchFocusNode.requestFocus(),
            tooltip: 'Buscar',
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: AdminSidebar(
            isExpanded: true,
            onToggle: () => Navigator.of(context).pop(),
            onNavTap: _navigate,
          ),
        ),
      ),
      body: widget.child,
    );
  }

  /// Desktop/tablet: persistent sidebar + content.
  Widget _buildDesktopLayout({
    required double sidebarWidth,
    required bool isExpanded,
    required bool showToggle,
    required bool isTablet,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      key: _scaffoldKey,
      body: Row(
        children: [
          // ── Sidebar ──────────────────────────────────────────────────
          AnimatedContainer(
            duration: _animDuration,
            curve: Curves.easeInOut,
            width: sidebarWidth,
            child: AdminSidebar(
              isExpanded: isExpanded,
              onToggle: () {
                ref.read(sidebarExpandedProvider.notifier).state = !isExpanded;
              },
            ),
          ),
          // ── Vertical divider ─────────────────────────────────────────
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: colors.outlineVariant,
          ),
          // ── Content area ─────────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                // Top bar with search placeholder
                _TopBar(
                  searchFocusNode: _searchFocusNode,
                  isTablet: isTablet,
                ),
                // Content
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Top bar with search ───────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.searchFocusNode,
    required this.isTablet,
  });

  final FocusNode searchFocusNode;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Search field placeholder
          SizedBox(
            width: isTablet ? 200 : 280,
            height: 36,
            child: TextField(
              focusNode: searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Buscar... ( / )',
                hintStyle: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.4),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: colors.onSurface.withValues(alpha: 0.4),
                ),
                filled: true,
                fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colors.primary, width: 1.5),
                ),
              ),
              style: theme.textTheme.bodySmall,
            ),
          ),
          const Spacer(),
          // Placeholder action icons
          IconButton(
            icon: Icon(
              Icons.notifications_outlined,
              color: colors.onSurface.withValues(alpha: 0.6),
              size: 22,
            ),
            onPressed: () {},
            tooltip: 'Notificaciones',
          ),
        ],
      ),
    );
  }
}
