import 'package:beautycita_core/supabase.dart';
import 'package:beautycita_core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/admin_user_full_profile_provider.dart';
import '../../providers/admin_users_provider.dart';

/// Admin user-detail panel rebuilt 2026-04-19.
///
/// Prior version showed ~12 fields from the profiles row with no
/// activity, financial, or behavioral context. BC's call: "useless and
/// not visible". Rebuild pulls from `admin_get_user_full_profile(uuid)`
/// and lays out six dense tabs: Perfil / Actividad / Dinero /
/// Inteligencia / Seguridad / Notas.
///
/// The panel itself stays in the 560-px slide-in slot; the "Ver perfil
/// completo" button opens a 90 %-width dialog with the same tabs
/// expanded for dense inspection.
class UserDetailContent extends ConsumerWidget {
  const UserDetailContent({
    required this.user,
    this.onUserUpdated,
    super.key,
  });

  final AdminUser user;
  final VoidCallback? onUserUpdated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fullAsync = ref.watch(userFullProfileProvider(user.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          user: user,
          onExpand: () => _openFullScreen(context, ref, user),
        ),
        const Divider(height: 1),
        Expanded(
          child: fullAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => _ErrorSection(
              error: err,
              onRetry: () => ref.invalidate(userFullProfileProvider(user.id)),
            ),
            data: (profile) => _TabbedBody(
              user: user,
              profile: profile,
              onUserUpdated: () {
                ref.invalidate(userFullProfileProvider(user.id));
                onUserUpdated?.call();
              },
            ),
          ),
        ),
      ],
    );
  }

  void _openFullScreen(BuildContext context, WidgetRef ref, AdminUser user) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final size = MediaQuery.sizeOf(ctx);
        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: size.width * 0.05,
            vertical: size.height * 0.05,
          ),
          child: SizedBox(
            width: size.width * 0.9,
            height: size.height * 0.9,
            child: Consumer(
              builder: (ctx, innerRef, _) {
                final fullAsync =
                    innerRef.watch(userFullProfileProvider(user.id));
                return Column(
                  children: [
                    _Header(
                      user: user,
                      compact: false,
                      onExpand: () => Navigator.of(ctx).pop(),
                      expandIcon: Icons.close,
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: fullAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (err, _) => _ErrorSection(
                          error: err,
                          onRetry: () => innerRef.invalidate(
                              userFullProfileProvider(user.id)),
                        ),
                        data: (profile) => _TabbedBody(
                          user: user,
                          profile: profile,
                          onUserUpdated: () {
                            innerRef
                                .invalidate(userFullProfileProvider(user.id));
                            onUserUpdated?.call();
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.user,
    required this.onExpand,
    this.compact = true,
    this.expandIcon = Icons.open_in_full,
  });

  final AdminUser user;
  final VoidCallback onExpand;
  final bool compact;
  final IconData expandIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(BCSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: compact ? 28 : 36,
            backgroundColor: colors.primary.withValues(alpha: 0.1),
            backgroundImage: user.avatarUrl != null
                ? NetworkImage(user.avatarUrl!)
                : null,
            child: user.avatarUrl == null
                ? Icon(Icons.person,
                    size: compact ? 28 : 36, color: colors.primary)
                : null,
          ),
          const SizedBox(width: BCSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.username,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (user.fullName != null && user.fullName!.isNotEmpty)
                  Text(
                    user.fullName!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RoleBadge(role: user.role),
                    const SizedBox(width: BCSpacing.xs),
                    _StatusDot(status: user.status),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(expandIcon, size: 18),
            tooltip: compact ? 'Ver perfil completo' : 'Cerrar',
            onPressed: onExpand,
          ),
        ],
      ),
    );
  }
}

// ── Tabbed body ───────────────────────────────────────────────────────────────

class _TabbedBody extends StatelessWidget {
  const _TabbedBody({
    required this.user,
    required this.profile,
    required this.onUserUpdated,
  });

  final AdminUser user;
  final AdminUserFullProfile profile;
  final VoidCallback onUserUpdated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 6,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: 'Perfil'),
              Tab(text: 'Actividad'),
              Tab(text: 'Dinero'),
              Tab(text: 'Inteligencia'),
              Tab(text: 'Seguridad'),
              Tab(text: 'Notas'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: [
                _ProfileTab(user: user, profile: profile),
                _ActivityTab(profile: profile),
                _MoneyTab(profile: profile),
                _IntelligenceTab(profile: profile),
                _SecurityTab(
                  user: user,
                  profile: profile,
                  onUserUpdated: onUserUpdated,
                ),
                _NotesTab(user: user, profile: profile, onUpdated: onUserUpdated),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared bits ───────────────────────────────────────────────────────────────

class _TabScroll extends StatelessWidget {
  const _TabScroll({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(BCSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BCSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: BCSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _KV extends StatelessWidget {
  const _KV({
    required this.label,
    required this.value,
    this.icon,
    this.trailing,
    this.monospace = false,
  });

  final IconData? icon;
  final String label;
  final String value;
  final Widget? trailing;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: BCSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16,
                color: colors.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: BCSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  value,
                  style: monospace
                      ? theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace', fontSize: 11)
                      : theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _StatChips extends StatelessWidget {
  const _StatChips({required this.stats});
  final List<({String label, String value})> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Wrap(
      spacing: BCSpacing.sm,
      runSpacing: BCSpacing.sm,
      children: stats.map((s) {
        return Container(
          padding: const EdgeInsets.symmetric(
              horizontal: BCSpacing.md, vertical: BCSpacing.xs),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                s.label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                s.value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final String role;
  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (role) {
      'superadmin' => ('Superadmin', Colors.deepPurple),
      'admin' => ('Admin', Colors.purple),
      'stylist' => ('Estilista', Colors.indigo),
      'rp' => ('RP', Colors.teal),
      'customer' => ('Cliente', Colors.blueGrey),
      _ => (role, Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: BCSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(BCSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'active' => (Colors.green, 'Activo'),
      'suspended' => (Colors.orange, 'Suspendido'),
      'archived' => (Colors.grey, 'Archivado'),
      _ => (Colors.grey, status),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return _KV(
      icon: Icons.fingerprint,
      label: label,
      value: value,
      monospace: true,
      trailing: IconButton(
        icon: const Icon(Icons.copy, size: 14),
        visualDensity: VisualDensity.compact,
        tooltip: 'Copiar',
        onPressed: () {
          Clipboard.setData(ClipboardData(text: value));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Copiado'),
              duration: Duration(milliseconds: 800),
            ),
          );
        },
      ),
    );
  }
}

String _formatMoney(dynamic v) {
  final n = v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
  final fmt = NumberFormat.currency(
      locale: 'es_MX', symbol: r'$', decimalDigits: 2);
  return fmt.format(n);
}

String _formatDate(dynamic v, {bool withTime = true}) {
  if (v == null) return '—';
  final dt = v is DateTime ? v : DateTime.tryParse('$v');
  if (dt == null) return '—';
  return DateFormat(withTime ? 'd MMM yyyy, HH:mm' : 'd MMM yyyy', 'es')
      .format(dt.toLocal());
}

// ── Tab 1: Profile ────────────────────────────────────────────────────────────

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.user, required this.profile});
  final AdminUser user;
  final AdminUserFullProfile profile;

  @override
  Widget build(BuildContext context) {
    final auth = profile.auth;
    final p = profile.profile;
    final providers = (auth['providers'] as List?)?.cast<String>() ?? const [];

    return _TabScroll(children: [
      _Section(
        title: 'Contacto',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _KV(
            icon: Icons.email_outlined,
            label: 'Email',
            value: (auth['email'] as String?) ?? '—',
            trailing: _VerifiedBadge(verifiedAt: auth['email_confirmed_at']),
          ),
          _KV(
            icon: Icons.phone_outlined,
            label: 'Teléfono',
            value: (auth['phone'] as String?) ??
                (p['phone'] as String?) ??
                '—',
            trailing: _VerifiedBadge(verifiedAt: auth['phone_confirmed_at']),
          ),
        ]),
      ),
      _Section(
        title: 'Identidad',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _KV(
            icon: Icons.cake_outlined,
            label: 'Cumpleaños',
            value: _formatDate(p['birthday'], withTime: false),
          ),
          _KV(
            icon: Icons.person_outline,
            label: 'Género',
            value: switch (p['gender'] as String?) {
              'male' => 'Masculino',
              'female' => 'Femenino',
              'other' => 'Otro',
              final g? when g.isNotEmpty => g,
              _ => '—',
            },
          ),
          if ((p['home_address'] as String?)?.isNotEmpty == true)
            _KV(
              icon: Icons.home_outlined,
              label: 'Dirección',
              value: p['home_address'] as String,
            ),
          if (p['registration_source'] != null)
            _KV(
              icon: Icons.door_front_door_outlined,
              label: 'Origen',
              value: '${p['registration_source']}',
            ),
        ]),
      ),
      _Section(
        title: 'Autenticación',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (providers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: BCSpacing.sm),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: providers.map(_providerChip).toList(),
              ),
            ),
          _KV(
            icon: Icons.lock_outline,
            label: 'Contraseña',
            value: auth['has_password'] == true ? 'Configurada' : '—',
          ),
          _KV(
            icon: Icons.key_outlined,
            label: 'Passkeys (WebAuthn)',
            value: '${auth['webauthn_credential_count'] ?? 0}',
          ),
          _KV(
            icon: Icons.qr_code_2,
            label: 'Sesiones QR activas',
            value: '${auth['active_qr_sessions'] ?? 0}',
          ),
        ]),
      ),
      _Section(
        title: 'Cuenta',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _KV(
            icon: Icons.calendar_today_outlined,
            label: 'Registrado',
            value: _formatDate(auth['created_at']),
          ),
          _KV(
            icon: Icons.login,
            label: 'Último login',
            value: _formatDate(auth['last_sign_in_at']),
          ),
          _KV(
            icon: Icons.access_time,
            label: 'Última actividad',
            value: _formatDate(p['last_seen']),
          ),
          _KV(
            icon: Icons.edit_outlined,
            label: 'Perfil actualizado',
            value: _formatDate(p['updated_at']),
          ),
          if (p['uber_linked'] == true)
            const _KV(
              icon: Icons.local_taxi_outlined,
              label: 'Uber',
              value: 'Vinculado',
            ),
          if (p['fcm_token'] != null)
            _KV(
              icon: Icons.notifications_outlined,
              label: 'Push notifications',
              value: 'Activo (actualizado ${_formatDate(p['fcm_updated_at'])})',
            ),
          _CopyRow(label: 'User ID', value: user.id),
        ]),
      ),
      if (profile.businesses.isNotEmpty)
        _Section(
          title: 'Negocio',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: profile.businesses.map((b) {
              return Container(
                margin: const EdgeInsets.only(bottom: BCSpacing.sm),
                padding: const EdgeInsets.all(BCSpacing.sm),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${b['name']}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _miniChip('Tier ${b['tier']}', Colors.indigo),
                        if (b['is_verified'] == true)
                          _miniChip('Verificado', Colors.green),
                        if (b['is_active'] == true)
                          _miniChip('Activo', Colors.blue)
                        else
                          _miniChip('Inactivo', Colors.grey),
                        if (b['stripe_charges_enabled'] == true)
                          _miniChip('Stripe OK', Colors.teal),
                        if (b['pos_enabled'] == true)
                          _miniChip('POS', Colors.orange),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${b['city'] ?? ''} · ${b['total_reviews'] ?? 0} reseñas '
                      '· ★${((b['average_rating'] as num?) ?? 0).toStringAsFixed(1)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
    ]);
  }

  static Widget _providerChip(String provider) {
    final (icon, label, color) = switch (provider) {
      'google' => (Icons.g_mobiledata, 'Google', Colors.red),
      'email' => (Icons.email_outlined, 'Email', Colors.blue),
      'phone' => (Icons.phone, 'Teléfono', Colors.teal),
      'apple' => (Icons.apple, 'Apple', Colors.black87),
      _ => (Icons.key_outlined, provider, Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(BCSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  static Widget _miniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(BCSpacing.radiusFull),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge({required this.verifiedAt});
  final dynamic verifiedAt;

  @override
  Widget build(BuildContext context) {
    final verified = verifiedAt != null && '$verifiedAt'.isNotEmpty;
    return Tooltip(
      message: verified
          ? 'Verificado ${_formatDate(verifiedAt, withTime: false)}'
          : 'No verificado',
      child: Icon(
        verified ? Icons.verified : Icons.warning_amber_rounded,
        size: 16,
        color: verified ? Colors.green : Colors.orange,
      ),
    );
  }
}

// ── Tab 2: Activity ───────────────────────────────────────────────────────────

class _ActivityTab extends StatelessWidget {
  const _ActivityTab({required this.profile});
  final AdminUserFullProfile profile;

  @override
  Widget build(BuildContext context) {
    final appts = profile.appointments;
    final byStatus = (appts['by_status'] as Map?)?.cast<String, dynamic>() ?? const {};
    final recent = (appts['recent'] as List?)?.cast<Map>() ?? const [];
    final next = appts['next_upcoming'] as Map?;
    final orders = profile.orders;
    final orderRecent = (orders['recent'] as List?)?.cast<Map>() ?? const [];
    final reviews = profile.reviews;
    final reviewRecent = (reviews['recent'] as List?)?.cast<Map>() ?? const [];
    final chat = profile.chat;
    final disputes = profile.disputes;
    final invites = profile.invites;
    final media = profile.media;
    final gift = profile.giftCards;

    return _TabScroll(children: [
      _Section(
        title: 'Citas',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _StatChips(stats: [
            (label: 'Total', value: '${appts['total'] ?? 0}'),
            (label: 'Completadas', value: '${byStatus['completed'] ?? 0}'),
            (label: 'Confirmadas', value: '${byStatus['confirmed'] ?? 0}'),
            (label: 'Canceladas', value:
                '${((byStatus['cancelled_customer'] as int?) ?? 0) + ((byStatus['cancelled_business'] as int?) ?? 0)}'),
            (label: 'No-show', value: '${byStatus['no_show'] ?? 0}'),
          ]),
          const SizedBox(height: BCSpacing.sm),
          _KV(
            icon: Icons.attach_money,
            label: 'Gasto acumulado',
            value: _formatMoney(appts['lifetime_spend']),
          ),
          _KV(
            icon: Icons.money_off,
            label: 'Reembolsado',
            value: _formatMoney(appts['lifetime_refunded']),
          ),
          _KV(
            icon: Icons.history,
            label: 'Última reserva',
            value: _formatDate(appts['last_booking_at']),
          ),
          if (next != null)
            Container(
              margin: const EdgeInsets.only(top: BCSpacing.sm),
              padding: const EdgeInsets.all(BCSpacing.sm),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Próxima cita',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          )),
                  Text('${next['service_name']} — ${_formatDate(next['starts_at'])}'),
                ],
              ),
            ),
          if (recent.isNotEmpty) ...[
            const SizedBox(height: BCSpacing.md),
            Text('Últimas ${recent.length}',
                style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            ...recent.map((r) => _ListRow(
                  title: '${r['service_name']} · ${_formatMoney(r['price'])}',
                  subtitle: '${r['business_name'] ?? '—'} · ${_formatDate(r['starts_at'], withTime: false)}',
                  trailing: _statusPill('${r['status']}'),
                )),
          ],
        ]),
      ),
      _Section(
        title: 'Marketplace',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _StatChips(stats: [
            (label: 'Pedidos', value: '${orders['total'] ?? 0}'),
            (label: 'Gasto', value: _formatMoney(orders['lifetime_spend'])),
          ]),
          if (orderRecent.isNotEmpty) ...[
            const SizedBox(height: BCSpacing.sm),
            ...orderRecent.map((o) => _ListRow(
                  title: '${o['product_name']} × ${o['quantity']}',
                  subtitle: '${o['business_name'] ?? '—'} · ${_formatDate(o['created_at'], withTime: false)}',
                  trailing: Text(_formatMoney(o['total_amount']),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          )),
                )),
          ],
        ]),
      ),
      _Section(
        title: 'Reseñas y chats',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _StatChips(stats: [
            (label: 'Reseñas', value: '${reviews['given_total'] ?? 0}'),
            (label: 'Rating avg', value: '${reviews['avg_rating_given'] ?? 0}'),
            (label: 'Chats', value: '${chat['total'] ?? 0}'),
            (label: 'No leídos', value: '${chat['unread_total'] ?? 0}'),
          ]),
          if (reviewRecent.isNotEmpty) ...[
            const SizedBox(height: BCSpacing.sm),
            ...reviewRecent.map((r) => _ListRow(
                  title: '★${r['rating']} · ${_formatDate(r['created_at'], withTime: false)}',
                  subtitle: (r['comment'] as String?)?.isNotEmpty == true
                      ? r['comment'] as String
                      : 'Sin comentario',
                )),
          ],
        ]),
      ),
      _Section(
        title: 'Comunidad',
        child: _StatChips(stats: [
          (label: 'Disputas', value: '${disputes['filed_total'] ?? 0}'),
          (label: 'Invites enviadas',
              value: '${invites['invites_sent'] ?? 0}'),
          (label: 'Invites entregadas',
              value: '${invites['invites_delivered'] ?? 0}'),
          (label: 'Señales interés',
              value: '${invites['interest_signals'] ?? 0}'),
          (label: 'Media subida', value: '${media['uploaded_count'] ?? 0}'),
          (label: 'Regalos canjeados',
              value: '${gift['redeemed_count'] ?? 0}'),
        ]),
      ),
    ]);
  }

  Widget _statusPill(String status) {
    final (color, label) = switch (status) {
      'completed' => (Colors.green, 'completa'),
      'confirmed' => (Colors.blue, 'confirmada'),
      'pending' => (Colors.orange, 'pendiente'),
      'cancelled_customer' => (Colors.grey, 'cancelada'),
      'cancelled_business' => (Colors.grey, 'cancelada'),
      'no_show' => (Colors.red, 'no-show'),
      _ => (Colors.blueGrey, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(BCSpacing.radiusFull),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.title,
    this.subtitle,
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (subtitle != null)
                  Text(subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ── Tab 3: Money ──────────────────────────────────────────────────────────────

class _MoneyTab extends ConsumerWidget {
  const _MoneyTab({required this.profile});
  final AdminUserFullProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = profile.saldo;
    final ledger = (s['recent_ledger'] as List?)?.cast<Map>() ?? const [];
    final loyalty = profile.loyalty;
    final gift = profile.giftCards;

    return _TabScroll(children: [
      _Section(
        title: 'Saldo',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.all(BCSpacing.md),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(BCSpacing.radiusSm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Balance actual',
                    style: Theme.of(context).textTheme.labelMedium),
                Text(_formatMoney(s['current_balance']),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        )),
              ],
            ),
          ),
          const SizedBox(height: BCSpacing.sm),
          _StatChips(stats: [
            (label: 'Créditos acum.', value: _formatMoney(s['lifetime_credits'])),
            (label: 'Débitos acum.', value: _formatMoney(s['lifetime_debits'])),
            (label: 'Movimientos', value: '${s['ledger_count'] ?? 0}'),
          ]),
          if (ledger.isNotEmpty) ...[
            const SizedBox(height: BCSpacing.md),
            Text('Últimos ${ledger.length} movimientos',
                style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            ...ledger.map((l) {
              final amount = (l['amount'] as num?)?.toDouble() ?? 0;
              final positive = amount >= 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      positive
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 14,
                      color: positive ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${l['reason']} · ${_formatDate(l['created_at'])}',
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(_formatMoney(amount),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: positive ? Colors.green : Colors.red,
                            )),
                  ],
                ),
              );
            }),
          ],
        ]),
      ),
      _Section(
        title: 'Lealtad',
        child: _StatChips(stats: [
          (label: 'Puntos', value: '${loyalty['points_balance'] ?? 0}'),
          (label: 'Movimientos',
              value: '${loyalty['transactions'] ?? 0}'),
        ]),
      ),
      _Section(
        title: 'Tarjetas de regalo',
        child: _StatChips(stats: [
          (label: 'Canjeadas', value: '${gift['redeemed_count'] ?? 0}'),
          (label: 'Valor canjeado',
              value: _formatMoney(gift['redeemed_total_value'])),
        ]),
      ),
    ]);
  }
}

