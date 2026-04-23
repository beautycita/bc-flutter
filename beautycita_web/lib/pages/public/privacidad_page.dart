import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Public privacy policy page — accessible without authentication.
class PrivacidadPage extends StatelessWidget {
  const PrivacidadPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Aviso de Privacidad'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aviso de Privacidad Integral',
                    style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Ultima actualizacion: 19 de abril de 2026',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                const SizedBox(height: 32),

                _section('Responsable del Tratamiento',
                    'BEAUTYCITA, S.A. de C.V.\n'
                    'RFC: BEA260313MI8\n'
                    'Domicilio: Avenida Manuel Corona, Alazan 11A, C.P. 48290, Jalisco, Mexico\n'
                    'Contacto de privacidad: legal@beautycita.com\n'
                    'Telefono: +52 (720) 677-7800\n\n'
                    'BEAUTYCITA es responsable del tratamiento de sus datos personales conforme a la Ley Federal de Proteccion de Datos Personales en Posesion de los Particulares (LFPDPPP) y su Reglamento.'),

                _section('Datos Personales que Recopilamos',
                    'Recopilamos las siguientes categorias de datos personales:\n\n'
                    'Datos de identificacion:\n'
                    '  - Nombre completo\n'
                    '  - Correo electronico\n'
                    '  - Numero de telefono (opcional, para verificacion y comunicaciones)\n'
                    '  - Foto de perfil (opcional)\n\n'
                    'Datos de ubicacion:\n'
                    '  - Coordenadas GPS (solo con su permiso, para encontrar salones cercanos)\n'
                    '  - Direccion de domicilio (opcional, para calcular tiempos de traslado)\n\n'
                    'Datos transaccionales:\n'
                    '  - Historial de reservas y servicios\n'
                    '  - Metodos de pago utilizados (solo ultimos 4 digitos de tarjeta)\n'
                    '  - Montos de transacciones, comisiones y retenciones fiscales\n'
                    '  - Saldo de credito en la Plataforma\n\n'
                    'Datos de comunicacion:\n'
                    '  - Mensajes enviados al asistente virtual (Aphrodite), soporte, y salones\n'
                    '  - Historial de conversaciones\n\n'
                    'Datos tecnicos:\n'
                    '  - Token de notificaciones push (Firebase Cloud Messaging)\n'
                    '  - Modelo de dispositivo, sistema operativo, version de la aplicacion\n'
                    '  - Reportes de errores anonimizados (Sentry)\n\n'
                    'Datos accedidos con permiso explicito (procesados localmente, no enviados a nuestros servidores salvo cuando el usuario lo decida):\n'
                    '  - Lista de contactos: con su permiso, leemos los nombres y numeros de telefono de sus contactos para identificar cuales corresponden a salones registrados en BeautyCita. El procesamiento ocurre en su dispositivo. Solo las coincidencias (no la lista completa) se cachean localmente. Puede revocar el permiso en cualquier momento desde los ajustes del sistema.\n'
                    '  - Camara: solo cuando usted captura una foto desde la aplicacion (avatar de perfil, portafolio del salon, fotos antes/despues). Las fotos elegidas para subir se almacenan en nuestros servidores; las descartadas no.\n'
                    '  - Fotos / galeria: solo cuando usted selecciona una imagen para subir (avatar, portafolio, foto de soporte, evidencia en disputas). Solo la imagen elegida se transfiere.\n\n'
                    'Para salones y profesionales, adicionalmente:\n'
                    '  - RFC (Registro Federal de Contribuyentes)\n'
                    '  - Regimen fiscal\n'
                    '  - CLABE interbancaria (via Stripe Connect)\n'
                    '  - Informacion del negocio (nombre, direccion, horarios, servicios)\n'
                    '  - Fotos de portafolio y del establecimiento'),

                _section('Datos que NO Recopilamos',
                    '  - Datos biometricos: La autenticacion biometrica (huella digital, reconocimiento facial) se procesa exclusivamente en el hardware seguro de su dispositivo (Secure Enclave / TEE). BeautyCita nunca recibe, transmite ni almacena datos biometricos.\n\n'
                    '  - Datos completos de tarjeta: Los datos de pago son procesados directamente por Stripe (certificado PCI-DSS Nivel 1). Solo conservamos los ultimos 4 digitos como referencia.\n\n'
                    '  - Lista de contactos en nuestros servidores: Aunque podemos leer su lista de contactos en su dispositivo (con permiso explicito) para identificar coincidencias con salones registrados, la lista completa nunca se transmite a nuestros servidores; el procesamiento es local. Vea la seccion anterior "Datos accedidos con permiso explicito" para mas detalles.\n\n'
                    '  - Cookies de rastreo: No utilizamos cookies publicitarias ni de terceros para seguimiento.'),

