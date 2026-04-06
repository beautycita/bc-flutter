import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/breakpoints.dart';

const _bg = Color(0xFFFFFAF5);
const _dark = Color(0xFF1A1A1A);
const _mid = Color(0xFF666666);
const _hint = Color(0xFF999999);
const _pink = Color(0xFFEC4899);
const _purple = Color(0xFF9333EA);
const _blue = Color(0xFF3B82F6);
const _green = Color(0xFF16A34A);
const _red = Color(0xFFEF4444);
const _grad = LinearGradient(colors: [_pink, _purple, _blue], begin: Alignment.topLeft, end: Alignment.bottomRight);

class _R {
  final double w;
  _R(this.w);
  bool get mob => w < 800;
  double get f => mob ? 1.0 : (w / 850).clamp(1.1, 1.6);
  double get pad => mob ? 20 : (w * 0.08).clamp(48, 140);
  double get max => mob ? double.infinity : 900.0;
  double get gap => mob ? 48 : 80;
  double get h1 => (mob ? 26 : 40) * f;
  double get h2 => (mob ? 22 : 32) * f;
  double get h3 => (mob ? 18 : 24) * f;
  double get body => (mob ? 15 : 17) * f;
  double get sm => (mob ? 13 : 15) * f;
  double get xs => (mob ? 12 : 13) * f;
}

class PorQuePage extends StatelessWidget {
  const PorQuePage({super.key});