// ── Tab 4: Intelligence ───────────────────────────────────────────────────────

class _IntelligenceTab extends StatelessWidget {
  const _IntelligenceTab({required this.profile});
  final AdminUserFullProfile profile;

  @override
  Widget build(BuildContext context) {
    final summary = profile.behaviorSummary;
    final traits = profile.orderedTraits;
    if (traits.isEmpty && summary.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(BCSpacing.lg),
          child: Text('Sin datos de comportamiento todavía.'),
        ),
      );
    }

    return _TabScroll(children: [
      if (summary.isNotEmpty)
        _Section(
          title: 'Resumen 90d',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _StatChips(stats: [
              (label: 'Segmento', value: '${summary['segment'] ?? '—'}'),
              (label: 'Eventos', value: '${summary['total_events'] ?? 0}'),
              (label: 'Días activos (30d)',
                  value: '${summary['active_days_30d'] ?? 0}'),
              (label: 'Días activos (90d)',
                  value: '${summary['active_days_90d'] ?? 0}'),
              (label: 'Whale score',
                  value: '${summary['whale_score'] ?? 0}'),
              (label: 'RP candidato',
                  value: '${summary['rp_candidate_score'] ?? 0}'),
            ]),
            if (summary['primary_city'] != null)
              _KV(
                icon: Icons.location_city_outlined,
                label: 'Ciudad principal',
                value: '${summary['primary_city']}',
              ),
            _KV(
              icon: Icons.timer_outlined,
              label: 'Calculado',
              value: _formatDate(summary['computed_at']),
            ),
          ]),
        ),
      _Section(
        title: 'Traits (0–100)',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: traits.map((e) {
            return Padding(
              padding: const EdgeInsets.only(bottom: BCSpacing.sm),
              child: _TraitBar(trait: e.key, score: e.value),
            );
          }).toList(),
        ),
      ),
    ]);
  }
}

