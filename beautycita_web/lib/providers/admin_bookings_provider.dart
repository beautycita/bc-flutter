import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';

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
    return AdminBooking(
      id: id,
      shortId: id.length > 8 ? id.substring(0, 8) : id,
      clientName: json['client_name'] as String? ??
          (json['profiles'] is Map
              ? (json['profiles']['display_name'] as String? ?? 'Cliente')
              : 'Cliente'),
      clientId: json['client_id'] as String?,
      salonName: json['salon_name'] as String? ??
          (json['businesses'] is Map
              ? (json['businesses']['name'] as String? ?? 'Salon')
              : 'Salon'),
      salonId: json['business_id'] as String?,
      service: json['service_name'] as String? ?? 'Servicio',
      dateTime:
          DateTime.tryParse(json['scheduled_at'] as String? ?? '') ??
              DateTime.now(),
      durationMinutes: json['duration_minutes'] as int? ?? 60,
      status: json['status'] as String? ?? 'pending',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      paymentMethod: json['payment_method'] as String?,
      paymentIntentId: json['payment_intent_id'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      confirmedAt:
          DateTime.tryParse(json['confirmed_at'] as String? ?? ''),
      completedAt:
          DateTime.tryParse(json['completed_at'] as String? ?? ''),
      cancelledAt:
          DateTime.tryParse(json['cancelled_at'] as String? ?? ''),
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
      'id, client_id, business_id, service_name, scheduled_at, '
      'duration_minutes, status, amount, payment_status, payment_method, '
      'payment_intent_id, notes, created_at, confirmed_at, completed_at, '
      'cancelled_at, '
      'profiles!appointments_client_id_fkey(display_name), '
      'businesses!appointments_business_id_fkey(name)',
    );

    // Apply equality/range filters (these keep PostgrestFilterBuilder type)
    if (filter.status != null) {
      query = query.eq('status', filter.status!);
    }
    if (filter.dateFrom != null) {
      query = query.gte(
          'scheduled_at', filter.dateFrom!.toIso8601String());
    }
    if (filter.dateTo != null) {
      query = query.lte(
        'scheduled_at',
        filter.dateTo!
            .add(const Duration(days: 1))
            .toIso8601String(),
      );
    }

    // .or() returns PostgrestTransformBuilder — chain order+range after it
    final sortCol = filter.sortColumn ?? 'scheduled_at';
    final from = filter.page * filter.pageSize;
    final to = from + filter.pageSize - 1;

    final List data;
    if (filter.searchText.isNotEmpty) {
      data = await query
          .or('service_name.ilike.%${filter.searchText}%')
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
          'scheduled_at', filter.dateFrom!.toIso8601String());
    }
    if (filter.dateTo != null) {
      countQuery = countQuery.lte(
        'scheduled_at',
        filter.dateTo!
            .add(const Duration(days: 1))
            .toIso8601String(),
      );
    }
    final int totalCount;
    if (filter.searchText.isNotEmpty) {
      final r = await countQuery
          .or('service_name.ilike.%${filter.searchText}%')
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
