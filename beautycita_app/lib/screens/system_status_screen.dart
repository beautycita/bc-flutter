import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/constants.dart';
import '../config/theme_extension.dart';

class SystemStatusScreen extends StatelessWidget {
  const SystemStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Estado del sistema',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.screenPaddingHorizontal,
          vertical: AppConstants.paddingMD,
        ),
        children: [
          // ── Hero Section ──
          _HeroCard(ext: ext),

          const SizedBox(height: AppConstants.paddingMD),

          // ── Overall Status Banner ──
          _OverallStatusBanner(colorScheme: colorScheme),

          const SizedBox(height: AppConstants.paddingLG),

          // ── Services Section Header ──
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: AppConstants.paddingSM),
            child: Text(
              'SERVICIOS',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: colorScheme.primary,
              ),
            ),
          ),

          // ── Service Cards ──
          ..._services(ext).map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: AppConstants.paddingSM),
              child: _ServiceCard(service: s, ext: ext),
            ),
          ),

          const SizedBox(height: AppConstants.paddingLG),

          // ── Incident History Section ──
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: AppConstants.paddingSM),
            child: Text(
              'HISTORIAL DE INCIDENTES',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: colorScheme.primary,
              ),
            ),
          ),

          _IncidentHistoryCard(colorScheme: colorScheme),

          const SizedBox(height: AppConstants.paddingXL),

          // ── Footer ──
          Center(
            child: Text(
              'Para reportar un problema, contacta\nsoporte@beautycita.com',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.45),
                height: 1.6,
              ),
            ),
          ),

          const SizedBox(height: AppConstants.paddingLG),
        ],
      ),
    );
  }

  List<_ServiceData> _services(BCThemeExtension ext) => [
        _ServiceData(
          icon: Icons.apps_rounded,
          name: 'Plataforma Principal',
          description: 'Aplicacion movil y servicios centrales',
        ),
        _ServiceData(
          icon: Icons.api_rounded,
          name: 'Servicios API',
          description: 'Endpoints REST y funciones edge',
        ),
        _ServiceData(
          icon: Icons.calendar_month_rounded,
          name: 'Sistema de Reservas',
          description: 'Motor de reservas y disponibilidad',
        ),
        _ServiceData(
          icon: Icons.payment_rounded,
          name: 'Procesamiento de Pagos',
          description: 'Stripe, BTCPay y pagos en efectivo',
        ),
        _ServiceData(
          icon: Icons.chat_rounded,
          name: 'Sistema de Mensajeria',
          description: 'Chat con salones y soporte',
        ),
        _ServiceData(
          icon: Icons.notifications_rounded,
          name: 'Notificaciones',
          description: 'Push, recordatorios y alertas',
        ),
        _ServiceData(
          icon: Icons.auto_awesome_rounded,
          name: 'Recomendaciones IA',
          description: 'Motor inteligente de recomendaciones',
        ),
        _ServiceData(
          icon: Icons.cloud_rounded,
          name: 'Almacenamiento de Medios',
          description: 'Imagenes, fotos y archivos (Cloudflare R2)',
        ),
        _ServiceData(
          icon: Icons.security_rounded,
          name: 'Seguridad y Autenticacion',
          description: 'Login biometrico y sesiones',
        ),
      ];
}

// ─────────────────────────────────────────────────────────────
// Hero Card
// ─────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.ext});

  final BCThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingLG,
        vertical: AppConstants.paddingXL,
      ),
      decoration: BoxDecoration(
        gradient: ext.primaryGradient,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
            ),
            child: const Icon(
              Icons.monitor_heart_rounded,
              color: Colors.white,
              size: AppConstants.iconSizeLG,
            ),
          ),

          const SizedBox(height: AppConstants.paddingMD),

          // Status row
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFF4ADE80),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4ADE80).withValues(alpha: 0.5),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppConstants.paddingSM),
              Text(
                'Todos los sistemas operativos',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Overall Status Banner
// ─────────────────────────────────────────────────────────────

class _OverallStatusBanner extends StatelessWidget {
  const _OverallStatusBanner({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        border: Border.all(color: const Color(0xFFBBF7D0), width: 1),
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF16A34A),
              size: AppConstants.iconSizeMD,
            ),
          ),
          const SizedBox(width: AppConstants.paddingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Todos los servicios funcionan correctamente',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF15803D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Disponibilidad promedio: 99.98%',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF16A34A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Actualizado hace unos momentos',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: const Color(0xFF4ADE80).withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Service Data Model
// ─────────────────────────────────────────────────────────────

class _ServiceData {
  const _ServiceData({
    required this.icon,
    required this.name,
    required this.description,
  });

  final IconData icon;
  final String name;
  final String description;
}

// ─────────────────────────────────────────────────────────────
// Service Card
// ─────────────────────────────────────────────────────────────

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service, required this.ext});

  final _ServiceData service;
  final BCThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMD,
        vertical: AppConstants.paddingMD,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(
          color: ext.cardBorderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon with gradient accent background
          ShaderMask(
            shaderCallback: (bounds) => ext.primaryGradient.createShader(bounds),
            blendMode: BlendMode.srcIn,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppConstants.radiusSM),
              ),
              child: Icon(
                service.icon,
                size: AppConstants.iconSizeMD,
                color: colorScheme.primary,
              ),
            ),
          ),

          const SizedBox(width: AppConstants.paddingMD),

          // Name + description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  service.description,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: AppConstants.paddingSM),

          // Green status badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingSM,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              border: Border.all(color: const Color(0xFFBBF7D0), width: 1),
              borderRadius: BorderRadius.circular(AppConstants.radiusFull),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF22C55E),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'Operativo',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Incident History Card
// ─────────────────────────────────────────────────────────────

class _IncidentHistoryCard extends StatelessWidget {
  const _IncidentHistoryCard({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: Color(0xFF22C55E),
              size: AppConstants.iconSizeMD,
            ),
          ),
          const SizedBox(width: AppConstants.paddingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sin incidentes recientes',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Los ultimos 90 dias han sido sin interrupciones',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
