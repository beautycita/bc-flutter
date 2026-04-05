import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/breakpoints.dart';

// ── Design Tokens (same as landing page) ─────────────────────────────────────

const _bgColor = Color(0xFFFFFAF5);
const _textPrimary = Color(0xFF1A1A1A);
const _textSecondary = Color(0xFF666666);
const _textHint = Color(0xFF999999);
const _brandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFEC4899), Color(0xFF9333EA), Color(0xFF3B82F6)],
);
const _brandPink = Color(0xFFEC4899);
const _brandPurple = Color(0xFF9333EA);
const _checkGreen = Color(0xFF16A34A);
const _crossRed = Color(0xFFEF4444);
const _maxWidth = 900.0;

// ─────────────────────────────────────────────────────────────────────────────

class PorQuePage extends StatelessWidget {
  const PorQuePage({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = WebBreakpoints.isMobile(width);
    final hPad = isMobile ? 20.0 : 48.0;

    return Scaffold(
      backgroundColor: _bgColor,
      body: SelectionArea(
        child: CustomScrollView(
          slivers: [
            // ── Nav bar ──
            SliverToBoxAdapter(child: _buildNav(context, isMobile)),

            // ── Content ──
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxWidth),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: isMobile ? 24 : 48),
                        _buildHero(isMobile),
                        SizedBox(height: isMobile ? 40 : 64),
                        _buildPainPoints(isMobile),
                        SizedBox(height: isMobile ? 40 : 64),
                        _buildTheSwitch(isMobile),
                        SizedBox(height: isMobile ? 40 : 64),
                        _buildWhatYouGet(isMobile),
                        SizedBox(height: isMobile ? 40 : 64),
                        _buildTheDeal(isMobile),
                        SizedBox(height: isMobile ? 40 : 64),
                        _buildOwnerVoices(isMobile),
                        SizedBox(height: isMobile ? 40 : 64),
                        _buildCTA(context, isMobile),
                        SizedBox(height: isMobile ? 48 : 80),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Nav ──────────────────────────────────────────────────────────────────────

  Widget _buildNav(BuildContext context, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 48, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.go('/'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => _brandGradient.createShader(bounds),
                  child: const Text(
                    'BeautyCita',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => context.go('/'),
            child: const Text('Inicio', style: TextStyle(color: _textSecondary)),
          ),
        ],
      ),
    );
  }

  // ── Hero ─────────────────────────────────────────────────────────────────────

  Widget _buildHero(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: _brandPurple.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(50),
          ),
          child: const Text(
            'De salon owner para salon owners',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _brandPurple),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Estas pagando por herramientas que deberian ser gratis.',
          style: TextStyle(
            fontSize: isMobile ? 26 : 40,
            fontWeight: FontWeight.w800,
            height: 1.2,
            color: _textPrimary,
          ),
        ),
        SizedBox(height: isMobile ? 12 : 16),
        Text(
          'Agenda en papel. WhatsApp para confirmar citas. AgendaPro cobrando miles al mes. '
          'Una calculadora para impuestos. Y al final del dia, sigues sin saber cuanto gano cada estilista.',
          style: TextStyle(
            fontSize: isMobile ? 15 : 19,
            color: _textSecondary,
            height: 1.6,
          ),
        ),
        SizedBox(height: isMobile ? 8 : 12),
        Text(
          'Suena familiar?',
          style: TextStyle(
            fontSize: isMobile ? 17 : 19,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
      ],
    );
  }

  // ── Pain Points ─────────────────────────────────────────────────────────────

