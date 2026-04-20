// Tests for the pure (non-Supabase) surface of business_provider.
//
// Every FutureProvider here touches Supabase — those are covered by the
// business-side flows in bughunter. Here we pin the plain value types
// that back the dashboard:
//   - BusinessStats.empty()
//   - StaffProductivityEntry field packing
//   - StaffProductivityData.empty() / topEarner / mostReviewed / mostBooked
//     / totalRevenue / totalHours — including null guards on empty lists
//   - StaffCommissionSummary.totalAmount
//   - StaffCommissionsData.empty() / totalMonth

import 'package:flutter_test/flutter_test.dart';
import 'package:beautycita/providers/business_provider.dart';

void main() {
  // ---------------------------------------------------------------------------
  // BusinessStats
  // ---------------------------------------------------------------------------
  group('BusinessStats.empty', () {
    test('returns all-zero stats', () {
      final stats = BusinessStats.empty();
      expect(stats.appointmentsToday, 0);
      expect(stats.appointmentsWeek, 0);
      expect(stats.revenueMonth, 0);
      expect(stats.pendingConfirmations, 0);
      expect(stats.averageRating, 0);
      expect(stats.totalReviews, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // StaffProductivityData
  // ---------------------------------------------------------------------------
  StaffProductivityEntry makeEntry({
    String staffId = 'staff-1',
    String firstName = 'Maria',
    int totalAppointments = 0,
    int completedAppointments = 0,
    int noShows = 0,
    double revenue = 0,
    double hoursWorked = 0,
    int reviewCount = 0,
    double avgRating = 0,
  }) {
    return StaffProductivityEntry(
      staffId: staffId,
      name: '$firstName Lopez',
      firstName: firstName,
      totalAppointments: totalAppointments,
      completedAppointments: completedAppointments,
      noShows: noShows,
      revenue: revenue,
      hoursWorked: hoursWorked,
      dailyHours: const {},
      reviewCount: reviewCount,
      avgRating: avgRating,
      allTimeRating: 0,
      allTimeReviews: 0,
    );
  }

  group('StaffProductivityData.empty', () {
    test('has empty entries and week period', () {
      final data = StaffProductivityData.empty();
      expect(data.entries, isEmpty);
      expect(data.period, 'week');
      expect(data.ownerId, isNull);
    });

    test('topEarner / mostReviewed / mostBooked are null on empty', () {
      final data = StaffProductivityData.empty();
      expect(data.topEarner, isNull);
      expect(data.mostReviewed, isNull);
      expect(data.mostBooked, isNull);
    });

    test('totalRevenue / totalHours are 0 on empty', () {
      final data = StaffProductivityData.empty();
      expect(data.totalRevenue, 0);
      expect(data.totalHours, 0);
    });
  });

  group('StaffProductivityData reducers', () {
    test('topEarner picks the entry with max revenue', () {
      final data = StaffProductivityData(
        period: 'month',
        entries: [
          makeEntry(staffId: 'a', firstName: 'Ana', revenue: 1200),
          makeEntry(staffId: 'b', firstName: 'Beto', revenue: 3400),
          makeEntry(staffId: 'c', firstName: 'Cata', revenue: 900),
        ],
      );
      expect(data.topEarner?.staffId, 'b');
    });

    test('mostReviewed picks the entry with max reviewCount', () {
      final data = StaffProductivityData(
        period: 'month',
        entries: [
          makeEntry(staffId: 'a', reviewCount: 2),
          makeEntry(staffId: 'b', reviewCount: 9),
          makeEntry(staffId: 'c', reviewCount: 5),
        ],
      );
      expect(data.mostReviewed?.staffId, 'b');
    });

    test('mostBooked picks the entry with max totalAppointments', () {
      final data = StaffProductivityData(
        period: 'week',
        entries: [
          makeEntry(staffId: 'a', totalAppointments: 4),
          makeEntry(staffId: 'b', totalAppointments: 1),
          makeEntry(staffId: 'c', totalAppointments: 12),
        ],
      );
      expect(data.mostBooked?.staffId, 'c');
    });

    test('totalRevenue sums across entries', () {
      final data = StaffProductivityData(
        period: 'month',
        entries: [
          makeEntry(staffId: 'a', revenue: 100.5),
          makeEntry(staffId: 'b', revenue: 250.25),
          makeEntry(staffId: 'c', revenue: 49.25),
        ],
      );
      expect(data.totalRevenue, closeTo(400.0, 0.001));
    });

    test('totalHours sums across entries', () {
      final data = StaffProductivityData(
        period: 'week',
        entries: [
          makeEntry(staffId: 'a', hoursWorked: 8),
          makeEntry(staffId: 'b', hoursWorked: 6.5),
          makeEntry(staffId: 'c', hoursWorked: 3.25),
        ],
      );
      expect(data.totalHours, closeTo(17.75, 0.001));
    });

    test('reducers with single entry return that entry', () {
      final only = makeEntry(
        staffId: 'solo',
        revenue: 500,
        reviewCount: 3,
        totalAppointments: 4,
      );
      final data = StaffProductivityData(period: 'week', entries: [only]);
      expect(data.topEarner?.staffId, 'solo');
      expect(data.mostReviewed?.staffId, 'solo');
      expect(data.mostBooked?.staffId, 'solo');
    });
  });

  // ---------------------------------------------------------------------------
  // StaffCommissionSummary / StaffCommissionsData
  // ---------------------------------------------------------------------------
  group('StaffCommissionSummary', () {
    test('totalAmount = pending + paid', () {
      const summary = StaffCommissionSummary(
        staffId: 'staff-1',
        firstName: 'Maria',
        pendingAmount: 125.50,
        paidAmount: 74.50,
        pendingCount: 2,
        paidCount: 1,
      );
      expect(summary.totalAmount, 200.0);
    });

    test('totalAmount with zero paid is just pending', () {
      const summary = StaffCommissionSummary(
        staffId: 'staff-2',
        firstName: 'Ana',
        pendingAmount: 88,
        paidAmount: 0,
        pendingCount: 3,
        paidCount: 0,
      );
      expect(summary.totalAmount, 88);
    });
  });

  group('StaffCommissionsData', () {
    test('empty() has zero totals and no entries', () {
      final data = StaffCommissionsData.empty();
      expect(data.entries, isEmpty);
      expect(data.totalPending, 0);
      expect(data.totalPaid, 0);
      expect(data.totalMonth, 0);
    });

    test('totalMonth = totalPending + totalPaid', () {
      const data = StaffCommissionsData(
        entries: [],
        totalPending: 1500,
        totalPaid: 500,
      );
      expect(data.totalMonth, 2000);
    });
  });
}
