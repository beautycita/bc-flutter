
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/web_invite_provider.dart';
import '../../widgets/invite/salon_detail_panel.dart';
import '../../widgets/invite/salon_list_panel.dart';

/// Master-detail invite page.
///
/// Desktop (>=1200px): side-by-side list + detail.
/// Tablet (800-1199px): full-width list; detail in a centered dialog.
/// Mobile (<800px): full-width list; detail as full-screen overlay.
class InvitePage extends ConsumerStatefulWidget {
  const InvitePage({this.serviceType, super.key});

  final String? serviceType;

  @override
  ConsumerState<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends ConsumerState<InvitePage> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Location will be handled by the provider if available.
    // On web, we skip JS geolocation interop to avoid dart2js type issues
    // and let the provider load salons without location (shows all nearby).
    if (!mounted) return;

    ref.read(webInviteProvider.notifier).initialize(
          lat: null,
          lng: null,
          serviceType: widget.serviceType,
        );

    setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1200) {
          return _DesktopLayout();
        }
        return _CompactLayout(isTablet: constraints.maxWidth >= 800);
      },
    );
  }
}

// ── Desktop: side-by-side ────────────────────────────────────────────────────

class _DesktopLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SalonListPanel(),
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              boxShadow: [
                BoxShadow(
                  offset: Offset(-2, 0),
                  blurRadius: 8,
                  color: Color(0x0A000000), // black 4%
                ),
              ],
            ),
            child: const SalonDetailPanel(),
          ),
        ),
      ],
    );
  }
}

// ── Compact: list full-width, detail as dialog/overlay ───────────────────────

class _CompactLayout extends ConsumerStatefulWidget {
  const _CompactLayout({required this.isTablet});

  final bool isTablet;

  @override
  ConsumerState<_CompactLayout> createState() => _CompactLayoutState();
}

class _CompactLayoutState extends ConsumerState<_CompactLayout> {
  bool _dialogOpen = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<WebInviteState>(webInviteProvider, (prev, next) {
      final hadSalon = prev?.selectedSalon != null;
      final hasSalon = next.selectedSalon != null;

      // Salon just selected — show detail
      if (!hadSalon && hasSalon && !_dialogOpen) {
        _dialogOpen = true;
        _showDetailOverlay(context);
      }

      // Salon deselected (backToList) — dismiss
      if (hadSalon && !hasSalon && _dialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        _dialogOpen = false;
      }
    });

    return const SalonListPanel();
  }

  void _showDetailOverlay(BuildContext context) {
    if (widget.isTablet) {
      // Tablet: centered dialog with backdrop blur
      showDialog(
        context: context,
        barrierColor: Colors.black26,
        builder: (_) => Center(
          child: Container(
            width: 600,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  offset: Offset(0, 8),
                  blurRadius: 32,
                  color: Color(0x33000000),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  _DialogCloseBar(onClose: _dismissDetail),
                  const Expanded(child: SalonDetailPanel()),
                ],
              ),
            ),
          ),
        ),
      ).then((_) {
        _dialogOpen = false;
        // If user dismissed via barrier tap, clear selection
        final salon = ref.read(webInviteProvider).selectedSalon;
        if (salon != null) {
          ref.read(webInviteProvider.notifier).backToList();
        }
      });
    } else {
      // Mobile: full-screen modal
      Navigator.of(context, rootNavigator: true)
          .push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _dismissDetail,
              ),
              title: const Text(
                'Detalle del salon',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              elevation: 0,
              scrolledUnderElevation: 1,
            ),
            body: const SalonDetailPanel(),
          ),
        ),
      )
          .then((_) {
        _dialogOpen = false;
        final salon = ref.read(webInviteProvider).selectedSalon;
        if (salon != null) {
          ref.read(webInviteProvider.notifier).backToList();
        }
      });
    }
  }

  void _dismissDetail() {
    ref.read(webInviteProvider.notifier).backToList();
  }
}

// ── Dialog close bar ─────────────────────────────────────────────────────────

class _DialogCloseBar extends StatelessWidget {
  const _DialogCloseBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 22),
            onPressed: onClose,
            splashRadius: 20,
          ),
          const Spacer(),
          const Text(
            'Detalle del salon',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const Spacer(),
          const SizedBox(width: 40), // balance close button
        ],
      ),
    );
  }
}
