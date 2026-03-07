import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/beautycita_core.dart';
import '../services/supabase_client.dart';
import '../providers/business_provider.dart';

// ---------------------------------------------------------------------------
// All photos for a business (sorted by sort_order)
// ---------------------------------------------------------------------------

final portfolioPhotosProvider = FutureProvider.autoDispose
    .family<List<PortfolioPhoto>, String>((ref, businessId) async {
  final data = await SupabaseClientService.client
      .from('portfolio_photos')
      .select()
      .eq('business_id', businessId)
      .order('sort_order');

  return (data as List)
      .map((e) => PortfolioPhoto.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ---------------------------------------------------------------------------
// Photos for a specific staff member (visible only)
// ---------------------------------------------------------------------------

final staffPhotosProvider = FutureProvider.autoDispose
    .family<List<PortfolioPhoto>, ({String businessId, String staffId})>(
        (ref, params) async {
  final data = await SupabaseClientService.client
      .from('portfolio_photos')
      .select()
      .eq('business_id', params.businessId)
      .eq('staff_id', params.staffId)
      .eq('is_visible', true)
      .order('sort_order');

  return (data as List)
      .map((e) => PortfolioPhoto.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ---------------------------------------------------------------------------
// Portfolio config for the current business owner
// ---------------------------------------------------------------------------

final portfolioConfigProvider =
    FutureProvider.autoDispose<PortfolioConfig?>((ref) async {
  final biz = await ref.watch(currentBusinessProvider.future);
  if (biz == null) return null;
  return PortfolioConfig.fromJson(biz);
});

// ---------------------------------------------------------------------------
// Agreement acceptance check
// ---------------------------------------------------------------------------

final portfolioAgreementProvider = FutureProvider.autoDispose
    .family<bool, ({String businessId, String version})>(
        (ref, params) async {
  final data = await SupabaseClientService.client
      .from('portfolio_agreements')
      .select('id')
      .eq('business_id', params.businessId)
      .eq('agreement_type', 'portfolio')
      .eq('agreement_version', params.version)
      .maybeSingle();

  return data != null;
});
