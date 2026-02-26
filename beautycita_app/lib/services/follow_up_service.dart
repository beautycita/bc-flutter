import 'supabase_client.dart';
import '../models/follow_up_question.dart';

class FollowUpService {
  /// Returns follow-up questions for a service type, ordered by question_order.
  /// Returns empty list if service has no follow-up questions.
  Future<List<FollowUpQuestion>> getQuestions(String serviceType) async {
    if (!SupabaseClientService.isInitialized) {
      return [];
    }

    final client = SupabaseClientService.client;

    final data = await client
        .from('service_follow_up_questions')
        .select()
        .eq('service_type', serviceType)
        .order('question_order');

    return (data as List<dynamic>)
        .map((row) => FollowUpQuestion.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}
