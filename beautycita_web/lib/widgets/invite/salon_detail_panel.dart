import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/web_invite_provider.dart';
import 'invite_message_card.dart';

/// Right panel of the master-detail invite layout.
///
/// Shows salon details, AI-generated bio, invite message, and send controls.
/// Min width: 600px. White background.
class SalonDetailPanel extends ConsumerStatefulWidget {
  const SalonDetailPanel({super.key});

  @override
  ConsumerState<SalonDetailPanel> createState() => _SalonDetailPanelState();
}

class _SalonDetailPanelState extends ConsumerState<SalonDetailPanel> {
  @override
  void initState() {
    super.initState();

    // Auto-generate message once bio arrives but message is still null.
    ref.listenManual(webInviteProvider, (prev, next) {
      if (next.step == WebInviteStep.salonDetail &&
          next.generatedBio == null &&
          next.selectedSalon != null &&
          (prev?.selectedSalon != next.selectedSalon)) {
        // Provider's selectSalon already clears bio/message;
        // generateMessage() handles both bio + message in parallel.
        ref.read(webInviteProvider.notifier).generateMessage();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(webInviteProvider);

    return Container(
      constraints: const BoxConstraints(minWidth: 600),
      color: Colors.white,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: state.selectedSalon == null
            ? _EmptyState(key: const ValueKey('empty'))
            : _SalonContent(
                key: ValueKey(state.selectedSalon!['id']),
                state: state,
              ),
      ),
    );
  }
}

// ── Empty state ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Brand gradient circle with sparkle icon
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFec4899),
                  Color(0xFF9333ea),
                  Color(0xFF3b82f6),
                ],
              ),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Selecciona un salon para ver detalles',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Busca o elige de la lista',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              color: Color(0xFFB0B8C4),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Salon content (scrollable + sticky bottom bar) ──────────────────────────

class _SalonContent extends ConsumerWidget {
  const _SalonContent({
    required this.state,
    super.key,
  });

  final WebInviteState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // Scrollable body
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroSection(salon: state.selectedSalon!),
                _InfoRow(salon: state.selectedSalon!),
                _BioSection(bio: state.generatedBio, isLoading: _isGenerating),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Divider(height: 1, color: Color(0xFFE5E7EB)),
                ),
                _InviteSection(state: state, ref: ref),
                const SizedBox(height: 100), // room above sticky bar
              ],
            ),
          ),
        ),
        // Sticky bottom bar
        _BottomBar(state: state, ref: ref),
      ],
    );
  }

  bool get _isGenerating =>
      state.step == WebInviteStep.generating ||
      (state.step == WebInviteStep.salonDetail &&
          state.generatedBio == null &&
          state.selectedSalon != null);
}