class _TraitBar extends StatelessWidget {
  const _TraitBar({required this.trait, required this.score});
  final String trait;
  final TraitScore score;

  static const Map<String, (String, Color, bool)> _meta = {
    // trait -> (label, color, higher-is-better)
    'churn_risk': ('Riesgo de abandono', Colors.red, false),
    'spend_velocity': ('Velocidad de gasto', Colors.teal, true),
    'consistency': ('Consistencia', Colors.indigo, true),
    'initiative': ('Iniciativa', Colors.deepPurple, true),
    'cancellation_rate': ('Cancelaciones', Colors.orange, false),
    'payment_reliability': ('Confiabilidad pago', Colors.green, true),
    'referral_impact': ('Impacto referral', Colors.pink, true),
    'geographic_spread': ('Distribución geográfica', Colors.blueGrey, true),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = _meta[trait] ?? (trait, Colors.grey, true);
    final pct = (score.score / 100).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(meta.$1,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  )),
            ),
            Text(score.score.toStringAsFixed(0),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: meta.$2,
                )),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: pct,
          minHeight: 6,
          backgroundColor: meta.$2.withValues(alpha: 0.12),
          valueColor: AlwaysStoppedAnimation(meta.$2),
        ),
        Text('raw: ${score.rawValue}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            )),
      ],
    );
  }
}

