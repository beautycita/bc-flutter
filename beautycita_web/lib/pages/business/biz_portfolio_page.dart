import 'dart:convert';

import 'package:beautycita_core/supabase.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../config/breakpoints.dart';
import '../../config/web_theme.dart';
import '../../providers/business_portal_provider.dart';
import '../../widgets/photo_studio.dart';

/// Business portfolio page — template selector + live preview builder.
///
/// Wraps the [PortfolioBuilder] widget from photo_studio.dart, feeding it
/// real business data and wiring save/publish actions to Supabase.
class BizPortfolioPage extends ConsumerWidget {
  const BizPortfolioPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bizAsync = ref.watch(currentBusinessProvider);

    return bizAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (biz) {
        if (biz == null) return const Center(child: Text('Sin negocio'));
        return _PortfolioContent(biz: biz);
      },
    );
  }
}

class _PortfolioContent extends ConsumerStatefulWidget {
  const _PortfolioContent({required this.biz});
  final Map<String, dynamic> biz;

  @override
  ConsumerState<_PortfolioContent> createState() => _PortfolioContentState();
}

class _PortfolioContentState extends ConsumerState<_PortfolioContent> {
  bool _publishing = false;

  /// Build [PortfolioSalonData] from the business record + staff + services.
  PortfolioSalonData _buildSalonData(
    Map<String, dynamic> biz,
    List<Map<String, dynamic>> staffList,
    List<Map<String, dynamic>> servicesList,
  ) {
    // Parse hours from business record
    final hoursMap = <String, String>{};
    final hoursRaw = biz['hours'];
    if (hoursRaw != null) {
      try {
        final Map<String, dynamic> parsed = hoursRaw is String
            ? jsonDecode(hoursRaw) as Map<String, dynamic>
            : hoursRaw as Map<String, dynamic>;
        for (final entry in parsed.entries) {
          final day = entry.value;
          if (day is Map<String, dynamic>) {
            final isOpen = day['open'] != null;
            if (isOpen) {
              final start = day['open'] as String? ?? '09:00';
              final end = day['close'] as String? ?? '18:00';
              hoursMap[entry.key] = '$start - $end';
            } else {
              hoursMap[entry.key] = 'Cerrado';
            }
          }
        }
      } catch (_) {
        // Ignore malformed hours
      }
    }

    // Collect portfolio photo URLs from staff records
    final servicePhotos = <String>[];
    for (final s in staffList) {
      final urls = s['portfolio_urls'];
      if (urls is List) {
        for (final u in urls) {
          if (u is String && u.isNotEmpty) servicePhotos.add(u);
        }
      }
    }

    // Build staff list
    final staffPhotos = staffList.map((s) {
      final firstName = s['first_name'] as String? ?? '';
      final lastName = s['last_name'] as String? ?? '';
      final name = '$firstName $lastName'.trim();
      return PortfolioStaff(
        name: name.isEmpty ? (s['name'] as String? ?? 'Staff') : name,
        role: s['role'] as String? ?? '',
        photoUrl: s['avatar_url'] as String?,
      );
    }).toList();

    // Service names
    final serviceNames =
        servicesList.map((s) => s['name'] as String? ?? '').where((n) => n.isNotEmpty).toList();

    return PortfolioSalonData(
      name: biz['name'] as String? ?? 'Mi Salon',
      slug: biz['slug'] as String? ?? '',
      tagline: biz['tagline'] as String? ?? biz['description'] as String? ?? '',
      phone: biz['phone'] as String? ?? '',
      address: biz['address'] as String? ?? '',
      rating: (biz['average_rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (biz['review_count'] as num?)?.toInt() ?? 0,
      coverPhotoUrl: biz['cover_photo_url'] as String?,
      logoUrl: biz['logo_url'] as String?,
      servicePhotos: servicePhotos,
      staffPhotos: staffPhotos,
      services: serviceNames,
      hours: hoursMap,
    );
  }

  Future<void> _handleCoverPhotoChanged(PlatformFile file) async {
    if (file.bytes == null) return;
    final bizId = widget.biz['id'] as String;
    final path = '$bizId/cover_photo.jpg';

    try {
      await BCSupabase.client.storage.from('staff-media').uploadBinary(
        path,
        file.bytes!,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );
      final url = BCSupabase.client.storage.from('staff-media').getPublicUrl(path);

      await BCSupabase.client
          .from(BCTables.businesses)
          .update({'cover_photo_url': url}).eq('id', bizId);

      ref.invalidate(currentBusinessProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de portada actualizada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error subiendo foto: $e')),
        );
      }
    }
  }

  Future<void> _handlePublish() async {
    setState(() => _publishing = true);
    try {
      final bizId = widget.biz['id'] as String;

      // Mark business as published / portfolio visible
      await BCSupabase.client
          .from(BCTables.businesses)
          .update({'portfolio_published': true}).eq('id', bizId);

      ref.invalidate(currentBusinessProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Portafolio publicado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(businessStaffProvider);
    final servicesAsync = ref.watch(businessServicesProvider);
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = WebBreakpoints.isMobile(constraints.maxWidth);
        final padding = isMobile ? 16.0 : 24.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.all(padding),
              child: Row(
                children: [
                  Icon(Icons.photo_library_outlined, color: kWebPrimary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Portafolio y Plantilla',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: kWebTextPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Personaliza como se ve tu salon en BeautyCita',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: kWebTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_publishing)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),

            const Divider(height: 1, color: kWebCardBorder),

            // ── Portfolio Builder ────────────────────────────────────
            Expanded(
              child: staffAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error cargando staff: $e')),
                data: (staffList) => servicesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error cargando servicios: $e')),
                  data: (servicesList) {
                    final salonData = _buildSalonData(widget.biz, staffList, servicesList);
                    return PortfolioBuilder(
                      salon: salonData,
                      onPublish: _handlePublish,
                      onCoverPhotoChanged: _handleCoverPhotoChanged,
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
