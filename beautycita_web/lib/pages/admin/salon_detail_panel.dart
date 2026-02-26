import 'package:beautycita_core/theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../providers/admin_salons_provider.dart';

/// Detail panel content for a registered salon.
class RegisteredSalonDetailContent extends StatelessWidget {
  const RegisteredSalonDetailContent({required this.salon, super.key});

  final RegisteredSalon salon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dateFormat = DateFormat('d MMM yyyy', 'es');
    final currencyFormat = NumberFormat.currency(
      locale: 'es_MX',
      symbol: r'$',
      decimalDigits: 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Logo + Name ────────────────────────────────────────────────
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: BCSpacing.avatarLg / 2,
                backgroundColor: colors.primary.withValues(alpha: 0.1),
                backgroundImage: salon.logoUrl != null
                    ? NetworkImage(salon.logoUrl!)
                    : null,
                child: salon.logoUrl == null
                    ? Icon(
                        Icons.store,
                        size: BCSpacing.iconLg,
                        color: colors.primary,
                      )
                    : null,
              ),
              const SizedBox(height: BCSpacing.sm),
              Text(
                salon.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: BCSpacing.xs),
              if (salon.city != null)
                Text(
                  salon.city!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              const SizedBox(height: BCSpacing.sm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _VerifiedBadge(verified: salon.verified),
                  const SizedBox(width: BCSpacing.sm),
                  _StripeStatusBadge(status: salon.stripeStatus),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: BCSpacing.lg),
        const Divider(),
        const SizedBox(height: BCSpacing.md),

        // ── Stats ──────────────────────────────────────────────────────
        _SectionTitle(title: 'Estadisticas'),
        const SizedBox(height: BCSpacing.sm),
        Row(
          children: [
            _StatCard(
              label: 'Servicios',
              value: '${salon.servicesCount}',
              icon: Icons.content_cut,
            ),
            const SizedBox(width: BCSpacing.sm),
            _StatCard(
              label: 'Staff',
              value: '${salon.staffCount}',
              icon: Icons.people,
            ),
            const SizedBox(width: BCSpacing.sm),
            _StatCard(
              label: 'Reservas',
              value: '${salon.bookingsCount}',
              icon: Icons.calendar_today,
            ),
          ],
        ),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.star,
          label: 'Rating',
          value: salon.rating > 0
              ? '${salon.rating.toStringAsFixed(1)} / 5.0'
              : 'Sin calificaciones',
          trailing: salon.rating > 0
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (i) {
                    return Icon(
                      i < salon.rating.round()
                          ? Icons.star
                          : Icons.star_border,
                      size: 14,
                      color: Colors.amber,
                    );
                  }),
                )
              : null,
        ),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.attach_money,
          label: 'Ingresos',
          value: currencyFormat.format(salon.revenue),
        ),

        const SizedBox(height: BCSpacing.lg),
        const Divider(),
        const SizedBox(height: BCSpacing.md),

        // ── Contact ────────────────────────────────────────────────────
        _SectionTitle(title: 'Contacto'),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.person,
          label: 'Dueno',
          value: salon.ownerName ?? 'No registrado',
        ),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.phone_outlined,
          label: 'Telefono',
          value: salon.phone ?? 'No registrado',
        ),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.email_outlined,
          label: 'Email',
          value: salon.email ?? 'No registrado',
        ),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.calendar_today_outlined,
          label: 'Registrado',
          value: dateFormat.format(salon.createdAt),
        ),

        const SizedBox(height: BCSpacing.lg),
        const Divider(),
        const SizedBox(height: BCSpacing.md),

        // ── Actions ────────────────────────────────────────────────────
        _SectionTitle(title: 'Acciones'),
        const SizedBox(height: BCSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              // TODO: Toggle verified status
            },
            icon: Icon(
              salon.verified
                  ? Icons.remove_circle_outline
                  : Icons.verified_outlined,
              size: 18,
            ),
            label: Text(
              salon.verified ? 'Quitar verificacion' : 'Verificar salon',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor:
                  salon.verified ? colors.error : Colors.green,
            ),
          ),
        ),
      ],
    );
  }
}

