import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita/config/fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions, UserAttributes;
import 'package:url_launcher/url_launcher.dart';
import '../providers/booking_flow_provider.dart' show placesServiceProvider;
import '../providers/security_provider.dart';
import '../services/location_service.dart';
import '../services/places_service.dart';
import 'package:beautycita_core/supabase.dart';
import '../services/supabase_client.dart';
import '../services/toast_service.dart';

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
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _suggestionsKey = GlobalKey();

  bool _submitting = false;
  bool _registered = false;
  bool _loadingPrefill = false;
  String? _photoUrl;
  Uint8List? _licenseBytes;
  String? _licenseName;
  Map<String, dynamic>? _discoveredSalonData;
  String? _discoveredSalonId; // ID of matched discovered salon (from refCode or phone match)
  String? _businessId;

  // Confirmation card state
  bool _showConfirmation = false;
  Map<String, dynamic>? _matchedSalon;
  List<Map<String, dynamic>> _nearbyMatches = [];
  bool _autoSubmitting = false;

  // Location state
  double? _pickedLat;
  double? _pickedLng;
  String? _pickedAddress;
  String? _pickedCity;
  String? _pickedState;
  bool _locationConfirmed = false;

  // Inline autocomplete
  Timer? _debounce;
  Timer? _phoneDebounce;
  List<PlacePrediction> _predictions = [];
  bool _loadingPlaces = false;
  bool _resolvingPlace = false;
  bool _phoneMatchLoading = false;

  // Map
  final _mapCtrl = MapController();

  @override
  void initState() {
    super.initState();
    _loadDiscoveredSalonData();
    _prefillEmail();
    _autoMatchByPhone();
    _autoMatchByLocation();
  }

  void _prefillEmail() {
    final user = SupabaseClientService.client.auth.currentUser;
    final email = user?.email;
    if (email != null && email.isNotEmpty && !email.endsWith('@qr.beautycita.app')) {
      _emailCtrl.text = email;
    }
  }

  /// Auto-match: if user has a verified phone, check discovered_salons for it
  Future<void> _autoMatchByPhone() async {
    // Skip if already loading via refCode invite link
    if (widget.refCode != null && widget.refCode!.isNotEmpty) return;

    final user = SupabaseClientService.client.auth.currentUser;
    final phone = user?.phone;
    if (phone == null || phone.isEmpty) return;

    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 10) return;

    final last10 = digits.length > 10
        ? digits.substring(digits.length - 10)
        : digits;

    try {
      final results = await SupabaseClientService.client
          .from(BCTables.discoveredSalons)
          .select()
          .or('phone.ilike.%$last10,whatsapp.ilike.%$last10')
          .neq('status', 'registered')
          .limit(1);

      if (!mounted || results.isEmpty) return;

      // Show confirmation card instead of direct prefill
      _phoneCtrl.text = phone;
      setState(() {
        _matchedSalon = results.first;
        _showConfirmation = true;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[SalonOnboarding] Auto-match by phone error: $e');
    }
  }

  /// Auto-match: check discovered_salons within 200m of user's GPS location
  Future<void> _autoMatchByLocation() async {
    // Skip if already loading via refCode invite link
    if (widget.refCode != null && widget.refCode!.isNotEmpty) return;

    try {
      final loc = await LocationService.getCurrentLocation();
      if (loc == null || !mounted) return;

      // Already matched by phone? Skip GPS match
      if (_showConfirmation) return;

      final results = await SupabaseClientService.client.rpc(
        'nearby_discovered_salons',
        params: {
          'p_lat': loc.lat,
          'p_lng': loc.lng,
          'p_radius_km': 0.2,
          'p_limit': 5,
        },
      ) as List<dynamic>;

      if (!mounted || results.isEmpty) return;
      // Already matched by phone while we were fetching GPS? Skip
      if (_showConfirmation) return;

      final salons = results
          .map((e) => e as Map<String, dynamic>)
          .toList();

      if (salons.length == 1) {
        // Single match — show confirmation card directly
        setState(() {
          _matchedSalon = salons.first;
          _showConfirmation = true;
        });
      } else {
        // Multiple matches — show selection list
        setState(() {
          _nearbyMatches = salons;
          _showConfirmation = true;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[SalonOnboarding] Auto-match by location error: $e');
    }
  }

  Future<void> _loadDiscoveredSalonData() async {
    if (widget.refCode == null || widget.refCode!.isEmpty) return;

    setState(() => _loadingPrefill = true);

    try {
      final response = await SupabaseClientService.client
          .from(BCTables.discoveredSalons)
          .select()
          .eq('id', widget.refCode!)
          .maybeSingle();

      if (response != null && mounted) {
        // Show confirmation card for refCode matches too
        setState(() {
          _matchedSalon = response;
          _showConfirmation = true;
          _photoUrl = response['feature_image_url'] ?? response['photo_url'];
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[SalonOnboarding] Error loading prefill data: $e');
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
    _phoneDebounce?.cancel();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _detailsCtrl.dispose();
    _scrollCtrl.dispose();
    _mapCtrl.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _nameCtrl.text.trim().length >= 2 &&
      _phoneCtrl.text.replaceAll(RegExp(r'[^\d]'), '').length >= 10 &&
      _emailCtrl.text.trim().contains('@') &&
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
        _pickedCity = location.city;
        _pickedState = location.state;
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
      ToastService.showError('No se pudo obtener la ubicacion');
    }
  }

  void _clearLocation() {
    setState(() {
      _pickedLat = null;
      _pickedLng = null;
      _pickedAddress = null;
      _pickedCity = null;
      _pickedState = null;
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

  // ── Identity gate ────────────────────────────────────────────────────

  Future<bool> _ensureIdentityVerified() async {
    final security = ref.read(securityProvider);
    if (security.isGoogleLinked || security.isEmailConfirmed) return true;

    // Show identity verification gate
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _IdentityGateSheet(),
    );

    if (result == true) {
      // Re-check after returning
      await ref.read(securityProvider.notifier).checkIdentities();
      final updated = ref.read(securityProvider);
      return updated.isGoogleLinked || updated.isEmailConfirmed;
    }
    return false;
  }

  // ── Phone matching against discovered_salons ────────────────────────

  void _onPhoneChanged(String value) {
    setState(() {}); // Refresh validation
    _phoneDebounce?.cancel();

    // Skip if already matched via invite link
    if (widget.refCode != null && widget.refCode!.isNotEmpty) return;

    final digits = value.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 10) {
      if (_discoveredSalonId != null) {
        setState(() {
          _discoveredSalonId = null;
          _discoveredSalonData = null;
        });
      }
      return;
    }

    _phoneDebounce = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted) return;
      setState(() => _phoneMatchLoading = true);

      try {
        final last10 = digits.length > 10
            ? digits.substring(digits.length - 10)
            : digits;

        final results = await SupabaseClientService.client
            .from(BCTables.discoveredSalons)
            .select()
            .or('phone.ilike.%$last10,whatsapp.ilike.%$last10')
            .limit(1);

        if (!mounted) return;

        if (results.isNotEmpty && results.first['status'] != 'registered') {
          _prefillFromDiscoveredSalon(results.first);
        } else if (_discoveredSalonId != null) {
          setState(() {
            _discoveredSalonId = null;
            _discoveredSalonData = null;
          });
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[SalonOnboarding] Phone match error: $e');
      } finally {
        if (mounted) setState(() => _phoneMatchLoading = false);
      }
    });
  }

  void _prefillFromDiscoveredSalon(Map<String, dynamic> salon) {
    setState(() {
      _discoveredSalonData = salon;
      _discoveredSalonId = salon['id'] as String?;

      final name = salon['business_name'] ?? salon['name'];
      if (name != null &&
          name.toString().isNotEmpty &&
          _nameCtrl.text.trim().isEmpty) {
        _nameCtrl.text = _sanitizeLatin(name.toString());
      }

      if (!_locationConfirmed) {
        final address = salon['location_address'] ?? salon['address'];
        final lat = salon['latitude'] ?? salon['location_lat'] ?? salon['lat'];
        final lng = salon['longitude'] ?? salon['location_lng'] ?? salon['lng'];

        if (address != null && address.toString().isNotEmpty) {
          _addressCtrl.text = _sanitizeLatin(address.toString());
          _pickedAddress = _addressCtrl.text;
        }
        if (lat != null && lng != null) {
          _pickedLat = (lat is num)
              ? lat.toDouble()
              : double.tryParse(lat.toString());
          _pickedLng = (lng is num)
              ? lng.toDouble()
              : double.tryParse(lng.toString());
          if (_pickedLat != null && _pickedLng != null) {
            _locationConfirmed = true;
          }
        }

        _pickedCity = salon['location_city'] ?? salon['city'];
        _pickedState = salon['location_state'] ?? salon['state'];
      }

      _photoUrl ??= salon['feature_image_url'] ?? salon['photo_url'];
    });
  }

  // ── Confirmation card actions ────────────────────────────────────────

  void _selectNearbyMatch(Map<String, dynamic> salon) {
    HapticFeedback.selectionClick();
    setState(() {
      _matchedSalon = salon;
      _nearbyMatches = [];
      _photoUrl = salon['feature_image_url'] ?? salon['photo_url'];
    });
  }

  Future<void> _confirmMatch() async {
    if (_matchedSalon == null) return;
    HapticFeedback.mediumImpact();

    final salon = _matchedSalon!;
    _prefillFromDiscoveredSalon(salon);

    // Also set phone from match if available
    final phone = salon['whatsapp'] ?? salon['phone'];
    if (phone != null && phone.toString().isNotEmpty && _phoneCtrl.text.trim() == '+52') {
      _phoneCtrl.text = phone.toString();
    }

    setState(() {
      _showConfirmation = false;
      _nearbyMatches = [];
    });

    // Check if we can auto-submit (all required fields filled)
    // Allow a frame for setState to settle
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    if (_isValid) {
      // All fields filled — auto-submit directly
      setState(() => _autoSubmitting = true);

      // Gate: require Google or confirmed email (bypass for invite links)
      if (widget.refCode == null || widget.refCode!.isEmpty) {
        final identityOk = await _ensureIdentityVerified();
        if (!identityOk || !mounted) {
          setState(() => _autoSubmitting = false);
          return;
        }
      }

      await _submit();
      if (mounted) setState(() => _autoSubmitting = false);
    }
  }

  void _dismissConfirmation() {
    setState(() {
      _showConfirmation = false;
      _matchedSalon = null;
      _nearbyMatches = [];
    });
  }

  // ── Submit ───────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_isValid || _submitting) return;

    // Gate: require Google or confirmed email (bypass for invite links)
    if (widget.refCode == null || widget.refCode!.isEmpty) {
      final identityOk = await _ensureIdentityVerified();
      if (!identityOk || !mounted) return;
    }

    setState(() => _submitting = true);

    try {
      final rawPhone = _phoneCtrl.text.replaceAll(RegExp(r'[^\d+]'), '');
      final phone = rawPhone.startsWith('+') ? rawPhone : '+52$rawPhone';

      // Check phone uniqueness before calling edge function
      final phoneDigits = phone.replaceAll(RegExp(r'[^\d]'), '');
      final last10 = phoneDigits.length > 10
          ? phoneDigits.substring(phoneDigits.length - 10)
          : phoneDigits;
      final existingBiz = await SupabaseClientService.client
          .from(BCTables.businesses)
          .select('id')
          .or('phone.ilike.%$last10,whatsapp.ilike.%$last10')
          .limit(1)
          .maybeSingle();
      if (existingBiz != null) {
        if (mounted) {
          ToastService.showError('Ya existe un salon con este numero de telefono');
          setState(() => _submitting = false);
        }
        return;
      }

      final baseAddress = _pickedAddress ?? _addressCtrl.text.trim();
      final details = _detailsCtrl.text.trim();
      final fullAddress =
          details.isNotEmpty ? '$baseAddress, $details' : baseAddress;

      // Resolve discovered salon ID from either invite ref or phone match
      final discoveredSalonId = widget.refCode?.isNotEmpty == true
          ? widget.refCode
          : _discoveredSalonId;

      final city = _pickedCity ??
          _discoveredSalonData?['location_city'] ??
          _discoveredSalonData?['city'];
      final state = _pickedState ??
          _discoveredSalonData?['location_state'] ??
          _discoveredSalonData?['state'];

      // Call register-business edge function — creates business, staff,
      // schedule (Mon-Sat 9-7), role upgrade, and discovered salon link atomically.
      // Retry up to 3 times with 2-second delays on failure.
      final requestBody = {
        'name': _nameCtrl.text.trim(),
        'phone': phone,
        'whatsapp': phone,
        'address': fullAddress,
        'city': ?city,
        'state': ?state,
        'lat': _pickedLat,
        'lng': _pickedLng,
        'photo_url': ?_photoUrl,
        'discovered_salon_id': ?discoveredSalonId,
      };

      const maxAttempts = 3;
      late Map<String, dynamic> data;
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          final res = await SupabaseClientService.client.functions.invoke(
            'register-business',
            body: requestBody,
          );
          data = res.data as Map<String, dynamic>;
          if (data['error'] != null) {
            throw Exception(data['error'] as String);
          }
          break; // Success — exit retry loop
        } catch (e) {
          if (attempt < maxAttempts) {
            ToastService.showWarning('Reintentando...');
            await Future.delayed(const Duration(seconds: 2));
          } else {
            rethrow; // All retries exhausted
          }
        }
      }

      final businessId = data['business']?['id'] as String? ?? '';

      // Save email on user's auth account (best-effort)
      final email = _emailCtrl.text.trim();
      if (email.isNotEmpty && email.contains('@')) {
        try {
          await SupabaseClientService.client.auth.updateUser(
            UserAttributes(email: email),
          );
        } catch (e) {
          if (kDebugMode) debugPrint('[SalonOnboarding] Email update failed (non-critical): $e');
        }
      }

      // Upload license image if provided
      if (_licenseBytes != null && businessId.isNotEmpty) {
        try {
          final licensePath = 'salon-ids/$businessId/license.jpg';
          await SupabaseClientService.client.storage
              .from('salon-ids')
              .uploadBinary(
                licensePath,
                _licenseBytes!,
                fileOptions: const FileOptions(
                  contentType: 'image/jpeg',
                  upsert: true,
                ),
              );
          await SupabaseClientService.client
              .from(BCTables.businesses)
              .update({'municipal_license_url': licensePath})
              .eq('id', businessId);
        } catch (e) {
          if (kDebugMode) debugPrint('[SalonOnboarding] License upload failed (non-critical): $e');
        }
      }

      setState(() {
        _businessId = businessId;
        _registered = true;
      });
    } catch (e, stack) {
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: colors.primary),
        ),
      );
    }

    // Show auto-submit loading state
    if (_autoSubmitting) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: colors.primary),
              const SizedBox(height: 20),
              Text(
                'Registrando tu salon...',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            // ── Gradient header ──────────────────────────────────────
            SliverToBoxAdapter(
              child: _HeroHeader(
                photoUrl: _showConfirmation
                    ? (_matchedSalon?['feature_image_url'] ??
                        _matchedSalon?['photo_url'] ??
                        _photoUrl)
                    : _photoUrl,
                onBack: () => context.pop(),
              ),
            ),

            // ── Confirmation card (match found) ─────────────────────
            if (_showConfirmation) ...[
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  20, 0, 20,
                  MediaQuery.of(context).viewInsets.bottom + 32,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (_matchedSalon != null && _nearbyMatches.isEmpty)
                      _ConfirmationCard(
                        salon: _matchedSalon!,
                        onConfirm: _confirmMatch,
                        onDismiss: _dismissConfirmation,
                      )
                    else if (_nearbyMatches.isNotEmpty)
                      _NearbyMatchList(
                        salons: _nearbyMatches,
                        onSelect: _selectNearbyMatch,
                        onDismiss: _dismissConfirmation,
                      ),
                    const SizedBox(height: 16),
                  ]),
                ),
              ),
            ] else ...[

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
                        onChanged: _onPhoneChanged,
                        suffixWidget: _phoneMatchLoading
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

                      // Phone match banner
                      if (_discoveredSalonId != null &&
                          (widget.refCode == null ||
                              widget.refCode!.isEmpty)) ...[
                        const SizedBox(height: 10),
                        _InfoBanner(
                          icon: Icons.auto_awesome,
                          text:
                              'Encontramos tu salon! Datos pre-llenados.',
                          color: colors.primary,
                        ),
                      ],
                      const SizedBox(height: 14),

                      // Email
                      _StyledField(
                        controller: _emailCtrl,
                        label: 'Email de contacto',
                        hint: 'tu@email.com',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
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
                              color: colors.surface,
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
                                                    color: colors.onSurface,
                                                  ),
                                                ),
                                                if (p.secondaryText.isNotEmpty)
                                                  Text(
                                                    p.secondaryText,
                                                    style: GoogleFonts.nunito(
                                                      fontSize: 12,
                                                      color: colors.onSurface.withValues(alpha: 0.6),
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
                                    color: colors.onSurface,
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

                  // ── Section: Licencia de funcionamiento (optional) ──
                  _SectionCard(
                    children: [
                      _SectionHeader(
                        icon: Icons.badge_outlined,
                        title: 'Licencia de funcionamiento',
                        color: colors.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Opcional: sube una foto de tu licencia de funcionamiento para acelerar la verificacion.',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          color: colors.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_licenseBytes != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            _licenseBytes!,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              _licenseName ?? 'Licencia adjunta',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: colors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () => setState(() {
                                _licenseBytes = null;
                                _licenseName = null;
                              }),
                              icon: const Icon(Icons.close, size: 16),
                              label: const Text('Quitar'),
                              style: TextButton.styleFrom(
                                foregroundColor: colors.error,
                              ),
                            ),
                          ],
                        ),
                      ] else
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picker = ImagePicker();
                            final picked = await picker.pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 1600,
                              imageQuality: 85,
                            );
                            if (picked != null) {
                              final bytes = await picked.readAsBytes();
                              setState(() {
                                _licenseBytes = bytes;
                                _licenseName = picked.name;
                              });
                            }
                          },
                          icon: const Icon(Icons.upload_file_rounded),
                          label: const Text('Subir licencia'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.primary,
                            side: BorderSide(color: colors.primary.withValues(alpha: 0.3)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
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
            ], // close else (form content)
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
            const Color(0xFF990033),
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
                  icon: Icon(Icons.arrow_back_rounded,
                      color: Theme.of(context).colorScheme.onPrimary, size: 24),
                  onPressed: onBack,
                ),
              ),
              const SizedBox(height: 8),

              // Avatar or icon
              if (photoUrl != null)
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).colorScheme.onPrimary, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
                    backgroundImage: NetworkImage(photoUrl!),
                    onBackgroundImageError: (_, _) {},
                  ),
                )
              else
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.15),
                    border:
                        Border.all(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.3), width: 2),
                  ),
                  child: Icon(Icons.store_rounded,
                      size: 36, color: Theme.of(context).colorScheme.onPrimary),
                ),
              const SizedBox(height: 16),

              Text(
                'Registra tu Salon',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onPrimary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Unete a BeautyCita y recibe clientes nuevas',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.85),
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF660033).withValues(alpha: 0.04),
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
            color: Theme.of(context).colorScheme.onSurface,
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
      style: GoogleFonts.nunito(fontSize: 15, color: colors.onSurface),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle:
            GoogleFonts.nunito(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6)),
        hintStyle:
            GoogleFonts.nunito(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.4)),
        prefixIcon: Icon(icon, size: 20, color: effectiveIconColor),
        suffixIcon: suffixWidget,
        filled: true,
        fillColor: colors.surface,
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
// Confirmation Card — "Es este tu salon?" with fade+scale entrance
// ==========================================================================

