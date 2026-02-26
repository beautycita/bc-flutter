import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/constants.dart';
import '../../providers/admin_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/supabase_client.dart';

class ApplicationsScreen extends ConsumerWidget {
  const ApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsAsync = ref.watch(adminApplicationsProvider);
    final colors = Theme.of(context).colorScheme;

    return appsAsync.when(
      data: (apps) {
        if (apps.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.assignment_turned_in_rounded,
                    size: 48, color: colors.onSurface.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                Text('Sin solicitudes pendientes',
                    style: GoogleFonts.nunito(
                        fontSize: 16,
                        color: colors.onSurface.withValues(alpha: 0.5))),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminApplicationsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(AppConstants.paddingMD),
            itemCount: apps.length,
            itemBuilder: (context, i) {
              final app = apps[i];
              return _ApplicationCard(app: app);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child:
            Text('Error: $e', style: GoogleFonts.nunito(color: colors.error)),
      ),
    );
  }
}

class _ApplicationCard extends ConsumerWidget {
  final Map<String, dynamic> app;
  const _ApplicationCard({required this.app});

  String _inferOrigin() {
    final onboardingStep = app['onboarding_step'] as String?;
    final whatsapp = app['whatsapp'] as String?;
    if (onboardingStep != null && onboardingStep.isNotEmpty) {
      return 'Auto-registro';
    }
    if (whatsapp != null && whatsapp.isNotEmpty) {
      return 'WhatsApp outreach';
    }
    return 'Desconocido';
  }

  String _formatDate(String? iso) {
    if (iso == null) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final date =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      final time =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      return '$date  $time';
    } catch (_) {
      return iso ?? '-';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final name = app['name'] as String? ?? 'Sin nombre';
    final phone = app['phone'] as String?;
    final city = app['city'] as String?;
    final state = app['state'] as String?;
    final createdAt = app['created_at'] as String?;
    final origin = _inferOrigin();
    final location =
        [city, state].where((s) => s != null && s.isNotEmpty).join(', ');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.paddingSM),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          onTap: () => _showDetailPopup(context, ref),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              border: Border.all(
                color: colors.onSurface.withValues(alpha: 0.12),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(AppConstants.paddingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: name + status chip
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.store_rounded,
                          color: Colors.orange, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface,
                            ),
                          ),
                          Text(
                            origin,
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: origin == 'WhatsApp outreach'
                                  ? Colors.green
                                  : colors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _statusChip('pendiente'),
                  ],
                ),

                const SizedBox(height: 12),

