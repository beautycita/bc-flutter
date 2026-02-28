import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/constants.dart';
import '../../providers/admin_provider.dart';
import '../../services/supabase_client.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  String _search = '';
  String? _roleFilter;
  String? _statusFilter = 'active'; // default to active users only

  static const _roles = ['customer', 'stylist', 'admin', 'superadmin'];
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

  /// Avatar accent color per role (used for initials).
  Color _roleColor(String role) {
    switch (role) {
      case 'superadmin':
        return Colors.red;
      case 'admin':
        return Colors.deepPurple;
      case 'stylist':
        return Colors.teal;
      default:
        return Colors.blueGrey;
    }
  }

  /// Chip background tint per role.
  Color _chipBgColor(String role) {
    switch (role) {
      case 'superadmin':
        return const Color(0xFF424242); // dark gray
      case 'admin':
        return const Color(0xFFFCE4EC); // light pink
      case 'stylist':
        return const Color(0xFFE8F5E9); // light green
      default:
        return const Color(0xFFE3F2FD); // light blue (customer)
    }
  }

  /// Chip text color per role.
  Color _chipTextColor(String role) {
    switch (role) {
      case 'superadmin':
        return Colors.white;
      case 'admin':
        return const Color(0xFFC62828);
      case 'stylist':
        return const Color(0xFF2E7D32);
      default:
        return const Color(0xFF1565C0);
    }
  }

  /// Status color for edit sheet chips.
  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'suspended':
        return Colors.orange;
      case 'archived':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  /// Chip stroke color per account status (list view).
  Color _statusStrokeColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'suspended':
        return Colors.red;
      case 'archived':
        return Colors.grey;
      default:
        return Colors.blueGrey;
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
            color: selected ? Colors.white : colors.onSurface.withValues(alpha: 0.6),
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
                    color: Colors.white,
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
                  color: Colors.white,
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
                        color: Colors.white,
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
                                  color: Colors.black.withValues(alpha: 0.04),
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
                                        (user.fullName ?? user.username)
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
                                              ? Colors.green
                                              : Colors.grey.shade400,
                                          border: Border.all(
                                            color: Colors.white,
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
                                        '@${user.username}',
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

    showModalBottomSheet(
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
              color: Colors.white,
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
                        color: Colors.grey[300],
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
                              (user.fullName ?? user.username)
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
                                    ? Colors.green
                                    : Colors.grey.shade400,
                                border:
                                    Border.all(color: Colors.white, width: 2),
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
                              user.fullName ?? user.username,
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: colors.onSurface,
                              ),
                            ),
                            Text(
                              '@${user.username}',
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
                    _DetailRow(
                      icon: Icons.local_taxi_rounded,
                      label: 'Uber',
                      value: user.uberLinked ? 'Vinculado' : 'No vinculado',
                      iconColor: dimIcon,
                      valueColor: user.uberLinked ? Colors.green : dim,
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
                        error: (_, __) => const SizedBox.shrink(),
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
                            foregroundColor: Colors.white,
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
                ],
              ),
            ),
          );
        },
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Solo un superadmin puede cambiar el rol de otro superadmin')),
          );
        }
        return;
      }
      if (!isMeSuperAdmin && newRole == 'superadmin') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Solo un superadmin puede asignar el rol de superadmin')),
          );
        }
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

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Usuario eliminado (sin telefono verificado)')),
          );
        }
        return;
      }

      // Normal update (role change, status change, or archive verified user)
      final updates = <String, dynamic>{};
      if (newRole != user.role) updates['role'] = newRole;
      if (newStatus != user.status) updates['status'] = newStatus;

      if (updates.isNotEmpty) {
        await SupabaseClientService.client
            .from('profiles')
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario actualizado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
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
