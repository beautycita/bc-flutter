import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/breakpoints.dart';
import '../../widgets/directory_nav.dart';

const _bgColor = Color(0xFFFFFAF5);
const _textPrimary = Color(0xFF1A1A1A);
const _textSecondary = Color(0xFF666666);
const _brandPink = Color(0xFFEC4899);
const _brandPurple = Color(0xFF9333EA);
const _brandGradient = LinearGradient(
  colors: [Color(0xFFEC4899), Color(0xFF9333EA), Color(0xFF3B82F6)],
);
const _maxWidth = 1200.0;

class DirectoryCityPage extends StatefulWidget {
  final String stateSlug;
  final String citySlug;
  const DirectoryCityPage({super.key, required this.stateSlug, required this.citySlug});
  @override
  State<DirectoryCityPage> createState() => _DirectoryCityPageState();
}

class _DirectoryCityPageState extends State<DirectoryCityPage> {
  // Registered businesses in this city (opted into platform — safe to show)
  List<dynamic> _registered = [];
  // Aggregate stats only — never expose individual discovered salons
  String _cityName = '';
  String _stateName = '';
  int _totalDiscovered = 0;
  List<String> _topCategories = [];
  double? _avgRating;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await Future.wait([
        _loadRegistered(),
        _loadAggregateStats(),
      ]);
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadRegistered() async {
    final cityName = _slugToName(widget.citySlug);
    final stateName = _slugToName(widget.stateSlug);
    try {
      final data = await BCSupabase.client
          .from(BCTables.businesses)
          .select('id, name, slug, photo_url, address, city, average_rating, total_reviews, service_categories, phone')
          .eq('is_active', true)
          .ilike('city', cityName);
      _registered = (data as List?) ?? [];
    } catch (_) {
      _registered = [];
    }
    _cityName = cityName;
    _stateName = stateName;
  }

