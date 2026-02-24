import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/models/booking.dart';
import 'package:beautycita/providers/booking_flow_provider.dart';

/// Single booking by ID, with joined business name.
final bookingDetailProvider =
    FutureProvider.family<Booking?, String>((ref, id) async {
  final repo = ref.watch(bookingRepositoryProvider);
  return repo.getBookingById(id);
});
