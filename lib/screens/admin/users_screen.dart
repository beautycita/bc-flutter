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

  Future<void> _changeRole(AdminUser user, String newRole) async {
    try {
      await SupabaseClientService.client
          .from('profiles')
          .update({'role': newRole}).eq('id', user.id);
      await adminLogAction(
        action: 'change_role',
        targetType: 'user',
        targetId: user.id,
        details: {'old_role': user.role, 'new_role': newRole},
      );
      ref.invalidate(adminUsersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rol cambiado a $newRole')),
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
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Buscar usuario...',
                    hintStyle: GoogleFonts.nunito(fontSize: 14),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusSM),
                      borderSide: BorderSide(
                          color: colors.onSurface.withValues(alpha: 0.2)),
                    ),
                  ),
                  style: GoogleFonts.nunito(fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String?>(
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppConstants.paddingMD),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final user = filtered[i];
                    return Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusMD),
                      ),
                      margin: const EdgeInsets.only(
                          bottom: AppConstants.paddingSM),
                      child: Padding(
                        padding:
                            const EdgeInsets.all(AppConstants.paddingSM),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor:
                                  colors.primary.withValues(alpha: 0.1),
                              child: Text(
                                (user.fullName ?? user.username)
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: colors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.fullName ?? user.username,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: colors.onSurface,
                                    ),
                                  ),
                                  Text(
                                    '@${user.username}',
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      color: colors.onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                  if (user.createdAt != null)
                                    Text(
                                      user.createdAt!.split('T')[0],
                                      style: GoogleFonts.nunito(
                                        fontSize: 11,
                                        color: colors.onSurface
                                            .withValues(alpha: 0.4),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            DropdownButton<String>(
                              value: user.role,
                              underline: const SizedBox.shrink(),
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.primary,
                              ),
                              items: _roles
                                  .map((r) => DropdownMenuItem(
                                        value: r,
                                        child: Text(r),
                                      ))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null && v != user.role) {
                                  _changeRole(user, v);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text('Error: $e',
                  style: GoogleFonts.nunito(color: colors.error)),
            ),
          ),
        ),
      ],
    );
  }
}
