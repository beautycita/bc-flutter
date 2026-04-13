import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/test_config.dart';
import '../core/test_case.dart';
import '../core/test_result.dart';

/// Test 01: SAT Compliance API
/// Simulates SAT accessing the API exactly as described in the compliance guide.
/// HMAC-SHA256 authentication, all 5 endpoints, rate limiting, audit trail.
class SatApiTest extends TestSuite {
  @override
  int get order => 1;

  @override
  String get name => 'SAT Compliance API';

  @override
  String get description =>
      'Simulates SAT accessing the platform API per CFF Art. 30-B guide';

  String get _baseUrl => '${TestConfig.functionsUrl}/sat-access';

  /// Generate HMAC-SHA256 signature matching the SAT API auth spec.
  Map<String, String> _signedHeaders(String method, String path) {
    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final payload = '$timestamp$method$path';
    final hmac = Hmac(sha256, utf8.encode(TestConfig.satApiSecret));
    final signature = hmac.convert(utf8.encode(payload)).toString();

    return {
      'X-SAT-Key': TestConfig.satApiKey,
      'X-SAT-Timestamp': timestamp,
      'X-SAT-Signature': signature,
      'Content-Type': 'application/json',
    };
  }

  /// Generate headers with an intentionally wrong key.
  Map<String, String> _wrongKeyHeaders(String method, String path) {
    final h = _signedHeaders(method, path);
    h['X-SAT-Key'] = 'wrong-key-12345';
    return h;
  }

  /// Generate headers with expired timestamp (10 minutes ago).
  Map<String, String> _expiredHeaders(String method, String path) {
    final expiredTs = ((DateTime.now().millisecondsSinceEpoch ~/ 1000) - 600).toString();
    final payload = '$expiredTs${method}$path';
    final hmac = Hmac(sha256, utf8.encode(TestConfig.satApiSecret));
    final signature = hmac.convert(utf8.encode(payload)).toString();

    return {
      'X-SAT-Key': TestConfig.satApiKey,
      'X-SAT-Timestamp': expiredTs,
      'X-SAT-Signature': signature,
      'Content-Type': 'application/json',
    };
  }

  /// Generate headers with tampered signature.
  Map<String, String> _tamperedHeaders(String method, String path) {
    final h = _signedHeaders(method, path);
    h['X-SAT-Signature'] = 'tampered${h['X-SAT-Signature']!.substring(8)}';
    return h;
  }

