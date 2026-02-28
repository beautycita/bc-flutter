import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/constants.dart';
import '../../providers/admin_provider.dart';
import '../../services/supabase_client.dart';

class AdminSalonDetailScreen extends ConsumerStatefulWidget {
  final String businessId;

  const AdminSalonDetailScreen({super.key, required this.businessId});

  @override
  ConsumerState<AdminSalonDetailScreen> createState() =>
      _AdminSalonDetailScreenState();
}

class _AdminSalonDetailScreenState
    extends ConsumerState<AdminSalonDetailScreen> {
  bool _tierUpdating = false;
  bool _activeUpdating = false;

  // ---------------------------------------------------------------------------
  // Tier update
  // ---------------------------------------------------------------------------

  Future<void> _setTier(int newTier) async {
    setState(() => _tierUpdating = true);
    try {
      await SupabaseClientService.client
          .from('businesses')
          .update({'tier': newTier}).eq('id', widget.businessId);
      ref.invalidate(adminSalonDetailProvider(widget.businessId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cambiar tier: $e'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _tierUpdating = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Active toggle
  // ---------------------------------------------------------------------------

  Future<void> _setActive(bool value) async {
    setState(() => _activeUpdating = true);
    try {
      await SupabaseClientService.client
          .from('businesses')
          .update({'is_active': value}).eq('id', widget.businessId);
      ref.invalidate(adminSalonDetailProvider(widget.businessId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cambiar estado: $e'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _activeUpdating = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Suspend dialog
  // ---------------------------------------------------------------------------

  Future<void> _confirmSuspend(Map<String, dynamic> salon) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Suspender Salon',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'El salon "${salon['name']}" quedara inactivo y no aparecera en busquedas. Puedes reactivarlo manualmente.',
          style: GoogleFonts.nunito(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: GoogleFonts.nunito()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red[600]),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Suspender', style: GoogleFonts.nunito()),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _setActive(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Salon suspendido'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // URL launchers
  // ---------------------------------------------------------------------------

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se puede abrir: $url')),
        );
      }
    }
  }

  Future<void> _launchPhone(String phone) =>
      _launchUrl('tel:${phone.replaceAll(RegExp(r'\s+'), '')}');

  Future<void> _launchWhatsApp(String phone) {
    final clean = phone.replaceAll(RegExp(r'[^\d]'), '');
    return _launchUrl('https://wa.me/$clean');
  }

  Future<void> _launchMaps(String address) {
    final encoded = Uri.encodeComponent(address);
    return _launchUrl('https://maps.google.com/?q=$encoded');
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(adminSalonDetailProvider(widget.businessId));
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          'Detalle del Salon',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: colors.onSurface.withValues(alpha: 0.08),
          ),
        ),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBody(
          error: e.toString(),
          onRetry: () =>
              ref.invalidate(adminSalonDetailProvider(widget.businessId)),
        ),
        data: (salon) {
          if (salon == null) {
            return Center(
              child: Text(
                'Salon no encontrado',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
              ),
            );
          }
          return _SalonDetailBody(
            salon: salon,
            businessId: widget.businessId,
            tierUpdating: _tierUpdating,
            activeUpdating: _activeUpdating,
            onTierChanged: _setTier,
            onActiveChanged: _setActive,
            onSuspend: () => _confirmSuspend(salon),
            onLaunchPhone: _launchPhone,
            onLaunchWhatsApp: _launchWhatsApp,
            onLaunchMaps: _launchMaps,
            onLaunchUrl: _launchUrl,
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Main scrollable body — extracted to keep state class clean
// ---------------------------------------------------------------------------

class _SalonDetailBody extends ConsumerWidget {
  final Map<String, dynamic> salon;
  final String businessId;
  final bool tierUpdating;
  final bool activeUpdating;
  final ValueChanged<int> onTierChanged;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onSuspend;
  final ValueChanged<String> onLaunchPhone;
  final ValueChanged<String> onLaunchWhatsApp;
  final ValueChanged<String> onLaunchMaps;
  final ValueChanged<String> onLaunchUrl;

  const _SalonDetailBody({
    required this.salon,
    required this.businessId,
    required this.tierUpdating,
    required this.activeUpdating,
    required this.onTierChanged,
    required this.onActiveChanged,
    required this.onSuspend,
    required this.onLaunchPhone,
    required this.onLaunchWhatsApp,
    required this.onLaunchMaps,
    required this.onLaunchUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appoAsync = ref.watch(adminSalonAppointmentsProvider(businessId));
    final dispAsync = ref.watch(adminSalonDisputesProvider(businessId));
    final revAsync = ref.watch(adminSalonReviewsProvider(businessId));
    final colors = Theme.of(context).colorScheme;

    final name = salon['name'] as String? ?? 'Sin nombre';
    final city = salon['city'] as String? ?? '';
    final state = salon['state'] as String? ?? '';
    final photoUrl = salon['photo_url'] as String?;
    final currentTier = salon['tier'] as int?;
    final isActive = salon['is_active'] as bool? ?? false;
    final avgRating = (salon['average_rating'] as num?)?.toDouble();
    final totalReviews = salon['total_reviews'] as int? ?? 0;
    final owner = salon['profiles'] as Map<String, dynamic>?;

    // Revenue & appointment count from appointments list
    final appointments = appoAsync.valueOrNull ?? [];
    final apptCount = appointments.length;
    double revenue = 0;
    for (final a in appointments) {
      if (a['payment_status'] == 'paid') {
        revenue += (a['price'] as num?)?.toDouble() ?? 0;
      }
    }

    final locationLine =
        [city, state].where((s) => s.isNotEmpty).join(', ');

    return ListView(
      padding: const EdgeInsets.only(
        left: AppConstants.paddingMD,
        right: AppConstants.paddingMD,
        top: AppConstants.paddingMD,
        bottom: 100,
      ),
      children: [
        // ----------------------------------------------------------------
        // 1. Header
        // ----------------------------------------------------------------
        _headerSection(
          context: context,
          name: name,
          locationLine: locationLine,
          photoUrl: photoUrl,
          currentTier: currentTier,
          isActive: isActive,
          colors: colors,
        ),

        const SizedBox(height: AppConstants.paddingMD),

        // ----------------------------------------------------------------
        // 2. Stats row
        // ----------------------------------------------------------------
        _statsRow(
          context: context,
          avgRating: avgRating,
          totalReviews: totalReviews,
          apptCount: apptCount,
          revenue: revenue,
          colors: colors,
        ),

        const SizedBox(height: AppConstants.paddingMD),

        // ----------------------------------------------------------------
        // 3. Contact
        // ----------------------------------------------------------------
        _contactCard(context: context, salon: salon, colors: colors),

        const SizedBox(height: AppConstants.paddingMD),

        // ----------------------------------------------------------------
        // 4. Business Info
        // ----------------------------------------------------------------
        _businessInfoCard(context: context, salon: salon, colors: colors),

        const SizedBox(height: AppConstants.paddingMD),

        // ----------------------------------------------------------------
        // 5. Owner
        // ----------------------------------------------------------------
        _ownerCard(context: context, owner: owner, colors: colors),

        const SizedBox(height: AppConstants.paddingMD),

        // ----------------------------------------------------------------
        // 6. Recent Appointments
        // ----------------------------------------------------------------
        _appointmentsCard(
          context: context,
          appoAsync: appoAsync,
          colors: colors,
        ),

        const SizedBox(height: AppConstants.paddingMD),

        // ----------------------------------------------------------------
        // 7. Open Disputes
        // ----------------------------------------------------------------
        _disputesCard(
          context: context,
          dispAsync: dispAsync,
          colors: colors,
        ),

        const SizedBox(height: AppConstants.paddingMD),

        // ----------------------------------------------------------------
        // 8. Recent Reviews
        // ----------------------------------------------------------------
        _reviewsCard(
          context: context,
          revAsync: revAsync,
          colors: colors,
        ),

        const SizedBox(height: AppConstants.paddingLG),

        // ----------------------------------------------------------------
        // 9. Action buttons
        // ----------------------------------------------------------------
        _actionButtons(
          context: context,
          owner: owner,
          isActive: isActive,
          colors: colors,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Header
  // ---------------------------------------------------------------------------

  Widget _headerSection({
    required BuildContext context,
    required String name,
    required String locationLine,
    required String? photoUrl,
    required int? currentTier,
    required bool isActive,
    required ColorScheme colors,
  }) {
    return _SectionCard(
      child: Column(
        children: [
          // Photo + name + location
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor:
                    colors.primary.withValues(alpha: 0.12),
                backgroundImage:
                    photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null
                    ? Icon(Icons.store,
                        size: 32,
                        color: colors.primary.withValues(alpha: 0.8))
                    : null,
              ),
              const SizedBox(width: AppConstants.paddingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    if (locationLine.isNotEmpty)
                      Text(
                        locationLine,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          color:
                              colors.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppConstants.paddingMD),
          Divider(
              height: 1, color: colors.onSurface.withValues(alpha: 0.08)),
          const SizedBox(height: AppConstants.paddingMD),

          // Tier selector
          _TierSelector(
            currentTier: currentTier,
            updating: false,
            onTierChanged: onTierChanged,
          ),

          const SizedBox(height: AppConstants.paddingMD),

          // Active toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isActive ? 'Activo' : 'Inactivo',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.green[700] : Colors.red[700],
                ),
              ),
              Switch(
                value: isActive,
                onChanged: activeUpdating ? null : onActiveChanged,
                activeThumbColor: Colors.green[600],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Stats row
  // ---------------------------------------------------------------------------

  Widget _statsRow({
    required BuildContext context,
    required double? avgRating,
    required int totalReviews,
    required int apptCount,
    required double revenue,
    required ColorScheme colors,
  }) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.star_rounded,
            iconColor: Colors.amber[600]!,
            label: 'Rating',
            value: avgRating != null
                ? avgRating.toStringAsFixed(1)
                : '--',
          ),
        ),
        const SizedBox(width: AppConstants.paddingSM),
        Expanded(
          child: _StatCard(
            icon: Icons.rate_review_outlined,
            iconColor: Colors.blue[600]!,
            label: 'Resenas',
            value: '$totalReviews',
          ),
        ),
        const SizedBox(width: AppConstants.paddingSM),
        Expanded(
          child: _StatCard(
            icon: Icons.calendar_today_outlined,
            iconColor: Colors.purple[600]!,
            label: 'Citas',
            value: '$apptCount',
          ),
        ),
        const SizedBox(width: AppConstants.paddingSM),
        Expanded(
          child: _StatCard(
            icon: Icons.payments_outlined,
            iconColor: Colors.green[600]!,
            label: 'Ingresos',
            value: '\$${revenue.toStringAsFixed(0)}',
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Contact card
  // ---------------------------------------------------------------------------

  Widget _contactCard({
    required BuildContext context,
    required Map<String, dynamic> salon,
    required ColorScheme colors,
  }) {
    final phone = salon['phone'] as String?;
    final whatsapp = salon['whatsapp'] as String?;
    final address = salon['address'] as String?;
    final website = salon['website'] as String?;
    final instagram = salon['instagram'] as String?;
    final facebook = salon['facebook'] as String?;

    final rows = <Widget>[];

    if (phone != null && phone.isNotEmpty) {
      rows.add(_ContactRow(
        icon: Icons.phone_outlined,
        text: phone,
        onTap: () => onLaunchPhone(phone),
        colors: colors,
      ));
    }
    if (whatsapp != null && whatsapp.isNotEmpty) {
      rows.add(_ContactRow(
        icon: Icons.chat_outlined,
        iconColor: const Color(0xFF25D366),
        text: whatsapp,
        label: 'WhatsApp',
        onTap: () => onLaunchWhatsApp(whatsapp),
        colors: colors,
      ));
    }
    if (address != null && address.isNotEmpty) {
      rows.add(_ContactRow(
        icon: Icons.location_on_outlined,
        text: address,
        onTap: () => onLaunchMaps(address),
        colors: colors,
      ));
    }
    if (website != null && website.isNotEmpty) {
      rows.add(_ContactRow(
        icon: Icons.link,
        text: website,
        onTap: () => onLaunchUrl(website),
        colors: colors,
      ));
    }
    if (instagram != null && instagram.isNotEmpty) {
      rows.add(_ContactRow(
        icon: Icons.camera_alt_outlined,
        iconColor: const Color(0xFFE1306C),
        text: instagram,
        label: 'Instagram',
        onTap: () {
          final handle = instagram.startsWith('@')
              ? instagram.substring(1)
              : instagram;
          onLaunchUrl('https://instagram.com/$handle');
        },
        colors: colors,
      ));
    }
    if (facebook != null && facebook.isNotEmpty) {
      rows.add(_ContactRow(
        icon: Icons.facebook,
        iconColor: const Color(0xFF1877F2),
        text: facebook,
        label: 'Facebook',
        onTap: () => onLaunchUrl(facebook.startsWith('http')
            ? facebook
            : 'https://facebook.com/$facebook'),
        colors: colors,
      ));
    }

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(label: 'CONTACTO', colors: colors),
          const SizedBox(height: AppConstants.paddingSM),
          if (rows.isEmpty)
            Text(
              'Sin informacion de contacto',
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.45),
              ),
            )
          else
            ...rows,
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Business info card
  // ---------------------------------------------------------------------------

  Widget _businessInfoCard({
    required BuildContext context,
    required Map<String, dynamic> salon,
    required ColorScheme colors,
  }) {
    final categories = salon['categories'];
    final hours = salon['hours'];
    final depositPct = salon['deposit_percentage'] as num?;
    final cancelHours = salon['cancellation_hours'] as int?;
    final autoConfirm = salon['auto_confirm'] as bool? ?? false;
    final walkins = salon['accept_walkins'] as bool? ?? false;

    String hoursText = 'No configurado';
    if (hours != null) {
      try {
        if (hours is String) {
          final decoded = jsonDecode(hours);
          hoursText = const JsonEncoder.withIndent('  ').convert(decoded);
        } else {
          hoursText = const JsonEncoder.withIndent('  ').convert(hours);
        }
      } catch (_) {
        hoursText = hours.toString();
      }
    }

    List<String> categoryList = [];
    if (categories is List) {
      categoryList = categories.map((e) => e.toString()).toList();
    } else if (categories is String) {
      try {
        final decoded = jsonDecode(categories);
        if (decoded is List) {
          categoryList = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        if (categories.isNotEmpty) categoryList = [categories];
      }
    }

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(label: 'INFORMACION DEL NEGOCIO', colors: colors),
          const SizedBox(height: AppConstants.paddingSM),

          // Categories
          if (categoryList.isNotEmpty) ...[
            Text(
              'Categorias',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: categoryList
                  .map((c) => _CategoryChip(label: c, colors: colors))
                  .toList(),
            ),
            const SizedBox(height: AppConstants.paddingSM),
          ],

          // Hours
          _InfoRow(
            label: 'Horario',
            value: hoursText,
            monospace: true,
            colors: colors,
          ),
          const SizedBox(height: AppConstants.paddingSM),

          // Deposit
          _InfoRow(
            label: 'Deposito',
            value: depositPct != null && depositPct > 0
                ? 'Requiere deposito: ${depositPct.toStringAsFixed(0)}%'
                : 'No requiere deposito',
            colors: colors,
          ),
          const SizedBox(height: AppConstants.paddingSM),

          // Cancellation
          _InfoRow(
            label: 'Cancelacion',
            value: cancelHours != null
                ? 'Hasta $cancelHours horas antes'
                : 'No configurado',
            colors: colors,
          ),
          const SizedBox(height: AppConstants.paddingSM),

          // Auto-confirm
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Confirmacion automatica',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
              _BoolBadge(value: autoConfirm, trueText: 'Si', falseText: 'No'),
            ],
          ),
          const SizedBox(height: AppConstants.paddingXS),

          // Walk-ins
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Walk-ins',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
              _BoolBadge(
                  value: walkins,
                  trueText: 'Acepta walk-ins',
                  falseText: 'No acepta walk-ins'),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Owner card
  // ---------------------------------------------------------------------------

  Widget _ownerCard({
    required BuildContext context,
    required Map<String, dynamic>? owner,
    required ColorScheme colors,
  }) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(label: 'PROPIETARIO', colors: colors),
          const SizedBox(height: AppConstants.paddingSM),
          if (owner == null)
            Text(
              'Sin propietario asignado',
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.45),
                fontStyle: FontStyle.italic,
              ),
            )
          else ...[
            _InfoRow(
              label: 'Nombre',
              value: owner['display_name'] as String? ?? 'Sin nombre',
              colors: colors,
            ),
            const SizedBox(height: AppConstants.paddingXS),
            _InfoRow(
              label: 'Telefono',
              value: owner['phone'] as String? ?? '--',
              colors: colors,
            ),
            const SizedBox(height: AppConstants.paddingXS),
            _InfoRow(
              label: 'Email',
              value: owner['email'] as String? ?? '--',
              colors: colors,
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. Appointments card
  // ---------------------------------------------------------------------------

  Widget _appointmentsCard({
    required BuildContext context,
    required AsyncValue<List<Map<String, dynamic>>> appoAsync,
    required ColorScheme colors,
  }) {
    return appoAsync.when(
      loading: () => _SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(label: 'ULTIMAS CITAS', colors: colors),
            const SizedBox(height: AppConstants.paddingSM),
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppConstants.paddingMD),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],
        ),
      ),
      error: (e, _) => _SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(label: 'ULTIMAS CITAS', colors: colors),
            const SizedBox(height: AppConstants.paddingSM),
            Text('Error: $e',
                style: GoogleFonts.nunito(
                    fontSize: 12, color: colors.error)),
          ],
        ),
      ),
      data: (appointments) {
        return _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                label: 'ULTIMAS CITAS',
                count: appointments.length,
                colors: colors,
              ),
              const SizedBox(height: AppConstants.paddingSM),
              if (appointments.isEmpty)
                Text(
                  'Sin citas registradas',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: colors.onSurface.withValues(alpha: 0.45),
                  ),
                )
              else
                ...appointments.map((a) => _AppointmentRow(
                      appointment: a,
                      colors: colors,
                    )),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 7. Disputes card
  // ---------------------------------------------------------------------------

  Widget _disputesCard({
    required BuildContext context,
    required AsyncValue<List<Map<String, dynamic>>> dispAsync,
    required ColorScheme colors,
  }) {
    return dispAsync.when(
      loading: () => _SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(label: 'DISPUTAS ABIERTAS', colors: colors),
            const SizedBox(height: AppConstants.paddingSM),
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppConstants.paddingMD),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],
        ),
      ),
      error: (e, _) => _SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(label: 'DISPUTAS ABIERTAS', colors: colors),
            const SizedBox(height: AppConstants.paddingSM),
            Text('Error: $e',
                style: GoogleFonts.nunito(
                    fontSize: 12, color: colors.error)),
          ],
        ),
      ),
      data: (disputes) {
        return _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                label: 'DISPUTAS ABIERTAS',
                count: disputes.length,
                colors: colors,
              ),
              const SizedBox(height: AppConstants.paddingSM),
              if (disputes.isEmpty)
                Text(
                  'Sin disputas abiertas',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: Colors.green[600],
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                ...disputes.map((d) => _DisputeRow(
                      dispute: d,
                      colors: colors,
                    )),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 8. Reviews card
  // ---------------------------------------------------------------------------

  Widget _reviewsCard({
    required BuildContext context,
    required AsyncValue<List<Map<String, dynamic>>> revAsync,
    required ColorScheme colors,
  }) {
    return revAsync.when(
      loading: () => _SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(label: 'ULTIMAS RESENAS', colors: colors),
            const SizedBox(height: AppConstants.paddingSM),
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppConstants.paddingMD),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],
        ),
      ),
      error: (e, _) => _SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(label: 'ULTIMAS RESENAS', colors: colors),
            const SizedBox(height: AppConstants.paddingSM),
            Text('Error: $e',
                style: GoogleFonts.nunito(
                    fontSize: 12, color: colors.error)),
          ],
        ),
      ),
      data: (reviews) {
        return _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                label: 'ULTIMAS RESENAS',
                count: reviews.length,
                colors: colors,
              ),
              const SizedBox(height: AppConstants.paddingSM),
              if (reviews.isEmpty)
                Text(
                  'Sin resenas',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: colors.onSurface.withValues(alpha: 0.45),
                  ),
                )
              else
                ...reviews.map((r) => _ReviewRow(
                      review: r,
                      colors: colors,
                    )),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 9. Action buttons
  // ---------------------------------------------------------------------------

  Widget _actionButtons({
    required BuildContext context,
    required Map<String, dynamic>? owner,
    required bool isActive,
    required ColorScheme colors,
  }) {
    final ownerPhone = owner?['phone'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ownerPhone != null && ownerPhone.isNotEmpty)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green[600],
              minimumSize: const Size.fromHeight(AppConstants.minTouchHeight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusSM),
              ),
            ),
            onPressed: () => onLaunchWhatsApp(ownerPhone),
            icon: const Icon(Icons.chat, size: 20),
            label: Text(
              'Contactar Propietario',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

        if (ownerPhone != null && ownerPhone.isNotEmpty)
          const SizedBox(height: AppConstants.paddingSM),

        if (isActive)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red[600],
              side: BorderSide(color: Colors.red[600]!),
              minimumSize:
                  const Size.fromHeight(AppConstants.minTouchHeight),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppConstants.radiusSM),
              ),
            ),
            onPressed: onSuspend,
            icon: const Icon(Icons.block, size: 20),
            label: Text(
              'Suspender Salon',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green[700],
              minimumSize:
                  const Size.fromHeight(AppConstants.minTouchHeight),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppConstants.radiusSM),
              ),
            ),
            onPressed: () => onActiveChanged(true),
            icon: const Icon(Icons.check_circle_outline, size: 20),
            label: Text(
              'Reactivar Salon',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tier selector widget
// ---------------------------------------------------------------------------

class _TierSelector extends StatelessWidget {
  final int? currentTier;
  final bool updating;
  final ValueChanged<int> onTierChanged;

  const _TierSelector({
    required this.currentTier,
    required this.updating,
    required this.onTierChanged,
  });

  Color _tierColor(int tier, ColorScheme colors) {
    switch (tier) {
      case 1:
        return Colors.grey[600]!;
      case 2:
        return Colors.blue[600]!;
      case 3:
        return colors.secondary;
      default:
        return colors.onSurface.withValues(alpha: 0.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TIER',
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: colors.onSurface.withValues(alpha: 0.45),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [1, 2, 3].map((tier) {
            final selected = currentTier == tier;
            final tColor = _tierColor(tier, colors);

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: updating ? null : () => onTierChanged(tier),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? tColor.withValues(alpha: 0.15)
                        : colors.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                    border: Border.all(
                      color: selected
                          ? tColor
                          : colors.onSurface.withValues(alpha: 0.15),
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    'Tier $tier',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? tColor
                          : colors.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Stat card
// ---------------------------------------------------------------------------

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingSM,
        vertical: AppConstants.paddingSM + 2,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        border: Border.all(
          color: colors.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 10,
              color: colors.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section card wrapper
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        border: Border.all(
          color: colors.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Section header label
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String label;
  final int? count;
  final ColorScheme colors;

  const _SectionHeader({
    required this.label,
    this.count,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: colors.onSurface.withValues(alpha: 0.4),
            letterSpacing: 1,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: colors.onSurface.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Contact row
// ---------------------------------------------------------------------------

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String text;
  final String? label;
  final VoidCallback onTap;
  final ColorScheme colors;

  const _ContactRow({
    required this.icon,
    this.iconColor,
    required this.text,
    this.label,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.radiusXS),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: iconColor ?? colors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (label != null)
                    Text(
                      label!,
                      style: GoogleFonts.nunito(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  Text(
                    text,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: colors.primary,
                      decoration: TextDecoration.underline,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.open_in_new,
              size: 14,
              color: colors.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info row (label + value)
// ---------------------------------------------------------------------------

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool monospace;
  final ColorScheme colors;

  const _InfoRow({
    required this.label,
    required this.value,
    this.monospace = false,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: colors.onSurface.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: monospace
              ? TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: colors.onSurface.withValues(alpha: 0.7),
                )
              : GoogleFonts.nunito(
                  fontSize: 13,
                  color: colors.onSurface.withValues(alpha: 0.7),
                ),
          maxLines: monospace ? 10 : 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Category chip
// ---------------------------------------------------------------------------

class _CategoryChip extends StatelessWidget {
  final String label;
  final ColorScheme colors;

  const _CategoryChip({required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppConstants.radiusXS),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.primary,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bool badge
// ---------------------------------------------------------------------------

class _BoolBadge extends StatelessWidget {
  final bool value;
  final String trueText;
  final String falseText;

  const _BoolBadge({
    required this.value,
    required this.trueText,
    required this.falseText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: value
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        value ? trueText : falseText,
        style: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: value ? Colors.green[700] : Colors.red[700],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Appointment row
// ---------------------------------------------------------------------------

class _AppointmentRow extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final ColorScheme colors;

  const _AppointmentRow({
    required this.appointment,
    required this.colors,
  });

  Color _statusColor(String? status) {
    switch (status) {
      case 'completed':
        return Colors.green[700]!;
      case 'cancelled':
        return Colors.red[600]!;
      case 'confirmed':
        return Colors.blue[600]!;
      case 'pending':
        return Colors.orange[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = appointment['date'] as String?;
    final time = appointment['time'] as String?;
    final status = appointment['status'] as String?;
    final price = (appointment['price'] as num?)?.toDouble();

    final serviceMap = appointment['services'] as Map<String, dynamic>?;
    final serviceName = serviceMap?['name'] as String? ?? 'Sin servicio';

    final profileMap =
        appointment['profiles'] as Map<String, dynamic>?;
    final clientName =
        profileMap?['display_name'] as String? ?? 'Sin cliente';

    final dateStr = date != null ? date.substring(0, 10) : '--';
    final timeStr = time != null ? time.substring(0, 5) : '';
    final statusColor = _statusColor(status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date column
          SizedBox(
            width: 60,
            child: Text(
              '$dateStr\n$timeStr',
              style: GoogleFonts.nunito(
                fontSize: 11,
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Service + client
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  serviceName,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  clientName,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: colors.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Status badge + price
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _StatusBadge(
                  label: status ?? '--', color: statusColor),
              if (price != null)
                Text(
                  '\$${price.toStringAsFixed(0)}',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dispute row
// ---------------------------------------------------------------------------

class _DisputeRow extends StatelessWidget {
  final Map<String, dynamic> dispute;
  final ColorScheme colors;

  const _DisputeRow({required this.dispute, required this.colors});

  Color _statusColor(String? status) {
    switch (status) {
      case 'open':
        return Colors.orange[700]!;
      case 'escalated':
        return Colors.red[700]!;
      case 'salon_responded':
        return Colors.blue[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = dispute['created_at'] as String?;
    final status = dispute['status'] as String?;
    final reason = dispute['reason'] as String? ?? '--';
    final refundAmount = (dispute['refund_amount'] as num?)?.toDouble();

    final dateStr = createdAt != null
        ? createdAt.substring(0, 10)
        : '--';
    final statusColor = _statusColor(status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              dateStr,
              style: GoogleFonts.nunito(
                fontSize: 11,
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              reason,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: colors.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _StatusBadge(label: status ?? '--', color: statusColor),
              if (refundAmount != null && refundAmount > 0)
                Text(
                  'Reembolso: \$${refundAmount.toStringAsFixed(0)}',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: Colors.red[700],
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Review row
// ---------------------------------------------------------------------------

class _ReviewRow extends StatelessWidget {
  final Map<String, dynamic> review;
  final ColorScheme colors;

  const _ReviewRow({required this.review, required this.colors});

  @override
  Widget build(BuildContext context) {
    final rating = review['rating'] as int? ?? 0;
    final comment = review['comment'] as String?;
    final createdAt = review['created_at'] as String?;
    final profileMap = review['profiles'] as Map<String, dynamic>?;
    final clientName =
        profileMap?['display_name'] as String? ?? 'Usuario';

    final dateStr =
        createdAt != null ? createdAt.substring(0, 10) : '--';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Stars
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 14,
                    color: i < rating
                        ? Colors.amber[600]
                        : colors.onSurface.withValues(alpha: 0.25),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  clientName,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface.withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                dateStr,
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  color: colors.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              comment,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.65),
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Divider(height: 1, color: colors.onSurface.withValues(alpha: 0.06)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status badge
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error body
// ---------------------------------------------------------------------------

class _ErrorBody extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorBody({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingLG),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 52,
              color: colors.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'Error al cargar el salon',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text('Reintentar', style: GoogleFonts.nunito()),
            ),
          ],
        ),
      ),
    );
  }
}
