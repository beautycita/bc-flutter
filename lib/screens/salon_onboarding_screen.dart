import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:url_launcher/url_launcher.dart';
import '../config/constants.dart';
import '../config/theme.dart';
import '../providers/booking_flow_provider.dart' show placesServiceProvider;
import '../services/places_service.dart';
import '../services/supabase_client.dart';

class SalonOnboardingScreen extends ConsumerStatefulWidget {
  final String? refCode;

  const SalonOnboardingScreen({super.key, this.refCode});

  @override
  ConsumerState<SalonOnboardingScreen> createState() =>
      _SalonOnboardingScreenState();
}

class _SalonOnboardingScreenState
    extends ConsumerState<SalonOnboardingScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController(text: '+52 ');
  final _addressCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _suggestionsKey = GlobalKey();

  bool _submitting = false;
  bool _registered = false;
  bool _loadingPrefill = false;
  String? _photoUrl;
  Map<String, dynamic>? _discoveredSalonData;
  String? _businessId;

  // Location state
  double? _pickedLat;
  double? _pickedLng;
  String? _pickedAddress;
  bool _locationConfirmed = false;

  // Inline autocomplete
  Timer? _debounce;
  List<PlacePrediction> _predictions = [];
  bool _loadingPlaces = false;
  bool _resolvingPlace = false;

  // Map
  final _mapCtrl = MapController();

  @override
  void initState() {
    super.initState();
    _loadDiscoveredSalonData();
  }

  Future<void> _loadDiscoveredSalonData() async {
    if (widget.refCode == null || widget.refCode!.isEmpty) return;

    setState(() => _loadingPrefill = true);

    try {
      final response = await SupabaseClientService.client
          .from('discovered_salons')
          .select()
          .eq('id', widget.refCode!)
          .maybeSingle();

      if (response != null && mounted) {
        _discoveredSalonData = response;

        final name = response['business_name'] ?? response['name'];
        if (name != null && name.toString().isNotEmpty) {
          _nameCtrl.text = _sanitizeLatin(name.toString());
        }

        final phone = response['whatsapp'] ?? response['phone'];
        if (phone != null && phone.toString().isNotEmpty) {
          _phoneCtrl.text = phone.toString();
        }

        final address = response['location_address'] ?? response['address'];
        final prefillLat = response['location_lat'] ?? response['lat'];
        final prefillLng = response['location_lng'] ?? response['lng'];
        if (address != null && address.toString().isNotEmpty) {
          _addressCtrl.text = _sanitizeLatin(address.toString());
          _pickedAddress = _addressCtrl.text;
        }
        if (prefillLat != null && prefillLng != null) {
          _pickedLat = (prefillLat is num)
              ? prefillLat.toDouble()
              : double.tryParse(prefillLat.toString());
          _pickedLng = (prefillLng is num)
              ? prefillLng.toDouble()
              : double.tryParse(prefillLng.toString());
          if (_pickedLat != null && _pickedLng != null) {
            _locationConfirmed = true;
          }
        }

        _photoUrl = response['feature_image_url'] ?? response['photo_url'];
      }
    } catch (e) {
      debugPrint('[SalonOnboarding] Error loading prefill data: $e');
    } finally {
      if (mounted) setState(() => _loadingPrefill = false);
    }
  }

  String _sanitizeLatin(String text) {
    return text
        .replaceAll(
          RegExp(
              r'[^\u0000-\u024F\u1E00-\u1EFF\u2000-\u206F\u2070-\u209F\u20A0-\u20CF\u2100-\u214F\s]'),
          '',
        )
        .trim();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _detailsCtrl.dispose();
    _scrollCtrl.dispose();
    _mapCtrl.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _nameCtrl.text.trim().length >= 2 &&
      _phoneCtrl.text.replaceAll(RegExp(r'[^\d]'), '').length >= 10 &&
      _locationConfirmed &&
      _pickedLat != null;

  // ── Address autocomplete ─────────────────────────────────────────────

  void _onAddressChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() {
        _predictions = [];
        _loadingPlaces = false;
      });
      return;
    }
    setState(() => _loadingPlaces = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final placesService = ref.read(placesServiceProvider);
      final results = await placesService.searchPlaces(query.trim());
      if (mounted) {
        setState(() {
          _predictions = results;
          _loadingPlaces = false;
        });
        _scrollToSuggestions();
      }
    });
  }

  void _scrollToSuggestions() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _suggestionsKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
  }

  Future<void> _selectPrediction(PlacePrediction prediction) async {
    setState(() => _resolvingPlace = true);
    final placesService = ref.read(placesServiceProvider);
    final location = await placesService.getPlaceDetails(prediction.placeId);
    if (!mounted) return;
    if (location != null) {
      setState(() {
        _pickedLat = location.lat;
        _pickedLng = location.lng;
        _pickedAddress = location.address;
        _addressCtrl.text = location.address;
        _predictions = [];
        _resolvingPlace = false;
        _locationConfirmed = true;
      });
      FocusScope.of(context).unfocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }
      });
    } else {
      setState(() => _resolvingPlace = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo obtener la ubicacion'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _clearLocation() {
    setState(() {
      _pickedLat = null;
      _pickedLng = null;
      _pickedAddress = null;
      _locationConfirmed = false;
      _addressCtrl.clear();
      _detailsCtrl.clear();
      _predictions = [];
    });
  }

  void _onMapTap(TapPosition tapPos, LatLng latLng) {
    setState(() {
      _pickedLat = latLng.latitude;
      _pickedLng = latLng.longitude;
    });
  }

  // ── Submit ───────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_isValid || _submitting) return;
    setState(() => _submitting = true);

    try {
      final rawPhone = _phoneCtrl.text.replaceAll(RegExp(r'[^\d+]'), '');
      final phone = rawPhone.startsWith('+') ? rawPhone : '+52$rawPhone';

      final userId = SupabaseClientService.client.auth.currentUser?.id;

      final baseAddress = _pickedAddress ?? _addressCtrl.text.trim();
      final details = _detailsCtrl.text.trim();
      final fullAddress =
          details.isNotEmpty ? '$baseAddress, $details' : baseAddress;

      final businessData = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'phone': phone,
        'whatsapp': phone,
        'address': fullAddress,
        'lat': _pickedLat,
        'lng': _pickedLng,
        'tier': 1,
        'is_active': true,
        if (userId != null) 'owner_id': userId,
      };

      if (_photoUrl != null) {
        businessData['photo_url'] = _photoUrl;
      }

      if (_discoveredSalonData != null) {
        final city = _discoveredSalonData!['location_city'] ??
            _discoveredSalonData!['city'];
        if (city != null) businessData['city'] = city;
        final rating = _discoveredSalonData!['rating_average'] ??
            _discoveredSalonData!['rating'];
        if (rating != null) businessData['average_rating'] = rating;
      }

      final response = await SupabaseClientService.client
          .from('businesses')
          .insert(businessData)
          .select('id')
          .single();

      final businessId = response['id'] as String;

      if (widget.refCode != null && widget.refCode!.isNotEmpty) {
        await SupabaseClientService.client
            .from('discovered_salons')
            .update({
              'status': 'registered',
              'registered_business_id': businessId,
              'registered_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', widget.refCode!);
      }

      setState(() {
        _businessId = businessId;
        _registered = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (_registered) {
      return _SuccessScreen(
        businessId: _businessId,
        businessName: _nameCtrl.text.trim(),
        onDone: () => context.go('/home'),
      );
    }

    if (_loadingPrefill) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFF8F0),
        body: Center(
          child: CircularProgressIndicator(color: colors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            // ── Gradient header ──────────────────────────────────────
            SliverToBoxAdapter(
              child: _HeroHeader(
                photoUrl: _photoUrl,
                onBack: () => context.pop(),
              ),
            ),

            // ── Form content ─────────────────────────────────────────
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                MediaQuery.of(context).viewInsets.bottom + 32,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Prefill notice
                  if (_discoveredSalonData != null) ...[
                    _InfoBanner(
                      icon: Icons.auto_awesome,
                      text: 'Datos pre-llenados. Puedes editarlos.',
                      color: colors.primary,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Section: Datos del salon ────────────────────────
                  _SectionCard(
                    children: [
                      _SectionHeader(
                        icon: Icons.store_rounded,
                        title: 'Datos del salon',
                        color: colors.primary,
                      ),
                      const SizedBox(height: 16),

                      // Business name
                      _StyledField(
                        controller: _nameCtrl,
                        label: 'Nombre del salon',
                        hint: 'Ej: Salon Rosa',
                        icon: Icons.storefront_rounded,
                        textCapitalization: TextCapitalization.words,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 14),

                      // WhatsApp
                      _StyledField(
                        controller: _phoneCtrl,
                        label: 'WhatsApp',
                        hint: '+52 33 1234 5678',
                        icon: Icons.chat_rounded,
                        iconColor: const Color(0xFF25D366),
                        keyboardType: TextInputType.phone,
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Section: Ubicacion ──────────────────────────────
                  _SectionCard(
                    children: [
                      _SectionHeader(
                        icon: Icons.location_on_rounded,
                        title: 'Ubicacion',
                        color: const Color(0xFFE91E63),
                      ),
                      const SizedBox(height: 16),

                      if (!_locationConfirmed) ...[
                        // Search mode
                        _StyledField(
                          controller: _addressCtrl,
                          label: 'Direccion del salon',
                          hint: 'Escribe para buscar...',
                          icon: Icons.search_rounded,
                          onChanged: _onAddressChanged,
                          suffixWidget: _loadingPlaces || _resolvingPlace
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                )
                              : null,
                        ),

                        // Autocomplete dropdown
                        if (_predictions.isNotEmpty)
                          Container(
                            key: _suggestionsKey,
                            margin: const EdgeInsets.only(top: 4),
                            constraints: const BoxConstraints(maxHeight: 220),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.primary.withValues(alpha: 0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(
                                color: colors.primary.withValues(alpha: 0.1),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: ListView(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                children: _predictions.map((p) {
                                  return InkWell(
                                    onTap: _resolvingPlace
                                        ? null
                                        : () => _selectPrediction(p),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 12),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: colors.primary
                                                  .withValues(alpha: 0.08),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.place_outlined,
                                              size: 16,
                                              color: colors.primary,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  p.mainText,
                                                  style: GoogleFonts.nunito(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: const Color(
                                                        0xFF212121),
                                                  ),
                                                ),
                                                if (p.secondaryText.isNotEmpty)
                                                  Text(
                                                    p.secondaryText,
                                                    style: GoogleFonts.nunito(
                                                      fontSize: 12,
                                                      color: const Color(
                                                          0xFF757575),
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                      ] else ...[
                        // Confirmed mode
                        // Address chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colors.primary.withValues(alpha: 0.06),
                                colors.primary.withValues(alpha: 0.02),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colors.primary.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color:
                                      colors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.location_on_rounded,
                                    size: 16, color: colors.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _pickedAddress ?? '',
                                  style: GoogleFonts.nunito(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF212121),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _clearLocation,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: colors.primary
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Cambiar',
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: colors.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Optional details
                        _StyledField(
                          controller: _detailsCtrl,
                          label: 'Detalles (opcional)',
                          hint: 'Local, piso, interior...',
                          icon: Icons.edit_location_alt_outlined,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                        const SizedBox(height: 14),

                        // Mini map
                        if (_pickedLat != null && _pickedLng != null)
                          _MiniMap(
                            lat: _pickedLat!,
                            lng: _pickedLng!,
                            pinColor: colors.primary,
                            mapController: _mapCtrl,
                            onTap: _onMapTap,
                          ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Register button ─────────────────────────────────
                  _RegisterButton(
                    enabled: _isValid && !_submitting,
                    loading: _submitting,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 20),

                  // ── Benefits section ────────────────────────────────
                  _BenefitsSection(primaryColor: colors.primary),
                  const SizedBox(height: 16),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================================
// Hero Header — gradient background with icon and title
// ==========================================================================

class _HeroHeader extends StatelessWidget {
  final String? photoUrl;
  final VoidCallback onBack;

  const _HeroHeader({this.photoUrl, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary,
            colors.primary.withValues(alpha: 0.85),
            const Color(0xFFD81B60),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 16, 28),
          child: Column(
            children: [
              // Back button row
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 24),
                  onPressed: onBack,
                ),
              ),
              const SizedBox(height: 8),

              // Avatar or icon
              if (photoUrl != null)
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    backgroundImage: NetworkImage(photoUrl!),
                    onBackgroundImageError: (_, __) {},
                  ),
                )
              else
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.15),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                  ),
                  child: const Icon(Icons.store_rounded,
                      size: 36, color: Colors.white),
                ),
              const SizedBox(height: 16),

              Text(
                'Registra tu Salon',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Unete a BeautyCita y recibe clientes nuevas',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.85),
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================================================
// Section Card — white card container
// ==========================================================================

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC2185B).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

// ==========================================================================
// Section Header — icon + title
// ==========================================================================

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF212121),
          ),
        ),
      ],
    );
  }
}

// ==========================================================================
// Styled text field
// ==========================================================================

class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final Color? iconColor;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final Widget? suffixWidget;

  const _StyledField({
    required this.controller,
    required this.label,
    this.hint,
    required this.icon,
    this.iconColor,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.suffixWidget,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final effectiveIconColor =
        iconColor ?? colors.primary.withValues(alpha: 0.5);

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      style: GoogleFonts.nunito(fontSize: 15, color: const Color(0xFF212121)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle:
            GoogleFonts.nunito(fontSize: 14, color: const Color(0xFF757575)),
        hintStyle:
            GoogleFonts.nunito(fontSize: 14, color: const Color(0xFF9E9E9E)),
        prefixIcon: Icon(icon, size: 20, color: effectiveIconColor),
        suffixIcon: suffixWidget,
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: colors.primary.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: colors.primary.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
      ),
    );
  }
}

// ==========================================================================
// Info banner
// ==========================================================================

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _InfoBanner({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================================================
// Register button — gradient style
// ==========================================================================

class _RegisterButton extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  const _RegisterButton({
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.5,
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: enabled
              ? LinearGradient(
                  colors: [colors.primary, const Color(0xFFD81B60)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: enabled ? null : const Color(0xFFE0E0E0),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'REGISTRARME GRATIS',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: enabled
                              ? Colors.white
                              : const Color(0xFF9E9E9E),
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================================================
// Benefits section — why join BeautyCita
// ==========================================================================

class _BenefitsSection extends StatelessWidget {
  final Color primaryColor;
  const _BenefitsSection({required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB300).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.star_rounded,
                    size: 18, color: Color(0xFFFFB300)),
              ),
              const SizedBox(width: 12),
              Text(
                'Beneficios',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF212121),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _BenefitItem(
            icon: Icons.people_rounded,
            text: 'Recibe clientes nuevas sin esfuerzo',
            color: primaryColor,
          ),
          const SizedBox(height: 12),
          _BenefitItem(
            icon: Icons.calendar_today_rounded,
            text: 'Agenda organizada automaticamente',
            color: primaryColor,
          ),
          const SizedBox(height: 12),
          _BenefitItem(
            icon: Icons.payment_rounded,
            text: 'Pagos seguros directo a tu cuenta',
            color: primaryColor,
          ),
          const SizedBox(height: 12),
          _BenefitItem(
            icon: Icons.trending_up_rounded,
            text: 'Crece tu negocio con visibilidad online',
            color: const Color(0xFFFFB300),
          ),
        ],
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _BenefitItem({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: const Color(0xFF424242),
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================================================
// Mini Map with animated pin drop
// ==========================================================================

class _MiniMap extends StatefulWidget {
  final double lat;
  final double lng;
  final Color pinColor;
  final MapController mapController;
  final void Function(TapPosition, LatLng) onTap;

  const _MiniMap({
    required this.lat,
    required this.lng,
    required this.pinColor,
    required this.mapController,
    required this.onTap,
  });

  @override
  State<_MiniMap> createState() => _MiniMapState();
}

class _MiniMapState extends State<_MiniMap>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _dropAnim;
  late Animation<double> _shadowAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    );
    _dropAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.2, 0.8, curve: Curves.bounceOut),
    );
    _shadowAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
    );
    _animCtrl.forward();
  }

  @override
  void didUpdateWidget(covariant _MiniMap old) {
    super.didUpdateWidget(old);
    if (old.lat != widget.lat || old.lng != widget.lng) {
      _animCtrl.reset();
      _animCtrl.forward();
      widget.mapController.move(
        LatLng(widget.lat, widget.lng),
        17,
      );
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  String get _mapTileUrl {
    final token = dotenv.env['MAPBOX_TOKEN'] ?? '';
    if (token.isNotEmpty) {
      return 'https://api.mapbox.com/styles/v1/mapbox/light-v11/tiles/{z}/{x}/{y}@2x?access_token=$token';
    }
    return 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 2),
            child: Text(
              'Toca el mapa para posicionar el pin en la entrada',
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: const Color(0xFF757575),
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.15),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: widget.mapController,
                    options: MapOptions(
                      initialCenter: LatLng(widget.lat, widget.lng),
                      initialZoom: 17,
                      maxZoom: 19,
                      minZoom: 14,
                      onTap: widget.onTap,
                      interactionOptions: const InteractionOptions(
                        flags:
                            InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: _mapTileUrl,
                        userAgentPackageName: 'com.beautycita',
                        maxZoom: 19,
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(widget.lat, widget.lng),
                            width: 48,
                            height: 60,
                            alignment: Alignment.topCenter,
                            child: _AnimatedPin(
                              dropAnimation: _dropAnim,
                              shadowAnimation: _shadowAnim,
                              color: widget.pinColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Top gradient overlay
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.3),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================================================
// Animated Pin — drops from above with bounce, shadow grows
// ==========================================================================

class _AnimatedPin extends StatelessWidget {
  final Animation<double> dropAnimation;
  final Animation<double> shadowAnimation;
  final Color color;

  const _AnimatedPin({
    required this.dropAnimation,
    required this.shadowAnimation,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: dropAnimation,
      builder: (context, child) {
        final drop = 1.0 - dropAnimation.value;
        return SizedBox(
          width: 48,
          height: 60,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                bottom: 0,
                child: Opacity(
                  opacity: shadowAnimation.value * 0.4,
                  child: Container(
                    width: 16 + (8 * shadowAnimation.value),
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 4 + (drop * 40),
                child: _PinIcon(color: color),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PinIcon extends StatelessWidget {
  final Color color;
  const _PinIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 44,
      child: CustomPaint(
        painter: _PinPainter(color: color),
      ),
    );
  }
}

class _PinPainter extends CustomPainter {
  final Color color;
  _PinPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    final pinPaint = Paint()..color = color;
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15);

    canvas.save();
    canvas.translate(1.5, 1.5);
    _drawPin(canvas, w, h, cx, shadowPaint);
    canvas.restore();

    _drawPin(canvas, w, h, cx, pinPaint);

    final innerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(cx, h * 0.32), w * 0.18, innerPaint);
  }

  void _drawPin(Canvas canvas, double w, double h, double cx, Paint paint) {
    final radius = w * 0.42;
    final path = Path();
    path.addArc(
      Rect.fromCircle(center: Offset(cx, h * 0.32), radius: radius),
      math.pi * 0.15,
      math.pi * 1.7,
    );
    path.lineTo(cx, h * 0.92);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PinPainter old) => old.color != color;
}

// ==========================================================================
// Success Screen
// ==========================================================================

class _SuccessScreen extends StatefulWidget {
  final String? businessId;
  final String businessName;
  final VoidCallback onDone;

  const _SuccessScreen({
    required this.businessId,
    required this.businessName,
    required this.onDone,
  });

  @override
  State<_SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<_SuccessScreen>
    with SingleTickerProviderStateMixin {
  bool _loadingStripe = false;
  late AnimationController _celebrationController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _celebrationController,
        curve: Curves.elasticOut,
      ),
    );
    _fadeAnim = CurvedAnimation(
      parent: _celebrationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    );
    _celebrationController.forward();
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    super.dispose();
  }

  Future<void> _setupStripe() async {
    if (widget.businessId == null) return;

    setState(() => _loadingStripe = true);

    try {
      final response = await SupabaseClientService.client.functions.invoke(
        'stripe-connect-onboard',
        body: {
          'action': 'get-onboard-link',
          'business_id': widget.businessId,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final onboardingUrl = data['onboarding_url'] as String?;

      if (onboardingUrl != null) {
        final uri = Uri.parse(onboardingUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else {
        throw Exception('No onboarding URL returned');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingStripe = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 48),
              ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        colors.primary.withValues(alpha: 0.15),
                        colors.primary.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                  child: Icon(
                    Icons.celebration_rounded,
                    size: 44,
                    color: colors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  children: [
                    Text(
                      'Bienvenido a BeautyCita!',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF212121),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          color: const Color(0xFF757575),
                          height: 1.5,
                        ),
                        children: [
                          const TextSpan(text: 'Tu salon '),
                          TextSpan(
                            text: '"${widget.businessName}"',
                            style: GoogleFonts.nunito(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: colors.primary,
                            ),
                          ),
                          const TextSpan(text: ' ya esta registrado.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              FadeTransition(
                opacity: _fadeAnim,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF635BFF).withValues(alpha: 0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF635BFF).withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF635BFF)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet_rounded,
                              color: Color(0xFF635BFF),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Configurar pagos',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF212121),
                                  ),
                                ),
                                Text(
                                  'Para recibir pagos de clientes',
                                  style: GoogleFonts.nunito(
                                    fontSize: 13,
                                    color: const Color(0xFF757575),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Conecta tu cuenta bancaria para recibir el pago de cada reserva directamente. Solo toma 2 minutos.',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: const Color(0xFF757575),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _loadingStripe ? null : _setupStripe,
                          icon: _loadingStripe
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward_rounded,
                                  size: 18),
                          label: Text(
                            _loadingStripe
                                ? 'Abriendo...'
                                : 'CONFIGURAR AHORA',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF635BFF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: widget.onDone,
                child: Text(
                  'Configurar despues',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: const Color(0xFF757575),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB300).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 20, color: Color(0xFFFFB300)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Sin configurar pagos, las clientas te contactaran por WhatsApp pero no podran pagar en la app.',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: const Color(0xFF757575),
                          height: 1.4,
                        ),
                      ),
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
