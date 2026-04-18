import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita_core/supabase.dart';

import '../config/breakpoints.dart';
import '../config/router.dart';
import '../config/web_theme.dart';
import '../providers/auth_provider.dart';

// ── Nav link definitions ────────────────────────────────────────────────────

class _NavDef {
  const _NavDef({required this.label, required this.route, required this.icon});
  final String label;
  final String route;
  final IconData icon;
}

const _navLinks = [
  _NavDef(label: 'Explorar', route: WebRoutes.explorar, icon: Icons.explore_outlined),
  _NavDef(label: 'Reservar', route: WebRoutes.reservar, icon: Icons.calendar_today_outlined),
  _NavDef(label: 'Mis Citas', route: WebRoutes.misCitas, icon: Icons.event_note_outlined),
  _NavDef(label: 'Invitar', route: WebRoutes.invitar, icon: Icons.share_outlined),
];

// ── Client Shell ────────────────────────────────────────────────────────────

class ClientShell extends StatelessWidget {
  const ClientShell({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).matchedLocation;
    final width = MediaQuery.of(context).size.width;
    final isMobile = WebBreakpoints.isMobile(width);

    return Scaffold(
      backgroundColor: kWebBackground,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: _TopNavBar(
          currentPath: currentPath,
          isMobile: isMobile,
        ),
      ),
      drawer: isMobile
          ? _MobileDrawer(currentPath: currentPath)
          : null,
      body: child,
    );
  }
}

// ── Top Navigation Bar ──────────────────────────────────────────────────────

class _TopNavBar extends StatelessWidget {
  const _TopNavBar({
    required this.currentPath,
    required this.isMobile,
  });

  final String currentPath;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: kWebBackground,
        border: Border(
          bottom: BorderSide(color: kWebCardBorder, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // ── Hamburger (mobile) ──
          if (isMobile)
            IconButton(
              icon: const Icon(Icons.menu_outlined, color: kWebTextPrimary),
              onPressed: () => Scaffold.of(context).openDrawer(),
              tooltip: 'Menu',
            ),

          // ── Logo ──
          GestureDetector(
            onTap: () => context.go(WebRoutes.home),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Beauty',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: kWebTextPrimary,
                      fontFamily: 'system-ui',
                    ),
                  ),
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        kWebBrandGradient.createShader(bounds),
                    child: const Text(
                      'Cita',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white, // masked by shader
                        fontFamily: 'system-ui',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // ── Desktop nav links ──
          if (!isMobile)
            for (final link in _navLinks)
              _DesktopNavLink(
                label: link.label,
                icon: link.icon,
                isActive: currentPath == link.route,
                onTap: () => context.go(link.route),
              ),

          const SizedBox(width: 16),

          // ── Avatar circle ──
          _AvatarCircle(),
        ],
      ),
    );
  }
}

// ── Desktop Nav Link (with gradient underline indicator) ─────────────────────

