import 'package:beautycita/widgets/cached_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita/config/fonts.dart';
import '../config/constants.dart';
import '../providers/profile_provider.dart';
import '../services/supabase_client.dart';
import '../services/toast_service.dart';

/// Shows enriched discovered salon data after phone verification match.
/// User confirms "Es tu salon?" and one-tap creates a stylist account.
class DiscoveredSalonConfirmScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> salonData;

  const DiscoveredSalonConfirmScreen({super.key, required this.salonData});

  @override
  ConsumerState<DiscoveredSalonConfirmScreen> createState() =>
      _DiscoveredSalonConfirmScreenState();
}

class _DiscoveredSalonConfirmScreenState
    extends ConsumerState<DiscoveredSalonConfirmScreen> {
  bool _isCreating = false;

  String get _salonName =>
      (widget.salonData['business_name'] ?? widget.salonData['name'] ?? '')
          as String;

  String? get _photoUrl =>
      (widget.salonData['feature_image_url'] ?? widget.salonData['photo_url'])
          as String?;

  double? get _rating =>
      (widget.salonData['rating_average'] ?? widget.salonData['rating'])
          as double?;

  int? get _reviewsCount =>
      (widget.salonData['rating_count'] ?? widget.salonData['reviews_count'])
          as int?;

  String? get _address {
    final addr = widget.salonData['location_address'] as String?;
    final city = widget.salonData['location_city'] as String?;
    return [addr, city].where((s) => s != null && s.isNotEmpty).join(', ');
  }

  String? get _phone =>
      (widget.salonData['whatsapp'] ?? widget.salonData['phone']) as String?;

  String get _salonId => widget.salonData['id'] as String;

  Future<void> _createAccount() async {
    setState(() => _isCreating = true);

    try {
      final profile = ref.read(profileProvider);
      final res = await SupabaseClientService.client.functions.invoke(
        'register-business',
        body: {
          'name': _salonName,
          'phone': profile.phone ?? _phone,
          'whatsapp': _phone,
          'address': widget.salonData['location_address'],
          'city': widget.salonData['location_city'],
          'lat': widget.salonData['lat'],
          'lng': widget.salonData['lng'],
          'service_categories': widget.salonData['specialties'] ?? [],
          'owner_name': profile.fullName,
          'discovered_salon_id': _salonId,
          'photo_url': _photoUrl,
        },
      );

      final data = res.data as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        throw Exception(
            data?['error'] ?? 'Error al crear cuenta de estilista');
      }

      if (!mounted) return;
      // Reload profile to pick up new role
      ref.read(profileProvider.notifier).load();
      context.go('/post-registration');
    } catch (e) {
      setState(() => _isCreating = false);
      final msg = e.toString().replaceFirst('Exception: ', '');
      ToastService.showError(msg);
    }
  }

  void _decline() {
    ref.read(profileProvider.notifier).clearDiscoveredSalonMatch();
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onSurfaceLight =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: primary),
          onPressed: _decline,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingLG,
          ),
          child: Column(
            children: [
              const SizedBox(height: 16),

              // Salon photo
              ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: _photoUrl != null
                    ? CachedImage(
                        _photoUrl!,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _defaultAvatar(),
                      )
                    : _defaultAvatar(),
              ),
              const SizedBox(height: 16),

              // Salon name
              Text(
                _salonName,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),

              // Rating
              if (_rating != null && _rating! > 0) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star, size: 18, color: Color(0xFFEC4899)),
                    const SizedBox(width: 4),
                    Text(
                      _rating!.toStringAsFixed(1),
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFEC4899),
                      ),
                    ),
                    if (_reviewsCount != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        '($_reviewsCount resenas)',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: onSurfaceLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 24),

              // Details card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppConstants.paddingMD),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusMD),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).shadowColor.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    if (_address != null && _address!.isNotEmpty)
                      _detailRow(Icons.location_on_outlined, _address!),
                    if (_phone != null)
                      _detailRow(Icons.phone_outlined, _phone!),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // "Es tu salon?" prompt
              Text(
                'Es tu salon?',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Confirma para crear tu cuenta de estilista en BeautyCita',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: onSurfaceLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Create account button
              GestureDetector(
                onTap: _isCreating ? null : _createAccount,
                child: Container(
                  height: 56,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: !_isCreating
                        ? const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFF9333EA)], begin: Alignment.centerLeft, end: Alignment.centerRight)
                        : const LinearGradient(
                            colors: [Color(0xFFCCCCCC), Color(0xFFAAAAAA)],
                          ),
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusMD),
                    boxShadow: !_isCreating
                        ? [
                            BoxShadow(
                              color: const Color(0xFFEC4899)
                                  .withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: _isCreating
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onPrimary),
                          ),
                        )
                      : Text(
                          'CREAR CUENTA DE ESTILISTA',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onPrimary,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Decline option
              TextButton(
                onPressed: _decline,
                child: Text(
                  'No, soy cliente',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: onSurfaceLight,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.nunito(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultAvatar() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.store,
        size: 48,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
