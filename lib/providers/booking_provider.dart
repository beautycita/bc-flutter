import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/models/booking.dart';
import 'package:beautycita/repositories/booking_repository.dart';

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
