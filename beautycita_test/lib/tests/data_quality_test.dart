import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/test_config.dart';
import '../core/test_case.dart';
import '../core/test_result.dart';

/// Test 02: Data Quality Scan
/// Queries prod DB and reports dirty, missing, or inconsistent data.
/// Every check tells BC something actionable about the state of his data.
class DataQualityTest extends TestSuite {
  @override
  int get order => 2;

  @override
  String get name => 'Data Quality Scan';

  @override
  String get description => 'Finds null fields, broken records, and data inconsistencies';

  SupabaseClient get _svc => SupabaseClient(TestConfig.supabaseUrl, TestConfig.supabaseServiceKey);

  @override
  Future<TestGroup> run(SupabaseClient client) async {
    final results = <TestResult>[];
    final svc = _svc;

    // --- BUSINESSES ---
    results.add(await runCase('Businesses: missing photo_url', () async {
      final data = await svc.from('businesses').select('id, name')
          .not('owner_id', 'is', null)
          .filter('photo_url', 'is', 'null');
      final count = (data as List).length;
      if (count == 0) return pass('Businesses: missing photo_url', detail: 'All registered businesses have photos');
      final names = (data).map((b) => b['name']).take(5).join(', ');
      return warn('Businesses: missing photo_url',
          '$count businesses have no photo. Gray avatar in results. ($names)',
          metrics: {'count': count});
    }));

    results.add(await runCase('Businesses: zero rating with reviews', () async {
      final data = await svc.from('businesses').select('id, name, average_rating, total_reviews')
          .not('owner_id', 'is', null)
          .eq('average_rating', 0);
      final count = (data as List).length;
      if (count == 0) return pass('Businesses: zero rating', detail: 'All businesses have ratings');
      final names = (data).map((b) => b['name']).take(5).join(', ');
      return warn('Businesses: zero rating',
          '$count businesses show 0.0 stars. ($names)',
          metrics: {'count': count});
    }));

    results.add(await runCase('Businesses: missing hours JSON', () async {
      final data = await svc.from('businesses').select('id, name')
          .not('owner_id', 'is', null)
          .filter('hours', 'is', 'null');
      final count = (data as List).length;
      if (count == 0) return pass('Businesses: hours set', detail: 'All businesses have schedules');
      return fail('Businesses: missing hours JSON',
          '$count businesses have no hours. Booking engine skips them entirely.');
    }));

    results.add(await runCase('Businesses: missing lat/lng', () async {
      final data = await svc.from('businesses').select('id, name')
          .not('owner_id', 'is', null)
          .or('lat.is.null,lng.is.null');
      final count = (data as List).length;
      if (count == 0) return pass('Businesses: geo coordinates set');
      return fail('Businesses: missing lat/lng',
          '$count businesses have no coordinates. Invisible to geo search.');
    }));

    results.add(await runCase('Businesses: onboarding bypass check', () async {
      // Salons that are onboarding_complete=true but missing real requirements
      final data = await svc.from('businesses').select('id, name, rfc, stripe_account_id')
          .not('owner_id', 'is', null)
          .eq('onboarding_complete', true);
      final businesses = data as List;
      final bypassed = businesses.where((b) {
        final stripe = b['stripe_account_id'] as String?;
        return stripe == null || stripe.isEmpty || stripe.startsWith('acct_test');
      }).toList();
      if (bypassed.isEmpty) return pass('Businesses: onboarding integrity', detail: 'All onboarded businesses have real Stripe');
      final names = bypassed.map((b) => b['name']).take(5).join(', ');
      return warn('Businesses: onboarding bypass check',
          '${bypassed.length} businesses have fake/missing Stripe accounts. ($names)',
          metrics: {'count': bypassed.length});
    }));

    // --- STAFF ---
    results.add(await runCase('Staff: missing avatar_url', () async {
      final data = await svc.from('staff').select('id, first_name, business_id')
          .eq('is_active', true)
          .filter('avatar_url', 'is', 'null');
      final count = (data as List).length;
      if (count == 0) return pass('Staff: all have avatars');
      return warn('Staff: missing avatar_url',
          '$count active staff have no photo. Gray circles on result cards.',
          metrics: {'count': count});
    }));

    results.add(await runCase('Staff: no schedule entries', () async {
      // Staff who have no staff_schedules rows — they can never get slots
      final staffData = await svc.from('staff').select('id, first_name').eq('is_active', true);
      final allStaff = staffData as List;

      final scheduledData = await svc.from('staff_schedules')
          .select('staff_id')
          .eq('is_available', true);
      final scheduledIds = (scheduledData as List).map((s) => s['staff_id']).toSet();

      final unscheduled = allStaff.where((s) => !scheduledIds.contains(s['id'])).toList();
      if (unscheduled.isEmpty) return pass('Staff: all have schedules');
      final names = unscheduled.map((s) => s['first_name']).take(5).join(', ');
      return warn('Staff: no schedule entries',
          '${unscheduled.length} active staff have no schedules. They can never appear in search. ($names)',
          metrics: {'count': unscheduled.length});
    }));

    results.add(await runCase('Staff: no service links', () async {
      final staffData = await svc.from('staff').select('id, first_name').eq('is_active', true);
      final allStaff = staffData as List;

      final linkedData = await svc.from('staff_services').select('staff_id');
      final linkedIds = (linkedData as List).map((s) => s['staff_id']).toSet();

      final unlinked = allStaff.where((s) => !linkedIds.contains(s['id'])).toList();
      if (unlinked.isEmpty) return pass('Staff: all linked to services');
      final names = unlinked.map((s) => s['first_name']).take(5).join(', ');
      return warn('Staff: no service links',
          '${unlinked.length} active staff have no service assignments. ($names)',
          metrics: {'count': unlinked.length});
    }));

    // --- SERVICES ---
    results.add(await runCase('Services: zero or null price', () async {
      final data = await svc.from('services').select('id, name, business_id')
          .eq('is_active', true)
          .or('price.is.null,price.eq.0');
      final count = (data as List).length;
      if (count == 0) return pass('Services: all have prices');
      return warn('Services: zero or null price',
          '$count active services have no price. Broken checkout.',
          metrics: {'count': count});
    }));

    // --- PROFILES ---
    results.add(await runCase('Profiles: missing phone', () async {
      final data = await svc.from('profiles').select('id, username')
          .filter('phone', 'is', 'null');
      final count = (data as List).length;
      if (count == 0) return pass('Profiles: all have phones');
      return warn('Profiles: missing phone',
          '$count profiles have no phone. Cannot receive WA notifications.',
          metrics: {'count': count});
    }));

    // --- DISCOVERED SALONS ---
    results.add(await runCase('Discovered salons: null location', () async {
      final countResp = await svc.from('discovered_salons').select('id', const FetchOptions(count: CountOption.exact, head: true))
          .or('latitude.is.null,longitude.is.null');
      final count = countResp.count ?? 0;
      if (count == 0) return pass('Discovered salons: all geolocated');
      return warn('Discovered salons: null location',
          '$count discovered salons have no coordinates. Cannot appear in fallback search.',
          metrics: {'count': count});
    }));

    final failed = results.where((r) => r.isFailed).length;
    final warned = results.where((r) => r.isWarning).length;
    final totalDuration = results.fold<Duration>(Duration.zero, (sum, r) => sum + r.duration);

    return TestGroup(
      order: order,
      name: name,
      description: description,
      results: results,
      groupStatus: failed > 0 ? TestStatus.failed : warned > 0 ? TestStatus.warning : TestStatus.passed,
      totalDuration: totalDuration,
    );
  }
}
