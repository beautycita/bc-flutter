import 'package:flutter/material.dart';

/// 10 salon default avatar URLs on R2. Same seed → same image, so a salon
/// that lacks a photo always renders the same default across the app.
const List<String> _salonDefaultAvatarUrls = [
  'https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/salon_defaults/salon_01.jpg',
  'https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/salon_defaults/salon_02.jpg',
  'https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/salon_defaults/salon_03.jpg',
  'https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/salon_defaults/salon_04.jpg',
  'https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/salon_defaults/salon_05.jpg',
  'https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/salon_defaults/salon_06.jpg',
  'https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/salon_defaults/salon_07.jpg',
  'https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/salon_defaults/salon_08.jpg',
  'https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/salon_defaults/salon_09.jpg',
  'https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/salon_defaults/salon_10.jpg',
];

/// Deterministic pick: same [seed] always returns the same URL.
/// Falls back to a random-ish hash on empty/null seeds.
String salonDefaultAvatarUrl(String? seed) {
  final s = (seed == null || seed.isEmpty) ? 'fallback' : seed;
  var h = 0;
  for (var i = 0; i < s.length; i++) {
    h = (h * 31 + s.codeUnitAt(i)) & 0x7fffffff;
  }
  return _salonDefaultAvatarUrls[h % _salonDefaultAvatarUrls.length];
}

/// Circle or rounded-rect salon image that falls back to one of 10 defaults
/// when [photoUrl] is null/empty. Use [seed] (typically the salon id) so the
/// same salon keeps the same default across sessions.
class SalonAvatar extends StatelessWidget {
  final String? photoUrl;
  final String? seed;
  final double size;
  final BorderRadius? borderRadius;
  final BoxFit fit;

  const SalonAvatar({
    super.key,
    required this.photoUrl,
    required this.seed,
    this.size = 50,
    this.borderRadius,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final url = (photoUrl != null && photoUrl!.isNotEmpty)
        ? photoUrl!
        : salonDefaultAvatarUrl(seed);
    final radius = borderRadius ?? BorderRadius.circular(size / 2);
    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: fit,
        errorBuilder: (_, _, _) =>Image.network(
          salonDefaultAvatarUrl(seed),
          width: size,
          height: size,
          fit: fit,
          errorBuilder: (_, _, _) =>_placeholder(context),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
        width: size,
        height: size,
        color: Theme.of(context)
            .colorScheme
            .primary
            .withValues(alpha: 0.12),
        child: Icon(
          Icons.store,
          size: size * 0.45,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
}
