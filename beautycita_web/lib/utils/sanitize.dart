/// Strip PostgREST filter metacharacters to prevent filter injection via .or().
///
/// Used in all admin search queries that pass user input to PostgREST filters.
String sanitizeSearch(String input) =>
    input.replaceAll(RegExp(r'[.,()\\]'), '').trim();
