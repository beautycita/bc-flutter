import 'package:beautycita_core/supabase.dart';

/// Create a Stripe PaymentIntent via the edge function.
/// Returns a map with 'client_secret', 'customer_id', etc.
Future<Map<String, dynamic>> createWebPaymentIntent({
  required String serviceId,
  required String businessId,
  required String staffId,
  required String scheduledAt,
  required int amountCents,
  required String userId,
}) async {
  final response = await BCSupabase.client.functions.invoke(
    'create-payment-intent',
    body: {
      'service_id': serviceId,
      'business_id': businessId,
      'staff_id': staffId,
      'scheduled_at': scheduledAt,
      'amount': amountCents,
      'user_id': userId,
      'payment_type': 'full',
      'payment_method': 'card',
    },
  );

  if (response.status != 200) {
    throw Exception('Error al procesar pago: ${response.status}');
  }

  return response.data as Map<String, dynamic>;
}

/// Create the appointment record in the database.
Future<String> createAppointment({
  required String userId,
  required String businessId,
  required String staffId,
  required String serviceId,
  required String serviceName,
  required String serviceType,
  required String startsAt,
  required String endsAt,
  required double price,
  required String paymentIntentId,
}) async {
  final response = await BCSupabase.client
      .from(BCTables.appointments)
      .insert({
        'user_id': userId,
        'business_id': businessId,
        'staff_id': staffId,
        'service_id': serviceId,
        'service_name': serviceName,
        'service_type': serviceType,
        'starts_at': startsAt,
        'ends_at': endsAt,
        'price': price,
        'payment_intent_id': paymentIntentId,
        'payment_status': 'pending',
        'status': 'pending',
      })
      .select('id')
      .single();

  return response['id'] as String;
}
