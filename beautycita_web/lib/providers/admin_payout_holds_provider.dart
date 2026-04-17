import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';

/// A single active payout hold with denormalized business info.
class PayoutHoldRow {
  final String id;
  final String businessId;
  final String businessName;
  final String reason;
  final String? oldValue;
  final String? newValue;
  final DateTime startedAt;

  const PayoutHoldRow({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.reason,
    required this.oldValue,
    required this.newValue,
    required this.startedAt,
  });

  /// Human-readable label for the hold reason (matches DB check constraint values).
  String get reasonLabel {
    switch (reason) {
      case 'beneficiary_name_changed':
        return 'Cambio en Nombre del Beneficiario';
      case 'rfc_changed':
        return 'Cambio en RFC';
      case 'clabe_changed':
        return 'Cambio en CLABE';
      case 'stripe_account_changed':
        return 'Cambio en cuenta Stripe';
      case 'identity_mismatch':
        return 'Identidad no coincide con Stripe';
      case 'third_party_complaint':
        return 'Queja de tercero';
      case 'manual_admin':
        return 'Accion manual de admin';
      default:
        return reason;
    }
  }
}

/// All currently-active payout holds (released_at IS NULL), newest first,
/// joined with the business name for the UI.
final activePayoutHoldsProvider =
    FutureProvider.autoDispose<List<PayoutHoldRow>>((ref) async {
  if (!BCSupabase.isInitialized) return const [];

  final rows = await BCSupabase.client
      .from('payout_holds')
      .select('id, business_id, reason, old_value, new_value, started_at, businesses(name)')
      .filter('released_at', 'is', null)
      .order('started_at', ascending: false);

  return (rows as List<dynamic>).map((r) {
    final row = r as Map<String, dynamic>;
    final biz = row['businesses'] as Map<String, dynamic>?;
    return PayoutHoldRow(
      id: row['id'] as String,
      businessId: row['business_id'] as String,
      businessName: biz?['name'] as String? ?? '(sin nombre)',
      reason: row['reason'] as String,
      oldValue: row['old_value'] as String?,
      newValue: row['new_value'] as String?,
      startedAt: DateTime.parse(row['started_at'] as String),
    );
  }).toList();
});

/// Calls the release_payout_hold admin RPC. Returns null on success or an error string.
Future<String?> releasePayoutHold({
  required String holdId,
  required String note,
}) async {
  try {
    await BCSupabase.client.rpc(
      'release_payout_hold',
      params: {
        'p_hold_id': holdId,
        'p_note': note,
      },
    );
    return null;
  } catch (e) {
    return e.toString();
  }
}
