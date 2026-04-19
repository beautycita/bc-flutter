import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:beautycita/services/supabase_client.dart';

/// Creates a [ProviderContainer] with optional overrides for testing.
ProviderContainer createContainer({
  List<Override> overrides = const [],
}) {
  final container = ProviderContainer(overrides: overrides);
  return container;
}

/// Sets up the Supabase test seam with a fake user ID.
/// Call in setUp(), and call [tearDownSupabase] in tearDown().
void setUpSupabaseTestSeam({String userId = 'test-user-id'}) {
  SupabaseClientService.testUserId = userId;
}

/// Sets up the Supabase test seam with a fake client + fake user ID.
/// The fake client returns null for any `.from(table).select().eq().maybeSingle()` chain.
void setUpSupabaseTestClient({String userId = 'test-user-id'}) {
  SupabaseClientService.testClient = FakeSupabaseClient();
  SupabaseClientService.testUserId = userId;
}

/// Tears down the Supabase test seam.
void tearDownSupabase() {
  SupabaseClientService.testClient = null;
  SupabaseClientService.testUserId = null;
}

// ---------------------------------------------------------------------------
// Supabase fakes for test client setup
// ---------------------------------------------------------------------------

/// Fake SupabaseClient whose .from() returns a chainable fake builder.
/// All chains resolve to null (maybeSingle) or empty map (single).
class FakeSupabaseClient extends Fake implements SupabaseClient {
  @override
  SupabaseQueryBuilder from(String table) => FakeSupabaseQueryBuilder();
}

class FakeSupabaseQueryBuilder extends Fake implements SupabaseQueryBuilder {
  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) =>
      MockPostgrestFilterBuilder();
}

/// Fake PostgREST chain that supports all chainable methods.
/// All filter/transform methods return `this`. Awaiting resolves to null.
/// This enables testing code that calls:
///   client.from('table').select('*').eq('col', val).maybeSingle()
class MockPostgrestFilterBuilder implements PostgrestFilterBuilder<PostgrestList> {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString().replaceAll('Symbol("', '').replaceAll('")', '');
    // Terminal methods that return awaitable builders
    if (name == 'maybeSingle') return _AwaitableNull();
    if (name == 'single') return _AwaitableEmptyMap();
    // Chain methods (eq, neq, select, order, limit, etc.) return this
    return this;
  }
}

/// Awaitable that resolves to null. Implements `Future<Map?>` via then().
class _AwaitableNull implements PostgrestTransformBuilder<PostgrestMap?> {
  @override
  Future<R> then<R>(FutureOr<R> Function(PostgrestMap? value) onValue,
          {Function? onError}) =>
      Future<PostgrestMap?>.value(null).then(onValue, onError: onError);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Awaitable that resolves to empty map. Implements Future<Map> via then().
class _AwaitableEmptyMap implements PostgrestTransformBuilder<PostgrestMap> {
  @override
  Future<R> then<R>(FutureOr<R> Function(PostgrestMap value) onValue,
          {Function? onError}) =>
      Future<PostgrestMap>.value(<String, dynamic>{})
          .then(onValue, onError: onError);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
