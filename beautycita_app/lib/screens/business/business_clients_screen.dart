import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../providers/business_provider.dart';
import '../../services/supabase_client.dart';
import '../../services/toast_service.dart';
import '../../widgets/admin/admin_widgets.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final businessClientsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, bizId) async {
  final data = await SupabaseClientService.client
      .from('business_clients')
      .select('*, profiles(username, avatar_url)')
      .eq('business_id', bizId)
      .order('last_visit_at', ascending: false);
  return (data as List).cast<Map<String, dynamic>>();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class BusinessClientsScreen extends ConsumerStatefulWidget {
  const BusinessClientsScreen({super.key});

  @override
  ConsumerState<BusinessClientsScreen> createState() => _BusinessClientsScreenState();
}

class _BusinessClientsScreenState extends ConsumerState<BusinessClientsScreen> {
  String _search = '';
  String? _sortField;
  bool _sortAsc = false;
  String? _tagFilter;
  final _searchCtrl = TextEditingController();

  static const _sortOptions = [
    SortOption('client_name', 'Nombre'),
    SortOption('total_visits', 'Visitas'),
    SortOption('total_spent', 'Gastado'),
    SortOption('last_visit_at', 'Ultima visita'),
    SortOption('no_show_count', 'No-shows'),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> clients) {
    var result = List<Map<String, dynamic>>.from(clients);

    // Search
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      result = result.where((c) {
        final name = (c['client_name'] as String? ?? '').toLowerCase();
        final phone = (c['phone'] as String? ?? '').toLowerCase();
        final tags = (c['tags'] as List?)?.join(' ').toLowerCase() ?? '';
        final notes = (c['notes'] as String? ?? '').toLowerCase();
        return name.contains(q) || phone.contains(q) || tags.contains(q) || notes.contains(q);
      }).toList();
    }

    // Tag filter
    if (_tagFilter != null) {
      result = result.where((c) {
        final tags = (c['tags'] as List?)?.cast<String>() ?? [];
        return tags.contains(_tagFilter);
      }).toList();
    }

    // Sort
    if (_sortField != null) {
      result.sort((a, b) {
        final va = a[_sortField] ?? '';
        final vb = b[_sortField] ?? '';
        int cmp;
        if (va is num && vb is num) {
          cmp = va.compareTo(vb);
        } else if (va is String && vb is String) {
          cmp = va.toLowerCase().compareTo(vb.toLowerCase());
        } else {
          cmp = va.toString().compareTo(vb.toString());
        }
        return _sortAsc ? cmp : -cmp;
      });
    }

