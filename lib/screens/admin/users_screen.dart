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

  static const _roles = ['customer', 'stylist', 'admin', 'superadmin'];
  static const _statuses = ['active', 'suspended', 'archived'];

  List<AdminUser> _filtered(List<AdminUser> users) {
    var list = users;
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
                    final sc = _statusColor(user.status);

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
                            ),
                            padding: const EdgeInsets.all(AppConstants.paddingSM),
                            child: Row(
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
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.fullName ?? user.username,
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: user.status == 'archived'
                                              ? colors.onSurface.withValues(alpha: 0.4)
                                              : colors.onSurface,
                                        ),
                                      ),
                                      Text(
                                        '@${user.username}',
                                        style: GoogleFonts.nunito(
                                          fontSize: 12,
                                          color: colors.onSurface.withValues(alpha: 0.5),
                                        ),
                                      ),
                                      if (user.createdAt != null)
                                        Text(
                                          user.createdAt!.split('T')[0],
                                          style: GoogleFonts.nunito(
                                            fontSize: 11,
                                            color: colors.onSurface.withValues(alpha: 0.4),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // Role chip
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: rc.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: rc.withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    user.role,
                                    style: GoogleFonts.nunito(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: rc,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Status dot
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: sc,
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
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

                // User info header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: _roleColor(user.role).withValues(alpha: 0.1),
                      child: Text(
                        (user.fullName ?? user.username)
                            .substring(0, 1)
                            .toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _roleColor(user.role),
                        ),
                      ),
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
                              fontSize: 14,
                              color: colors.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (user.phone != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.phone_rounded,
                          size: 16, color: colors.onSurface.withValues(alpha: 0.4)),
                      const SizedBox(width: 6),
                      Text(
                        user.phone!,
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          color: colors.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],

                if (user.createdAt != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 16, color: colors.onSurface.withValues(alpha: 0.4)),
                      const SizedBox(width: 6),
                      Text(
                        'Registrado: ${user.createdAt!.split('T')[0]}',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          color: colors.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),
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
                Wrap(
                  spacing: 8,
                  children: _roles.map((r) {
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
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? rc : colors.onSurface.withValues(alpha: 0.7),
                      ),
                      side: BorderSide(
                        color: isSelected ? rc.withValues(alpha: 0.5) : Colors.transparent,
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
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? sc : colors.onSurface.withValues(alpha: 0.7),
                      ),
                      side: BorderSide(
                        color: isSelected ? sc.withValues(alpha: 0.5) : Colors.transparent,
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
                            style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: (selectedRole != user.role ||
                                selectedStatus != user.status)
                            ? () => _saveUser(ctx, user, selectedRole, selectedStatus)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[200],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text('Guardar',
                            style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
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
                      icon: Icon(Icons.archive_outlined,
                          size: 18, color: Colors.grey[600]),
                      label: Text(
                        'Archivar usuario',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
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
          SnackBar(content: Text('Usuario actualizado')),
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
