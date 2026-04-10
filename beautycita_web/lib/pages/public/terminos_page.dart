import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Public terms of service page — accessible without authentication.
class TerminosPage extends StatelessWidget {
  const TerminosPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Terminos y Condiciones'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Terminos y Condiciones de Uso',
                    style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Ultima actualizacion: 10 de abril de 2026',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                const SizedBox(height: 32),
                _section('1. Aceptacion de los Terminos',
                    'Al acceder y utilizar la plataforma BeautyCita ("la Plataforma"), usted acepta estos Terminos y Condiciones en su totalidad. Si no esta de acuerdo con alguna parte, no utilice la Plataforma.'),
                _section('2. Descripcion del Servicio',
                    'BeautyCita es una plataforma tecnologica que conecta a usuarios con salones de belleza y profesionales de servicios esteticos. BeautyCita facilita la reserva de citas pero no es proveedor directo de los servicios de belleza.'),
                _section('3. Registro y Cuenta',
                    'Para utilizar ciertos servicios, debera crear una cuenta proporcionando informacion veraz y actualizada. Usted es responsable de mantener la confidencialidad de sus credenciales de acceso.'),
                _section('4. Reservas y Pagos',
                    'Las reservas realizadas a traves de la Plataforma constituyen un acuerdo entre el usuario y el salon. Los pagos se procesan de forma segura a traves de proveedores certificados (Stripe). BeautyCita no almacena datos de tarjetas de credito.'),
                _section('5. Cancelaciones y Reembolsos',
                    'Las politicas de cancelacion varian por salon. En general, las cancelaciones con mas de 2 horas de anticipacion son gratuitas. Los reembolsos se acreditan al saldo de la cuenta o al metodo de pago original segun corresponda.'),
                _section('6. Obligaciones del Usuario',
                    'El usuario se compromete a: (a) proporcionar informacion veraz, (b) no utilizar la Plataforma para fines ilicitos, (c) respetar las citas reservadas, (d) tratar con respeto al personal de los salones.'),
                _section('7. Obligaciones de los Salones',
                    'Los salones registrados se comprometen a: (a) cumplir con todas las leyes y regulaciones aplicables, (b) mantener sus precios y disponibilidad actualizados, (c) cumplir con los servicios reservados, (d) cumplir con obligaciones fiscales (SAT).'),
                _section('8. Comisiones y Facturacion',
                    'BeautyCita opera bajo un modelo de comision por transaccion. Las retenciones de ISR e IVA se realizan conforme a los articulos 113-A de LISR y 18-J de LIVA. Los salones reciben CFDI por las retenciones efectuadas.'),
                _section('9. Propiedad Intelectual',
                    'Todo el contenido de la Plataforma, incluyendo pero no limitado a disenos, logotipos, textos y software, es propiedad de BeautyCita o sus licenciantes y esta protegido por leyes de propiedad intelectual.'),
                _section('10. Limitacion de Responsabilidad',
                    'BeautyCita no sera responsable por: (a) la calidad de los servicios prestados por los salones, (b) danos indirectos o consecuenciales, (c) interrupciones del servicio por causas de fuerza mayor.'),
                _section('11. Modificaciones',
                    'BeautyCita se reserva el derecho de modificar estos terminos en cualquier momento. Los cambios seran notificados a traves de la Plataforma. El uso continuado despues de los cambios constituye aceptacion.'),
                _section('12. Ley Aplicable',
                    'Estos terminos se rigen por las leyes de los Estados Unidos Mexicanos. Cualquier controversia sera sometida a los tribunales competentes de Jalisco, Mexico.'),
                _section('13. Contacto',
                    'Para preguntas sobre estos terminos, contactenos en soporte@beautycita.com o al +52 (720) 677-7800.'),
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