  @override
  Widget build(BuildContext context) {
    final r = _R(MediaQuery.sizeOf(context).width);
    return Scaffold(
      backgroundColor: _bg,
      body: SelectionArea(
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: r.pad),
          children: [
            _nav(context),
            SizedBox(height: r.gap * 0.5),
            _hero(r),
            SizedBox(height: r.gap),
            _realReasons(r),
            SizedBox(height: r.gap),
            _theSwitch(r),
            SizedBox(height: r.gap),
            _theCatch(r),
            SizedBox(height: r.gap),
            _replace(r),
            SizedBox(height: r.gap),
            _theDeal(r),
            SizedBox(height: r.gap),
            _numbers(context, r),
            SizedBox(height: r.gap),
            _possible(r),
            SizedBox(height: r.gap),
            _cta(context, r),
            SizedBox(height: r.gap),
          ],
        ),
      ),
    );
  }

  Widget _nav(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: GestureDetector(
      onTap: () => context.go('/'),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: ShaderMask(
          shaderCallback: (b) => _grad.createShader(b),
          child: const Text('BeautyCita', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
        ),
      ),
    ),
  );

  // ── 1. Hero ──

  Widget _hero(_R r) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: r.max),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(color: _purple.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(50)),
        child: Text('De salon owner para salon owners', style: TextStyle(fontSize: r.sm, fontWeight: FontWeight.w600, color: _purple)),
      ),
      const SizedBox(height: 20),
      Text('Cada plataforma de salones cobra mensualidad. Nosotros no.',
        style: TextStyle(fontSize: r.h1, fontWeight: FontWeight.w800, height: 1.2, color: _dark)),
      SizedBox(height: r.body),
      Text('AgendaPro: \$4,500/mes. Vagaro: \$25 USD por estilista. Fresha: 20% por cliente nuevo. '
        'Todos prometen hacerte crecer. Todos empiezan cobrandote antes de que ganes un peso.',
        style: TextStyle(fontSize: r.body, color: _mid, height: 1.6)),
      SizedBox(height: r.body * 0.8),
      Text('BeautyCita te da TODO gratis. Sin mensualidad. Sin limites. Sin letras chiquitas. '
        'Solo cobramos si te traemos una clienta nueva.',
        style: TextStyle(fontSize: r.body, fontWeight: FontWeight.w600, color: _dark, height: 1.5)),
      SizedBox(height: r.body * 0.8),
      Text('Si suena demasiado bueno — sigue leyendo.',
        style: TextStyle(fontSize: r.body * 1.05, fontWeight: FontWeight.w700, fontStyle: FontStyle.italic, color: _purple)),
    ]),
  );

  // ── 2. Real Reasons You Haven't Switched ──

  Widget _realReasons(_R r) {
    final reasons = [
      ('Es demasiado dificil aprender un sistema nuevo',
        'Ya intentaste. Tus estilistas no lo usaron. Terminaste manejando dos agendas al mismo tiempo hasta que regresaste a lo de siempre. '
        'El problema no eras tu — el problema es que esos sistemas no fueron disenados para ser simples.',
        'BeautyCita se configura en 2 minutos. Si tu equipo sabe usar WhatsApp, sabe usar BeautyCita.'),
      ('Pago mucho y no se ni por que',
        'Cada mes te llega un cargo. Quieres revisar que estas pagando y si realmente lo necesitas, pero la pagina de configuracion '
        'es un laberinto. Tienes miedo de desactivar algo y que se rompa todo. Asi que sigues pagando.',
        'BeautyCita no tiene planes. No hay nada que desactivar. Todo esta incluido. Siempre.'),
      ('Ya tengo dos servicios, no quiero un tercero',
        'Un sistema para citas, otro para pagos, otro para mensajes. A cierto punto los costos y la complejidad '
        'de manejar todo pesan mas que los beneficios. Quieres simple, y te estan complicando la vida.',
        'BeautyCita es UNA herramienta. Citas, pagos, mensajes, impuestos, staff, CRM — todo en un lugar.'),
      ('No quiero reportar impuestos',
        'Nunca has reportado. Si empiezas ahora, el SAT podria preguntar por los anos anteriores. '
        'Tu salon apenas sobrevive y la retencion de impuestos te quitaria dinero que necesitas.',
        'BeautyCita es tu herramienta — tu decides. Los walk-ins que registras no generan retenciones. '
        'Solo aplicamos retenciones en clientes que NOSOTROS te enviamos, donde la ley nos obliga como intermediarios. '
        'Tus propios clientes, tu negocio, tus decisiones.'),
      ('Si no esta roto, para que lo cambio?',
        'Tu cuaderno funciona. WhatsApp funciona. No perfecto, pero funciona. '
        'El riesgo de cambiar se siente mas grande que el beneficio.',
        'No te pedimos que dejes nada. Usa BeautyCita junto con lo que ya tienes. Es gratis. '
        'Cuando veas que funciona mejor, el cuaderno se retira solo.'),
    ];

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: r.max),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Por que no has cambiado', style: TextStyle(fontSize: r.h2, fontWeight: FontWeight.w800, color: _dark)),
        SizedBox(height: r.body * 0.6),
        Text('Lo sabemos. Porque lo hemos escuchado.', style: TextStyle(fontSize: r.body, color: _mid, height: 1.6)),
        SizedBox(height: r.body * 1.5),
        ...reasons.map((reason) => Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: EdgeInsets.all(r.mob ? 16 : 24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF0EBE6))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(reason.$1, style: TextStyle(fontSize: r.body * 1.05, fontWeight: FontWeight.w800, color: _dark)),
            SizedBox(height: r.body * 0.5),
            Text(reason.$2, style: TextStyle(fontSize: r.sm, color: _mid, height: 1.6)),
            SizedBox(height: r.body * 0.5),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(r.mob ? 12 : 16),
              decoration: BoxDecoration(color: _green.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(10)),
              child: Text(reason.$3, style: TextStyle(fontSize: r.sm, color: _green.withValues(alpha: 0.9), fontWeight: FontWeight.w600, height: 1.5)),
            ),
          ]),
        )),
      ]),
    );
  }

  // ── 3. The Switch ──

  Widget _theSwitch(_R r) => Container(
    constraints: BoxConstraints(maxWidth: r.max),
    padding: EdgeInsets.all(r.mob ? 20 : 40),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [_pink.withValues(alpha: 0.04), _purple.withValues(alpha: 0.04)]),
      borderRadius: BorderRadius.circular(20), border: Border.all(color: _purple.withValues(alpha: 0.1))),
    child: Column(children: [
      Text('Y si una sola herramienta reemplaza TODO?', textAlign: TextAlign.center,
        style: TextStyle(fontSize: r.h2, fontWeight: FontWeight.w800, color: _dark, height: 1.3)),
      SizedBox(height: r.body),
      Text('Abres la app. Ves las citas del dia. Quien trabaja. Cuanto ha producido cada estilista. '
        'Impuestos calculados. Recordatorios enviados. Y no pagas un peso hasta que te traigamos un cliente nuevo.',
        textAlign: TextAlign.center, style: TextStyle(fontSize: r.body, color: _mid, height: 1.7)),
      SizedBox(height: r.body * 1.5),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('Eso es ', style: TextStyle(fontSize: r.h2, fontWeight: FontWeight.w800, color: _dark)),
        ShaderMask(shaderCallback: (b) => _grad.createShader(b),
          child: Text('BeautyCita.', style: TextStyle(fontSize: r.h2, fontWeight: FontWeight.w800, color: Colors.white))),
      ]),
    ]),
  );

  // ── 4. The Catch — expose the real markup ──

  Widget _theCatch(_R r) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: r.max),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Cual es el truco?', style: TextStyle(fontSize: r.h2, fontWeight: FontWeight.w800, color: _dark)),
      SizedBox(height: r.body * 0.8),
      Text('Es lo primero que todos preguntan. Y es justo.\n\n'
        'Pero antes de responder, veamos algo que nadie te ha mostrado: '
        'cuanto REALMENTE cuestan los servicios por los que estas pagando.',
        style: TextStyle(fontSize: r.body, color: _mid, height: 1.6)),
      SizedBox(height: r.body * 1.2),

      // AgendaPro messaging markup
      _markupCard(
        name: 'AgendaPro — mensajes',
        whatTheyCharge: '\$2 MXN por mensaje de recordatorio',
        whatItCosts: '\$0.09 MXN por mensaje (costo real de WhatsApp API)',
        markup: '22x de markup',
        math: 'Un salon con 30 citas/dia envia ~60 mensajes.\n'
          '60 × \$2 = \$120 MXN/dia = \$3,360 MXN/mes que TU pagas.\n'
          '60 × \$0.09 = \$5.40 MXN/dia = \$151 MXN/mes que a ELLOS les cuesta.\n'
          'Ganancia por salon: \$3,209 MXN/mes. Por 20,000 salones: \$64 millones MXN/mes.',
        r: r,
      ),

      // Per-stylist fee markup
      _markupCard(
        name: 'Vagaro — cobro por estilista',
        whatTheyCharge: '\$10 USD/mes por cada estilista adicional',
        whatItCosts: '~\$0.10 USD/mes (unas consultas extra a la base de datos)',
        markup: '100x de markup',
        math: 'Alojar 1 estilista o 10 en la misma cuenta cuesta exactamente lo mismo — '
          'es la misma base de datos, el mismo servidor, el mismo ancho de banda.\n'
          'Un salon con 5 estilistas paga \$30 base + \$40 extra = \$70 USD/mes.\n'
          'El costo real de esos 4 estilistas extra: menos de 50 centavos.\n\n'
          'Vagaro proceso 141 millones de citas en 2024 — eso son ~55,000 estilistas activos.\n'
          'Si 40,000 son "adicionales" a \$10 USD/mes: \$400,000 USD/mes.\n'
          '\$4.8 millones USD al ano — por agregar filas a una base de datos que ya existe.',
        r: r,
      ),

      // Fresha "free" markup
      _markupCard(
        name: 'Fresha — "gratis"',
        whatTheyCharge: '20% de comision por cada cliente nuevo (minimo \$6 USD)',
        whatItCosts: 'El costo de mostrar tu salon en un listado web: ~\$0',
        markup: 'Infinito markup',
        math: 'En 2025, Fresha conecto 3 millones de clientes nuevos con salones.\n'
          'A \$6 USD minimo cada uno: \$18 millones USD solo por "nuevos clientes."\n'
          'Revenue total 2024: \$43.4 millones USD. De software "gratuito."',
        r: r,
      ),

      SizedBox(height: r.body),
      Container(
        width: double.infinity, padding: EdgeInsets.all(r.mob ? 16 : 24),
        decoration: BoxDecoration(color: _dark, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Text('Ingresos combinados de estas tres plataformas:', style: TextStyle(fontSize: r.sm, color: Colors.white70)),
          SizedBox(height: r.body * 0.4),
          Text('~\$500 millones USD al ano', style: TextStyle(fontSize: r.h2, fontWeight: FontWeight.w800, color: _red)),
          SizedBox(height: r.body * 0.4),
          Text('De salones como el tuyo. Por servicios que les cuestan centavos.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: r.body, color: Colors.white.withValues(alpha: 0.8))),
          SizedBox(height: r.body),
          Text('BeautyCita cobra en TOTAL lo que ellos cobran solo en mensajes de texto.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: r.body, fontWeight: FontWeight.w700, color: _green)),
          SizedBox(height: r.body),
          SizedBox(height: r.body * 0.5),
          Text('Como la industria medica o funeraria — saben que no conoces los costos reales, '
            'y cobran lo que quieren porque confian en que no vas a investigar.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: r.sm, color: Colors.white.withValues(alpha: 0.7), height: 1.6)),
          SizedBox(height: r.body),
          Text('Ahora ya lo sabes.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: r.body, fontWeight: FontWeight.w700, color: Colors.white)),
          SizedBox(height: r.body * 0.5),
          Text('No se trata de ahorrarte \$250 pesos. Se trata de que alguien te estuvo cobrando 22 veces '
            'el costo real y esperaba que nunca preguntaras.\n\n'
            'BeautyCita existe porque alguien decidio que esto no tenia que ser asi.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: r.sm, color: Colors.white.withValues(alpha: 0.8), height: 1.6)),
        ]),
      ),
    ]),
  );

  Widget _markupCard({required String name, required String whatTheyCharge, required String whatItCosts, required String markup, required String math, required _R r}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14), padding: EdgeInsets.all(r.mob ? 16 : 22),
      decoration: BoxDecoration(color: _red.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(14), border: Border.all(color: _red.withValues(alpha: 0.12))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: TextStyle(fontSize: r.body, fontWeight: FontWeight.w800, color: _red)),
        SizedBox(height: r.body * 0.6),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Te cobran: ', style: TextStyle(fontSize: r.sm, color: _mid)),
          Expanded(child: Text(whatTheyCharge, style: TextStyle(fontSize: r.sm, fontWeight: FontWeight.w700, color: _dark))),
        ]),
        SizedBox(height: r.body * 0.3),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Les cuesta: ', style: TextStyle(fontSize: r.sm, color: _mid)),
          Expanded(child: Text(whatItCosts, style: TextStyle(fontSize: r.sm, fontWeight: FontWeight.w700, color: _green))),
        ]),
        SizedBox(height: r.body * 0.3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: _red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
          child: Text(markup, style: TextStyle(fontSize: r.sm, fontWeight: FontWeight.w800, color: _red)),
        ),
        SizedBox(height: r.body * 0.6),
        Text(math, style: TextStyle(fontSize: r.xs, color: _mid, height: 1.6)),
      ]),
    );
  }

  // ── 5. What You Replace ──

  Widget _replace(_R r) {
    final data = [
      ('Agenda de papel', 'Calendario visual con drag & drop'),
      ('"Llama para reagendar"', 'Arrastra la cita. El cliente recibe alerta automatica.'),
      ('WhatsApp manual', 'Recordatorios automaticos GRATIS e ILIMITADOS'),
      ('AgendaPro (\$2,500/mes)', 'Todo gratis. Staff ilimitado. Sin mensualidad.'),
      ('Calculadora de impuestos', 'UNICA plataforma en Mexico con ISR/IVA automaticos'),
      ('Comisiones "a ojo"', 'Productividad por estilista en tiempo real'),
      ('Libreta de clientes', 'CRM con historial y tags automaticos'),
      ('Sitio web (\$5,000+)', 'Pagina portfolio gratis — 5 temas'),
    ];
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: r.max),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Lo que reemplazas', style: TextStyle(fontSize: r.h2, fontWeight: FontWeight.w800, color: _dark)),
        SizedBox(height: r.body * 1.5),
        ...data.map((d) => Container(
          margin: const EdgeInsets.only(bottom: 8), padding: EdgeInsets.all(r.mob ? 12 : 18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF0EBE6))),
          child: Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: _green.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.check_rounded, color: _green, size: 20)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.$1, style: TextStyle(fontSize: r.sm, color: _red, fontWeight: FontWeight.w600, decoration: TextDecoration.lineThrough, decorationColor: _red)),
              const SizedBox(height: 2),
              Text(d.$2, style: TextStyle(fontSize: r.body * 0.95, color: _dark, fontWeight: FontWeight.w600)),
            ])),
          ]),
        )),
      ]),
    );
  }

  // ── 6. The Deal ──

  Widget _theDeal(_R r) {
    final steps = [
      ('1', 'Te registras hoy', 'En 2 minutos. Sin tarjeta. Sin compromiso.', false),
      ('2', 'Usas todo gratis', 'Calendario, staff, recordatorios, web, analiticas, CRM. Sin limite de tiempo.', false),
      ('3', 'Nosotros te buscamos clientes', 'Nuestro motor inteligente conecta clientas nuevas con tu salon.', false),
      ('4', 'Solo cobramos cuando funciona', '3% por cada cliente que NOSOTROS te enviamos. Tus clientas: 0%. Siempre.', true),
    ];
    return Container(
      constraints: BoxConstraints(maxWidth: r.max), padding: EdgeInsets.all(r.mob ? 20 : 40),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0EBE6)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 4))]),
      child: Column(children: [
        Text('El trato', style: TextStyle(fontSize: r.h2, fontWeight: FontWeight.w800, color: _dark)),
        SizedBox(height: r.body * 1.5),
        ...steps.map((s) => Padding(padding: const EdgeInsets.only(bottom: 20), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(gradient: s.$4 ? _grad : null, color: s.$4 ? null : const Color(0xFFF5F0EB), shape: BoxShape.circle),
            child: Center(child: Text(s.$1, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: s.$4 ? Colors.white : _dark)))),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.$2, style: TextStyle(fontSize: r.body, fontWeight: FontWeight.w700, color: _dark)),
            const SizedBox(height: 4),
            Text(s.$3, style: TextStyle(fontSize: r.sm, color: _mid, height: 1.5)),
          ])),
        ]))),
        const SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(r.mob ? 16 : 20),
          decoration: BoxDecoration(color: _green.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: _green.withValues(alpha: 0.2))),
          child: Column(children: [
            Text('Tus clientas = 0% comision', style: TextStyle(fontSize: r.h3 * 0.9, fontWeight: FontWeight.w800, color: _green)),
            const SizedBox(height: 6),
            Text('Walk-ins y clientas que reservan por tu link son tuyas. BeautyCita es tu herramienta, no tu intermediario.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: r.sm, color: _mid, height: 1.5)),
            SizedBox(height: r.body),
            Container(height: 1, color: _green.withValues(alpha: 0.15)),
            SizedBox(height: r.body),
            Text('Clientas nuevas que te enviamos = 3%', style: TextStyle(fontSize: r.h3 * 0.9, fontWeight: FontWeight.w800, color: _purple)),
            const SizedBox(height: 6),
            Text('Cuando nuestro motor conecta una clienta nueva con tu salon, cobramos 3%. Incluye retenciones ISR e IVA ante el SAT.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: r.sm, color: _mid, height: 1.5)),
          ]),
        ),
      ]),
    );
  }

  // ── 7. In Numbers ──

  Widget _numbers(BuildContext context, _R r) {
    final data = [('\$0', 'Mensualidad', 'Hoy, manana, siempre'), ('\$0', 'Por estilista', 'Agrega 100. Sigue gratis'),
      ('\$0', 'Por mensaje', 'WhatsApp ilimitado'), ('0', 'Funciones bloqueadas', 'Todo abierto dia 1'),
      ('3%', 'Solo si funciona', 'Cobramos cuando TE TRAEMOS clienta'), ('100%', 'Tuyo', 'Tus datos, tu negocio')];
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: r.max),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('En numeros', style: TextStyle(fontSize: r.h2, fontWeight: FontWeight.w800, color: _dark)),
        SizedBox(height: r.body * 1.5),
        LayoutBuilder(builder: (ctx, box) {
          final cw = r.mob ? (box.maxWidth - 12) / 2 : 270.0;
          return Wrap(spacing: 14, runSpacing: 14, children: data.map((s) => SizedBox(width: cw, child: Container(
            padding: EdgeInsets.all(r.mob ? 16 : 22),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF0EBE6))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ShaderMask(shaderCallback: (b) => _grad.createShader(b),
                child: Text(s.$1, style: TextStyle(fontSize: r.h1 * 0.85, fontWeight: FontWeight.w800, color: Colors.white))),
              const SizedBox(height: 4),
              Text(s.$2, style: TextStyle(fontSize: r.sm, fontWeight: FontWeight.w700, color: _dark)),
              const SizedBox(height: 2),
              Text(s.$3, style: TextStyle(fontSize: r.xs, color: _hint)),
            ]),
          ))).toList());
        }),
      ]),
    );
  }

  // ── 8. How Is This Possible ──

  Widget _possible(_R r) => Container(
    constraints: BoxConstraints(maxWidth: r.max), padding: EdgeInsets.all(r.mob ? 20 : 40),
    decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(20)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Como es posible?', style: TextStyle(fontSize: r.h2, fontWeight: FontWeight.w800, color: Colors.white)),
      SizedBox(height: r.body * 1.2),
      Text('Nuestros costos reales:', style: TextStyle(fontSize: r.h3, fontWeight: FontWeight.w700, color: Colors.white)),
      SizedBox(height: r.body),
      _cost('Servidores e infraestructura', '\$4,200/mes', r),
      _cost('Alertas WhatsApp (por salon)', '\$0.09 MXN/mensaje', r),
      _cost('Procesamiento Stripe', '2.9% + \$3 MXN', r),
      _cost('Soporte y desarrollo', '\$18,000/mes', r),
      SizedBox(height: r.body),
      Container(
        padding: EdgeInsets.all(r.mob ? 16 : 22),
        decoration: BoxDecoration(color: _green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: _green.withValues(alpha: 0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Lo que cobramos: 3% por clienta nueva que te enviamos', style: TextStyle(fontSize: r.body, fontWeight: FontWeight.w700, color: _green)),
          SizedBox(height: r.body * 0.4),
          Text('Lo que NO cobramos: mensualidad, por estilista, por mensaje, por funcion, por existir.',
            style: TextStyle(fontSize: r.sm, color: Colors.white.withValues(alpha: 0.8))),
        ]),
      ),
      SizedBox(height: r.body * 1.2),
      Container(
        padding: EdgeInsets.all(r.mob ? 16 : 22),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
        child: Text('Cada vez que tuvimos la opcion de cobrar unos pesos extra — elegimos a ti. '
          'No a una mesa de inversionistas.\n\n'
          'Eso es lo que "justo" se ve cuando lo pones en numeros.',
          style: TextStyle(fontSize: r.body, color: Colors.white.withValues(alpha: 0.9), height: 1.6)),
      ),
      SizedBox(height: r.body * 1.2),
      Text('No hay plan Pro. No hay version Premium. Lo que ves es lo que tienes. Hoy y siempre.',
        style: TextStyle(fontSize: r.body, fontWeight: FontWeight.w700, color: Colors.white, height: 1.5)),
      SizedBox(height: r.body),
      Text('Esta es nuestra primera version — y solo va a mejorar. '
        'Los salones que se unan ahora tendran cada nueva mejora. Para siempre. Gratis.',
        style: TextStyle(fontSize: r.sm, color: Colors.white.withValues(alpha: 0.7), height: 1.5)),
    ]),
  );

  Widget _cost(String label, String cost, _R r) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Text('\u2022 ', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: r.sm)),
      Expanded(child: Text(label, style: TextStyle(fontSize: r.sm, color: Colors.white.withValues(alpha: 0.7)))),
      Text(cost, style: TextStyle(fontSize: r.sm, fontWeight: FontWeight.w700, color: Colors.white)),
    ]),
  );

  // ── 9. CTA ──

  Widget _cta(BuildContext context, _R r) => Container(
    constraints: BoxConstraints(maxWidth: r.max),
    padding: EdgeInsets.symmetric(vertical: r.mob ? 36 : 60, horizontal: r.mob ? 20 : 40),
    decoration: BoxDecoration(gradient: _grad, borderRadius: BorderRadius.circular(r.mob ? 16 : 24)),
    child: Column(children: [
      Text('Ahora que sabes la verdad — que vas a hacer?', textAlign: TextAlign.center,
        style: TextStyle(fontSize: r.h2, fontWeight: FontWeight.w800, color: Colors.white, height: 1.3)),
      SizedBox(height: r.body),
      Text('Adopta BeautyCita. Recomiendala. Somos la unica plataforma en Mexico '
        'que mantiene a tu salon en cumplimiento con el SAT, '
        'te da todas las herramientas sin cobrarte un peso, '
        'y solo gana dinero cuando te traemos clientas nuevas.',
        textAlign: TextAlign.center, style: TextStyle(fontSize: r.body, color: Colors.white70, height: 1.6)),
      SizedBox(height: r.body * 1.8),
      GestureDetector(
        onTap: () => context.go('/'),
        child: MouseRegion(cursor: SystemMouseCursors.click, child: Container(
          width: r.mob ? double.infinity : 340, padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: Text('Registrar Mi Salon — Gratis', textAlign: TextAlign.center,
            style: TextStyle(fontSize: r.body, fontWeight: FontWeight.w700, color: _purple)),
        )),
      ),
      SizedBox(height: r.body),
      Text('Sin tarjeta. Sin compromiso. Sin mensualidad.', style: TextStyle(fontSize: r.xs, color: Colors.white60)),
    ]),
  );
}
