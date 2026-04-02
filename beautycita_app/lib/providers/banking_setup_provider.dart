import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/providers/business_provider.dart';
import 'package:beautycita/services/supabase_client.dart';

/// Whether the current business has completed banking setup.
/// Returns true if CLABE and beneficiary_name are present and non-empty.
final bankingCompleteProvider = FutureProvider.autoDispose<bool>((ref) async {
  final biz = await ref.watch(currentBusinessProvider.future);
  if (biz == null) return false;

  final clabe = biz['clabe'] as String?;
  final beneficiary = biz['beneficiary_name'] as String?;

  return clabe != null &&
      clabe.isNotEmpty &&
      beneficiary != null &&
      beneficiary.isNotEmpty;
});

/// Banking info for the current business (clabe, beneficiary_name, bank detected).
final bankingInfoProvider =
    FutureProvider.autoDispose<Map<String, String?>>((ref) async {
  final biz = await ref.watch(currentBusinessProvider.future);
  if (biz == null) return {};

  return {
    'clabe': biz['clabe'] as String?,
    'beneficiary_name': biz['beneficiary_name'] as String?,
  };
});

/// Save banking details to the businesses table.
Future<void> saveBankingDetails({
  required String businessId,
  required String clabe,
  required String beneficiaryName,
}) async {
  await SupabaseClientService.client
      .from('businesses')
      .update({
        'clabe': clabe,
        'beneficiary_name': beneficiaryName,
      })
      .eq('id', businessId);
}
