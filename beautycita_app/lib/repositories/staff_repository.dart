import 'package:beautycita/services/supabase_client.dart';

class StaffRepository {
  /// Fetch all staff for a given business, ordered by sort_order.
  Future<List<Map<String, dynamic>>> getStaff(String bizId) async {
    final response = await SupabaseClientService.client
        .from('staff')
        .select()
        .eq('business_id', bizId)
        .order('sort_order');
    return (response as List).cast<Map<String, dynamic>>();
  }

  /// Update specific fields on a staff record.
  Future<void> updateStaff(String id, Map<String, dynamic> data) async {
    await SupabaseClientService.client
        .from('staff')
        .update(data)
        .eq('id', id);
  }

  /// Toggle the is_active flag on a staff record.
  Future<void> toggleActive(String id) async {
    // Fetch current value first
    final row = await SupabaseClientService.client
        .from('staff')
        .select('is_active')
        .eq('id', id)
        .single();
    final current = row['is_active'] as bool? ?? true;
    await SupabaseClientService.client
        .from('staff')
        .update({'is_active': !current})
        .eq('id', id);
  }
}
