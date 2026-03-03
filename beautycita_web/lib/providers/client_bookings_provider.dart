import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/models.dart';
import 'package:beautycita_core/supabase.dart';

// ── Tab enum ─────────────────────────────────────────────────────────────────

enum BookingsTab { upcoming, past, cancelled }

// ── State ────────────────────────────────────────────────────────────────────

@immutable
class ClientBookingsState {
  final List<Booking> bookings;
  final bool isLoading;
  final String? error;
  final BookingsTab activeTab;

  const ClientBookingsState({
    this.bookings = const [],
    this.isLoading = false,
    this.error,
    this.activeTab = BookingsTab.upcoming,
  });

  ClientBookingsState copyWith({
    List<Booking>? bookings,
    bool? isLoading,
    String? error,
    BookingsTab? activeTab,
    bool clearError = false,
  }) {
    return ClientBookingsState(
      bookings: bookings ?? this.bookings,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      activeTab: activeTab ?? this.activeTab,
    );
  }

  // ── Filtered getters ───────────────────────────────────────────────────

  List<Booking> get upcoming {
    final now = DateTime.now();
    return bookings
        .where((b) =>
            b.scheduledAt.isAfter(now) &&
            b.status != 'cancelled_customer' &&
            b.status != 'cancelled_business' &&
            b.status != 'no_show' &&
            b.status != 'completed')
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  List<Booking> get past {
    final now = DateTime.now();
    return bookings
        .where((b) =>
            b.scheduledAt.isBefore(now) ||
            b.status == 'completed')
        .where((b) =>
            b.status != 'cancelled_customer' &&
            b.status != 'cancelled_business')
        .toList()
      ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
  }

  List<Booking> get cancelled {
    return bookings
        .where((b) =>
            b.status == 'cancelled_customer' ||
            b.status == 'cancelled_business')
        .toList()
      ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
  }

  List<Booking> get activeList {
    switch (activeTab) {
      case BookingsTab.upcoming:
        return upcoming;
      case BookingsTab.past:
        return past;
      case BookingsTab.cancelled:
        return cancelled;
    }
  }
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class ClientBookingsNotifier extends StateNotifier<ClientBookingsState> {
  ClientBookingsNotifier() : super(const ClientBookingsState());

  Future<void> fetchBookings() async {
    if (!BCSupabase.isInitialized || !BCSupabase.isAuthenticated) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final userId = BCSupabase.currentUserId!;
      final data = await BCSupabase.client
          .from(BCTables.appointments)
          .select(
            'id, user_id, business_id, service_id, service_name, service_type, '
            'starts_at, ends_at, status, price, payment_status, notes, '
            'created_at, transport_mode, deposit_amount, updated_at, '
            'businesses!appointments_business_id_fkey(name)',
          )
          .eq('user_id', userId)
          .order('starts_at', ascending: false);

      final bookings = (data as List)
          .map((row) => Booking.fromJson(row as Map<String, dynamic>))
          .toList();

      state = state.copyWith(bookings: bookings, isLoading: false);
    } catch (e, st) {
      debugPrint('ClientBookings error: $e\n${st.toString().split('\n').take(5).join('\n')}');
      state = state.copyWith(
        isLoading: false,
        error: 'No se pudieron cargar tus citas',
      );
    }
  }

  Future<bool> cancelBooking(String id) async {
    try {
      await BCSupabase.client
          .from(BCTables.appointments)
          .update({'status': 'cancelled_customer'})
          .eq('id', id);

      // Update local state
      state = state.copyWith(
        bookings: state.bookings.map((b) {
          if (b.id == id) return b.copyWith(status: 'cancelled_customer');
          return b;
        }).toList(),
      );
      return true;
    } catch (e) {
      debugPrint('Cancel booking error: $e');
      return false;
    }
  }

  void setTab(BookingsTab tab) {
    state = state.copyWith(activeTab: tab);
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final clientBookingsProvider =
    StateNotifierProvider<ClientBookingsNotifier, ClientBookingsState>(
  (ref) => ClientBookingsNotifier(),
);
