import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/router.dart';
import '../config/web_theme.dart';

/// A navigation entry in the business sidebar.
class _NavItem {
  final String label;
  final IconData icon;
  final String route;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.route,
  });
}

/// Sentinel type for dividers in the nav list.
class _NavDivider extends _NavItem {
  const _NavDivider() : super(label: '', icon: Icons.remove, route: '');
}

/// Navigation items for the business sidebar.
const _navItems = <_NavItem>[
  _NavItem(label: 'Dashboard', icon: Icons.dashboard_outlined, route: WebRoutes.negocio),
  _NavItem(label: 'Calendario', icon: Icons.calendar_month_outlined, route: WebRoutes.negocioCalendar),
  _NavItem(label: 'Cal. Externo', icon: Icons.sync_outlined, route: WebRoutes.negocioCalendarSync),
  _NavItem(label: 'Servicios', icon: Icons.spa_outlined, route: WebRoutes.negocioServices),
  _NavItem(label: 'Staff', icon: Icons.people_outlined, route: WebRoutes.negocioStaff),
  _NavDivider(),
  _NavItem(label: 'Pagos', icon: Icons.payments_outlined, route: WebRoutes.negocioPayments),
  _NavItem(label: 'Disputas', icon: Icons.gavel_outlined, route: WebRoutes.negocioDisputes),
  _NavItem(label: 'QR Walk-in', icon: Icons.qr_code_2_outlined, route: WebRoutes.negocioQr),
  _NavItem(label: 'Resenas', icon: Icons.reviews_outlined, route: WebRoutes.negocioReviews),
  _NavItem(label: 'Tienda', icon: Icons.storefront_outlined, route: WebRoutes.negocioPos),
  _NavDivider(),
  _NavItem(label: 'Configuracion', icon: Icons.settings_outlined, route: WebRoutes.negocioSettings),
];

/// Reusable business sidebar content.
///
/// Renders the logo, navigation items, dividers, and user section.
/// [isExpanded] controls full (labels + icons) vs collapsed (icons only).
/// [onToggle] fires when the expand/collapse chevron is pressed.
/// [onNavTap] fires when a nav item is tapped (optional — defaults to GoRouter navigation).
class BusinessSidebar extends StatelessWidget {
  const BusinessSidebar({
    required this.isExpanded,
    required this.onToggle,
    this.onNavTap,
    this.onSignOut,
    this.routePrefix,
    super.key,
  });

  final bool isExpanded;
  final VoidCallback onToggle;
  final void Function(String route)? onNavTap;
  final VoidCallback? onSignOut;

  /// When set, route matching uses this prefix instead of `/negocio`.
  /// Used by the demo shell so sidebar highlights work on `/demo/*` routes.
  final String? routePrefix;

  @override
  Widget build(BuildContext context) {
    final currentLocation = GoRouterState.of(context).matchedLocation;

    return Container(
      decoration: const BoxDecoration(
        color: kWebSurface,
        border: Border(
          right: BorderSide(color: kWebCardBorder, width: 1),
        ),
      ),
      child: Column(
        children: [
          // -- Logo --
          const SizedBox(height: 20),
          _Logo(isExpanded: isExpanded, isDemo: routePrefix != null),
          const SizedBox(height: 24),

          // -- Nav items --
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final item in _navItems)
                  if (item is _NavDivider)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: kWebCardBorder,
                      ),
                    )
                  else
                    _SidebarNavTile(
                      item: item,
                      isExpanded: isExpanded,
                      isActive: _isRouteActive(item.route, currentLocation),
                      onTap: () {
                        if (onNavTap != null) {
                          onNavTap!(item.route);
                        } else {
                          context.go(item.route);
                        }
                      },
                    ),
              ],
            ),
          ),

          // -- Bottom section: user + collapse toggle --
          const Divider(height: 1, thickness: 1, color: kWebCardBorder),
          _UserSection(
            isExpanded: isExpanded,
            onSignOut: onSignOut,
            isDemo: routePrefix != null,
          ),
          _CollapseToggle(isExpanded: isExpanded, onToggle: onToggle),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Check if a route is the active route.
  /// When [routePrefix] is set, maps the nav item route from /negocio to the
  /// demo prefix for comparison.
  bool _isRouteActive(String route, String currentLocation) {
    final effectiveRoute = routePrefix != null
        ? route.replaceFirst('/negocio', routePrefix!)
        : route;
    final baseRoute = routePrefix ?? WebRoutes.negocio;
    if (effectiveRoute == baseRoute) {
      return currentLocation == baseRoute;
    }
    return currentLocation.startsWith(effectiveRoute);
  }
}

