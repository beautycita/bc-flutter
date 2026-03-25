import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/router.dart';
import '../config/web_theme.dart';

/// A navigation entry in the admin sidebar.
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

/// Navigation items for the admin sidebar.
const _navItems = <_NavItem>[
  _NavItem(label: 'Dashboard', icon: Icons.home_outlined, route: WebRoutes.admin),
  _NavItem(label: 'Usuarios', icon: Icons.people_outlined, route: WebRoutes.adminUsers),
  _NavItem(label: 'Salones', icon: Icons.store_outlined, route: WebRoutes.adminSalons),
  _NavItem(label: 'Solicitudes', icon: Icons.assignment_outlined, route: WebRoutes.adminApplications),
  _NavItem(label: 'Reservas', icon: Icons.calendar_today_outlined, route: WebRoutes.adminBookings),
  _NavItem(label: 'Servicios', icon: Icons.spa_outlined, route: WebRoutes.adminServices),
  _NavItem(label: 'Disputas', icon: Icons.gavel_outlined, route: WebRoutes.adminDisputes),
  _NavItem(label: 'Finanzas', icon: Icons.payments_outlined, route: WebRoutes.adminFinance),
  _NavItem(label: 'Analiticas', icon: Icons.analytics_outlined, route: WebRoutes.adminAnalytics),
  _NavDivider(),
  _NavItem(label: 'Finanzas CEO', icon: Icons.account_balance_outlined, route: WebRoutes.adminFinanceDashboard),
  _NavItem(label: 'Operaciones', icon: Icons.monitor_heart_outlined, route: WebRoutes.adminOperations),
  _NavDivider(),
  _NavItem(label: 'Motor', icon: Icons.settings_outlined, route: WebRoutes.adminEngine),
  _NavItem(label: 'Outreach', icon: Icons.campaign_outlined, route: WebRoutes.adminOutreach),
  _NavDivider(),
  _NavItem(label: 'Config', icon: Icons.build_outlined, route: WebRoutes.adminConfig),
  _NavItem(label: 'Toggles', icon: Icons.toggle_on_outlined, route: WebRoutes.adminToggles),
];

/// Reusable admin sidebar content.
///
/// Renders the logo, navigation items, dividers, and user section.
/// [isExpanded] controls full (labels + icons) vs collapsed (icons only).
/// [onToggle] fires when the expand/collapse chevron is pressed.
/// [onNavTap] fires when a nav item is tapped (optional — defaults to GoRouter navigation).
class AdminSidebar extends StatelessWidget {
  const AdminSidebar({
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
          // ── Logo ──────────────────────────────────────────────────────
          const SizedBox(height: 20),
          _Logo(isExpanded: isExpanded),
          const SizedBox(height: 24),

          // ── Nav items ─────────────────────────────────────────────────
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

          // ── Bottom section: user + collapse toggle ────────────────────
          const Divider(height: 1, thickness: 1, color: kWebCardBorder),
          _UserSection(isExpanded: isExpanded, onSignOut: onSignOut),
          _CollapseToggle(isExpanded: isExpanded, onToggle: onToggle),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Check if a route is the active route.
  /// For the admin dashboard (/app/admin), require exact match.
  /// For sub-routes, use startsWith.
  bool _isRouteActive(String route, String currentLocation) {
    if (route == WebRoutes.admin) {
      return currentLocation == WebRoutes.admin;
    }
    return currentLocation.startsWith(route);
  }
}

// ── Logo ──────────────────────────────────────────────────────────────────────

class _Logo extends StatelessWidget {
  const _Logo({required this.isExpanded});
  final bool isExpanded;

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
          'Admin',
          style: theme.textTheme.bodySmall?.copyWith(
            color: kWebTextHint,
          ),
        ),
      ],
    );
  }
}

// ── Nav tile ──────────────────────────────────────────────────────────────────

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

// ── User section ──────────────────────────────────────────────────────────────

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
                      child: Text(
                        'BC',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: kWebPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'BC Admin',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: kWebTextPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Cerrar sesion',
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
                    message: 'Cerrar sesion',
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: kWebPrimary.withValues(alpha: 0.10),
                      child: Text(
                        'BC',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: kWebPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

// ── Collapse toggle ───────────────────────────────────────────────────────────

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
