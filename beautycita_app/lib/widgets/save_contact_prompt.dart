import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:beautycita/config/fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';

/// Adds BeautyCita to the user's contacts so the alerts we send (push, WA,
/// SMS) aren't silently filtered. Two presentations:
///
///   * `showIfNeeded(context)` — bottom sheet, used right after phone
///     verification. Falls back to the native Android save-contact intent
///     so no WRITE_CONTACTS permission is required.
///
///   * `showPopupIfMissing(context)` — small dialog with a corner X close
///     and an "Agregar" accept. Used after the user reaches 5/5 on the
///     security screen, and at the same point where we already hold
///     READ_CONTACTS permission for salon-match. Skipped silently if BC
///     is already among the user's contacts.
class SaveContactPrompt {
  static const _shownKey = 'bc_contact_prompt_shown';
  static const _popupShownKey = 'bc_contact_popup_shown_at';
  static const _addedKey = 'bc_contact_added';
  static const _platform = MethodChannel('com.beautycita.app/contacts');

  /// Bottom-sheet variant used post phone-verify. Native intent path —
  /// works without WRITE_CONTACTS.
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
      await _launchSaveContactIntent();
    }

    await prefs.setBool(_shownKey, true);
  }

  /// Popup variant. Run after the security screen reaches 5/5 or any time
  /// we already hold READ_CONTACTS permission. Silent no-op if the user
  /// already has BeautyCita in their contacts, has previously added it,
  /// or dismissed the popup in the last 30 days.
  static Future<void> showPopupIfMissing(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    if (prefs.getBool(_addedKey) == true) return;

    final lastShown = prefs.getString(_popupShownKey);
    if (lastShown != null) {
      final ts = DateTime.tryParse(lastShown);
      if (ts != null &&
          DateTime.now().difference(ts) < const Duration(days: 30)) {
        return;
      }
    }

    // Need read permission to know whether BC is already a contact. We
    // don't request it here — the caller has already cleared that path
    // (security-screen trigger waits for the contact-match permission
    // grant; the auto-sync trigger only fires after permission is held).
    final hasRead = await FlutterContacts.permissions.has(PermissionType.read);
    if (!hasRead) return;

    final already = await _isAlreadyContact();
    if (already) {
      await prefs.setBool(_addedKey, true);
      return;
    }

    if (!context.mounted) return;

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // user must hit X or Agregar
      builder: (_) => const _SaveContactPopup(),
    );

    await prefs.setString(_popupShownKey, DateTime.now().toIso8601String());

    if (accepted == true) {
      final ok = await _addContactProgrammatically();
      if (!ok) {
        // FlutterContacts insert needs WRITE_CONTACTS — if the user
        // declined that, fall back to the native intent (no perm needed).
        await _launchSaveContactIntent();
      }
      await prefs.setBool(_addedKey, true);
    }
  }

  /// Mirror of ContactMatchService.normalizePhone — strips formatting and
  /// adds a +52 prefix to bare 10-digit MX numbers so a saved local-format
  /// contact still matches our +52-prefixed canonical number.
  static String _normalizePhone(String phone) {
    var digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final hasPlus = digits.startsWith('+');
    if (hasPlus) digits = digits.substring(1);
    if (digits.length == 10 && !digits.startsWith('1')) {
      digits = '52$digits';
    }
    return '+$digits';
  }

  static Future<bool> _isAlreadyContact() async {
    try {
      final target = _normalizePhone(AppConstants.bcContactPhone);
      final contacts = await FlutterContacts.getAll(
        properties: {ContactProperty.phone},
      );
      for (final c in contacts) {
        for (final p in c.phones) {
          if (_normalizePhone(p.number) == target) return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Insert BC contact via FlutterContacts. Requires WRITE_CONTACTS,
  /// which the user is prompted for the first time. Returns false on
  /// any failure so the caller can fall back to the system intent path.
  static Future<bool> _addContactProgrammatically() async {
    try {
      final status = await FlutterContacts.permissions.request(
        PermissionType.write,
      );
      if (status != PermissionStatus.granted) return false;
      final contact = Contact(
        name: const Name(first: AppConstants.bcContactName),
        organizations: const [
          Organization(name: AppConstants.bcContactOrganization),
        ],
        phones: const [
          Phone(
            number: AppConstants.bcContactPhone,
            label: Label(PhoneLabel.work),
          ),
        ],
        emails: const [
          Email(
            address: AppConstants.supportEmail,
            label: Label(EmailLabel.work),
          ),
        ],
      );
      await FlutterContacts.create(contact);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Native Android save-contact intent — opens the system "create contact"
  /// editor with our fields pre-filled. No permission needed and the user
  /// stays in control. No-op on iOS (caller currently only invokes this
  /// path after the user explicitly accepts).
  static Future<void> _launchSaveContactIntent() async {
    try {
      await _platform.invokeMethod('saveContact', {
        'name': AppConstants.bcContactName,
        'phone': AppConstants.bcContactPhone,
        'organization': AppConstants.bcContactOrganization,
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
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEC4899), Color(0xFF9333EA)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.contact_phone_rounded, color: Color(0xFFFFFFFF), size: 32),
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
            'Si no nos tienes guardados, tu telefono podria filtrar nuestras alertas de citas y mensajes como spam.',
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: cs.onSurface.withValues(alpha: 0.54),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
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

class _SaveContactPopup extends StatelessWidget {
  const _SaveContactPopup();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 12, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top row: icon + close X
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEC4899), Color(0xFF9333EA)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.contact_phone_rounded,
                      color: Color(0xFFFFFFFF), size: 22),
                ),
                const Spacer(),
                IconButton(
                  iconSize: 22,
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close_rounded,
                      color: cs.onSurface.withValues(alpha: 0.6)),
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Guardanos como contacto',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Si BeautyCita no esta en tus contactos, tu telefono o WhatsApp pueden bloquear nuestras alertas de citas y mensajes importantes.',
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.62),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(true),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEC4899), Color(0xFF9333EA)],
                  ),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Agregar contacto',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFFFFFFF),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
