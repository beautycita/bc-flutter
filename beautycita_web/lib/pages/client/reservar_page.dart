import 'dart:async';
import 'dart:ui_web' as ui_web;

import 'package:beautycita_core/models.dart';
import 'package:beautycita_core/supabase.dart';
import 'package:beautycita_core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OtpType;
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;

import '../../config/breakpoints.dart';
import '../../config/web_theme.dart';
import '../../data/categories.dart';
import '../../providers/booking_flow_provider.dart';
import '../../providers/client_bookings_provider.dart';
import '../../providers/curate_provider.dart';
import '../../providers/payment_provider.dart';
import '../../services/geocoding_web.dart';
import '../../services/geolocation_web.dart';
import '../../services/stripe_web.dart';
import '../../widgets/web_design_system.dart';

// ============================================================================
// ReservarPage — Single-Page Search Experience
//
// Desktop-first search layout inspired by Airbnb/OpenTable.
// Search bar at top, filter sidebar left, results grid right.
// Detail panel slides from right when a result is selected.
// ============================================================================

const _kSidebarWidth = 280.0;
const _kDetailPanelWidth = 500.0;
const _kGoldColor = Color(0xFFFFB300);

// ── Main page ────────────────────────────────────────────────────────────────

class ReservarPage extends ConsumerStatefulWidget {
  const ReservarPage({super.key});

  @override
  ConsumerState<ReservarPage> createState() => _ReservarPageState();
}

class _ReservarPageState extends ConsumerState<ReservarPage> {
  bool _locationRequested = false;

  // Filter state (local, drives curate calls)
  ServiceCategory? _selectedCategory;
  ServiceSubcategory? _selectedSubcategory;
  ServiceItem? _selectedServiceItem;
  double _maxDistanceKm = 25;
  double _minRating = 0;
  int _priceLevel = 0; // 0=all, 1=$, 2=$$, 3=$$$
  String _sortBy = 'relevancia';

  // Detail panel
  ResultCard? _detailResult;
  bool _detailOpen = false;

  // Search state
  bool _searching = false;
  bool _hasSearched = false;
  CurateResponse? _curateResponse;
  String? _searchError;
  Timer? _filterDebounce;

