// =============================================================================
// WalkinPendingBanner + assign modal — shown atop business_calendar_screen
// =============================================================================
// Watches walkin_pending_appointments for this business. When a row appears
// with status='pending_assignment', shows a banner. Tapping it opens an
// assign modal where the owner picks a stylist + time slot.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/config/fonts.dart';
import '../config/constants.dart';
import '../providers/business_provider.dart';
import '../services/supabase_client.dart';
import '../services/toast_service.dart';

final _walkinPendingProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) async* {
  final biz = await ref.watch(currentBusinessProvider.future);
  if (biz == null) {
    yield const [];
    return;
  }
  final bizId = biz['id'] as String;
  final client = SupabaseClientService.client;

  // Initial fetch
  final initial = await client
      .from('walkin_pending_appointments')
      .select('id, registration_id, service_id, service_name, client_notes, created_at, expires_at, salon_walkin_registrations!inner(full_name, phone)')
      .eq('business_id', bizId)
      .eq('status', 'pending_assignment')
      .order('created_at', ascending: true);

  yield (initial as List).cast<Map<String, dynamic>>();

  // Poll every 30s — realtime would be nicer but avoids RLS realtime config churn
  while (true) {
    await Future.delayed(const Duration(seconds: 30));
    try {
      final refreshed = await client
          .from('walkin_pending_appointments')
          .select('id, registration_id, service_id, service_name, client_notes, created_at, expires_at, salon_walkin_registrations!inner(full_name, phone)')
          .eq('business_id', bizId)
          .eq('status', 'pending_assignment')
          .order('created_at', ascending: true);
      yield (refreshed as List).cast<Map<String, dynamic>>();
    } catch (_) {
      // keep previous state
    }
  }
});

