import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme_extension.dart';
import '../providers/contact_match_provider.dart';
import '../providers/feature_toggle_provider.dart';
import 'contact_salon_card.dart';
import 'save_contact_prompt.dart';

/// Home screen section that shows salons found in the user's contacts.
/// Gated by the `enable_contact_match` feature toggle.
class ContactMatchSection extends ConsumerStatefulWidget {
  const ContactMatchSection({super.key});

  @override
  ConsumerState<ContactMatchSection> createState() =>
      _ContactMatchSectionState();
}

class _ContactMatchSectionState extends ConsumerState<ContactMatchSection> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      // Check permission + load cache on first build.
      Future.microtask(() {
        ref.read(contactMatchProvider.notifier).checkPermission();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Gate on feature toggle.
    final toggles = ref.watch(featureTogglesProvider);
    if (!toggles.isEnabled('enable_contact_match')) {
      return const SizedBox.shrink();
    }

    final state = ref.watch(contactMatchProvider);

    // We're already holding READ_CONTACTS at this point — same window the
    // user asked us to also check whether BC is in their address book.
    // Helper is silent if BC is already a contact / already added /
    // dismissed in the last 30 days, so this is safe to fire each time
    // the state transitions to a permission-granted step.
    ref.listen<ContactMatchState>(contactMatchProvider, (prev, next) {
      final wasGranted = prev != null &&
          (prev.step == ContactMatchStep.loaded ||
              prev.step == ContactMatchStep.scanning);
      final isGranted = next.step == ContactMatchStep.loaded ||
          next.step == ContactMatchStep.scanning;
      if (!wasGranted && isGranted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          SaveContactPrompt.showPopupIfMissing(context);
        });
      }
    });

    return switch (state.step) {
      ContactMatchStep.idle => _buildCta(loading: false),
      ContactMatchStep.requesting => _buildCta(loading: true),
      ContactMatchStep.scanning => _buildShimmer(),
      ContactMatchStep.loaded => state.matches.isEmpty
          ? const SizedBox.shrink()
          : _buildMatchList(state.matches),
      ContactMatchStep.denied => _buildDenied(),
      ContactMatchStep.error => _buildError(state.error),
    };
  }

  // ---------------------------------------------------------------------------
  // CTA — first-time prompt
  // ---------------------------------------------------------------------------

  Widget _buildCta({required bool loading}) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.contacts_rounded,
                color: cs.primary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Encuentra salones en tus contactos',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 36,
              child: loading
                  ? const SizedBox(
                      width: 36,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: ext.primaryGradient,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            ref
                                .read(contactMatchProvider.notifier)
                                .requestAndScan();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Center(
                              child: Text(
                                'Buscar',
                                style: TextStyle(
                                  color: cs.onPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shimmer placeholder
  // ---------------------------------------------------------------------------

  Widget _buildShimmer() {
    final shimmerColor = Theme.of(context).extension<BCThemeExtension>()!.shimmerColor;
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, _) => Container(
          width: 280,
          decoration: BoxDecoration(
            color: shimmerColor,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Match list
  // ---------------------------------------------------------------------------

  Widget _buildMatchList(List<EnrichedMatch> matches) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Salones en tus contactos (${matches.length})',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: matches.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => ContactSalonCard(match: matches[i]),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Denied / Error
  // ---------------------------------------------------------------------------

  Widget _buildDenied() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Text(
        'Activa el permiso de contactos en Ajustes',
        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
      ),
    );
  }

  Widget _buildError(String? error) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Text(
        error ?? 'Error al buscar contactos',
        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error.withValues(alpha: 0.7)),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