    return result;
  }

  Set<String> _allTags(List<Map<String, dynamic>> clients) {
    final tags = <String>{};
    for (final c in clients) {
      final t = (c['tags'] as List?)?.cast<String>() ?? [];
      tags.addAll(t);
    }
    return tags;
  }

  void _exportCsv(List<Map<String, dynamic>> clients) {
    CsvExporter.exportMaps(
      context: context,
      filename: 'clientes',
      headers: ['Nombre', 'Telefono', 'Email', 'Visitas', 'Gastado', 'Ultima Visita', 'No-Shows', 'Tags', 'Notas'],
      keys: ['client_name', 'phone', 'email', 'total_visits', 'total_spent', 'last_visit_at', 'no_show_count', 'tags', 'notes'],
      items: clients,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bizAsync = ref.watch(currentBusinessProvider);

    return bizAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (biz) {
        if (biz == null) return const Center(child: Text('Sin negocio'));
        final bizId = biz['id'] as String;
        final clientsAsync = ref.watch(businessClientsProvider(bizId));

        return clientsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e', style: GoogleFonts.nunito(color: colors.error))),
          data: (allClients) {
            final filtered = _filter(allClients);
            final allTags = _allTags(allClients);

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(businessClientsProvider(bizId)),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: AdminToolbar(
                      showSearch: true,
                      searchHint: 'Buscar cliente...',
                      searchController: _searchCtrl,
                      onSearchChanged: (q) => setState(() => _search = q),
                      showSort: true,
                      sortOptions: _sortOptions,
                      currentSortField: _sortField,
                      sortAscending: _sortAsc,
                      onSortChanged: (f) => setState(() {
                        if (_sortField == f) {
                          _sortAsc = !_sortAsc;
                        } else {
                          _sortField = f;
                          _sortAsc = false;
                        }
                      }),
                      showExport: true,
                      onExport: () => _exportCsv(filtered),
                      totalCount: allClients.length,
                      filteredCount: filtered.length,
                    ),
                  ),

                  // Tag filter chips
                  if (allTags.isNotEmpty)
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _TagChip(
                            label: 'Todos',
                            selected: _tagFilter == null,
                            onTap: () => setState(() => _tagFilter = null),
                          ),
                          ...allTags.map((tag) => _TagChip(
                            label: tag,
                            selected: _tagFilter == tag,
                            onTap: () => setState(() => _tagFilter = _tagFilter == tag ? null : tag),
                          )),
                        ],
                      ),
                    ),

                  const SizedBox(height: 8),

                  // Client list
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people_outline, size: 48, color: colors.onSurface.withValues(alpha: 0.2)),
                                const SizedBox(height: 12),
                                Text(
                                  allClients.isEmpty
                                      ? 'Los clientes aparecen automaticamente\ncuando completan una cita'
                                      : 'Sin resultados',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.nunito(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.5)),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filtered.length,
                            itemBuilder: (ctx, i) => _ClientCard(
                              client: filtered[i],
                              bizId: bizId,
                              onUpdated: () => ref.invalidate(businessClientsProvider(bizId)),
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tag chip
// ---------------------------------------------------------------------------

class _TagChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TagChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Chip(
          label: Text(label, style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : colors.onSurface.withValues(alpha: 0.7),
          )),
          backgroundColor: selected ? colors.primary : colors.surface,
          side: BorderSide(color: selected ? colors.primary : colors.outline.withValues(alpha: 0.2)),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Client card (tappable → detail sheet)
// ---------------------------------------------------------------------------

class _ClientCard extends StatelessWidget {
  final Map<String, dynamic> client;
  final String bizId;
  final VoidCallback onUpdated;

  const _ClientCard({required this.client, required this.bizId, required this.onUpdated});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = client['client_name'] as String? ?? 'Cliente';
    final visits = client['total_visits'] as int? ?? 0;
    final spent = (client['total_spent'] as num?)?.toDouble() ?? 0;
    final lastVisit = DateTime.tryParse(client['last_visit_at']?.toString() ?? '');
    final noShows = client['no_show_count'] as int? ?? 0;
    final loyaltyPoints = client['loyalty_points'] as int? ?? 0;
    final tags = (client['tags'] as List?)?.cast<String>() ?? [];
    final notes = client['notes'] as String?;
    final fmt = NumberFormat('#,##0', 'es_MX');

    return GestureDetector(
      onTap: () => _showClientDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outline.withValues(alpha: 0.1)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: colors.primary.withValues(alpha: 0.1),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: colors.primary),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (noShows > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('$noShows no-show', style: GoogleFonts.nunito(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text('$visits visitas', style: GoogleFonts.nunito(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5))),
                      const SizedBox(width: 8),
                      Text('\$${fmt.format(spent)}', style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF059669))),
                      if (lastVisit != null) ...[
                        const SizedBox(width: 8),
                        Text(_timeAgo(lastVisit), style: GoogleFonts.nunito(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
                      ],
                      if (loyaltyPoints > 0) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.stars_rounded, size: 12, color: Colors.amber[700]),
                        const SizedBox(width: 2),
                        Text('$loyaltyPoints pts', style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.amber[700])),
                      ],
                    ],
                  ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      children: tags.take(3).map((t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(t, style: GoogleFonts.nunito(fontSize: 10, color: colors.primary)),
                      )).toList(),
                    ),
                  ],
                  if (notes != null && notes.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(notes, style: GoogleFonts.nunito(fontSize: 11, fontStyle: FontStyle.italic, color: colors.onSurface.withValues(alpha: 0.4)),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: colors.onSurface.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }

  void _showClientDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _ClientDetailSheet(client: client, bizId: bizId, onUpdated: onUpdated),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 30) return 'hace ${diff.inDays ~/ 30}m';
    if (diff.inDays > 0) return 'hace ${diff.inDays}d';
    if (diff.inHours > 0) return 'hace ${diff.inHours}h';
    return 'reciente';
  }
}

// ---------------------------------------------------------------------------
// Detail sheet with edit capability
// ---------------------------------------------------------------------------

class _ClientDetailSheet extends StatefulWidget {
  final Map<String, dynamic> client;
  final String bizId;
  final VoidCallback onUpdated;

  const _ClientDetailSheet({required this.client, required this.bizId, required this.onUpdated});

  @override
  State<_ClientDetailSheet> createState() => _ClientDetailSheetState();
}

class _ClientDetailSheetState extends State<_ClientDetailSheet> {
  late final TextEditingController _notesCtrl;
  late final TextEditingController _tagsCtrl;
  bool _saving = false;
  bool _redeemingPoints = false;

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController(text: widget.client['notes'] as String? ?? '');
    final tags = (widget.client['tags'] as List?)?.cast<String>() ?? [];
    _tagsCtrl = TextEditingController(text: tags.join(', '));
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