class _ConfirmationCard extends StatefulWidget {
  final Map<String, dynamic> salon;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  const _ConfirmationCard({
    required this.salon,
    required this.onConfirm,
    required this.onDismiss,
  });

  @override
  State<_ConfirmationCard> createState() => _ConfirmationCardState();
}

class _ConfirmationCardState extends State<_ConfirmationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOut,
    );
    _scaleAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack),
    );
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final salon = widget.salon;
    final name = salon['business_name'] ?? salon['name'] ?? '';
    final address = salon['location_address'] ?? salon['address'] ?? '';
    final phone = salon['whatsapp'] ?? salon['phone'] ?? '';
    final photoUrl = salon['feature_image_url'] ?? salon['photo_url'];
    const brandStart = Color(0xFFEC4899);
    const brandEnd = Color(0xFF9333EA);

    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Background photo or gradient
              if (photoUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 320,
                    child: Image.network(
                      photoUrl.toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colors.primary,
                              colors.primary.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  height: 320,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.primary,
                        colors.primary.withValues(alpha: 0.7),
                        const Color(0xFF990033),
                      ],
                    ),
                  ),
                ),

              // Dark overlay for readability
              Container(
                width: double.infinity,
                height: 320,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),

              // Content overlay
              SizedBox(
                width: double.infinity,
                height: 320,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Salon name
                      Text(
                        name.toString(),
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onPrimary,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (address.toString().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded,
                                size: 16, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                address.toString(),
                                style: GoogleFonts.nunito(
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (phone.toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.phone_rounded,
                                size: 16, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7)),
                            const SizedBox(width: 4),
                            Text(
                              phone.toString(),
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),

                      // Question
                      Text(
                        'Es este tu salon?',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // CTA buttons
                      // Brand "Si" button
                      SizedBox(
                        width: double.infinity,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: const LinearGradient(
                              colors: [brandStart, brandEnd],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: brandStart.withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap: widget.onConfirm,
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                child: Center(
                                  child: Text(
                                    'SI, ESTE ES MI SALON',
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // "No" text button
                      Center(
                        child: TextButton(
                          onPressed: widget.onDismiss,
                          child: Text(
                            'No, registrar otro',
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                              decoration: TextDecoration.underline,
                              decorationColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.54),
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
        ),
      ),
    );
  }
}

// ==========================================================================
// Nearby Match List — multiple GPS matches, tap to select
// ==========================================================================

class _NearbyMatchList extends StatefulWidget {
  final List<Map<String, dynamic>> salons;
  final void Function(Map<String, dynamic>) onSelect;
  final VoidCallback onDismiss;

  const _NearbyMatchList({
    required this.salons,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  State<_NearbyMatchList> createState() => _NearbyMatchListState();
}

class _NearbyMatchListState extends State<_NearbyMatchList>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Encontramos salones cerca de ti',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Toca tu salon para continuar',
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: colors.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),

          // Salon cards
          ...widget.salons.asMap().entries.map((entry) {
            final idx = entry.key;
            final salon = entry.value;
            final name = salon['business_name'] ?? salon['name'] ?? '';
            final address = salon['location_address'] ?? salon['address'] ?? '';
            final phone = salon['whatsapp'] ?? salon['phone'] ?? '';
            final photoUrl =
                salon['feature_image_url'] ?? salon['photo_url'];

            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 300 + (idx * 100)),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  elevation: 0,
                  child: InkWell(
                    onTap: () => widget.onSelect(salon),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Photo or icon
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: colors.primary.withValues(alpha: 0.08),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: photoUrl != null
                                ? Image.network(
                                    photoUrl.toString(),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.store_rounded,
                                      size: 28,
                                      color: colors.primary.withValues(alpha: 0.5),
                                    ),
                                  )
                                : Icon(
                                    Icons.store_rounded,
                                    size: 28,
                                    color: colors.primary.withValues(alpha: 0.5),
                                  ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name.toString(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: colors.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (address.toString().isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    address.toString(),
                                    style: GoogleFonts.nunito(
                                      fontSize: 13,
                                      color: colors.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                if (phone.toString().isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    phone.toString(),
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      color: colors.onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: colors.primary.withValues(alpha: 0.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),

          // "None of these" button
          Center(
            child: TextButton(
              onPressed: widget.onDismiss,
              child: Text(
                'Ninguno es mi salon, registrar nuevo',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: colors.onSurface.withValues(alpha: 0.5),
                  decoration: TextDecoration.underline,
                ),
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
                  colors: [colors.primary, const Color(0xFF990033)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: enabled ? null : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
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
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary),
                      )
                    : Text(
                        'REGISTRARME GRATIS',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: enabled
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
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
        color: Theme.of(context).colorScheme.surface,
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
                  color: Theme.of(context).colorScheme.onSurface,
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
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
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
                color: colors.onSurface.withValues(alpha: 0.6),
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
                            Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.3),
                            Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.0),
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
                      color: Theme.of(context).colorScheme.onSurface,
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
// Identity Gate Sheet — requires Google or confirmed email before registering
// ==========================================================================

class _IdentityGateSheet extends ConsumerStatefulWidget {
  const _IdentityGateSheet();

  @override
  ConsumerState<_IdentityGateSheet> createState() => _IdentityGateSheetState();
}

class _IdentityGateSheetState extends ConsumerState<_IdentityGateSheet> {
  bool _showEmailInput = false;
  final _emailCtrl = TextEditingController();
  bool _emailSent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final security = ref.watch(securityProvider);
    final colors = Theme.of(context).colorScheme;

    // Auto-dismiss if verification succeeded
    if (security.isGoogleLinked || security.isEmailConfirmed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, true);
      });
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24, 16, 24,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.verified_user_rounded,
                  size: 32, color: colors.primary),
            ),
            const SizedBox(height: 16),

            Text(
              'Verifica tu identidad',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Para registrar un salon necesitas vincular tu cuenta de Google o confirmar tu email.',
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: colors.onSurface.withValues(alpha: 0.6),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Google button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: security.isLoading
                    ? null
                    : () async {
                        await ref.read(securityProvider.notifier).linkGoogle();
                      },
                icon: security.isLoading && !_showEmailInput
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary),
                      )
                    : const Icon(Icons.g_mobiledata_rounded, size: 24),
                label: const Text('Continuar con Google'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Divider
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('o',
                      style: GoogleFonts.nunito(
                          color: colors.onSurface.withValues(alpha: 0.4), fontSize: 14)),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 12),

            if (!_showEmailInput && !_emailSent)
              // Show email option button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _showEmailInput = true),
                  icon: const Icon(Icons.email_outlined, size: 20),
                  label: const Text('Verificar con email'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              )
            else if (_emailSent)
              // Confirmation sent
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.mark_email_read_rounded,
                        color: Colors.green.shade600, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Se envio un correo de confirmacion a ${_emailCtrl.text}. Confirma tu email y luego intenta registrarte de nuevo.',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          color: Colors.green.shade800,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              // Email input
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.nunito(fontSize: 15),
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'tu@email.com',
                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                  filled: true,
                  fillColor: colors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: colors.primary.withValues(alpha: 0.12)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: colors.primary.withValues(alpha: 0.12)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: security.isLoading
                      ? null
                      : () async {
                          final email = _emailCtrl.text.trim();
                          if (email.isEmpty || !email.contains('@')) return;
                          await ref
                              .read(securityProvider.notifier)
                              .addEmail(email);
                          if (mounted) setState(() => _emailSent = true);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: security.isLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary),
                        )
                      : const Text('Enviar confirmacion'),
                ),
              ),
            ],

            if (security.error != null) ...[
              const SizedBox(height: 12),
              Text(
                security.error!,
                style: GoogleFonts.nunito(
                    fontSize: 13, color: Colors.red.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
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
    } catch (e, stack) {
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
    } finally {
      if (mounted) setState(() => _loadingStripe = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                        color: colors.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          color: colors.onSurface.withValues(alpha: 0.6),
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
                    color: Theme.of(context).colorScheme.onPrimary,
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
                                    color: colors.onSurface,
                                  ),
                                ),
                                Text(
                                  'Para recibir pagos de clientes',
                                  style: GoogleFonts.nunito(
                                    fontSize: 13,
                                    color: colors.onSurface.withValues(alpha: 0.6),
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
                          color: colors.onSurface.withValues(alpha: 0.6),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _loadingStripe ? null : _setupStripe,
                          icon: _loadingStripe
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Theme.of(context).colorScheme.onPrimary,
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
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                    color: colors.onSurface.withValues(alpha: 0.6),
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
                          color: colors.onSurface.withValues(alpha: 0.6),
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
