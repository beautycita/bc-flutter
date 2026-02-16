import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/constants.dart';
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

  final Set<String> _selectedCategories = {};
  bool _submitting = false;
  bool _registered = false;
  bool _loadingPrefill = false;
  String? _photoUrl;
  Map<String, dynamic>? _discoveredSalonData;
  String? _businessId; // Stored after registration for Stripe setup

  static const _categories = <_CategoryOption>[
    _CategoryOption(slug: 'unas', label: 'Unas', icon: Icons.brush),
    _CategoryOption(slug: 'cabello', label: 'Cabello', icon: Icons.content_cut),
    _CategoryOption(
        slug: 'pestanas_cejas', label: 'Pestanas y Cejas', icon: Icons.visibility),
    _CategoryOption(slug: 'maquillaje', label: 'Maquillaje', icon: Icons.palette),
    _CategoryOption(slug: 'facial', label: 'Facial', icon: Icons.face),
    _CategoryOption(slug: 'cuerpo_spa', label: 'Cuerpo y Spa', icon: Icons.spa),
    _CategoryOption(
        slug: 'cuidado_especializado',
        label: 'Cuidado Especializado',
        icon: Icons.star),
  ];

  @override
  void initState() {
    super.initState();
    _loadDiscoveredSalonData();
  }

  /// Fetch discovered_salon data by refCode and pre-fill form fields
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

        // Pre-fill name (try business_name first, then name)
        final name = response['business_name'] ?? response['name'];
        if (name != null && name.toString().isNotEmpty) {
          _nameCtrl.text = _sanitizeLatin(name.toString());
        }

        // Pre-fill phone (prefer whatsapp, then phone)
        final phone = response['whatsapp'] ?? response['phone'];
        if (phone != null && phone.toString().isNotEmpty) {
          _phoneCtrl.text = phone.toString();
        }

        // Pre-fill address (try location_address first, then address)
        final address = response['location_address'] ?? response['address'];
        if (address != null && address.toString().isNotEmpty) {
          _addressCtrl.text = _sanitizeLatin(address.toString());
        }

        // Store photo URL for display
        _photoUrl = response['feature_image_url'] ?? response['photo_url'];

        // Try to infer categories from service_types or keywords if available
        final serviceTypes = response['service_types'];
        if (serviceTypes is List) {
          for (final svc in serviceTypes) {
            final svcStr = svc.toString().toLowerCase();
            if (svcStr.contains('una') || svcStr.contains('nail')) {
              _selectedCategories.add('unas');
            }
            if (svcStr.contains('cabello') || svcStr.contains('hair') || svcStr.contains('corte')) {
              _selectedCategories.add('cabello');
            }
            if (svcStr.contains('pestana') || svcStr.contains('ceja') || svcStr.contains('lash') || svcStr.contains('brow')) {
              _selectedCategories.add('pestanas_cejas');
            }
            if (svcStr.contains('maquillaje') || svcStr.contains('makeup')) {
              _selectedCategories.add('maquillaje');
            }
            if (svcStr.contains('facial') || svcStr.contains('face')) {
              _selectedCategories.add('facial');
            }
            if (svcStr.contains('spa') || svcStr.contains('cuerpo') || svcStr.contains('body') || svcStr.contains('massage')) {
              _selectedCategories.add('cuerpo_spa');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[SalonOnboarding] Error loading prefill data: $e');
    } finally {
      if (mounted) setState(() => _loadingPrefill = false);
    }
  }

  /// Strip non-Latin characters from scraped data
  String _sanitizeLatin(String text) {
    return text.replaceAll(
      RegExp(r'[^\u0000-\u024F\u1E00-\u1EFF\u2000-\u206F\u2070-\u209F\u20A0-\u20CF\u2100-\u214F\s]'),
      '',
    ).trim();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _nameCtrl.text.trim().length >= 2 &&
      _phoneCtrl.text.replaceAll(RegExp(r'[^\d]'), '').length >= 10 &&
      _selectedCategories.isNotEmpty;

  Future<void> _submit() async {
    if (!_isValid || _submitting) return;
    setState(() => _submitting = true);

    try {
      // Normalize phone to E.164
      final rawPhone = _phoneCtrl.text.replaceAll(RegExp(r'[^\d+]'), '');
      final phone =
          rawPhone.startsWith('+') ? rawPhone : '+52$rawPhone';

      // Build business record with pre-filled data where available
      final businessData = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'phone': phone,
        'whatsapp': phone,
        'address': _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        'tier': 1,
        'is_active': true,
        'service_categories': _selectedCategories.toList(),
      };

      // Include photo URL from discovered salon if available
      if (_photoUrl != null) {
        businessData['photo_url'] = _photoUrl;
      }

      // Include location coordinates from discovered salon if available
      if (_discoveredSalonData != null) {
        final lat = _discoveredSalonData!['location_lat'] ?? _discoveredSalonData!['lat'];
        final lng = _discoveredSalonData!['location_lng'] ?? _discoveredSalonData!['lng'];
        if (lat != null && lng != null) {
          businessData['location'] = 'POINT($lng $lat)';
        }
        // Include city if available
        final city = _discoveredSalonData!['location_city'] ?? _discoveredSalonData!['city'];
        if (city != null) {
          businessData['city'] = city;
        }
        // Include rating if available (as initial rating)
        final rating = _discoveredSalonData!['rating_average'] ?? _discoveredSalonData!['rating'];
        if (rating != null) {
          businessData['initial_rating'] = rating;
        }
      }

      // Create business record (Tier 1)
      final response = await SupabaseClientService.client
          .from('businesses')
          .insert(businessData)
          .select('id')
          .single();

      final businessId = response['id'] as String;

      // If ref code is a discovered_salon_id, mark it as registered
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

  @override
  Widget build(BuildContext context) {
    if (_registered) {
      return _SuccessScreen(
        businessId: _businessId,
        businessName: _nameCtrl.text.trim(),
        onDone: () => context.go('/home'),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    if (_loadingPrefill) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Cargando datos de tu salon...',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: colorScheme.onSurface, size: 24),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.paddingLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo preview (if available from discovered_salons)
            if (_photoUrl != null) ...[
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppConstants.radiusLG),
                  child: Image.network(
                    _photoUrl!,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppConstants.radiusLG),
                      ),
                      child: Icon(
                        Icons.store,
                        size: 48,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.paddingMD),
            ],

            // Header
            Text(
              'Registra tu salon',
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Gratis. 60 segundos. Sin tarjeta.',
              style: GoogleFonts.nunito(
                fontSize: 15,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),

            // Pre-fill notice
            if (_discoveredSalonData != null) ...[
              const SizedBox(height: AppConstants.paddingSM),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 18, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Datos pre-llenados. Puedes editarlos si algo esta mal.',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppConstants.paddingXL),

            // Business name
            Text('Nombre del salon',
                style: _labelStyle(colorScheme)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              onChanged: (_) => setState(() {}),
              decoration: _inputDecoration('Ej: Salon Rosa', colorScheme),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppConstants.paddingLG),

            // WhatsApp number
            Text('WhatsApp',
                style: _labelStyle(colorScheme)),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneCtrl,
              onChanged: (_) => setState(() {}),
              decoration: _inputDecoration('+52 33 1234 5678', colorScheme),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppConstants.paddingLG),

            // Address
            Text('Direccion (opcional)',
                style: _labelStyle(colorScheme)),
            const SizedBox(height: 8),
            TextField(
              controller: _addressCtrl,
              decoration: _inputDecoration('Buscar direccion o usar GPS', colorScheme),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppConstants.paddingXL),

            // Categories
            Text('Que servicios ofreces?',
                style: _labelStyle(colorScheme)),
            const SizedBox(height: AppConstants.paddingMD),
            Wrap(
              spacing: AppConstants.paddingSM,
              runSpacing: AppConstants.paddingSM,
              children: _categories.map((cat) {
                final selected = _selectedCategories.contains(cat.slug);
                return FilterChip(
                  selected: selected,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        cat.icon,
                        size: 18,
                        color: selected
                            ? Colors.white
                            : colorScheme.onSurface,
                      ),
                      const SizedBox(width: 6),
                      Text(cat.label),
                    ],
                  ),
                  selectedColor: colorScheme.primary,
                  checkmarkColor: Colors.white,
                  labelStyle: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : colorScheme.onSurface,
                  ),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusMD),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 4),
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _selectedCategories.add(cat.slug);
                      } else {
                        _selectedCategories.remove(cat.slug);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: AppConstants.paddingXL),

            // Submit
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isValid && !_submitting ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      vertical: AppConstants.paddingMD),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusLG),
                  ),
                  elevation: 0,
                  disabledBackgroundColor:
                      colorScheme.primary.withValues(alpha: 0.3),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'REGISTRARME GRATIS',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: AppConstants.paddingLG),
          ],
        ),
      ),
    );
  }

  TextStyle _labelStyle(ColorScheme colorScheme) => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      );

  InputDecoration _inputDecoration(String hint, ColorScheme colorScheme) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.nunito(fontSize: 14, color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
          borderSide:
              BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingMD,
          vertical: AppConstants.paddingMD,
        ),
      );
}

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