      await SupabaseClientService.client
          .from('business_clients')
          .update({
            'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
            'tags': tags.isEmpty ? null : tags,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', widget.client['id']);

      widget.onUpdated();
      if (mounted) {
        Navigator.pop(context);
        ToastService.showSuccess('Cliente actualizado');
      }
    } catch (e) {
      ToastService.showError('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _redeemPoints() async {
    final userId = widget.client['user_id'] as String?;
    if (userId == null) {
      ToastService.showError('Cliente sin cuenta registrada');
      return;
    }
    final points = widget.client['loyalty_points'] as int? ?? 0;
    if (points < 100) {
      ToastService.showError('Se necesitan al menos 100 puntos');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Canjear puntos',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          'Canjear 100 puntos por \$50 MXN de saldo para ${widget.client['client_name'] ?? 'este cliente'}?',
          style: GoogleFonts.nunito(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Canjear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _redeemingPoints = true);
    try {
      // Deduct 100 points from business_clients
      await SupabaseClientService.client
          .from('business_clients')
          .update({
            'loyalty_points': points - 100,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', widget.client['id']);

      // Record loyalty transaction
      await SupabaseClientService.client.from('loyalty_transactions').insert({
        'business_id': widget.bizId,
        'user_id': userId,
        'points': -100,
        'type': 'redeemed',
        'source': 'redemption',
      });

      // Credit $50 saldo to user
      await SupabaseClientService.adjustSaldo(userId: userId, amount: 50.0);

      widget.onUpdated();
      if (mounted) {
        Navigator.pop(context);
        ToastService.showSuccess('\$50 MXN acreditados al cliente');
      }
    } catch (e) {
      ToastService.showError('Error: $e');
    } finally {
      if (mounted) setState(() => _redeemingPoints = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.client;
    final colors = Theme.of(context).colorScheme;
    final name = c['client_name'] as String? ?? 'Cliente';
    final phone = c['phone'] as String?;
    final email = c['email'] as String?;
    final visits = c['total_visits'] as int? ?? 0;
    final spent = (c['total_spent'] as num?)?.toDouble() ?? 0;
    final noShows = c['no_show_count'] as int? ?? 0;
    final loyaltyPoints = c['loyalty_points'] as int? ?? 0;
    final firstVisit = DateTime.tryParse(c['first_visit_at']?.toString() ?? '');
    final lastVisit = DateTime.tryParse(c['last_visit_at']?.toString() ?? '');
    final birthday = c['birthday'] as String?;
    final fmt = NumberFormat('#,##0', 'es_MX');
    final dateFmt = DateFormat('dd/MM/yyyy');

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(20),
        children: [
          // Handle
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: colors.primary.withValues(alpha: 0.1),
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700, color: colors.primary)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
                    if (phone != null) Text(phone, style: GoogleFonts.nunito(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6))),
                    if (email != null) Text(email, style: GoogleFonts.nunito(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.5))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Stats row
          Row(
            children: [
              _StatPill(label: 'Visitas', value: '$visits', color: colors.primary),
              const SizedBox(width: 8),
              _StatPill(label: 'Gastado', value: '\$${fmt.format(spent)}', color: const Color(0xFF059669)),
              const SizedBox(width: 8),
              _StatPill(label: 'No-shows', value: '$noShows', color: noShows > 0 ? Colors.red : colors.onSurface.withValues(alpha: 0.4)),
            ],
          ),
          const SizedBox(height: 8),

          // Loyalty points row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.stars_rounded, color: Colors.amber[700], size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$loyaltyPoints puntos de lealtad',
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.amber[800])),
                      Text('100 puntos = \$50 MXN de descuento',
                          style: GoogleFonts.nunito(
                              fontSize: 11,
                              color: Colors.amber[700])),
                    ],
                  ),
                ),
                if (loyaltyPoints >= 100)
                  SizedBox(
                    height: 34,
                    child: FilledButton(
                      onPressed: _redeemingPoints ? null : _redeemPoints,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.amber[700],
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _redeemingPoints
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text('Canjear',
                              style: GoogleFonts.poppins(
                                  fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Dates
          _DetailRow('Primera visita', firstVisit != null ? dateFmt.format(firstVisit.toLocal()) : '—'),
          _DetailRow('Ultima visita', lastVisit != null ? dateFmt.format(lastVisit.toLocal()) : '—'),
          if (birthday != null) _DetailRow('Cumpleanos', birthday),
          _DetailRow('ID', c['id']?.toString() ?? '—'),
          if (c['user_id'] != null) _DetailRow('User ID', c['user_id'].toString()),

          const SizedBox(height: 20),

          // Tags (editable)
          Text('Etiquetas', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _tagsCtrl,
            style: GoogleFonts.nunito(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'VIP, fiel, prefiere martes... (separar con coma)',
              hintStyle: GoogleFonts.nunito(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 16),

          // Notes (editable)
          Text('Notas privadas', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _notesCtrl,
            style: GoogleFonts.nunito(fontSize: 14),
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Preferencias, alergias, detalles importantes...',
              hintStyle: GoogleFonts.nunito(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 20),

          // Save button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Guardar', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
            Text(label, style: GoogleFonts.nunito(fontSize: 11, color: color.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }
}

Widget _DetailRow(String label, String value) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Row(
    children: [
      SizedBox(width: 120, child: Text(label, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey[600]))),
      Expanded(child: Text(value, style: GoogleFonts.nunito(fontSize: 13))),
    ],
  ),
);