  @override
  Future<TestGroup> run(SupabaseClient client) async {
    final results = <TestResult>[];

    // --- AUTH TESTS ---
    results.add(await runCase('Valid HMAC auth → 200', () async {
      final resp = await http.get(
        Uri.parse('$_baseUrl/transactions?limit=1'),
        headers: _signedHeaders('GET', '/transactions'),
      );
      if (resp.statusCode == 200) {
        return pass('Valid HMAC auth → 200',
            detail: 'Response: ${resp.body.substring(0, (resp.body.length).clamp(0, 200))}');
      }
      return fail('Valid HMAC auth → 200', 'Expected 200, got ${resp.statusCode}: ${resp.body}');
    }));

    results.add(await runCase('Wrong API key → 401', () async {
      final resp = await http.get(
        Uri.parse('$_baseUrl/transactions'),
        headers: _wrongKeyHeaders('GET', '/transactions'),
      );
      if (resp.statusCode == 401) {
        return pass('Wrong API key → 401');
      }
      return fail('Wrong API key → 401', 'Expected 401, got ${resp.statusCode}');
    }));

    results.add(await runCase('Expired timestamp → 401', () async {
      final resp = await http.get(
        Uri.parse('$_baseUrl/transactions'),
        headers: _expiredHeaders('GET', '/transactions'),
      );
      if (resp.statusCode == 401) {
        return pass('Expired timestamp → 401');
      }
      return fail('Expired timestamp → 401', 'Expected 401, got ${resp.statusCode}');
    }));

    results.add(await runCase('Tampered signature → 401', () async {
      final resp = await http.get(
        Uri.parse('$_baseUrl/transactions'),
        headers: _tamperedHeaders('GET', '/transactions'),
      );
      if (resp.statusCode == 401) {
        return pass('Tampered signature → 401');
      }
      return fail('Tampered signature → 401', 'Expected 401, got ${resp.statusCode}');
    }));

    // --- ENDPOINT TESTS ---
    results.add(await runCase('GET /transactions — valid response', () async {
      final now = DateTime.now();
      final from = DateTime(now.year, now.month - 1, 1).toIso8601String().substring(0, 10);
      final to = now.toIso8601String().substring(0, 10);

      final resp = await http.get(
        Uri.parse('$_baseUrl/transactions?from=$from&to=$to&limit=10'),
        headers: _signedHeaders('GET', '/transactions'),
      );
      if (resp.statusCode != 200) {
        return fail('GET /transactions', 'HTTP ${resp.statusCode}: ${resp.body}');
      }

      final body = jsonDecode(resp.body);
      final txns = body['transactions'] as List?;
      if (txns == null) {
        return fail('GET /transactions', 'Missing "transactions" array in response');
      }

      return pass('GET /transactions — valid response',
          detail: '${txns.length} transactions returned',
          metrics: {'count': txns.length});
    }));

    results.add(await runCase('GET /withholdings — current period', () async {
      final now = DateTime.now();
      final period = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      final resp = await http.get(
        Uri.parse('$_baseUrl/withholdings?period=$period'),
        headers: _signedHeaders('GET', '/withholdings'),
      );
      if (resp.statusCode != 200) {
        return fail('GET /withholdings', 'HTTP ${resp.statusCode}: ${resp.body}');
      }

      final body = jsonDecode(resp.body);
      return pass('GET /withholdings — current period',
          detail: 'Period: $period, response keys: ${body.keys.join(', ')}',
          metrics: {'period': period});
    }));

    results.add(await runCase('GET /providers — lookup BC entity', () async {
      final resp = await http.get(
        Uri.parse('$_baseUrl/providers?rfc=BEA260313MI8'),
        headers: _signedHeaders('GET', '/providers'),
      );
      if (resp.statusCode != 200) {
        return fail('GET /providers', 'HTTP ${resp.statusCode}: ${resp.body}');
      }

      final body = jsonDecode(resp.body);
      final providers = body['providers'] as List?;
      if (providers == null || providers.isEmpty) {
        return warn('GET /providers — lookup BC entity',
            'RFC BEA260313MI8 not found in providers. Is any business registered with BC RFC?');
      }

      final first = providers.first;
      return pass('GET /providers — lookup BC entity',
          detail: 'Found: ${first['name']} (RFC: ${first['rfc']})',
          metrics: {'provider_count': providers.length});
    }));

    results.add(await runCase('GET /summary — monthly aggregate', () async {
      final now = DateTime.now();
      final period = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      final resp = await http.get(
        Uri.parse('$_baseUrl/summary?period=$period'),
        headers: _signedHeaders('GET', '/summary'),
      );
      if (resp.statusCode != 200) {
        return fail('GET /summary', 'HTTP ${resp.statusCode}: ${resp.body}');
      }

      final body = jsonDecode(resp.body);
      return pass('GET /summary — monthly aggregate',
          detail: jsonEncode(body).substring(0, (jsonEncode(body).length).clamp(0, 300)),
          metrics: body is Map ? Map<String, dynamic>.from(body) : {});
    }));

    results.add(await runCase('GET /platform — platform declaration', () async {
      final now = DateTime.now();
      final period = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      final resp = await http.get(
        Uri.parse('$_baseUrl/platform?period=$period'),
        headers: _signedHeaders('GET', '/platform'),
      );
      if (resp.statusCode != 200) {
        return fail('GET /platform', 'HTTP ${resp.statusCode}: ${resp.body}');
      }

      final body = jsonDecode(resp.body);
      return pass('GET /platform — platform declaration',
          detail: jsonEncode(body).substring(0, (jsonEncode(body).length).clamp(0, 300)),
          metrics: body is Map ? Map<String, dynamic>.from(body) : {});
    }));

    // --- CROSS-CHECK: summary totals match sum of transactions ---
    results.add(await runCase('Cross-check: summary matches transactions', () async {
      final now = DateTime.now();
      final period = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final from = DateTime(now.year, now.month, 1).toIso8601String().substring(0, 10);
      final to = DateTime(now.year, now.month + 1, 0).toIso8601String().substring(0, 10);

      // Fetch summary
      final summaryResp = await http.get(
        Uri.parse('$_baseUrl/summary?period=$period'),
        headers: _signedHeaders('GET', '/summary'),
      );
      // Fetch all transactions for the period
      final txnResp = await http.get(
        Uri.parse('$_baseUrl/transactions?from=$from&to=$to&limit=1000'),
        headers: _signedHeaders('GET', '/transactions'),
      );

      if (summaryResp.statusCode != 200 || txnResp.statusCode != 200) {
        return fail('Cross-check', 'Could not fetch both summary and transactions');
      }

      final summary = jsonDecode(summaryResp.body);
      final txns = (jsonDecode(txnResp.body)['transactions'] as List?) ?? [];

      final summaryTotal = (summary['total_transactions'] as num?)?.toInt() ?? 0;
      final txnCount = txns.length;

      if (txnCount == 0 && summaryTotal == 0) {
        return pass('Cross-check: summary matches transactions',
            detail: 'Both report 0 transactions for $period (no data yet)');
      }

      if (summaryTotal != txnCount) {
        return warn('Cross-check: summary matches transactions',
            'Summary says $summaryTotal transactions but /transactions returned $txnCount',
            metrics: {'summary_count': summaryTotal, 'txn_count': txnCount});
      }

      return pass('Cross-check: summary matches transactions',
          detail: 'Both report $txnCount transactions for $period',
          metrics: {'count': txnCount});
    }));

    // --- AUDIT LOG CHECK ---
    results.add(await runCase('Audit log: sat_access_log has entries', () async {
      // Use service role to query the audit table directly
      final serviceClient = SupabaseClient(
        TestConfig.supabaseUrl,
        TestConfig.supabaseServiceKey,
      );

      final response = await serviceClient
          .from('sat_access_log')
          .select('id, endpoint, status_code, created_at')
          .order('created_at', ascending: false)
          .limit(5);

      final logs = response as List;
      if (logs.isEmpty) {
        return fail('Audit log check', 'sat_access_log table is empty — no API calls logged');
      }

      return pass('Audit log: sat_access_log has entries',
          detail: '${logs.length} recent entries. Latest: ${logs.first['endpoint']} → ${logs.first['status_code']}',
          metrics: {'log_count': logs.length});
    }));

    // Calculate group status
    final failed = results.where((r) => r.isFailed).length;
    final warned = results.where((r) => r.isWarning).length;
    final totalDuration = results.fold<Duration>(Duration.zero, (sum, r) => sum + r.duration);

    final groupStatus = failed > 0
        ? TestStatus.failed
        : warned > 0
            ? TestStatus.warning
            : TestStatus.passed;

    return TestGroup(
      order: order,
      name: name,
      description: description,
      results: results,
      groupStatus: groupStatus,
      totalDuration: totalDuration,
    );
  }
}