// ── Hero ────────────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.salon});

  final Map<String, dynamic> salon;

  String get _name => (salon['name'] ?? salon['salon_name'] ?? '').toString();
  String? get _imageUrl =>
      (salon['feature_image_url'] ?? salon['photo_url'])?.toString();

  @override
  Widget build(BuildContext context) {
    if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      return SizedBox(
        height: 220,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              _imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _gradientFallback(),
            ),
            // Gradient overlay
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC000000)],
                  stops: [0.4, 1.0],
                ),
              ),
            ),
            // Salon name bottom-left
            Positioned(
              left: 24,
              bottom: 20,
              right: 24,
              child: Text(
                _name,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(offset: Offset(0, 1), blurRadius: 4),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _gradientFallback();
  }

  Widget _gradientFallback() {
    final initial = _name.isNotEmpty ? _name[0].toUpperCase() : '?';
    return Container(
      height: 220,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFec4899),
            Color(0xFF9333ea),
            Color(0xFF3b82f6),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              initial,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 56,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Info row ────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.salon});

  final Map<String, dynamic> salon;

  @override
  Widget build(BuildContext context) {
    final address =
        (salon['address'] ?? salon['formatted_address'] ?? '').toString();
    final rating = salon['rating'];
    final reviewCount = salon['review_count'] ?? salon['user_ratings_total'];
    final category =
        (salon['category'] ?? salon['service_type'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Location
          if (address.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 16, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    address,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

          // Rating
          if (rating != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded,
                    size: 16, color: Color(0xFFF59E0B)),
                const SizedBox(width: 4),
                Text(
                  _formatRating(rating),
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                if (reviewCount != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    '($reviewCount resenas)',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ],
            ),

          // Category chip
          if (category.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                category,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9333EA),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatRating(dynamic rating) {
    if (rating is num) return rating.toStringAsFixed(1);
    return rating.toString();
  }
}

// ── Bio section ─────────────────────────────────────────────────────────────

class _BioSection extends StatefulWidget {
  const _BioSection({required this.bio, required this.isLoading});

  final String? bio;
  final bool isLoading;

  @override
  State<_BioSection> createState() => _BioSectionState();
}

class _BioSectionState extends State<_BioSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Acerca de este estilista',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          // Blockquote style
          Container(
            padding: const EdgeInsets.only(left: 16),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: Color(0xFFe8b4f8),
                  width: 3,
                ),
              ),
            ),
            child: widget.isLoading ? _buildShimmer() : _buildBio(),
          ),
        ],
      ),
    );
  }

  Widget _buildBio() {
    if (widget.bio == null || widget.bio!.isEmpty) {
      return const Text(
        'Generando...',
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 14,
          fontStyle: FontStyle.italic,
          color: Color(0xFF9CA3AF),
        ),
      );
    }
    return Text(
      widget.bio!,
      style: const TextStyle(
        fontFamily: 'Nunito',
        fontSize: 14,
        fontStyle: FontStyle.italic,
        color: Color(0xFF4B5563),
        height: 1.6,
      ),
    );
  }

  Widget _buildShimmer() {
    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (context, _) {
        final opacity = 0.3 + (_shimmerCtrl.value * 0.4);
        return Opacity(
          opacity: opacity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bar(double.infinity),
              const SizedBox(height: 8),
              _bar(double.infinity),
              const SizedBox(height: 8),
              _bar(200),
            ],
          ),
        );
      },
    );
  }

  Widget _bar(double width) {
    return Container(
      width: width,
      height: 14,
      decoration: BoxDecoration(
        color: const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// ── Invite section ──────────────────────────────────────────────────────────

class _InviteSection extends StatelessWidget {
  const _InviteSection({required this.state, required this.ref});

  final WebInviteState state;
  final WidgetRef ref;

  bool get _isGenerating => state.step == WebInviteStep.generating;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with sparkle icon
          Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFec4899), Color(0xFF9333ea)],
                ).createShader(bounds),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Tu invitacion personalizada',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Invite message card
          InviteMessageCard(
            message: state.inviteMessage,
            isGenerating: _isGenerating,
            onRedo: state.inviteMessage != null
                ? () =>
                    ref.read(webInviteProvider.notifier).generateMessage()
                : null,
          ),

          // Generate button when on salonDetail with no message and not generating
          if (state.inviteMessage == null &&
              !_isGenerating &&
              state.step == WebInviteStep.salonDetail)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFec4899), Color(0xFF9333ea)],
                    ),
                  ),
                  child: ElevatedButton(
                    onPressed: () =>
                        ref.read(webInviteProvider.notifier).generateMessage(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Generar invitacion',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Sticky bottom bar ───────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.state, required this.ref});

  final WebInviteState state;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            offset: Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: SizedBox(
        width: double.infinity,
        child: _buildButton(),
      ),
    );
  }

  Widget _buildButton() {
    switch (state.step) {
      case WebInviteStep.readyToSend:
        return _gradientButton(
          onPressed: () => ref.read(webInviteProvider.notifier).sendInvite(),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.send_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Enviar Invitacion',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );

      case WebInviteStep.sending:
        return _gradientButton(
          onPressed: null,
          child: const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          ),
        );

      case WebInviteStep.sent:
        // Auto-open WA URL after 1 second
        if (state.waUrl != null) {
          Future.delayed(const Duration(seconds: 1), () {
            launchUrl(
              Uri.parse(state.waUrl!),
              mode: LaunchMode.externalApplication,
            );
          });
        }
        return SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              disabledBackgroundColor: const Color(0xFF22C55E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Invitacion Enviada',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );

      default:
        // Disabled grey
        return SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE5E7EB),
              disabledBackgroundColor: const Color(0xFFE5E7EB),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Enviar Invitacion',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ),
        );
    }
  }

  Widget _gradientButton({
    required VoidCallback? onPressed,
    required Widget child,
  }) {
    return SizedBox(
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: onPressed != null
              ? const LinearGradient(
                  colors: [Color(0xFFec4899), Color(0xFF9333ea)],
                )
              : null,
          color: onPressed == null ? const Color(0xFFE5E7EB) : null,
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
