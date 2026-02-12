import 'package:flutter/material.dart';
import 'package:beautycita/config/theme.dart';

/// Global toast service for showing error and success messages
/// Uses a GlobalKey to access ScaffoldMessenger from anywhere
class ToastService {
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Show an error toast at the top of the screen
  static void showError(String message) {
    _show(
      message: message,
      backgroundColor: Colors.red.shade600,
      icon: Icons.error_outline_rounded,
    );
  }

  /// Show a success toast at the top of the screen
  static void showSuccess(String message) {
    _show(
      message: message,
      backgroundColor: Colors.green.shade600,
      icon: Icons.check_circle_outline_rounded,
    );
  }

  /// Show an info toast at the top of the screen
  static void showInfo(String message) {
    _show(
      message: message,
      backgroundColor: BeautyCitaTheme.primaryRose,
      icon: Icons.info_outline_rounded,
    );
  }

  /// Show a warning toast at the top of the screen
  static void showWarning(String message) {
    _show(
      message: message,
      backgroundColor: Colors.orange.shade600,
      icon: Icons.warning_amber_rounded,
    );
  }

  static void _show({
    required String message,
    required Color backgroundColor,
    required IconData icon,
  }) {
    final messenger = messengerKey.currentState;
    if (messenger == null) {
      debugPrint('[ToastService] No ScaffoldMessenger available: $message');
      return;
    }

    // Clear any existing snackbars
    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(
          top: 16,
          left: 16,
          right: 16,
          bottom: 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 4),
        dismissDirection: DismissDirection.up,
      ),
    );
  }

  /// Convert common error types to user-friendly messages
  static String friendlyError(Object error) {
    final msg = error.toString();

    // Network errors
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
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

    // Return original if no match, but truncate if too long
    if (msg.length > 100) {
      return '${msg.substring(0, 97)}...';
    }

    return msg;
  }
}
