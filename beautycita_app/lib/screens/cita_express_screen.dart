import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../config/constants.dart';
import '../models/curate_result.dart';
import '../providers/cita_express_provider.dart';
import '../services/supabase_client.dart';

class CitaExpressScreen extends ConsumerStatefulWidget {
  final String businessId;
  const CitaExpressScreen({super.key, required this.businessId});

  @override
  ConsumerState<CitaExpressScreen> createState() => _CitaExpressScreenState();
}

class _CitaExpressScreenState extends ConsumerState<CitaExpressScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(citaExpressProvider.notifier).loadBusiness(widget.businessId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(citaExpressProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(AppConstants.radiusMD),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: colors.onSurface),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/home');
            }
          },
        ),
        title: Text(
          'Cita Express',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: colors.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildStep(state, colors),
      ),
    );
  }

  Widget _buildStep(CitaExpressState state, ColorScheme colors) {
    switch (state.step) {
      case CitaExpressStep.loading:
        return _LoadingView(key: const ValueKey('loading'));
      case CitaExpressStep.serviceSelect:
        return _ServiceSelectView(
          key: const ValueKey('serviceSelect'),
          state: state,
          onSelect: (serviceId, name) {
            ref.read(citaExpressProvider.notifier).selectService(serviceId, name);
          },
        );
      case CitaExpressStep.searching:
        return _SearchingView(
          key: const ValueKey('searching'),
          serviceName: state.selectedServiceName ?? '',
        );
      case CitaExpressStep.results:
      case CitaExpressStep.futureResults:
        return _ResultsView(
          key: ValueKey('results_${state.step.name}'),
          state: state,
          onSelect: (card) {
            ref.read(citaExpressProvider.notifier).selectResult(card);
          },
          onBack: () {
            ref.read(citaExpressProvider.notifier).backToServices();
          },
        );
      case CitaExpressStep.noSlotsToday:
        return _NoSlotsView(
          key: const ValueKey('noSlots'),
          state: state,
          onOtherDay: () {
            ref.read(citaExpressProvider.notifier).tryOtherDay();
          },
          onBack: () {
            ref.read(citaExpressProvider.notifier).backToServices();
          },
        );
      case CitaExpressStep.confirming:
        return _ConfirmView(
          key: const ValueKey('confirming'),
          state: state,
          onConfirm: () {
            // Check auth first
            final userId = SupabaseClientService.currentUserId;
            if (userId == null) {
              context.push('/auth');
              return;
            }
            ref.read(citaExpressProvider.notifier).confirmBooking();
          },
          onBack: () {
            ref.read(citaExpressProvider.notifier).backToResults();
          },
        );
      case CitaExpressStep.booking:
        return _BookingView(key: const ValueKey('booking'));
      case CitaExpressStep.booked:
        return _BookedView(
          key: const ValueKey('booked'),
          state: state,
          onDone: () => context.go('/home'),
        );
      case CitaExpressStep.error:
        return _ErrorView(
          key: const ValueKey('error'),
          error: state.error ?? 'Error desconocido',
          onRetry: () {
            ref
                .read(citaExpressProvider.notifier)
                .loadBusiness(widget.businessId);
          },
          onClose: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/home');
            }
          },
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Loading
// ---------------------------------------------------------------------------

class _LoadingView extends StatelessWidget {
  const _LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: colors.primary),
          const SizedBox(height: AppConstants.paddingMD),
          Text(
            'Cargando salon...',
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: colors.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Service Selection
// ---------------------------------------------------------------------------

class _ServiceSelectView extends StatelessWidget {
  final CitaExpressState state;
  final void Function(String serviceId, String name) onSelect;

  const _ServiceSelectView({
    super.key,
    required this.state,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final biz = state.businessInfo;
    final bizName = biz?['name'] as String? ?? 'Salon';
    final bizAddress = biz?['address'] as String? ?? '';
    final bizPhoto = biz?['photo_url'] as String?;

    // Group services by category
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final svc in state.services) {
      final cat = svc['category'] as String? ?? 'Otros';
      grouped.putIfAbsent(cat, () => []).add(svc);
    }

    return ListView(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      children: [
        // Salon header card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppConstants.radiusLG),
            border: Border.all(
              color: colors.onSurface.withValues(alpha: 0.08),
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
          child: Row(
            children: [
              // Salon photo
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                  color: colors.primary.withValues(alpha: 0.08),
                  image: bizPhoto != null
                      ? DecorationImage(
                          image: NetworkImage(bizPhoto),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: bizPhoto == null
                    ? Icon(Icons.store_rounded,
                        color: colors.primary, size: 28)
                    : null,
              ),
              const SizedBox(width: AppConstants.paddingSM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bizName,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    if (bizAddress.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        bizAddress,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: colors.onSurface.withValues(alpha: 0.5),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppConstants.paddingLG),

        // Question
        Text(
          'Que servicio te interesa?',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: AppConstants.paddingMD),

        // Services grouped by category
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.only(
              top: AppConstants.paddingSM,
              bottom: AppConstants.paddingXS,
            ),
            child: Text(
              _categoryLabel(entry.key),
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: colors.primary.withValues(alpha: 0.6),
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: entry.value.map((svc) {
              final name = svc['name'] as String? ?? '';
              final serviceId = svc['id'] as String;
              final price = svc['price'] as num?;
              final duration = svc['duration_minutes'] as int?;

              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                child: InkWell(
                  onTap: () => onSelect(serviceId, name),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMD),
                      border: Border.all(
                        color: colors.onSurface.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (price != null)
                              Text(
                                '\$${price.toStringAsFixed(0)}',
                                style: GoogleFonts.nunito(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: colors.primary,
                                ),
                              ),
                            if (price != null && duration != null)
                              Text(
                                ' · ',
                                style: GoogleFonts.nunito(
                                  fontSize: 11,
                                  color: colors.onSurface
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                            if (duration != null)
                              Text(
                                '${duration}min',
                                style: GoogleFonts.nunito(
                                  fontSize: 11,
                                  color: colors.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],

        const SizedBox(height: AppConstants.paddingXL),
      ],
    );
  }

  String _categoryLabel(String key) {
    const labels = {
      'unas': 'UNAS',
      'cabello': 'CABELLO',
      'pestanas': 'PESTANAS',
      'cejas': 'CEJAS',
      'maquillaje': 'MAQUILLAJE',
      'facial': 'FACIAL',
      'corporal': 'CORPORAL',
      'depilacion': 'DEPILACION',
      'barberia': 'BARBERIA',
    };
    return labels[key.toLowerCase()] ?? key.toUpperCase();
  }
}

// ---------------------------------------------------------------------------
// Searching
// ---------------------------------------------------------------------------

class _SearchingView extends StatelessWidget {
  final String serviceName;
  const _SearchingView({super.key, required this.serviceName});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: colors.primary),
          const SizedBox(height: AppConstants.paddingLG),
          Text(
            'Buscando disponibilidad',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            serviceName,
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: colors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Results
// ---------------------------------------------------------------------------

class _ResultsView extends StatelessWidget {
  final CitaExpressState state;
  final void Function(ResultCard) onSelect;
  final VoidCallback onBack;

  const _ResultsView({
    super.key,
    required this.state,
    required this.onSelect,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final results = state.curateResponse?.results ?? [];

    String headerText;
    switch (state.step) {
      case CitaExpressStep.futureResults:
        final bizName = state.businessInfo?['name'] as String? ?? 'salon';
        headerText = 'Disponible esta semana en $bizName';
      default:
        headerText = 'Disponible hoy';
    }

    return ListView(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      children: [
        // Header
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_rounded,
                  color: colors.onSurface, size: 22),
              onPressed: onBack,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                headerText,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: AppConstants.paddingMD),

        // Result cards
        for (final result in results) ...[
          _ResultCardWidget(
            result: result,
            isWalkin: state.step == CitaExpressStep.results,
            onReserve: () => onSelect(result),
          ),
          const SizedBox(height: AppConstants.paddingSM),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Result Card Widget
// ---------------------------------------------------------------------------

class _ResultCardWidget extends StatelessWidget {
  final ResultCard result;
  final bool isWalkin;
  final VoidCallback onReserve;

  const _ResultCardWidget({
    required this.result,
    required this.isWalkin,
    required this.onReserve,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final slot = result.slot;
    final timeFormat = DateFormat('h:mm a', 'es');
    final dateFormat = DateFormat('EEE d MMM', 'es');
    final startTime = slot.startTime.toLocal();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLG),
        border: Border.all(
          color: colors.onSurface.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Staff + business header
          Padding(
            padding: const EdgeInsets.all(AppConstants.paddingMD),
            child: Row(
              children: [
                // Staff avatar
                CircleAvatar(
                  radius: 22,
                  backgroundColor: colors.primary.withValues(alpha: 0.08),
                  backgroundImage: result.staff.avatarUrl != null
                      ? NetworkImage(result.staff.avatarUrl!)
                      : null,
                  child: result.staff.avatarUrl == null
                      ? Icon(Icons.person, color: colors.primary, size: 22)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.staff.name,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                      Text(
                        result.business.name,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: colors.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                // Rating
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded,
                          size: 14, color: colors.primary),
                      const SizedBox(width: 2),
                      Text(
                        result.staff.rating.toStringAsFixed(1),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Divider(
            height: 1,
            color: colors.onSurface.withValues(alpha: 0.06),
          ),

          // Service + time + price
          Padding(
            padding: const EdgeInsets.all(AppConstants.paddingMD),
            child: Row(
              children: [
                // Time
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timeFormat.format(startTime),
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    Text(
                      dateFormat.format(startTime),
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: colors.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${result.service.price.toStringAsFixed(0)} MXN',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                      ),
                    ),
                    Text(
                      '${result.service.durationMinutes} min',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: colors.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Transport info
          if (isWalkin)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.paddingMD,
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.place_rounded, size: 14, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      'Ya estas aqui',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Badges
          if (result.badges.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.paddingMD,
                8,
                AppConstants.paddingMD,
                0,
              ),
              child: Wrap(
                spacing: 6,
                children: result.badges.map((b) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _badgeLabel(b),
                      style: GoogleFonts.nunito(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // RESERVAR button
          Padding(
            padding: const EdgeInsets.all(AppConstants.paddingMD),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: onReserve,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusMD),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'RESERVAR',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _badgeLabel(String badge) {
    const labels = {
      'available_today': 'Hoy',
      'walk_in_ok': 'Walk-in',
      'new_on_platform': 'Nuevo',
      'instant_confirm': 'Confirmacion inmediata',
    };
    return labels[badge] ?? badge;
  }
}

// ---------------------------------------------------------------------------
// No Slots Today
// ---------------------------------------------------------------------------

class _NoSlotsView extends StatelessWidget {
  final CitaExpressState state;
  final VoidCallback onOtherDay;
  final VoidCallback onBack;

  const _NoSlotsView({
    super.key,
    required this.state,
    required this.onOtherDay,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bizName = state.businessInfo?['name'] as String? ?? 'este salon';

    return Padding(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      child: Column(
        children: [
          // Back button
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: Icon(Icons.arrow_back_rounded,
                  color: colors.onSurface, size: 22),
              onPressed: onBack,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),

          const Spacer(),

          // No slots message
          Icon(
            Icons.event_busy_rounded,
            size: 56,
            color: colors.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppConstants.paddingMD),
          Text(
            'Sin disponibilidad hoy',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$bizName no tiene citas disponibles hoy para ${state.selectedServiceName ?? "este servicio"}.',
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: colors.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppConstants.paddingXL),

          // Try another day at same salon
          _ActionCard(
            icon: Icons.calendar_month_rounded,
            title: 'Otro dia',
            subtitle: 'Buscar disponibilidad esta semana en $bizName',
            color: colors.primary,
            onTap: onOtherDay,
          ),

          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppConstants.radiusLG),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusLG),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppConstants.paddingMD),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusLG),
            border: Border.all(
              color: color.withValues(alpha: 0.15),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: AppConstants.paddingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: colors.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Confirmation
// ---------------------------------------------------------------------------

class _ConfirmView extends StatelessWidget {
  final CitaExpressState state;
  final VoidCallback onConfirm;
  final VoidCallback onBack;

  const _ConfirmView({
    super.key,
    required this.state,
    required this.onConfirm,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final result = state.selectedResult!;
    final slot = result.slot;
    final startTime = slot.startTime.toLocal();
    final timeFormat = DateFormat('h:mm a', 'es');
    final dateFormat = DateFormat('EEEE d MMMM', 'es');

    return ListView(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      children: [
        // Back
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            icon: Icon(Icons.arrow_back_rounded,
                color: colors.onSurface, size: 22),
            onPressed: onBack,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),

        const SizedBox(height: AppConstants.paddingMD),

        Text(
          'Confirmar tu cita',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: colors.onSurface,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: AppConstants.paddingLG),

        // Summary card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppConstants.radiusLG),
            border: Border.all(
              color: colors.primary.withValues(alpha: 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(AppConstants.paddingLG),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Service
              _SummaryRow(
                icon: Icons.content_cut_rounded,
                label: 'Servicio',
                value: result.service.name,
                color: colors,
              ),
              const SizedBox(height: AppConstants.paddingMD),

              // Staff
              _SummaryRow(
                icon: Icons.person_rounded,
                label: 'Estilista',
                value: result.staff.name,
                color: colors,
              ),
              const SizedBox(height: AppConstants.paddingMD),

              // Salon
              _SummaryRow(
                icon: Icons.store_rounded,
                label: 'Salon',
                value: result.business.name,
                color: colors,
              ),
              const SizedBox(height: AppConstants.paddingMD),

              // Date + time
              _SummaryRow(
                icon: Icons.calendar_today_rounded,
                label: 'Fecha',
                value: dateFormat.format(startTime),
                color: colors,
              ),
              const SizedBox(height: AppConstants.paddingMD),

              _SummaryRow(
                icon: Icons.access_time_rounded,
                label: 'Hora',
                value: timeFormat.format(startTime),
                color: colors,
              ),
              const SizedBox(height: AppConstants.paddingMD),

              // Duration
              _SummaryRow(
                icon: Icons.timer_rounded,
                label: 'Duracion',
                value: '${result.service.durationMinutes} min',
                color: colors,
              ),

              const SizedBox(height: AppConstants.paddingMD),
              Divider(
                color: colors.onSurface.withValues(alpha: 0.06),
              ),
              const SizedBox(height: AppConstants.paddingSM),

              // Price
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                  Text(
                    '\$${result.service.price.toStringAsFixed(0)} MXN',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: AppConstants.paddingXL),

        // CONFIRMAR button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMD),
              ),
              elevation: 0,
            ),
            child: Text(
              'CONFIRMAR CITA',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ColorScheme color;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color.primary.withValues(alpha: 0.5)),
        const SizedBox(width: 10),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: color.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Booking in progress
// ---------------------------------------------------------------------------

class _BookingView extends StatelessWidget {
  const _BookingView({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: colors.primary),
          const SizedBox(height: AppConstants.paddingMD),
          Text(
            'Reservando tu cita...',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Booked (success)
// ---------------------------------------------------------------------------

class _BookedView extends StatelessWidget {
  final CitaExpressState state;
  final VoidCallback onDone;

  const _BookedView({
    super.key,
    required this.state,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final result = state.selectedResult;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLG),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 48,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: AppConstants.paddingLG),
            Text(
              'Cita Reservada',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: AppConstants.paddingSM),
            if (result != null) ...[
              Text(
                result.service.name,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${result.staff.name} en ${result.business.name}',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('EEEE d MMMM, h:mm a', 'es')
                    .format(result.slot.startTime.toLocal()),
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
            const SizedBox(height: AppConstants.paddingXL),
            SizedBox(
              width: 200,
              height: 48,
              child: ElevatedButton(
                onPressed: onDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusMD),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'LISTO',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error
// ---------------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  const _ErrorView({
    super.key,
    required this.error,
    required this.onRetry,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLG),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: colors.error.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppConstants.paddingMD),
            Text(
              error,
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: colors.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.paddingLG),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: onClose,
                  child: const Text('Cerrar'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
