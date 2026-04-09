/// Maps raw exceptions (especially Supabase/Postgrest errors) to
/// user-friendly Spanish messages for display in SnackBars and error widgets.
String friendlyError(Object e) {
  final msg = e.toString();

  // Supabase / Postgrest error codes
  if (msg.contains('PGRST301') || msg.contains('JWT expired')) {
    return 'Tu sesion ha expirado. Inicia sesion de nuevo.';
  }
  if (msg.contains('PGRST204') || msg.contains('column') && msg.contains('does not exist')) {
    return 'Error de configuracion del servidor. Contacta soporte.';
  }
  if (msg.contains('42501') || msg.contains('permission denied') || msg.contains('new row violates row-level security')) {
    return 'No tienes permisos para realizar esta accion.';
  }
  if (msg.contains('23505') || msg.contains('duplicate key')) {
    return 'Este registro ya existe.';
  }
  if (msg.contains('23503') || msg.contains('foreign key')) {
    return 'No se puede completar: hay datos relacionados.';
  }
  if (msg.contains('23502') || msg.contains('not-null')) {
    return 'Faltan campos obligatorios.';
  }
  if (msg.contains('PGRST116')) {
    return 'No se encontro el registro solicitado.';
  }
  if (msg.contains('FetchError') || msg.contains('SocketException') || msg.contains('NetworkException')) {
    return 'Sin conexion a internet. Verifica tu red.';
  }
  if (msg.contains('AuthException') || msg.contains('invalid_grant') || msg.contains('Invalid login')) {
    return 'Error de autenticacion. Intenta de nuevo.';
  }
  if (msg.contains('StorageException') || msg.contains('Payload too large')) {
    return 'El archivo es demasiado grande.';
  }
  if (msg.contains('timeout') || msg.contains('TimeoutException')) {
    return 'La solicitud tardo demasiado. Intenta de nuevo.';
  }

  // Fallback: generic message (no raw exception leak)
  return 'Ocurrio un error inesperado. Intenta de nuevo.';
}
