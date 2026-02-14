import 'package:flutter/foundation.dart';
import 'package:beautycita/services/supabase_client.dart';

/// BTCPay invoice data returned from edge function
class BTCPayInvoice {
  final String invoiceId;
  final String checkoutLink;
  final double amount;
  final double depositAmount;
  final double platformFee;
  final double providerReceives;
  final String currency;
  final DateTime? expiresAt;

  const BTCPayInvoice({
    required this.invoiceId,
    required this.checkoutLink,
    required this.amount,
    required this.depositAmount,
    required this.platformFee,
    required this.providerReceives,
    required this.currency,
    this.expiresAt,
  });

  factory BTCPayInvoice.fromJson(Map<String, dynamic> json) {
    return BTCPayInvoice(
      invoiceId: json['invoice_id'] as String,
      checkoutLink: json['checkout_link'] as String,
      amount: (json['amount'] as num).toDouble(),
      depositAmount: (json['deposit_amount'] as num?)?.toDouble() ?? 0,
      platformFee: (json['platform_fee'] as num).toDouble(),
      providerReceives: (json['provider_receives'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'MXN',
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
    );
  }
}

/// Service for interacting with BTCPay Server via edge functions
class BTCPayService {
  BTCPayService._();

  /// Create a Bitcoin invoice for a booking
  static Future<BTCPayInvoice> createInvoice({
    required String serviceId,
    required String scheduledAt,
    String? staffId,
    String paymentType = 'full',
  }) async {
    if (!SupabaseClientService.isInitialized) {
      throw Exception('Supabase not initialized');
    }

    try {
      final response = await SupabaseClientService.client.functions.invoke(
        'btcpay-invoice',
        body: {
          'service_id': serviceId,
          'scheduled_at': scheduledAt,
          if (staffId != null) 'staff_id': staffId,
          'payment_type': paymentType,
        },
      );

      if (response.status != 200) {
        final data = response.data as Map<String, dynamic>?;
        throw Exception(data?['error'] ?? 'Failed to create Bitcoin invoice');
      }

      final data = response.data as Map<String, dynamic>;
      if (data['error'] != null) {
        throw Exception(data['error']);
      }

      return BTCPayInvoice.fromJson(data);
    } catch (e) {
      debugPrint('BTCPayService.createInvoice error: $e');
      rethrow;
    }
  }
}