  // Discovered salons fallback
  bool _showingDiscovered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestLocationIfNeeded();
    });
  }

  @override
  void dispose() {
    _filterDebounce?.cancel();
    super.dispose();
  }

  Future<void> _requestLocationIfNeeded() async {
    if (_locationRequested) return;
    final flowState = ref.read(bookingFlowProvider);
    if (flowState.userLat != null) return;

    _locationRequested = true;
    try {
      final (lat, lng) = await getWebLocation();
      if (!mounted) return;
      ref.read(bookingFlowProvider.notifier).setLocation(lat, lng);
    } catch (_) {
      // Location denied -- user can enter manually via the search bar
    }
  }

  void _onCategorySelected(ServiceCategory? category) {
    setState(() {
      _selectedCategory = category;
      _selectedSubcategory = null;
      _selectedServiceItem = null;
    });
    _debouncedSearch();
  }

  void _onSubcategorySelected(ServiceSubcategory sub) {
    final hasItems = sub.items != null && sub.items!.isNotEmpty;
    if (!hasItems) {
      // Leaf subcategory acts as a service
      setState(() {
        _selectedSubcategory = sub;
        _selectedServiceItem = ServiceItem(
          id: sub.id,
          subcategoryId: sub.id,
          nameEs: sub.nameEs,
          serviceType: sub.id,
        );
      });
      _triggerSearch();
    } else {
      setState(() {
        _selectedSubcategory = sub;
        _selectedServiceItem = null;
      });
    }
  }

  void _onServiceItemSelected(ServiceSubcategory sub, ServiceItem item) {
    setState(() {
      _selectedSubcategory = sub;
      _selectedServiceItem = item;
    });
    _triggerSearch();
  }

  void _debouncedSearch() {
    _filterDebounce?.cancel();
    _filterDebounce = Timer(const Duration(milliseconds: 300), () {
      if (_selectedServiceItem != null) {
        _triggerSearch();
      }
    });
  }

  Future<void> _triggerSearch() async {
    final serviceItem = _selectedServiceItem;
    if (serviceItem == null) return;

    final flowState = ref.read(bookingFlowProvider);
    final lat = flowState.userLat;
    final lng = flowState.userLng;

    if (lat == null || lng == null) {
      setState(() {
        _searchError = 'location_missing';
        _searching = false;
        _hasSearched = true;
      });
      return;
    }

    // Sync to booking flow provider for downstream use
    if (_selectedCategory != null) {
      ref.read(bookingFlowProvider.notifier).selectCategory(_selectedCategory!);
    }
    if (_selectedSubcategory != null && _selectedServiceItem != null) {
      ref.read(bookingFlowProvider.notifier).selectService(
            _selectedSubcategory!,
            _selectedServiceItem!,
          );
    }

    setState(() {
      _searching = true;
      _searchError = null;
      _hasSearched = true;
      _showingDiscovered = false;
    });

    try {
      final response = await callCurateEngine(
        serviceType: serviceItem.serviceType,
        lat: lat,
        lng: lng,
        followUpAnswers: null,
        userId: BCSupabase.currentUserId,
      );
      if (!mounted) return;
      ref.read(bookingFlowProvider.notifier).setCurateResponse(response);
      setState(() {
        _curateResponse = response;
        _searching = false;
        if (response.results.isEmpty) {
          _showingDiscovered = true;
        }
      });
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e.toString();
      if (errorMsg.contains('404') || errorMsg.contains('not found')) {
        setState(() {
          _searchError = 'service_unavailable';
          _searching = false;
        });
      } else {
        setState(() {
          _searchError = errorMsg;
          _searching = false;
        });
      }
    }
  }

  void _onSearchBarSubmit() {
    if (_selectedServiceItem != null) {
      _triggerSearch();
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = null;
      _selectedSubcategory = null;
      _selectedServiceItem = null;
      _maxDistanceKm = 25;
      _minRating = 0;
      _priceLevel = 0;
      _sortBy = 'relevancia';
      _hasSearched = false;
      _curateResponse = null;
      _searchError = null;
      _showingDiscovered = false;
    });
    ref.read(bookingFlowProvider.notifier).reset();
  }

  void _openDetail(ResultCard result) {
    ref.read(bookingFlowProvider.notifier).selectResult(result);
    setState(() {
      _detailResult = result;
      _detailOpen = true;
    });
  }

  void _closeDetail() {
    setState(() {
      _detailOpen = false;
    });
  }

  void _onLocationSelected(double lat, double lng, String name) {
    ref.read(bookingFlowProvider.notifier).setLocationWithName(lat, lng, name);
    setState(() => _searchError = null);
    if (_selectedServiceItem != null) {
      _triggerSearch();
    }
  }

  List<ResultCard> get _filteredResults {
    if (_curateResponse == null) return [];
    var results = List<ResultCard>.from(_curateResponse!.results);

    // Filter by distance
    results = results
        .where((r) => r.transport.distanceKm <= _maxDistanceKm)
        .toList();

    // Filter by rating
    if (_minRating > 0) {
      results = results
          .where((r) => (r.staff?.rating ?? 0) >= _minRating)
          .toList();
    }

    // Filter by price level
    if (_priceLevel > 0) {
      results = results.where((r) {
        final price = r.service.price ?? 0;
        switch (_priceLevel) {
          case 1:
            return price < 300;
          case 2:
            return price >= 300 && price < 600;
          case 3:
            return price >= 600;
          default:
            return true;
        }
      }).toList();
    }

    // Sort
    switch (_sortBy) {
      case 'precio':
        results.sort((a, b) =>
            (a.service.price ?? 0).compareTo(b.service.price ?? 0));
      case 'distancia':
        results.sort((a, b) =>
            a.transport.distanceKm.compareTo(b.transport.distanceKm));
      case 'calificacion':
        results.sort((a, b) =>
            (b.staff?.rating ?? 0).compareTo(a.staff?.rating ?? 0));
      default: // relevancia = original engine ranking
        results.sort((a, b) => a.rank.compareTo(b.rank));
    }

    return results;
  }

  @override
  Widget build(BuildContext context) {
    final flowState = ref.watch(bookingFlowProvider);

    // If booking is confirmed, show confirmation overlay
    if (flowState.step == BookingStep.confirmed) {
      return _ConfirmationOverlay(
        flowState: flowState,
        onReset: () {
          _clearFilters();
          ref.read(bookingFlowProvider.notifier).reset();
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = WebBreakpoints.isMobile(width);
        final isTablet = WebBreakpoints.isTablet(width);

        return Stack(
          children: [
            // Main content
            Column(
              children: [
                // Search bar (always at top)
                _SearchBar(
                  selectedCategory: _selectedCategory,
                  selectedServiceItem: _selectedServiceItem,
                  locationName: flowState.locationName,
                  hasLocation: flowState.userLat != null,
                  onCategoryChanged: _onCategorySelected,
                  onServiceSelected: _onServiceItemSelected,
                  onSubmit: _onSearchBarSubmit,
                  isMobile: isMobile,
                ),

                // Filter chips on mobile
                if (isMobile && _hasSearched)
                  _MobileFilterChips(
                    selectedCategory: _selectedCategory,
                    maxDistanceKm: _maxDistanceKm,
                    minRating: _minRating,
                    priceLevel: _priceLevel,
                    onOpenFilters: () => _showMobileFilters(context),
                  ),

                // Body: sidebar + results
                Expanded(
                  child: _buildBody(width, isMobile, isTablet, flowState),
                ),
              ],
            ),

            // Detail panel overlay
            if (_detailOpen && _detailResult != null)
              _DetailPanelOverlay(
                result: _detailResult!,
                isMobile: isMobile,
                onClose: _closeDetail,
                flowState: flowState,
              ),
          ],
        );
      },
    );
  }

  Widget _buildBody(
    double width,
    bool isMobile,
    bool isTablet,
    BookingFlowState flowState,
  ) {
    // Location missing state
    if (_searchError == 'location_missing') {
      return _LocationInputSection(
        onLocationSelected: _onLocationSelected,
        onRetryGps: () async {
          try {
            final (lat, lng) = await getWebLocation();
            if (!mounted) return;
            ref.read(bookingFlowProvider.notifier).setLocation(lat, lng);
            setState(() => _searchError = null);
            if (_selectedServiceItem != null) _triggerSearch();
          } catch (_) {
            // stay on location input
          }
        },
      );
    }

    if (isMobile) {
      return _buildMobileBody(flowState);
    }

    // Desktop/tablet: sidebar + results grid
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter sidebar
        SizedBox(
          width: _kSidebarWidth,
          child: _FilterSidebar(
            selectedCategory: _selectedCategory,
            selectedSubcategory: _selectedSubcategory,
            selectedServiceItem: _selectedServiceItem,
            maxDistanceKm: _maxDistanceKm,
            minRating: _minRating,
            priceLevel: _priceLevel,
            onCategorySelected: _onCategorySelected,
            onSubcategorySelected: _onSubcategorySelected,
            onServiceItemSelected: _onServiceItemSelected,
            onDistanceChanged: (v) {
              setState(() => _maxDistanceKm = v);
              _debouncedSearch();
            },
            onRatingChanged: (v) {
              setState(() => _minRating = v);
              _debouncedSearch();
            },
            onPriceLevelChanged: (v) {
              setState(() => _priceLevel = v);
              _debouncedSearch();
            },
            onClear: _clearFilters,
          ),
        ),

        // Results area
        Expanded(
          child: _ResultsArea(
            searching: _searching,
            hasSearched: _hasSearched,
            searchError: _searchError,
            results: _filteredResults,
            sortBy: _sortBy,
            showingDiscovered: _showingDiscovered,
            onSortChanged: (v) => setState(() => _sortBy = v),
            onCardTap: _openDetail,
            onRetry: _triggerSearch,
            onShowDiscovered: () => setState(() => _showingDiscovered = true),
            onHideDiscovered: () => setState(() => _showingDiscovered = false),
            curateResponse: _curateResponse,
            isMobile: false,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileBody(BookingFlowState flowState) {
    return _ResultsArea(
      searching: _searching,
      hasSearched: _hasSearched,
      searchError: _searchError,
      results: _filteredResults,
      sortBy: _sortBy,
      showingDiscovered: _showingDiscovered,
      onSortChanged: (v) => setState(() => _sortBy = v),
      onCardTap: _openDetail,
      onRetry: _triggerSearch,
      onShowDiscovered: () => setState(() => _showingDiscovered = true),
      onHideDiscovered: () => setState(() => _showingDiscovered = false),
      curateResponse: _curateResponse,
      isMobile: true,
    );
  }

  void _showMobileFilters(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(BCSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kWebCardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: BCSpacing.lg),
              const Text(
                'Filtros',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: kWebTextPrimary,
                  fontFamily: 'system-ui',
                ),
              ),
              const SizedBox(height: BCSpacing.lg),
              _FilterSidebar(
                selectedCategory: _selectedCategory,
                selectedSubcategory: _selectedSubcategory,
                selectedServiceItem: _selectedServiceItem,
                maxDistanceKm: _maxDistanceKm,
                minRating: _minRating,
                priceLevel: _priceLevel,
                onCategorySelected: (cat) {
                  _onCategorySelected(cat);
                  Navigator.pop(ctx);
                },
                onSubcategorySelected: (sub) {
                  _onSubcategorySelected(sub);
                },
                onServiceItemSelected: (sub, item) {
                  _onServiceItemSelected(sub, item);
                  Navigator.pop(ctx);
                },
                onDistanceChanged: (v) {
                  setState(() => _maxDistanceKm = v);
                  _debouncedSearch();
                },
                onRatingChanged: (v) {
                  setState(() => _minRating = v);
                  _debouncedSearch();
                },
                onPriceLevelChanged: (v) {
                  setState(() => _priceLevel = v);
                  _debouncedSearch();
                },
                onClear: () {
                  _clearFilters();
                  Navigator.pop(ctx);
                },
                embedded: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Search Bar
// ============================================================================

class _SearchBar extends StatefulWidget {
  final ServiceCategory? selectedCategory;
  final ServiceItem? selectedServiceItem;
  final String? locationName;
  final bool hasLocation;
  final ValueChanged<ServiceCategory?> onCategoryChanged;
  final void Function(ServiceSubcategory, ServiceItem) onServiceSelected;
  final VoidCallback onSubmit;
  final bool isMobile;

  const _SearchBar({
    required this.selectedCategory,
    required this.selectedServiceItem,
    required this.locationName,
    required this.hasLocation,
    required this.onCategoryChanged,
    required this.onServiceSelected,
    required this.onSubmit,
    required this.isMobile,
  });

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.isMobile ? BCSpacing.md : BCSpacing.lg,
        vertical: BCSpacing.md,
      ),
      decoration: BoxDecoration(
        color: kWebSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kWebMaxContentWidth),
          child: Container(
            decoration: BoxDecoration(
              color: kWebSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kWebCardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: widget.isMobile
                ? _buildMobileLayout()
                : _buildDesktopLayout(),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Category dropdown
        Expanded(
          flex: 3,
          child: _buildCategoryDropdown(),
        ),
        _divider(),
        // Service display
        Expanded(
          flex: 3,
          child: _buildServiceDisplay(),
        ),
        _divider(),
        // Location
        Expanded(
          flex: 3,
          child: _buildLocationDisplay(),
        ),
        // Search button
        Padding(
          padding: const EdgeInsets.all(6),
          child: _buildSearchButton(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: _buildCategoryDropdown()),
            _divider(),
            Expanded(child: _buildServiceDisplay()),
          ],
        ),
        Divider(height: 1, color: kWebCardBorder),
        Row(
          children: [
            Expanded(child: _buildLocationDisplay()),
            Padding(
              padding: const EdgeInsets.all(6),
              child: _buildSearchButton(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 40,
      color: kWebCardBorder,
    );
  }

  Widget _buildCategoryDropdown() {
    return PopupMenuButton<ServiceCategory>(
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      itemBuilder: (_) => [
        for (final cat in allCategories)
          PopupMenuItem(
            value: cat,
            child: Row(
              children: [
                Text(cat.icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Text(
                  cat.nameEs,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: kWebTextPrimary,
                    fontFamily: 'system-ui',
                  ),
                ),
              ],
            ),
          ),
      ],
      onSelected: widget.onCategoryChanged,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              Icons.grid_view_outlined,
              size: 18,
              color: widget.selectedCategory != null
                  ? kWebPrimary
                  : kWebTextHint,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.selectedCategory?.nameEs ?? 'Categoria',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: widget.selectedCategory != null
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: widget.selectedCategory != null
                      ? kWebTextPrimary
                      : kWebTextHint,
                  fontFamily: 'system-ui',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.expand_more, size: 18, color: kWebTextHint),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceDisplay() {
    final hasService = widget.selectedServiceItem != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(
            Icons.content_cut_outlined,
            size: 18,
            color: hasService ? kWebPrimary : kWebTextHint,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasService
                  ? widget.selectedServiceItem!.nameEs
                  : 'Servicio',
              style: TextStyle(
                fontSize: 14,
                fontWeight: hasService ? FontWeight.w600 : FontWeight.w400,
                color: hasService ? kWebTextPrimary : kWebTextHint,
                fontFamily: 'system-ui',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationDisplay() {
    final hasLoc = widget.hasLocation;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(
            Icons.location_on_outlined,
            size: 18,
            color: hasLoc ? kWebPrimary : kWebTextHint,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.locationName ?? (hasLoc ? 'Mi ubicacion' : 'Ubicacion'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: hasLoc ? FontWeight.w600 : FontWeight.w400,
                color: hasLoc ? kWebTextPrimary : kWebTextHint,
                fontFamily: 'system-ui',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchButton() {
    final enabled = widget.selectedServiceItem != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? widget.onSubmit : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: enabled ? kWebBrandGradient : null,
            color: enabled ? null : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              const Text(
                'Buscar',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontFamily: 'system-ui',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Mobile Filter Chips (horizontal scrollable)
// ============================================================================

class _MobileFilterChips extends StatelessWidget {
  final ServiceCategory? selectedCategory;
  final double maxDistanceKm;
  final double minRating;
  final int priceLevel;
  final VoidCallback onOpenFilters;

  const _MobileFilterChips({
    required this.selectedCategory,
    required this.maxDistanceKm,
    required this.minRating,
    required this.priceLevel,
    required this.onOpenFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: kWebBackground,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: BCSpacing.md),
        children: [
          _FilterChipButton(
            icon: Icons.tune_outlined,
            label: 'Filtros',
            onTap: onOpenFilters,
            active: false,
          ),
          const SizedBox(width: 8),
          if (selectedCategory != null)
            _FilterChipButton(
              icon: null,
              label: selectedCategory!.nameEs,
              onTap: onOpenFilters,
              active: true,
            ),
          if (minRating > 0) ...[
            const SizedBox(width: 8),
            _FilterChipButton(
              icon: Icons.star_outlined,
              label: '${minRating.toStringAsFixed(0)}+',
              onTap: onOpenFilters,
              active: true,
            ),
          ],
          if (priceLevel > 0) ...[
            const SizedBox(width: 8),
            _FilterChipButton(
              icon: null,
              label: '\$' * priceLevel,
              onTap: onOpenFilters,
              active: true,
            ),
          ],
          const SizedBox(width: 8),
          _FilterChipButton(
            icon: Icons.near_me_outlined,
            label: '${maxDistanceKm.toInt()} km',
            onTap: onOpenFilters,
            active: maxDistanceKm != 25,
          ),
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final IconData? icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _FilterChipButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? kWebPrimary.withValues(alpha: 0.10) : kWebSurface,
          borderRadius: BorderRadius.circular(BCSpacing.radiusFull),
          border: Border.all(
            color: active ? kWebPrimary : kWebCardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: active ? kWebPrimary : kWebTextSecondary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active ? kWebPrimary : kWebTextPrimary,
                fontFamily: 'system-ui',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Filter Sidebar (desktop)
// ============================================================================

class _FilterSidebar extends StatelessWidget {
  final ServiceCategory? selectedCategory;
  final ServiceSubcategory? selectedSubcategory;
  final ServiceItem? selectedServiceItem;
  final double maxDistanceKm;
  final double minRating;
  final int priceLevel;
  final ValueChanged<ServiceCategory?> onCategorySelected;
  final ValueChanged<ServiceSubcategory> onSubcategorySelected;
  final void Function(ServiceSubcategory, ServiceItem) onServiceItemSelected;
  final ValueChanged<double> onDistanceChanged;
  final ValueChanged<double> onRatingChanged;
  final ValueChanged<int> onPriceLevelChanged;
  final VoidCallback onClear;
  final bool embedded;

  const _FilterSidebar({
    required this.selectedCategory,
    required this.selectedSubcategory,
    required this.selectedServiceItem,
    required this.maxDistanceKm,
    required this.minRating,
    required this.priceLevel,
    required this.onCategorySelected,
    required this.onSubcategorySelected,
    required this.onServiceItemSelected,
    required this.onDistanceChanged,
    required this.onRatingChanged,
    required this.onPriceLevelChanged,
    required this.onClear,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      padding: embedded
          ? EdgeInsets.zero
          : const EdgeInsets.all(BCSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category section
          _buildSectionTitle('Categoria'),
          const SizedBox(height: BCSpacing.sm),
          _buildCategoryList(),
          const SizedBox(height: BCSpacing.lg),

          // Subcategory / service section
          if (selectedCategory != null) ...[
            _buildSectionTitle('Servicio'),
            const SizedBox(height: BCSpacing.sm),
            _buildServiceList(),
            const SizedBox(height: BCSpacing.lg),
          ],

          // Price section
          _buildSectionTitle('Precio'),
          const SizedBox(height: BCSpacing.sm),
          _buildPriceChips(),
          const SizedBox(height: BCSpacing.lg),

          // Distance section
          _buildSectionTitle(
              'Distancia: ${maxDistanceKm.toInt()} km'),
          const SizedBox(height: BCSpacing.sm),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: kWebPrimary,
              inactiveTrackColor: kWebCardBorder,
              thumbColor: kWebPrimary,
              overlayColor: kWebPrimary.withValues(alpha: 0.12),
              trackHeight: 4,
            ),
            child: Slider(
              value: maxDistanceKm,
              min: 5,
              max: 50,
              divisions: 9,
              label: '${maxDistanceKm.toInt()} km',
              onChanged: onDistanceChanged,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('5 km',
                  style: TextStyle(
                      fontSize: 11, color: kWebTextHint, fontFamily: 'system-ui')),
              Text('50 km',
                  style: TextStyle(
                      fontSize: 11, color: kWebTextHint, fontFamily: 'system-ui')),
            ],
          ),
          const SizedBox(height: BCSpacing.lg),

          // Rating section
          _buildSectionTitle('Calificacion'),
          const SizedBox(height: BCSpacing.sm),
          _buildRatingFilter(),
          const SizedBox(height: BCSpacing.xl),

          // Clear filters
          Center(
            child: TextButton(
              onPressed: onClear,
              child: const Text(
                'Limpiar filtros',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: kWebPrimary,
                  fontFamily: 'system-ui',
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (embedded) return content;

    return Container(
      decoration: BoxDecoration(
        color: kWebSurface,
        border: Border(
          right: BorderSide(color: kWebCardBorder, width: 1),
        ),
      ),
      child: content,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: kWebTextSecondary,
        letterSpacing: 0.5,
        fontFamily: 'system-ui',
      ),
    );
  }

  Widget _buildCategoryList() {
    return Column(
      children: [
        for (final cat in allCategories)
          _CategoryRadioTile(
            category: cat,
            selected: selectedCategory?.id == cat.id,
            onTap: () => onCategorySelected(cat),
          ),
      ],
    );
  }

  Widget _buildServiceList() {
    if (selectedCategory == null) return const SizedBox.shrink();
    final subs = selectedCategory!.subcategories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final sub in subs) ...[
          _SubcategoryTile(
            sub: sub,
            selected: selectedSubcategory?.id == sub.id,
            onTap: () => onSubcategorySelected(sub),
          ),
          // Show items if this subcategory is selected and has items
          if (selectedSubcategory?.id == sub.id &&
              sub.items != null &&
              sub.items!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Column(
                children: [
                  for (final item in sub.items!)
                    _ServiceItemTile(
                      item: item,
                      selected: selectedServiceItem?.id == item.id,
                      onTap: () => onServiceItemSelected(sub, item),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildPriceChips() {
    const labels = ['Todos', '\$', '\$\$', '\$\$\$'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (int i = 0; i < labels.length; i++)
          _PriceChip(
            label: labels[i],
            selected: priceLevel == i,
            onTap: () => onPriceLevelChanged(i),
          ),
      ],
    );
  }

  Widget _buildRatingFilter() {
    const options = [0.0, 3.0, 4.0, 4.5];
    const labels = ['Todas', '3+', '4+', '4.5+'];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (int i = 0; i < options.length; i++)
          _RatingChip(
            label: labels[i],
            selected: minRating == options[i],
            onTap: () => onRatingChanged(options[i]),
            showStar: i > 0,
          ),
      ],
    );
  }
}

// ── Sidebar tile widgets ─────────────────────────────────────────────────────

class _CategoryRadioTile extends StatefulWidget {
  final ServiceCategory category;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryRadioTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_CategoryRadioTile> createState() => _CategoryRadioTileState();
}

class _CategoryRadioTileState extends State<_CategoryRadioTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.selected
                ? kWebPrimary.withValues(alpha: 0.06)
                : _hovering
                    ? kWebPrimary.withValues(alpha: 0.03)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border(
              left: BorderSide(
                color: widget.selected ? kWebPrimary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(widget.category.icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.category.nameEs,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        widget.selected ? FontWeight.w600 : FontWeight.w400,
                    color:
                        widget.selected ? kWebPrimary : kWebTextPrimary,
                    fontFamily: 'system-ui',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubcategoryTile extends StatefulWidget {
  final ServiceSubcategory sub;
  final bool selected;
  final VoidCallback onTap;

  const _SubcategoryTile({
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_SubcategoryTile> createState() => _SubcategoryTileState();
}

class _SubcategoryTileState extends State<_SubcategoryTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final hasItems = widget.sub.items != null && widget.sub.items!.isNotEmpty;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.selected
                ? kWebPrimary.withValues(alpha: 0.06)
                : _hovering
                    ? kWebPrimary.withValues(alpha: 0.03)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: widget.selected ? kWebPrimary : kWebTextHint,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.sub.nameEs,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        widget.selected ? FontWeight.w600 : FontWeight.w400,
                    color:
                        widget.selected ? kWebPrimary : kWebTextPrimary,
                    fontFamily: 'system-ui',
                  ),
                ),
              ),
              if (hasItems)
                Icon(
                  widget.selected
                      ? Icons.expand_less
                      : Icons.expand_more,
                  size: 16,
                  color: kWebTextHint,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceItemTile extends StatefulWidget {
  final ServiceItem item;
  final bool selected;
  final VoidCallback onTap;

  const _ServiceItemTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_ServiceItemTile> createState() => _ServiceItemTileState();
}

class _ServiceItemTileState extends State<_ServiceItemTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: widget.selected
                ? kWebPrimary.withValues(alpha: 0.08)
                : _hovering
                    ? kWebPrimary.withValues(alpha: 0.03)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                widget.selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 14,
                color:
                    widget.selected ? kWebPrimary : kWebTextHint,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.item.nameEs,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        widget.selected ? FontWeight.w600 : FontWeight.w400,
                    color: widget.selected
                        ? kWebPrimary
                        : kWebTextSecondary,
                    fontFamily: 'system-ui',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PriceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_PriceChip> createState() => _PriceChipState();
}

class _PriceChipState extends State<_PriceChip> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: widget.selected ? kWebBrandGradient : null,
            color: widget.selected
                ? null
                : _hovering
                    ? kWebPrimary.withValues(alpha: 0.04)
                    : kWebSurface,
            borderRadius: BorderRadius.circular(BCSpacing.radiusFull),
            border: Border.all(
              color: widget.selected ? Colors.transparent : kWebCardBorder,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: widget.selected ? Colors.white : kWebTextPrimary,
              fontFamily: 'system-ui',
            ),
          ),
        ),
      ),
    );
  }
}

class _RatingChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool showStar;

  const _RatingChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.showStar = false,
  });

  @override
  State<_RatingChip> createState() => _RatingChipState();
}

class _RatingChipState extends State<_RatingChip> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: widget.selected
                ? kWebPrimary.withValues(alpha: 0.10)
                : _hovering
                    ? kWebPrimary.withValues(alpha: 0.04)
                    : kWebSurface,
            borderRadius: BorderRadius.circular(BCSpacing.radiusFull),
            border: Border.all(
              color: widget.selected ? kWebPrimary : kWebCardBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showStar) ...[
                Icon(Icons.star_rounded,
                    size: 14, color: widget.selected ? kWebPrimary : _kGoldColor),
                const SizedBox(width: 4),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
                  color: widget.selected ? kWebPrimary : kWebTextPrimary,
                  fontFamily: 'system-ui',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Results Area
// ============================================================================

class _ResultsArea extends StatelessWidget {
  final bool searching;
  final bool hasSearched;
  final String? searchError;
  final List<ResultCard> results;
  final String sortBy;
  final bool showingDiscovered;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<ResultCard> onCardTap;
  final VoidCallback onRetry;
  final VoidCallback onShowDiscovered;
  final VoidCallback onHideDiscovered;
  final CurateResponse? curateResponse;
  final bool isMobile;

  const _ResultsArea({
    required this.searching,
    required this.hasSearched,
    required this.searchError,
    required this.results,
    required this.sortBy,
    required this.showingDiscovered,
    required this.onSortChanged,
    required this.onCardTap,
    required this.onRetry,
    required this.onShowDiscovered,
    required this.onHideDiscovered,
    required this.curateResponse,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? BCSpacing.md : BCSpacing.lg),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    // Initial empty state (no search yet)
    if (!hasSearched) {
      return _buildInitialState();
    }

    // Loading
    if (searching) {
      return _buildLoadingState();
    }

    // Service unavailable
    if (searchError == 'service_unavailable') {
      return _buildServiceUnavailable();
    }

    // Generic error
    if (searchError != null && searchError != 'location_missing') {
      return _buildErrorState(searchError!);
    }

    // Discovered salons fallback
    if (showingDiscovered) {
      return _DiscoveredSalonsList(
        hasResults: curateResponse?.results.isNotEmpty ?? false,
        onGoBack: onHideDiscovered,
      );
    }

    // Results
    if (results.isEmpty && curateResponse != null) {
      return _buildEmptyResults();
    }

    return _buildResultsGrid(context);
  }

  Widget _buildInitialState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: kWebPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.search_outlined,
                size: 40,
                color: kWebPrimary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: BCSpacing.lg),
            const Text(
              'Encuentra tu salon ideal',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: kWebTextPrimary,
                fontFamily: 'system-ui',
              ),
            ),
            const SizedBox(height: BCSpacing.sm),
            const Text(
              'Selecciona una categoria y servicio para comenzar',
              style: TextStyle(
                fontSize: 16,
                color: kWebTextSecondary,
                fontFamily: 'system-ui',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Buscando las mejores opciones...',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: kWebTextPrimary,
            fontFamily: 'system-ui',
          ),
        ),
        const SizedBox(height: BCSpacing.lg),
        for (int i = 0; i < 6; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: BCSpacing.md),
            child: _ShimmerCard(),
          ),
      ],
    );
  }

  Widget _buildServiceUnavailable() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction_outlined,
                size: 56, color: kWebSecondary.withValues(alpha: 0.6)),
            const SizedBox(height: BCSpacing.md),
            const Text(
              'Servicio temporalmente no disponible',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: kWebTextPrimary,
                fontFamily: 'system-ui',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: BCSpacing.sm),
            const Text(
              'Estamos trabajando para habilitar este servicio.\nIntenta de nuevo mas tarde.',
              style: TextStyle(
                fontSize: 15,
                color: kWebTextSecondary,
                fontFamily: 'system-ui',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Color(0xFFEF4444)),
            const SizedBox(height: BCSpacing.md),
            const Text(
              'Error buscando salones',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: kWebTextPrimary,
                fontFamily: 'system-ui',
              ),
            ),
            const SizedBox(height: BCSpacing.sm),
            Text(
              error,
              style: const TextStyle(
                fontSize: 14,
                color: kWebTextSecondary,
                fontFamily: 'system-ui',
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: BCSpacing.lg),
            WebGradientButton(
              onPressed: onRetry,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_outlined,
                size: 56, color: kWebTextHint.withValues(alpha: 0.5)),
            const SizedBox(height: BCSpacing.md),
            const Text(
              'Aun no hay salones registrados con este servicio',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: kWebTextPrimary,
                fontFamily: 'system-ui',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: BCSpacing.sm),
            const Text(
              'Pero conocemos miles de salones en tu zona. Invita a tu salon favorito a unirse — es gratis para ellos.',
              style: TextStyle(
                fontSize: 15,
                color: kWebTextSecondary,
                fontFamily: 'system-ui',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: BCSpacing.lg),
            WebOutlinedButton(
              onPressed: onShowDiscovered,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.explore_outlined, size: 16, color: kWebPrimary),
                  SizedBox(width: 8),
                  Text('Ver salones cerca de ti'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Results header: count + sort
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${results.length} resultado${results.length == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: kWebTextSecondary,
                fontFamily: 'system-ui',
              ),
            ),
            _SortDropdown(
              value: sortBy,
              onChanged: onSortChanged,
            ),
          ],
        ),
        const SizedBox(height: BCSpacing.md),

        // Results grid
        LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            final cols = isMobile
                ? 1
                : availableWidth >= 900
                    ? 3
                    : 2;

            return StaggeredFadeIn(
              staggerDelay: const Duration(milliseconds: 80),
              spacing: 0,
              children: [
                Wrap(
                  spacing: BCSpacing.md,
                  runSpacing: BCSpacing.md,
                  children: [
                    for (final result in results)
                      SizedBox(
                        width: cols == 1
                            ? availableWidth
                            : (availableWidth - BCSpacing.md * (cols - 1)) /
                                cols,
                        child: _ResultCardWidget(
                          result: result,
                          onTap: () => onCardTap(result),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),

        // "Ver mas salones" button
        const SizedBox(height: BCSpacing.lg),
        Center(
          child: WebOutlinedButton(
            onPressed: onShowDiscovered,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.explore_outlined, size: 16, color: kWebPrimary),
                SizedBox(width: 8),
                Text('Ver mas salones cerca de ti'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Sort dropdown ────────────────────────────────────────────────────────────

class _SortDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _SortDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      itemBuilder: (_) => [
        _sortItem('relevancia', 'Relevancia'),
        _sortItem('precio', 'Precio'),
        _sortItem('distancia', 'Distancia'),
        _sortItem('calificacion', 'Calificacion'),
      ],
      onSelected: onChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kWebCardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort, size: 16, color: kWebTextSecondary),
            const SizedBox(width: 6),
            Text(
              _labelFor(value),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: kWebTextPrimary,
                fontFamily: 'system-ui',
              ),
            ),
            const Icon(Icons.expand_more, size: 16, color: kWebTextHint),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _sortItem(String val, String label) {
    return PopupMenuItem(
      value: val,
      child: Row(
        children: [
          if (value == val)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.check, size: 16, color: kWebPrimary),
            ),
          Text(label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: value == val ? FontWeight.w600 : FontWeight.w400,
                color: kWebTextPrimary,
                fontFamily: 'system-ui',
              )),
        ],
      ),
    );
  }

  String _labelFor(String val) {
    switch (val) {
      case 'precio':
        return 'Precio';
      case 'distancia':
        return 'Distancia';
      case 'calificacion':
        return 'Calificacion';
      default:
        return 'Relevancia';
    }
  }
}

// ============================================================================
// Result Card Widget (grid card)
// ============================================================================

class _ResultCardWidget extends StatefulWidget {
  final ResultCard result;
  final VoidCallback onTap;

  const _ResultCardWidget({required this.result, required this.onTap});

  @override
  State<_ResultCardWidget> createState() => _ResultCardWidgetState();
}

class _ResultCardWidgetState extends State<_ResultCardWidget> {
  String _formatSlotDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      final now = DateTime.now();
      final isToday = dt.year == now.year &&
          dt.month == now.month &&
          dt.day == now.day;
      final isTomorrow = dt.year == now.year &&
          dt.month == now.month &&
          dt.day == now.day + 1;
      final timeFormat = DateFormat('h:mm a', 'es');
      if (isToday) return 'Hoy ${timeFormat.format(dt)}';
      if (isTomorrow) return 'Manana ${timeFormat.format(dt)}';
      final dayFormat = DateFormat('MMM d', 'es');
      return '${dayFormat.format(dt)}, ${timeFormat.format(dt)}';
    } catch (_) {
      return isoString;
    }
  }

  String _formatPrice(double price, String currency) {
    if (currency.toUpperCase() == 'MXN') {
      return '\$${price.toStringAsFixed(0)}';
    }
    return '\$${price.toStringAsFixed(0)} $currency';
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final hasPhoto =
        result.business.photoUrl != null && result.business.photoUrl!.isNotEmpty;

    return WebCard(
      onTap: widget.onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo area
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              height: 160,
              width: double.infinity,
              child: hasPhoto
                  ? Image.network(
                      result.business.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _buildPhotoPlaceholder(result.business.name),
                    )
                  : _buildPhotoPlaceholder(result.business.name),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + rating
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        result.business.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: kWebTextPrimary,
                          fontFamily: 'system-ui',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (result.staff != null) ...[
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 16, color: _kGoldColor),
                          const SizedBox(width: 2),
                          Text(
                            result.staff!.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _kGoldColor,
                              fontFamily: 'system-ui',
                            ),
                          ),
                          Text(
                            ' (${result.staff!.totalReviews})',
                            style: const TextStyle(
                              fontSize: 12,
                              color: kWebTextHint,
                              fontFamily: 'system-ui',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),

                // Service + price
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        result.service.name,
                        style: const TextStyle(
                          fontSize: 14,
                          color: kWebTextSecondary,
                          fontFamily: 'system-ui',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _formatPrice(
                          result.service.price ?? 0, result.service.currency),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: kWebPrimary,
                        fontFamily: 'system-ui',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Slot badge + distance
                Row(
                  children: [
                    if (result.slot != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: kWebBrandGradient,
                          borderRadius:
                              BorderRadius.circular(BCSpacing.radiusFull),
                        ),
                        child: Text(
                          _formatSlotDate(result.slot!.startsAt),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontFamily: 'system-ui',
                          ),
                        ),
                      ),
                    const Spacer(),
                    Icon(Icons.near_me_outlined,
                        size: 14, color: kWebTextHint),
                    const SizedBox(width: 4),
                    Text(
                      '${result.transport.distanceKm.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontSize: 12,
                        color: kWebTextHint,
                        fontFamily: 'system-ui',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // RESERVAR button
                SizedBox(
                  width: double.infinity,
                  child: WebGradientButton(
                    onPressed: widget.onTap,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: const Text(
                      'RESERVAR',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPlaceholder(String name) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            kWebPrimary.withValues(alpha: 0.15),
            kWebSecondary.withValues(alpha: 0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.storefront_outlined,
          size: 48,
          color: kWebPrimary.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

// ============================================================================
// Shimmer Skeleton Card
// ============================================================================

class _ShimmerCard extends StatefulWidget {
  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.08, end: 0.18).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final opacity = _animation.value;
        return Container(
          decoration: BoxDecoration(
            color: kWebSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kWebCardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: opacity),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 18,
                      width: 180,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: opacity),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 14,
                      width: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: opacity),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 14,
                      width: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: opacity),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      height: 40,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: opacity),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// Detail Panel Overlay (slides from right)
// ============================================================================

class _DetailPanelOverlay extends ConsumerStatefulWidget {
  final ResultCard result;
  final bool isMobile;
  final VoidCallback onClose;
  final BookingFlowState flowState;

  const _DetailPanelOverlay({
    required this.result,
    required this.isMobile,
    required this.onClose,
    required this.flowState,
  });

  @override
  ConsumerState<_DetailPanelOverlay> createState() =>
      _DetailPanelOverlayState();
}

class _DetailPanelOverlayState extends ConsumerState<_DetailPanelOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;

  // Payment state
  bool _isAuthenticated = false;
  bool _creatingIntent = false;
  bool _confirmingPayment = false;
  String? _clientSecret;
  String? _paymentIntentId;
  String? _error;
  StripeWeb? _stripe;
  String? _stripeContainerId;
  bool _elementMounted = false;
  String? _selectedTransport;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _slideController.forward();
    _checkAuth();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _stripe?.dispose();
    super.dispose();
  }

  void _checkAuth() {
    _isAuthenticated = BCSupabase.client.auth.currentUser != null;
  }

  void _onAuthSuccess() {
    if (!mounted) return;
    setState(() => _isAuthenticated = true);
    _initPayment();
  }

  Future<void> _initPayment() async {
    if (_clientSecret != null) return;
    setState(() {
      _creatingIntent = true;
      _error = null;
    });

    try {
      final result = widget.result;
      final user = BCSupabase.client.auth.currentUser!;

      final intentResult = await createWebPaymentIntent(
        serviceId: result.service.id ?? '',
        businessId: result.business.id,
        staffId: result.staff!.id,
        scheduledAt: result.slot!.startsAt,
        amountCents: ((result.service.price ?? 0) * 100).round(),
        userId: user.id,
      );

      if (!mounted) return;

      final clientSecret = intentResult['client_secret'] as String?;
      final paymentIntentId = intentResult['payment_intent_id'] as String? ??
          intentResult['id'] as String?;

      if (clientSecret == null || clientSecret.isEmpty) {
        throw Exception('No se obtuvo client_secret del servidor');
      }

      setState(() {
        _clientSecret = clientSecret;
        _paymentIntentId = paymentIntentId;
        _creatingIntent = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mountStripeElement();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _creatingIntent = false;
        _error = e.toString();
      });
    }
  }

  void _mountStripeElement() {
    if (_clientSecret == null || _elementMounted) return;

    final stripeKey = dotenv.env['STRIPE_PUBLIC_KEY'] ?? '';
    if (stripeKey.isEmpty) {
      setState(() => _error = 'Stripe key not configured');
      return;
    }

    _stripe = StripeWeb(stripeKey);
    final containerId = _stripeContainerId;
    if (containerId == null) return;

    try {
      _stripe!.mountPaymentElement(_clientSecret!, containerId);
      setState(() => _elementMounted = true);
    } catch (e) {
      setState(() => _error = 'Error montando formulario de pago: $e');
    }
  }

  Future<void> _confirmPayment() async {
    if (_stripe == null || !_elementMounted) return;

    setState(() {
      _confirmingPayment = true;
      _error = null;
    });

    try {
      final returnUrl =
          '${Uri.base.origin}/reservar?payment_status=success';
      final errorMsg = await _stripe!.confirmPayment(returnUrl);

      if (errorMsg != null) {
        if (!mounted) return;
        setState(() {
          _confirmingPayment = false;
          _error = errorMsg;
        });
        return;
      }

      final flowState = ref.read(bookingFlowProvider);
      final result = widget.result;
      final user = BCSupabase.client.auth.currentUser!;

      final appointmentId = await createAppointment(
        userId: user.id,
        businessId: result.business.id,
        staffId: result.staff!.id,
        serviceId: result.service.id ?? '',
        serviceName: result.service.name,
        serviceType:
            flowState.selectedService?.serviceType ?? result.service.id ?? '',
        startsAt: result.slot!.startsAt,
        endsAt: result.slot!.endsAt,
        price: result.service.price ?? 0,
        paymentIntentId: _paymentIntentId ?? '',
      );

      if (!mounted) return;

      // Save transport if selected
      if (_selectedTransport != null) {
        try {
          await BCSupabase.client
              .from(BCTables.appointments)
              .update({'transport_mode': _selectedTransport})
              .eq('id', appointmentId);
        } catch (e) {
          debugPrint('[RESERVAR] Transport mode update failed: $e');
        }
        ref
            .read(bookingFlowProvider.notifier)
            .setTransportMode(_selectedTransport!);
      }

      ref.read(bookingFlowProvider.notifier).setBookingConfirmed(appointmentId);

      // Invalidate client bookings so "Mis Citas" reflects the new appointment
      ref.invalidate(clientBookingsProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _confirmingPayment = false;
        _error = e.toString();
      });
    }
  }

  void _close() async {
    await _slideController.reverse();
    widget.onClose();
  }

  String _formatSlotDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      final dayFormat = DateFormat('EEEE d MMMM', 'es');
      final timeFormat = DateFormat('h:mm a', 'es');
      return '${dayFormat.format(dt)}, ${timeFormat.format(dt)}';
    } catch (_) {
      return isoString;
    }
  }

  String _formatPrice(double price, String currency) {
    if (currency.toUpperCase() == 'MXN') {
      return '\$${price.toStringAsFixed(0)} MXN';
    }
    return '\$${price.toStringAsFixed(0)} $currency';
  }

  @override
  Widget build(BuildContext context) {
    final panelWidth =
        widget.isMobile ? MediaQuery.of(context).size.width : _kDetailPanelWidth;

    return Stack(
      children: [
        // Scrim
        GestureDetector(
          onTap: _close,
          child: AnimatedBuilder(
            animation: _slideController,
            builder: (context, child) => Container(
              color: Colors.black
                  .withValues(alpha: 0.4 * _slideController.value),
            ),
          ),
        ),

        // Panel
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: panelWidth,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              decoration: BoxDecoration(
                color: kWebSurface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(-4, 0),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header
                  _buildPanelHeader(),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(BCSpacing.lg),
                      child: _buildPanelContent(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPanelHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: BCSpacing.lg, vertical: 14),
      decoration: BoxDecoration(
        color: kWebSurface,
        border: Border(
          bottom: BorderSide(color: kWebCardBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.result.business.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: kWebTextPrimary,
                fontFamily: 'system-ui',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: _close,
            icon: const Icon(Icons.close, color: kWebTextSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelContent() {
    final result = widget.result;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Photo
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 200,
            width: double.infinity,
            child: result.business.photoUrl != null &&
                    result.business.photoUrl!.isNotEmpty
                ? Image.network(
                    result.business.photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _buildGradientPlaceholder(),
                  )
                : _buildGradientPlaceholder(),
          ),
        ),
        const SizedBox(height: BCSpacing.lg),

        // Rating
        if (result.staff != null)
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 20, color: _kGoldColor),
              const SizedBox(width: 4),
              Text(
                result.staff!.rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _kGoldColor,
                  fontFamily: 'system-ui',
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '(${result.staff!.totalReviews} resenas)',
                style: const TextStyle(
                  fontSize: 14,
                  color: kWebTextSecondary,
                  fontFamily: 'system-ui',
                ),
              ),
            ],
          ),
        const SizedBox(height: BCSpacing.md),

        // Address + distance
        if (result.business.address != null)
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 16, color: kWebTextSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${result.business.address} (${result.transport.distanceKm.toStringAsFixed(1)} km)',
                  style: const TextStyle(
                    fontSize: 14,
                    color: kWebTextSecondary,
                    fontFamily: 'system-ui',
                  ),
                ),
              ),
            ],
          ),

        const SizedBox(height: BCSpacing.lg),
        Divider(color: kWebCardBorder, height: 1),
        const SizedBox(height: BCSpacing.lg),

        // Service details
        const Text(
          'Detalles del servicio',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: kWebTextPrimary,
            fontFamily: 'system-ui',
          ),
        ),
        const SizedBox(height: BCSpacing.md),
        WebInfoRow(
          icon: Icons.content_cut_outlined,
          iconColor: kWebPrimary,
          label: 'Servicio',
          value: result.service.name,
        ),
        const SizedBox(height: 10),
        if (result.staff != null) ...[
          WebInfoRow(
            icon: Icons.person_outlined,
            iconColor: kWebSecondary,
            label: 'Estilista',
            value: result.staff!.name,
          ),
          const SizedBox(height: 10),
        ],
        if (result.slot != null) ...[
          WebInfoRow(
            icon: Icons.calendar_today_outlined,
            iconColor: kWebTertiary,
            label: 'Horario',
            value:
                '${_formatSlotDate(result.slot!.startsAt)} -- ${result.service.durationMinutes} min',
          ),
          const SizedBox(height: 10),
        ],
        WebInfoRow(
          icon: Icons.directions_car_outlined,
          iconColor: kWebTextSecondary,
          label: 'Distancia',
          value:
              '${result.transport.durationMin} min -- ${result.transport.distanceKm.toStringAsFixed(1)} km',
        ),
        const SizedBox(height: BCSpacing.md),

        // Review snippet
        if (result.reviewSnippet != null &&
            !result.reviewSnippet!.isFallback) ...[
          Divider(color: kWebCardBorder, height: 1),
          const SizedBox(height: BCSpacing.md),
          Text(
            '\u201c${result.reviewSnippet!.text}\u201d',
            style: const TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: kWebTextSecondary,
              fontFamily: 'system-ui',
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (result.reviewSnippet!.authorName != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '\u2014 ${result.reviewSnippet!.authorName}',
                style: const TextStyle(
                  fontSize: 12,
                  color: kWebTextHint,
                  fontFamily: 'system-ui',
                ),
              ),
            ),
          const SizedBox(height: BCSpacing.md),
        ],

        // Price
        Divider(color: kWebCardBorder, height: 1),
        const SizedBox(height: BCSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: kWebTextPrimary,
                fontFamily: 'system-ui',
              ),
            ),
            Text(
              _formatPrice(
                  result.service.price ?? 0, result.service.currency),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: kWebPrimary,
                fontFamily: 'system-ui',
              ),
            ),
          ],
        ),
        const SizedBox(height: BCSpacing.lg),

        // Transport options
        const Text(
          'Transporte',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: kWebTextPrimary,
            fontFamily: 'system-ui',
          ),
        ),
        const SizedBox(height: BCSpacing.sm),
        _TransportSelector(
          selected: _selectedTransport,
          onSelected: (mode) => setState(() => _selectedTransport = mode),
        ),
        const SizedBox(height: BCSpacing.lg),

        // Payment section
        Divider(color: kWebCardBorder, height: 1),
        const SizedBox(height: BCSpacing.lg),
        _buildPaymentSection(),
      ],
    );
  }

  Widget _buildPaymentSection() {
    if (!_isAuthenticated) {
      return _PhoneVerification(onSuccess: _onAuthSuccess);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pago',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: kWebTextPrimary,
            fontFamily: 'system-ui',
          ),
        ),
        const SizedBox(height: BCSpacing.md),

        if (_error != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(BCSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(BCSpacing.radiusSm),
              border: Border.all(
                color: const Color(0xFFEF4444).withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              _error!,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFEF4444),
                fontFamily: 'system-ui',
              ),
            ),
          ),
          const SizedBox(height: BCSpacing.md),
        ],

        if (_creatingIntent)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: BCSpacing.xl),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: BCSpacing.md),
                  Text(
                    'Preparando formulario de pago...',
                    style: TextStyle(
                      fontSize: 14,
                      color: kWebTextSecondary,
                      fontFamily: 'system-ui',
                    ),
                  ),
                ],
              ),
            ),
          ),

        if (!_creatingIntent && _clientSecret == null && _error == null)
          SizedBox(
            width: double.infinity,
            child: WebGradientButton(
              onPressed: _initPayment,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: const Text(
                'Continuar al pago',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),

        if (_clientSecret != null && !_creatingIntent) ...[
          _StripeElementContainer(
            onContainerReady: (containerId) {
              _stripeContainerId = containerId;
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) _mountStripeElement();
              });
            },
          ),
          const SizedBox(height: BCSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: WebGradientButton(
              onPressed: _confirmingPayment || !_elementMounted
                  ? null
                  : _confirmPayment,
              isLoading: _confirmingPayment,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Confirmar Reserva -- ${_formatPrice(widget.result.service.price ?? 0, widget.result.service.currency)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],

        if (_error != null && _clientSecret == null && !_creatingIntent) ...[
          const SizedBox(height: BCSpacing.md),
          Center(
            child: WebGradientButton(
              onPressed: _initPayment,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: const Text('Reintentar'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGradientPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            kWebPrimary.withValues(alpha: 0.15),
            kWebSecondary.withValues(alpha: 0.10),
            kWebTertiary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.storefront_outlined,
          size: 56,
          color: kWebPrimary.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

// ── Transport selector ───────────────────────────────────────────────────────

class _TransportSelector extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelected;

  const _TransportSelector({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TransportPill(
          icon: Icons.directions_car_outlined,
          label: 'Carro',
          mode: 'car',
          selected: selected == 'car',
          onTap: () => onSelected('car'),
        ),
        const SizedBox(width: 8),
        _TransportPill(
          icon: Icons.local_taxi_outlined,
          label: 'Uber',
          mode: 'uber',
          selected: selected == 'uber',
          onTap: () => onSelected('uber'),
        ),
        const SizedBox(width: 8),
        _TransportPill(
          icon: Icons.directions_bus_outlined,
          label: 'Publico',
          mode: 'transit',
          selected: selected == 'transit',
          onTap: () => onSelected('transit'),
        ),
      ],
    );
  }
}

class _TransportPill extends StatefulWidget {
  final IconData icon;
  final String label;
  final String mode;
  final bool selected;
  final VoidCallback onTap;

  const _TransportPill({
    required this.icon,
    required this.label,
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_TransportPill> createState() => _TransportPillState();
}

class _TransportPillState extends State<_TransportPill> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: widget.selected
                  ? kWebPrimary.withValues(alpha: 0.08)
                  : _hovering
                      ? kWebPrimary.withValues(alpha: 0.03)
                      : kWebSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.selected ? kWebPrimary : kWebCardBorder,
                width: widget.selected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  size: 22,
                  color:
                      widget.selected ? kWebPrimary : kWebTextSecondary,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        widget.selected ? FontWeight.w600 : FontWeight.w500,
                    color: widget.selected
                        ? kWebPrimary
                        : kWebTextSecondary,
                    fontFamily: 'system-ui',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Stripe Element Container
// ============================================================================

class _StripeElementContainer extends StatefulWidget {
  const _StripeElementContainer({required this.onContainerReady});

  final ValueChanged<String> onContainerReady;

  @override
  State<_StripeElementContainer> createState() =>
      _StripeElementContainerState();
}

class _StripeElementContainerState extends State<_StripeElementContainer> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType =
        'stripe-payment-element-${DateTime.now().millisecondsSinceEpoch}';
    final containerId = 'payment-element-container';

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) {
        final div = web.document.createElement('div') as web.HTMLDivElement;
        div.id = containerId;
        div.style.minHeight = '300px';
        return div;
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onContainerReady(containerId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 350,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}

// ============================================================================
// Phone Verification
// ============================================================================

class _PhoneVerification extends StatefulWidget {
  const _PhoneVerification({required this.onSuccess});

  final VoidCallback onSuccess;

  @override
  State<_PhoneVerification> createState() => _PhoneVerificationState();
}

class _PhoneVerificationState extends State<_PhoneVerification> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpSent = false;
  bool _loading = false;
  String? _error;
  int _resendCountdown = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  String get _fullPhoneNumber {
    final raw = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (raw.startsWith('52')) return '+$raw';
    return '+52$raw';
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) timer.cancel();
      });
    });
  }

  Future<void> _sendOtp() async {
    final phone = _fullPhoneNumber;
    if (phone.length < 12) {
      setState(() => _error = 'Ingresa un numero valido de 10 digitos');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await BCSupabase.client.auth.signInWithOtp(phone: phone);
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _loading = false;
      });
      _startResendTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Error enviando codigo: $e';
      });
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Ingresa el codigo de 6 digitos');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await BCSupabase.client.auth.verifyOTP(
        phone: _fullPhoneNumber,
        token: code,
        type: OtpType.sms,
      );
      if (!mounted) return;
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Codigo incorrecto o expirado';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.phone_android, color: kWebPrimary, size: 24),
              const SizedBox(width: BCSpacing.sm),
              const Expanded(
                child: Text(
                  'Verifica tu numero para continuar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kWebTextPrimary,
                    fontFamily: 'system-ui',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Te enviaremos un codigo por SMS',
            style: TextStyle(
              fontSize: 14,
              color: kWebTextSecondary,
              fontFamily: 'system-ui',
            ),
          ),
          const SizedBox(height: BCSpacing.lg),

          if (_error != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(BCSpacing.sm),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(BCSpacing.radiusSm),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFEF4444),
                  fontFamily: 'system-ui',
                ),
              ),
            ),
            const SizedBox(height: BCSpacing.md),
          ],

          if (!_otpSent) ...[
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Numero de celular',
                prefixText: '+52 ',
                prefixIcon: const Icon(Icons.phone_outlined),
                hintText: '33 1234 5678',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(BCSpacing.radiusSm),
                ),
              ),
              onSubmitted: (_) => _sendOtp(),
            ),
            const SizedBox(height: BCSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: WebGradientButton(
                onPressed: _loading ? null : _sendOtp,
                isLoading: _loading,
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: const Text(
                  'Enviar codigo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],

          if (_otpSent) ...[
            Text(
              'Codigo enviado a $_fullPhoneNumber',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: kWebTextPrimary,
                fontFamily: 'system-ui',
              ),
            ),
            const SizedBox(height: BCSpacing.md),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                labelText: 'Codigo de verificacion',
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(BCSpacing.radiusSm),
                ),
              ),
              onSubmitted: (_) => _verifyOtp(),
            ),
            const SizedBox(height: BCSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: WebGradientButton(
                onPressed: _loading ? null : _verifyOtp,
                isLoading: _loading,
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: const Text(
                  'Verificar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: BCSpacing.md),
            Center(
              child: _resendCountdown > 0
                  ? Text(
                      'Reenviar codigo en ${_resendCountdown}s',
                      style: const TextStyle(
                        fontSize: 13,
                        color: kWebTextHint,
                        fontFamily: 'system-ui',
                      ),
                    )
                  : TextButton(
                      onPressed: _loading ? null : _sendOtp,
                      child: const Text(
                        'Reenviar codigo',
                        style: TextStyle(
                          color: kWebPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// Location Input Section
// ============================================================================

class _LocationInputSection extends StatefulWidget {
  final void Function(double lat, double lng, String name) onLocationSelected;
  final VoidCallback onRetryGps;

  const _LocationInputSection({
    required this.onLocationSelected,
    required this.onRetryGps,
  });

  @override
  State<_LocationInputSection> createState() => _LocationInputSectionState();
}

class _LocationInputSectionState extends State<_LocationInputSection> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<GeoPlace> _suggestions = [];
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _suggestions = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final results = await geocodeSuggestions(query);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _searching = false;
      });
    });
  }

  String _shortenName(String displayName) {
    final parts = displayName.split(',').map((s) => s.trim()).toList();
    if (parts.length <= 3) return displayName;
    return parts.take(3).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(BCSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: kWebPrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.location_on_outlined,
                    size: 36,
                    color: kWebPrimary.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(height: BCSpacing.lg),
              const Text(
                '\u00bfDonde buscas tu servicio?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: kWebTextPrimary,
                  fontFamily: 'system-ui',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: BCSpacing.sm),
              const Text(
                'Necesitamos tu ubicacion para encontrar salones cerca de ti',
                style: TextStyle(
                  fontSize: 15,
                  color: kWebTextSecondary,
                  fontFamily: 'system-ui',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: BCSpacing.xl),
              TextField(
                controller: _controller,
                onChanged: _onQueryChanged,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Ciudad, Estado (ej: Guadalajara, JAL)',
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
                      : _controller.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _controller.clear();
                                _onQueryChanged('');
                              },
                            )
                          : null,
                ),
              ),
              const SizedBox(height: BCSpacing.sm),

              if (_suggestions.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 240),
                  decoration: BoxDecoration(
                    color: kWebSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kWebCardBorder),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: kWebCardBorder.withValues(alpha: 0.5),
                    ),
                    itemBuilder: (context, index) {
                      final place = _suggestions[index];
                      final shortName = _shortenName(place.displayName);
                      return ListTile(
                        leading: const Icon(Icons.place,
                            color: kWebPrimary, size: 20),
                        title: Text(
                          shortName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'system-ui',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        dense: true,
                        onTap: () => widget.onLocationSelected(
                          place.lat,
                          place.lng,
                          shortName,
                        ),
                      );
                    },
                  ),
                ),

              if (!_searching &&
                  _suggestions.isEmpty &&
                  _controller.text.trim().length >= 2)
                Padding(
                  padding: const EdgeInsets.only(top: BCSpacing.sm),
                  child: Text(
                    'No se encontraron resultados. Intenta con otro nombre.',
                    style: TextStyle(
                      fontSize: 13,
                      color: kWebTextHint,
                      fontFamily: 'system-ui',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: BCSpacing.lg),
              Center(
                child: TextButton.icon(
                  onPressed: widget.onRetryGps,
                  icon: const Icon(Icons.my_location, size: 18),
                  label: const Text('Usar mi ubicacion'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Discovered Salons List (WhatsApp invite fallback)
// ============================================================================

class _DiscoveredSalonsList extends ConsumerStatefulWidget {
  final bool hasResults;
  final VoidCallback onGoBack;

  const _DiscoveredSalonsList({
    required this.hasResults,
    required this.onGoBack,
  });

  @override
  ConsumerState<_DiscoveredSalonsList> createState() =>
      _DiscoveredSalonsListState();
}

class _DiscoveredSalonsListState extends ConsumerState<_DiscoveredSalonsList> {
  static const _waHeaderBg = Color(0xFF00A884);
  static const _waChatBg = Color(0xFFEFEAE2);
  static const _waIncomingBubble = Color(0xFFFFFFFF);
  static const _waOutgoingBubble = Color(0xFFD9FDD3);
  static const _waTextPrimary = Color(0xFF111B21);
  static const _waTextSecondary = Color(0xFF667781);
  static const _waCheckBlue = Color(0xFF53BDEB);
  static const _waDivider = Color(0xFFE9EDEF);

  bool _loading = true;
  String? _error;
  final Set<String> _invitedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchDiscovered());
  }

  Future<void> _fetchDiscovered() async {
    if (!mounted) return;

    // Edge function `list` action requires an authenticated session.
    // Direct PostgREST queries are blocked by the RPs+admins-only RLS
    // policy on discovered_salons, which previously left this panel
    // permanently empty for normal customers.
    if (BCSupabase.client.auth.currentUser == null) {
      setState(() {
        _loading = false;
        _error = 'auth_required';
      });
      return;
    }

    final existing = ref.read(bookingFlowProvider).discoveredSalons;
    if (existing.isNotEmpty) {
      setState(() => _loading = false);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final flowState = ref.read(bookingFlowProvider);
      final lat = flowState.userLat;
      final lng = flowState.userLng;

      final body = <String, dynamic>{
        'action': 'list',
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        'radius_km': 50,
        'limit': 25,
      };

      final response = await BCSupabase.client.functions.invoke(
        'outreach-discovered-salon',
        body: body,
      );

      if (!mounted) return;

      final data = response.data;
      final raw = data is Map ? data['salons'] : null;
      final salons = (raw is List)
          ? raw
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList()
          : <Map<String, dynamic>>[];

      ref.read(bookingFlowProvider.notifier).setDiscoveredSalons(salons);
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _inviteSalon(String salonId) async {
    if (_invitedIds.contains(salonId)) return;

    // Optimistically mark as in-flight so duplicate taps no-op.
    setState(() => _invitedIds.add(salonId));

    try {
      final response = await BCSupabase.client.functions.invoke(
        'outreach-discovered-salon',
        body: {
          'action': 'invite',
          'discovered_salon_id': salonId,
        },
      );

      final data = response.data;
      final errorCode = data is Map ? data['error'] as String? : null;
      if (errorCode != null) {
        if (!mounted) return;
        setState(() => _invitedIds.remove(salonId));
        _showInviteError(errorCode, data is Map ? data['message'] as String? : null);
      }
    } catch (e) {
      debugPrint('[RESERVAR] Salon outreach invite failed: $e');
      if (!mounted) return;
      setState(() => _invitedIds.remove(salonId));
      _showInviteError(_extractErrorCode(e), null);
    }
  }

  String _extractErrorCode(Object e) {
    final msg = e.toString();
    if (msg.contains('identity_required')) return 'identity_required';
    if (msg.contains('daily_limit')) return 'daily_limit';
    if (msg.contains('cooldown')) return 'cooldown';
    if (msg.contains('Unauthorized') || msg.contains('401')) return 'auth_required';
    return 'unknown';
  }

  void _showInviteError(String code, String? serverMessage) {
    final message = switch (code) {
      'auth_required' =>
        'Inicia sesión para invitar salones.',
      'identity_required' =>
        serverMessage ?? 'Verifica tu teléfono o email antes de invitar salones.',
      'daily_limit' =>
        serverMessage ?? 'Alcanzaste el límite diario de invitaciones. Intenta mañana.',
      'cooldown' =>
        serverMessage ?? 'Espera unos segundos entre invitaciones.',
      _ => 'No pudimos enviar la invitación. Intenta de nuevo.',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final salons = ref.watch(bookingFlowProvider).discoveredSalons;

    return ClipRRect(
      borderRadius: BorderRadius.circular(BCSpacing.radiusMd),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: _waDivider),
          borderRadius: BorderRadius.circular(BCSpacing.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: _waHeaderBg,
              child: Row(
                children: [
                  if (widget.hasResults)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: InkWell(
                        onTap: widget.onGoBack,
                        child: const Icon(Icons.arrow_back,
                            size: 20, color: Colors.white),
                      ),
                    ),
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFF00806A),
                    child: Icon(Icons.storefront_rounded,
                        size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Salones cerca de ti',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _loading
                              ? 'buscando...'
                              : '${salons.length} salones disponibles',
                          style: const TextStyle(
                            color: Color(0xCCFFFFFF),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Body
            Container(
              constraints: const BoxConstraints(maxHeight: 520),
              color: _waChatBg,
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: _waHeaderBg,
                          strokeWidth: 2.5,
                        ),
                      ),
                    )
                  : _error != null
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildSystemBubble(
                                _error == 'auth_required'
                                    ? 'Inicia sesión para ver salones cerca de ti e invitarlos por WhatsApp.'
                                    : 'No se pudieron cargar los salones',
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _error == 'auth_required'
                                    ? () => context.go('/auth')
                                    : _fetchDiscovered,
                                style: TextButton.styleFrom(
                                    foregroundColor: _waHeaderBg),
                                child: Text(
                                  _error == 'auth_required'
                                      ? 'Iniciar sesión'
                                      : 'Reintentar',
                                ),
                              ),
                            ],
                          ),
                        )
                      : salons.isEmpty
                          ? Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 40),
                              child: _buildSystemBubble(
                                  'No hay salones verificados en tu zona aun'),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 12),
                              itemCount: salons.length + 1,
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 8),
                                    child: _buildSystemBubble(
                                      'Estos salones aun no estan en BeautyCita. '
                                      'Invitalos por WhatsApp y recibe beneficios cuando se registren.',
                                    ),
                                  );
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: _buildSalonBubble(
                                      salons[index - 1]),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemBubble(String text) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3C4).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _waTextSecondary,
            fontSize: 12.5,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildSalonBubble(Map<String, dynamic> salon) {
    final salonId = salon['id']?.toString() ?? '';
    final name = salon['business_name'] as String? ?? 'Sin nombre';
    final address = salon['location_address'] as String?;
    final imageUrl = salon['feature_image_url'] as String?;
    final ratingAvg = (salon['rating_average'] as num?)?.toDouble();
    final ratingCount = salon['rating_count'] as int? ?? 0;
    final invited = _invitedIds.contains(salonId);

    return Align(
      alignment: invited ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: invited ? _waOutgoingBubble : _waIncomingBubble,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(8),
            topRight: const Radius.circular(8),
            bottomLeft:
                invited ? const Radius.circular(8) : Radius.zero,
            bottomRight:
                invited ? Radius.zero : const Radius.circular(8),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAvatar(name, imageUrl),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: _waTextPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (address != null && address.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        address,
                        style: const TextStyle(
                          color: _waTextSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (ratingAvg != null && ratingCount > 0) ...[
                        const Icon(Icons.star_rounded,
                            size: 14, color: _kGoldColor),
                        const SizedBox(width: 2),
                        Text(
                          '${ratingAvg.toStringAsFixed(1)} ($ratingCount)',
                          style: const TextStyle(
                            color: _waTextSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      const Spacer(),
                      if (invited)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Enviado',
                              style: TextStyle(
                                color: _waHeaderBg,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(Icons.done_all,
                                size: 16, color: _waCheckBlue),
                          ],
                        )
                      else
                        InkWell(
                          onTap: () => _inviteSalon(salonId),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _waHeaderBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.send_rounded,
                                    size: 12, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Invitar',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String name, String? imageUrl) {
    const size = 44.0;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(imageUrl),
        onBackgroundImageError: (_, __) {},
      );
    }
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: _waHeaderBg.withValues(alpha: 0.15),
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: _waHeaderBg,
        ),
      ),
    );
  }
}

// ============================================================================
// Confirmation Overlay
// ============================================================================

class _ConfirmationOverlay extends ConsumerWidget {
  final BookingFlowState flowState;
  final VoidCallback onReset;

  const _ConfirmationOverlay({
    required this.flowState,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = flowState.selectedResult;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(BCSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: StaggeredFadeIn(
            staggerDelay: const Duration(milliseconds: 100),
            children: [
              const SizedBox(height: BCSpacing.xl),

              // Gradient check
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: kWebBrandGradient,
                  ),
                  child: const Icon(
                    Icons.check_outlined,
                    size: 50,
                    color: Colors.white,
                  ),
                )
                    .animate()
                    .scale(
                      begin: const Offset(0, 0),
                      end: const Offset(1, 1),
                      duration: 500.ms,
                      curve: Curves.elasticOut,
                    )
                    .fade(duration: 300.ms),
              ),

              const SizedBox(height: BCSpacing.lg),

              Center(
                child: ShaderMask(
                  shaderCallback: (bounds) =>
                      kWebBrandGradient.createShader(bounds),
                  child: const Text(
                    '\u00a1Reservacion confirmada!',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontFamily: 'system-ui',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              const SizedBox(height: BCSpacing.sm),

              if (flowState.bookingId != null)
                Center(
                  child: Text(
                    'ID: ${flowState.bookingId!.length > 8 ? flowState.bookingId!.substring(0, 8) : flowState.bookingId!}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      color: kWebTextHint,
                    ),
                  ),
                ),

              const SizedBox(height: BCSpacing.lg),

              // Summary card
              if (result != null) _buildSummaryCard(result),

              const SizedBox(height: BCSpacing.lg),

              // WhatsApp contact
              if (result != null && result.business.whatsapp != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: BCSpacing.md),
                  child: SizedBox(
                    width: double.infinity,
                    child: WebOutlinedButton(
                      onPressed: () {
                        final phone = result.business.whatsapp!
                            .replaceAll(RegExp(r'[^\d]'), '');
                        launchUrl(Uri.parse('https://wa.me/$phone'));
                      },
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_outlined,
                              color: Color(0xFF25D366), size: 18),
                          SizedBox(width: 8),
                          Text('Contactar salon'),
                        ],
                      ),
                    ),
                  ),
                ),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: WebOutlinedButton(
                      onPressed: onReset,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: const Text('Hacer otra reservacion'),
                    ),
                  ),
                  const SizedBox(width: BCSpacing.md),
                  Expanded(
                    child: WebGradientButton(
                      onPressed: () => context.go('/mis-citas'),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: const Text('Ver mis citas'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: BCSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(ResultCard result) {
    final slot = result.slot!;
    final startTime = slot.startTime;
    final formattedDate =
        DateFormat('EEEE d MMMM, yyyy', 'es').format(startTime);
    final formattedTime = DateFormat('h:mm a').format(startTime);
    final price = result.service.price ?? 0;
    final currency = result.service.currency.toUpperCase();

    String transportLabel;
    switch (flowState.transportMode) {
      case 'car':
        transportLabel = 'En mi carro';
      case 'uber':
        transportLabel = 'Uber';
      case 'transit':
        transportLabel = 'Transporte Publico';
      default:
        transportLabel = flowState.transportMode ?? '--';
    }

    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: kWebTextPrimary,
              fontFamily: 'system-ui',
            ),
          ),
          const SizedBox(height: 16),
          WebInfoRow(
            icon: Icons.content_cut_outlined,
            iconColor: kWebPrimary,
            label: 'Servicio',
            value: result.service.name,
          ),
          const SizedBox(height: 10),
          WebInfoRow(
            icon: Icons.storefront_outlined,
            iconColor: kWebSecondary,
            label: 'Salon',
            value: result.business.name,
          ),
          const SizedBox(height: 10),
          WebInfoRow(
            icon: Icons.calendar_today_outlined,
            iconColor: kWebTertiary,
            label: 'Fecha',
            value: formattedDate,
          ),
          const SizedBox(height: 10),
          WebInfoRow(
            icon: Icons.access_time_outlined,
            iconColor: kWebTertiary,
            label: 'Hora',
            value: formattedTime,
          ),
          const SizedBox(height: 10),
          WebInfoRow(
            icon: Icons.payments_outlined,
            iconColor: kWebPrimary,
            label: 'Precio',
            value: '\$${price.toStringAsFixed(2)} $currency',
          ),
          if (flowState.transportMode != null) ...[
            const SizedBox(height: 10),
            WebInfoRow(
              icon: Icons.directions_car_outlined,
              iconColor: kWebTextSecondary,
              label: 'Transporte',
              value: transportLabel,
            ),
          ],
        ],
      ),
    );
  }
}
