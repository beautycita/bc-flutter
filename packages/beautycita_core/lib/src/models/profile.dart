class Profile {
  final String id;
  final String? fullName;
  final String? username;
  final String? phone;
  final String? avatarUrl;
  final double saldo;
  final String role;

  const Profile({
    required this.id,
    this.fullName,
    this.username,
    this.phone,
    this.avatarUrl,
    this.saldo = 0,
    this.role = 'customer',
  });

  String get displayName => fullName ?? username ?? 'Usuario';

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      fullName: json['full_name'] as String?,
      username: json['username'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      saldo: (json['saldo'] as num?)?.toDouble() ?? 0,
      role: json['role'] as String? ?? 'customer',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'username': username,
      'phone': phone,
      'avatar_url': avatarUrl,
      'saldo': saldo,
      'role': role,
    };
  }
}
