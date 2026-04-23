/// Deterministic salon default-avatar picker.
/// Mirrors the mobile-app pool of 10 R2 images so a salon that lacks
/// a photo renders the same default here and on mobile.
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

String salonDefaultAvatarUrl(String? seed) {
  final s = (seed == null || seed.isEmpty) ? 'fallback' : seed;
  var h = 0;
  for (var i = 0; i < s.length; i++) {
    h = (h * 31 + s.codeUnitAt(i)) & 0x7fffffff;
  }
  return _salonDefaultAvatarUrls[h % _salonDefaultAvatarUrls.length];
}
