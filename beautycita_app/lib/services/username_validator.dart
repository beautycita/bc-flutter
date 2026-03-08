/// Validates usernames to prevent impersonation, profanity, and abuse.
///
/// Enforcement layers:
///   1. Client-side in profile_screen.dart (instant feedback)
///   2. Before DB write in profile_provider.dart (guard)
///   3. DB trigger (ultimate defense — see migration)
class UsernameValidator {
  UsernameValidator._();

  static const int minLength = 3;
  static const int maxLength = 30;

  /// Validate a username. Returns null if valid, or an error message (Spanish).
  static String? validate(String username) {
    final trimmed = username.trim();

    if (trimmed.length < minLength) {
      return trimmed.isEmpty ? null : 'Minimo $minLength caracteres';
    }
    if (trimmed.length > maxLength) {
      return 'Maximo $maxLength caracteres';
    }
    if (!_alphanumericOnly.hasMatch(trimmed)) {
      return 'Solo letras y numeros';
    }
    if (_allNumeric.hasMatch(trimmed)) {
      return 'No puede ser solo numeros';
    }
    if (_containsReservedWord(trimmed)) {
      return 'Nombre reservado — elige otro';
    }
    if (_containsProfanity(trimmed)) {
      return 'Nombre no permitido';
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Format checks
  // ---------------------------------------------------------------------------

  static final _alphanumericOnly = RegExp(r'^[a-zA-Z0-9]+$');
  static final _allNumeric = RegExp(r'^[0-9]+$');

  // ---------------------------------------------------------------------------
  // Reserved word detection (impersonation prevention)
  // ---------------------------------------------------------------------------

  /// Reserved words that must not appear anywhere in the username.
  /// Checked against a normalized (lowercased, leet-decoded, diacritic-stripped)
  /// version of the input.
  static const _reservedWords = <String>[
    // Platform identity
    'beautycita', 'beautycit', 'beauticita', 'beauticit',
    'bcita', 'bcapp',
    // Roles & authority
    'admin', 'administrador', 'administrator',
    'superadmin', 'superadministrador',
    'moderador', 'moderator',
    'soporte', 'support',
    'sistema', 'system',
    'oficial', 'official',
    'verificado', 'verified',
    'staff', 'empleado',
    'helpdesk', 'help',
    // Team members (prevent impersonation of known staff)
    'eros',
    // Technical / misleading
    'root', 'sudo', 'null', 'undefined', 'anonymous',
    'bot', 'robot', 'autobot',
    'test', 'testing',
    'api', 'webhook', 'server',
    'security', 'seguridad',
    'payment', 'pago', 'pagos',
    'stripe', 'btcpay', 'bitcoin',
  ];

  /// Check if the normalized username contains any reserved word.
  static bool _containsReservedWord(String username) {
    final normalized = _normalize(username);
    for (final word in _reservedWords) {
      if (normalized.contains(word)) return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Profanity filter (Spanish + English basics)
  // ---------------------------------------------------------------------------

  /// Minimal profanity list — common slurs and offensive terms.
  /// Checked against normalized input so leet/accent tricks don't bypass.
  static const _profanityWords = <String>[
    // Spanish
    'puta', 'puto', 'pendejo', 'pendeja', 'chinga', 'chingada',
    'verga', 'culero', 'culera', 'cabron', 'cabrona', 'mamada',
    'joto', 'jota', 'maricon', 'marica', 'mierda', 'pinche',
    'huevon', 'huevona', 'idiota', 'estupido', 'estupida',
    'zorra', 'prostituta', 'prostituto', 'nalgas', 'culo',
    // English
    'fuck', 'shit', 'bitch', 'asshole', 'dick', 'pussy',
    'nigger', 'nigga', 'faggot', 'retard', 'cunt', 'whore',
    'slut', 'bastard',
  ];

  static bool _containsProfanity(String username) {
    final normalized = _normalize(username);
    for (final word in _profanityWords) {
      if (normalized.contains(word)) return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Normalization: leet speak, diacritics, homoglyphs
  // ---------------------------------------------------------------------------

  /// Normalize a username for comparison:
  /// 1. Lowercase
  /// 2. Strip diacritics (á→a, ñ→n, etc.)
  /// 3. Decode leet speak (0→o, 1→i, 3→e, 4→a, 5→s, 7→t, 8→b, @→a)
  /// 4. Collapse repeated chars (aaadmin → admin)
  static String _normalize(String input) {
    var s = input.toLowerCase();
    s = _stripDiacritics(s);
    s = _decodeLeet(s);
    s = _collapseRepeats(s);
    return s;
  }

  static String _stripDiacritics(String s) {
    const map = {
      'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', 'å': 'a',
      'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
      'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
      'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
      'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
      'ñ': 'n', 'ç': 'c', 'ß': 'ss',
    };
    final buf = StringBuffer();
    for (final c in s.split('')) {
      buf.write(map[c] ?? c);
    }
    return buf.toString();
  }

  static String _decodeLeet(String s) {
    const map = {
      '0': 'o', '1': 'i', '3': 'e', '4': 'a',
      '5': 's', '7': 't', '8': 'b', '@': 'a',
      '\$': 's', '!': 'i',
    };
    final buf = StringBuffer();
    for (final c in s.split('')) {
      buf.write(map[c] ?? c);
    }
    return buf.toString();
  }

  /// Collapse runs of 3+ identical chars to 1 (e.g., "aaadmin" → "admin").
  static String _collapseRepeats(String s) {
    if (s.length < 3) return s;
    final buf = StringBuffer();
    var prev = '';
    var count = 0;
    for (final c in s.split('')) {
      if (c == prev) {
        count++;
        if (count < 2) buf.write(c);
      } else {
        buf.write(c);
        prev = c;
        count = 0;
      }
    }
    return buf.toString();
  }
}