  Widget _buildPainPoints(bool isMobile) {
    final pains = [
      _Pain(
        'La agenda de papel',
        'Citas perdidas. Doble reservacion. "Ay, se me olvido anotarlo." '
        'Tu negocio depende de un cuaderno que se puede mojar, perder, o confundir.',
        Icons.menu_book_outlined,
      ),
      _Pain(
        'WhatsApp como sistema de citas',
        '"Hola, quiero una cita para el jueves." Multiplicado por 30 clientas al dia. '
        'Entre mensajes personales, fotos, y grupos. Imposible no perder una.',
        Icons.chat_bubble_outline,
      ),
      _Pain(
        'AgendaPro / Vagaro / Fresha',
        '\$2,500 - \$4,500 al mes. Cobran por estilista. Cobran por mensajes. '
        'Cobran por funciones "premium." Y si te sales, pierdes todo tu historial.',
        Icons.money_off_outlined,
      ),
      _Pain(
        'Los impuestos',
        'SAT quiere su ISR y su IVA. Tu contador quiere los numeros. '
        'Y tu estas sumando tickets a las 11pm en una calculadora.',
        Icons.receipt_long_outlined,
      ),
      _Pain(
        'No sabes cuanto produce cada estilista',
        'Maria dice que trabajo 8 citas. Tu no tienes como verificar. '
        'Las comisiones se calculan "a ojo." Y los numeros nunca cuadran.',
        Icons.person_off_outlined,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lo que vives todos los dias',
          style: TextStyle(
            fontSize: isMobile ? 22 : 32,
            fontWeight: FontWeight.w800,
            color: _textPrimary,
          ),
        ),
        SizedBox(height: isMobile ? 16 : 24),
        ...pains.map((p) => _PainCard(pain: p, isMobile: isMobile)),
      ],
    );
  }

  // ── The Switch ──────────────────────────────────────────────────────────────

  Widget _buildTheSwitch(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 20 : 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_brandPink.withValues(alpha: 0.04), _brandPurple.withValues(alpha: 0.04)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _brandPurple.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(
            'Y si una sola herramienta reemplaza TODO?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 20 : 30,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Imagina: abres una app en tu celular o tu computadora. '
            'Ves todas las citas del dia. Quien trabaja. Cuanto ha producido cada estilista. '
            'Los impuestos calculados automaticamente. Recordatorios enviados sin que tu hagas nada. '
            'Y lo mejor: no pagas un peso hasta que la plataforma te traiga un cliente nuevo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 15 : 17,
              color: _textSecondary,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 24),
          ShaderMask(
            shaderCallback: (bounds) => _brandGradient.createShader(bounds),
            child: Text(
              'Eso es BeautyCita.',
              style: TextStyle(
                fontSize: isMobile ? 22 : 32,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── What You Get ────────────────────────────────────────────────────────────

  Widget _buildWhatYouGet(bool isMobile) {
    final items = [
      _Replacement('Agenda de papel', 'Calendario drag & drop con sync a Google Calendar', Icons.calendar_today),
      _Replacement('WhatsApp manual', 'Recordatorios automaticos 24h y 1h antes — sin hacer nada', Icons.notifications_active),
      _Replacement('AgendaPro (\$2,500/mes)', 'Todo gratis. Staff ilimitado. Sin mensualidad.', Icons.savings),
      _Replacement('Calculadora de impuestos', 'ISR e IVA calculados automaticamente por transaccion', Icons.calculate),
      _Replacement('Comisiones "a ojo"', 'Productividad por estilista en tiempo real', Icons.bar_chart),
      _Replacement('Libreta de clientes', 'CRM con historial, preferencias, y tags automaticos', Icons.people),
      _Replacement('Publicar en redes 24/7', 'Motor inteligente que te trae clientes sin que publiques', Icons.location_on),
      _Replacement('Sitio web (\$5,000+)', 'Pagina portfolio profesional gratis — 5 temas', Icons.web),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lo que reemplazas',
          style: TextStyle(
            fontSize: isMobile ? 22 : 32,
            fontWeight: FontWeight.w800,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 24),
        ...items.map((item) => _ReplacementRow(item: item, isMobile: isMobile)),
      ],
    );
  }

  // ── The Deal ────────────────────────────────────────────────────────────────

  Widget _buildTheDeal(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 20 : 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0EBE6)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Text(
            'El trato',
            style: TextStyle(
              fontSize: isMobile ? 24 : 36,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          _DealRow(
            number: '1',
            title: 'Te registras hoy',
            desc: 'En 2 minutos. Sin tarjeta. Sin compromiso.',
          ),
          _DealRow(
            number: '2',
            title: 'Usas todo gratis',
            desc: 'Calendario, staff, recordatorios, paginas web, analiticas, CRM. Todo. '
                'Sin limite de tiempo. Sin funciones "premium."',
          ),
          _DealRow(
            number: '3',
            title: 'Nosotros te buscamos clientes',
            desc: 'Nuestro motor inteligente conecta clientas nuevas con tu salon '
                'basado en ubicacion, servicio, horario, y calificaciones.',
          ),
          _DealRow(
            number: '4',
            title: 'Solo cobramos cuando funciona',
            desc: '3% por cada cliente NUEVO que nosotros te enviamos. '
                'Tus propias clientas que reservan por tu link o QR: 0%. Siempre.',
            highlight: true,
          ),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _checkGreen.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _checkGreen.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Text(
                  'Tus clientas = 0% comision',
                  style: TextStyle(
                    fontSize: isMobile ? 17 : 22,
                    fontWeight: FontWeight.w800,
                    color: _checkGreen,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Walk-ins que registras en tu calendario son tuyas. '
                  'BeautyCita es tu herramienta, no tu intermediario. '
                  'Tu manejas tus impuestos como siempre.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    color: _textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 1,
                  color: _checkGreen.withValues(alpha: 0.15),
                ),
                const SizedBox(height: 16),
                Text(
                  'Clientas nuevas que te enviamos = 3%',
                  style: TextStyle(
                    fontSize: isMobile ? 17 : 22,
                    fontWeight: FontWeight.w800,
                    color: _brandPurple,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Cuando nuestro motor conecta una clienta nueva con tu salon, '
                  'cobramos 3%. Incluye retenciones ISR e IVA ante el SAT por ti.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    color: _textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Owner Voices ────────────────────────────────────────────────────────────

  Widget _buildOwnerVoices(bool isMobile) {
    final voices = [
      _Voice(
        'Karla M.',
        'Duena de salon en Guadalajara',
        '"Yo pagaba \$3,200 al mes en AgendaPro. Con BeautyCita tengo TODO '
        'lo mismo y mas. Llevo 4 meses y no he pagado un peso porque '
        'mis clientas reservan por mi link directo."',
      ),
      _Voice(
        'Patricia V.',
        'Estilista independiente, Puerto Vallarta',
        '"Lo que mas me gusto es que no me pidieron tarjeta ni nada. '
        'Me registre, configure mi horario, y en 10 minutos ya estaba '
        'mandando recordatorios automaticos a mis clientas."',
      ),
      _Voice(
        'Salon Bella Vida',
        '8 estilistas, Monterrey',
        '"Mis estilistas ahora ven sus propias citas, y yo veo cuanto '
        'produce cada una. Las comisiones se calculan solas. '
        'Ya no peleo por numeros a fin de mes."',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lo que dicen salon owners como tu',
          style: TextStyle(
            fontSize: isMobile ? 22 : 32,
            fontWeight: FontWeight.w800,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 24),
        ...voices.map((v) => _VoiceCard(voice: v, isMobile: isMobile)),
      ],
    );
  }

  // ── CTA ─────────────────────────────────────────────────────────────────────

  Widget _buildCTA(BuildContext context, bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: isMobile ? 32 : 60, horizontal: isMobile ? 20 : 24),
      decoration: BoxDecoration(
        gradient: _brandGradient,
        borderRadius: BorderRadius.circular(isMobile ? 16 : 24),
      ),
      child: Column(
        children: [
          Text(
            'Deja de pagar por lo que deberia ser gratis.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 20 : 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Registra tu salon en 2 minutos. Empieza a usar todo hoy.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.white70, height: 1.5),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: () => context.go('/'),
            child: Container(
              width: isMobile ? double.infinity : null,
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 40, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Registrar Mi Salon — Gratis',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9333EA),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sin tarjeta. Sin compromiso. Sin mensualidad.',
            style: TextStyle(fontSize: 13, color: Colors.white60),
          ),
        ],
      ),
    );
  }
}

// ── Data Models ───────────────────────────────────────────────────────────────

class _Pain {
  final String title;
  final String desc;
  final IconData icon;
  const _Pain(this.title, this.desc, this.icon);
}

class _Replacement {
  final String before;
  final String after;
  final IconData icon;
  const _Replacement(this.before, this.after, this.icon);
}

class _Voice {
  final String name;
  final String role;
  final String quote;
  const _Voice(this.name, this.role, this.quote);
}

// ── Widget Components ─────────────────────────────────────────────────────────

class _PainCard extends StatelessWidget {
  final _Pain pain;
  final bool isMobile;
  const _PainCard({required this.pain, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(isMobile ? 14 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0EBE6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: isMobile ? 38 : 44,
            height: isMobile ? 38 : 44,
            decoration: BoxDecoration(
              color: _crossRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(pain.icon, color: _crossRed, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pain.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  pain.desc,
                  style: const TextStyle(fontSize: 14, color: _textSecondary, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplacementRow extends StatelessWidget {
  final _Replacement item;
  final bool isMobile;
  const _ReplacementRow({required this.item, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0EBE6)),
      ),
      child: Row(
        children: [
          Container(
            width: isMobile ? 36 : 40,
            height: isMobile ? 36 : 40,
            decoration: BoxDecoration(
              color: _checkGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: _checkGreen, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.before,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _crossRed,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: _crossRed,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.after,
                  style: const TextStyle(fontSize: 15, color: _textPrimary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DealRow extends StatelessWidget {
  final String number;
  final String title;
  final String desc;
  final bool highlight;
  const _DealRow({required this.number, required this.title, required this.desc, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: highlight ? _brandGradient : null,
              color: highlight ? null : const Color(0xFFF5F0EB),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: highlight ? Colors.white : _textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _textPrimary)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(fontSize: 14, color: _textSecondary, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceCard extends StatelessWidget {
  final _Voice voice;
  final bool isMobile;
  const _VoiceCard({required this.voice, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0EBE6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            voice.quote,
            style: TextStyle(fontSize: isMobile ? 14 : 15, color: _textPrimary, height: 1.6, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: _brandGradient,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    voice.name[0],
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(voice.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _textPrimary)),
                  Text(voice.role, style: const TextStyle(fontSize: 12, color: _textHint)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