class _SuccessScreenState extends State<_SuccessScreen> {
  bool _loadingStripe = false;

  Future<void> _setupStripe() async {
    if (widget.businessId == null) return;

    setState(() => _loadingStripe = true);

    try {
      // Call edge function to get Stripe onboarding URL
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
        // Launch Stripe onboarding in browser
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.paddingXL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 48),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 48,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppConstants.paddingLG),
              Text(
                'Bienvenido a BeautyCita!',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.paddingSM),
              Text(
                'Tu salon "${widget.businessName}" ya esta registrado.',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.paddingXL),

              // Stripe setup card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppConstants.paddingLG),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppConstants.radiusLG),
                  border: Border.all(
                    color: const Color(0xFF635BFF).withValues(alpha: 0.3), // Stripe purple
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF635BFF).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet,
                            color: Color(0xFF635BFF),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Configurar pagos',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                'Para recibir pagos de clientes',
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.paddingMD),
                    Text(
                      'Conecta tu cuenta bancaria para recibir el pago de cada reserva directamente. Solo toma 2 minutos.',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: AppConstants.paddingMD),
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
                            : const Icon(Icons.arrow_forward, size: 18),
                        label: Text(
                          _loadingStripe ? 'Abriendo...' : 'CONFIGURAR AHORA',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF635BFF), // Stripe purple
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppConstants.paddingMD),

              // Skip option
              TextButton(
                onPressed: widget.onDone,
                child: Text(
                  'Configurar despues',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),

              const SizedBox(height: AppConstants.paddingLG),

              // Info note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.amber.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sin configurar pagos, las clientas te contactaran por WhatsApp pero no podran pagar en la app.',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: Colors.amber.shade900,
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

class _CategoryOption {
  final String slug;
  final String label;
  final IconData icon;
  const _CategoryOption({
    required this.slug,
    required this.label,
    required this.icon,
  });
}
