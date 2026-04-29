import 'dart:convert';

class JwtClaims {
  JwtClaims(this.raw);

  final Map<String, dynamic> raw;

  String? get aud {
    final v = raw['aud'];
    if (v is String) return v;
    if (v is List && v.isNotEmpty && v.first is String) return v.first as String;
    return null;
  }

  String? get iss => raw['iss'] is String ? raw['iss'] as String : null;
  String? get sessionId => raw['session_id'] is String ? raw['session_id'] as String : null;
  String? get sub => raw['sub'] is String ? raw['sub'] as String : null;

  DateTime? get exp {
    final v = raw['exp'];
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v * 1000);
    if (v is double) return DateTime.fromMillisecondsSinceEpoch((v * 1000).round());
    return null;
  }
}

JwtClaims? decodeJwt(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    var b64 = parts[1].replaceAll('-', '+').replaceAll('_', '/');
    while (b64.length % 4 != 0) {
      b64 += '=';
    }
    final decoded = utf8.decode(base64.decode(b64));
    final claims = jsonDecode(decoded);
    if (claims is! Map<String, dynamic>) return null;
    return JwtClaims(claims);
  } catch (_) {
    return null;
  }
}

String? validateSupabaseAccessToken(String token, {required String supabaseUrl}) {
  final claims = decodeJwt(token);
  if (claims == null) return 'token_malformed';

  final exp = claims.exp;
  if (exp == null || exp.isBefore(DateTime.now())) return 'token_expired';

  if (claims.aud != 'authenticated') return 'token_aud_mismatch';

  final base = supabaseUrl.replaceAll(RegExp(r'/+$'), '');
  if (base.isEmpty) return 'supabase_url_unset';
  final expectedIss = '$base/auth/v1';
  if (claims.iss != expectedIss) return 'token_iss_mismatch';

  return null;
}
