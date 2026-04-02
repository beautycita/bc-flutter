import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/constants.dart';
import '../../providers/invite_provider.dart';
import '../../services/toast_service.dart';
import 'invite_message_bubble.dart';

/// Salon detail screen in the invite flow.
/// Shows hero photo, salon info, Aphrodite-generated bio,
/// personalized invite message, and send-via-WhatsApp CTA.
class InviteSalonDetailScreen extends ConsumerStatefulWidget {
  const InviteSalonDetailScreen({super.key});

  @override
  ConsumerState<InviteSalonDetailScreen> createState() =>
      _InviteSalonDetailScreenState();
}

class _InviteSalonDetailScreenState
    extends ConsumerState<InviteSalonDetailScreen> {
  bool _autoGenTriggered = false;

  @override
  Widget build(BuildContext context) {
    // Listen for errors and success
    ref.listen<InviteState>(inviteProvider, (prev, next) {
      if (next.step == InviteStep.error && next.error != null) {
        ToastService.showError(next.error!);
      }
      if (next.step == InviteStep.sent && prev?.step != InviteStep.sent) {
        ToastService.showSuccess('Invitación enviada');
      }
    });

    final state = ref.watch(inviteProvider);
    final salon = state.selectedSalon;
    if (salon == null) {
      // Salon cleared (e.g., backToList was called) — pop this screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
      });
      return const Scaffold(backgroundColor: Colors.white);
    }

    // Auto-generate message when bio is ready and we haven't triggered yet.
    if (state.generatedBio != null &&
        state.inviteMessage == null &&
        state.step == InviteStep.salonDetail &&
        !_autoGenTriggered) {
      _autoGenTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(inviteProvider.notifier).generateMessage();
      });
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                // --- Hero ---
                SliverToBoxAdapter(child: _buildHero(context, salon, state)),

                // --- Info section ---
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _buildInfoSection(salon),
                  ),
                ),

                // --- Bio section ---
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: _buildBioSection(state),
                  ),
                ),

                // --- Divider ---
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Divider(height: 1),
                  ),
                ),

                // --- Message section ---
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: _buildMessageSection(state),
                  ),
                ),
              ],
            ),
          ),

          // --- Bottom bar ---
          _buildBottomBar(state),
        ],
      ),
    );
  }

  // ─── Hero ──────────────────────────────────────────────────────────────

  Widget _buildHero(
    BuildContext context,
    dynamic salon,
    InviteState state,
  ) {
    const heroHeight = 240.0;
    final hasPhoto = salon.photoUrl != null;

    return SizedBox(
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          if (hasPhoto)
            Image.network(
              salon.photoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _gradientPlaceholder(),
            )
          else
            _gradientPlaceholder(),

          // Dark gradient overlay for text readability
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black54],
                stops: [0.4, 1.0],
              ),
            ),
          ),

          // Salon name at bottom-left
          Positioned(
            left: 20,
            right: 60,
            bottom: 16,
            child: Text(
              salon.name,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  const Shadow(blurRadius: 8, color: Colors.black45),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: Material(
              color: Colors.black26,
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).pop();
                  ref.read(inviteProvider.notifier).backToList();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradientPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFec4899), Color(0xFF9333ea)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.store_rounded, size: 64, color: Colors.white54),
      ),
    );
  }

  // ─── Info section ──────────────────────────────────────────────────────

  Widget _buildInfoSection(dynamic salon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Address + city
        if (salon.address != null || salon.city != null)
          Row(
            children: [
              Icon(Icons.location_on_outlined,
                  size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  [salon.address, salon.city]
                      .where((s) => s != null && (s as String).isNotEmpty)
                      .join(', '),
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

        const SizedBox(height: 8),

        // Rating
        if (salon.rating != null)
          Row(
            children: [
              const Icon(Icons.star_rounded,
                  size: 18, color: Color(0xFFFFB300)),
              const SizedBox(width: 4),
              Text(
                salon.rating!.toStringAsFixed(1),
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (salon.reviewsCount != null) ...[
                const SizedBox(width: 4),
                Text(
                  '(${salon.reviewsCount} resenas)',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),

        const SizedBox(height: 10),

        // City chip
        if (salon.city != null && (salon.city as String).isNotEmpty)
          Wrap(
            spacing: 8,
            children: [
              Chip(
                label: Text(
                  salon.city!,
                  style: GoogleFonts.nunito(fontSize: 12),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ],
          ),
      ],
    );
  }

  // ─── Bio section ───────────────────────────────────────────────────────

  Widget _buildBioSection(InviteState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Acerca de este estilista',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        if (state.generatedBio != null)
          Text(
            state.generatedBio!,
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              height: 1.5,
            ),
          )
        else
          // Shimmer placeholder — 3 lines
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _StaticShimmerBar(width: 260),
              SizedBox(height: 8),
              _StaticShimmerBar(width: 220),
              SizedBox(height: 8),
              _StaticShimmerBar(width: 180),
            ],
          ),
      ],
    );
  }

  // ─── Message section ───────────────────────────────────────────────────

  Widget _buildMessageSection(InviteState state) {
    final isGenerating = state.step == InviteStep.generating;
    final hasMessage = state.inviteMessage != null;
    final isPreGenerate =
        state.step == InviteStep.salonDetail && !hasMessage && !_autoGenTriggered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with Aphrodite badge
        Row(
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFec4899), Color(0xFF9333ea)],
              ).createShader(bounds),
              child: const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 6),
            Text(
              'Invitación',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (isPreGenerate)
          // "Generate" button if auto-gen hasn't fired
          Center(
            child: _GradientButton(
              label: 'Generar invitacion',
              icon: Icons.auto_awesome,
              onTap: () {
                _autoGenTriggered = true;
                ref.read(inviteProvider.notifier).generateMessage();
              },
            ),
          )
        else
          InviteMessageBubble(
            message: hasMessage ? state.inviteMessage : null,
            isGenerating: isGenerating,
            onRedo: hasMessage
                ? () => ref.read(inviteProvider.notifier).generateMessage()
                : null,
          ),
      ],
    );
  }

  // ─── Bottom bar ────────────────────────────────────────────────────────

  Widget _buildBottomBar(InviteState state) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: _buildBottomButton(state),
    );
  }

  Widget _buildBottomButton(InviteState state) {
    switch (state.step) {
      case InviteStep.readyToSend:
        return _GradientButton(
          label: 'Enviar Invitacion',
          icon: Icons.chat_rounded,
          iconColor: const Color(0xFF25D366),
          onTap: () async {
            await ref.read(inviteProvider.notifier).sendInvite();
          },
        );
      case InviteStep.sending:
        return const SizedBox(
          height: AppConstants.minTouchHeight,
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
        );
      case InviteStep.sent:
        // Launch WA URL if available
        _launchWaIfReady(state);
        return Container(
          height: AppConstants.minTouchHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF25D366),
            borderRadius: BorderRadius.circular(AppConstants.radiusLG),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Invitacion Enviada',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      default:
        // Disabled state while generating or before message is ready
        return Container(
          height: AppConstants.minTouchHeight,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(AppConstants.radiusLG),
          ),
          child: Center(
            child: Text(
              'Enviar Invitacion',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.grey[500],
              ),
            ),
          ),
        );
    }
  }

  bool _waLaunched = false;

  void _launchWaIfReady(InviteState state) {
    if (state.waUrl != null && !_waLaunched) {
      _waLaunched = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        launchUrl(
          Uri.parse(state.waUrl!),
          mode: LaunchMode.externalApplication,
        );
      });
    }
  }
}

// ─── Shared widgets ──────────────────────────────────────────────────────

/// Simple gradient CTA button.
class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;

  const _GradientButton({
    required this.label,
    required this.icon,
    this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(AppConstants.radiusLG),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFec4899), Color(0xFF9333ea)],
            ),
            borderRadius: BorderRadius.circular(AppConstants.radiusLG),
          ),
          child: Container(
            height: AppConstants.minTouchHeight,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: iconColor ?? Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Static shimmer bar for bio loading state.
class _StaticShimmerBar extends StatefulWidget {
  final double width;

  const _StaticShimmerBar({required this.width});

  @override
  State<_StaticShimmerBar> createState() => _StaticShimmerBarState();
}

class _StaticShimmerBarState extends State<_StaticShimmerBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppConstants.shimmerAnimation,
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.15, end: 0.35).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: _opacity.value),
            borderRadius: BorderRadius.circular(6),
          ),
        );
      },
    );
  }
}