class _DesktopNavLink extends StatefulWidget {
  const _DesktopNavLink({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_DesktopNavLink> createState() => _DesktopNavLinkState();
}

class _DesktopNavLinkState extends State<_DesktopNavLink> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final showIndicator = widget.isActive;
    final textColor = widget.isActive
        ? kWebPrimary
        : _hovering
            ? kWebTextPrimary
            : kWebTextSecondary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.icon,
                    size: 18,
                    color: textColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          widget.isActive ? FontWeight.w600 : FontWeight.w500,
                      color: textColor,
                      fontFamily: 'system-ui',
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // ── Gradient underline indicator ──
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 3,
                width: showIndicator ? 40 : 0,
                decoration: BoxDecoration(
                  gradient: showIndicator ? kWebBrandGradient : null,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Avatar Circle with Account Dropdown ─────────────────────────────────────

class _AvatarCircle extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AvatarCircle> createState() => _AvatarCircleState();
}

class _AvatarCircleState extends ConsumerState<_AvatarCircle> {
  String? _role;
  String? _username;
  String? _fullName;
  String? _avatarUrl;
  String? _email;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (!BCSupabase.isInitialized) {
      await BCSupabase.initialize();
    }
    if (!mounted) return;
    final user = BCSupabase.client.auth.currentUser;
    if (user == null) return;
    _email = user.email;

    final role = await ref.read(authProvider.notifier).getUserRole();

    try {
      final data = await BCSupabase.client
          .from(BCTables.profiles)
          .select('username, full_name, avatar_url')
          .eq('id', user.id)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _role = role;
          _username = data?['username'] as String?;
          _fullName = data?['full_name'] as String?;
          _avatarUrl = data?['avatar_url'] as String?;
        });
      }
    } catch (e) {
      debugPrint('[CLIENT-SHELL] Profile load failed: $e');
      if (mounted) setState(() => _role = role);
    }
  }

  bool get _isBusinessUser =>
      _role == 'stylist' || _role == 'business' ||
      _role == 'admin' || _role == 'superadmin';

  String get _initials {
    if (_fullName != null && _fullName!.isNotEmpty) {
      final parts = _fullName!.trim().split(' ');
      if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      return parts[0][0].toUpperCase();
    }
    if (_username != null && _username!.isNotEmpty) {
      return _username![0].toUpperCase();
    }
    return '?';
  }

  String get _displayName => _fullName ?? _username ?? '';

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 52),
      constraints: const BoxConstraints(minWidth: 240),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: kWebCardBorder),
      ),
      color: kWebSurface,
      onSelected: (value) async {
        switch (value) {
          case 'cuenta':
            context.go(WebRoutes.cuenta);
            break;
          case 'negocio':
            context.go(WebRoutes.negocio);
            break;
          case 'mis_citas':
            context.go(WebRoutes.misCitas);
            break;
          case 'config':
            context.go(WebRoutes.configuracion);
            break;
          case 'soporte':
            context.go(WebRoutes.soporte);
            break;
          case 'logout':
            await ref.read(authProvider.notifier).signOut();
            if (context.mounted) context.go(WebRoutes.auth);
            break;
        }
      },
      itemBuilder: (context) => [
        // ── Header: name + email ──
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_displayName.isNotEmpty)
                Text(
                  _displayName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kWebTextPrimary,
                    fontFamily: 'system-ui',
                  ),
                ),
              if (_email != null)
                Text(
                  _email!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: kWebTextHint,
                    fontFamily: 'system-ui',
                  ),
                ),
            ],
          ),
        ),
        const PopupMenuDivider(),

        // ── Account section ──
        _menuItem('cuenta', Icons.person_outlined, 'Mi Cuenta'),
        if (_isBusinessUser)
          _menuItem('negocio', Icons.storefront_outlined, 'Mi Negocio'),
        _menuItem('mis_citas', Icons.event_note_outlined, 'Mis Citas'),
        const PopupMenuDivider(),

        // ── Settings section ──
        _menuItem('config', Icons.settings_outlined, 'Configuracion'),
        _menuItem('soporte', Icons.help_outline_rounded, 'Ayuda'),
        const PopupMenuDivider(),

        // ── Logout ──
        _menuItem('logout', Icons.logout_outlined, 'Cerrar Sesion'),
      ],
      child: _avatarUrl != null
          ? CircleAvatar(
              radius: 19,
              backgroundImage: NetworkImage(_avatarUrl!),
              backgroundColor: kWebCardBorder,
            )
          : Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: kWebBrandGradient,
              ),
              child: Center(
                child: Text(
                  _initials,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontFamily: 'system-ui',
                  ),
                ),
              ),
            ),
    );
  }

  PopupMenuItem<String> _menuItem(
      String value, IconData icon, String label) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: kWebTextSecondary),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: kWebTextPrimary,
              fontFamily: 'system-ui',
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mobile Drawer ───────────────────────────────────────────────────────────

class _MobileDrawer extends StatelessWidget {
  const _MobileDrawer({required this.currentPath});
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: kWebBackground,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Drawer header with logo ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                children: [
                  Text(
                    'Beauty',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: kWebTextPrimary,
                      fontFamily: 'system-ui',
                    ),
                  ),
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        kWebBrandGradient.createShader(bounds),
                    child: const Text(
                      'Cita',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontFamily: 'system-ui',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: kWebCardBorder, height: 1),
            const SizedBox(height: 8),

            // ── Nav links ──
            for (final link in _navLinks)
              _MobileNavItem(
                label: link.label,
                icon: link.icon,
                isActive: currentPath == link.route,
                onTap: () {
                  Navigator.of(context).pop();
                  context.go(link.route);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _MobileNavItem extends StatefulWidget {
  const _MobileNavItem({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_MobileNavItem> createState() => _MobileNavItemState();
}

class _MobileNavItemState extends State<_MobileNavItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: widget.isActive
                ? kWebPrimary.withValues(alpha: 0.08)
                : _hovering
                    ? kWebCardBorder.withValues(alpha: 0.5)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              // Gradient accent bar for active item
              if (widget.isActive)
                Container(
                  width: 3,
                  height: 20,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    gradient: kWebBrandGradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              Icon(
                widget.icon,
                size: 20,
                color: widget.isActive ? kWebPrimary : kWebTextSecondary,
              ),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                      widget.isActive ? FontWeight.w600 : FontWeight.w500,
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
