import 'package:beautycita_core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final dateFmt = DateFormat('d MMM yyyy, HH:mm', 'es');
    final dateFmtShort = DateFormat('d MMM yyyy', 'es');

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
              if (user.fullName != null && user.fullName!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  user.fullName!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
              const SizedBox(height: BCSpacing.xs),
              _RoleBadge(role: user.role),
            ],
          ),
        ),

        const SizedBox(height: BCSpacing.lg),
        const Divider(),
        const SizedBox(height: BCSpacing.md),

        // ── Auth method ───────────────────────────────────────────────
        _SectionTitle(title: 'Autenticacion'),
        const SizedBox(height: BCSpacing.sm),
        _AuthProvidersRow(providers: user.authProviders),
        const SizedBox(height: BCSpacing.xs),
        _InfoRow(
          icon: Icons.lock_outline,
          label: 'Contrasena',
          value: user.hasPassword ? 'Configurada' : 'Sin contrasena',
          trailing: Icon(
            user.hasPassword ? Icons.check_circle : Icons.cancel_outlined,
            size: 16,
            color: user.hasPassword ? Colors.green : Colors.grey,
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
          trailing: user.email != null
              ? _VerificationBadge(
                  verified: user.emailVerified,
                  verifiedAt: user.emailConfirmedAt,
                )
              : null,
        ),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.phone_outlined,
          label: 'Telefono',
          value: user.phone ?? 'No registrado',
          trailing: user.phone != null
              ? _VerificationBadge(
                  verified: user.phoneVerified,
                  verifiedAt: user.phoneVerifiedAt,
                )
              : null,
        ),

        const SizedBox(height: BCSpacing.lg),
        const Divider(),
        const SizedBox(height: BCSpacing.md),

        // ── Personal info ───────────────────────────────────────────────
        _SectionTitle(title: 'Personal'),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.cake_outlined,
          label: 'Cumpleanos',
          value: user.birthday != null
              ? dateFmtShort.format(user.birthday!)
              : 'No registrado',
        ),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.person_outline,
          label: 'Genero',
          value: switch (user.gender) {
            'male' => 'Masculino',
            'female' => 'Femenino',
            'other' => 'Otro',
            String g when g.isNotEmpty => g,
            _ => 'No registrado',
          },
        ),
        if (user.homeAddress != null && user.homeAddress!.isNotEmpty) ...[
          const SizedBox(height: BCSpacing.sm),
          _InfoRow(
            icon: Icons.home_outlined,
            label: 'Direccion',
            value: user.homeAddress!,
          ),
        ],

        const SizedBox(height: BCSpacing.lg),
        const Divider(),
        const SizedBox(height: BCSpacing.md),

        // ── Account info ────────────────────────────────────────────────
        _SectionTitle(title: 'Cuenta'),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.calendar_today_outlined,
          label: 'Registrado',
          value: dateFmt.format(user.createdAt),
        ),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.login,
          label: 'Ultimo login',
          value: user.lastSignInAt != null
              ? dateFmt.format(user.lastSignInAt!)
              : 'Nunca',
        ),
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.access_time,
          label: 'Ultimo acceso',
          value: user.lastSeen != null
              ? dateFmt.format(user.lastSeen!)
              : 'Nunca',
        ),
        if (user.updatedAt != null) ...[
          const SizedBox(height: BCSpacing.sm),
          _InfoRow(
            icon: Icons.edit_outlined,
            label: 'Perfil actualizado',
            value: dateFmt.format(user.updatedAt!),
          ),
        ],
        const SizedBox(height: BCSpacing.sm),
        _InfoRow(
          icon: Icons.circle,
          label: 'Estado',
          value: switch (user.status) {
            'active' => 'Activo',
            'suspended' => 'Suspendido',
            'archived' => 'Archivado',
            _ => user.status,
          },
          trailing: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: switch (user.status) {
                'active' => Colors.green,
                'suspended' => Colors.orange,
                _ => Colors.grey,
              },
            ),
          ),
        ),
        const SizedBox(height: BCSpacing.sm),
        _CopyableIdRow(id: user.id),

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
                  DropdownMenuItem(value: 'customer', child: Text('Cliente')),
                  DropdownMenuItem(
                      value: 'stylist', child: Text('Estilista')),
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
              // TODO: Toggle status via Supabase
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

// ── Auth providers row ───────────────────────────────────────────────────────

class _AuthProvidersRow extends StatelessWidget {
  const _AuthProvidersRow({required this.providers});
  final List<String> providers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (providers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(left: 28),
        child: Text(
          'Sin metodo de autenticacion',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurface.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 28),
      child: Wrap(
        spacing: BCSpacing.xs,
        runSpacing: BCSpacing.xs,
        children: providers.map((p) {
          final (icon, label, color) = switch (p) {
            'google' => (Icons.g_mobiledata, 'Google', Colors.red),
            'email' => (Icons.email, 'Email', Colors.blue),
            'phone' => (Icons.phone, 'Telefono', Colors.teal),
            _ => (Icons.key, p, Colors.grey),
          };
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(BCSpacing.radiusFull),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Verification badge ───────────────────────────────────────────────────────

class _VerificationBadge extends StatelessWidget {
  const _VerificationBadge({
    required this.verified,
    this.verifiedAt,
  });

  final bool verified;
  final DateTime? verifiedAt;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yy', 'es');

    return Tooltip(
      message: verified && verifiedAt != null
          ? 'Verificado ${fmt.format(verifiedAt!)}'
          : 'No verificado',
      child: Icon(
        verified ? Icons.verified : Icons.warning_amber_rounded,
        size: 16,
        color: verified ? Colors.green : Colors.orange,
      ),
    );
  }
}

// ── Copyable ID row ─────────────────────────────────────────────────────────

class _CopyableIdRow extends StatelessWidget {
  const _CopyableIdRow({required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        Icon(Icons.fingerprint, size: 16,
            color: colors.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: BCSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ID',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
              ),
              Text(
                id,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 14),
          tooltip: 'Copiar ID',
          visualDensity: VisualDensity.compact,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: id));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('ID copiado'),
                duration: Duration(seconds: 1),
              ),
            );
          },
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
      'admin' || 'superadmin' => ('Admin', Colors.deepPurple),
      'stylist' => ('Estilista', Colors.indigo),
      'customer' => ('Cliente', Colors.blueGrey),
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