// ── Tab 5: Security & Actions ─────────────────────────────────────────────────

class _SecurityTab extends StatefulWidget {
  const _SecurityTab({
    required this.user,
    required this.profile,
    required this.onUserUpdated,
  });
  final AdminUser user;
  final AdminUserFullProfile profile;
  final VoidCallback onUserUpdated;

  @override
  State<_SecurityTab> createState() => _SecurityTabState();
}

class _SecurityTabState extends State<_SecurityTab> {
  late String _selectedRole = widget.user.role;
  bool _savingRole = false;
  bool _savingStatus = false;

  Future<void> _updateRole(String newRole) async {
    if (newRole == widget.user.role || _savingRole) return;
    setState(() => _savingRole = true);
    try {
      await BCSupabase.client
          .from(BCTables.profiles)
          .update({'role': newRole}).eq('id', widget.user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rol actualizado a $newRole')),
      );
      widget.onUserUpdated();
    } catch (e) {
      if (!mounted) return;
      setState(() => _selectedRole = widget.user.role);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error),
      );
    } finally {
      if (mounted) setState(() => _savingRole = false);
    }
  }

  Future<void> _toggleStatus() async {
    if (_savingStatus) return;
    setState(() => _savingStatus = true);
    final newStatus = widget.user.isActive ? 'suspended' : 'active';
    try {
      await BCSupabase.client
          .from(BCTables.profiles)
          .update({'status': newStatus}).eq('id', widget.user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.user.isActive
              ? 'Cuenta suspendida'
              : 'Cuenta activada'),
        ),
      );
      widget.onUserUpdated();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error),
      );
    } finally {
      if (mounted) setState(() => _savingStatus = false);
    }
  }

  Future<void> _adjustSaldo() async {
    final controller = TextEditingController();
    final reason = TextEditingController(text: 'admin adjustment');
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajustar saldo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(
                labelText: 'Monto (positivo = crédito, negativo = débito)',
              ),
            ),
            const SizedBox(height: BCSpacing.sm),
            TextField(
              controller: reason,
              decoration: const InputDecoration(labelText: 'Motivo'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(controller.text.replaceAll(',', '.'));
              if (v == null || v == 0) {
                Navigator.of(ctx).pop();
                return;
              }
              Navigator.of(ctx).pop(v);
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
    if (amount == null) return;
    try {
      // Idempotency key: admin + target + exact signed amount + minute-level
      // timestamp. Stops the same Apply click from double-crediting if the
      // button is tapped twice or the dialog is dismissed and reopened within
      // the same minute with the same amount.
      final me = BCSupabase.client.auth.currentUser?.id ?? 'unknown';
      final ts = DateTime.now().toUtc().toIso8601String().substring(0, 16);
      final idemKey = 'admin:$me:${widget.user.id}:${amount.toStringAsFixed(2)}:$ts';
      await BCSupabase.client.rpc('increment_saldo', params: {
        'p_user_id': widget.user.id,
        'p_amount': amount,
        'p_reason': 'admin_adjustment',
        'p_idempotency_key': idemKey,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saldo ajustado por ${_formatMoney(amount)}')),
      );
      widget.onUserUpdated();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin =
        widget.user.role == 'admin' || widget.user.role == 'superadmin';

    return _TabScroll(children: [
      _Section(
        title: 'Rol',
        child: Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _selectedRole,
              isDense: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'customer', child: Text('Cliente')),
                DropdownMenuItem(value: 'stylist', child: Text('Estilista')),
                DropdownMenuItem(value: 'rp', child: Text('RP')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
                DropdownMenuItem(
                    value: 'superadmin', child: Text('Superadmin')),
              ],
              onChanged: _savingRole
                  ? null
                  : (v) {
                      if (v == null) return;
                      setState(() => _selectedRole = v);
                      _updateRole(v);
                    },
            ),
          ),
          if (_savingRole) ...[
            const SizedBox(width: 8),
            const SizedBox(
                width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ]),
      ),
      _Section(
        title: 'Estado',
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _savingStatus ? null : _toggleStatus,
            icon: _savingStatus
                ? const SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(widget.user.isActive
                    ? Icons.block
                    : Icons.check_circle_outline),
            label: Text(
                widget.user.isActive ? 'Suspender cuenta' : 'Activar cuenta'),
            style: OutlinedButton.styleFrom(
              foregroundColor: widget.user.isActive
                  ? Theme.of(context).colorScheme.error
                  : Colors.green,
            ),
          ),
        ),
      ),
      _Section(
        title: 'Saldo',
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.swap_vert),
            label: const Text('Ajustar saldo'),
            onPressed: _adjustSaldo,
          ),
        ),
      ),
      if (!isAdmin)
        _Section(
          title: 'Eliminación',
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: Icon(Icons.delete_forever,
                  color: Theme.of(context).colorScheme.error),
              label: Text(
                'Eliminar usuario',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error),
              ),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('¿Eliminar usuario?'),
                    content: Text(
                        'Esto borrará permanentemente a ${widget.user.username}. No se puede deshacer.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancelar')),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: FilledButton.styleFrom(
                            backgroundColor:
                                Theme.of(ctx).colorScheme.error),
                        child: const Text('Eliminar'),
                      ),
                    ],
                  ),
                );
                if (confirm != true) return;
                try {
                  await BCSupabase.client.rpc('admin_delete_user',
                      params: {'p_user_id': widget.user.id});
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Usuario eliminado')),
                  );
                  widget.onUserUpdated();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor:
                            Theme.of(context).colorScheme.error),
                  );
                }
              },
            ),
          ),
        ),
    ]);
  }
}

