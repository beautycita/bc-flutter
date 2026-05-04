import 'dart:async';

import 'package:beautycita_core/supabase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/breakpoints.dart';
import '../config/router.dart';

/// Self-registration page — salon owner searches for their business,
/// auto-matches against 76K discovered salons, then redirects to
/// the pre-filled /registro/{id} flow.
class RegistrarPage extends ConsumerStatefulWidget {
  const RegistrarPage({super.key});

  @override
  ConsumerState<RegistrarPage> createState() => _RegistrarPageState();
}

class _RegistrarPageState extends ConsumerState<RegistrarPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  bool _hasSearched = false;

  static const _deepRose = Color(0xFFAA7EAA);
  static const _lightRose = Color(0xFFC8A2C8);

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _search(query.trim());
    });
  }

  Future<void> _search(String query) async {
    if (!BCSupabase.isInitialized) return;
    setState(() => _searching = true);
    try {
      // Search by phone (digits only) or business name
      final isPhone = RegExp(r'^\d{7,}$').hasMatch(query.replaceAll(RegExp(r'[\s\-\+\(\)]'), ''));
      final sanitized = query.replaceAll("'", "''");

      List<dynamic> data;
      if (isPhone) {
        final digits = query.replaceAll(RegExp(r'[\s\-\+\(\)]'), '');
        data = await BCSupabase.client
            .from(BCTables.discoveredSalons)
            .select('id, business_name, phone, location_city, location_state, feature_image_url')
            .or('phone.ilike.%$digits%')
            .eq('status', 'discovered')
            .limit(8);
      } else {
        data = await BCSupabase.client
            .from(BCTables.discoveredSalons)
            .select('id, business_name, phone, location_city, location_state, feature_image_url')
            .ilike('business_name', '%$sanitized%')
            .eq('status', 'discovered')
            .limit(8);
      }

      if (mounted) {
        setState(() {
          _results = data.cast<Map<String, dynamic>>();
          _searching = false;
          _hasSearched = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final isMobile = w < 600;
          final isDesktop = WebBreakpoints.isDesktop(w);
          final hPad = isMobile ? 16.0 : (isDesktop ? 80.0 : 32.0);

          return SingleChildScrollView(
            child: Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF8A6B8A), _deepRose, _lightRose],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: hPad,
                    vertical: isMobile ? 24 : 40,
                  ),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => context.go(WebRoutes.home),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Text(
                            'BeautyCita',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: isMobile ? 20 : 24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Registra tu Salon',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                          fontSize: isMobile ? 18 : 24,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Busca tu negocio para registrarte en segundos',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),

                // Search section
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: hPad,
                    vertical: isMobile ? 20 : 40,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isDesktop ? 640 : double.infinity),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Search card
                          Container(
                            padding: EdgeInsets.all(isMobile ? 20 : 32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Busca tu salon',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Ingresa el nombre de tu negocio o tu numero de telefono',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: 'Ej: "Salon Maria" o "3221234567"',
                                    prefixIcon: const Icon(Icons.search),
                                    suffixIcon: _searching
                                        ? const Padding(
                                            padding: EdgeInsets.all(12),
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          )
                                        : null,
                                  ),
                                  onChanged: _onSearchChanged,
                                ),

                                // Results
                                if (_results.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    'Es alguno de estos tu salon?',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...List.generate(_results.length, (i) {
                                    final salon = _results[i];
                                    return _SalonMatchCard(
                                      name: salon['business_name'] as String? ?? '',
                                      city: salon['location_city'] as String? ?? '',
                                      state: salon['location_state'] as String? ?? '',
                                      phone: salon['phone'] as String? ?? '',
                                      imageUrl: salon['feature_image_url'] as String?,
                                      onTap: () => context.go('/onboard/${salon['id']}'),
                                    );
                                  }),
                                ],

                                // No results
                                if (_hasSearched && _results.isEmpty && !_searching) ...[
                                  const SizedBox(height: 20),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.amber.shade200),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(Icons.info_outline, color: Colors.amber.shade700),
                                        const SizedBox(height: 8),
                                        Text(
                                          'No encontramos tu salon en nuestro directorio',
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Puedes registrarte manualmente — solo toma 2 minutos',
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        OutlinedButton.icon(
                                          onPressed: () => context.go(WebRoutes.auth),
                                          icon: const Icon(Icons.edit_outlined, size: 18),
                                          label: const Text('Registro manual'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SalonMatchCard extends StatefulWidget {
  const _SalonMatchCard({
    required this.name,
    required this.city,
    required this.state,
    required this.phone,
    required this.onTap,
    this.imageUrl,
  });

  final String name;
  final String city;
  final String state;
  final String phone;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  State<_SalonMatchCard> createState() => _SalonMatchCardState();
}

class _SalonMatchCardState extends State<_SalonMatchCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hovering
                ? const Color(0xFFC8A2C8).withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovering
                  ? const Color(0xFFC8A2C8)
                  : Colors.black.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              // Image or placeholder
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: widget.imageUrl != null
                    ? Image.network(
                        widget.imageUrl!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.city}, ${widget.state}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    if (widget.phone.isNotEmpty)
                      Text(
                        widget.phone,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              // Arrow
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.store_outlined, color: Colors.grey.shade400, size: 24),
    );
  }
}
