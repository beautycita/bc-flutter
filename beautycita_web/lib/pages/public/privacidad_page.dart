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
                Text('Ultima actualizacion: 10 de abril de 2026',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                const SizedBox(height: 32),
                _section('Responsable',
                    'BeautyCita, con domicilio en Jalisco, Mexico, es responsable del tratamiento de sus datos personales conforme a la Ley Federal de Proteccion de Datos Personales en Posesion de los Particulares (LFPDPPP).'),
                _section('Datos que Recopilamos',
                    'Recopilamos los siguientes datos personales:\n'
                    '- Nombre completo\n'
                    '- Numero de telefono\n'
                    '- Correo electronico\n'
                    '- Ubicacion (para encontrar salones cercanos)\n'
                    '- Historial de reservas\n'
                    '- Informacion de pago (procesada por Stripe, no almacenada por nosotros)\n\n'
                    'Para salones, adicionalmente:\n'
                    '- RFC y datos fiscales\n'
                    '- CLABE interbancaria\n'
                    '- Informacion del negocio'),
                _section('Finalidad del Tratamiento',
                    'Sus datos personales seran utilizados para:\n'
                    '- Crear y administrar su cuenta\n'
                    '- Facilitar la reserva de servicios de belleza\n'
                    '- Procesar pagos y emitir comprobantes fiscales (CFDI)\n'
                    '- Enviar confirmaciones y recordatorios de citas\n'
                    '- Cumplir con obligaciones fiscales ante el SAT\n'
                    '- Mejorar nuestros servicios mediante analisis anonimizados'),
                _section('Transferencia de Datos',
                    'Sus datos podran ser compartidos con:\n'
                    '- El salon de belleza donde realice su reserva (nombre, telefono)\n'
                    '- Procesadores de pago (Stripe) para completar transacciones\n'
                    '- Autoridades fiscales (SAT) conforme a la legislacion vigente\n\n'
                    'No vendemos ni compartimos sus datos con terceros para fines publicitarios.'),
                _section('Medidas de Seguridad',
                    'Implementamos medidas de seguridad tecnicas, administrativas y fisicas para proteger sus datos, incluyendo:\n'
                    '- Cifrado en transito (TLS/SSL)\n'
                    '- Control de acceso basado en roles (RLS)\n'
                    '- Autenticacion segura\n'
                    '- Respaldos cifrados diarios'),
                _section('Derechos ARCO',
                    'Usted tiene derecho a Acceder, Rectificar, Cancelar u Oponerse al tratamiento de sus datos personales (derechos ARCO). Para ejercer estos derechos, envie su solicitud a soporte@beautycita.com con:\n'
                    '- Nombre completo\n'
                    '- Descripcion del derecho que desea ejercer\n'
                    '- Identificacion oficial\n\n'
                    'Responderemos en un plazo maximo de 20 dias habiles.'),
                _section('Cookies y Tecnologias de Rastreo',
                    'Nuestra plataforma web utiliza cookies estrictamente necesarias para el funcionamiento del servicio. No utilizamos cookies de rastreo publicitario ni de terceros.'),
                _section('Cambios al Aviso de Privacidad',
                    'Nos reservamos el derecho de modificar este aviso de privacidad. Cualquier cambio sera notificado a traves de la Plataforma o por correo electronico.'),
                _section('Contacto',
                    'Para dudas o solicitudes relacionadas con sus datos personales:\n\n'
                    'Email: soporte@beautycita.com\n'
                    'Telefono: +52 (720) 677-7800\n'
                    'Domicilio: Jalisco, Mexico'),
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