// -- Logo -------------------------------------------------------------------

class _Logo extends StatelessWidget {
  const _Logo({required this.isExpanded, this.isDemo = false});
  final bool isExpanded;
  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!isExpanded) {
      // Collapsed: gradient "BC" pill
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: kWebBrandGradient,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          'BC',
          style: theme.textTheme.labelLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Column(
      children: [
        // Gradient logo box
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: kWebBrandGradient,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            'BC',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // "Beauty" in dark + "Cita" in gradient
        Row(
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
                  color: Colors.white, // masked by shader
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        Text(
          isDemo ? 'Demo' : 'Negocio',
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDemo ? kWebTertiary : kWebTextHint,
            fontWeight: isDemo ? FontWeight.w600 : null,
          ),
        ),
      ],
    );
  }
}

// -- Nav tile ----------------------------------------------------------------

class _SidebarNavTile extends StatefulWidget {
  const _SidebarNavTile({
    required this.item,
    required this.isExpanded,
    required this.isActive,
    required this.onTap,
  });

  final _NavItem item;
  final bool isExpanded;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_SidebarNavTile> createState() => _SidebarNavTileState();
}

class _SidebarNavTileState extends State<_SidebarNavTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isActive = widget.isActive;
    final bgColor = isActive
        ? kWebPrimary.withValues(alpha: 0.08)
        : _hovering
            ? kWebPrimary.withValues(alpha: 0.04)
            : Colors.transparent;
    final iconColor =
        isActive ? kWebPrimary : kWebTextSecondary;
    final textColor =
        isActive ? kWebTextPrimary : kWebTextSecondary;

    final tile = MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: widget.isExpanded ? 8 : 0,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: widget.isExpanded
              ? Row(
                  children: [
                    // Gradient left accent bar for active item
                    if (isActive)
                      Container(
                        width: 3,
                        height: 24,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          gradient: kWebBrandGradient,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      )
                    else
                      const SizedBox(width: 11), // 3 + 8 spacing match
                    // 34x34 icon box
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isActive
                            ? kWebPrimary.withValues(alpha: 0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(widget.item.icon, size: 20, color: iconColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.item.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: textColor,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )
              : Center(
                  // 34x34 icon box in collapsed mode
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isActive
                          ? kWebPrimary.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(widget.item.icon, size: 20, color: iconColor),
                  ),
                ),
        ),
      ),
    );

    if (!widget.isExpanded) {
      return Tooltip(
        message: widget.item.label,
        preferBelow: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: tile,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: tile,
    );
  }
}

// -- User section ------------------------------------------------------------

class _UserSection extends StatefulWidget {
  const _UserSection({
    required this.isExpanded,
    this.onSignOut,
    this.isDemo = false,
  });
  final bool isExpanded;
  final VoidCallback? onSignOut;
  final bool isDemo;

  @override
  State<_UserSection> createState() => _UserSectionState();
}

class _UserSectionState extends State<_UserSection> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onSignOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: widget.isExpanded ? 16 : 8,
            vertical: 12,
          ),
          color: _hovering
              ? kWebPrimary.withValues(alpha: 0.04)
              : Colors.transparent,
          child: widget.isExpanded
              ? Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: kWebPrimary.withValues(alpha: 0.10),
                      child: Icon(
                        Icons.storefront_outlined,
                        size: 18,
                        color: kWebPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.isDemo ? 'Salon de Vallarta' : 'Mi Negocio',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: kWebTextPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            widget.isDemo
                                ? 'Salir del demo'
                                : 'Cerrar sesion',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: kWebTextHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.logout_outlined,
                      size: 18,
                      color: kWebTextHint,
                    ),
                  ],
                )
              : Center(
                  child: Tooltip(
                    message: widget.isDemo ? 'Salir del demo' : 'Cerrar sesion',
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: kWebPrimary.withValues(alpha: 0.10),
                      child: Icon(
                        Icons.storefront_outlined,
                        size: 18,
                        color: kWebPrimary,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

// -- Collapse toggle ---------------------------------------------------------

class _CollapseToggle extends StatefulWidget {
  const _CollapseToggle({required this.isExpanded, required this.onToggle});
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  State<_CollapseToggle> createState() => _CollapseToggleState();
}

class _CollapseToggleState extends State<_CollapseToggle> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: _hovering
              ? kWebPrimary.withValues(alpha: 0.04)
              : Colors.transparent,
          child: Center(
            child: AnimatedRotation(
              turns: widget.isExpanded ? 0 : 0.5,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.chevron_left_outlined,
                size: 20,
                color: kWebTextHint,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
