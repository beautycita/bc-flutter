import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/breakpoints.dart';
import '../config/router.dart';
import '../config/web_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/business_sidebar.dart';

// -- Sidebar state ------------------------------------------------------------

/// Persists business sidebar expanded/collapsed preference across navigation.
/// true = expanded (240px), false = collapsed (64px).
final businessSidebarExpandedProvider = StateProvider<bool>((ref) => true);

// -- Business Shell -----------------------------------------------------------

/// Persistent layout wrapper for all `/negocio/*` routes.
///
/// Responsive behavior:
/// - >1200px (desktop): full sidebar (240px) with icons + labels
/// - 800-1200px (tablet): collapsed sidebar (64px) with icons only, tooltips
/// - <800px (mobile): no sidebar, hamburger drawer overlay
///
/// Keyboard shortcuts:
/// - `/` -- focus search placeholder
/// - `Esc` -- close drawer / dismiss overlays
class BusinessShell extends ConsumerStatefulWidget {
  const BusinessShell({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<BusinessShell> createState() => _BusinessShellState();
}

class _BusinessShellState extends ConsumerState<BusinessShell> {
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

    // "/" -- focus search
    if (event.logicalKey == LogicalKeyboardKey.slash) {
      // Only if no text field is currently focused
      final primary = FocusManager.instance.primaryFocus;
      if (primary == null || primary == _shellFocusNode) {
        _searchFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
    }

    // Esc -- close drawer or unfocus
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

  Future<void> _signOut() async {
    await ref.read(authProvider.notifier).signOut();
    if (mounted) context.go(WebRoutes.auth);
  }

  @override
  Widget build(BuildContext context) {
    final isExpanded = ref.watch(businessSidebarExpandedProvider);

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

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: kWebBackground,
      appBar: AppBar(
        backgroundColor: kWebSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_outlined, color: kWebTextPrimary),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          tooltip: 'Menu',
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Beauty',
              style: theme.textTheme.titleMedium?.copyWith(
                color: kWebTextPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            ShaderMask(
              shaderCallback: (bounds) =>
                  kWebBrandGradient.createShader(bounds),
              child: Text(
                'Cita',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              ' Negocio',
              style: theme.textTheme.bodySmall?.copyWith(
                color: kWebTextHint,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: kWebCardBorder),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_outlined, color: kWebTextSecondary),
            onPressed: () => _searchFocusNode.requestFocus(),
            tooltip: 'Buscar',
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: kWebSurface,
        child: SafeArea(
          child: BusinessSidebar(
            isExpanded: true,
            onToggle: () => Navigator.of(context).pop(),
            onNavTap: _navigate,
            onSignOut: _signOut,
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
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: kWebBackground,
      body: Row(
        children: [
          // -- Sidebar --
          AnimatedContainer(
            duration: _animDuration,
            curve: Curves.easeInOut,
            width: sidebarWidth,
            child: BusinessSidebar(
              isExpanded: isExpanded,
              onToggle: () {
                ref.read(businessSidebarExpandedProvider.notifier).state = !isExpanded;
              },
              onSignOut: _signOut,
            ),
          ),
          // -- Content area --
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

// -- Top bar with search ------------------------------------------------------

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

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: kWebSurface,
        border: Border(
          bottom: BorderSide(color: kWebCardBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Search field with subtle bg and focus glow
          SizedBox(
            width: isTablet ? 200 : 280,
            height: 36,
            child: TextField(
              focusNode: searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Buscar... ( / )',
                hintStyle: theme.textTheme.bodySmall?.copyWith(
                  color: kWebTextHint,
                ),
                prefixIcon: const Icon(
                  Icons.search_outlined,
                  size: 18,
                  color: kWebTextHint,
                ),
                filled: true,
                fillColor: kWebBackground,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: kWebCardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: kWebCardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: kWebPrimary, width: 1.5),
                ),
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: kWebTextPrimary,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(
              Icons.notifications_outlined,
              color: kWebTextSecondary,
              size: 22,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Proximamente')),
              );
            },
            tooltip: 'Notificaciones',
          ),
        ],
      ),
    );
  }
}
