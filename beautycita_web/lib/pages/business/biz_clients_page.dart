import 'dart:convert';

import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:web/web.dart' as web;

import '../../config/breakpoints.dart';
import '../../config/web_theme.dart';
import '../../providers/business_portal_provider.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final _clientsSearchProvider = StateProvider<String>((ref) => '');
final _selectedClientProvider =
    StateProvider<Map<String, dynamic>?>((ref) => null);

final _bizClientsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, bizId) async {
  final rows = await BCSupabase.client
      .from('business_clients')
      .select()
      .eq('business_id', bizId)
      .order('last_visit', ascending: false, nullsFirst: false);
  return List<Map<String, dynamic>>.from(rows as List);
});

// ── Page ─────────────────────────────────────────────────────────────────────

/// CRM client list for a business.
class BizClientsPage extends ConsumerWidget {
  const BizClientsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bizAsync = ref.watch(currentBusinessProvider);
    return bizAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (biz) {
        if (biz == null) return const Center(child: Text('Sin negocio'));
        return _ClientsContent(bizId: biz['id'] as String);
      },
    );
  }
}

// ── Content ──────────────────────────────────────────────────────────────────

class _ClientsContent extends ConsumerWidget {
  const _ClientsContent({required this.bizId});
  final String bizId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(_bizClientsProvider(bizId));
    final selected = ref.watch(_selectedClientProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = WebBreakpoints.isDesktop(constraints.maxWidth);
        final showPanel = selected != null && isDesktop;

        return Row(
          children: [
            Expanded(
              child: clientsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Error al cargar clientes: $e')),
                data: (clients) => _ClientsTable(
                  clients: clients,
                  bizId: bizId,
                  isDesktop: isDesktop,
                ),
              ),
            ),
            if (showPanel) ...[
              const VerticalDivider(width: 1, color: kWebCardBorder),
              SizedBox(
                width: 400,
                child: _ClientDetailPanel(client: selected, bizId: bizId),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ── Table ─────────────────────────────────────────────────────────────────────

class _ClientsTable extends ConsumerStatefulWidget {
  const _ClientsTable({
    required this.clients,
    required this.bizId,
    required this.isDesktop,
  });
  final List<Map<String, dynamic>> clients;
  final String bizId;
  final bool isDesktop;

  @override
  ConsumerState<_ClientsTable> createState() => _ClientsTableState();
}

class _ClientsTableState extends ConsumerState<_ClientsTable> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filtered(String q) {
    if (q.isEmpty) return widget.clients;
    final lower = q.toLowerCase();
    return widget.clients.where((c) {
      final name = (c['client_name'] as String? ?? '').toLowerCase();
      final phone = (c['phone'] as String? ?? '').toLowerCase();
      return name.contains(lower) || phone.contains(lower);
    }).toList();
  }

  void _exportCsv(List<Map<String, dynamic>> rows) {
    final sb = StringBuffer();
    sb.writeln(
        'Nombre,Telefono,Visitas,Total Gastado,Ultima Visita,No-Shows,Puntos Lealtad,Tags');
    for (final c in rows) {
      final tags = (c['tags'] as List?)?.join(';') ?? '';
      sb.writeln([
        _csvEscape(c['client_name'] ?? ''),
        _csvEscape(c['phone'] ?? ''),
        c['visit_count'] ?? 0,
        c['total_spent'] ?? 0,
        _csvEscape(c['last_visit'] ?? ''),
        c['no_show_count'] ?? 0,
        c['loyalty_points'] ?? 0,
        _csvEscape(tags),
      ].join(','));
    }

    final bytes = utf8.encode(sb.toString());
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'text/csv'),
    );
    final url = web.URL.createObjectURL(blob);
    (web.document.createElement('a') as web.HTMLAnchorElement
          ..href = url
          ..download = 'clientes.csv')
        .click();
    web.URL.revokeObjectURL(url);
  }

  String _csvEscape(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = ref.watch(_clientsSearchProvider);
    final rows = _filtered(q);
    final selected = ref.watch(_selectedClientProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header bar
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          decoration: const BoxDecoration(
            color: kWebSurface,
            border: Border(bottom: BorderSide(color: kWebCardBorder)),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Clientes (CRM)',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: kWebTextPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${rows.length} clientes',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: kWebTextHint),
                  ),
                ],
              ),
              const Spacer(),
              // Search
              SizedBox(
                width: 260,
                height: 36,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) =>
                      ref.read(_clientsSearchProvider.notifier).state = v,
                  decoration: InputDecoration(
                    hintText: 'Buscar nombre o telefono...',
                    hintStyle: theme.textTheme.bodySmall
                        ?.copyWith(color: kWebTextHint),
                    prefixIcon: const Icon(Icons.search_outlined,
                        size: 18, color: kWebTextHint),
                    filled: true,
                    fillColor: kWebBackground,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kWebCardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kWebCardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: kWebPrimary, width: 1.5),
                    ),
                  ),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: kWebTextPrimary),
                ),
              ),
              const SizedBox(width: 12),
              // Export CSV
              OutlinedButton.icon(
                onPressed: () => _exportCsv(rows),
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Exportar CSV'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kWebTextSecondary,
                  side: const BorderSide(color: kWebCardBorder),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  textStyle: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),

        // Table
        Expanded(
          child: rows.isEmpty
              ? Center(
                  child: Text(
                    'No hay clientes todavia',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: kWebTextHint),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: _DataTable(
                    rows: rows,
                    isDesktop: widget.isDesktop,
                    selectedId: selected?['id'] as String?,
                    onSelect: (c) {
                      ref.read(_selectedClientProvider.notifier).state =
                          selected?['id'] == c['id'] ? null : c;
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Data table widget ─────────────────────────────────────────────────────────

class _DataTable extends StatelessWidget {
  const _DataTable({
    required this.rows,
    required this.isDesktop,
    required this.selectedId,
    required this.onSelect,
  });
  final List<Map<String, dynamic>> rows;
  final bool isDesktop;
  final String? selectedId;
  final void Function(Map<String, dynamic>) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String fmtMoney(dynamic v) =>
        v == null ? '-' : '\$${(v as num).toStringAsFixed(2)}';
    String fmtDate(dynamic v) {
      if (v == null) return '-';
      try {
        final d = DateTime.parse(v.toString());
        return '${d.day}/${d.month}/${d.year}';
      } catch (_) {
        return v.toString();
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: kWebSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kWebCardBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Table(
          columnWidths: isDesktop
              ? const {
                  0: FlexColumnWidth(2.5),
                  1: FlexColumnWidth(1.8),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(1.5),
                  4: FlexColumnWidth(1.5),
                  5: FlexColumnWidth(1),
                  6: FlexColumnWidth(1.2),
                  7: FlexColumnWidth(1.5),
                }
              : const {
                  0: FlexColumnWidth(2.5),
                  1: FlexColumnWidth(1.5),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(1.5),
                },
          children: [
            // Header
            TableRow(
              decoration:
                  const BoxDecoration(color: kWebBackground),
              children: [
                _th(theme, 'Nombre'),
                _th(theme, 'Telefono'),
                _th(theme, 'Visitas'),
                _th(theme, 'Total Gastado'),
                if (isDesktop) ...[
                  _th(theme, 'Ultima Visita'),
                  _th(theme, 'No-Shows'),
                  _th(theme, 'Puntos'),
                  _th(theme, 'Tags'),
                ],
              ],
            ),
            // Rows
            for (final c in rows)
              TableRow(
                decoration: BoxDecoration(
                  color: selectedId == (c['id'] as String?)
                      ? kWebPrimary.withValues(alpha: 0.04)
                      : null,
                  border: const Border(
                    top: BorderSide(color: kWebCardBorder, width: 0.5),
                  ),
                ),
                children: [
                  _td(
                    theme,
                    child: _ClickableCell(
                      onTap: () => onSelect(c),
                      child: Text(
                        c['client_name'] as String? ?? 'Sin nombre',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: kWebPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  _td(theme,
                      child: Text(
                        c['phone'] as String? ?? '-',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: kWebTextSecondary),
                      )),
                  _td(theme,
                      child: Text(
                        '${c['visit_count'] ?? 0}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: kWebTextPrimary),
                      )),
                  _td(theme,
                      child: Text(
                        fmtMoney(c['total_spent']),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: kWebTextPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      )),
                  if (isDesktop) ...[
                    _td(theme,
                        child: Text(
                          fmtDate(c['last_visit']),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: kWebTextSecondary),
                        )),
                    _td(theme,
                        child: _NoShowBadge(count: c['no_show_count'] as int? ?? 0)),
                    _td(theme,
                        child: Text(
                          '${c['loyalty_points'] ?? 0}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: kWebTextSecondary),
                        )),
                    _td(theme, child: _TagsCell(tags: c['tags'] as List?)),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _th(ThemeData theme, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: kWebTextHint,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _td(ThemeData theme, {required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: child,
    );
  }
}

class _ClickableCell extends StatefulWidget {
  const _ClickableCell({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_ClickableCell> createState() => _ClickableCellState();
}

class _ClickableCellState extends State<_ClickableCell> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Opacity(
          opacity: _hovering ? 0.75 : 1.0,
          child: widget.child,
        ),
      ),
    );
  }
}

class _NoShowBadge extends StatelessWidget {
  const _NoShowBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 0) {
      return Text('0',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: kWebTextHint));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.red.shade700,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _TagsCell extends StatelessWidget {
  const _TagsCell({required this.tags});
  final List? tags;

  @override
  Widget build(BuildContext context) {
    if (tags == null || (tags as List).isEmpty) {
      return Text('-',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: kWebTextHint));
    }
    final list = (tags as List).take(2).toList();
    return Wrap(
      spacing: 4,
      children: [
        for (final t in list)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: kWebPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              t.toString(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: kWebPrimary,
                  ),
            ),
          ),
        if ((tags as List).length > 2)
          Text(
            '+${(tags as List).length - 2}',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: kWebTextHint),
          ),
      ],
    );
  }
}

// ── Detail Panel ─────────────────────────────────────────────────────────────

class _ClientDetailPanel extends ConsumerStatefulWidget {
  const _ClientDetailPanel({required this.client, required this.bizId});
  final Map<String, dynamic> client;
  final String bizId;

  @override
  ConsumerState<_ClientDetailPanel> createState() =>
      _ClientDetailPanelState();
}

class _ClientDetailPanelState extends ConsumerState<_ClientDetailPanel> {
  late TextEditingController _notesCtrl;
  late TextEditingController _tagsCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController(
        text: widget.client['notes'] as String? ?? '');
    _tagsCtrl = TextEditingController(
        text: ((widget.client['tags'] as List?) ?? []).join(', '));
  }

  @override
  void didUpdateWidget(_ClientDetailPanel old) {
    super.didUpdateWidget(old);
    if (old.client['id'] != widget.client['id']) {
      _notesCtrl.text = widget.client['notes'] as String? ?? '';
      _tagsCtrl.text =
          ((widget.client['tags'] as List?) ?? []).join(', ');
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final tags = _tagsCtrl.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      await BCSupabase.client
          .from('business_clients')
          .update({'notes': _notesCtrl.text, 'tags': tags}).eq(
              'id', widget.client['id'].toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Guardado')),
        );
        ref.invalidate(_bizClientsProvider(widget.bizId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = widget.client;

    String fmtDate(dynamic v) {
      if (v == null) return '-';
      try {
        final d = DateTime.parse(v.toString());
        return '${d.day}/${d.month}/${d.year}';
      } catch (_) {
        return v.toString();
      }
    }

    return Container(
      color: kWebSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: kWebCardBorder)),
            ),
            child: Row(
              children: [
                Text(
                  'Detalle del Cliente',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: kWebTextPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_outlined,
                      size: 20, color: kWebTextHint),
                  onPressed: () => ref
                      .read(_selectedClientProvider.notifier)
                      .state = null,
                  tooltip: 'Cerrar',
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar + name
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor:
                              kWebPrimary.withValues(alpha: 0.12),
                          child: Text(
                            (c['client_name'] as String? ?? '?')
                                .characters
                                .first
                                .toUpperCase(),
                            style: theme.textTheme.headlineSmall
                                ?.copyWith(color: kWebPrimary),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          c['client_name'] as String? ?? 'Sin nombre',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: kWebTextPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (c['phone'] != null)
                          Text(
                            c['phone'] as String,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: kWebTextHint),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Stats grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.2,
                    children: [
                      _StatCard(
                          label: 'Visitas',
                          value: '${c['visit_count'] ?? 0}'),
                      _StatCard(
                        label: 'Total Gastado',
                        value:
                            '\$${((c['total_spent'] as num?) ?? 0).toStringAsFixed(0)}',
                      ),
                      _StatCard(
                          label: 'No-Shows',
                          value: '${c['no_show_count'] ?? 0}',
                          danger: (c['no_show_count'] as int? ?? 0) > 0),
                      _StatCard(
                          label: 'Puntos',
                          value: '${c['loyalty_points'] ?? 0}'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _InfoRow(
                      label: 'Ultima visita',
                      value: fmtDate(c['last_visit'])),
                  _InfoRow(
                      label: 'Primera visita',
                      value: fmtDate(c['first_visit'])),
                  _InfoRow(
                      label: 'Cumpleanos',
                      value: fmtDate(c['birthday'])),
                  const SizedBox(height: 20),

                  // Editable notes
                  Text('Notas',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: kWebTextSecondary,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Agregar notas sobre este cliente...',
                      hintStyle: theme.textTheme.bodySmall
                          ?.copyWith(color: kWebTextHint),
                      filled: true,
                      fillColor: kWebBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: kWebCardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: kWebCardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: kWebPrimary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: kWebTextPrimary),
                  ),
                  const SizedBox(height: 14),

                  // Editable tags
                  Text('Tags (separados por coma)',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: kWebTextSecondary,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _tagsCtrl,
                    decoration: InputDecoration(
                      hintText: 'vip, regular, alergias...',
                      hintStyle: theme.textTheme.bodySmall
                          ?.copyWith(color: kWebTextHint),
                      filled: true,
                      fillColor: kWebBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: kWebCardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: kWebCardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: kWebPrimary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: kWebTextPrimary),
                  ),
                  const SizedBox(height: 20),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: kWebPrimary,
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Guardar',
                              style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.label,
      required this.value,
      this.danger = false});
  final String label;
  final String value;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: danger
            ? Colors.red.withValues(alpha: 0.05)
            : kWebBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: danger
              ? Colors.red.withValues(alpha: 0.2)
              : kWebCardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: danger ? Colors.red.shade700 : kWebTextPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: kWebTextHint),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: kWebTextHint),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: kWebTextPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
