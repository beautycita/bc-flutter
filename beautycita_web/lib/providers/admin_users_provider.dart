import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';

/// Strip PostgREST filter metacharacters to prevent filter injection via .or().
String _sanitize(String input) =>
    input.replaceAll(RegExp(r'[.,()\\]'), '').trim();

// ── Data classes ──────────────────────────────────────────────────────────────

@immutable
class AdminUser {
  final String id;
  final String username;
  final String? fullName;
  final String role;
  final String? phone;
  final DateTime? phoneVerifiedAt;
  final String? email;
  final DateTime? emailConfirmedAt;
  final List<String> authProviders; // e.g. ['google', 'email', 'phone']
  final bool hasPassword;
  final DateTime? birthday;
  final String? gender;
  final String? homeAddress;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastSeen;
  final DateTime? lastSignInAt;
  final String status;

  const AdminUser({
    required this.id,
    required this.username,
    this.fullName,
    required this.role,
    this.phone,
    this.phoneVerifiedAt,
    this.email,
    this.emailConfirmedAt,
    this.authProviders = const [],
    this.hasPassword = false,
    this.birthday,
    this.gender,
    this.homeAddress,
    this.avatarUrl,
    required this.createdAt,
    this.updatedAt,
    this.lastSeen,
    this.lastSignInAt,
    this.status = 'active',
  });

  bool get isActive => status == 'active';
  bool get phoneVerified => phoneVerifiedAt != null;
  bool get emailVerified => emailConfirmedAt != null;
  bool get usesGoogle => authProviders.contains('google');

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    // auth_providers can be a JSON array like ["google","email"] or null
    final rawProviders = json['auth_providers'];
    final providers = <String>[];
    if (rawProviders is List) {
      for (final p in rawProviders) {
        if (p is String) providers.add(p);
      }
    }

    return AdminUser(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? 'Sin nombre',
      fullName: json['full_name'] as String?,
      role: json['role'] as String? ?? 'customer',
      phone: json['phone'] as String?,
      phoneVerifiedAt:
          DateTime.tryParse(json['phone_verified_at'] as String? ?? ''),
      email: json['email'] as String?,
      emailConfirmedAt:
          DateTime.tryParse(json['email_confirmed_at'] as String? ?? ''),
      authProviders: providers,
      hasPassword: json['has_password'] as bool? ?? false,
      birthday: DateTime.tryParse(json['birthday'] as String? ?? ''),
      gender: json['gender'] as String?,
      homeAddress: json['home_address'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
      lastSeen: DateTime.tryParse(json['last_seen'] as String? ?? ''),
      lastSignInAt:
          DateTime.tryParse(json['last_sign_in_at'] as String? ?? ''),
      status: json['status'] as String? ?? 'active',
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

    final result = await client.rpc('admin_list_users', params: {
      'p_role': filter.role,
      'p_status': filter.status,
      'p_search': _sanitize(filter.searchText),
      'p_sort': filter.sortColumn ?? 'created_at',
      'p_asc': filter.sortAscending,
      'p_offset': filter.page * filter.pageSize,
      'p_limit': filter.pageSize,
    });

    final data = result as Map<String, dynamic>;
    final usersJson = data['users'] as List? ?? [];
    final total = data['total'] as int? ?? 0;

    final users = usersJson
        .map((row) => AdminUser.fromJson(row as Map<String, dynamic>))
        .toList();

    return UsersPageData(users: users, totalCount: total);
  } catch (e, st) {
    debugPrint(
        'Admin users error: $e\n${st.toString().split('\n').take(5).join('\n')}');
    rethrow;
  }
});