                _section('Finalidades del Tratamiento',
                    'Finalidades primarias (necesarias para el servicio):\n\n'
                    '  a) Crear y administrar su cuenta de usuario\n'
                    '  b) Facilitar la busqueda y reserva de servicios de belleza\n'
                    '  c) Procesar pagos y emitir recibos\n'
                    '  d) Realizar retenciones de ISR e IVA conforme a la legislacion fiscal (Art. 113-A LISR, Art. 18-J LIVA)\n'
                    '  e) Emitir CFDI por retenciones efectuadas\n'
                    '  f) Enviar confirmaciones, recordatorios y actualizaciones de citas\n'
                    '  g) Proporcionar soporte al cliente y asistencia virtual\n'
                    '  h) Cumplir con obligaciones ante el SAT (Art. 30-B CFF)\n'
                    '  i) Prevenir fraude y actividades ilicitas\n\n'
                    'Finalidades secundarias (puede oponerse sin afectar el servicio):\n\n'
                    '  a) Mejorar nuestros servicios mediante analisis anonimizados de uso\n'
                    '  b) Personalizar recomendaciones de salones y servicios\n'
                    '  c) Enviar comunicaciones promocionales (puede desactivarse en Ajustes)\n\n'
                    'Si desea oponerse a las finalidades secundarias, envie un correo a legal@beautycita.com con el asunto "Negativa finalidades secundarias".'),

                _section('Transferencias de Datos',
                    'Sus datos pueden ser compartidos con los siguientes destinatarios:\n\n'
                    'Transferencias nacionales:\n'
                    '  - Salones de belleza: Nombre y telefono del usuario para confirmar y atender la cita\n'
                    '  - Servicio de Administracion Tributaria (SAT): Informacion fiscal conforme a la ley\n\n'
                    'Transferencias internacionales (con clausulas contractuales estandar, Art. 36 LFPDPPP):\n'
                    '  - Stripe (EE.UU.): Procesamiento de pagos\n'
                    '  - Google LLC (EE.UU.): Autenticacion OAuth y servicios de ubicacion\n'
                    '  - Apple Inc. (EE.UU.): Autenticacion OAuth\n'
                    '  - Firebase / Google Cloud (EE.UU.): Notificaciones push\n'
                    '  - Sentry (EE.UU.): Reportes de errores anonimizados (sin datos personales identificables)\n'
                    '  - OpenAI (EE.UU.): Procesamiento de mensajes del asistente virtual (sin datos fiscales ni de pago)\n'
                    '  - Cloudflare (global): Almacenamiento de medios (fotos de portafolio)\n'
                    '  - Meta / WhatsApp (EE.UU.): Comunicaciones de negocio (numero de telefono)\n'
                    '  - LightX (India): Procesamiento de IA para transformaciones de imagen del estudio virtual. Solo la imagen seleccionada por el usuario se transmite; no se envian datos de identificacion personal ni datos de pago. LightX no retiene imagenes para entrenamiento de modelos.\n\n'
                    'No vendemos, rentamos ni compartimos sus datos personales con terceros para fines publicitarios, de mercadotecnia o perfilamiento comercial.'),

                _section('Medidas de Seguridad',
                    'Implementamos las siguientes medidas para proteger sus datos:\n\n'
                    'Tecnicas:\n'
                    '  - Cifrado en transito (TLS/SSL) para todas las comunicaciones\n'
                    '  - Control de acceso basado en roles (Row Level Security) en la base de datos\n'
                    '  - Autenticacion con tokens JWT de corta duracion\n'
                    '  - Operaciones financieras atomicas con bloqueo de fila (prevencion de condiciones de carrera)\n'
                    '  - Respaldos diarios cifrados con almacenamiento redundante\n'
                    '  - Claves API segregadas (cliente vs servidor)\n\n'
                    'Administrativas:\n'
                    '  - Acceso a datos personales restringido a personal autorizado\n'
                    '  - Registro de auditoria para accesos a datos fiscales (5 anos)\n'
                    '  - Revision periodica de seguridad del codigo fuente\n\n'
                    'Fisicas:\n'
                    '  - Infraestructura alojada en centros de datos con certificacion de seguridad\n'
                    '  - Acceso fisico restringido a servidores de produccion'),

