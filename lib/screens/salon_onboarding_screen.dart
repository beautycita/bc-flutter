import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
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

      // Create business record (Tier 1)
      final response = await SupabaseClientService.client
          .from('businesses')
          .insert({
            'name': _nameCtrl.text.trim(),
            'phone': phone,
            'whatsapp': phone,
            'address': _addressCtrl.text.trim().isEmpty
                ? null
                : _addressCtrl.text.trim(),
            'tier': 1,
            'is_active': true,
            'service_categories': _selectedCategories.toList(),
          })
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

      setState(() => _registered = true);
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
        onDone: () => context.go('/home'),
      );
    }

    return Scaffold(
      backgroundColor: BeautyCitaTheme.surfaceCream,
      appBar: AppBar(
        backgroundColor: BeautyCitaTheme.surfaceCream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: BeautyCitaTheme.textDark, size: 24),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(BeautyCitaTheme.spaceLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Registra tu salon',
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: BeautyCitaTheme.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Gratis. 60 segundos. Sin tarjeta.',
              style: GoogleFonts.nunito(
                fontSize: 15,
                color: BeautyCitaTheme.textLight,
              ),
            ),
            const SizedBox(height: BeautyCitaTheme.spaceXL),

            // Business name
            Text('Nombre del salon',
                style: _labelStyle()),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              onChanged: (_) => setState(() {}),
              decoration: _inputDecoration('Ej: Salon Rosa'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: BeautyCitaTheme.spaceLG),

            // WhatsApp number
            Text('WhatsApp',
                style: _labelStyle()),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneCtrl,
              onChanged: (_) => setState(() {}),
              decoration: _inputDecoration('+52 33 1234 5678'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: BeautyCitaTheme.spaceLG),

            // Address
            Text('Direccion (opcional)',
                style: _labelStyle()),
            const SizedBox(height: 8),
            TextField(
              controller: _addressCtrl,
              decoration: _inputDecoration('Buscar direccion o usar GPS'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: BeautyCitaTheme.spaceXL),

            // Categories
            Text('Que servicios ofreces?',
                style: _labelStyle()),
            const SizedBox(height: BeautyCitaTheme.spaceMD),
            Wrap(
              spacing: BeautyCitaTheme.spaceSM,
              runSpacing: BeautyCitaTheme.spaceSM,
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
                            : BeautyCitaTheme.textDark,
                      ),
                      const SizedBox(width: 6),
                      Text(cat.label),
                    ],
                  ),
                  selectedColor: BeautyCitaTheme.primaryRose,
                  checkmarkColor: Colors.white,
                  labelStyle: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : BeautyCitaTheme.textDark,
                  ),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(BeautyCitaTheme.radiusMedium),
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

            const SizedBox(height: BeautyCitaTheme.spaceXL),

            // Submit
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isValid && !_submitting ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BeautyCitaTheme.primaryRose,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      vertical: BeautyCitaTheme.spaceMD),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(BeautyCitaTheme.radiusLarge),
                  ),
                  elevation: 0,
                  disabledBackgroundColor:
                      BeautyCitaTheme.primaryRose.withValues(alpha: 0.3),
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
            const SizedBox(height: BeautyCitaTheme.spaceLG),
          ],
        ),
      ),
    );
  }

  TextStyle _labelStyle() => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: BeautyCitaTheme.textDark,
      );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.nunito(fontSize: 14, color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BeautyCitaTheme.radiusMedium),
          borderSide:
              const BorderSide(color: BeautyCitaTheme.primaryRose, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: BeautyCitaTheme.spaceMD,
          vertical: BeautyCitaTheme.spaceMD,
        ),
      );
}

class _SuccessScreen extends StatelessWidget {
  final VoidCallback onDone;
  const _SuccessScreen({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BeautyCitaTheme.surfaceCream,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(BeautyCitaTheme.spaceXL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: BeautyCitaTheme.primaryRose.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 48,
                  color: BeautyCitaTheme.primaryRose,
                ),
              ),
              const SizedBox(height: BeautyCitaTheme.spaceLG),
              Text(
                'Bienvenido a BeautyCita!',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: BeautyCitaTheme.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: BeautyCitaTheme.spaceSM),
              Text(
                'Tu salon ya esta visible para clientas cercanas. '
                'Te contactaran por WhatsApp.',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  color: BeautyCitaTheme.textLight,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: BeautyCitaTheme.spaceXL),
              ElevatedButton(
                onPressed: onDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BeautyCitaTheme.primaryRose,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(200, 48),
                ),
                child: const Text('CONTINUAR'),
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
