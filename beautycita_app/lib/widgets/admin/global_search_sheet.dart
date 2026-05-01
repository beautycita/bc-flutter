import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita/config/fonts.dart';

import '../../config/constants.dart';
import '../../services/supabase_client.dart';

/// Bottom-sheet global search across users / salons / bookings / disputes.
/// Calls admin_global_search RPC (tier-aware projection on the backend).
class GlobalSearchSheet extends ConsumerStatefulWidget {
  const GlobalSearchSheet({super.key});

  @override
  ConsumerState<GlobalSearchSheet> createState() => _GlobalSearchSheetState();
}

class _GlobalSearchSheetState extends ConsumerState<GlobalSearchSheet> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _query = v.trim();
    _debounce?.cancel();
    if (_query.length < 3) {
      setState(() {
        _results = const [];
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), _runSearch);
  }

  Future<void> _runSearch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await SupabaseClientService.client
          .rpc('admin_global_search', params: {'p_query': _query, 'p_per_kind': 8});
      setState(() {
        _results = (rows as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } on Object catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _open(Map<String, dynamic> row) {
    final kind = row['kind'] as String?;
    final id = row['ref_id'] as String?;
    if (id == null || kind == null) return;
    Navigator.of(context).pop();
    switch (kind) {
      case 'user':
        context.push('/admin/users/$id');
        break;
      case 'salon':
        context.push('/admin/salones/$id');
        break;
      case 'booking':
        context.push('/admin/citas/$id');
        break;
      case 'dispute':
        context.push('/admin/disputas/$id');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              decoration: BoxDecoration(
                color: colors.onSurface.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Search field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                onChanged: _onChanged,
                style: GoogleFonts.nunito(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Buscar usuario, salón, cita, disputa…',
                  hintStyle: GoogleFonts.nunito(
                      color: colors.onSurface.withValues(alpha: 0.45), fontSize: 15),
                  prefixIcon: const Icon(Icons.search, size: 22),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () {
                            _ctrl.clear();
                            _onChanged('');
                          },
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusLG),
                    borderSide: BorderSide(color: colors.onSurface.withValues(alpha: 0.12)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusLG),
                    borderSide: BorderSide(color: colors.onSurface.withValues(alpha: 0.12)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusLG),
                    borderSide: BorderSide(color: colors.primary, width: 1.5),
                  ),
                ),
              ),
            ),
            // Results / states
            Expanded(child: _buildBody(colors, scrollCtrl)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ColorScheme colors, ScrollController scrollCtrl) {
    if (_query.length < 3) {
      return _hint(colors, 'Escribe al menos 3 caracteres para buscar.');
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null) {
      return _hint(colors, 'Error: $_error');
    }
    if (_results.isEmpty) {
      return _hint(colors, 'Sin coincidencias en usuarios, salones, citas o disputas.');
    }

    // Group by kind
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final r in _results) {
      final k = r['kind'] as String? ?? 'other';
      grouped.putIfAbsent(k, () => []).add(r);
    }
    const order = ['user', 'salon', 'booking', 'dispute'];
    const labels = {'user': 'Usuarios', 'salon': 'Salones', 'booking': 'Citas', 'dispute': 'Disputas'};

    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
      children: [
        for (final k in order)
          if (grouped.containsKey(k)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
              child: Text(
                labels[k]!,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface.withValues(alpha: 0.55),
                  letterSpacing: 0.6,
                ),
              ),
            ),
            for (final row in grouped[k]!) _resultTile(colors, row),
          ],
      ],
    );
  }

  Widget _resultTile(ColorScheme colors, Map<String, dynamic> row) {
    final primary = row['primary_text'] as String? ?? '';
    final secondary = row['secondary_text'] as String? ?? '';
    final badge = row['badge_text'] as String?;
    return ListTile(
      title: Text(primary,
          style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: secondary.isEmpty
          ? null
          : Text(secondary,
              style: GoogleFonts.nunito(
                  fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6))),
      trailing: badge == null || badge.isEmpty
          ? const Icon(Icons.chevron_right, size: 20)
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badge,
                style: GoogleFonts.nunito(
                    fontSize: 11, fontWeight: FontWeight.w700, color: colors.primary),
              ),
            ),
      onTap: () => _open(row),
    );
  }

  Widget _hint(ColorScheme colors, String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            text,
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: colors.onSurface.withValues(alpha: 0.55),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
}

/// Helper to open the sheet from anywhere in the admin shell.
Future<void> showGlobalSearch(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const GlobalSearchSheet(),
  );
}
