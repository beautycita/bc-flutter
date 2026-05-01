// Admin v2 GlobalSearchSheet — searches across users + salons + bookings + disputes
// via the Phase 0 admin_global_search RPC (tier-aware projection server-side).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes.dart';
import '../../../../services/supabase_client.dart';
import '../layout/empty_state.dart';
import '../tokens.dart';

class AdminGlobalSearchSheet extends ConsumerStatefulWidget {
  const AdminGlobalSearchSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.85,
        child: AdminGlobalSearchSheet(),
      ),
    );
  }

  @override
  ConsumerState<AdminGlobalSearchSheet> createState() => _State();
}

class _State extends ConsumerState<AdminGlobalSearchSheet> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>>? _results;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.length < 3) {
      setState(() {
        _results = null;
        _error = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final rows = await SupabaseClientService.client.rpc(
        'admin_global_search',
        params: {'p_query': q, 'p_per_kind': 5},
      );
      setState(() {
        _results = (rows as List).cast<Map<String, dynamic>>();
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _busy = false;
        _results = null;
      });
    }
  }

  void _open(Map<String, dynamic> row) {
    final kind = row['kind'] as String?;
    final id = row['ref_id'] as String?;
    if (id == null) return;
    Navigator.of(context).pop();
    if (kind == 'salon') {
      context.push(AppRoutes.adminV3PersonasSalonDetail.replaceFirst(':id', id));
    }
    // user / booking / dispute drilldowns added when their detail screens land
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AdminV2Tokens.spacingLG,
          right: AdminV2Tokens.spacingLG,
          top: AdminV2Tokens.spacingLG,
          bottom: AdminV2Tokens.spacingLG + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Búsqueda global', style: AdminV2Tokens.title(context)),
            const SizedBox(height: AdminV2Tokens.spacingMD),
            TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Nombre, teléfono, email…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AdminV2Tokens.radiusSM)),
              ),
            ),
            const SizedBox(height: AdminV2Tokens.spacingSM),
            Expanded(child: _body(context)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_ctrl.text.trim().length < 3) {
      return Center(
        child: Text('Escribe al menos 3 caracteres', style: AdminV2Tokens.muted(context)),
      );
    }
    if (_busy) return const AdminEmptyState(kind: AdminEmptyKind.loading);
    if (_error != null) return AdminEmptyState(kind: AdminEmptyKind.error, body: _error);
    final results = _results ?? const <Map<String, dynamic>>[];
    if (results.isEmpty) {
      return const AdminEmptyState(kind: AdminEmptyKind.empty, title: 'Sin coincidencias');
    }
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (ctx, i) {
        final r = results[i];
        final kind = r['kind'] as String? ?? '?';
        final label = r['primary_text'] as String? ?? '';
        final hint = (r['secondary_text'] as String? ?? '').trim();
        final icon = switch (kind) {
          'salon' => Icons.store_outlined,
          'user' => Icons.person_outline,
          'booking' => Icons.event_note_outlined,
          'dispute' => Icons.gavel_outlined,
          _ => Icons.help_outline,
        };
        return ListTile(
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(label.isNotEmpty ? label : '(sin nombre)', style: AdminV2Tokens.body(context).copyWith(fontWeight: FontWeight.w600)),
          subtitle: Text('$kind${hint.isNotEmpty ? ' • $hint' : ''}', style: AdminV2Tokens.muted(context)),
          onTap: () => _open(r),
        );
      },
    );
  }
}
