import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../providers/admin_provider.dart';
import '../../services/supabase_client.dart';

/// Provider for pipeline stats from discovered_salons.
final _pipelineStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final response = await SupabaseClientService.client
      .from('discovered_salons')
      .select('status, city, interest_count');

  final rows = response as List;
  final statusCounts = <String, int>{};
  final cityCounts = <String, int>{};
  final topByInterest = <Map<String, dynamic>>[];

  for (final row in rows) {
    final status = row['status'] as String? ?? 'discovered';
    final city = row['city'] as String? ?? 'Unknown';
    statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    cityCounts[city] = (cityCounts[city] ?? 0) + 1;

    if ((row['interest_count'] as int? ?? 0) > 0) {
      topByInterest.add(row as Map<String, dynamic>);
    }
  }

  topByInterest.sort((a, b) =>
      (b['interest_count'] as int).compareTo(a['interest_count'] as int));

  return {
    'total': rows.length,
    'by_status': statusCounts,
    'by_city': cityCounts,
    'top_interest': topByInterest.take(10).toList(),
  };
});

class SalonManagementScreen extends ConsumerStatefulWidget {
  const SalonManagementScreen({super.key});

  @override
  ConsumerState<SalonManagementScreen> createState() =>
      _SalonManagementScreenState();
}

class _SalonManagementScreenState
    extends ConsumerState<SalonManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  String _searchQuery = '';
  int? _tierFilter;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabCtrl,
          labelColor: BeautyCitaTheme.primaryRose,
          unselectedLabelColor: BeautyCitaTheme.textLight,
          indicatorColor: BeautyCitaTheme.primaryRose,
          labelStyle: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Salones'),
            Tab(text: 'Pipeline'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildSalonsList(),
              _buildPipeline(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSalonsList() {
    final bizAsync = ref.watch(adminBusinessesProvider);

    return bizAsync.when(
      data: (businesses) {
        var filtered = businesses.where((b) {
          if (_searchQuery.isNotEmpty &&
              !b.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
            return false;
          }
          if (_tierFilter != null && b.tier != _tierFilter) return false;
          return true;
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(BeautyCitaTheme.spaceMD),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Buscar salon...',
                        hintStyle: GoogleFonts.nunito(fontSize: 14),
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<int?>(
                    icon: Icon(
                      Icons.filter_list,
                      color: _tierFilter != null
                          ? BeautyCitaTheme.primaryRose
                          : BeautyCitaTheme.textLight,
                    ),
                    onSelected: (v) => setState(() => _tierFilter = v),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: null, child: Text('Todos')),
                      const PopupMenuItem(value: 1, child: Text('Tier 1')),
                      const PopupMenuItem(value: 2, child: Text('Tier 2')),
                      const PopupMenuItem(value: 3, child: Text('Tier 3')),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: BeautyCitaTheme.spaceLG),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${filtered.length} salones',
                  style: GoogleFonts.nunito(
                      fontSize: 13, color: BeautyCitaTheme.textLight),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: BeautyCitaTheme.spaceMD),
                itemCount: filtered.length,
                itemBuilder: (context, i) =>
                    _SalonTile(business: filtered[i]),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: GoogleFonts.nunito(color: BeautyCitaTheme.textLight)),
      ),
    );
  }

  Widget _buildPipeline() {
    final statsAsync = ref.watch(_pipelineStatsProvider);

    return statsAsync.when(
      data: (stats) {
        final byStatus = stats['by_status'] as Map<String, int>;
        final byCity = stats['by_city'] as Map<String, int>;
        final topInterest =
            stats['top_interest'] as List<Map<String, dynamic>>;

        return ListView(
          padding: const EdgeInsets.all(BeautyCitaTheme.spaceMD),
          children: [
            // Funnel
            _PipelineCard(
              title: 'Embudo de Conversion',
              icon: Icons.filter_alt,
              child: Column(
                children: [
                  _FunnelRow('Descubiertos',
                      byStatus['discovered'] ?? 0, Colors.grey),
                  _FunnelRow('Seleccionados',
                      byStatus['selected'] ?? 0, Colors.blue),
                  _FunnelRow('Outreach Enviado',
                      byStatus['outreach_sent'] ?? 0, Colors.orange),
                  _FunnelRow('Registrados',
                      byStatus['registered'] ?? 0, Colors.green),
                  _FunnelRow('Declinados',
                      byStatus['declined'] ?? 0, Colors.red),
                  _FunnelRow('Inalcanzables',
                      byStatus['unreachable'] ?? 0, Colors.grey[400]!),
                ],
              ),
            ),

            // By city
            _PipelineCard(
              title: 'Por Ciudad',
              icon: Icons.location_city,
              child: Column(
                children: (byCity.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value)))
                    .map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(e.key,
                                  style: GoogleFonts.nunito(
                                      fontSize: 13,
                                      color: BeautyCitaTheme.textDark)),
                              Text('${e.value}',
                                  style: GoogleFonts.nunito(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: BeautyCitaTheme.textDark)),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),

            // Top interest
            if (topInterest.isNotEmpty)
              _PipelineCard(
                title: 'Mayor Demanda (no registrados)',
                icon: Icons.trending_up,
                child: Column(
                  children: topInterest.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            s['name'] as String? ?? '-',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              color: BeautyCitaTheme.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: BeautyCitaTheme.primaryRose
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${s['interest_count']} interesadas',
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: BeautyCitaTheme.primaryRose,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: GoogleFonts.nunito(color: BeautyCitaTheme.textLight)),
      ),
    );
  }
}

class _SalonTile extends StatelessWidget {
  final AdminBusiness business;
  const _SalonTile({required this.business});

  Color _tierColor(int? tier) {
    switch (tier) {
      case 1:
        return Colors.grey;
      case 2:
        return Colors.blue;
      case 3:
        return BeautyCitaTheme.secondaryGold;
      default:
        return BeautyCitaTheme.textLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusSmall),
      ),
      margin: const EdgeInsets.only(bottom: 4),
      child: Padding(
        padding: const EdgeInsets.all(BeautyCitaTheme.spaceMD),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: business.isActive ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    business.name,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: BeautyCitaTheme.textDark,
                    ),
                  ),
                  if (business.avgRating != null)
                    Row(
                      children: [
                        Icon(Icons.star,
                            size: 14,
                            color: BeautyCitaTheme.secondaryGold),
                        const SizedBox(width: 4),
                        Text(
                          '${business.avgRating!.toStringAsFixed(1)} (${business.reviewCount ?? 0})',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: BeautyCitaTheme.textLight,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (business.tier != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _tierColor(business.tier).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Tier ${business.tier}',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _tierColor(business.tier),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PipelineCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _PipelineCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
      ),
      margin: const EdgeInsets.only(bottom: BeautyCitaTheme.spaceMD),
      child: Padding(
        padding: const EdgeInsets.all(BeautyCitaTheme.spaceMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: BeautyCitaTheme.primaryRose, size: 22),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: BeautyCitaTheme.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: BeautyCitaTheme.spaceMD),
            child,
          ],
        ),
      ),
    );
  }
}

class _FunnelRow extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _FunnelRow(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: BeautyCitaTheme.textDark,
              ),
            ),
          ),
          Text(
            '$count',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: BeautyCitaTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
