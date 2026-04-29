import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:web/web.dart' as web;

import '../config/breakpoints.dart';
import '../config/router.dart';
import '../providers/demo_providers.dart';
import '../providers/demo_session_store.dart' show demoTokenKey;
import '../widgets/business_sidebar.dart';
import 'business_shell.dart' show businessSidebarExpandedProvider;

/// Shell for the read-only demo business portal at `/demo/*`.
///
/// Wraps content in a [ProviderScope] with demo data overrides so that all
/// business pages render static Salon de Vallarta data without hitting Supabase.
/// Adds a persistent banner at the top with a CTA to register.
class DemoShell extends StatelessWidget {
  const DemoShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: demoProviderOverrides,
      child: _DemoShellInner(child: child),
    );
  }
}

class _DemoShellInner extends ConsumerStatefulWidget {
  const _DemoShellInner({required this.child});
  final Widget child;

  @override
  ConsumerState<_DemoShellInner> createState() => _DemoShellInnerState();
}

class _DemoShellInnerState extends ConsumerState<_DemoShellInner> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _shellFocusNode = FocusNode();

  static const double _expandedWidth = 240;
  static const double _collapsedWidth = 64;
  static const _animDuration = Duration(milliseconds: 200);

  @override
  void dispose() {
    _shellFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
        Navigator.of(context).pop();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _navigate(String route) {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
    // Remap /negocio routes to /demo routes
    final demoRoute = route.replaceFirst('/negocio', '/demo');
    context.go(demoRoute);
  }

  Future<void> _exitDemo() async {
    try {
      if (BCSupabase.isInitialized &&
          BCSupabase.client.auth.currentUser != null) {
        await BCSupabase.client.auth.signOut();
      }
    } catch (_) {/* best-effort */}
    try {
      web.window.localStorage.removeItem(demoTokenKey);
    } catch (_) {/* storage unavailable */}
    if (!mounted) return;
    context.go(WebRoutes.home);
  }

  Future<void> _signUpFromDemo() async {
    try {
      if (BCSupabase.isInitialized &&
          BCSupabase.client.auth.currentUser != null) {
        await BCSupabase.client.auth.signOut();
      }
    } catch (_) {/* best-effort */}
    try {
      web.window.localStorage.removeItem(demoTokenKey);
    } catch (_) {/* storage unavailable */}
    if (!mounted) return;
    context.go(WebRoutes.register);
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
          final isMobile = WebBreakpoints.isMobile(width);

          final effectiveExpanded = isDesktop ? isExpanded : false;
          final sidebarWidth =
              effectiveExpanded ? _expandedWidth : _collapsedWidth;

          final content = Column(
            children: [
              _DemoBanner(isMobile: isMobile, onSignUp: _signUpFromDemo),
              Expanded(child: widget.child),
            ],
          );

          if (isMobile) {
            return _buildMobileLayout(content);
          }
          return _buildDesktopLayout(
            content: content,
            sidebarWidth: sidebarWidth,
            isExpanded: effectiveExpanded,
            isDesktop: isDesktop,
          );
        },
      ),
    );
  }

  Widget _buildMobileLayout(Widget content) {
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
          'Demo — Salon de Vallarta',
          style: theme.textTheme.titleMedium?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      drawer: Drawer(
        child: SafeArea(
          child: BusinessSidebar(
            isExpanded: true,
            onToggle: () => Navigator.of(context).pop(),
            onNavTap: _navigate,
            onSignOut: _exitDemo,
            routePrefix: '/demo',
          ),
        ),
      ),
      body: content,
    );
  }

  Widget _buildDesktopLayout({
    required Widget content,
    required double sidebarWidth,
    required bool isExpanded,
    required bool isDesktop,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      key: _scaffoldKey,
      body: Row(
        children: [
          AnimatedContainer(
            duration: _animDuration,
            curve: Curves.easeInOut,
            width: sidebarWidth,
            child: BusinessSidebar(
              isExpanded: isExpanded,
              onToggle: () {
                ref
                    .read(businessSidebarExpandedProvider.notifier)
                    .state = !isExpanded;
              },
              onNavTap: _navigate,
              onSignOut: _exitDemo,
              routePrefix: '/demo',
            ),
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: colors.outlineVariant,
          ),
          Expanded(child: content),
        ],
      ),
    );
  }
}

// ── Demo banner ─────────────────────────────────────────────────────────────

class _DemoBanner extends StatelessWidget {
  const _DemoBanner({required this.isMobile, required this.onSignUp});
  final bool isMobile;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary.withValues(alpha: 0.08),
            colors.tertiary.withValues(alpha: 0.08),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: colors.primary.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.visibility_outlined,
            size: 18,
            color: colors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isMobile
                  ? 'Vista de ejemplo — Salon de Vallarta'
                  : 'Estas viendo un ejemplo del portal de negocios — Salon de Vallarta',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonal(
            onPressed: onSignUp,
            style: FilledButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 20,
                vertical: 8,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              isMobile ? 'Crear salon' : 'Crear mi salon gratis',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