/// Detail panel content for a discovered salon.
class DiscoveredSalonDetailContent extends StatelessWidget {
  const DiscoveredSalonDetailContent({required this.salon, super.key});

  final DiscoveredSalon salon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dateFormat = DateFormat('d MMM yyyy', 'es');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Name + Source ──────────────────────────────────────────────
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: BCSpacing.avatarLg / 2,
                backgroundColor: colors.secondary.withValues(alpha: 0.1),
                child: Icon(
                  Icons.explore,
                  size: BCSpacing.iconLg,
                  color: colors.secondary,
                ),
              ),
              const SizedBox(height: BCSpacing.sm),
              Text(
                salon.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: BCSpacing.xs),
              _SourceBadge(source: salon.source),
            ],
          ),
        ),

        const SizedBox(height: BCSpacing.lg),
        const Divider(),
        const SizedBox(height: BCSpacing.md),

        // ── Info ────────────────────────────────────────────────────────
        _SectionTitle(title: 'Informacion'),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.phone_outlined,
          label: 'Telefono',
          value: salon.phone ?? 'No disponible',
          trailing: salon.phone != null
              ? _WaStatusBadge(status: salon.waStatus)
              : null,
        ),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.location_on_outlined,
          label: 'Ciudad',
          value: salon.city ?? 'Desconocida',
        ),
        const SizedBox(height: BCSpacing.sm),
        if (salon.address != null) ...[
          _InfoRow(
            icon: Icons.map_outlined,
            label: 'Direccion',
            value: salon.address!,
          ),
          const SizedBox(height: BCSpacing.sm),
        ],
        _InfoRow(
          icon: Icons.calendar_today_outlined,
          label: 'Descubierto',
          value: dateFormat.format(salon.createdAt),
        ),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.message_outlined,
          label: 'Ultimo contacto',
          value: salon.lastContactDate != null
              ? dateFormat.format(salon.lastContactDate!)
              : 'Nunca',
        ),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.trending_up,
          label: 'Senales de interes',
          value: '${salon.interestSignals}',
        ),

        if (salon.latitude != null && salon.longitude != null) ...[
          const SizedBox(height: BCSpacing.sm),
          _InfoRow(
            icon: Icons.gps_fixed,
            label: 'Coordenadas',
            value:
                '${salon.latitude!.toStringAsFixed(4)}, ${salon.longitude!.toStringAsFixed(4)}',
          ),
        ],

        const SizedBox(height: BCSpacing.lg),
        const Divider(),
        const SizedBox(height: BCSpacing.md),

        // ── Actions ────────────────────────────────────────────────────
        _SectionTitle(title: 'Acciones'),
        const SizedBox(height: BCSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              // TODO: Convert to registered salon
            },
            icon: const Icon(Icons.add_business, size: 18),
            label: const Text('Convertir a registrado'),
          ),
        ),
        const SizedBox(height: BCSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              // TODO: Send WhatsApp invitation
            },
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Enviar invitacion WA'),
          ),
        ),
      ],
    );
  }
}

// ── Shared helper widgets ─────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        Icon(icon, size: 16, color: colors.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: BCSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(BCSpacing.sm),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: colors.primary),
            const SizedBox(height: BCSpacing.xs),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.primary,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge({required this.verified});
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final color = verified ? Colors.green : Colors.orange;
    final label = verified ? 'Verificado' : 'No verificado';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(BCSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.verified : Icons.pending,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StripeStatusBadge extends StatelessWidget {
  const _StripeStatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'connected' => ('Stripe OK', Colors.green),
      'pending' => ('Stripe pendiente', Colors.orange),
      _ => ('Sin Stripe', Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(BCSpacing.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({this.source});
  final String? source;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (source) {
      'google_maps' => ('Google Maps', Colors.blue),
      'facebook' => ('Facebook', Colors.indigo),
      'bing' => ('Bing', Colors.teal),
      _ => (source ?? 'Desconocido', Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(BCSpacing.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _WaStatusBadge extends StatelessWidget {
  const _WaStatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      'valid' => (Icons.check_circle, Colors.green),
      'invalid' => (Icons.cancel, Colors.red),
      _ => (Icons.help_outline, Colors.grey),
    };

    return Icon(icon, size: 16, color: color);
  }
}