  Future<void> _loadAggregateStats() async {
    try {
      final result = await BCSupabase.client.rpc('get_city_salons', params: {
        'p_state_slug': widget.stateSlug,
        'p_city_slug': widget.citySlug,
        'p_offset': 0,
        'p_limit': 1, // We only need the aggregate, not the list
      });
      final data = (result as Map<String, dynamic>?) ?? <String, dynamic>{};
      _cityName = data['city'] as String? ?? _slugToName(widget.citySlug);
      _stateName = data['state'] as String? ?? _slugToName(widget.stateSlug);
      _totalDiscovered = (data['total'] as num?)?.toInt() ?? 0;
      // Extract top categories from the single returned salon if available
      final salons = (data['salons'] as List?) ?? [];
      final catSet = <String>{};
      for (final s in salons) {
        final cats = (s['categories'] as List?)?.cast<String>() ?? [];
        catSet.addAll(cats);
      }
      _topCategories = catSet.take(6).toList();
    } catch (_) {
      _totalDiscovered = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: LayoutBuilder(builder: (context, constraints) {
        final w = constraints.maxWidth;
        final isMobile = WebBreakpoints.isMobile(w);
        final hPad = isMobile ? 16.0 : 40.0;

        return CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: DirectoryNav()),
            SliverToBoxAdapter(child: _buildHero(isMobile)),
            // Breadcrumb
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxWidth),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 12),
                    child: Row(
                      children: [
                        _breadLink('Inicio', '/'),
                        _breadSep(),
                        _breadLink('Salones', '/salones'),
                        _breadSep(),
                        _breadLink(_stateName, '/salones/${widget.stateSlug}'),
                        _breadSep(),
                        Text(_cityName, style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              SliverFillRemaining(child: Center(child: Text('Error cargando directorio', style: TextStyle(color: _textSecondary))))
            else
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: _maxWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // === REGISTERED SALONS (on BeautyCita) ===
                          if (_registered.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('En BeautyCita', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                                ),
                                const SizedBox(width: 10),
                                Text('Reserva en linea al instante', style: TextStyle(fontSize: 13, color: _textSecondary)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ..._registered.map((b) => _buildRegisteredCard(b, isMobile)),
                            const SizedBox(height: 32),
                          ],

                          // === DISCOVERED STATS (aggregate only — no individual salon data) ===
                          if (_totalDiscovered > 0) ...[
                            _buildDiscoveredStats(isMobile),
                            const SizedBox(height: 32),
                          ],

                          // Invite CTA
                          _buildInviteCta(isMobile),
                          const SizedBox(height: 32),

                          // Bottom CTA
                          _buildBottomCta(isMobile),
                          const SizedBox(height: 60),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _breadLink(String text, String route) => GestureDetector(
    onTap: () => context.go(route),
    child: MouseRegion(cursor: SystemMouseCursors.click, child: Text(text, style: const TextStyle(color: _textSecondary, fontSize: 13))),
  );
  Widget _breadSep() => Text('  /  ', style: TextStyle(color: _textSecondary.withValues(alpha: 0.4), fontSize: 13));

  Widget _buildHero(bool isMobile) {
    final regCount = _registered.length;
    final totalCount = _totalDiscovered + regCount;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 60, vertical: isMobile ? 36 : 56),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFFFFF0F5), Color(0xFFF5F0FF), Color(0xFFF0F5FF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => _brandGradient.createShader(bounds),
                child: Text('Salones en $_cityName',
                  style: TextStyle(fontSize: isMobile ? 26 : 38, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2)),
              ),
              const SizedBox(height: 10),
              Text(
                '$totalCount salones de belleza en $_cityName, $_stateName',
                style: TextStyle(fontSize: isMobile ? 15 : 18, color: _textSecondary),
              ),
              if (regCount > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '$regCount disponibles para reservar en linea',
                  style: TextStyle(fontSize: 14, color: const Color(0xFF16A34A), fontWeight: FontWeight.w500),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // === REGISTERED SALON CARD (full-featured, bookable) ===
  Widget _buildRegisteredCard(dynamic biz, bool isMobile) {
    final name = biz['name'] as String? ?? '';
    final slug = biz['slug'] as String?;
    final photo = biz['photo_url'] as String?;
    final address = biz['address'] as String? ?? '';
    final rating = (biz['average_rating'] as num?)?.toDouble() ?? 0;
    final reviews = (biz['total_reviews'] as num?)?.toInt() ?? 0;
    final phone = biz['phone'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: photo != null
                ? Image.network(photo, width: isMobile ? 64 : 88, height: isMobile ? 64 : 88, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder(isMobile))
                : _placeholder(isMobile),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (address.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(address, style: const TextStyle(fontSize: 12, color: _textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(height: 6),
                Row(children: [
                  if (rating > 0) ...[
                    const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 3),
                    Text('$rating', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary)),
                    Text(' ($reviews)', style: const TextStyle(fontSize: 12, color: _textSecondary)),
                  ],
                ]),
              ],
            ),
          ),
          if (slug != null)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => context.go('/salon/$slug'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(gradient: _brandGradient, borderRadius: BorderRadius.circular(10)),
                  child: const Text('Reservar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // === AGGREGATE STATS (no individual salon data exposed) ===
  Widget _buildDiscoveredStats(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0EBE6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.explore_rounded, size: 24, color: _brandPurple),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$_totalDiscovered salones de belleza en $_cityName',
                  style: TextStyle(fontSize: isMobile ? 17 : 20, fontWeight: FontWeight.w700, color: _textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Hemos identificado $_totalDiscovered salones y esteticas en $_cityName, $_stateName. '
            'Estamos invitando a los mejores a unirse a BeautyCita para que puedas reservar en linea.',
            style: TextStyle(fontSize: 14, color: _textSecondary, height: 1.5),
          ),
          if (_topCategories.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Servicios disponibles en $_cityName:', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _topCategories.map((cat) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF0EBE6)),
                ),
                child: Text(_categoryLabel(cat), style: const TextStyle(fontSize: 12, color: _textSecondary)),
              )).toList(),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Conoces un salon en $_cityName? Invitalo a unirse — es gratis para ellos.',
            style: TextStyle(fontSize: 13, color: _brandPurple, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(bool isMobile) {
    final size = isMobile ? 64.0 : 88.0;
    return Container(width: size, height: size, decoration: BoxDecoration(color: const Color(0xFFF0EBE6), borderRadius: BorderRadius.circular(10)),
      child: Icon(Icons.storefront_rounded, color: _textSecondary.withValues(alpha: 0.3), size: 30));
  }

  Widget _placeholderSmall(bool isMobile) {
    final size = isMobile ? 52.0 : 68.0;
    return Container(width: size, height: size, decoration: BoxDecoration(color: const Color(0xFFF0EBE6), borderRadius: BorderRadius.circular(8)),
      child: Icon(Icons.storefront_rounded, color: _textSecondary.withValues(alpha: 0.3), size: 24));
  }

  Widget _buildInviteCta(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_brandPink.withValues(alpha: 0.08), _brandPurple.withValues(alpha: 0.08)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _brandPink.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.storefront_rounded, size: 36, color: _brandPurple),
          const SizedBox(height: 12),
          Text('Conoces un salon en $_cityName?', style: TextStyle(fontSize: isMobile ? 17 : 20, fontWeight: FontWeight.w700, color: _textPrimary), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Invita a tu salon favorito a unirse a BeautyCita. Es completamente gratis para ellos — sin comisiones, sin contratos.',
            style: TextStyle(fontSize: 14, color: _textSecondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => launchUrl(Uri.parse('https://beautycita.com/invitar'), mode: LaunchMode.externalApplication),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                decoration: BoxDecoration(gradient: _brandGradient, borderRadius: BorderRadius.circular(12)),
                child: const Text('Invitar un salon', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCta(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFF0F5), Color(0xFFF5F0FF)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0EBE6)),
      ),
      child: Column(
        children: [
          Text('Eres dueno de un salon en $_cityName?', style: TextStyle(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.w700, color: _textPrimary), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Registrate gratis. Sin comisiones por tus clientes. Gestiona citas, pagos y mas.', style: TextStyle(fontSize: 14, color: _textSecondary), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(
                onTap: () => context.go('/auth'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(gradient: _brandGradient, borderRadius: BorderRadius.circular(12)),
                  child: const Text('Registrar mi salon', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              )),
              MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(
                onTap: () => context.go('/'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(border: Border.all(color: _brandPink, width: 2), borderRadius: BorderRadius.circular(12)),
                  child: const Text('Saber mas', style: TextStyle(color: _brandPink, fontWeight: FontWeight.w700)),
                ),
              )),
            ],
          ),
        ],
      ),
    );
  }

  String _slugToName(String slug) => slug.split('-').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

  static const _catLabels = {
    'hair': 'Cabello', 'nails': 'Unas', 'lashes': 'Pestanas', 'barber': 'Barberia',
    'skin': 'Piel', 'spa': 'Spa', 'makeup': 'Maquillaje', 'brows': 'Cejas',
    'massage': 'Masaje', 'waxing': 'Depilacion', 'facial': 'Facial',
  };
  String _categoryLabel(String cat) => _catLabels[cat] ?? cat;
}