class WalkinPendingBanner extends ConsumerWidget {
  const WalkinPendingBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(_walkinPendingProvider);
    return pending.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (rows) {
        if (rows.isEmpty) return const SizedBox.shrink();
        return Column(
          children: rows.map((row) => _buildBanner(context, ref, row)).toList(),
        );
      },
    );
  }

  Widget _buildBanner(BuildContext context, WidgetRef ref, Map<String, dynamic> row) {
    final colors = Theme.of(context).colorScheme;
    final reg = row['salon_walkin_registrations'] as Map<String, dynamic>?;
    final clientName = reg?['full_name'] ?? 'Cliente';
    final service = row['service_name'] ?? 'servicio';
    return InkWell(
      onTap: () => _openAssignModal(context, ref, row),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.12),
          border: Border(bottom: BorderSide(color: Colors.amber.withValues(alpha: 0.3))),
        ),
        child: Row(
          children: [
            const Icon(Icons.notifications_active_rounded, color: Colors.orange, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey[900]),
                  children: [
                    const TextSpan(
                        text: 'Nuevo walk-in: ',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: '$clientName — '),
                    TextSpan(
                        text: service,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            TextButton(
              onPressed: () => _openAssignModal(context, ref, row),
              style: TextButton.styleFrom(foregroundColor: colors.primary),
              child: Text('Asignar',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAssignModal(BuildContext context, WidgetRef ref, Map<String, dynamic> row) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => WalkinAssignSheet(pending: row),
    );
    if (result == true) {
      ref.invalidate(_walkinPendingProvider);
    }
  }
}

class WalkinAssignSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> pending;
  const WalkinAssignSheet({super.key, required this.pending});

  @override
  ConsumerState<WalkinAssignSheet> createState() => _WalkinAssignSheetState();
}

class _WalkinAssignSheetState extends ConsumerState<WalkinAssignSheet> {
  String? _staffId;
  DateTime _scheduledAt = DateTime.now().add(const Duration(minutes: 15));
  List<Map<String, dynamic>> _staff = [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    try {
      final biz = await ref.read(currentBusinessProvider.future);
      if (biz == null) {
        setState(() { _loading = false; _error = 'Negocio no encontrado'; });
        return;
      }
      final bizId = biz['id'] as String;
      final staff = await SupabaseClientService.client
          .from('staff')
          .select('id, first_name, last_name')
          .eq('business_id', bizId)
          .eq('is_active', true)
          .order('sort_order');

      // Recommend stylist: most common for this service in last 90 days
      final serviceId = widget.pending['service_id'] as String?;
      String? recommendedId;
      if (serviceId != null) {
        final ago90 = DateTime.now().subtract(const Duration(days: 90)).toIso8601String();
        final hist = await SupabaseClientService.client
            .from('appointments')
            .select('staff_id')
            .eq('business_id', bizId)
            .eq('service_id', serviceId)
            .eq('status', 'completed')
            .gte('starts_at', ago90);
        final counts = <String, int>{};
        for (final a in (hist as List)) {
          final sid = a['staff_id'] as String?;
          if (sid != null) counts[sid] = (counts[sid] ?? 0) + 1;
        }
        if (counts.isNotEmpty) {
          recommendedId = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
        }
      }

      final list = (staff as List).cast<Map<String, dynamic>>();
      setState(() {
        _staff = list;
        _staffId = recommendedId ?? (list.isNotEmpty ? list.first['id'] as String : null);
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; _error = 'Error: $e'; });
    }
  }

  Future<void> _pickDateTime() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now().subtract(const Duration(hours: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (time == null) return;
    setState(() {
      _scheduledAt = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (_staffId == null) return;
    setState(() => _submitting = true);
    try {
      final res = await SupabaseClientService.client.functions.invoke(
        'qr-walkin-assign',
        body: {
          'pending_id': widget.pending['id'],
          'staff_id': _staffId,
          'scheduled_at': _scheduledAt.toUtc().toIso8601String(),
        },
      );
      final data = res.data;
      if (data is Map && data['success'] == true) {
        if (!mounted) return;
        ToastService.showSuccess('Cita confirmada');
        Navigator.pop(context, true);
      } else {
        final err = data is Map ? data['error']?.toString() : 'Error inesperado';
        setState(() { _error = err; _submitting = false; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Error: $e'; _submitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reg = widget.pending['salon_walkin_registrations'] as Map<String, dynamic>?;
    final clientName = reg?['full_name'] ?? 'Cliente';
    final phone = reg?['phone'] ?? '';
    final service = widget.pending['service_name'] ?? '';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: _loading
          ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Asignar walk-in',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(clientName,
                    style: GoogleFonts.nunito(fontSize: 14, color: Colors.grey[700])),
                if (phone.isNotEmpty)
                  Text(phone,
                      style: GoogleFonts.firaCode(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.content_cut_rounded, color: colors.primary, size: 18),
                      const SizedBox(width: 8),
                      Text(service, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _staffId,
                  decoration: InputDecoration(
                    labelText: 'Estilista',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.person_outline),
                    helperText: _staffId != null && _staff.isNotEmpty
                        ? 'Recomendado: ${_staff.firstWhere((s) => s['id'] == _staffId, orElse: () => _staff.first)['first_name']}'
                        : null,
                  ),
                  items: _staff.map((s) {
                    final name = '${s['first_name']} ${s['last_name'] ?? ''}'.trim();
                    return DropdownMenuItem<String>(
                      value: s['id'] as String,
                      child: Text(name),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _staffId = v),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickDateTime,
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text(
                    '${_scheduledAt.day}/${_scheduledAt.month.toString().padLeft(2, '0')}/${_scheduledAt.year} '
                    '${_scheduledAt.hour.toString().padLeft(2, '0')}:${_scheduledAt.minute.toString().padLeft(2, '0')}',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: AppConstants.minTouchHeight,
                  child: ElevatedButton(
                    onPressed: _staffId == null || _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text('Confirmar cita',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                ),
              ],
            ),
    );
  }
}