                _section('Derechos ARCO',
                    'Conforme a la LFPDPPP, usted tiene derecho a:\n\n'
                    'Acceso (A): Conocer que datos personales tenemos y como los usamos.\n\n'
                    'Rectificacion (R): Corregir datos inexactos o incompletos.\n\n'
                    'Cancelacion (C): Solicitar la eliminacion de sus datos cuando considere que no se requieren para las finalidades establecidas. Puede iniciar la eliminacion desde Ajustes > Eliminar cuenta en la aplicacion.\n\n'
                    'Oposicion (O): Oponerse al tratamiento de sus datos para finalidades especificas.\n\n'
                    'Para ejercer sus derechos ARCO, envie su solicitud a legal@beautycita.com incluyendo:\n'
                    '  - Nombre completo\n'
                    '  - Correo electronico asociado a su cuenta\n'
                    '  - Descripcion clara del derecho que desea ejercer\n'
                    '  - Copia de identificacion oficial (INE/pasaporte)\n\n'
                    'Plazo de respuesta: 20 dias habiles a partir de la recepcion de la solicitud completa.\n\n'
                    'Excepciones a la eliminacion (datos retenidos por obligacion legal):\n'
                    '  - Registros fiscales y de retenciones: 5 anos (Art. 30 CFF)\n'
                    '  - Historial de transacciones con desglose fiscal: 5 anos\n'
                    '  - RFC y regimen fiscal de proveedores: 5 anos\n'
                    '  - Registros de acceso del SAT: 5 anos\n'
                    '  - Historial de soporte: 2 anos\n'
                    '  - Demas datos personales: eliminacion permanente en 30 dias'),

                _section('Notificaciones y Comunicaciones',
                    'La Plataforma envia las siguientes notificaciones:\n\n'
                    '  a) Confirmaciones y recordatorios de citas (push y/o WhatsApp)\n'
                    '  b) Actualizaciones de estado de reserva (confirmada, cancelada)\n'
                    '  c) Notificaciones de pago (recibido, fallido, reembolsado)\n'
                    '  d) Alertas del sistema y mantenimiento\n\n'
                    'Las notificaciones push se envian a traves de Firebase Cloud Messaging (Google). Puede desactivarlas en cualquier momento desde los ajustes de la aplicacion o del dispositivo.\n\n'
                    'Las comunicaciones por WhatsApp se envian al numero registrado. Puede optar por no recibir mensajes promocionales respondiendo "BAJA" a cualquier mensaje.'),

                _section('Analitica y Monitoreo',
                    'Utilizamos las siguientes herramientas de analitica:\n\n'
                    'Sentry (monitoreo de errores):\n'
                    '  - Recopila reportes de errores tecnicos anonimizados\n'
                    '  - NO recopila datos personales identificables (sendDefaultPii = false)\n'
                    '  - Muestreo del 20% en produccion\n'
                    '  - Proposito: estabilidad y rendimiento de la aplicacion\n\n'
                    'Analitica interna:\n'
                    '  - Pantallas visitadas, acciones realizadas (reservar, buscar, cancelar)\n'
                    '  - Datos agregados y anonimizados\n'
                    '  - Retencion: 12 meses, luego anonimizacion permanente\n'
                    '  - Proposito: mejora del servicio\n\n'
                    'No utilizamos:\n'
                    '  - Google Analytics ni servicios de analitica de terceros\n'
                    '  - Pixeles de retargeting o seguimiento publicitario\n'
                    '  - Cookies de seguimiento entre sitios\n'
                    '  - Redes de publicidad de terceros'),

