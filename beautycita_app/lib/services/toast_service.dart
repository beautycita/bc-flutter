import 'package:flutter/material.dart';
import 'package:beautycita/config/routes.dart';
import 'package:beautycita/repositories/error_report_repository.dart';
import 'package:beautycita/widgets/bc_toast_overlay.dart';

/// Global toast service — overlay-based, works without BuildContext.
///
/// Wire [navigatorKey] into GoRouter so the overlay resolves.
/// Keep [messengerKey] during migration (old SnackBar calls still work).
class ToastService {
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static OverlayEntry? _currentEntry;

  // ── Public API (same signatures as before) ──

  static void showError(String message, {String? technicalDetails}) {
    _showOverlay(
      type: BCToastType.error,
      message: message,
      technicalDetails: technicalDetails,
    );
  }

  static void showSuccess(String message) {
    _showOverlay(type: BCToastType.success, message: message);
  }

  static void showInfo(String message) {
    _showOverlay(type: BCToastType.info, message: message);
  }

  static void showWarning(String message, {String? technicalDetails}) {
    _showOverlay(
      type: BCToastType.warning,
      message: message,
      technicalDetails: technicalDetails,
    );
  }

  /// Convenience for catch blocks: shows friendly message + stores raw details.
  static void showErrorWithDetails(String message, Object error,
      [StackTrace? stack]) {
    final details = stack != null
        ? '${error.runtimeType}: $error\n${stack.toString().split('\n').take(8).join('\n')}'
        : '${error.runtimeType}: $error';
    showError(message, technicalDetails: details);
  }

  // ── Internal ──

  static String _currentScreenName() {
    try {
      return AppRoutes.router.routeInformationProvider.value.uri.path;
    } catch (_) {
      return 'unknown';
    }
  }

  static void _showOverlay({
    required BCToastType type,
    required String message,
    String? technicalDetails,
  }) {
    // Remove previous toast
    _removeCurrentEntry();

    final overlay = navigatorKey.currentState?.overlay;
    if (overlay == null) {
      // Fallback to old SnackBar path if overlay not available yet
      _fallbackSnackBar(message, type);
      return;
    }

    final screenName = _currentScreenName();
    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (context) => SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: BCToastOverlay(
              type: type,
              message: message,
              technicalDetails: technicalDetails,
              screenName: screenName,
              onDismiss: () {
                entry?.remove();
                if (_currentEntry == entry) _currentEntry = null;
              },
              onReport: technicalDetails != null
                  ? (details) => _submitReport(
                        message: message,
                        details: details,
                        screenName: screenName,
                      )
                  : null,
            ),
          ),
        ),
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }

  static void _removeCurrentEntry() {
    try {
      _currentEntry?.remove();
    } catch (_) {
      // Entry may already be removed
    }
    _currentEntry = null;
  }

  static void _fallbackSnackBar(String message, BCToastType type) {
    final messenger = messengerKey.currentState;
    if (messenger == null) {
      debugPrint('[ToastService] No messenger: $message');
      return;
    }
    Color bg;
    switch (type) {
      case BCToastType.error:
        bg = Colors.red.shade600;
      case BCToastType.warning:
        bg = Colors.orange.shade600;
      case BCToastType.success:
        bg = Colors.green.shade600;
      case BCToastType.info:
        bg = Colors.blue.shade600;
    }
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
    ));
  }

  static Future<void> _submitReport({
    required String message,
    required String details,
    required String screenName,
  }) async {
    try {
      await ErrorReportRepository.submit(
        errorMessage: message,
        errorDetails: details,
        screenName: screenName,
      );
    } catch (e) {
      debugPrint('[ToastService] Report failed: $e');
    }
  }

  /// Convert common error types to user-friendly messages
  static String friendlyError(Object error) {
    final msg = error.toString();

    // Network errors
    if (msg.contains('SocketException') ||
        msg.contains('Connection refused')) {
      return 'Sin conexion a internet';
    }
    if (msg.contains('TimeoutException') || msg.contains('timed out')) {
      return 'La conexion tardo demasiado';
    }

    // Auth errors
    if (msg.contains('Invalid login credentials')) {
      return 'Credenciales incorrectas';
    }
    if (msg.contains('Email not confirmed')) {
      return 'Confirma tu correo electronico';
    }
    if (msg.contains('User already registered')) {
      return 'Este correo ya esta registrado';
    }

    // Storage errors
    if (msg.contains('StorageException')) {
      return 'Error al subir archivo';
    }
    if (msg.contains('Bucket not found')) {
      return 'Error de almacenamiento';
    }

    // Database errors
    if (msg.contains('duplicate key') || msg.contains('unique constraint')) {
      return 'Este registro ya existe';
    }
    if (msg.contains('foreign key')) {
      return 'No se puede eliminar, hay datos relacionados';
    }

    // Stripe errors
    if (msg.contains('StripeException')) {
      return 'Error en el pago';
    }

    // Generic cleanup
    if (msg.startsWith('Exception: ')) {
      return msg.replaceFirst('Exception: ', '');
    }

    // Truncate if too long
    if (msg.length > 100) {
      return '${msg.substring(0, 97)}...';
    }

    return msg;
  }
}
