import 'package:beautycita_core/theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../providers/admin_users_provider.dart';

/// Detail panel content for a selected user in the admin users page.
class UserDetailContent extends StatelessWidget {
  const UserDetailContent({required this.user, super.key});

  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dateFormat = DateFormat('d MMM yyyy, HH:mm', 'es');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Avatar + Name ───────────────────────────────────────────────
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: BCSpacing.avatarLg / 2,
                backgroundColor: colors.primary.withValues(alpha: 0.1),
                backgroundImage: user.avatarUrl != null
                    ? NetworkImage(user.avatarUrl!)
                    : null,
                child: user.avatarUrl == null
                    ? Icon(
                        Icons.person,
                        size: BCSpacing.iconLg,
                        color: colors.primary,
                      )
                    : null,
              ),
              const SizedBox(height: BCSpacing.sm),
              Text(
                user.username,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: BCSpacing.xs),
              _RoleBadge(role: user.role),
            ],
          ),
        ),

        const SizedBox(height: BCSpacing.lg),
        const Divider(),
        const SizedBox(height: BCSpacing.md),

        // ── Contact info ────────────────────────────────────────────────
        _SectionTitle(title: 'Contacto'),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.email_outlined,
          label: 'Email',
          value: user.email ?? 'No registrado',
        ),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.phone_outlined,
          label: 'Telefono',
          value: user.phone ?? 'No registrado',
          trailing: user.phone != null
              ? Icon(
                  user.phoneVerified
                      ? Icons.verified
                      : Icons.warning_amber_rounded,
                  size: 16,
                  color: user.phoneVerified ? Colors.green : Colors.orange,
                )
              : null,
        ),

        const SizedBox(height: BCSpacing.lg),
        const Divider(),
        const SizedBox(height: BCSpacing.md),

        // ── Account info ────────────────────────────────────────────────
        _SectionTitle(title: 'Cuenta'),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.calendar_today_outlined,
          label: 'Registrado',
          value: dateFormat.format(user.createdAt),
        ),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.access_time,
          label: 'Ultimo acceso',
          value: user.lastActiveAt != null
              ? dateFormat.format(user.lastActiveAt!)
              : 'Nunca',
        ),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.circle,
          label: 'Estado',
          value: user.isActive ? 'Activo' : 'Inactivo',
          trailing: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: user.isActive ? Colors.green : Colors.red,
            ),
          ),
        ),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.fingerprint,
          label: 'ID',
          value: user.id.length > 8
              ? '${user.id.substring(0, 8)}...'
              : user.id,
        ),

        const SizedBox(height: BCSpacing.lg),
        const Divider(),
        const SizedBox(height: BCSpacing.md),

        // ── Admin notes ─────────────────────────────────────────────────
        _SectionTitle(title: 'Notas del admin'),
        const SizedBox(height: BCSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(BCSpacing.sm),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Text(
            user.notes?.isNotEmpty == true
                ? user.notes!
                : 'Sin notas',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.7),
              fontStyle: user.notes?.isNotEmpty == true
                  ? FontStyle.normal
                  : FontStyle.italic,
            ),
          ),
        ),

        const SizedBox(height: BCSpacing.lg),
        const Divider(),
        const SizedBox(height: BCSpacing.md),

        // ── Actions ─────────────────────────────────────────────────────
        _SectionTitle(title: 'Acciones'),
        const SizedBox(height: BCSpacing.sm),

        // Role change
        Row(
          children: [
            Text(
              'Cambiar rol:',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(width: BCSpacing.sm),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: user.role,
                isDense: true,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: BCSpacing.sm,
                    vertical: BCSpacing.xs,
                  ),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(BCSpacing.radiusXs),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'client', child: Text('Cliente')),
                  DropdownMenuItem(
                      value: 'stylist', child: Text('Estilista')),
                  DropdownMenuItem(
                      value: 'salon_owner', child: Text('Dueno')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (value) {
                  // TODO: Update role via Supabase
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: BCSpacing.md),

        // Suspend/activate
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              // TODO: Toggle active status via Supabase
            },
            icon: Icon(
              user.isActive ? Icons.block : Icons.check_circle_outline,
              size: 18,
            ),
            label: Text(user.isActive ? 'Suspender cuenta' : 'Activar cuenta'),
            style: OutlinedButton.styleFrom(
              foregroundColor:
                  user.isActive ? colors.error : Colors.green,
              side: BorderSide(
                color: user.isActive ? colors.error : Colors.green,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (role) {
      'admin' => ('Admin', Colors.deepPurple),
      'salon_owner' => ('Dueno', Colors.teal),
      'stylist' => ('Estilista', Colors.indigo),
      'client' => ('Cliente', Colors.blueGrey),
      _ => (role, Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BCSpacing.sm,
        vertical: BCSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(BCSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

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
                maxLines: 1,
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