// ── Tab 6: Notes ──────────────────────────────────────────────────────────────

class _NotesTab extends ConsumerStatefulWidget {
  const _NotesTab({
    required this.user,
    required this.profile,
    required this.onUpdated,
  });
  final AdminUser user;
  final AdminUserFullProfile profile;
  final VoidCallback onUpdated;

  @override
  ConsumerState<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends ConsumerState<_NotesTab> {
  final _noteCtl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _noteCtl.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    final text = _noteCtl.text.trim();
    if (text.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await BCSupabase.client.from('admin_notes').insert({
        'target_type': 'user',
        'target_id': widget.user.id,
        'note': text,
        'created_by': BCSupabase.client.auth.currentUser?.id,
      });
      if (!mounted) return;
      _noteCtl.clear();
      widget.onUpdated();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notes = widget.profile.adminNotes;

    return _TabScroll(children: [
      _Section(
        title: 'Nueva nota',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(
            controller: _noteCtl,
            maxLines: 3,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Anota algo sobre este usuario…',
            ),
          ),
          const SizedBox(height: BCSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              icon: _saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save, size: 16),
              label: const Text('Guardar'),
              onPressed: _saving ? null : _saveNote,
            ),
          ),
        ]),
      ),
      if (notes.isNotEmpty)
        _Section(
          title: 'Notas anteriores (${notes.length})',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: notes.map((n) => Container(
                  margin: const EdgeInsets.only(bottom: BCSpacing.sm),
                  padding: const EdgeInsets.all(BCSpacing.sm),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${n['note']}',
                          style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 4),
                      Text(
                        '${n['created_by_username'] ?? 'admin'} · ${_formatDate(n['created_at'])}',
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.5),
                                ),
                      ),
                    ],
                  ),
                )).toList(),
          ),
        ),
    ]);
  }
}

// ── Error ────────────────────────────────────────────────────────────────────

class _ErrorSection extends StatelessWidget {
  const _ErrorSection({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BCSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 40,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(height: BCSpacing.sm),
            Text('No se pudo cargar el perfil',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: BCSpacing.xs),
            SelectableText(
              '$error',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: BCSpacing.md),
            FilledButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reintentar'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
