import 'package:flutter/foundation.dart';
import 'package:beautycita/config/app_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/config/fonts.dart';
import 'package:intl/intl.dart';
import '../../config/constants.dart';
import '../../config/theme_extension.dart';
import '../../models/chat_message.dart';
import '../../providers/admin_provider.dart';
import '../../providers/chat_provider.dart';
import 'package:beautycita_core/supabase.dart';
import '../../services/supabase_client.dart';
import '../../services/toast_service.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  String _search = '';
  String? _roleFilter;
  String? _statusFilter = 'active'; // default to active users only

  static const _roles = ['customer', 'stylist', 'admin', 'superadmin', 'rp'];
  static const _statuses = ['active', 'suspended', 'archived'];

  List<AdminUser> _filtered(List<AdminUser> users) {
    var list = users;
    if (_statusFilter != null) {
      list = list.where((u) => u.status == _statusFilter).toList();
    }
    if (_roleFilter != null) {
      list = list.where((u) => u.role == _roleFilter).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where((u) =>
              (u.fullName?.toLowerCase().contains(q) ?? false) ||
              u.username.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  /// Avatar accent color per role (using theme colors).
  Color _roleColor(String role) {
    final colors = Theme.of(context).colorScheme;
    switch (role) {
      case 'superadmin':
        return colors.error;
      case 'admin':
        return colors.secondary;
      case 'stylist':
        return colors.primary;
      default:
        return colors.onSurface.withValues(alpha: 0.5);
    }
  }

  /// Chip background tint per role.
  Color _chipBgColor(String role) {
    final colors = Theme.of(context).colorScheme;
    switch (role) {
      case 'superadmin':
        return colors.onSurface.withValues(alpha: 0.15);
      case 'admin':
        return colors.error.withValues(alpha: 0.08);
      case 'stylist':
        return colors.primary.withValues(alpha: 0.08);
      default:
        return colors.secondary.withValues(alpha: 0.08);
    }
  }

  /// Chip text color per role.
  Color _chipTextColor(String role) {
    final colors = Theme.of(context).colorScheme;
    switch (role) {
      case 'superadmin':
        return colors.onPrimary;
      case 'admin':
        return colors.error;
      case 'stylist':
        return colors.primary;
      default:
        return colors.secondary;
    }
  }

  /// Status color for edit sheet chips.
  Color _statusColor(String status) {
    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    final colors = Theme.of(context).colorScheme;
    switch (status) {
      case 'active':
        return ext.successColor;
      case 'suspended':
        return ext.warningColor;
      case 'archived':
        return colors.onSurface.withValues(alpha: 0.4);
      default:
        return colors.onSurface.withValues(alpha: 0.4);
    }
  }

  /// Chip stroke color per account status (list view).
  Color _statusStrokeColor(String status) {
    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    final colors = Theme.of(context).colorScheme;
    switch (status) {
      case 'active':
        return ext.successColor;
      case 'suspended':
        return colors.error;
      case 'archived':
        return colors.onSurface.withValues(alpha: 0.4);
      default:
        return colors.onSurface.withValues(alpha: 0.4);
    }
  }

  String _sourceLabel(String? source) {
    switch (source) {
      case 'apk':
        return 'APK (Android)';
      case 'web':
        return '.com (Web)';
      case 'pwa':
        return 'PWA';
      case 'ipa':
        return 'IPA (iOS)';
      case 'exe':
        return 'EXE (Windows)';
      default:
        return source ?? 'Desconocido';
    }
  }

  Widget _statusChip(String? value, String label, ColorScheme colors) {
    final selected = _statusFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _statusFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? colors.primary : colors.onSurface.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersProvider);
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Search + filter bar
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.paddingMD,
            AppConstants.paddingMD,
            AppConstants.paddingMD,
            AppConstants.paddingSM,
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                    border: Border.all(
                      color: colors.onSurface.withValues(alpha: 0.15),
                      width: 1,
                    ),
                    color: Theme.of(context).colorScheme.surface,
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'Buscar usuario...',
                      hintStyle: GoogleFonts.nunito(fontSize: 14),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      border: InputBorder.none,
                    ),
                    style: GoogleFonts.nunito(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppConstants.radiusSM),
                  border: Border.all(
                    color: colors.onSurface.withValues(alpha: 0.15),
                    width: 1,
                  ),
                  color: Theme.of(context).colorScheme.surface,
                ),
                child: PopupMenuButton<String?>(
                  icon: Icon(Icons.filter_list,
                      color: _roleFilter != null
                          ? colors.primary
                          : colors.onSurface.withValues(alpha: 0.5)),
                  onSelected: (v) => setState(() => _roleFilter = v),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: null, child: Text('Todos')),
                    for (final r in _roles)
                      PopupMenuItem(value: r, child: Text(r)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Status filter chips
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingMD,
          ),
          child: Row(
            children: [
              _statusChip(null, 'Todos', colors),
              const SizedBox(width: 6),
              _statusChip('active', 'Activos', colors),
              const SizedBox(width: 6),
              _statusChip('suspended', 'Suspendidos', colors),
              const SizedBox(width: 6),
              _statusChip('archived', 'Archivados', colors),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.paddingSM),

        // User list
        Expanded(
          child: usersAsync.when(
            data: (users) {
              final filtered = _filtered(users);
              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    'Sin resultados',
                    style: GoogleFonts.nunito(
                        color: colors.onSurface.withValues(alpha: 0.5)),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(adminUsersProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.paddingMD),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final user = filtered[i];
                    final rc = _roleColor(user.role);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppConstants.paddingSM),
                      child: Material(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                          onTap: () => _showEditSheet(user),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                              border: Border.all(
                                color: colors.onSurface.withValues(alpha: 0.12),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).shadowColor.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(AppConstants.paddingSM),
                            child: Row(
                              children: [
                                // Avatar with online indicator
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: rc.withValues(alpha: 0.1),
                                      child: Text(
                                        user.displayName
                                            .substring(0, 1)
                                            .toUpperCase(),
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          color: rc,
                                        ),
                                      ),
                                    ),
                                    // Online/offline dot
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: user.isOnline
                                              ? Theme.of(context).extension<BCThemeExtension>()!.successColor
                                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                                          border: Border.all(
                                            color: Theme.of(context).colorScheme.surface,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '@${user.displayName}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: user.status == 'archived'
                                              ? colors.onSurface.withValues(alpha: 0.4)
                                              : colors.onSurface,
                                        ),
                                      ),
                                      if (user.fullName != null && user.fullName!.isNotEmpty)
                                        Text(
                                          user.fullName!,
                                          style: GoogleFonts.nunito(
                                            fontSize: 12,
                                            color: colors.onSurface.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      if (user.createdAt != null)
                                        Text(
                                          _formatLocalDate(user.createdAt!),
                                          style: GoogleFonts.nunito(
                                            fontSize: 11,
                                            color: colors.onSurface.withValues(alpha: 0.4),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // Role chip — bg tinted by role, stroke by status
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _chipBgColor(user.role),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _statusStrokeColor(user.status),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    user.role,
                                    style: GoogleFonts.nunito(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _chipTextColor(user.role),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text('Error: $e',
                  style: GoogleFonts.nunito(color: colors.error)),
            ),
          ),
        ),
      ],
    );
  }

  void _showEditSheet(AdminUser user) {
    String selectedRole = user.role;
    String selectedStatus = user.status;
    final colors = Theme.of(context).colorScheme;
    final dim = colors.onSurface.withValues(alpha: 0.5);
    final dimIcon = colors.onSurface.withValues(alpha: 0.35);
    final isSelf = user.id == SupabaseClientService.currentUserId;
    final isMeSuperAdmin =
        ref.read(isSuperAdminProvider).valueOrNull ?? false;
    final targetIsSuperAdmin = user.role == 'superadmin';

    showBurstBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            margin: const EdgeInsets.all(16),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // User info header with online indicator
                  Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor:
                                _roleColor(user.role).withValues(alpha: 0.1),
                            child: Text(
                              user.displayName
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: _roleColor(user.role),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: user.isOnline
                                    ? Theme.of(context).extension<BCThemeExtension>()!.successColor
                                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                                border:
                                    Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName ?? user.displayName,
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: colors.onSurface,
                              ),
                            ),
                            Text(
                              '@${user.displayName}',
                              style: GoogleFonts.nunito(
                                  fontSize: 14, color: dim),
                            ),
                            Text(
                              user.isOnline
                                  ? 'En linea'
                                  : 'Visto: ${user.lastSeenText}',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: user.isOnline
                                    ? Colors.green
                                    : colors.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Live support button — only for online non-admin users
                  if (user.isOnline &&
                      user.role != 'admin' &&
                      user.role != 'superadmin') ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop(); // close edit sheet
                          _openLiveSupportChat(user);
                        },
                        icon: const Icon(Icons.support_agent_rounded, size: 20),
                        label: Text(
                          'Soporte en Vivo',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Profile details
                  _DetailSection(children: [
                    _DetailRow(
                      icon: Icons.fingerprint_rounded,
                      label: 'ID',
                      value: user.id.substring(0, 8),
                      iconColor: dimIcon,
                      valueColor: dim,
                    ),
                    _DetailRow(
                      icon: Icons.install_mobile_rounded,
                      label: 'Registro via',
                      value: _sourceLabel(user.registrationSource),
                      iconColor: dimIcon,
                      valueColor: dim,
                    ),
                    if (user.phone != null)
                      _DetailRow(
                        icon: Icons.phone_rounded,
                        label: 'Telefono',
                        value: user.phone!,
                        iconColor: dimIcon,
                        valueColor: colors.onSurface.withValues(alpha: 0.7),
                      ),
                    if (user.gender != null)
                      _DetailRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Genero',
                        value: user.gender!,
                        iconColor: dimIcon,
                        valueColor: dim,
                      ),
                    if (user.birthday != null)
                      _DetailRow(
                        icon: Icons.cake_rounded,
                        label: 'Cumpleanos',
                        value: user.birthday!,
                        iconColor: dimIcon,
                        valueColor: dim,
                      ),
                    if (user.homeAddress != null)
                      _DetailRow(
                        icon: Icons.home_rounded,
                        label: 'Direccion',
                        value: user.homeAddress!,
                        iconColor: dimIcon,
                        valueColor: dim,
                      ),
                    _DetailRow(
                      icon: Icons.calendar_today_rounded,
                      label: 'Registro',
                      value: user.createdAt != null ? _formatLocalDate(user.createdAt!) : '-',
                      iconColor: dimIcon,
                      valueColor: dim,
                    ),
                    if (user.updatedAt != null)
                      _DetailRow(
                        icon: Icons.update_rounded,
                        label: 'Actualizado',
                        value: _formatLocalDate(user.updatedAt!),
                        iconColor: dimIcon,
                        valueColor: dim,
                      ),
                  ]),

                  const SizedBox(height: 12),

                  // Saldo section
                  _DetailSection(children: [
                    GestureDetector(
                      onTap: () => _showSaldoEditDialog(ctx, user, setSheetState),
                      child: Row(
                        children: [
                          Icon(Icons.account_balance_wallet_rounded,
                              size: 16, color: Colors.amber.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Saldo',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '\$${user.saldo.toStringAsFixed(2)}',
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: user.saldo > 0
                                  ? Colors.green.shade700
                                  : colors.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.edit_rounded,
                              size: 14,
                              color: colors.primary.withValues(alpha: 0.6)),
                        ],
                      ),
                    ),
                  ]),

                  const SizedBox(height: 12),

                  // Auth / login methods section
                  Consumer(
                    builder: (ctx, ref, _) {
                      final authAsync =
                          ref.watch(adminUserAuthInfoProvider(user.id));
                      return authAsync.when(
                        data: (auth) {
                          if (auth.isEmpty) return const SizedBox.shrink();
                          final providers =
                              (auth['providers'] as List?)?.cast<String>() ??
                                  [];
                          final email = auth['email'] as String?;
                          final phone = auth['phone'] as String?;
                          final emailConfirmed =
                              auth['email_confirmed'] as bool? ?? false;
                          final phoneConfirmed =
                              auth['phone_confirmed'] as bool? ?? false;
                          final hasPassword =
                              auth['has_password'] as bool? ?? false;
                          final isAnonymous =
                              auth['is_anonymous'] as bool? ?? false;

                          return _DetailSection(children: [
                            _DetailRow(
                              icon: Icons.login_rounded,
                              label: 'Providers',
                              value: providers.isEmpty
                                  ? (isAnonymous ? 'anonimo' : '-')
                                  : providers.join(', '),
                              iconColor: dimIcon,
                              valueColor: dim,
                            ),
                            if (email != null && email.isNotEmpty)
                              _DetailRow(
                                icon: Icons.email_rounded,
                                label: 'Email',
                                value: email,
                                iconColor: dimIcon,
                                valueColor: colors.onSurface
                                    .withValues(alpha: 0.7),
                              ),
                            _DetailRow(
                              icon: Icons.verified_rounded,
                              label: 'Email verificado',
                              value: emailConfirmed ? 'Si' : 'No',
                              iconColor: dimIcon,
                              valueColor:
                                  emailConfirmed ? Colors.green : dim,
                            ),
                            if (phone != null && phone.isNotEmpty)
                              _DetailRow(
                                icon: Icons.sms_rounded,
                                label: 'Tel. auth',
                                value: phone,
                                iconColor: dimIcon,
                                valueColor: colors.onSurface
                                    .withValues(alpha: 0.7),
                              ),
                            _DetailRow(
                              icon: Icons.phone_android_rounded,
                              label: 'Tel. verificado',
                              value: phoneConfirmed ? 'Si' : 'No',
                              iconColor: dimIcon,
                              valueColor:
                                  phoneConfirmed ? Colors.green : dim,
                            ),
                            _DetailRow(
                              icon: Icons.lock_rounded,
                              label: 'Password',
                              value: hasPassword ? 'Si' : 'No',
                              iconColor: dimIcon,
                              valueColor: hasPassword ? Colors.green : dim,
                            ),
                            _DetailRow(
                              icon: Icons.fingerprint_rounded,
                              label: 'Biometrico',
                              value: isAnonymous ? 'Si (anonimo)' : 'No',
                              iconColor: dimIcon,
                              valueColor: dim,
                            ),
                          ]);
                        },
                        loading: () => Padding(
                          padding: const EdgeInsets.all(12),
                          child: Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ),
                        error: (e, _) => Padding(
                          padding: const EdgeInsets.all(12),
                          child: Center(child: Text('Error al cargar', style: TextStyle(color: Colors.red.shade400, fontSize: 13))),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 20),

                  // Role selector
                  Text(
                    'Rol',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (isSelf)
                    Text(
                      'No puedes cambiar tu propio rol',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: colors.onSurface.withValues(alpha: 0.4),
                      ),
                    )
                  else if (!isMeSuperAdmin && targetIsSuperAdmin)
                    Text(
                      'Solo un superadmin puede cambiar el rol de otro superadmin',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: colors.onSurface.withValues(alpha: 0.4),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      children: _roles
                          .where((r) => isMeSuperAdmin || r != 'superadmin')
                          .map((r) {
                        final isSelected = selectedRole == r;
                        final rc = _roleColor(r);
                        return ChoiceChip(
                          label: Text(r),
                          selected: isSelected,
                          onSelected: (_) =>
                              setSheetState(() => selectedRole = r),
                          selectedColor: rc.withValues(alpha: 0.2),
                          backgroundColor: Colors.grey[100],
                          labelStyle: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? rc
                                : colors.onSurface.withValues(alpha: 0.7),
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? rc.withValues(alpha: 0.5)
                                : Colors.transparent,
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 20),

                  // Status selector
                  Text(
                    'Estatus',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _statuses.map((s) {
                      final isSelected = selectedStatus == s;
                      final sc = _statusColor(s);
                      final label = s == 'active'
                          ? 'Activo'
                          : s == 'suspended'
                              ? 'Suspendido'
                              : 'Archivado';
                      return ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        onSelected: (_) =>
                            setSheetState(() => selectedStatus = s),
                        selectedColor: sc.withValues(alpha: 0.2),
                        backgroundColor: Colors.grey[100],
                        labelStyle: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? sc
                              : colors.onSurface.withValues(alpha: 0.7),
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? sc.withValues(alpha: 0.5)
                              : Colors.transparent,
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text('Cancelar',
                              style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: (selectedRole != user.role ||
                                  selectedStatus != user.status)
                              ? () => _saveUser(
                                  ctx, user, selectedRole, selectedStatus)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            disabledBackgroundColor: Colors.grey[200],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text('Guardar',
                              style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),

                  // Archive shortcut if not already archived
                  if (selectedStatus != 'archived') ...[
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton.icon(
                        onPressed: () =>
                            setSheetState(() => selectedStatus = 'archived'),
                        icon: Icon(
                          user.phoneVerified
                              ? Icons.archive_outlined
                              : Icons.delete_outline_rounded,
                          size: 18,
                          color: user.phoneVerified
                              ? Colors.grey[600]
                              : Colors.red[400],
                        ),
                        label: Text(
                          user.phoneVerified
                              ? 'Archivar usuario'
                              : 'Eliminar usuario (sin tel. verificado)',
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            color: user.phoneVerified
                                ? Colors.grey[600]
                                : Colors.red[400],
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Permanent delete — SUPERADMIN ONLY
                  Consumer(
                    builder: (context, ref, _) {
                      final isSuperAdmin = ref.watch(isSuperAdminProvider).valueOrNull ?? false;
                      if (!isSuperAdmin) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Center(
                          child: TextButton.icon(
                            onPressed: () => _confirmPermanentDelete(context, user),
                            icon: const Icon(Icons.delete_forever_rounded, size: 18, color: Colors.red),
                            label: Text(
                              'Eliminar Permanentemente',
                              style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.red),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmPermanentDelete(BuildContext ctx, AdminUser user) async {
    // First confirmation
    final first = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            Text('Eliminar Permanentemente', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          'Vas a eliminar permanentemente a "${user.username}" (${user.fullName ?? 'Sin nombre'}).\n\n'
          'Esto eliminara su cuenta, perfil, y todos los datos asociados. '
          'Esta accion NO se puede deshacer.',
          style: GoogleFonts.nunito(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Theme.of(context).colorScheme.onPrimary),
            child: const Text('Si, eliminar'),
          ),
        ],
      ),
    );
    if (first != true) return;
    // The outer context can be unmounted after the first dialog awaits
    // (e.g. the admin list rebuilt under us). Bail rather than passing a
    // dead BuildContext to the second showDialog.
    if (!ctx.mounted) return;

    // Second confirmation — type username
    final confirmCtrl = TextEditingController();
    final second = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Confirmar Eliminacion', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Escribe "${user.username}" para confirmar:', style: GoogleFonts.nunito(fontSize: 14)),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                hintText: user.username,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (confirmCtrl.text.trim() == user.username) {
                Navigator.pop(c, true);
              } else {
                ToastService.showWarning('El nombre de usuario no coincide');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Theme.of(context).colorScheme.onPrimary),
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );
    confirmCtrl.dispose();
    if (second != true) return;

    // Show loading indicator
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await SupabaseClientService.client
          .rpc('admin_delete_user', params: {'p_user_id': user.id});

      await adminLogAction(
        action: 'permanent_delete_user',
        targetType: 'user',
        targetId: user.id,
        details: {
          'username': user.username,
          'full_name': user.fullName,
          'role': user.role,
          'reason': 'superadmin_permanent_delete',
        },
      );

      ref.invalidate(adminUsersProvider);
      if (mounted) {
        Navigator.of(context).pop(); // Close loading
        Navigator.of(context).pop(); // Close the detail sheet
      }
      ToastService.showSuccess('Usuario eliminado permanentemente');
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // Close loading
      ToastService.showErrorWithDetails('Error al eliminar', e, StackTrace.current);
    }
  }

  Future<void> _showSaldoEditDialog(
    BuildContext sheetCtx,
    AdminUser user,
    StateSetter setSheetState,
  ) async {
    final controller = TextEditingController(
      text: user.saldo.toStringAsFixed(2),
    );
    final colors = Theme.of(context).colorScheme;

    final newValue = await showDialog<double>(
      context: sheetCtx,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Editar Saldo',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '@${user.displayName}',
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Saldo (MXN)',
                prefixText: '\$ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                isDense: true,
              ),
              style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancelar', style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.replaceAll(',', '.'));
              if (parsed == null) {
                ToastService.showWarning('Ingresa un numero valido');
                return;
              }
              Navigator.of(ctx).pop(parsed);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Guardar', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (newValue == null) return;

    try {
      await SupabaseClientService.client
          .from(BCTables.profiles)
          .update({'saldo': newValue})
          .eq('id', user.id);

      await adminLogAction(
        action: 'update_saldo',
        targetType: 'user',
        targetId: user.id,
        details: {
          'old_saldo': user.saldo,
          'new_saldo': newValue,
          'username': user.username,
        },
      );

      ref.invalidate(adminUsersProvider);

      // Close the bottom sheet and show success
      if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
      ToastService.showSuccess(
        'Saldo de @${user.displayName} actualizado: \$${newValue.toStringAsFixed(2)}',
      );
    } catch (e, stack) {
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
    }
  }

  void _openLiveSupportChat(AdminUser user) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _LiveSupportSheet(user: user),
      ),
    );
  }

  Future<void> _saveUser(
    BuildContext ctx,
    AdminUser user,
    String newRole,
    String newStatus,
  ) async {
    Navigator.of(ctx).pop();

    try {
      // Block non-superadmin from changing superadmin roles
      final isMeSuperAdmin =
          ref.read(isSuperAdminProvider).valueOrNull ?? false;
      if (!isMeSuperAdmin && user.role == 'superadmin' && newRole != user.role) {
        ToastService.showWarning('Solo un superadmin puede cambiar el rol de otro superadmin');
        return;
      }
      if (!isMeSuperAdmin && newRole == 'superadmin') {
        ToastService.showWarning('Solo un superadmin puede asignar el rol de superadmin');
        return;
      }

      // Archiving a user who never verified phone → delete completely
      if (newStatus == 'archived' && !user.phoneVerified) {
        await SupabaseClientService.client
            .rpc('admin_delete_user', params: {'p_user_id': user.id});

        await adminLogAction(
          action: 'delete_user',
          targetType: 'user',
          targetId: user.id,
          details: {
            'reason': 'archived_unverified_phone',
            'username': user.username,
            'phone': user.phone,
          },
        );

        ref.invalidate(adminUsersProvider);
        ToastService.showSuccess('Usuario eliminado (sin telefono verificado)');
        return;
      }

      // Normal update (role change, status change, or archive verified user)
      final updates = <String, dynamic>{};
      if (newRole != user.role) updates['role'] = newRole;
      if (newStatus != user.status) updates['status'] = newStatus;

      if (updates.isNotEmpty) {
        await SupabaseClientService.client
            .from(BCTables.profiles)
            .update(updates)
            .eq('id', user.id);

        await adminLogAction(
          action: 'update_user',
          targetType: 'user',
          targetId: user.id,
          details: {
            if (newRole != user.role) ...{
              'old_role': user.role,
              'new_role': newRole,
            },
            if (newStatus != user.status) ...{
              'old_status': user.status,
              'new_status': newStatus,
            },
          },
        );
      }

      ref.invalidate(adminUsersProvider);
      ToastService.showSuccess('Usuario actualizado');
    } catch (e, stack) {
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
    }
  }
}

// ---------------------------------------------------------------------------
// Helper widgets for the edit sheet
// ---------------------------------------------------------------------------

class _DetailSection extends StatelessWidget {
  final List<Widget> children;
  const _DetailSection({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(height: 16, color: Colors.grey.shade200),
          ],
        ],
      ),
    );
  }
}

String _formatLocalDate(String iso) {
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return iso.split('T')[0];
  return '${dt.day}/${dt.month}/${dt.year}';
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final Color valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: valueColor,
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Live Support Chat — Full-screen modal for admin → user messaging
// ---------------------------------------------------------------------------

class _LiveSupportSheet extends ConsumerStatefulWidget {
  final AdminUser user;
  const _LiveSupportSheet({required this.user});

  @override
  ConsumerState<_LiveSupportSheet> createState() => _LiveSupportSheetState();
}

class _LiveSupportSheetState extends ConsumerState<_LiveSupportSheet> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  String? _threadId;
  bool _loadingThread = true;
  String? _threadError;

  @override
  void initState() {
    super.initState();
    _resolveThread();
  }

  Future<void> _resolveThread() async {
    try {
      final id = await ref.read(
        adminSupportThreadProvider(widget.user.id).future,
      );
      if (mounted) {
        setState(() {
          _threadId = id;
          _loadingThread = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _threadError = e.toString();
          _loadingThread = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending || _threadId == null) return;
    _textController.clear();
    setState(() => _isSending = true);

    try {
      final client = SupabaseClientService.client;

      // Insert message as support (sender_id null = anonymous admin)
      await client.from(BCTables.chatMessages).insert({
        'thread_id': _threadId,
        'sender_type': 'support',
        'sender_id': null,
        'content_type': 'text',
        'text_content': text,
      });

      // Update thread last message + increment unread
      await Future.wait([
        client.from(BCTables.chatThreads).update({
          'last_message_text': text,
          'last_message_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', _threadId!),
        client.rpc('increment_unread', params: {'p_thread_id': _threadId}),
      ]);

      // Push notification to user
      try {
        await client.functions.invoke('send-push-notification', body: {
          'user_id': widget.user.id,
          'notification_type': 'booking_confirmed',
          'custom_title': 'Soporte en Vivo',
          'custom_body': text.length > 80 ? '${text.substring(0, 80)}...' : text,
          'data': {'route': '/chat', 'type': 'support_message'},
        });
      } catch (e) {
        if (kDebugMode) debugPrint('[Users] Push notification failed (best-effort): $e');
      }
    } catch (e, stack) {
      ToastService.showErrorWithDetails(
        ToastService.friendlyError(e), e, stack,
      );
    }

    if (mounted) {
      setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF0ECE5),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.error,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.15),
              ),
              child: Center(
                child: Text(
                  widget.user.displayName.substring(0, 1).toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.surface,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.user.displayName,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.surface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.greenAccent,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Soporte en Vivo',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _loadingThread
          ? const Center(child: CircularProgressIndicator())
          : _threadError != null
              ? Center(
                  child: Text(
                    'Error: $_threadError',
                    style: GoogleFonts.nunito(color: colors.error),
                  ),
                )
              : Column(
                  children: [
                    // Messages
                    Expanded(
                      child: Consumer(
                        builder: (context, ref, _) {
                          final messagesAsync = ref.watch(
                            chatMessagesProvider(_threadId!),
                          );
                          return messagesAsync.when(
                            data: (messages) {
                              WidgetsBinding.instance.addPostFrameCallback(
                                (_) => _scrollToBottom(),
                              );
                              if (messages.isEmpty) {
                                return Center(
                                  child: Text(
                                    'Inicia la conversacion',
                                    style: GoogleFonts.nunito(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                );
                              }
                              return ListView.builder(
                                controller: _scrollController,
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                                itemCount: messages.length,
                                itemBuilder: (context, i) {
                                  final msg = messages[i];
                                  return _SupportBubble(message: msg);
                                },
                              );
                            },
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (e, _) => Center(
                              child: Text('Error: $e'),
                            ),
                          );
                        },
                      ),
                    ),
                    // Input bar
                    Container(
                      padding: EdgeInsets.only(
                        left: 12,
                        right: 12,
                        top: 8,
                        bottom: MediaQuery.of(context).padding.bottom + 8,
                      ),
                      color: Theme.of(context).colorScheme.surface,
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F3FF),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: TextField(
                                controller: _textController,
                                enabled: !_isSending,
                                maxLines: 4,
                                minLines: 1,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                style: GoogleFonts.nunito(fontSize: 15),
                                decoration: InputDecoration(
                                  hintText: 'Escribe un mensaje...',
                                  hintStyle: GoogleFonts.nunito(
                                    fontSize: 15,
                                    color: Colors.grey[400],
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                ),
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _isSending ? null : _sendMessage,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _isSending
                                    ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15)
                                    : Theme.of(context).colorScheme.error,
                                shape: BoxShape.circle,
                              ),
                              child: _isSending
                                  ? Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colors.primary,
                                      ),
                                    )
                                  : Icon(
                                      Icons.send_rounded,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      size: 20,
                                    ),
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

/// Chat bubble for admin live support — user on left, support on right.
class _SupportBubble extends StatelessWidget {
  final ChatMessage message;
  const _SupportBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isSupport = message.isFromSupport;
    final isSystem = message.senderType == 'system';

    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              message.textContent ?? '',
              style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final alignment =
        isSupport ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = isSupport ? const Color(0xFFDCF8C6) : Theme.of(context).colorScheme.surface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(isSupport ? 12 : 2),
                bottomRight: Radius.circular(isSupport ? 2 : 12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  message.textContent ?? '',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: const Color(0xFF303030),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat.Hm().format(message.createdAt.toLocal()),
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    color: Colors.grey[500],
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
