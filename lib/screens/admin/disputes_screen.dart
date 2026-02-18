import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/constants.dart';
import '../../providers/admin_provider.dart';
import '../../services/supabase_client.dart';

class DisputesScreen extends ConsumerStatefulWidget {
  const DisputesScreen({super.key});

  @override
  ConsumerState<DisputesScreen> createState() => _DisputesScreenState();
}

class _DisputesScreenState extends ConsumerState<DisputesScreen> {
  String? _statusFilter;

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> disputes) {
    if (_statusFilter == null) return disputes;
    return disputes
        .where((d) => d['status'] == _statusFilter)
        .toList();
  }

  Future<void> _resolve(
      Map<String, dynamic> dispute, String resolution) async {
    final id = dispute['id'] as String;
    try {
      await SupabaseClientService.client.from('disputes').update({
        'status': 'resolved',
        'resolution': resolution,
        'resolved_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      await adminLogAction(
        action: 'resolve_dispute',
        targetType: 'dispute',
        targetId: id,
        details: {'resolution': resolution},
      );
      ref.invalidate(adminDisputesProvider);
      ref.invalidate(adminDashStatsProvider);
      if (mounted) {
        Navigator.of(context).pop(); // close bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Disputa resuelta: $resolution')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showDetail(Map<String, dynamic> dispute) {
    final colors = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppConstants.radiusMD)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.85,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollCtrl) {
            return ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(AppConstants.paddingLG),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMD),
                Text(
                  'Disputa #${(dispute['id'] as String).substring(0, 8)}',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMD),
                _infoRow('Estado', dispute['status'] as String? ?? '-'),
                _infoRow(
                    'Fecha',
                    (dispute['created_at'] as String?)?.split('T')[0] ??
                        '-'),
                _infoRow(
                    'Cliente', dispute['client_id'] as String? ?? '-'),
                _infoRow(
                    'Estilista', dispute['stylist_id'] as String? ?? '-'),
                const SizedBox(height: AppConstants.paddingSM),
                Text('Razon:',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  dispute['reason'] as String? ?? 'Sin razon',
                  style: GoogleFonts.nunito(fontSize: 14),
                ),
                if (dispute['client_evidence'] != null) ...[
                  const SizedBox(height: AppConstants.paddingSM),
                  Text('Evidencia cliente:',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('${dispute['client_evidence']}',
                      style: GoogleFonts.nunito(fontSize: 13)),
                ],
                if (dispute['stylist_evidence'] != null) ...[
                  const SizedBox(height: AppConstants.paddingSM),
                  Text('Evidencia estilista:',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('${dispute['stylist_evidence']}',
                      style: GoogleFonts.nunito(fontSize: 13)),
                ],
                const SizedBox(height: AppConstants.paddingLG),
                if (dispute['status'] != 'resolved') ...[
                  Text('Resolver:',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: AppConstants.paddingSM),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _resolve(dispute, 'refund'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green),
                          child: Text('Reembolso',
                              style: GoogleFonts.poppins(
                                  fontSize: 13, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _resolve(dispute, 'credit'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange),
                          child: Text('Credito',
                              style: GoogleFonts.poppins(
                                  fontSize: 13, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () =>
                              _resolve(dispute, 'dismissed'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey),
                          child: Text('Descartar',
                              style: GoogleFonts.poppins(
                                  fontSize: 13, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: colors.onSurface.withValues(alpha: 0.5))),
          Text(value,
              style: GoogleFonts.nunito(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final disputesAsync = ref.watch(adminDisputesProvider);
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Status filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.paddingMD,
            AppConstants.paddingMD,
            AppConstants.paddingMD,
            AppConstants.paddingSM,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('Todos', null),
                _filterChip('Abierta', 'open'),
                _filterChip('Resuelta', 'resolved'),
              ],
            ),
          ),
        ),

        Expanded(
          child: disputesAsync.when(
            data: (disputes) {
              final filtered = _filtered(disputes);
              if (filtered.isEmpty) {
                return Center(
                  child: Text('Sin disputas',
                      style: GoogleFonts.nunito(
                          color:
                              colors.onSurface.withValues(alpha: 0.5))),
                );
              }
              return RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(adminDisputesProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.paddingMD),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final d = filtered[i];
                    final status = d['status'] as String? ?? 'open';
                    return Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusMD),
                      ),
                      margin: const EdgeInsets.only(
                          bottom: AppConstants.paddingSM),
                      child: InkWell(
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusMD),
                        onTap: () => _showDetail(d),
                        child: Padding(
                          padding: const EdgeInsets.all(
                              AppConstants.paddingSM),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '#${(d['id'] as String).substring(0, 8)}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: colors.onSurface,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _statusChip(status),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      d['reason'] as String? ??
                                          'Sin razon',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.nunito(
                                        fontSize: 13,
                                        color: colors.onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      (d['created_at'] as String?)
                                              ?.split('T')[0] ??
                                          '',
                                      style: GoogleFonts.nunito(
                                        fontSize: 11,
                                        color: colors.onSurface
                                            .withValues(alpha: 0.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right,
                                  color: colors.onSurface
                                      .withValues(alpha: 0.3)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text('Error: $e',
                  style: GoogleFonts.nunito(color: colors.error)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String? value) {
    final selected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            )),
        selected: selected,
        onSelected: (_) => setState(() => _statusFilter = value),
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = status == 'open'
        ? Colors.orange
        : status == 'resolved'
            ? Colors.green
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
