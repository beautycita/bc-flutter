import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/router.dart';

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
  _NavItem(label: 'Servicios', icon: Icons.spa_outlined, route: WebRoutes.negocioServices),
  _NavItem(label: 'Staff', icon: Icons.people_outlined, route: WebRoutes.negocioStaff),
  _NavDivider(),
  _NavItem(label: 'Pagos', icon: Icons.payments_outlined, route: WebRoutes.negocioPayments),
  _NavItem(label: 'Disputas', icon: Icons.gavel_outlined, route: WebRoutes.negocioDisputes),
  _NavItem(label: 'QR Walk-in', icon: Icons.qr_code_2_outlined, route: WebRoutes.negocioQr),
  _NavItem(label: 'Resenas', icon: Icons.reviews_outlined, route: WebRoutes.negocioReviews),
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
    super.key,
  });

  final bool isExpanded;
  final VoidCallback onToggle;
  final void Function(String route)? onNavTap;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final currentLocation = GoRouterState.of(context).matchedLocation;

    return ColoredBox(
      color: colors.surface,
      child: Column(
        children: [
          // -- Logo --
          const SizedBox(height: 20),
          _Logo(isExpanded: isExpanded),
          const SizedBox(height: 24),

          // -- Nav items --
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final item in _navItems)
                  if (item is _NavDivider)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: colors.outlineVariant,
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
          const Divider(height: 1),
          _UserSection(isExpanded: isExpanded, onSignOut: onSignOut),
          _CollapseToggle(isExpanded: isExpanded, onToggle: onToggle),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Check if a route is the active route.
  /// For the business dashboard (/negocio), require exact match.
  /// For sub-routes, use startsWith.
  bool _isRouteActive(String route, String currentLocation) {
    if (route == WebRoutes.negocio) {
      return currentLocation == WebRoutes.negocio;
    }
    return currentLocation.startsWith(route);
  }
}

// -- Logo -------------------------------------------------------------------

class _Logo extends StatelessWidget {
  const _Logo({required this.isExpanded});
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (!isExpanded) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          'BC',
          style: theme.textTheme.labelLarge?.copyWith(
            color: colors.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            'BC',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'BeautyCita',
          style: theme.textTheme.titleMedium?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'Negocio',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurface.withValues(alpha: 0.5),
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
    final colors = theme.colorScheme;

    final isActive = widget.isActive;
    final bgColor = isActive
        ? colors.primary.withValues(alpha: 0.12)
        : _hovering
            ? colors.primary.withValues(alpha: 0.06)
            : Colors.transparent;
    final iconColor = isActive ? colors.primary : colors.onSurface.withValues(alpha: 0.7);
    final textColor = isActive ? colors.primary : colors.onSurface.withValues(alpha: 0.85);

    final tile = MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: widget.isExpanded ? 12 : 0,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: widget.isExpanded
              ? Row(
                  children: [
                    Icon(widget.item.icon, size: 22, color: iconColor),
                    const SizedBox(width: 12),
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
                  child: Icon(widget.item.icon, size: 22, color: iconColor),
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
  const _UserSection({required this.isExpanded, this.onSignOut});
  final bool isExpanded;
  final VoidCallback? onSignOut;

  @override
  State<_UserSection> createState() => _UserSectionState();
}

class _UserSectionState extends State<_UserSection> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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
          color: _hovering ? colors.primary.withValues(alpha: 0.04) : Colors.transparent,
          child: widget.isExpanded
              ? Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: colors.primary.withValues(alpha: 0.15),
                      child: Icon(
                        Icons.storefront_outlined,
                        size: 18,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Mi Negocio',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Cerrar sesion',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.logout_outlined,
                      size: 18,
                      color: colors.onSurface.withValues(alpha: 0.5),
                    ),
                  ],
                )
              : Center(
                  child: Tooltip(
                    message: 'Cerrar sesion',
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: colors.primary.withValues(alpha: 0.15),
                      child: Icon(
                        Icons.storefront_outlined,
                        size: 18,
                        color: colors.primary,
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
    final colors = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: _hovering ? colors.primary.withValues(alpha: 0.06) : Colors.transparent,
          child: Center(
            child: AnimatedRotation(
              turns: widget.isExpanded ? 0 : 0.5,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.chevron_left,
                size: 20,
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
