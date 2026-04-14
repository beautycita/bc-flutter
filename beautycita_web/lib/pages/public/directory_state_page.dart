import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita_core/supabase.dart';

import '../../config/breakpoints.dart';
import '../../widgets/directory_nav.dart';

const _bgColor = Color(0xFFFFFAF5);
const _textPrimary = Color(0xFF1A1A1A);
const _textSecondary = Color(0xFF666666);
const _brandGradient = LinearGradient(
  colors: [Color(0xFFEC4899), Color(0xFF9333EA), Color(0xFF3B82F6)],
);
const _maxWidth = 1200.0;

class DirectoryStatePage extends StatefulWidget {
  final String stateSlug;
  const DirectoryStatePage({super.key, required this.stateSlug});
  @override
  State<DirectoryStatePage> createState() => _DirectoryStatePageState();
}

class _DirectoryStatePageState extends State<DirectoryStatePage> {
  List<dynamic>? _cities;
  String _stateName = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await BCSupabase.client
          .rpc('get_directory_cities', params: {'p_state_slug': widget.stateSlug});
      final cities = result as List? ?? [];
      setState(() {
        _cities = cities;
        _stateName = _slugToName(widget.stateSlug);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  int get _totalSalons =>
      _cities?.fold<int>(0, (sum, c) => sum + ((c['salon_count'] as num?) ?? 0).toInt()) ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: LayoutBuilder(builder: (context, constraints) {
        final w = constraints.maxWidth;
        final isDesktop = WebBreakpoints.isDesktop(w);
        final isMobile = WebBreakpoints.isMobile(w);
        final crossCount = isDesktop ? 3 : isMobile ? 1 : 2;
        final hPad = isMobile ? 16.0 : 40.0;

        return CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: DirectoryNav()),
            SliverToBoxAdapter(child: _buildHero(isMobile)),
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxWidth),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 12),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.go('/'),
                          child: const Text('Inicio', style: TextStyle(color: _textSecondary, fontSize: 13)),
                        ),
                        _breadSep(),
                        GestureDetector(
                          onTap: () => context.go('/salones'),
                          child: const Text('Salones', style: TextStyle(color: _textSecondary, fontSize: 13)),
                        ),
                        _breadSep(),
                        Text(_stateName, style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              SliverFillRemaining(child: Center(child: Text('Error: $_error')))
            else if (_cities == null || _cities!.isEmpty)
              const SliverFillRemaining(child: Center(child: Text('No se encontraron ciudades')))
            else
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: _maxWidth),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: _cities!.map((c) => _buildCityCard(c, crossCount, w)).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        );
      }),
    );
  }

  Widget _breadSep() => Text('  /  ', style: TextStyle(color: _textSecondary.withValues(alpha: 0.4), fontSize: 13));

  Widget _buildHero(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 60, vertical: isMobile ? 40 : 60),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFF0F5), Color(0xFFF5F0FF), Color(0xFFF0F5FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => _brandGradient.createShader(bounds),
                child: Text(
                  'Salones en $_stateName',
                  style: TextStyle(fontSize: isMobile ? 28 : 40, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${_formatNumber(_totalSalons)} salones en ${_cities?.length ?? 0} ciudades',
                style: TextStyle(fontSize: isMobile ? 16 : 20, color: _textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCityCard(dynamic city, int crossCount, double screenW) {
    final name = city['city'] as String? ?? '';
    final slug = city['slug'] as String? ?? '';
    final count = (city['salon_count'] as num?)?.toInt() ?? 0;
    final avgRating = (city['avg_rating'] as num?)?.toDouble();
    final categories = (city['top_categories'] as List?)?.cast<String>() ?? [];
    final cardW = crossCount == 1
        ? screenW - 32
        : (screenW.clamp(0, _maxWidth) - 32 - (crossCount - 1) * 16) / crossCount;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go('/salones/${widget.stateSlug}/$slug'),
        child: Container(
          width: cardW.clamp(200, 500),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF0EBE6)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _textPrimary)),
                  ),
                  Text('$count', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textSecondary.withValues(alpha: 0.7))),
                  const SizedBox(width: 4),
                  Icon(Icons.storefront_rounded, size: 14, color: _textSecondary.withValues(alpha: 0.5)),
                ],
              ),
              if (avgRating != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 4),
                    Text('$avgRating promedio', style: const TextStyle(fontSize: 12, color: _textSecondary)),
                  ],
                ),
              ],
              if (categories.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: categories.take(4).map<Widget>((cat) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F4F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_categoryLabel(cat), style: const TextStyle(fontSize: 11, color: _textSecondary)),
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  String _slugToName(String slug) {
    return slug.split('-').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }

  static const _catLabels = {
    'hair': 'Cabello', 'nails': 'Unas', 'lashes': 'Pestanas',
    'barber': 'Barberia', 'skin': 'Piel', 'spa': 'Spa',
    'makeup': 'Maquillaje', 'brows': 'Cejas', 'massage': 'Masaje',
    'waxing': 'Depilacion', 'facial': 'Facial',
  };
  String _categoryLabel(String cat) => _catLabels[cat] ?? cat;
}
