import 'package:flutter/material.dart';

void showLeadDetailSheet(BuildContext context, Map<String, dynamic> lead) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            lead['business_name']?.toString() ?? 'Sin nombre',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('${lead['location_city']}, ${lead['location_state']}'),
          Text('Status: ${lead['status']}'),
        ],
      ),
    ),
  );
}
