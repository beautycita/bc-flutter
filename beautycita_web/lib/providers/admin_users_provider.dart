import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';

// ── Data classes ──────────────────────────────────────────────────────────────

@immutable
class AdminUser {
  final String id;
  final String username;
  final String? email;
  final String role;
  final String? phone;
  final bool phoneVerified;
  final DateTime createdAt;
  final DateTime? lastActiveAt;
  final bool isActive;
  final String? avatarUrl;
  final String? notes;

  const AdminUser({
    required this.id,
    required this.username,
    this.email,
    required this.role,
    this.phone,
    this.phoneVerified = false,
    required this.createdAt,
    this.lastActiveAt,
    this.isActive = true,
    this.avatarUrl,
    this.notes,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as String? ?? '',
      username: json['display_name'] as String? ??
          json['username'] as String? ??
          'Sin nombre',
      email: json['email'] as String?,
      role: json['role'] as String? ?? 'client',
      phone: json['phone'] as String?,
      phoneVerified: json['phone_verified'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      lastActiveAt:
          DateTime.tryParse(json['last_active_at'] as String? ?? ''),
      isActive: json['is_active'] as bool? ?? true,
      avatarUrl: json['avatar_url'] as String?,
      notes: json['admin_notes'] as String?,
    );
  }
}

@immutable
class UsersPageData {
  final List<AdminUser> users;
  final int totalCount;

  const UsersPageData({required this.users, required this.totalCount});

  static const empty = UsersPageData(users: [], totalCount: 0);
}

// ── Filter state ──────────────────────────────────────────────────────────────

@immutable
class UsersFilter {
  final String? role;
  final String searchText;
  final String? status; // 'active', 'inactive', null=all
  final int page;
  final int pageSize;
  final String? sortColumn;
  final bool sortAscending;

  const UsersFilter({
    this.role,
    this.searchText = '',
    this.status,
    this.page = 0,
    this.pageSize = 20,
    this.sortColumn,
    this.sortAscending = true,
  });

  UsersFilter copyWith({
    String? Function()? role,
    String? searchText,
    String? Function()? status,
    int? page,
    int? pageSize,
    String? Function()? sortColumn,
    bool? sortAscending,
  }) {
    return UsersFilter(
      role: role != null ? role() : this.role,
      searchText: searchText ?? this.searchText,
      status: status != null ? status() : this.status,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      sortColumn: sortColumn != null ? sortColumn() : this.sortColumn,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }

  bool get hasActiveFilters =>
      role != null || searchText.isNotEmpty || status != null;
}

// ── Providers ─────────────────────────────────────────────────────────────────

final usersFilterProvider = StateProvider<UsersFilter>(
  (ref) => const UsersFilter(),
);

final adminUsersProvider = FutureProvider<UsersPageData>((ref) async {
  final filter = ref.watch(usersFilterProvider);

  if (!BCSupabase.isInitialized) return UsersPageData.empty;

  try {
    final client = BCSupabase.client;
    final sortCol = filter.sortColumn ?? 'created_at';
    final from = filter.page * filter.pageSize;
    final to = from + filter.pageSize - 1;

    // Build base query with equality filters first
    var query = client.from(BCTables.profiles).select(
      'id, display_name, username, email, role, phone, phone_verified, '
      'created_at, last_active_at, is_active, avatar_url, admin_notes',
    );
    if (filter.role != null) {
      query = query.eq('role', filter.role!);
    }
    if (filter.status != null) {
      query = query.eq('is_active', filter.status == 'active');
    }

    // .or() returns PostgrestTransformBuilder, so chain everything after it
    final List data;
    if (filter.searchText.isNotEmpty) {
      data = await query
          .or(
            'display_name.ilike.%${filter.searchText}%,'
            'email.ilike.%${filter.searchText}%,'
            'phone.ilike.%${filter.searchText}%',
          )
          .order(sortCol, ascending: filter.sortAscending)
          .range(from, to);
    } else {
      data = await query
          .order(sortCol, ascending: filter.sortAscending)
          .range(from, to);
    }

    // Count query — separate chain
    var countQuery = client.from(BCTables.profiles).select('id');
    if (filter.role != null) {
      countQuery = countQuery.eq('role', filter.role!);
    }
    if (filter.status != null) {
      countQuery = countQuery.eq('is_active', filter.status == 'active');
    }
    final int totalCount;
    if (filter.searchText.isNotEmpty) {
      final countResult = await countQuery
          .or(
            'display_name.ilike.%${filter.searchText}%,'
            'email.ilike.%${filter.searchText}%,'
            'phone.ilike.%${filter.searchText}%',
          )
          .count();
      totalCount = countResult.count;
    } else {
      final countResult = await countQuery.count();
      totalCount = countResult.count;
    }

    final users = data.map((row) =>
        AdminUser.fromJson(row as Map<String, dynamic>)).toList();

    return UsersPageData(users: users, totalCount: totalCount);
  } catch (e) {
    debugPrint('Admin users error: $e');
    return UsersPageData.empty;
  }
});
