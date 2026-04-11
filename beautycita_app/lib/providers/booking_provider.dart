import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/models/booking.dart';
import 'package:beautycita/repositories/booking_repository.dart';
import 'package:beautycita/services/supabase_client.dart';

/// Repository provider for BookingRepository.
final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepository();
});

/// All bookings for the current user.
final userBookingsProvider = FutureProvider<List<Booking>>((ref) async {
  final repository = ref.watch(bookingRepositoryProvider);
  return repository.getUserBookings();
});

/// Upcoming bookings (future, not cancelled) for the current user.
final upcomingBookingsProvider = FutureProvider<List<Booking>>((ref) async {
  final repository = ref.watch(bookingRepositoryProvider);
  return repository.getUpcomingBookings();
});

/// Available slot with staff assignment.
class AvailableSlot {
  final String staffId;
  final String staffName;
  final DateTime slotStart;
  final DateTime slotEnd;

  const AvailableSlot({
    required this.staffId,
    required this.staffName,
    required this.slotStart,
    required this.slotEnd,
  });

  /// Display time as HH:mm
  String get timeLabel =>
      '${slotStart.hour.toString().padLeft(2, '0')}:${slotStart.minute.toString().padLeft(2, '0')}';
}

/// Params: (businessId, serviceId, date, durationMinutes)
typedef SlotQuery = ({String businessId, String serviceId, DateTime date, int durationMinutes});

/// Fetches real available slots by querying find_available_slots RPC
/// for every staff member who can perform the selected service.
final availableSlotsProvider =
    FutureProvider.family<List<AvailableSlot>, SlotQuery>((ref, query) async {
  final client = SupabaseClientService.client;

  // 1. Find staff who can perform this service at this business
  final staffRows = await client
      .from('staff_services')
      .select('staff_id, staff:staff_id(id, first_name, last_name, business_id)')
      .eq('service_id', query.serviceId);

  final staffList = (staffRows as List).whereType<Map<String, dynamic>>().toList();
  // Filter to staff belonging to this business
  final bizStaff = staffList.where((s) {
    final staff = s['staff'] as Map<String, dynamic>?;
    return staff?['business_id'] == query.businessId;
  }).toList();

  if (bizStaff.isEmpty) return [];

  // 2. Query available slots for each staff member
  final dayStart = DateTime(query.date.year, query.date.month, query.date.day);
  final dayEnd = dayStart.add(const Duration(hours: 23, minutes: 59));

  final allSlots = <AvailableSlot>[];

  for (final row in bizStaff) {
    final staffData = row['staff'] as Map<String, dynamic>;
    final staffId = staffData['id'] as String;
    final staffName = '${staffData['first_name'] ?? ''} ${staffData['last_name'] ?? ''}'.trim();

    final slots = await client.rpc('find_available_slots', params: {
      'p_staff_id': staffId,
      'p_duration_minutes': query.durationMinutes,
      'p_window_start': dayStart.toUtc().toIso8601String(),
      'p_window_end': dayEnd.toUtc().toIso8601String(),
    });

    for (final s in (slots as List)) {
      allSlots.add(AvailableSlot(
        staffId: staffId,
        staffName: staffName,
        slotStart: DateTime.tryParse(s['slot_start'] as String? ?? '')?.toLocal() ?? DateTime.now(),
        slotEnd: DateTime.tryParse(s['slot_end'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      ));
    }
  }

  // 3. Sort by time
  allSlots.sort((a, b) => a.slotStart.compareTo(b.slotStart));
  return allSlots;
});
