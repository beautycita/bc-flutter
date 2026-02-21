import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:beautycita/services/supabase_client.dart';

/// BTC price in USD and MXN
class BtcPrice {
  final double usd;
  final double mxn;
  final DateTime fetchedAt;

  const BtcPrice({required this.usd, required this.mxn, required this.fetchedAt});

  String get formattedMxn {
    final f = NumberFormat('#,##0', 'es_MX');
    return f.format(mxn);
  }

  String get formattedUsd {
    final f = NumberFormat('#,##0', 'en_US');
    return f.format(usd);
  }
}

/// User wallet info from BTCPay
class BtcWallet {
  final int id;
  final String? walletAddress;
  final String? label;
  final String? btcpayInvoiceId;
  final String? checkoutLink;
  final DateTime createdAt;

  const BtcWallet({
    required this.id,
    this.walletAddress,
    this.label,
    this.btcpayInvoiceId,
    this.checkoutLink,
    required this.createdAt,
  });

  factory BtcWallet.fromJson(Map<String, dynamic> json) {
    return BtcWallet(
      id: json['id'] as int,
      walletAddress: json['wallet_address'] as String?,
      label: json['label'] as String?,
      btcpayInvoiceId: json['btcpay_invoice_id'] as String?,
      checkoutLink: json['checkout_link'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// User balance info
class BtcBalance {
  final double balanceUsd;
  final double balanceMxn;
  final double totalDepositedBtc;
  final double totalDepositedUsd;
  final double totalDepositedMxn;

  const BtcBalance({
    this.balanceUsd = 0,
    this.balanceMxn = 0,
    this.totalDepositedBtc = 0,
    this.totalDepositedUsd = 0,
    this.totalDepositedMxn = 0,
  });

  factory BtcBalance.fromJson(Map<String, dynamic> json) {
    return BtcBalance(
      balanceUsd: _toDouble(json['balance_usd']),
      balanceMxn: _toDouble(json['balance_mxn']),
      totalDepositedBtc: _toDouble(json['total_deposited_btc']),
      totalDepositedUsd: _toDouble(json['total_deposited_usd']),
      totalDepositedMxn: _toDouble(json['total_deposited_mxn']),
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

/// A single deposit record
class BtcDeposit {
  final int id;
  final String? txid;
  final double amountBtc;
  final double amountMxn;
  final int confirmations;
  final String status;
  final DateTime? detectedAt;
  final DateTime? confirmedAt;

  const BtcDeposit({
    required this.id,
    this.txid,
    this.amountBtc = 0,
    this.amountMxn = 0,
    this.confirmations = 0,
    this.status = 'pending',
    this.detectedAt,
    this.confirmedAt,
  });

  factory BtcDeposit.fromJson(Map<String, dynamic> json) {
    return BtcDeposit(
      id: json['id'] as int,
      txid: json['txid'] as String?,
      amountBtc: BtcBalance._toDouble(json['amount_btc']),
      amountMxn: BtcBalance._toDouble(json['amount_mxn']),
      confirmations: (json['confirmations'] as int?) ?? 0,
      status: json['status'] as String? ?? 'pending',
      detectedAt: DateTime.tryParse(json['detected_at'] as String? ?? ''),
      confirmedAt: DateTime.tryParse(json['confirmed_at'] as String? ?? ''),
    );
  }
}

/// A balance transaction record
class BtcTransaction {
  final int id;
  final String type;
  final double amountMxn;
  final String? description;
  final DateTime createdAt;

  const BtcTransaction({
    required this.id,
    this.type = '',
    this.amountMxn = 0,
    this.description,
    required this.createdAt,
  });

  factory BtcTransaction.fromJson(Map<String, dynamic> json) {
    return BtcTransaction(
      id: json['id'] as int,
      type: json['transaction_type'] as String? ?? '',
      amountMxn: BtcBalance._toDouble(json['amount_mxn']),
      description: json['description'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

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

/// Service for interacting with BTCPay Server directly and via edge functions
class BTCPayService {
  BTCPayService._();

  static const String _btcpayBase = 'https://beautycita.com/btcpay';
  static const String _btcpayApiKey = 'c1abd88fda4af3d5861f7cd33c3f3f83dc37e5dc';
  static const String _btcpayStoreId = '9XbJqLfMLdCj8ezecxthj41wk4GpDe27ajw66a9ULY2V';

  static Map<String, String> get _btcpayHeaders => {
    'Authorization': 'token $_btcpayApiKey',
    'Content-Type': 'application/json',
  };

  /// Fetch live BTC price from BTCPay Server rates + forex for MXN
  static Future<BtcPrice?> getPrice() async {
    try {
      // Get BTC_USD from BTCPay's configured rate source
      final ratesResp = await http.get(
        Uri.parse('$_btcpayBase/api/v1/stores/$_btcpayStoreId/rates?currencyPair=BTC_USD'),
        headers: _btcpayHeaders,
      ).timeout(const Duration(seconds: 10));

      if (ratesResp.statusCode != 200) return null;
      final ratesList = jsonDecode(ratesResp.body) as List<dynamic>;
      if (ratesList.isEmpty) return null;

      final btcUsdEntry = ratesList[0] as Map<String, dynamic>;
      final btcUsdRate = btcUsdEntry['rate'];
      if (btcUsdRate == null) return null;
      final usd = double.parse(btcUsdRate.toString());

      // Get USD_MXN from free forex API
      double mxn = usd * 17.0; // fallback
      try {
        final fxResp = await http.get(
          Uri.parse('https://open.er-api.com/v6/latest/USD'),
        ).timeout(const Duration(seconds: 5));
        if (fxResp.statusCode == 200) {
          final fxJson = jsonDecode(fxResp.body) as Map<String, dynamic>;
          final rates = fxJson['rates'] as Map<String, dynamic>?;
          if (rates != null && rates['MXN'] != null) {
            final usdMxn = (rates['MXN'] as num).toDouble();
            mxn = usd * usdMxn;
          }
        }
      } catch (_) {
        // use fallback
      }

      return BtcPrice(usd: usd, mxn: mxn, fetchedAt: DateTime.now());
    } catch (e) {
      debugPrint('BTCPayService.getPrice error: $e');
      return null;
    }
  }

  /// Create a BTCPay invoice to generate a deposit address
  static Future<BtcWallet?> getWallet() async {
    try {
      final resp = await http.post(
        Uri.parse('$_btcpayBase/api/v1/stores/$_btcpayStoreId/invoices'),
        headers: _btcpayHeaders,
        body: jsonEncode({
          'currency': 'BTC',
          'metadata': {'purpose': 'deposit_wallet'},
          'checkout': {
            'expirationMinutes': 525600, // 1 year
            'paymentMethods': ['BTC', 'BTC-LightningNetwork'],
          },
        }),
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode != 200) {
        debugPrint('BTCPayService.getWallet: status ${resp.statusCode} body ${resp.body}');
        return null;
      }

      final invoice = jsonDecode(resp.body) as Map<String, dynamic>;
      final invoiceId = invoice['id'] as String?;
      if (invoiceId == null) return null;

      // Fetch the payment methods to get the on-chain address
      final pmResp = await http.get(
        Uri.parse('$_btcpayBase/api/v1/stores/$_btcpayStoreId/invoices/$invoiceId/payment-methods'),
        headers: _btcpayHeaders,
      ).timeout(const Duration(seconds: 10));

      String? btcAddress;
      if (pmResp.statusCode == 200) {
        final methods = jsonDecode(pmResp.body) as List<dynamic>;
        for (final m in methods) {
          final pm = m as Map<String, dynamic>;
          if (pm['paymentMethod'] == 'BTC' || pm['paymentMethodId'] == 'BTC') {
            btcAddress = pm['destination'] as String?;
            break;
          }
        }
      }

      return BtcWallet(
        id: 0,
        walletAddress: btcAddress ?? invoice['checkoutLink'] as String?,
        label: 'BeautyCita Deposit',
        btcpayInvoiceId: invoiceId,
        checkoutLink: invoice['checkoutLink'] as String?,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('BTCPayService.getWallet error: $e');
      return null;
    }
  }

  /// Get user's balance (placeholder — no backend route active)
  static Future<BtcBalance> getBalance() async {
    return const BtcBalance();
  }

  /// Get deposit history (placeholder — no backend route active)
  static Future<List<BtcDeposit>> getDeposits({int limit = 20}) async {
    return [];
  }

  /// Get balance transaction history (placeholder — no backend route active)
  static Future<List<BtcTransaction>> getTransactions({int limit = 20}) async {
    return [];
  }

  static String? get _authToken {
    if (!SupabaseClientService.isInitialized) return null;
    return SupabaseClientService.client.auth.currentSession?.accessToken;
  }

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
