import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:beautycita/config/fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';

/// Shows a prompt to save BeautyCita as a contact after phone verification.
/// Uses Android's native "save contact" intent — no permissions needed.
class SaveContactPrompt {
  static const _shownKey = 'bc_contact_prompt_shown';
  static const _platform = MethodChannel('com.beautycita.app/contacts');

  /// Show the save-contact prompt if not already shown.
  /// Call this after successful phone verification.
  static Future<void> showIfNeeded(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_shownKey) == true) return;

    if (!context.mounted) return;

    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SaveContactSheet(),
    );

    if (result == true) {
      await _launchSaveContact();
    }

    // Mark as shown regardless of choice
    await prefs.setBool(_shownKey, true);
  }

  /// Launch the native save-contact intent with pre-filled data.
  static Future<void> _launchSaveContact() async {
    try {
      await _platform.invokeMethod('saveContact', {
        'name': 'BeautyCita',
        'phone': '+527206777800',
        'organization': 'BeautyCita S.A. de C.V.',
      });
    } catch (e) {
      debugPrint('[SaveContact] Intent failed: $e');
    }
  }
}

class _SaveContactSheet extends StatelessWidget {
  const _SaveContactSheet();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: AppConstants.paddingLG,
        right: AppConstants.paddingLG,
        top: AppConstants.paddingMD,
        bottom: AppConstants.paddingLG + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Icon
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEC4899), Color(0xFF9333EA)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.contact_phone_rounded, color: const Color(0xFFFFFFFF), size: 32),
          ),
          const SizedBox(height: 20),

          Text(
            'Agregar BeautyCita\ncomo contacto?',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          Text(
            'Esto mejora nuestra capacidad de enviarte alertas sobre tus citas y mensajes de BeautyCita.',
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: cs.onSurface.withValues(alpha: 0.54),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Yes button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(true),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEC4899), Color(0xFF9333EA)],
                ),
                borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEC4899).withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                'Si, agregar contacto',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFFFFFF),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // No thanks
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Ahora no',
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: cs.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
