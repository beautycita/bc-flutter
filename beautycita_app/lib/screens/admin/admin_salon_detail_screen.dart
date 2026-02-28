import 'package:flutter/material.dart';

/// Placeholder — full implementation in Task 8.
class AdminSalonDetailScreen extends StatelessWidget {
  final String businessId;

  const AdminSalonDetailScreen({super.key, required this.businessId});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Detalle del Salon')),
        body: Center(child: Text('Salon: $businessId')),
      );
}
