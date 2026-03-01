import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';

/// Strip PostgREST filter metacharacters to prevent filter injection via .or().
String _sanitize(String input) =>
    input.replaceAll(RegExp(r'[.,()\\]'), '').trim();

// ── Data classes ──────────────────────────────────────────────────────────────

@immutable
class AdminBooking {
  final String id;
  final String shortId;
  final String clientName;
  final String? clientId;
  final String salonName;
  final String? salonId;
  final String service;
  final DateTime dateTime;
  final int durationMinutes;
  final String status; // pending, confirmed, completed, cancelled, no_show
  final double amount;
  final String paymentStatus; // pending, paid, refunded, failed
  final String? paymentMethod;
  final String? paymentIntentId;
  final String? notes;
  final DateTime createdAt;
  final DateTime? confirmedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  const AdminBooking({
    required this.id,
    required this.shortId,
    required this.clientName,
    this.clientId,
    required this.salonName,
    this.salonId,
    required this.service,
    required this.dateTime,
    this.durationMinutes = 60,
    required this.status,
    this.amount = 0,
    this.paymentStatus = 'pending',
    this.paymentMethod,
    this.paymentIntentId,
    this.notes,
    required this.createdAt,
    this.confirmedAt,
    this.completedAt,
    this.cancelledAt,
  });

  factory AdminBooking.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    // Compute duration from starts_at/ends_at
    final startsAt = DateTime.tryParse(json['starts_at'] as String? ?? '');
    final endsAt = DateTime.tryParse(json['ends_at'] as String? ?? '');
    final duration = (startsAt != null && endsAt != null)
        ? endsAt.difference(startsAt).inMinutes
        : 60;

    return AdminBooking(
      id: id,
      shortId: id.length > 8 ? id.substring(0, 8) : id,
      clientName: json['profiles'] is Map
          ? (json['profiles']['full_name'] as String? ??
              json['profiles']['username'] as String? ??
              'Cliente')
          : 'Cliente',
      clientId: json['user_id'] as String?,
      salonName: json['businesses'] is Map
          ? (json['businesses']['name'] as String? ?? 'Salon')
          : 'Salon',
      salonId: json['business_id'] as String?,
      service: json['service_name'] as String? ?? 'Servicio',
      dateTime: startsAt ?? DateTime.now(),
      durationMinutes: duration,
      status: json['status'] as String? ?? 'pending',
      amount: (json['price'] as num?)?.toDouble() ?? 0,
      paymentStatus: json['payment_status'] as String? ?? 'unpaid',
      paymentMethod: null,
      paymentIntentId: json['payment_intent_id'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      confirmedAt: null,
      completedAt: null,
      cancelledAt: null,
    );
  }
}

@immutable
class BookingsPageData {
  final List<AdminBooking> bookings;
  final int totalCount;

  const BookingsPageData({
    required this.bookings,
    required this.totalCount,
  });

  static const empty = BookingsPageData(bookings: [], totalCount: 0);
}

// ── Filter state ──────────────────────────────────────────────────────────────

@immutable
class BookingsFilter {
  final String? status;
  final String searchText;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final int page;
  final int pageSize;
  final String? sortColumn;
  final bool sortAscending;

  const BookingsFilter({
    this.status,
    this.searchText = '',
    this.dateFrom,
    this.dateTo,
    this.page = 0,
    this.pageSize = 20,
    this.sortColumn,
    this.sortAscending = false, // newest first by default
  });

  BookingsFilter copyWith({
    String? Function()? status,
    String? searchText,
    DateTime? Function()? dateFrom,
    DateTime? Function()? dateTo,
    int? page,
    int? pageSize,
    String? Function()? sortColumn,
    bool? sortAscending,
  }) {
    return BookingsFilter(
      status: status != null ? status() : this.status,
      searchText: searchText ?? this.searchText,
      dateFrom: dateFrom != null ? dateFrom() : this.dateFrom,
      dateTo: dateTo != null ? dateTo() : this.dateTo,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      sortColumn: sortColumn != null ? sortColumn() : this.sortColumn,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }

  bool get hasActiveFilters =>
      status != null ||
      searchText.isNotEmpty ||
      dateFrom != null ||
      dateTo != null;
}

// ── Providers ─────────────────────────────────────────────────────────────────

final bookingsFilterProvider = StateProvider<BookingsFilter>(
  (ref) => const BookingsFilter(),
);

final adminBookingsProvider = FutureProvider<BookingsPageData>((ref) async {
  final filter = ref.watch(bookingsFilterProvider);

  if (!BCSupabase.isInitialized) return BookingsPageData.empty;

  try {
    final client = BCSupabase.client;

    // Main query with joins to profiles and businesses
    var query = client.from(BCTables.appointments).select(
      'id, user_id, business_id, service_name, starts_at, ends_at, '
      'status, price, payment_status, payment_intent_id, notes, created_at, '
      'profiles!appointments_user_id_fkey(full_name, username), '
      'businesses!appointments_business_id_fkey(name)',
    );

    // Apply equality/range filters (these keep PostgrestFilterBuilder type)
    if (filter.status != null) {
      query = query.eq('status', filter.status!);
    }
    if (filter.dateFrom != null) {
      query = query.gte(
          'starts_at', filter.dateFrom!.toIso8601String());
    }
    if (filter.dateTo != null) {
      query = query.lte(
        'starts_at',
        filter.dateTo!
            .add(const Duration(days: 1))
            .toIso8601String(),
      );
    }

    // .or() returns PostgrestTransformBuilder — chain order+range after it
    final sortCol = filter.sortColumn ?? 'starts_at';
    final from = filter.page * filter.pageSize;
    final to = from + filter.pageSize - 1;

    final List data;
    if (filter.searchText.isNotEmpty) {
      data = await query
          .or('service_name.ilike.%${_sanitize(filter.searchText)}%')
          .order(sortCol, ascending: filter.sortAscending)
          .range(from, to);
    } else {
      data = await query
          .order(sortCol, ascending: filter.sortAscending)
          .range(from, to);
    }

    // Count query — separate chain
    var countQuery = client.from(BCTables.appointments).select('id');
    if (filter.status != null) {
      countQuery = countQuery.eq('status', filter.status!);
    }
    if (filter.dateFrom != null) {
      countQuery = countQuery.gte(
          'starts_at', filter.dateFrom!.toIso8601String());
    }
    if (filter.dateTo != null) {
      countQuery = countQuery.lte(
        'starts_at',
        filter.dateTo!
            .add(const Duration(days: 1))
            .toIso8601String(),
      );
    }
    final int totalCount;
    if (filter.searchText.isNotEmpty) {
      final r = await countQuery
          .or('service_name.ilike.%${_sanitize(filter.searchText)}%')
          .count();
      totalCount = r.count;
    } else {
      final r = await countQuery.count();
      totalCount = r.count;
    }

    final bookings = data
        .map((row) => AdminBooking.fromJson(row as Map<String, dynamic>))
        .toList();

    return BookingsPageData(bookings: bookings, totalCount: totalCount);
  } catch (e) {
    debugPrint('Admin bookings error: $e');
    return BookingsPageData.empty;
  }
});
