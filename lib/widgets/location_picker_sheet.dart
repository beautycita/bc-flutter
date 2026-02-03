import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/config/theme.dart';
import 'package:beautycita/providers/booking_flow_provider.dart'
    show placesServiceProvider, uberServiceProvider;
import 'package:beautycita/services/location_service.dart';
import 'package:beautycita/services/places_service.dart';
import 'package:beautycita/services/uber_service.dart';

/// Shows a LocationPickerSheet as a modal bottom sheet.
/// Returns a [PlaceLocation] if the user selects a location, or null if dismissed.
Future<PlaceLocation?> showLocationPicker({
  required BuildContext context,
  required WidgetRef ref,
  required String title,
  String? currentAddress,
  bool showUberPlaces = false,
}) {
  return showModalBottomSheet<PlaceLocation>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppConstants.radiusXL)),
    ),
    builder: (ctx) {
      return _LocationPickerBody(
        ref: ref,
        title: title,
        currentAddress: currentAddress,
        showUberPlaces: showUberPlaces,
      );
    },
  );
}

class _LocationPickerBody extends StatefulWidget {
  final WidgetRef ref;
  final String title;
  final String? currentAddress;
  final bool showUberPlaces;

  const _LocationPickerBody({
    required this.ref,
    required this.title,
    this.currentAddress,
    this.showUberPlaces = false,
  });

  @override
  State<_LocationPickerBody> createState() => _LocationPickerBodyState();
}

