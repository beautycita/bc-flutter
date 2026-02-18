import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/constants.dart';
import '../../providers/admin_provider.dart';
import '../../services/supabase_client.dart';

class ApplicationsScreen extends ConsumerWidget {
  const ApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsAsync = ref.watch(adminApplicationsProvider);
    final colors = Theme.of(context).colorScheme;

    return appsAsync.when(
      data: (apps) {
        if (apps.isEmpty) {
          return Center(
            child: Text('Sin solicitudes',
                style: GoogleFonts.nunito(
                    color: colors.onSurface.withValues(alpha: 0.5))),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminApplicationsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(AppConstants.paddingMD),
            itemCount: apps.length,
            itemBuilder: (context, i) {
              final app = apps[i];
              return _ApplicationCard(app: app);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child:
            Text('Error: $e', style: GoogleFonts.nunito(color: colors.error)),
      ),
    );
  }
}

class _ApplicationCard extends ConsumerWidget {
  final Map<String, dynamic> app;
  const _ApplicationCard({required this.app});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final status = app['status'] as String? ?? 'pending';
    final categories = app['categories'] as List<dynamic>? ?? [];

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      ),
      margin: const EdgeInsets.only(bottom: AppConstants.paddingSM),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    app['business_name'] as String? ?? 'Sin nombre',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                ),
                _statusChip(status),
              ],
            ),
            const SizedBox(height: 6),
            if (app['owner_name'] != null)
              Text(
                'Propietario: ${app['owner_name']}',
                style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: colors.onSurface.withValues(alpha: 0.6)),
              ),
            if (app['phone'] != null)
              Text(
                'Tel: ${app['phone']}',
                style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: colors.onSurface.withValues(alpha: 0.6)),
              ),
            if (app['city'] != null)
              Text(
                'Ciudad: ${app['city']}',
                style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: colors.onSurface.withValues(alpha: 0.6)),
              ),
            if (categories.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: categories
                    .map((c) => Chip(
                          label: Text('$c',
                              style: GoogleFonts.nunito(fontSize: 11)),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ],
            if (status == 'pending') ...[
              const SizedBox(height: AppConstants.paddingSM),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _approve(context, ref),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green),
                      child: Text('Aprobar',
                          style: GoogleFonts.poppins(
                              fontSize: 13, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _rejectDialog(context, ref),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red),
                      child: Text('Rechazar',
                          style: GoogleFonts.poppins(
                              fontSize: 13, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final id = app['id'] as String;
    try {
      await SupabaseClientService.client
          .from('stylist_applications')
          .update({'status': 'approved'}).eq('id', id);
      await adminLogAction(
        action: 'approve_application',
        targetType: 'stylist_application',
        targetId: id,
      );
      ref.invalidate(adminApplicationsProvider);
      ref.invalidate(adminDashStatsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud aprobada')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _rejectDialog(BuildContext context, WidgetRef ref) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rechazar solicitud',
            style: GoogleFonts.poppins(fontSize: 16)),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Razon del rechazo...',
            hintStyle: GoogleFonts.nunito(fontSize: 14),
            border: const OutlineInputBorder(),
          ),
          style: GoogleFonts.nunito(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Rechazar',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final id = app['id'] as String;
    try {
      await SupabaseClientService.client
          .from('stylist_applications')
          .update({
        'status': 'rejected',
        'admin_notes': reasonCtrl.text,
      }).eq('id', id);
      await adminLogAction(
        action: 'reject_application',
        targetType: 'stylist_application',
        targetId: id,
        details: {'reason': reasonCtrl.text},
      );
      ref.invalidate(adminApplicationsProvider);
      ref.invalidate(adminDashStatsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud rechazada')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
    reasonCtrl.dispose();
  }

  Widget _statusChip(String status) {
    final color = status == 'pending'
        ? Colors.orange
        : status == 'approved'
            ? Colors.green
            : status == 'rejected'
                ? Colors.red
                : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppConstants.radiusXS),
      ),
      child: Text(
        status,
        style: GoogleFonts.nunito(
            fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
