// Provider for the Personas → Salones detail FinancialSummaryCard.
// Wraps the admin_salon_financial_summary RPC built in session 2a.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_client.dart';

class AdminSalonFinancialSummary {
  AdminSalonFinancialSummary({
    required this.saldo,
    required this.outstandingDebt,
    required this.revenue30d,
    required this.appointmentCount30d,
  });

  final double saldo;
  final double outstandingDebt;
  final double revenue30d;
  final int appointmentCount30d;

  factory AdminSalonFinancialSummary.fromRow(Map<String, dynamic> row) {
    return AdminSalonFinancialSummary(
      saldo: ((row['out_saldo'] ?? 0) as num).toDouble(),
      outstandingDebt: ((row['out_outstanding_debt'] ?? 0) as num).toDouble(),
      revenue30d: ((row['out_revenue_30d'] ?? 0) as num).toDouble(),
      appointmentCount30d: ((row['out_appointment_count_30d'] ?? 0) as num).toInt(),
    );
  }
}

final adminSalonFinancialSummaryProvider =
    FutureProvider.family<AdminSalonFinancialSummary?, String>((ref, businessId) async {
  final client = SupabaseClientService.client;
  final rows = await client.rpc(
    'admin_salon_financial_summary',
    params: {'p_business_id': businessId},
  );
  if (rows is List && rows.isNotEmpty) {
    return AdminSalonFinancialSummary.fromRow(rows.first as Map<String, dynamic>);
  }
  return null;
});