class _LocationPickerBodyState extends State<_LocationPickerBody> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<PlacePrediction> _predictions = [];
  List<UberSavedPlace> _uberPlaces = [];
  bool _loadingUber = false;
  bool _loadingSearch = false;
  bool _resolving = false;

  PlacesService get _placesService => widget.ref.read(placesServiceProvider);
  UberService get _uberService => widget.ref.read(uberServiceProvider);

  @override
  void initState() {
    super.initState();
    if (widget.showUberPlaces) _checkAndFetchUberPlaces();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkAndFetchUberPlaces() async {
    // Only attempt to fetch if Uber is actually linked
    final linked = await _uberService.isLinked();
    if (!linked || !mounted) return;

    setState(() => _loadingUber = true);
    try {
      final places = await _uberService.getSavedPlaces();
      if (mounted) setState(() => _uberPlaces = places);
    } finally {
      if (mounted) setState(() => _loadingUber = false);
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _predictions = [];
        _loadingSearch = false;
      });
      return;
    }
    setState(() => _loadingSearch = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await _placesService.searchPlaces(query.trim());
      if (mounted) {
        setState(() {
          _predictions = results;
          _loadingSearch = false;
        });
      }
    });
  }

  Future<void> _selectPrediction(PlacePrediction prediction) async {
    setState(() => _resolving = true);
    final location = await _placesService.getPlaceDetails(prediction.placeId);
    if (!mounted) return;
    if (location != null) {
      Navigator.pop(context, location);
    } else {
      setState(() => _resolving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No se pudo obtener la ubicacion'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Future<void> _selectUberPlace(UberSavedPlace place) async {
    setState(() => _resolving = true);
    // Geocode via Places API text search
    final results = await _placesService.searchPlaces(place.address);
    if (!mounted) return;
    if (results.isNotEmpty) {
      final location =
          await _placesService.getPlaceDetails(results.first.placeId);
      if (!mounted) return;
      if (location != null) {
        Navigator.pop(context, location);
        return;
      }
    }
    setState(() => _resolving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No se pudo resolver la direccion'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _resolving = true);
    final loc = await LocationService.getCurrentLocation();
    if (!mounted) return;
    if (loc != null) {
      Navigator.pop(
        context,
        PlaceLocation(
            lat: loc.lat, lng: loc.lng, address: 'Ubicacion actual'),
      );
    } else {
      setState(() => _resolving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No se pudo obtener tu ubicacion'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 100),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: AppConstants.paddingMD),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // Title + current address
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.paddingLG,
                BeautyCitaTheme.spaceMD,
                AppConstants.paddingLG,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (widget.currentAddress != null) ...[
                    const SizedBox(height: BeautyCitaTheme.spaceXS),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: AppConstants.iconSizeSM,
                            color: BeautyCitaTheme.textLight),
                        const SizedBox(width: BeautyCitaTheme.spaceXS),
                        Expanded(
                          child: Text(
                            'Actual: ${widget.currentAddress}',
                            style: textTheme.bodySmall?.copyWith(
                              color: BeautyCitaTheme.textLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Scrollable content
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.paddingLG,
                  BeautyCitaTheme.spaceMD,
                  AppConstants.paddingLG,
                  AppConstants.paddingLG,
                ),
                children: [
                  // Uber saved places section — only if loading or has results
                  if (_loadingUber)
                    _buildShimmerPlaces()
                  else if (_uberPlaces.isNotEmpty) ...[
                    Text(
                      'Lugares guardados',
                      style: textTheme.labelMedium?.copyWith(
                        color: BeautyCitaTheme.textLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: BeautyCitaTheme.spaceSM),
                    ..._uberPlaces.map(_buildUberPlaceTile),
                    const SizedBox(height: BeautyCitaTheme.spaceMD),
                  ],

                  // Use current location button
                  SizedBox(
                    width: double.infinity,
                    height: AppConstants.minTouchHeight,
                    child: OutlinedButton.icon(
                      onPressed: _resolving ? null : _useCurrentLocation,
                      icon: _resolving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location_rounded),
                      label: Text(
                        _resolving
                            ? 'Obteniendo ubicacion...'
                            : 'Usar ubicacion actual',
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: BeautyCitaTheme.primaryRose),
                        foregroundColor: BeautyCitaTheme.primaryRose,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusLG),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: BeautyCitaTheme.spaceMD),

                  // Search field
                  TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    enabled: !_resolving,
                    decoration: InputDecoration(
                      hintText: 'Buscar direccion...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusSM),
                      ),
                      filled: true,
                      fillColor: BeautyCitaTheme.surfaceCream,
                    ),
                  ),

                  // Search results
                  if (_loadingSearch)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                          vertical: BeautyCitaTheme.spaceMD),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else if (_predictions.isNotEmpty) ...[
                    const SizedBox(height: BeautyCitaTheme.spaceSM),
                    ..._predictions.map(_buildPredictionTile),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUberPlaceTile(UberSavedPlace place) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BeautyCitaTheme.spaceXS),
      child: Material(
        color: BeautyCitaTheme.surfaceCream,
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        child: InkWell(
          onTap: _resolving ? null : () => _selectUberPlace(place),
          borderRadius: BorderRadius.circular(AppConstants.radiusSM),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingMD,
              vertical: AppConstants.paddingSM + 4,
            ),
            child: Row(
              children: [
                Icon(place.icon,
                    size: AppConstants.iconSizeMD,
                    color: BeautyCitaTheme.primaryRose),
                const SizedBox(width: BeautyCitaTheme.spaceSM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.label,
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      Text(
                        place.address,
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: BeautyCitaTheme.textLight,
                                ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: BeautyCitaTheme.textLight),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPredictionTile(PlacePrediction prediction) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _resolving ? null : () => _selectPrediction(prediction),
        borderRadius: BorderRadius.circular(AppConstants.radiusSM),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingSM,
            vertical: AppConstants.paddingSM + 2,
          ),
          child: Row(
            children: [
              const Icon(Icons.place_outlined,
                  size: AppConstants.iconSizeMD,
                  color: BeautyCitaTheme.textLight),
              const SizedBox(width: BeautyCitaTheme.spaceSM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prediction.mainText,
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                    if (prediction.secondaryText.isNotEmpty)
                      Text(
                        prediction.secondaryText,
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: BeautyCitaTheme.textLight,
                                ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerPlaces() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lugares guardados',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: BeautyCitaTheme.textLight,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: BeautyCitaTheme.spaceSM),
        for (int i = 0; i < 2; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: BeautyCitaTheme.spaceXS),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: BeautyCitaTheme.surfaceCream,
                borderRadius:
                    BorderRadius.circular(AppConstants.radiusSM),
              ),
            ),
          ),
        const SizedBox(height: BeautyCitaTheme.spaceMD),
      ],
    );
  }
}
