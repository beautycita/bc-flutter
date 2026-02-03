import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'supabase_client.dart';

/// Client-side Uber integration service.
/// Handles OAuth flow and provides helper methods for Uber-related operations.
class UberService {
  static const String _uberAuthUrl = 'https://login.uber.com/oauth/v2/authorize';

  final String clientId;
  final String redirectUri;

  UberService({
    required this.clientId,
    required this.redirectUri,
  });

  /// Build the OAuth authorization URL for Uber login.
  Uri buildAuthUrl({String scope = 'profile request'}) {
    return Uri.parse(_uberAuthUrl).replace(queryParameters: {
      'response_type': 'code',
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'scope': scope,
    });
  }

  /// Exchange an authorization code for tokens via the link-uber edge function.
  /// The edge function handles the token exchange server-side to keep
  /// client_secret off the device.
  Future<bool> linkAccount(String authCode) async {
    try {
      final client = SupabaseClientService.client;
      final response = await client.functions.invoke(
        'link-uber',
        body: {'auth_code': authCode},
      );

      if (response.status != 200) {
        debugPrint('link-uber failed: ${response.status}');
        return false;
      }

      final data = jsonDecode(response.data as String);
      return data['linked'] == true;
    } catch (e) {
      debugPrint('Uber link error: $e');
      return false;
    }
  }

  /// Unlink Uber account by clearing tokens server-side.
  Future<bool> unlinkAccount() async {
    try {
      final client = SupabaseClientService.client;
      final response = await client.functions.invoke(
        'link-uber',
        body: {'action': 'unlink'},
      );
      return response.status == 200;
    } catch (e) {
      debugPrint('Uber unlink error: $e');
      return false;
    }
  }

  /// Check if current user has a linked Uber account.
  Future<bool> isLinked() async {
    try {
      final client = SupabaseClientService.client;
      final userId = SupabaseClientService.currentUserId;
      if (userId == null) return false;

      final response = await client
          .from('profiles')
          .select('uber_linked')
          .eq('id', userId)
          .single();

      return response['uber_linked'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Schedule outbound + return Uber rides for an appointment.
  /// Returns the scheduling result or null on failure.
  /// If user's Uber is not linked, returns a result with scheduled=false.
  Future<UberScheduleResult> scheduleRides({
    required String appointmentId,
    required double pickupLat,
    required double pickupLng,
    required double salonLat,
    required double salonLng,
    String? salonAddress,
    required String appointmentAt,
    required int durationMinutes,
  }) async {
    try {
      final client = SupabaseClientService.client;
      final response = await client.functions.invoke(
        'schedule-uber',
        body: {
          'action': 'schedule',
          'appointment_id': appointmentId,
          'pickup_lat': pickupLat,
          'pickup_lng': pickupLng,
          'salon_lat': salonLat,
          'salon_lng': salonLng,
          'salon_address': salonAddress,
          'appointment_at': appointmentAt,
          'duration_minutes': durationMinutes,
        },
      );

      if (response.status == 401) {
        // Uber not linked or token expired
        return const UberScheduleResult(
          scheduled: false,
          reason: 'uber_not_linked',
        );
      }

      if (response.status != 200) {
        debugPrint('schedule-uber failed: ${response.status}');
        return const UberScheduleResult(
          scheduled: false,
          reason: 'api_error',
        );
      }

      final data = jsonDecode(response.data as String);
      return UberScheduleResult(
        scheduled: data['scheduled'] == true,
        outboundRequestId: data['outbound']?['uber_request_id'] as String?,
        returnRequestId: data['return_ride']?['uber_request_id'] as String?,
      );
    } catch (e) {
      debugPrint('Uber schedule error: $e');
      return UberScheduleResult(
        scheduled: false,
        reason: e.toString(),
      );
    }
  }

  /// Get a fare estimate for a ride (calls Uber Estimates API via edge function).
  Future<FareEstimate?> getFareEstimate({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    try {
      final client = SupabaseClientService.client;
      final response = await client.functions.invoke(
        'schedule-uber',
        body: {
          'action': 'estimate',
          'start_lat': startLat,
          'start_lng': startLng,
          'end_lat': endLat,
          'end_lng': endLng,
        },
      );

      if (response.status != 200) return null;

      final data = jsonDecode(response.data as String);
      return FareEstimate.fromJson(data);
    } catch (e) {
      debugPrint('Uber estimate error: $e');
      return null;
    }
  }
}

class FareEstimate {
  final double fareMin;
  final double fareMax;
  final String currency;
  final int durationMin;
  final double distanceKm;

  const FareEstimate({
    required this.fareMin,
    required this.fareMax,
    required this.currency,
    required this.durationMin,
    required this.distanceKm,
  });

  factory FareEstimate.fromJson(Map<String, dynamic> json) {
    return FareEstimate(
      fareMin: (json['fare_min'] as num).toDouble(),
      fareMax: (json['fare_max'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'MXN',
      durationMin: json['duration_min'] as int? ?? 0,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
    );
  }
}

class UberScheduleResult {
  final bool scheduled;
  final String? outboundRequestId;
  final String? returnRequestId;
  final String? reason;

  const UberScheduleResult({
    required this.scheduled,
    this.outboundRequestId,
    this.returnRequestId,
    this.reason,
  });
}
