import 'dart:math';

/// Generates cute, memorable usernames for BeautyCita users.
/// Auto-generated on registration - NO keyboard input required.
///
/// Format: camelCase (e.g., strawberryBlonde, velvetRose42)
/// Pattern: adjective/descriptor + beauty/nature noun + optional 2-digit suffix
class UsernameGenerator {
  static final Random _random = Random();

  // Colors, textures, moods, precious things, nature
  static const List<String> _adjectives = [
    'velvet',
    'golden',
    'coral',
    'moonlit',
    'sparkle',
    'crystal',
    'honey',
    'cherry',
    'pearl',
    'silk',
    'rose',
    'amber',
    'jade',
    'lavender',
    'crimson',
    'ivory',
    'scarlet',
    'emerald',
    'sapphire',
    'ruby',
    'opal',
    'cosmic',
    'dreamy',
    'mystic',
    'starlit',
    'twilight',
    'radiant',
    'shimmer',
    'glitter',
    'frosted',
    'blushing',
    'dewy',
    'luminous',
    'enchanted',
    'serene',
    'ethereal',
    'celestial',
    'divine',
    'precious',
    'dazzling',
    'strawberry',
    'blissful',
    'whispering',
    'dancing',
    'singing',
    'blazing',
    'glowing',
    'shining',
    'twinkling',
    'sparkling',
  ];

  // Beauty-related, nature, royalty
  static const List<String> _nouns = [
    'blonde',
    'bee',
    'rose',
    'lash',
    'glow',
    'dream',
    'queen',
    'blossom',
    'mist',
    'curl',
    'nail',
    'star',
    'moon',
    'petal',
    'jewel',
    'crown',
    'butterfly',
    'orchid',
    'dahlia',
    'peony',
    'lily',
    'iris',
    'violet',
    'gem',
    'tiara',
    'goddess',
    'swan',
    'dove',
    'phoenix',
    'angel',
    'muse',
    'diva',
    'belle',
    'charm',
    'pixie',
    'fairy',
    'bloom',
    'aurora',
    'luna',
    'stella',
    'sky',
    'sun',
    'flame',
    'breeze',
    'wave',
    'rain',
    'shine',
    'diamond',
    'sapphire',
  ];

  /// Generates a random username in camelCase format.
  ///
  /// Example: velvetRose, strawberryBlonde, moonlitLash
  ///
  /// Returns a username like: adjective + Noun (first letter capitalized)
  static String generateUsername() {
    final adjective = _adjectives[_random.nextInt(_adjectives.length)];
    final noun = _nouns[_random.nextInt(_nouns.length)];

    // Capitalize first letter of noun for camelCase
    final capitalizedNoun = noun[0].toUpperCase() + noun.substring(1);

    return '$adjective$capitalizedNoun';
  }

  // Third word for three-word usernames (used on collision)
  static const List<String> _midWords = [
    'burning', 'dancing', 'falling', 'hidden', 'flying',
    'rising', 'floating', 'wild', 'gentle', 'silent',
    'bright', 'sweet', 'soft', 'bold', 'deep',
    'warm', 'cool', 'rare', 'pure', 'true',
    'little', 'lucky', 'magic', 'misty', 'sunny',
  ];

  /// Generates a three-word username for collision recovery.
  ///
  /// Example: mysticBurningFlame, velvetSilentRose, goldenWildBloom
  static String generateThreeWordUsername() {
    final adjective = _adjectives[_random.nextInt(_adjectives.length)];
    final mid = _midWords[_random.nextInt(_midWords.length)];
    final noun = _nouns[_random.nextInt(_nouns.length)];

    final capitalizedMid = mid[0].toUpperCase() + mid.substring(1);
    final capitalizedNoun = noun[0].toUpperCase() + noun.substring(1);

    return '$adjective$capitalizedMid$capitalizedNoun';
  }

  /// @deprecated Use [generateUsername] with collision retry via [generateThreeWordUsername].
  static String generateUsernameWithSuffix() => generateThreeWordUsername();

  /// Generates multiple unique username suggestions.
  ///
  /// Returns a list of [count] usernames (default: 5).
  /// Usernames in the list are unique within the set.
  static List<String> generateSuggestions({int count = 5, bool withSuffix = false}) {
    final Set<String> suggestions = {};

    while (suggestions.length < count) {
      final username = withSuffix
          ? generateUsernameWithSuffix()
          : generateUsername();
      suggestions.add(username);
    }

    return suggestions.toList();
  }

  /// Get total possible combinations (without suffix).
  static int get totalCombinations => _adjectives.length * _nouns.length;

  /// Get total possible combinations (with 2-digit suffix).
  static int get totalCombinationsWithSuffix => totalCombinations * 90;
}
