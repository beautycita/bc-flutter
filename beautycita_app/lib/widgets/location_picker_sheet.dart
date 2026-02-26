import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/providers/booking_flow_provider.dart'
    show placesServiceProvider;
import 'package:beautycita/services/location_service.dart';
import 'package:beautycita/services/places_service.dart';

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
  bool _loadingSearch = false;
  bool _resolving = false;

  PlacesService get _placesService => widget.ref.read(placesServiceProvider);

  @override
  void initState() {
    super.initState();
    // Uber saved places no longer available (using deep links)
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
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
      debugPrint('[LocationPicker] searching: "${query.trim()}"');
      final results = await _placesService.searchPlaces(query.trim());
      debugPrint('[LocationPicker] got ${results.length} results');
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
    final primary = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).colorScheme.surface;
    final onSurfaceLight = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
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
                AppConstants.paddingMD,
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
                    const SizedBox(height: AppConstants.paddingXS),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: AppConstants.iconSizeSM,
                            color: onSurfaceLight),
                        const SizedBox(width: AppConstants.paddingXS),
                        Expanded(
                          child: Text(
                            'Actual: ${widget.currentAddress}',
                            style: textTheme.bodySmall?.copyWith(
                              color: onSurfaceLight,
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
                  AppConstants.paddingMD,
                  AppConstants.paddingLG,
                  AppConstants.paddingLG,
                ),
                children: [
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
                        side: BorderSide(color: primary),
                        foregroundColor: primary,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusLG),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingMD),

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
                      fillColor: surface,
                    ),
                  ),

                  // Search results
                  if (_loadingSearch)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                          vertical: AppConstants.paddingMD),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else if (_predictions.isNotEmpty) ...[
                    const SizedBox(height: AppConstants.paddingSM),
                    ..._predictions.map((prediction) => _buildPredictionTile(prediction, onSurfaceLight)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionTile(PlacePrediction prediction, Color onSurfaceLight) {
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
              Icon(Icons.place_outlined,
                  size: AppConstants.iconSizeMD,
                  color: onSurfaceLight),
              const SizedBox(width: AppConstants.paddingSM),
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
                                  color: onSurfaceLight,
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

}
