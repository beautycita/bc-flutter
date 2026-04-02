import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../providers/business_provider.dart';
import '../../services/supabase_client.dart';
import '../../services/toast_service.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final businessClosuresProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, bizId) async {
  final data = await SupabaseClientService.client
      .from('business_closures')
      .select()
      .eq('business_id', bizId)
      .gte('closure_date', DateTime.now().subtract(const Duration(days: 30)).toIso8601String().substring(0, 10))
      .order('closure_date');
  return (data as List).cast<Map<String, dynamic>>();
});

// ---------------------------------------------------------------------------
// Screen — shows as a section in Business Settings or standalone
// ---------------------------------------------------------------------------

class BusinessClosuresSection extends ConsumerStatefulWidget {
  const BusinessClosuresSection({super.key});

  @override
  ConsumerState<BusinessClosuresSection> createState() => _BusinessClosuresSectionState();
}

class _BusinessClosuresSectionState extends ConsumerState<BusinessClosuresSection> {
  final _dateFmt = DateFormat('EEEE d MMM yyyy', 'es');

  Future<void> _addClosure(String bizId) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('es', 'MX'),
    );
    if (picked == null || !mounted) return;

    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String r = '';
        return AlertDialog(
          title: Text('Razon del cierre', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
          content: TextField(
            autofocus: true,
            onChanged: (v) => r = v,
            decoration: InputDecoration(
              hintText: 'Dia festivo, vacaciones, mantenimiento...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, r), child: const Text('Agregar')),
          ],
        );
      },
    );
    if (reason == null || !mounted) return;

    // Check for existing appointments on that day
    try {
      final dateStr = picked.toIso8601String().substring(0, 10);
      final conflicts = await SupabaseClientService.client
          .from('appointments')
          .select('id')
          .eq('business_id', bizId)
          .gte('starts_at', '${dateStr}T00:00:00')
          .lte('starts_at', '${dateStr}T23:59:59')
          .inFilter('status', ['pending', 'confirmed']);

      if ((conflicts as List).isNotEmpty && mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Citas existentes', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
            content: Text(
              'Hay ${(conflicts as List).length} cita(s) confirmada(s) para ese dia. Se cancelaran automaticamente si cierras.',
              style: GoogleFonts.nunito(fontSize: 14),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                child: const Text('Cerrar y cancelar citas'),
              ),
            ],
          ),
        );
        if (proceed != true || !mounted) return;
      }

      await SupabaseClientService.client.from('business_closures').insert({
        'business_id': bizId,
        'closure_date': dateStr,
        'reason': reason.trim().isEmpty ? null : reason.trim(),
        'all_day': true,
      });
      ref.invalidate(businessClosuresProvider(bizId));
      ToastService.showSuccess('Cierre agregado');
    } catch (e) {
      if (e.toString().contains('duplicate') || e.toString().contains('unique')) {
        ToastService.showWarning('Ya existe un cierre para esa fecha');
      } else {
        ToastService.showError('Error: $e');
      }
    }
  }

  Future<void> _deleteClosure(String bizId, String closureId) async {
    try {
      await SupabaseClientService.client.from('business_closures').delete().eq('id', closureId);
      ref.invalidate(businessClosuresProvider(bizId));
      ToastService.showSuccess('Cierre eliminado');
    } catch (e) {
      ToastService.showError('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bizAsync = ref.watch(currentBusinessProvider);

    return bizAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (biz) {
        if (biz == null) return const SizedBox.shrink();
        final bizId = biz['id'] as String;
        final closuresAsync = ref.watch(businessClosuresProvider(bizId));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.event_busy, size: 20, color: Colors.red),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Dias de cierre', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  icon: Icon(Icons.add_circle_outline, color: colors.primary),
                  onPressed: () => _addClosure(bizId),
                  tooltip: 'Agregar cierre',
                ),
              ],
            ),
            const SizedBox(height: 8),

            closuresAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (e, _) => Text('Error: $e', style: GoogleFonts.nunito(color: colors.error)),
              data: (closures) {
                if (closures.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Sin cierres programados. Agrega dias festivos o vacaciones.',
                      style: GoogleFonts.nunito(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.5)),
                    ),
                  );
                }

                return Column(
                  children: closures.map((c) {
                    final dateStr = c['closure_date'] as String? ?? '';
                    final dt = DateTime.tryParse(dateStr);
                    final reason = c['reason'] as String? ?? '';
                    final today = DateTime.now();
                    final isPast = dt != null && dt.isBefore(DateTime(today.year, today.month, today.day));
                    final formatted = dt != null ? _dateFmt.format(dt) : dateStr;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isPast ? colors.surfaceContainerHighest.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isPast ? colors.outline.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.event_busy, size: 16, color: isPast ? colors.onSurface.withValues(alpha: 0.3) : Colors.red),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${formatted[0].toUpperCase()}${formatted.substring(1)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isPast ? colors.onSurface.withValues(alpha: 0.4) : colors.onSurface,
                                  ),
                                ),
                                if (reason.isNotEmpty)
                                  Text(reason, style: GoogleFonts.nunito(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5))),
                              ],
                            ),
                          ),
                          if (!isPast)
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              color: Colors.red.withValues(alpha: 0.5),
                              onPressed: () => _deleteClosure(bizId, c['id'] as String),
                              tooltip: 'Eliminar',
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
