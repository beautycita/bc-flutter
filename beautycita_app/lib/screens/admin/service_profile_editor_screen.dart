import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/constants.dart';
import '../../providers/admin_provider.dart';
import '../../services/supabase_client.dart';
import '../../services/toast_service.dart';

class ServiceProfileEditorScreen extends ConsumerStatefulWidget {
  const ServiceProfileEditorScreen({super.key});

  @override
  ConsumerState<ServiceProfileEditorScreen> createState() =>
      _ServiceProfileEditorScreenState();
}

class _ServiceProfileEditorScreenState
    extends ConsumerState<ServiceProfileEditorScreen> {
  String? _expandedCategory;
  String? _expandedSubcategory;
  ServiceProfileAdmin? _editing;
  bool _saving = false;

  // Editable copies
  late double _availabilityLevel;
  late int _typicalDuration;
  late double _skillCriticality;
  late double _priceVariance;
  late double _portfolioImportance;
  late String _typicalLeadTime;
  late bool _isEventService;
  late double _searchRadiusKm;
  late bool _radiusAutoExpand;
  late double _radiusMaxMultiplier;
  late double _weightProximity;
  late double _weightAvailability;
  late double _weightRating;
  late double _weightPrice;
  late double _weightPortfolio;
  late bool _showPriceComparison;
  late bool _showPortfolioCarousel;
  late bool _showExperienceYears;
  late bool _showCertificationBadge;
  late bool _showWalkinIndicator;

  void _startEditing(ServiceProfileAdmin profile) {
    setState(() {
      _editing = profile;
      _availabilityLevel = profile.availabilityLevel;
      _typicalDuration = profile.typicalDuration;
      _skillCriticality = profile.skillCriticality;
      _priceVariance = profile.priceVariance;
      _portfolioImportance = profile.portfolioImportance;
      _typicalLeadTime = profile.typicalLeadTime;
      _isEventService = profile.isEventService;
      _searchRadiusKm = profile.searchRadiusKm;
      _radiusAutoExpand = profile.radiusAutoExpand;
      _radiusMaxMultiplier = profile.radiusMaxMultiplier;
      _weightProximity = profile.weightProximity;
      _weightAvailability = profile.weightAvailability;
      _weightRating = profile.weightRating;
      _weightPrice = profile.weightPrice;
      _weightPortfolio = profile.weightPortfolio;
      _showPriceComparison = profile.showPriceComparison;
      _showPortfolioCarousel = profile.showPortfolioCarousel;
      _showExperienceYears = profile.showExperienceYears;
      _showCertificationBadge = profile.showCertificationBadge;
      _showWalkinIndicator = profile.showWalkinIndicator;
    });
  }

  double get _weightSum =>
      _weightProximity +
      _weightAvailability +
      _weightRating +
      _weightPrice +
      _weightPortfolio;

  bool get _weightsValid => (_weightSum - 1.0).abs() <= 0.01;

  Future<void> _save() async {
    if (!_weightsValid || _editing == null) return;
    setState(() => _saving = true);

    try {
      await SupabaseClientService.client
          .from('service_profiles')
          .update({
            'availability_level': _availabilityLevel,
            'typical_duration': _typicalDuration,
            'skill_criticality': _skillCriticality,
            'price_variance': _priceVariance,
            'portfolio_importance': _portfolioImportance,
            'typical_lead_time': _typicalLeadTime,
            'is_event_service': _isEventService,
            'search_radius_km': _searchRadiusKm,
            'radius_auto_expand': _radiusAutoExpand,
            'radius_max_multiplier': _radiusMaxMultiplier,
            'weight_proximity': _weightProximity,
            'weight_availability': _weightAvailability,
            'weight_rating': _weightRating,
            'weight_price': _weightPrice,
            'weight_portfolio': _weightPortfolio,
            'show_price_comparison': _showPriceComparison,
            'show_portfolio_carousel': _showPortfolioCarousel,
            'show_experience_years': _showExperienceYears,
            'show_certification_badge': _showCertificationBadge,
            'show_walkin_indicator': _showWalkinIndicator,
          })
          .eq('service_type', _editing!.serviceType);

      ref.invalidate(serviceProfilesProvider);
      ToastService.showSuccess('${_editing!.serviceType} guardado');
      if (mounted) {
        setState(() => _editing = null);
      }
    } catch (e, stack) {
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profilesAsync = ref.watch(serviceProfilesProvider);
    final colors = Theme.of(context).colorScheme;

    if (_editing != null) {
      return _buildEditor();
    }

    return profilesAsync.when(
      data: (profiles) => _buildCategoryTree(profiles),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: GoogleFonts.nunito(
                color: colors.onSurface.withValues(alpha: 0.5))),
      ),
    );
  }

  Widget _buildCategoryTree(List<ServiceProfileAdmin> profiles) {
    final colors = Theme.of(context).colorScheme;

    // Group by category -> subcategory -> profiles
    final tree = <String, Map<String, List<ServiceProfileAdmin>>>{};
    for (final p in profiles) {
      final cat = p.category ?? 'sin_categoria';
      final sub = p.subcategory ?? 'general';
      tree.putIfAbsent(cat, () => {});
      tree[cat]!.putIfAbsent(sub, () => []);
      tree[cat]![sub]!.add(p);
    }

    final categories = tree.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      itemCount: categories.length,
      itemBuilder: (context, i) {
        final cat = categories[i];
        final subs = tree[cat]!;
        final isExpanded = _expandedCategory == cat;

        return Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppConstants.radiusMD),
          ),
          margin: const EdgeInsets.only(bottom: AppConstants.paddingSM),
          child: Column(
            children: [
              // Category header
              InkWell(
                onTap: () => setState(() {
                  _expandedCategory = isExpanded ? null : cat;
                  _expandedSubcategory = null;
                }),
                borderRadius:
                    BorderRadius.circular(AppConstants.radiusMD),
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.paddingMD),
                  child: Row(
                    children: [
                      Icon(
                        _categoryIcon(cat),
                        color: colors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _formatLabel(cat),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        '${subs.values.fold<int>(0, (s, l) => s + l.length)}',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          color: colors.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: colors.onSurface.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
              ),

              // Subcategories
              if (isExpanded)
                ...subs.entries.map((sub) {
                  final subKey = '${cat}_${sub.key}';
                  final subExpanded = _expandedSubcategory == subKey;
                  return Column(
                    children: [
                      const Divider(height: 1),
                      InkWell(
                        onTap: () => setState(() {
                          _expandedSubcategory =
                              subExpanded ? null : subKey;
                        }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.paddingLG,
                            vertical: AppConstants.paddingSM,
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _formatLabel(sub.key),
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: colors.onSurface,
                                  ),
                                ),
                              ),
                              Text(
                                '${sub.value.length}',
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  color: colors.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                subExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: colors.onSurface.withValues(alpha: 0.5),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (subExpanded)
                        ...sub.value.map((profile) => _ServiceTile(
                              profile: profile,
                              onTap: () => _startEditing(profile),
                            )),
                    ],
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEditor() {
    final p = _editing!;
    final colors = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      children: [
        // Header
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, size: 24),
              onPressed: () => setState(() => _editing = null),
            ),
            Expanded(
              child: Text(
                _formatLabel(p.serviceType),
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
            ),
          ],
        ),
        if (p.category != null)
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Text(
              '${_formatLabel(p.category!)} > ${_formatLabel(p.subcategory ?? 'general')}',
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        const SizedBox(height: AppConstants.paddingLG),

        // --- Characteristics ---
        _SectionHeader(title: 'Características del Servicio'),
        _SliderRow(
          label: 'Nivel de Disponibilidad',
          value: _availabilityLevel,
          onChanged: (v) => setState(() => _availabilityLevel = v),
        ),
        _IntSliderRow(
          label: 'Duración Típica (min)',
          value: _typicalDuration,
          min: 10,
          max: 300,
          onChanged: (v) => setState(() => _typicalDuration = v),
        ),
        _SliderRow(
          label: 'Criticidad de Habilidad',
          value: _skillCriticality,
          onChanged: (v) => setState(() => _skillCriticality = v),
        ),
        _SliderRow(
          label: 'Varianza de Precio',
          value: _priceVariance,
          onChanged: (v) => setState(() => _priceVariance = v),
        ),
        _SliderRow(
          label: 'Importancia del Portafolio',
          value: _portfolioImportance,
          onChanged: (v) => setState(() => _portfolioImportance = v),
        ),

        const SizedBox(height: AppConstants.paddingSM),

        // Lead time dropdown
        Padding(
          padding:
              const EdgeInsets.symmetric(vertical: AppConstants.paddingSM),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Tiempo de Anticipación',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: colors.onSurface,
                  ),
                ),
              ),
              DropdownButton<String>(
                value: _typicalLeadTime,
                underline: const SizedBox(),
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: colors.onSurface,
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'same_day', child: Text('Mismo día')),
                  DropdownMenuItem(
                      value: '1_day', child: Text('1 día')),
                  DropdownMenuItem(
                      value: '2_3_days', child: Text('2-3 días')),
                  DropdownMenuItem(
                      value: '1_week', child: Text('1 semana')),
                  DropdownMenuItem(
                      value: '2_weeks', child: Text('2 semanas')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _typicalLeadTime = v);
                },
              ),
            ],
          ),
        ),

        _ToggleRow(
          label: 'Servicio para Eventos',
          value: _isEventService,
          onChanged: (v) => setState(() => _isEventService = v),
        ),

        const SizedBox(height: AppConstants.paddingLG),

        // --- Search settings ---
        _SectionHeader(title: 'Configuración de Búsqueda'),
        _SliderRow(
          label: 'Radio de Búsqueda (km)',
          value: _searchRadiusKm,
          min: 1,
          max: 50,
          decimals: 1,
          onChanged: (v) => setState(() => _searchRadiusKm = v),
        ),
        _ToggleRow(
          label: 'Auto-expandir Radio',
          value: _radiusAutoExpand,
          onChanged: (v) => setState(() => _radiusAutoExpand = v),
        ),
        _SliderRow(
          label: 'Multiplicador Máximo Radio',
          value: _radiusMaxMultiplier,
          min: 1,
          max: 10,
          decimals: 1,
          onChanged: (v) => setState(() => _radiusMaxMultiplier = v),
        ),

        const SizedBox(height: AppConstants.paddingLG),

        // --- Ranking weights ---
        _SectionHeader(title: 'Pesos del Ranking'),
        // Weight sum indicator
        Container(
          margin:
              const EdgeInsets.only(bottom: AppConstants.paddingSM),
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingMD,
            vertical: AppConstants.paddingSM,
          ),
          decoration: BoxDecoration(
            color: _weightsValid
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.red.withValues(alpha: 0.1),
            borderRadius:
                BorderRadius.circular(AppConstants.radiusSM),
          ),
          child: Row(
            children: [
              Icon(
                _weightsValid ? Icons.check_circle : Icons.warning,
                size: 18,
                color: _weightsValid ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(
                'Suma: ${_weightSum.toStringAsFixed(2)} / 1.00',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _weightsValid ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ),
        _SliderRow(
          label: 'Proximidad',
          value: _weightProximity,
          onChanged: (v) => setState(() => _weightProximity = v),
        ),
        _SliderRow(
          label: 'Disponibilidad',
          value: _weightAvailability,
          onChanged: (v) => setState(() => _weightAvailability = v),
        ),
        _SliderRow(
          label: 'Calificación',
          value: _weightRating,
          onChanged: (v) => setState(() => _weightRating = v),
        ),
        _SliderRow(
          label: 'Precio',
          value: _weightPrice,
          onChanged: (v) => setState(() => _weightPrice = v),
        ),
        _SliderRow(
          label: 'Portafolio',
          value: _weightPortfolio,
          onChanged: (v) => setState(() => _weightPortfolio = v),
        ),

        const SizedBox(height: AppConstants.paddingLG),

        // --- Display toggles ---
        _SectionHeader(title: 'Opciones de Visualización'),
        _ToggleRow(
          label: 'Comparación de Precios',
          value: _showPriceComparison,
          onChanged: (v) => setState(() => _showPriceComparison = v),
        ),
        _ToggleRow(
          label: 'Carrusel de Portafolio',
          value: _showPortfolioCarousel,
          onChanged: (v) => setState(() => _showPortfolioCarousel = v),
        ),
        _ToggleRow(
          label: 'Años de Experiencia',
          value: _showExperienceYears,
          onChanged: (v) => setState(() => _showExperienceYears = v),
        ),
        _ToggleRow(
          label: 'Badge de Certificación',
          value: _showCertificationBadge,
          onChanged: (v) => setState(() => _showCertificationBadge = v),
        ),
        _ToggleRow(
          label: 'Indicador Walk-in',
          value: _showWalkinIndicator,
          onChanged: (v) => setState(() => _showWalkinIndicator = v),
        ),

        const SizedBox(height: AppConstants.paddingXL),

        // --- Buttons ---
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _startEditing(p),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.onSurface.withValues(alpha: 0.5),
                  side: BorderSide(color: Theme.of(context).dividerColor),
                  minimumSize: const Size(0, 48),
                ),
                child: const Text('RESTABLECER'),
              ),
            ),
            const SizedBox(width: AppConstants.paddingMD),
            Expanded(
              child: ElevatedButton(
                onPressed:
                    _weightsValid && !_saving ? _save : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                  disabledBackgroundColor:
                      colors.primary.withValues(alpha: 0.3),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('GUARDAR'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.paddingXL),
      ],
    );
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'cabello':
        return Icons.content_cut;
      case 'unas':
        return Icons.brush;
      case 'facial':
        return Icons.face;
      case 'maquillaje':
        return Icons.palette;
      case 'pestanas_cejas':
        return Icons.visibility;
      case 'cuerpo_spa':
        return Icons.spa;
      case 'cuidado_especializado':
        return Icons.star;
      default:
        return Icons.category;
    }
  }

  String _formatLabel(String snakeCase) {
    return snakeCase
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}

// ---------------------------------------------------------------------------
// Reusable row widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.paddingSM),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int decimals;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    this.min = 0.0,
    this.max = 1.0,
    this.decimals = 2,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: colors.onSurface,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              activeColor: colors.primary,
              inactiveColor:
                  colors.primary.withValues(alpha: 0.15),
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              value.toStringAsFixed(decimals),
              textAlign: TextAlign.end,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntSliderRow extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _IntSliderRow({
    required this.label,
    required this.value,
    this.min = 0,
    this.max = 300,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: colors.onSurface,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Slider(
              value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: max - min,
              activeColor: colors.primary,
              inactiveColor:
                  colors.primary.withValues(alpha: 0.15),
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              '$value',
              textAlign: TextAlign.end,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: colors.onSurface,
              ),
            ),
          ),
          Switch(
            value: value,
            activeColor: colors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final ServiceProfileAdmin profile;
  final VoidCallback onTap;

  const _ServiceTile({required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingLG + 12,
          vertical: AppConstants.paddingSM,
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: profile.isActive
                    ? Colors.green
                    : colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                profile.serviceType.replaceAll('_', ' '),
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: colors.onSurface,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: colors.onSurface.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
