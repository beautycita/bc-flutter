import 'package:beautycita_core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/admin_users_provider.dart';
import '../../widgets/bc_data_table.dart';
import '../../widgets/bulk_action_bar.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/master_detail_layout.dart';
import '../../widgets/pagination_bar.dart';
import 'user_detail_panel.dart';

/// Admin users management page with master-detail layout.
class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  AdminUser? _selectedUser;
  Set<AdminUser> _checkedUsers = {};
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final filter = ref.watch(usersFilterProvider);
    final usersAsync = ref.watch(adminUsersProvider);
    final dateFormat = DateFormat('d MMM yy', 'es');

    final items = usersAsync.valueOrNull?.users ?? [];
    final totalCount = usersAsync.valueOrNull?.totalCount ?? 0;
    final isLoading = usersAsync.isLoading;
    final totalPages = (totalCount / filter.pageSize).ceil();

    return MasterDetailLayout<AdminUser>(
      items: items,
      isLoading: isLoading,
      selectedItem: _selectedUser,
      onSelect: (user) => setState(() => _selectedUser = user),
      detailTitle: _selectedUser?.username ?? 'Usuario',
      detailBuilder: (user) => UserDetailContent(user: user),
      filterBar: FilterBar(
        searchField: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Buscar usuario...',
            prefixIcon: const Icon(Icons.search, size: 20),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: BCSpacing.sm,
              vertical: BCSpacing.sm,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
            ),
            suffixIcon: filter.searchText.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(usersFilterProvider.notifier).state =
                          filter.copyWith(searchText: '', page: 0);
                    },
                  )
                : null,
          ),
          onChanged: (value) {
            ref.read(usersFilterProvider.notifier).state =
                filter.copyWith(searchText: value, page: 0);
          },
        ),
        filters: [
          // Role filter
          _FilterDropdown(
            value: filter.role,
            hint: 'Rol',
            items: const {
              null: 'Todos',
              'customer': 'Cliente',
              'stylist': 'Estilista',
              'admin': 'Admin',
            },
            onChanged: (value) {
              ref.read(usersFilterProvider.notifier).state =
                  filter.copyWith(role: () => value, page: 0);
            },
          ),
          // Status filter
          _FilterDropdown(
            value: filter.status,
            hint: 'Estado',
            items: const {
              null: 'Todos',
              'active': 'Activo',
              'suspended': 'Suspendido',
              'archived': 'Archivado',
            },
            onChanged: (value) {
              ref.read(usersFilterProvider.notifier).state =
                  filter.copyWith(status: () => value, page: 0);
            },
          ),
        ],
        onClearAll: filter.hasActiveFilters
            ? () {
                _searchController.clear();
                ref.read(usersFilterProvider.notifier).state =
                    const UsersFilter();
              }
            : null,
      ),
      table: BCDataTable<AdminUser>(
        columns: [
          BCColumn<AdminUser>(
            id: 'username',
            label: 'Usuario',
            sortable: true,
            cellBuilder: (user) => Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      colors.primary.withValues(alpha: 0.1),
                  backgroundImage: user.avatarUrl != null
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  child: user.avatarUrl == null
                      ? Icon(Icons.person, size: 14, color: colors.primary)
                      : null,
                ),
                const SizedBox(width: BCSpacing.sm),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.fullName ?? user.username,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (user.fullName != null)
                        Text(
                          '@${user.username}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.5),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          BCColumn<AdminUser>(
            id: 'role',
            label: 'Rol',
            sortable: true,
            width: 100,
            cellBuilder: (user) => _RoleChip(role: user.role),
          ),
          BCColumn<AdminUser>(
            id: 'phone',
            label: 'Telefono',
            cellBuilder: (user) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    user.phone ?? '-',
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (user.phone != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    user.phoneVerified
                        ? Icons.verified
                        : Icons.warning_amber_rounded,
                    size: 14,
                    color:
                        user.phoneVerified ? Colors.green : Colors.orange,
                  ),
                ],
              ],
            ),
          ),
          BCColumn<AdminUser>(
            id: 'created_at',
            label: 'Creado',
            sortable: true,
            width: 100,
            cellBuilder: (user) => Text(
              dateFormat.format(user.createdAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.7),
              ),
              maxLines: 1,
            ),
          ),
          BCColumn<AdminUser>(
            id: 'last_seen',
            label: 'Ultimo acceso',
            sortable: true,
            width: 100,
            cellBuilder: (user) => Text(
              user.lastSeen != null
                  ? dateFormat.format(user.lastSeen!)
                  : 'Nunca',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.7),
              ),
              maxLines: 1,
            ),
          ),
          BCColumn<AdminUser>(
            id: 'status',
            label: 'Estado',
            width: 80,
            cellBuilder: (user) => _StatusChip(
              status: user.status,
            ),
          ),
        ],
        items: items,
        selectedItems: _checkedUsers,
        selectedItem: _selectedUser,
        isLoading: isLoading,
        sortColumn: filter.sortColumn,
        sortAscending: filter.sortAscending,
        onRowTap: (user) =>
            setState(() => _selectedUser = user),
        onSelectionChanged: (selected) =>
            setState(() => _checkedUsers = selected),
        onSort: (column) {
          final ascending =
              filter.sortColumn == column ? !filter.sortAscending : true;
          ref.read(usersFilterProvider.notifier).state = filter.copyWith(
            sortColumn: () => column,
            sortAscending: ascending,
          );
        },
        emptyIcon: Icons.people_outline,
        emptyTitle: 'No hay usuarios',
        emptySubtitle: filter.hasActiveFilters
            ? 'Intenta con otros filtros'
            : null,
      ),
      bulkActionBar: _checkedUsers.isNotEmpty
          ? BulkActionBar(
              selectedCount: _checkedUsers.length,
              onClearSelection: () =>
                  setState(() => _checkedUsers = {}),
              actions: [
                TextButton.icon(
                  onPressed: () {
                    // TODO: Export selected users
                  },
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Exportar'),
                ),
                TextButton.icon(
                  onPressed: () {
                    // TODO: Bulk suspend
                  },
                  icon: Icon(Icons.block, size: 18, color: colors.error),
                  label: Text(
                    'Suspender',
                    style: TextStyle(color: colors.error),
                  ),
                ),
              ],
            )
          : null,
      pagination: totalPages > 1
          ? PaginationBar(
              currentPage: filter.page,
              totalPages: totalPages,
              totalItems: totalCount,
              pageSize: filter.pageSize,
              onPageChanged: (page) {
                ref.read(usersFilterProvider.notifier).state =
                    filter.copyWith(page: page);
              },
              onPageSizeChanged: (size) {
                ref.read(usersFilterProvider.notifier).state =
                    filter.copyWith(pageSize: size, page: 0);
              },
            )
          : null,
    );
  }
}

// ── Chip widgets ──────────────────────────────────────────────────────────────

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'active' => ('Activo', Colors.green),
      'suspended' => ('Suspendido', Colors.orange),
      'archived' => ('Archivado', Colors.grey),
      _ => (status, Colors.grey),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Filter dropdown ───────────────────────────────────────────────────────────

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final String? value;
  final String hint;
  final Map<String?, String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: BCSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isDense: true,
          hint: Text(hint, style: theme.textTheme.bodySmall),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurface,
          ),
          items: items.entries
              .map((e) => DropdownMenuItem<String?>(
                    value: e.key,
                    child: Text(e.value),
                  ))
              .toList(),
          onChanged: (v) => onChanged(v),
        ),
      ),
    );
  }
}
