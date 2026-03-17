import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/contact_match_provider.dart';
import '../providers/feature_toggle_provider.dart';
import 'contact_salon_card.dart';

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.contacts_rounded,
                color: Color(0xFF9333ea), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Encuentra salones en tus contactos',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
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
                        gradient: const LinearGradient(
                          colors: [Color(0xFFec4899), Color(0xFF9333ea)],
                        ),
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
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Center(
                              child: Text(
                                'Buscar',
                                style: TextStyle(
                                  color: Colors.white,
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
            color: Colors.grey[200],
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
              color: Colors.grey[800],
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
        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
      ),
    );
  }

  Widget _buildError(String? error) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Text(
        error ?? 'Error al buscar contactos',
        style: TextStyle(fontSize: 12, color: Colors.red[300]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