                _section('Analisis de Comportamiento y Perfilado',
                    'BeautyCita analiza patrones de uso de la plataforma para mejorar el servicio, '
                    'prevenir fraude y personalizar la experiencia. Este analisis incluye:\n\n'
                    'Datos que analizamos:\n'
                    '  - Frecuencia y patrones de reservas\n'
                    '  - Categorias de servicios utilizados\n'
                    '  - Patrones geograficos de uso (a nivel ciudad, no coordenadas exactas)\n'
                    '  - Interacciones con la plataforma (busquedas, invitaciones, resenas)\n'
                    '  - Patrones de gasto y metodos de pago preferidos\n\n'
                    'Lo que generamos:\n'
                    '  - Puntuaciones de comportamiento (traits) que describen sus habitos de uso\n'
                    '  - Segmentos de usuario para personalizar recomendaciones\n'
                    '  - Senales de riesgo para prevencion de fraude\n\n'
                    'Lo que NO hacemos:\n'
                    '  - No inferimos datos sensibles (salud, preferencias sexuales, religion, origen etnico, opiniones politicas)\n'
                    '  - No tomamos decisiones automatizadas que afecten sus derechos sin revision humana\n'
                    '  - No compartimos perfiles individuales con terceros\n'
                    '  - No utilizamos estos datos para publicidad de terceros\n\n'
                    'Su control:\n'
                    '  - Puede desactivar el analisis de comportamiento en cualquier momento desde '
                    'Ajustes > Privacidad > "Analisis de actividad" en la aplicacion\n'
                    '  - Al desactivar, detenemos la recopilacion y eliminamos sus puntuaciones dentro de 30 dias\n'
                    '  - Los registros transaccionales (reservas, pagos) se mantienen por obligacion legal independiente\n'
                    '  - Puede solicitar acceso a su perfil de comportamiento via soporte@beautycita.com (Art. 27 LFPDPPP)\n\n'
                    'Base legal: Consentimiento implicito para datos no sensibles (Art. 8 LFPDPPP). '
                    'Interes legitimo para prevencion de fraude (Art. 12 Reglamento LFPDPPP).'),

                _section('Programa QR de Registro',
                    'Si usted escanea un codigo QR interno en un salon participante y completa el formulario de registro, BeautyCita almacena los siguientes datos proporcionados por usted:\n\n'
                    '  - Nombre completo\n'
                    '  - Numero telefonico (verificado por codigo OTP via WhatsApp)\n'
                    '  - Servicio solicitado y notas opcionales\n'
                    '  - Identificador de dispositivo (UUID generado localmente en su navegador)\n'
                    '  - Hashes anonimos de direccion IP y navegador (capturados unicamente para prevencion de fraude; no reversibles despues de 30 dias por rotacion diaria de sal criptografica)\n\n'
                    'Proposito: completar su cita en el salon donde realizo el registro. BeautyCita actua como procesador de estos datos en nombre del salon.\n\n'
                    'Base legal del programa QR:\n'
                    '  - Consentimiento expreso (Art. 8 LFPDPPP) — usted marca casillas de aviso de privacidad, terminos y cookies antes de enviar el formulario\n'
                    '  - Principio de finalidad y minimizacion (Art. 11 LFPDPPP) — solo capturamos datos necesarios para completar su cita y prevenir fraude; no hay uso secundario\n\n'
                    'Sus derechos ARCO permanecen vigentes. Para ejercerlos o eliminar sus datos, escribanos a soporte@beautycita.com. Eliminacion en plazo maximo de 30 dias.\n\n'
                    'Retencion: los registros se mantienen mientras la cuenta este activa, mas el plazo legal aplicable por CFF Art. 30 cuando aplica.'),

                _section('Menores de Edad',
                    'La Plataforma esta dirigida a personas mayores de 18 anos. No recopilamos intencionalmente datos de menores de edad. Si detectamos que un menor ha creado una cuenta, procederemos a eliminarla y sus datos asociados.'),

                _section('Cambios al Aviso de Privacidad',
                    'Nos reservamos el derecho de modificar este aviso de privacidad. Cualquier cambio sera notificado a traves de:\n\n'
                    '  a) Notificacion push en la aplicacion\n'
                    '  b) Correo electronico al email registrado\n'
                    '  c) Publicacion en beautycita.com/privacidad\n\n'
                    'La fecha de ultima actualizacion se indica al inicio de este documento.'),

                _section('Contacto y Quejas',
                    'Para dudas, solicitudes ARCO, o quejas relacionadas con el tratamiento de sus datos personales:\n\n'
                    'Email de privacidad: legal@beautycita.com\n'
                    'Email de soporte: soporte@beautycita.com\n'
                    'Telefono: +52 (720) 677-7800\n'
                    'WhatsApp: +52 (720) 677-7800\n'
                    'Domicilio: Avenida Manuel Corona, Alazan 11A, C.P. 48290, Jalisco, Mexico\n\n'
                    'Si considera que su derecho a la proteccion de datos personales ha sido vulnerado, puede presentar una queja ante la Secretaria de Anticorrupcion y Buen Gobierno (SABG), autoridad garante en materia de proteccion de datos personales.'),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF444444))),
        ],
      ),
    );
  }
}
