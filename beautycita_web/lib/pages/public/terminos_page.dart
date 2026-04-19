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
                Text('Ultima actualizacion: 19 de abril de 2026',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                const SizedBox(height: 12),
                Text('BEAUTYCITA, S.A. de C.V. (RFC: BEA260313MI8)\nAvenida Manuel Corona, Alazan 11A, C.P. 48290, Jalisco, Mexico',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                const SizedBox(height: 32),

                _section('1. Aceptacion de los Terminos',
                    'Al descargar, instalar, o utilizar la plataforma BeautyCita ("la Plataforma"), incluyendo la aplicacion movil y el sitio web beautycita.com, usted acepta estos Terminos y Condiciones en su totalidad. Si no esta de acuerdo con alguna disposicion, no utilice la Plataforma. El uso continuado despues de cualquier modificacion constituye su aceptacion de los terminos actualizados.'),

                _section('2. Descripcion del Servicio',
                    'BeautyCita es un agente inteligente de reservas que conecta a usuarios con salones de belleza y profesionales de servicios esteticos en Mexico. La Plataforma:\n\n'
                    '  a) Facilita la busqueda, seleccion y reserva de servicios de belleza\n'
                    '  b) Procesa pagos de forma segura entre usuarios y proveedores\n'
                    '  c) Realiza retenciones fiscales conforme a la legislacion mexicana\n'
                    '  d) Ofrece herramientas de gestion para salones registrados\n'
                    '  e) Proporciona un asistente virtual de belleza (Aphrodite) y soporte al cliente\n\n'
                    'BeautyCita NO es proveedor directo de servicios de belleza. Los servicios son prestados exclusivamente por los salones y profesionales registrados, quienes son responsables de la calidad, seguridad e higiene de los mismos.'),

                _section('3. Registro y Cuenta',
                    'Para utilizar la Plataforma se requiere crear una cuenta. El registro se realiza mediante:\n\n'
                    '  a) Autenticacion biometrica del dispositivo (huella digital o reconocimiento facial)\n'
                    '  b) Inicio de sesion con Google o Apple\n'
                    '  c) Correo electronico y contrasena\n\n'
                    'La autenticacion biometrica se procesa exclusivamente en el dispositivo del usuario. BeautyCita nunca recibe, transmite ni almacena datos biometricos en sus servidores.\n\n'
                    'El usuario es responsable de mantener la seguridad de su cuenta y de toda actividad realizada bajo sus credenciales. Notifique inmediatamente a soporte@beautycita.com si detecta uso no autorizado.'),

                _section('4. Reservas',
                    'Las reservas realizadas a traves de la Plataforma constituyen un acuerdo entre el usuario y el salon. Al confirmar una reserva, el usuario se compromete a:\n\n'
                    '  a) Asistir a la cita en la fecha y hora indicadas\n'
                    '  b) Notificar cancelaciones con la anticipacion requerida\n'
                    '  c) Proporcionar informacion veraz sobre el servicio solicitado\n\n'
                    'Los salones pueden requerir un deposito configurable (porcentaje del precio del servicio) como garantia de reserva. El deposito se aplica al costo total del servicio.'),

                _section('5. Pagos y Procesamiento',
                    'Los pagos se procesan a traves de Stripe, procesador certificado PCI-DSS Nivel 1. BeautyCita nunca almacena datos completos de tarjetas de credito o debito; unicamente se conservan los ultimos 4 digitos para referencia.\n\n'
                    'Metodos de pago aceptados:\n'
                    '  a) Tarjeta de credito o debito (via Stripe)\n'
                    '  b) OXXO (pago en efectivo en tienda)\n'
                    '  c) Saldo BeautyCita (credito en plataforma)\n'
                    '  d) Pago directo en efectivo al salon\n\n'
                    'Los reembolsos se acreditan exclusivamente al saldo de la cuenta del usuario dentro de la Plataforma, no al metodo de pago original. El saldo puede utilizarse para futuras reservas o compras.'),

                _section('6. Cancelaciones y Reembolsos',
                    'La politica de cancelacion es configurable por cada salon. Las reglas generales son:\n\n'
                    'Cancelacion gratuita por el usuario: Si el usuario cancela con la anticipacion establecida por el salon (por defecto, 24 horas antes), recibe un reembolso del precio menos la comision de plataforma del 3%, acreditado a su saldo en la Plataforma. La comision retenida cubre el procesamiento de pago y operacion de la cita.\n\n'
                    'Cancelacion tardia: Si el usuario cancela dentro del periodo no reembolsable y el salon requiere deposito, el deposito se pierde. El monto restante se reembolsa al saldo, tambien menos la comision del 3%.\n\n'
                    'Cancelacion por el salon: Si el salon cancela la cita, el usuario recibe un reembolso COMPLETO del precio acreditado a su saldo. La comision (3%) la asume el salon como adeudo, no se descuenta del usuario.\n\n'
                    'No se realizan devoluciones a tarjetas de credito o cuentas bancarias. Todos los reembolsos se procesan como credito en la Plataforma (saldo).'),

                _section('7. Comisiones',
                    'BeautyCita opera bajo el siguiente modelo de comisiones:\n\n'
                    '  a) Reservas del marketplace: 3% del precio del servicio\n'
                    '  b) Reservas directas del salon: 0% (sin comision)\n'
                    '  c) Venta de productos (POS): 10% del precio del producto\n\n'
                    'Las comisiones se deducen automaticamente del pago al proveedor. Los salones reciben un desglose detallado de cada transaccion incluyendo comision, retenciones fiscales y monto neto.'),

                _section('8. Retenciones Fiscales',
                    'Conforme a la legislacion fiscal mexicana, BeautyCita actua como plataforma tecnologica intermediaria y esta obligada a realizar las siguientes retenciones:\n\n'
                    'Para proveedores con RFC registrado:\n'
                    '  - ISR (Impuesto Sobre la Renta): 2.5% del monto bruto (Art. 113-A LISR)\n'
                    '  - IVA (Impuesto al Valor Agregado): 8% de la porcion de IVA (Art. 18-J LIVA)\n\n'
                    'Para proveedores sin RFC registrado:\n'
                    '  - ISR: 20% del monto bruto\n'
                    '  - IVA: 16% de la porcion de IVA\n\n'
                    'BeautyCita emite CFDI (Comprobante Fiscal Digital por Internet) por todas las retenciones efectuadas. Los registros fiscales se conservan por 5 anos conforme al Articulo 30 del Codigo Fiscal de la Federacion.\n\n'
                    'La Plataforma cumple con el Articulo 30-B del Codigo Fiscal, proporcionando al SAT acceso autenticado a la informacion de transacciones y retenciones.'),

                _section('9. Saldo y Sistema de Creditos',
                    'La Plataforma mantiene un sistema de credito interno ("Saldo") asociado a cada cuenta de usuario:\n\n'
                    '  a) Los reembolsos por cancelaciones se acreditan al Saldo\n'
                    '  b) Las tarjetas de regalo se cargan al Saldo\n'
                    '  c) El programa de lealtad acumula puntos canjeables por Saldo\n'
                    '  d) El Saldo puede utilizarse para pagar servicios y productos\n\n'
                    'El Saldo no es transferible entre cuentas, no genera intereses, y no es canjeable por efectivo. En caso de eliminacion de cuenta, el Saldo restante se pierde despues de 30 dias.'),

                _section('10. Obligaciones del Usuario',
                    'El usuario se compromete a:\n\n'
                    '  a) Proporcionar informacion veraz y mantenerla actualizada\n'
                    '  b) No utilizar la Plataforma para fines ilicitos o fraudulentos\n'
                    '  c) Respetar las citas reservadas y las politicas de cancelacion\n'
                    '  d) Tratar con respeto al personal de los salones\n'
                    '  e) No manipular, modificar o hacer ingenieria inversa de la Plataforma\n'
                    '  f) No crear multiples cuentas para evadir restricciones\n'
                    '  g) No enviar contenido inapropiado a traves del sistema de mensajeria'),

                _section('11. Obligaciones de los Salones',
                    'Los salones y profesionales registrados se comprometen a:\n\n'
                    '  a) Cumplir con todas las leyes, regulaciones sanitarias y fiscales aplicables\n'
                    '  b) Mantener precios, disponibilidad y servicios actualizados\n'
                    '  c) Cumplir con los servicios reservados segun lo publicado\n'
                    '  d) Registrar su RFC ante la Plataforma para recibir tasas preferenciales de retencion\n'
                    '  e) Completar el proceso de verificacion (servicios, horarios, cuenta Stripe, RFC)\n'
                    '  f) Mantener estandares de calidad e higiene en la prestacion de servicios\n'
                    '  g) Responder a las comunicaciones de clientes en tiempo razonable'),

                _section('11 bis. Cuenta Bancaria de Beneficiario y Pagos',
                    'Para los salones y profesionales (el "Establecimiento") que reciban pagos a traves de la Plataforma:\n\n'
                    '§ 1. Identidad del Beneficiario. Al registrarse, el Establecimiento proporciona (i) el nombre completo del titular de la cuenta bancaria destinada a recibir pagos ("Nombre del Beneficiario") y (ii) el RFC del mismo titular. El Establecimiento declara, bajo protesta de decir verdad, que ambos datos corresponden de manera inequivoca a la persona fisica o moral titular de la cuenta bancaria designada.\n\n'
                    '§ 2. Correspondencia Obligatoria. La Plataforma unicamente realizara pagos, dispersiones o transferencias a cuentas cuyo titular coincida con la Identidad del Beneficiario registrada. La Plataforma se reserva el derecho de verificar por cualquier medio, incluyendo cotejo con la institucion bancaria receptora o con el SAT, que la cuenta bancaria corresponda a los datos declarados.\n\n'
                    '§ 3. Suspension Automatica por Modificacion. Cualquier cambio en el Nombre del Beneficiario, el RFC o la CLABE suspendera inmediatamente todos los pagos pendientes y programados, sin necesidad de notificacion adicional, hasta que un administrador de la Plataforma verifique y autorice expresamente la nueva informacion. La Plataforma no sera responsable por retrasos derivados de dicha suspension.\n\n'
                    '§ 4. Quejas de Terceros y Facultad de Cancelacion. Si cualquier tercero, incluyendo clientes, autoridades, instituciones financieras o titulares originales de la cuenta bancaria, presenta una queja que alegue que un pago fue realizado a una cuenta cuyo titular no corresponde a la Identidad del Beneficiario declarada, la Plataforma, a su entera discrecion y sin necesidad de demostrar la veracidad de la queja, podra cancelar la cuenta del Establecimiento en cualquier momento.\n\n'
                    '§ 5. Apelacion por Panel Arbitral. El Establecimiento podra apelar la cancelacion mediante solicitud por escrito a apelaciones@beautycita.com dentro de los diez (10) dias naturales siguientes a la notificacion. La apelacion sera resuelta por un Panel Arbitral integrado por tres (3) personas designadas por la Plataforma al momento de la controversia, ninguna de las cuales podra ser empleado directamente involucrado en la transaccion o queja. La resolucion sera final, inapelable y vinculante en terminos del articulo 1423 del Codigo de Comercio, con sede en la Ciudad de Mexico e idioma espanol. Las partes renuncian a cualquier recurso judicial distinto a la accion de nulidad prevista en el articulo 1457 del mismo Codigo.\n\n'
                    '§ 6. Consecuencias de la Cancelacion. Cancelada la cuenta del Establecimiento: (a) cualquier saldo a su favor sera remitido en su totalidad a la Plataforma como compensacion por gastos administrativos, de verificacion y resolucion de controversias, asi como posibles danos reputacionales; y (b) cualquier adeudo pendiente del Establecimiento frente a la Plataforma quedara extinguido en su totalidad. Dichas medidas constituyen compensacion integra y final respecto a esos rubros.\n\n'
                    '§ 7. Naturaleza Esencial. El Establecimiento reconoce haber leido y aceptado la presente clausula y su caracter de condicion esencial. La invalidez de cualquier disposicion de la misma no afectara la validez del resto del contrato ni de las demas disposiciones de la clausula.'),

                _section('12. Propiedad Intelectual',
                    'Todo el contenido de la Plataforma, incluyendo disenos, logotipos, interfaces, codigo fuente, algoritmos de recomendacion, modelos de IA (Aphrodite, Eros), textos y graficos, es propiedad exclusiva de BEAUTYCITA, S.A. de C.V. o sus licenciantes, y esta protegido por las leyes de propiedad intelectual de Mexico y tratados internacionales.\n\n'
                    'Los salones conservan la propiedad de su contenido (fotos de portafolio, descripciones de servicios) pero otorgan a BeautyCita una licencia no exclusiva para exhibirlo en la Plataforma.'),

                _section('13. Limitacion de Responsabilidad',
                    'BeautyCita no sera responsable por:\n\n'
                    '  a) La calidad, seguridad o resultado de los servicios prestados por los salones\n'
                    '  b) Danos directos, indirectos, incidentales o consecuenciales derivados del uso de la Plataforma\n'
                    '  c) Interrupciones del servicio por causas de fuerza mayor, mantenimiento programado o fallas de terceros\n'
                    '  d) Perdida de datos por uso inadecuado de credenciales por parte del usuario\n'
                    '  e) Disputas entre usuarios y salones respecto a la prestacion de servicios\n\n'
                    'La responsabilidad maxima de BeautyCita en cualquier caso se limita al monto de las comisiones cobradas en los ultimos 12 meses al usuario o salon afectado.'),

                _section('14. Resolucion de Disputas',
                    'En caso de controversia entre usuario y salon:\n\n'
                    '  a) Primera instancia: Mediacion a traves del equipo de soporte de BeautyCita\n'
                    '  b) Segunda instancia: Escalamiento a PROFECO (Procuraduria Federal del Consumidor)\n'
                    '  c) Tercera instancia: Tribunales competentes de Puerto Vallarta, Jalisco, Mexico\n\n'
                    'BeautyCita se reserva el derecho de suspender o cancelar cuentas que infrinjan estos terminos, con notificacion previa al usuario afectado.'),

                _section('15. Modificaciones',
                    'BeautyCita se reserva el derecho de modificar estos terminos en cualquier momento. Los cambios se notificaran a traves de:\n\n'
                    '  a) Notificacion push en la aplicacion\n'
                    '  b) Correo electronico al email registrado\n'
                    '  c) Aviso en el sitio web\n\n'
                    'El uso continuado de la Plataforma despues de la notificacion constituye aceptacion de los terminos modificados. Si no esta de acuerdo, debera dejar de utilizar la Plataforma y solicitar la eliminacion de su cuenta.'),

                _section('16. Ley Aplicable y Jurisdiccion',
                    'Estos terminos se rigen por las leyes de los Estados Unidos Mexicanos, incluyendo:\n\n'
                    '  - Ley Federal de Proteccion al Consumidor\n'
                    '  - Codigo Fiscal de la Federacion (Art. 30-B)\n'
                    '  - Ley del Impuesto Sobre la Renta (Art. 113-A)\n'
                    '  - Ley del Impuesto al Valor Agregado (Art. 18-J)\n'
                    '  - Ley Federal de Proteccion de Datos Personales en Posesion de los Particulares\n\n'
                    'Cualquier controversia sera sometida a los tribunales competentes de Puerto Vallarta, Jalisco, Mexico.'),

                _section('17. Contacto',
                    'Para preguntas sobre estos terminos:\n\n'
                    'Email: soporte@beautycita.com\n'
                    'Telefono: +52 (720) 677-7800\n'
                    'WhatsApp: +52 (720) 677-7800\n'
                    'Domicilio: Avenida Manuel Corona, Alazan 11A, C.P. 48290, Jalisco, Mexico'),
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
