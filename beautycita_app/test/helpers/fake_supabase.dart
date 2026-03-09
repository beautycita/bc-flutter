/// Lightweight fake for Supabase's chained PostgREST API.
///
/// Usage:
///   final fake = FakePostgrestBuilder({'business_id': 'biz-1'});
///   // When code does: client.from('favorites').select('business_id').eq('user_id', id)
///   // The fake returns the preconfigured rows.
///
/// Add chainable methods as tests need them.

class FakePostgrestBuilder {
  final List<Map<String, dynamic>> _rows;
  final Exception? _error;

  FakePostgrestBuilder(this._rows)
      : _error = null;

  FakePostgrestBuilder.single(Map<String, dynamic> row)
      : _rows = [row],
        _error = null;

  FakePostgrestBuilder.empty()
      : _rows = [],
        _error = null;

  FakePostgrestBuilder.error(this._error)
      : _rows = [];

  // Chainable query methods — all return `this` for chaining.
  FakePostgrestBuilder select([String? columns]) => this;
  FakePostgrestBuilder insert(dynamic data) => this;
  FakePostgrestBuilder update(dynamic data) => this;
  FakePostgrestBuilder delete() => this;
  FakePostgrestBuilder eq(String column, dynamic value) => this;
  FakePostgrestBuilder neq(String column, dynamic value) => this;
  FakePostgrestBuilder not(String column, String operator, dynamic value) => this;
  FakePostgrestBuilder gte(String column, dynamic value) => this;
  FakePostgrestBuilder lte(String column, dynamic value) => this;
  FakePostgrestBuilder order(String column, {bool ascending = true}) => this;
  FakePostgrestBuilder limit(int count) => this;

  /// Terminal: returns the row list (simulates await on query).
  Future<List<Map<String, dynamic>>> asList() async {
    if (_error != null) throw _error;
    return _rows;
  }

  /// Terminal: returns a single row or null.
  Future<Map<String, dynamic>?> maybeSingle() async {
    if (_error != null) throw _error;
    return _rows.isEmpty ? null : _rows.first;
  }

  /// Terminal: returns a single row (throws if empty).
  Future<Map<String, dynamic>> single() async {
    if (_error != null) throw _error;
    if (_rows.isEmpty) throw Exception('No rows returned');
    return _rows.first;
  }
}
