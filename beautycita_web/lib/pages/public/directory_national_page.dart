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

class DirectoryNationalPage extends StatefulWidget {
  const DirectoryNationalPage({super.key});
  @override
  State<DirectoryNationalPage> createState() => _DirectoryNationalPageState();
}

class _DirectoryNationalPageState extends State<DirectoryNationalPage> {
  List<dynamic>? _states;
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
          .rpc('get_directory_states');
      setState(() {
        _states = result as List;
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
      _states?.fold<int>(0, (sum, s) => sum + ((s['salon_count'] as num?) ?? 0).toInt()) ?? 0;

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
            // Hero
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
                        GestureDetector(
                          onTap: () => context.go('/'),
                          child: Text('Inicio', style: TextStyle(color: _textSecondary, fontSize: 13)),
                        ),
                        Text('  /  ', style: TextStyle(color: _textSecondary.withValues(alpha: 0.4), fontSize: 13)),
                        Text('Directorio de Salones', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Loading / Error / Grid
            if (_loading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              SliverFillRemaining(child: Center(child: Text('Error: $_error')))
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
                        children: _states!.map((s) => _buildStateCard(s, crossCount, w)).toList(),
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

  Widget _buildHero(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 60,
        vertical: isMobile ? 40 : 60,
      ),
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
                  'Directorio de Salones',
                  style: TextStyle(
                    fontSize: isMobile ? 28 : 40,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${_formatNumber(_totalSalons)} salones de belleza en Mexico',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 20,
                  color: _textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '32 estados  -  360 ciudades',
                style: TextStyle(fontSize: 14, color: _textSecondary.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStateCard(dynamic state, int crossCount, double screenW) {
    final name = state['state'] as String? ?? '';
    final slug = state['slug'] as String? ?? '';
    final count = (state['salon_count'] as num?)?.toInt() ?? 0;
    final topCities = (state['top_cities'] as List?) ?? [];
    final cardW = crossCount == 1
        ? screenW - 32
        : (screenW.clamp(0, _maxWidth) - 32 - (crossCount - 1) * 16) / crossCount;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go('/salones/$slug'),
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
                    child: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _textPrimary)),
                  ),
                  Text('${_formatNumber(count)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textSecondary.withValues(alpha: 0.7))),
                  const SizedBox(width: 4),
                  Icon(Icons.storefront_rounded, size: 14, color: _textSecondary.withValues(alpha: 0.5)),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: topCities.take(4).map<Widget>((c) {
                  final city = c['city'] as String? ?? '';
                  final cnt = (c['cnt'] as num?)?.toInt() ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F4F0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('$city ($cnt)', style: const TextStyle(fontSize: 12, color: _textSecondary)),
                  );
                }).toList(),
              ),
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
}