                // Info rows
                _InfoRow(
                    icon: Icons.phone_rounded, text: phone ?? 'Sin telefono'),
                if (location.isNotEmpty)
                  _InfoRow(icon: Icons.location_on_rounded, text: location),
                _InfoRow(
                    icon: Icons.access_time_rounded,
                    text: _formatDate(createdAt)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        status,
        style: GoogleFonts.nunito(
            fontSize: 11, fontWeight: FontWeight.w700, color: Colors.orange),
      ),
    );
  }

  void _showDetailPopup(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final name = app['name'] as String? ?? 'Sin nombre';
    final phone = app['phone'] as String?;
    final whatsapp = app['whatsapp'] as String?;
    final address = app['address'] as String?;
    final city = app['city'] as String?;
    final state = app['state'] as String?;
    final country = app['country'] as String?;
    final website = app['website'] as String?;
    final instagram = app['instagram_handle'] as String?;
    final facebook = app['facebook_url'] as String?;
    final createdAt = app['created_at'] as String?;
    final categories = app['service_categories'] as List<dynamic>? ?? [];
    final origin = _inferOrigin();
    final ownerId = app['owner_id'] as String?;
    final photoUrl = app['photo_url'] as String?;
    final lat = (app['lat'] as num?)?.toDouble();
    final lng = (app['lng'] as num?)?.toDouble();
    final hasCoords = lat != null && lng != null;
    final location = [city, state, country]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMD)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: photo + name + chips
              Row(
                children: [
                  if (photoUrl != null && photoUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(photoUrl,
                          width: 56, height: 56, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholderIcon()),
                    )
                  else
                    _placeholderIcon(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: GoogleFonts.poppins(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        Row(
                          children: [
                            _statusChip('pendiente'),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: origin == 'WhatsApp outreach'
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : colors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(origin,
                                  style: GoogleFonts.nunito(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: origin == 'WhatsApp outreach'
                                          ? Colors.green[700]
                                          : colors.primary)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Contact
              _SectionHeader(title: 'Contacto'),
              const SizedBox(height: 8),
              _DetailRow(label: 'Telefono', value: phone ?? '-'),
              if (whatsapp != null)
                _DetailRow(label: 'WhatsApp', value: whatsapp),
              _DetailRow(
                  label: 'Registro', value: _formatDate(createdAt)),
              const SizedBox(height: 12),

              // Location
              _SectionHeader(title: 'Ubicacion'),
              const SizedBox(height: 8),
              if (address != null)
                _DetailRow(label: 'Direccion', value: address),
              if (location.isNotEmpty)
                _DetailRow(label: 'Ciudad', value: location),
              const SizedBox(height: 12),

              // Social / Web
              if (website != null ||
                  instagram != null ||
                  facebook != null) ...[
                _SectionHeader(title: 'Redes'),
                const SizedBox(height: 8),
                if (website != null)
                  _DetailRow(label: 'Web', value: website),
                if (instagram != null)
                  _DetailRow(label: 'Instagram', value: '@$instagram'),
                if (facebook != null)
                  _DetailRow(label: 'Facebook', value: facebook),
                const SizedBox(height: 12),
              ],

              // Categories
              if (categories.isNotEmpty) ...[
                _SectionHeader(title: 'Categorias'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: categories
                      .map((c) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: colors.primary.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '$c',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.primary,
                              ),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
              ],

              const Divider(height: 1),
              const SizedBox(height: 16),

              // Action icons row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Street View
                  _ActionIcon(
                    icon: Icons.streetview_rounded,
                    label: 'Street View',
                    color: hasCoords ? Colors.blue[700]! : Colors.grey[400]!,
                    onTap: hasCoords
                        ? () {
                            final url = Uri.parse(
                                'https://www.google.com/maps/@$lat,$lng,3a,75y,90t/data=!3m6!1e1!3m4!1s!2e0!7i16384!8i8192');
                            launchUrl(url,
                                mode: LaunchMode.externalApplication);
                          }
                        : null,
                  ),
                  // Map
                  _ActionIcon(
                    icon: Icons.map_rounded,
                    label: 'Mapa',
                    color: hasCoords ? Colors.green[700]! : Colors.grey[400]!,
                    onTap: hasCoords
                        ? () {
                            final url = Uri.parse(
                                'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                            launchUrl(url,
                                mode: LaunchMode.externalApplication);
                          }
                        : null,
                  ),
                  // Chat
                  _ActionIcon(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Chat',
                    color: ownerId != null
                        ? colors.primary
                        : Colors.grey[400]!,
                    onTap: ownerId != null
                        ? () {
                            Navigator.pop(ctx);
                            _startChat(context, ref, ownerId, name);
                          }
                        : null,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Approve / Reject buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _approve(context, ref);
                      },
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text('Aprobar',
                          style:
                              GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _rejectDialog(context, ref);
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: Text('Rechazar',
                          style:
                              GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholderIcon() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.store_rounded, color: Colors.orange, size: 28),
    );
  }

  Future<void> _startChat(
      BuildContext context, WidgetRef ref, String ownerId, String salonName) async {
    try {
      final client = SupabaseClientService.client;
      final adminId = SupabaseClientService.currentUserId;
      if (adminId == null) return;

      // Check if a salon-type thread already exists for this owner
      final existing = await client
          .from('chat_threads')
          .select()
          .eq('user_id', adminId)
          .eq('contact_type', 'salon')
          .eq('contact_id', ownerId)
          .isFilter('archived_at', null)
          .maybeSingle();

      String threadId;
      if (existing != null) {
        threadId = existing['id'] as String;
      } else {
        // Create a new thread
        final now = DateTime.now().toUtc().toIso8601String();
        final result = await client
            .from('chat_threads')
            .insert({
              'user_id': adminId,
              'contact_type': 'salon',
              'contact_id': ownerId,
              'contact_name': salonName,
              'last_message_text': 'Chat con $salonName',
              'last_message_at': now,
            })
            .select()
            .single();
        threadId = result['id'] as String;

        // Insert a system message as opener
        await client.from('chat_messages').insert({
          'thread_id': threadId,
          'sender_type': 'system',
          'sender_id': adminId,
          'content_type': 'text',
          'text_content': 'Chat iniciado con $salonName',
        });
      }

      if (context.mounted) {
        context.push('/chat/$threadId');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error iniciando chat: $e')),
        );
      }
    }
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final id = app['id'] as String;
    final ownerId = app['owner_id'] as String?;
    try {
      await SupabaseClientService.client
          .from('businesses')
          .update({'is_verified': true}).eq('id', id);

      if (ownerId != null) {
        await SupabaseClientService.client
            .from('profiles')
            .update({'role': 'stylist'}).eq('id', ownerId);
      }

      await adminLogAction(
        action: 'approve_application',
        targetType: 'business',
        targetId: id,
      );
      ref.invalidate(adminApplicationsProvider);
      ref.invalidate(adminDashStatsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud aprobada')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _rejectDialog(BuildContext context, WidgetRef ref) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Rechazar solicitud',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Razon del rechazo...',
            hintStyle: GoogleFonts.nunito(fontSize: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          style: GoogleFonts.nunito(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Rechazar',
                style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final id = app['id'] as String;
    try {
      await SupabaseClientService.client
          .from('businesses')
          .update({
            'is_active': false,
            'is_verified': true,
          }).eq('id', id);

      await adminLogAction(
        action: 'reject_application',
        targetType: 'business',
        targetId: id,
        details: {'reason': reasonCtrl.text},
      );
      ref.invalidate(adminApplicationsProvider);
      ref.invalidate(adminDashStatsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud rechazada')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
    reasonCtrl.dispose();
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon,
              size: 16, color: colors.onSurface.withValues(alpha: 0.4)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionIcon(
      {required this.icon,
      required this.label,
      required this.color,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap != null ? 1.0 : 0.4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
