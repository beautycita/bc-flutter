import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr/qr.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/breakpoints.dart';

// ── Design Tokens ────────────────────────────────────────────────────────────

const _bgColor = Color(0xFFFFFAF5);
const _cardBorder = Color(0xFFF0EBE6);
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
const _brandBlue = Color(0xFF3B82F6);
const _checkGreen = Color(0xFF16A34A);
const _crossRed = Color(0xFFEF4444);
const _warnAmber = Color(0xFFF59E0B);

const _maxWidth = 1200.0;

BoxShadow _cardShadow = BoxShadow(
  color: Colors.black.withValues(alpha: 0.04),
  blurRadius: 10,
  offset: const Offset(0, 3),
);

BoxShadow _cardShadowHover = BoxShadow(
  color: Colors.black.withValues(alpha: 0.08),
  blurRadius: 32,
  offset: const Offset(0, 8),
);

const _apkUrl =
    'https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/apk/beautycita.apk';

// ── Gradient Text Helper ─────────────────────────────────────────────────────

class _GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const _GradientText(this.text, {this.style});
  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => _brandGradient.createShader(bounds),
      child: Text(text, style: (style ?? const TextStyle()).copyWith(color: Colors.white)),
    );
  }
}

// ── Section Keys for Scroll Navigation ───────────────────────────────────────

final _heroKey = GlobalKey();
final _comparisonKey = GlobalKey();
final _forSalonsKey = GlobalKey();
final _forClientsKey = GlobalKey();
final _demoKey = GlobalKey();
final _pricingKey = GlobalKey();
final _downloadKey = GlobalKey();

// ── Landing Page ─────────────────────────────────────────────────────────────

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});
  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  bool _navScrolled = false;
  bool _mobileMenuOpen = false;

  // Animation controllers for staggered fade-in
  late final AnimationController _heroAnim;
  late final AnimationController _comparisonAnim;
  late final AnimationController _salonsAnim;
  late final AnimationController _demoAnim;
  late final AnimationController _clientsAnim;
  late final AnimationController _testimonialsAnim;
  late final AnimationController _pricingAnim;
  late final AnimationController _downloadAnim;

  final List<AnimationController> _sectionAnims = [];

  // Phone input for demo section
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  String? _phoneError;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    _heroAnim = _createAnim(800);
    _comparisonAnim = _createAnim(700);
    _salonsAnim = _createAnim(700);
    _demoAnim = _createAnim(700);
    _clientsAnim = _createAnim(700);
    _testimonialsAnim = _createAnim(700);
    _pricingAnim = _createAnim(700);
    _downloadAnim = _createAnim(700);

    _sectionAnims.addAll([
      _heroAnim,
      _comparisonAnim,
      _salonsAnim,
      _demoAnim,
      _clientsAnim,
      _testimonialsAnim,
      _pricingAnim,
      _downloadAnim,
    ]);

    // Start hero animation immediately
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _heroAnim.forward();
    });
  }

  AnimationController _createAnim(int ms) {
    return AnimationController(
      vsync: this,
      duration: Duration(milliseconds: ms),
    );
  }

  void _onScroll() {
    final scrolled = _scrollController.offset > 10;
    if (scrolled != _navScrolled) {
      setState(() => _navScrolled = scrolled);
    }
    _checkSectionVisibility();
  }

  void _checkSectionVisibility() {
    final anims = [
      _comparisonAnim,
      _salonsAnim,
      _demoAnim,
      _clientsAnim,
      _testimonialsAnim,
      _pricingAnim,
      _downloadAnim,
    ];

    for (var i = 0; i < anims.length; i++) {
      if (!anims[i].isCompleted) {
        // Trigger when scroll reaches roughly the section area
        final triggerOffset = (i + 1) * 400.0;
        if (_scrollController.offset > triggerOffset - 600) {
          anims[i].forward();
        }
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final a in _sectionAnims) {
      a.dispose();
    }
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _scrollToSection(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut);
    }
    if (_mobileMenuOpen) {
      setState(() => _mobileMenuOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final isDesktop = WebBreakpoints.isDesktop(w);
          final isTablet = WebBreakpoints.isTablet(w);
          final isMobile = WebBreakpoints.isMobile(w);

          return Stack(
            children: [
              SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  children: [
                    const SizedBox(height: 72), // space for fixed nav
                    _buildHero(isDesktop, isMobile),
                    _buildComparison(isDesktop, isMobile),
                    _buildForSalons(isDesktop, isMobile, isTablet),
                    _buildDemo(isDesktop, isMobile),
                    _buildForClients(isDesktop, isMobile),
                    _buildTestimonials(isDesktop, isMobile),
                    _buildPricing(isDesktop, isMobile),
                    _buildDownload(isDesktop, isMobile),
                    _buildFooter(isDesktop, isMobile),
                  ],
                ),
              ),
              // Sticky nav on top
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildNavBar(isDesktop, isMobile),
              ),
              // Mobile menu overlay
              if (_mobileMenuOpen)
                Positioned(
                  top: 72,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildMobileMenu(),
                ),
            ],
          );
        },
      ),
    );
  }

  // ── NavBar ─────────────────────────────────────────────────────────────────

  Widget _buildNavBar(bool isDesktop, bool isMobile) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 72,
      decoration: BoxDecoration(
        color: _bgColor.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(
            color: _navScrolled ? _cardBorder : Colors.transparent,
          ),
        ),
        boxShadow: _navScrolled
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 2))]
            : [],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // Logo
                MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => _scrollToSection(_heroKey),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network('img/bc_logo.png', width: 36, height: 36, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(gradient: _brandGradient, borderRadius: BorderRadius.circular(10)),
                                  child: const Center(child: Text('BC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14))),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text.rich(
                              TextSpan(children: [
                                const TextSpan(text: 'Beauty', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: _textPrimary)),
                                TextSpan(text: 'Cita', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, foreground: Paint()..shader = _brandGradient.createShader(const Rect.fromLTWH(0, 0, 60, 30)))),
                              ]),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Desktop nav links
                    if (isDesktop) ...[
                      _navLink('Inicio', _heroKey),
                      const SizedBox(width: 28),
                      _navLink('Para Salones', _forSalonsKey),
                      const SizedBox(width: 28),
                      _navRouteLink(context, 'Por que BC?', '/porque-beautycita'),
                      const SizedBox(width: 28),
                      _navLink('Para Clientes', _forClientsKey),
                      const SizedBox(width: 28),
                      _navLink('Demo', _demoKey),
                      const SizedBox(width: 28),
                      _navLink('Precios', _pricingKey),
                      const SizedBox(width: 28),
                      _navLink('Descargar', _downloadKey),
                      const SizedBox(width: 28),
                    ],
                    // Booking CTA
                    if (!isMobile) ...[
                      _HoverScaleButton(
                        onTap: () => context.go('/reservar'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: _brandPink, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Reserva tu cita', style: TextStyle(color: _brandPink, fontWeight: FontWeight.w700, fontSize: 14)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Salon CTA
                      _HoverScaleButton(
                        onTap: () => _scrollToSection(_demoKey),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: _brandGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Registra tu Salon', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                        ),
                      ),
                    ],
                    // Mobile hamburger
                    if (isMobile)
                      IconButton(
                        icon: Icon(_mobileMenuOpen ? Icons.close : Icons.menu, color: _textPrimary),
                        onPressed: () => setState(() => _mobileMenuOpen = !_mobileMenuOpen),
                      ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _navLink(String label, GlobalKey key) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _scrollToSection(key),
        child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _textSecondary)),
      ),
    );
  }

  Widget _navRouteLink(BuildContext context, String label, String route) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go(route),
        child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _brandPurple)),
      ),
    );
  }

  Widget _buildMobileMenu() {
    return Container(
      color: _bgColor.withValues(alpha: 0.98),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _mobileNavItem('Inicio', _heroKey),
          _mobileNavItem('Para Salones', _forSalonsKey),
          GestureDetector(
            onTap: () { setState(() => _mobileMenuOpen = false); context.go('/porque-beautycita'); },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Por que BC?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: _brandPurple)),
            ),
          ),
          _mobileNavItem('Para Clientes', _forClientsKey),
          _mobileNavItem('Demo', _demoKey),
          _mobileNavItem('Precios', _pricingKey),
          _mobileNavItem('Descargar', _downloadKey),
          const SizedBox(height: 16),
          _HoverScaleButton(
            onTap: () {
              setState(() => _mobileMenuOpen = false);
              context.go('/reservar');
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: _brandPink, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text('Reserva tu cita', style: TextStyle(color: _brandPink, fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _HoverScaleButton(
            onTap: () {
              setState(() => _mobileMenuOpen = false);
              _scrollToSection(_demoKey);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: _brandGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text('Registra tu Salon', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileNavItem(String label, GlobalKey key) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _scrollToSection(key),
          child: Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: _textPrimary)),
        ),
      ),
    );
  }

  // ── Hero Section ───────────────────────────────────────────────────────────

  Widget _buildHero(bool isDesktop, bool isMobile) {
    return Container(
      key: _heroKey,
      width: double.infinity,
      constraints: BoxConstraints(minHeight: isMobile ? 0 : 600),
      padding: EdgeInsets.symmetric(vertical: isDesktop ? 80 : 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _heroAnim, curve: Curves.easeOut),
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
                    .animate(CurvedAnimation(parent: _heroAnim, curve: Curves.easeOut)),
                child: isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(flex: 14, child: _heroLeft(isDesktop, isMobile)),
                          const SizedBox(width: 60),
                          Expanded(flex: 10, child: _heroPhone()),
                        ],
                      )
                    : Column(
                        children: [
                          _heroLeft(isDesktop, isMobile),
                          const SizedBox(height: 40),
                          SizedBox(
                            width: isMobile ? 260 : 300,
                            child: _heroPhone(),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroLeft(bool isDesktop, bool isMobile) {
    final align = isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center;
    final textAlign = isDesktop ? TextAlign.start : TextAlign.center;

    return Column(
      crossAxisAlignment: align,
      children: [
        // Badge pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_brandPink.withValues(alpha: 0.1), _brandPurple.withValues(alpha: 0.1)],
            ),
            border: Border.all(color: _brandPurple.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(50),
          ),
          child: const Text(
            'La primera plataforma sin mensualidad en Mexico',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _brandPurple),
          ),
        ),
        const SizedBox(height: 24),
        // Headline
        Text.rich(
          TextSpan(children: [
            TextSpan(
              text: 'Tu salon merece mas clientes.\n',
              style: TextStyle(fontSize: isMobile ? 32 : 52, fontWeight: FontWeight.w800, height: 1.15, color: _textPrimary),
            ),
          ]),
          textAlign: textAlign,
        ),
        // Gradient part of headline
        _GradientText(
          'Nosotros te los traemos.',
          style: TextStyle(fontSize: isMobile ? 32 : 52, fontWeight: FontWeight.w800, height: 1.15),
        ),
        const SizedBox(height: 20),
        // Subtitle
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'Usa todas las herramientas gratis desde hoy. 0% comision hasta que te enviemos tu primer cliente nuevo. Sin cuota mensual. Sin letra chiquita.',
            textAlign: textAlign,
            style: const TextStyle(fontSize: 19, color: _textSecondary, height: 1.7),
          ),
        ),
        const SizedBox(height: 36),
        // CTAs
        Wrap(
          spacing: 16,
          runSpacing: 12,
          alignment: isDesktop ? WrapAlignment.start : WrapAlignment.center,
          children: [
            _HoverScaleButton(
              onTap: () => _scrollToSection(_demoKey),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  gradient: _brandGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text('Prueba el Demo Gratis', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
            _HoverScaleButton(
              onTap: () => context.go('/reservar'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: _brandPurple, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text('Buscar un salon', style: TextStyle(color: _brandPurple, fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),
        // Trust badges
        Wrap(
          spacing: 32,
          runSpacing: 12,
          alignment: isDesktop ? WrapAlignment.start : WrapAlignment.center,
          children: [
            _trustBadge('Cumplimiento SAT automatico'),
            _trustBadge('\$0 cuota mensual'),
            _trustBadge('WhatsApp ilimitado gratis'),
          ],
        ),
      ],
    );
  }

  Widget _trustBadge(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            gradient: _brandGradient,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.check, color: Colors.white, size: 12),
          ),
        ),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textSecondary)),
      ],
    );
  }

  Widget _heroPhone() {
    return _PhoneFloating(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.network(
          'img/01_home.png',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => _phoneContent(),
        ),
      ),
    );
  }

  Widget _phoneContent() {
    return Column(
      children: [
        // Status bar
        Container(
          height: 32,
          decoration: const BoxDecoration(
            gradient: _brandGradient,
          ),
          child: const Center(
            child: Text('BeautyCita', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600)),
          ),
        ),
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: _cardBorder)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hola, bienvenida', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _textPrimary)),
              SizedBox(height: 2),
              Text('Que servicio buscas hoy?', style: TextStyle(fontSize: 12, color: _textHint)),
            ],
          ),
        ),
        // Category grid
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _phoneCat(Icons.content_cut, 'Corte', _brandPurple),
                _phoneCat(Icons.palette_outlined, 'Color', _brandPink),
                _phoneCat(Icons.brush_outlined, 'Unas', _brandBlue),
                _phoneCat(Icons.visibility_outlined, 'Pestanas', _brandPurple),
                _phoneCat(Icons.star_outline, 'Facial', _brandPink),
                _phoneCat(Icons.face_outlined, 'Maquillaje', _brandBlue),
              ],
            ),
          ),
        ),
        // Bottom bar
        Container(
          height: 48,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: _cardBorder)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Container(width: 24, height: 24, decoration: BoxDecoration(gradient: _brandGradient, borderRadius: BorderRadius.circular(6))),
              Container(width: 24, height: 24, decoration: BoxDecoration(color: _cardBorder, borderRadius: BorderRadius.circular(6))),
              Container(width: 24, height: 24, decoration: BoxDecoration(color: _cardBorder, borderRadius: BorderRadius.circular(6))),
              Container(width: 24, height: 24, decoration: BoxDecoration(color: _cardBorder, borderRadius: BorderRadius.circular(6))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _phoneCat(IconData icon, String label, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_brandPink.withValues(alpha: 0.15), _brandPurple.withValues(alpha: 0.15)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _textSecondary)),
        ],
      ),
    );
  }

  // ── Comparison Table ───────────────────────────────────────────────────────

  Widget _buildComparison(bool isDesktop, bool isMobile) {
    return _SectionWrapper(
      sectionKey: _comparisonKey,
      anim: _comparisonAnim,
      child: Column(
        children: [
          _sectionHeader(
            'Compara y decide',
            'Por que BeautyCita es la mejor opcion para tu salon',
          ),
          const SizedBox(height: 40),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 2))],
            ),
            clipBehavior: Clip.antiAlias,
            child: isMobile
                ? _comparisonCards()
                : _comparisonTable(),
          ),
        ],
      ),
    );
  }

  Widget _comparisonTable() {
    final rows = [
      _CompRow('Cuota mensual', 'GRATIS', '\$299 - \$4,500/mes', '"Gratis" + 20% clientes nuevos', bcType: _CellType.free, col2Type: _CellType.warn, col3Type: _CellType.warn),
      _CompRow('Staff ilimitado', null, '1-20 (segun plan)', '\$14.95/mes por estilista', bcType: _CellType.check, col2Type: _CellType.warn, col3Type: _CellType.warn),
      _CompRow('Mensajes WhatsApp', 'ILIMITADOS GRATIS', '\$2/mensaje', 'Incluido (limitado)', bcType: _CellType.free, col2Type: _CellType.warn, col3Type: _CellType.plain),
      _CompRow('Pagina portfolio', '5 temas', 'Pagina basica', 'Perfil en marketplace', bcType: _CellType.checkText, col2Type: _CellType.plain, col3Type: _CellType.plain),
      _CompRow('Punto de venta', 'GRATIS (10% comision)', '\$250/mes', '2.19% + 0.20 por pago', bcType: _CellType.free, col2Type: _CellType.warn, col3Type: _CellType.warn),
      _CompRow('Cumplimiento SAT', 'Automatico', 'Solo autofacturacion', 'No', bcType: _CellType.checkText, col2Type: _CellType.plain, col3Type: _CellType.cross),
      _CompRow('Calendario drag & drop', null, 'No', 'Basico', bcType: _CellType.check, col2Type: _CellType.cross, col3Type: _CellType.plain),
      _CompRow('Sync Google Calendar', 'GRATIS', 'Solo Premium', 'No', bcType: _CellType.free, col2Type: _CellType.warn, col3Type: _CellType.cross),
      _CompRow('Motor inteligente', 'Busca clientes PARA ti (0% hasta el primero)', 'Directorio pasivo', '20% comision por cliente nuevo', bcType: _CellType.checkText, col2Type: _CellType.plain, col3Type: _CellType.warn),
      _CompRow('Velocidad de la app', 'Rapida y fluida', 'Lenta en algunos dispositivos', 'Normal', bcType: _CellType.checkText, col2Type: _CellType.warn, col3Type: _CellType.plain),
      _CompRow('Soporte en cash/OXXO', null, 'No', 'No', bcType: _CellType.check, col2Type: _CellType.cross, col3Type: _CellType.cross),
    ];

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 700),
      child: Column(
        children: [
          // Header row
          Row(
              children: [
                _tableHeaderCell('Caracteristica', flex: 3, align: Alignment.centerLeft),
                _tableHeaderCellBC('BeautyCita', flex: 2),
                _tableHeaderCell('AgendaPro', flex: 2),
                _tableHeaderCell('Fresha', flex: 2),
              ],
          ),
          Divider(height: 1, thickness: 1, color: _cardBorder.withValues(alpha: 0.5)),
          // Data rows
          ...rows.asMap().entries.map((entry) {
            final i = entry.key;
            final row = entry.value;
            return _ComparisonRow(row: row, isEven: i.isEven);
          }),
        ],
      ),
    );
  }

  Widget _tableHeaderCell(String text, {int flex = 1, Alignment align = Alignment.center}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Align(
          alignment: align,
          child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary)),
        ),
      ),
    );
  }

  Widget _tableHeaderCellBC(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                gradient: _brandGradient,
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Text('RECOMENDADO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
            ),
            const SizedBox(height: 6),
            _GradientText(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _comparisonCards() {
    final items = [
      ('Cuota mensual', 'GRATIS', '\$299-4,500/mes', '"Gratis" + 20%'),
      ('Staff', 'Ilimitado', '1-20 (segun plan)', '\$14.95/mes c/u'),
      ('WhatsApp', 'ILIMITADO GRATIS', '\$2/mensaje', 'Limitado'),
      ('Cumplimiento SAT', 'Automatico', 'Solo autofacturacion', 'No'),
      ('Calendario', 'Drag & drop', 'No', 'Basico'),
      ('Motor inteligente', '0% hasta el primero', 'Directorio pasivo', '20% comision'),
      ('Punto de venta', 'GRATIS (10%)', '\$250/mes', '2.19% + 0.20'),
      ('Cash/OXXO', 'Si', 'No', 'No'),
    ];

    return Column(
      children: items.map((item) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.$1, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textPrimary)),
            const SizedBox(height: 10),
            // BC row
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(gradient: _brandGradient, borderRadius: BorderRadius.circular(6)),
                child: const Text('BC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(item.$2, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _checkGreen))),
            ]),
            const SizedBox(height: 6),
            // AgendaPro row
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: _textHint.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: const Text('AP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _textHint)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(item.$3, style: TextStyle(fontSize: 13, color: _crossRed.withValues(alpha: 0.8)))),
            ]),
            const SizedBox(height: 4),
            // Fresha row
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: _textHint.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: const Text('FR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _textHint)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(item.$4, style: TextStyle(fontSize: 13, color: _crossRed.withValues(alpha: 0.8)))),
            ]),
          ],
        ),
      )).toList(),
    );
  }

  // ── Feature Detail Popup ───────────────────────────────────────────────────

  void _showFeatureDetail(BuildContext context, _Feature feature, Offset tapPosition) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Feature Detail',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, anim, secondaryAnim) {
        return _FeatureDetailPopup(
          feature: feature,
          onDemo: () {
            Navigator.of(context).pop();
            _scrollToSection(_demoKey);
          },
        );
      },
      transitionBuilder: (context, anim, secondaryAnim, child) {
        final screenSize = MediaQuery.of(context).size;
        final maxRadius = (screenSize.width > screenSize.height
            ? screenSize.width
            : screenSize.height) * 1.5;
        final radius = anim.value * maxRadius;

        return ClipPath(
          clipper: _CircleClipper(center: tapPosition, radius: radius),
          child: child,
        );
      },
    );
  }

  // ── For Salons (Feature Grid) ──────────────────────────────────────────────

  Widget _buildForSalons(bool isDesktop, bool isMobile, bool isTablet) {
    final features = [
      _Feature(Icons.location_on_outlined, 'Motor Inteligente',
        'Nuestro AI encuentra clientes para tu salon — 0% comision hasta el primero',
        detailTitle: 'Motor de Busqueda Inteligente',
        detailBullets: [
          'Pipeline de 6 pasos que analiza ubicacion, horario, especialidad, precio y calificaciones',
          'Cada tipo de servicio tiene su propio perfil de ranking — corte \u2260 extensiones \u2260 novia',
          'Devuelve los 3 mejores salones con el mejor horario disponible en menos de 400ms',
          'Los clientes no buscan — el motor los conecta contigo automaticamente',
          'Tu salon aparece cuando un cliente busca tu tipo de servicio en tu zona',
          'Usa todas las herramientas gratis. Solo cobramos 3% cuando te enviemos un cliente nuevo',
        ],
      ),
      _Feature(Icons.people_outline, 'Staff Ilimitado',
        'Agrega todo tu equipo sin pagar mas',
        detailTitle: 'Gestion de Equipo Sin Limites',
        detailBullets: [
          'Agrega estilistas, recepcionistas y asistentes sin costo adicional',
          'Cada miembro tiene su propio perfil con foto, bio y especialidades',
          'Asigna servicios especificos a cada estilista',
          'Analiticas de productividad por empleado',
          'AgendaPro cobra por profesional. Nosotros no.',
        ],
      ),
      _Feature(Icons.calendar_today_outlined, 'Calendario Inteligente',
        'Drag & drop para reagendar. Auto-sync. Alertas automaticas.',
        detailTitle: 'Calendario con Superpoderes',
        detailBullets: [
          'Arrastra y suelta para reagendar o reasignar citas a otro estilista',
          'Sincronizacion automatica en tiempo real con Google Calendar',
          'Alertas automaticas al cliente y estilista cuando hay cambios',
          'Si el salon modifica una cita, el cliente puede cancelar gratis y recibir reembolso completo en saldo',
          'BeautyCita solo cobra comision en citas que nosotros te enviamos — tus propios clientes, 0%',
          'Politica de cancelacion configurable por salon (default 24 horas)',
        ],
        detailNote: 'El cliente siempre tiene la opcion de modificar o cancelar sin penalizacion cuando el salon inicia el cambio.',
      ),
      _Feature(Icons.desktop_mac_outlined, 'Portfolio Web',
        'Tu pagina profesional en beautycita.com/p/tu-salon',
        detailTitle: 'Tu Sitio Web Profesional — Gratis',
        detailBullets: [
          '5 temas profesionales: portfolio, team-builder, storefront, gallery, local',
          'Se construye automaticamente con los datos de tu salon',
          'URL personalizada: beautycita.com/p/tu-salon',
          'Fotos de servicios, equipo, horarios, ubicacion — todo incluido',
          'Ideal si no tienes sitio web — o como complemento al que ya tienes',
          'Los motores de busqueda indexan tu pagina — mas visibilidad gratis',
        ],
      ),
      _Feature(Icons.notifications_active_outlined, 'Alertas Automaticas',
        'Recordatorios y notificaciones a tus clientes — sin costo',
        detailTitle: 'Sistema de Alertas Inteligente',
        detailBullets: [
          'Recordatorio automatico 24 horas antes de la cita',
          'Segundo recordatorio 1 hora antes',
          'Alerta inmediata si hay cambios en la reservacion',
          'Confirmacion de reserva al momento de agendar',
          'Todo esto sin costo — AgendaPro cobra \$100 por 50 mensajes',
          'Tu no envias nada manualmente — nosotros nos encargamos',
        ],
        detailNote: 'Todas las alertas son automaticas. El salon no tiene que hacer nada.',
      ),
      _Feature(Icons.storefront_outlined, 'Punto de Venta',
        'Vende productos de belleza. Solo 10% comision, sin mensualidad',
        detailTitle: 'Vende Productos Sin Costo de Entrada',
        detailBullets: [
          '10 categorias de productos (los mas vendidos en TikTok y redes)',
          'Catalogo con fotos, precios, y estado de inventario',
          'Publica productos en el feed de inspiracion — miles de ojos',
          'Pedidos con seguimiento: push + email \u2192 recordatorio 3 dias \u2192 escalamiento 7 dias \u2192 reembolso 14 dias',
          'Solo 10% comision via Stripe Connect. Sin mensualidad. Sin setup.',
          'AgendaPro cobra \$250/mes por su terminal de pago',
        ],
      ),
      _Feature(Icons.bar_chart_outlined, 'Analiticas',
        'Productividad por empleado, ingresos, tendencias',
        detailTitle: 'Datos que Hacen Crecer tu Negocio',
        detailBullets: [
          'Dashboard con KPIs en tiempo real: citas hoy, ingresos, cancelaciones',
          'Productividad por estilista: citas completadas, ingresos, calificaciones',
          'Tendencias mensuales con graficas interactivas',
          'Desglose de ingresos por servicio, estilista y metodo de pago',
          'Reportes exportables a CSV',
        ],
      ),
      _Feature(Icons.verified_outlined, 'Cumplimiento SAT',
        'Cumplimiento fiscal automatico para todas las transacciones',
        detailTitle: 'SAT Compliant — Automatico y Gratuito',
        detailBullets: [
          'Retenciones ISR (2.5% con RFC, 20% sin RFC) y IVA (8%/16%) calculadas automaticamente',
          'Ledger inmutable de todas las transacciones — listo para auditoria',
          'Reportes mensuales para el SAT generados automaticamente',
          'Compatible con CFF Art. 30-B (acceso SAT en tiempo real, vigente abril 2026)',
          'Badge de "Negocio Verificado" visible para clientes — genera confianza',
          'Tu no calculas nada — nosotros nos encargamos de todo',
        ],
        detailNote: 'Integracion con PAC SW Sapien para timbrado de CFDI (proximamente).',
      ),
      _Feature(Icons.download_outlined, 'Import de Datos',
        'Migra desde Vagaro, Fresha o Booksy en minutos',
        detailTitle: 'Migracion Facil desde Otra Plataforma',
        detailBullets: [
          'Importa clientes, servicios, horarios y citas desde Vagaro, Fresha o Booksy',
          'Proceso guiado paso a paso — no necesitas ser tecnico',
          'Tus datos historicos se preservan — no pierdes nada',
          'Soporte personalizado durante la migracion',
          'Empieza a recibir citas el mismo dia',
        ],
      ),
      _Feature(Icons.credit_card_outlined, 'Prestamos para Salones',
        'Creditos para hacer crecer tu negocio (proximamente)',
        detailTitle: 'Financiamiento para Crecer',
        detailBullets: [
          'Creditos de bajo interes disenados para salones de belleza',
          'Basados en tu historial de ingresos en BeautyCita',
          'Aprobacion rapida — sin burocracia bancaria',
          'Para: remodelacion, equipo nuevo, inventario, publicidad',
          'Pagos automaticos deducidos de tus ingresos',
        ],
        detailNote: 'Proximamente — en desarrollo. Registrate ahora para ser de los primeros.',
      ),
      _Feature(Icons.photo_library_outlined, 'Fotos Antes/Despues',
        'El arma secreta para atraer mas clientes',
        detailTitle: 'El Portfolio Visual que Vende por Ti',
        detailBullets: [
          'Los salones con portfolio visual reciben 4x mas reservaciones que los que no tienen',
          'Te recordamos antes de cada cita: "No olvides pedir la foto del antes"',
          'Alerta 10 min antes: el estilista recibe un push — "Tu cliente llega pronto para [servicio]. Pide la foto antes."',
          'Alerta ~20 min antes de terminar: "Recuerda pedir la foto del despues. Tu proximo cliente es a las [hora]."',
          'Las fotos alimentan tu portfolio web, el feed de inspiracion, y Google Images',
          'Los motores de busqueda indexan imagenes y comentarios — visibilidad gratuita',
          'Convence a clientes timidos: "Es solo para mostrar nuestro trabajo, no se publica tu cara"',
        ],
        detailNote: 'Los salones que suben antes/despues consistentemente ven un incremento del 40% en reservaciones nuevas.',
      ),
      _Feature(Icons.bolt_outlined, 'Cita Express',
        'Widget embebible para tu sitio web existente',
        detailTitle: 'Booking Widget para tu Sitio Web',
        detailBullets: [
          'Un boton de "Reservar" que puedes poner en tu pagina web, Instagram o Facebook',
          'Los clientes reservan sin salir de tu sitio',
          'Personalizable con tus colores y servicios',
          'QR code para walk-ins: el cliente escanea y reserva al instante',
          'Funciona en cualquier sitio web — solo copia y pega el codigo',
        ],
      ),
    ];

    final crossCount = isDesktop ? 4 : (isTablet ? 3 : (isMobile ? 1 : 2));

    return Container(
      key: _forSalonsKey,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bgColor, _brandPink.withValues(alpha: 0.04), _brandPurple.withValues(alpha: 0.04), _bgColor],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: _SectionWrapper(
        anim: _salonsAnim,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: isDesktop ? 100 : 60, horizontal: 24),
              child: Column(
                children: [
                  _sectionHeader(
                    null,
                    'Herramientas profesionales para hacer crecer tu negocio — 0% comision hasta que te enviemos tu primer cliente',
                    richTitle: Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'Todo lo que tu salon necesita. ', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: _textPrimary)),
                      ]),
                      textAlign: TextAlign.center,
                    ),
                    richTitleSuffix: const _GradientText('Gratis.', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 48),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _maxWidth),
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 24,
                      children: features.map((f) {
                        final cardWidth = crossCount == 1
                            ? double.infinity
                            : (_maxWidth - (crossCount - 1) * 24) / crossCount;
                        return SizedBox(
                          width: crossCount == 1 ? null : cardWidth,
                          child: _FeatureCard(
                            feature: f,
                            onTapUp: (pos) => _showFeatureDetail(context, f, pos),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Demo Section ───────────────────────────────────────────────────────────

  Widget _buildDemo(bool isDesktop, bool isMobile) {
    return _SectionWrapper(
      sectionKey: _demoKey,
      anim: _demoAnim,
      child: Column(
        children: [
          _sectionHeader(
            null,
            'Ingresa tu numero y explora todas las herramientas',
            richTitle: Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Prueba BeautyCita en ', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: _textPrimary)),
              ]),
              textAlign: TextAlign.center,
            ),
            richTitleSuffix: const _GradientText('30 segundos', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 48),
          isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _demoLeft(isMobile)),
                    const SizedBox(width: 60),
                    Expanded(child: _demoDashboardPreview()),
                  ],
                )
              : Column(
                  children: [
                    _demoLeft(isMobile),
                    const SizedBox(height: 40),
                    _demoDashboardPreview(),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _demoLeft(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_codeSent) ...[
          // Step 1: Phone input row
          Row(
            children: [
              Expanded(
                child: _DemoPhoneInput(
                  controller: _phoneController,
                  error: _phoneError,
                ),
              ),
              const SizedBox(width: 12),
              _HoverScaleButton(
                onTap: _sendingCode ? null : _onSendDemoCode,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: _brandGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _sendingCode
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Enviar codigo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Te enviaremos un codigo por WhatsApp para verificar tu numero. Sin compromiso.',
            style: TextStyle(fontSize: 14, color: _textHint),
          ),
        ] else ...[
          // Step 2: Verification code entry
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 8, color: _textPrimary),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '000000',
                    hintStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 8, color: _textHint.withValues(alpha: 0.3)),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _textHint.withValues(alpha: 0.2))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _textHint.withValues(alpha: 0.2))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _brandPink, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _HoverScaleButton(
                onTap: _verifyingCode ? null : _onVerifyCode,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: _brandGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _verifyingCode
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Verificar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.check_circle, color: _checkGreen, size: 16),
              const SizedBox(width: 6),
              const Expanded(child: Text('Codigo enviado por WhatsApp. Ingresalo arriba.', style: TextStyle(fontSize: 14, color: _checkGreen, fontWeight: FontWeight.w600))),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => setState(() { _codeSent = false; _codeController.clear(); _phoneError = null; }),
                child: const Text('Cambiar numero', style: TextStyle(fontSize: 13, color: _brandPink, decoration: TextDecoration.underline)),
              ),
            ],
          ),
        ],
        if (_phoneError != null) ...[
          const SizedBox(height: 8),
          Text(_phoneError!, style: const TextStyle(fontSize: 14, color: _crossRed, fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 40),
        // 3 steps
        isMobile
            ? Column(
                children: [
                  _demoStep('1', 'Ingresa tu numero', 'Tu numero de celular mexicano', done: _codeSent),
                  const SizedBox(height: 20),
                  _demoStep('2', 'Verifica por WhatsApp', 'Recibe tu codigo de acceso', active: _codeSent && !_codeVerified, done: _codeVerified),
                  const SizedBox(height: 20),
                  _demoStep('3', 'Explora el demo completo', 'Accede a todas las herramientas'),
                ],
              )
            : Row(
                children: [
                  Expanded(child: _demoStep('1', 'Ingresa tu numero', 'Tu numero de celular mexicano', done: _codeSent)),
                  const SizedBox(width: 24),
                  Expanded(child: _demoStep('2', 'Verifica por WhatsApp', 'Recibe tu codigo de acceso', active: _codeSent && !_codeVerified, done: _codeVerified)),
                  const SizedBox(width: 24),
                  Expanded(child: _demoStep('3', 'Explora el demo completo', 'Accede a todas las herramientas')),
                ],
              ),
      ],
    );
  }

  Widget _demoStep(String num, String title, String subtitle, {bool done = false, bool active = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: done ? null : (active ? _brandGradient : null),
            color: done ? _checkGreen : (!active ? _textHint.withValues(alpha: 0.2) : null),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(num, style: TextStyle(color: active ? Colors.white : _textHint, fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: active ? _textPrimary : (done ? _checkGreen : _textHint))),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 13, color: _textHint)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _demoDashboardPreview() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _cardBorder),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 24, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Browser chrome
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_brandPink.withValues(alpha: 0.06), _brandPurple.withValues(alpha: 0.06)]),
              border: const Border(bottom: BorderSide(color: _cardBorder)),
            ),
            child: Row(children: [
              Container(width: 10, height: 10, decoration: const BoxDecoration(color: _crossRed, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Container(width: 10, height: 10, decoration: const BoxDecoration(color: _warnAmber, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Container(width: 10, height: 10, decoration: const BoxDecoration(color: _checkGreen, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              const Text('beautycita.com/negocio', style: TextStyle(fontSize: 13, color: _textHint)),
            ]),
          ),
          // Dashboard body — responsive
          LayoutBuilder(builder: (context, constraints) {
            final narrow = constraints.maxWidth < 500;
            if (narrow) {
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  Row(children: [
                    Expanded(child: _demoStatCard('87', 'Citas')),
                    const SizedBox(width: 8),
                    Expanded(child: _demoStatCard('\$38.5k', 'MXN')),
                    const SizedBox(width: 8),
                    Expanded(child: _demoStatCard('4.7', 'Rating')),
                  ]),
                  const SizedBox(height: 12),
                  Container(
                    height: 80,
                    decoration: BoxDecoration(color: _bgColor, borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [_demoBar(0.4), _demoBar(0.65), _demoBar(0.8), _demoBar(0.55), _demoBar(0.9)],
                    ),
                  ),
                ]),
              );
            }
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 140, child: Column(children: [
                  _demoSidebarItem('Dashboard', active: true),
                  _demoSidebarItem('Calendario'),
                  _demoSidebarItem('Clientes'),
                  _demoSidebarItem('Servicios'),
                  _demoSidebarItem('Staff'),
                  _demoSidebarItem('Pagos'),
                  _demoSidebarItem('QR Code'),
                  _demoSidebarItem('Marketing'),
                  _demoSidebarItem('Analiticas'),
                  _demoSidebarItem('Portfolio'),
                ])),
                const SizedBox(width: 16),
                Expanded(child: Column(children: [
                  Row(children: [
                    Expanded(child: _demoStatCard('87', 'Citas este mes')),
                    const SizedBox(width: 12),
                    Expanded(child: _demoStatCard('\$38.5k', 'MXN ingresos')),
                    const SizedBox(width: 12),
                    Expanded(child: _demoStatCard('4.7', 'Calificacion')),
                  ]),
                  const SizedBox(height: 12),
                  Container(
                    height: 120,
                    decoration: BoxDecoration(color: _bgColor, borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.all(16),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      _demoBar(0.4), _demoBar(0.65), _demoBar(0.45),
                      _demoBar(0.8), _demoBar(0.55), _demoBar(0.9), _demoBar(0.7),
                    ]),
                  ),
                ])),
              ]),
            );
          }),
        ],
      ),
    );
  }

  Widget _demoSidebarItem(String label, {bool active = false}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: active
            ? LinearGradient(colors: [_brandPink.withValues(alpha: 0.1), _brandPurple.withValues(alpha: 0.1)])
            : null,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: active ? _brandPurple : _textSecondary,
        ),
      ),
    );
  }

  Widget _demoStatCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GradientText(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: _textHint)),
        ],
      ),
    );
  }

  Widget _demoBar(double heightFraction) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FractionallySizedBox(
          heightFactor: heightFraction,
          alignment: Alignment.bottomCenter,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [_brandPink.withValues(alpha: 0.3), _brandPurple.withValues(alpha: 0.3)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            ),
          ),
        ),
      ),
    );
  }

  bool _sendingCode = false;
  bool _codeSent = false;
  bool _verifyingCode = false;
  bool _codeVerified = false;
  String? _demoPhone;

  Future<void> _onSendDemoCode() async {
    final raw = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (raw.length < 10) {
      setState(() => _phoneError = 'Ingresa un numero de 10 digitos valido');
      return;
    }
    setState(() {
      _phoneError = null;
      _sendingCode = true;
    });

    try {
      final phone = raw.startsWith('52') ? raw : '52$raw';
      _demoPhone = phone;
      final response = await Supabase.instance.client.functions.invoke(
        'demo-wa-funnel',
        body: {'action': 'send_code', 'phone': phone},
      );
      final data = response.data as Map<String, dynamic>?;
      if (data?['sent'] == true) {
        setState(() {
          _codeSent = true;
          _sendingCode = false;
          _phoneError = null;
        });
      } else {
        setState(() {
          _sendingCode = false;
          _phoneError = data?['error'] as String? ?? 'Error al enviar. Intenta de nuevo.';
        });
      }
    } catch (e) {
      setState(() {
        _sendingCode = false;
        _phoneError = 'Error de conexion. Intenta de nuevo.';
      });
    }
  }

  Future<void> _onVerifyCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _phoneError = 'Ingresa el codigo de 6 digitos');
      return;
    }
    setState(() { _phoneError = null; _verifyingCode = true; });

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'demo-wa-funnel',
        body: {'action': 'verify', 'phone': _demoPhone, 'code': code},
      );
      final data = response.data as Map<String, dynamic>?;
      if (data?['verified'] == true) {
        final token = data?['demo_token'] as String?;
        setState(() { _codeVerified = true; _verifyingCode = false; });
        // Notify the edge function that demo was opened
        if (token != null) {
          Supabase.instance.client.functions.invoke(
            'demo-wa-funnel',
            body: {'action': 'demo_opened', 'demo_token': token},
          );
        }
        // Navigate to demo after brief success animation
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) context.go('/demo');
        });
      } else {
        setState(() {
          _verifyingCode = false;
          _phoneError = data?['error'] as String? ?? 'Codigo incorrecto';
        });
      }
    } catch (e) {
      setState(() {
        _verifyingCode = false;
        _phoneError = 'Error de conexion. Intenta de nuevo.';
      });
    }
  }

  // ── For Clients ────────────────────────────────────────────────────────────

  Widget _buildForClients(bool isDesktop, bool isMobile) {
    final cards = [
      _ClientCard(Icons.attach_money, 'Precios Justos', 'Sin mensualidades infladas que los salones te pasan a ti. Pagas el precio real del servicio.'),
      _ClientCard(Icons.verified_outlined, 'Cumplimiento Fiscal Automatico', 'Los salones en BeautyCita cumplen con el SAT automaticamente. Apoyas negocios que contribuyen a Mexico.'),
      _ClientCard(Icons.star_outline_rounded, 'Calificaciones Reales', 'Solo opiniones de clientes verificados que realmente visitaron el salon. Sin resenas falsas.'),
    ];

    return _SectionWrapper(
      sectionKey: _forClientsKey,
      anim: _clientsAnim,
      child: Column(
        children: [
          _sectionHeader(
            null,
            'Para los que buscan el salon perfecto, sin sorpresas',
            richTitle: Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'La mejor experiencia de ', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: _textPrimary)),
              ]),
              textAlign: TextAlign.center,
            ),
            richTitleSuffix: const _GradientText('reserva', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 40),
          isMobile
              ? Column(
                  children: cards.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _ClientCardWidget(card: c),
                  )).toList(),
                )
              : Row(
                  children: cards.map((c) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: _ClientCardWidget(card: c),
                    ),
                  )).toList(),
                ),
          const SizedBox(height: 60),
          // Download CTA
          Column(
            children: [
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Descarga la app y reserva en ', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _textPrimary)),
                ]),
                textAlign: TextAlign.center,
              ),
              const _GradientText('30 segundos', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              const Text('Sin cuentas, sin passwords. Solo tu huella o tu cara.', style: TextStyle(color: _textSecondary, fontSize: 16)),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _HoverScaleButton(
                    onTap: () => context.go('/reservar'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: _brandGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text('Reservar ahora', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                  ),
                  _HoverScaleButton(
                    onTap: () => _scrollToSection(_downloadKey),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: _brandPurple, width: 2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text('Descargar la app', style: TextStyle(color: _brandPurple, fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Testimonials ───────────────────────────────────────────────────────────

  Widget _buildTestimonials(bool isDesktop, bool isMobile) {
    // Real testimonials will be added as salons adopt.
    // For now, show a CTA to the porque page instead.

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bgColor, _brandPink.withValues(alpha: 0.03), _bgColor],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: _SectionWrapper(
        anim: _testimonialsAnim,
        padding: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: isDesktop ? 100 : 60, horizontal: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: Column(
                children: [
                  _sectionHeader(
                    null,
                    'Sabias cuanto realmente cuestan los servicios por los que pagas?',
                    richTitle: Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'La verdad detras de las ', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: _textPrimary)),
                      ]),
                      textAlign: TextAlign.center,
                    ),
                    richTitleSuffix: const _GradientText('mensualidades', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 24),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: const Text(
                      'AgendaPro cobra \$2 por mensaje que les cuesta \$0.09. Vagaro cobra \$10/mes por estilista que les cuesta \$0.10. '
                      'Fresha cobra 20% por clientes nuevos que les cuesta \$0 mostrar en un listado.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 17, color: _textSecondary, height: 1.6),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _HoverScaleButton(
                    onTap: () => context.go('/porque-beautycita'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: _brandGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text('Ver los numeros reales', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 60),
                  // Trust metrics bar
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _cardBorder),
                    ),
                    child: Wrap(
                      spacing: 48,
                      runSpacing: 24,
                      alignment: WrapAlignment.center,
                      children: [
                        _trustMetric('\$0', 'Mensualidad'),
                        _trustMetric('20+', 'Ciudades'),
                        _trustMetric('\u221E', 'Staff ilimitado'),
                        _trustMetric('0%', 'Comision tus clientas'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _trustMetric(String value, String label) {
    return Column(
      children: [
        _GradientText(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 13, color: _textHint)),
      ],
    );
  }

  // ── Pricing ────────────────────────────────────────────────────────────────

  Widget _buildPricing(bool isDesktop, bool isMobile) {
    final features = [
      'Staff ilimitado',
      'Calendario inteligente con drag & drop',
      'WhatsApp ilimitado (recordatorios + alertas)',
      'Pagina portfolio con 5 temas',
      'Sync Google Calendar',
      'Motor inteligente de clientes',
      'Punto de venta integrado',
      'Analiticas y reportes',
      'Cumplimiento SAT automatico',
      'Pagos cash, OXXO, y tarjeta',
      '0% comision hasta que te enviemos tu primer cliente',
    ];

    return _SectionWrapper(
      sectionKey: _pricingKey,
      anim: _pricingAnim,
      child: Column(
        children: [
          _sectionHeader(
            null,
            'Sin mensualidades. 0% comision hasta que te enviemos tu primer cliente.',
            richTitle: Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Nuestros precios ', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: _textPrimary)),
              ]),
              textAlign: TextAlign.center,
            ),
            richTitleSuffix: const _GradientText('(spoiler: es gratis)', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 40),
          // Pricing card with gradient border
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              decoration: BoxDecoration(
                gradient: _brandGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: _brandPurple.withValues(alpha: 0.1), blurRadius: 40, offset: const Offset(0, 8))],
              ),
              padding: const EdgeInsets.all(2), // gradient border width
              child: Container(
                padding: EdgeInsets.all(isMobile ? 28 : 48),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    const Text('Plan Profesional', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: _textPrimary)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: const [
                        Text('\$0', style: TextStyle(fontSize: 56, fontWeight: FontWeight.w800, color: _textPrimary)),
                        SizedBox(width: 8),
                        Text('MXN / mes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: _textHint)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Otros cobran \$299 - \$4,500/mes',
                      style: TextStyle(fontSize: 14, color: _textHint, decoration: TextDecoration.lineThrough),
                    ),
                    const SizedBox(height: 32),
                    // Feature checklist
                    ...features.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: Color(0xFFF9F4EF))),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: _checkGreen.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Text('\u2713', style: TextStyle(color: _checkGreen, fontSize: 13, fontWeight: FontWeight.w700)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(f, style: const TextStyle(fontSize: 15, color: Color(0xFF444444)))),
                          ],
                        ),
                      ),
                    )),
                    const SizedBox(height: 28),
                    const Text(
                      'Usa todo gratis desde hoy. Solo cobramos 3% cuando\nte enviemos un cliente nuevo por nuestra plataforma.\nTus propios clientes: 0% comision. Siempre.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: _textHint, height: 1.6),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: _HoverScaleButton(
                        onTap: () => _scrollToSection(_demoKey),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: _brandGradient,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Text('Comienza ahora', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Download CTA ───────────────────────────────────────────────────────────

  Widget _buildDownload(bool isDesktop, bool isMobile) {
    return Container(
      key: _downloadKey,
      width: double.infinity,
      decoration: const BoxDecoration(gradient: _brandGradient),
      child: _SectionWrapper(
        anim: _downloadAnim,
        padding: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: isDesktop ? 100 : 60, horizontal: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: Column(
                children: [
                  Text(
                    'Descarga BeautyCita',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: isMobile ? 28 : 42, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Disponible para Android. iOS proximamente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.white.withValues(alpha: 0.85)),
                  ),
                  const SizedBox(height: 40),
                  // Download buttons
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      _downloadBtn(Icons.play_arrow, 'Google Play (proximamente)', null),
                      _downloadBtn(Icons.download, 'Descarga APK directa', _apkUrl),
                    ],
                  ),
                  const SizedBox(height: 40),
                  // QR code — real scannable data, styled like original design
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: CustomPaint(
                        size: const Size(100, 100),
                        painter: _StyledQrPainter('HTTPS://BEAUTYCITA.COM/D'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.share_outlined, size: 18, color: Colors.white.withValues(alpha: 0.8)),
                      const SizedBox(width: 8),
                      Text(
                        'Reenvia este mensaje a un amigo que tenga salon',
                        style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.8)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _downloadBtn(IconData icon, String label, String? url) {
    return _HoverScaleButton(
      onTap: url != null ? () => _launchUrl(url) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────

  Widget _buildFooter(bool isDesktop, bool isMobile) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1A1A), Color(0xFF0D0D0D)],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: isDesktop ? 60 : 40),
            child: Column(
              children: [
                isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Brand column
                          Expanded(child: _footerBrand()),
                          // Links columns
                          Expanded(flex: 2, child: _footerLinks(isMobile)),
                          // Contact column
                          Expanded(child: _footerContact()),
                        ],
                      )
                    : Column(
                        children: [
                          _footerBrand(),
                          const SizedBox(height: 32),
                          _footerLinks(isMobile),
                          const SizedBox(height: 32),
                          _footerContact(),
                        ],
                      ),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.only(top: 24),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                  ),
                  child: isMobile
                      ? Column(
                          children: [
                            Text('BeautyCita S.A. de C.V. -- Puerto Vallarta, Jalisco, Mexico', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.3))),
                            const SizedBox(height: 8),
                            Text('2026 BeautyCita. Todos los derechos reservados.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.3))),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('BeautyCita S.A. de C.V. -- Puerto Vallarta, Jalisco, Mexico', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.3))),
                            Text('2026 BeautyCita. Todos los derechos reservados.', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.3))),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _footerBrand() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network('img/bc_logo.png', width: 32, height: 32, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          ),
          const SizedBox(width: 10),
          Text.rich(TextSpan(children: [
            const TextSpan(text: 'Beauty', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
            TextSpan(text: 'Cita', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _brandPink)),
          ])),
        ]),
        const SizedBox(height: 12),
        Text(
          'La plataforma inteligente que conecta clientes con el salon perfecto. Hecha en Mexico, para Mexico.',
          style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.5), height: 1.6),
        ),
        const SizedBox(height: 16),
        // Social icons
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _socialIcon(Icons.camera_alt_outlined), // Instagram
            const SizedBox(width: 12),
            _socialIcon(Icons.facebook_outlined), // Facebook
            const SizedBox(width: 12),
            _socialIcon(Icons.music_note_outlined), // TikTok
          ],
        ),
      ],
    );
  }

  Widget _socialIcon(IconData icon) {
    return _HoverContainer(
      normalDecoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      hoverDecoration: BoxDecoration(
        color: _brandPink.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Center(child: Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.6))),
      ),
    );
  }

  Widget _footerLinks(bool isMobile) {
    return Wrap(
      spacing: 60,
      runSpacing: 32,
      children: [
        _footerCol('Plataforma', [
          _FooterLink('Para Salones', key: _forSalonsKey),
          _FooterLink('Por que BeautyCita?', route: '/porque-beautycita'),
          _FooterLink('Para Clientes', key: _forClientsKey),
          _FooterLink('Precios', key: _pricingKey),
          _FooterLink('Demo', key: _demoKey),
        ]),
        _footerCol('Empresa', [
          _FooterLink('Sobre nosotros'),
          _FooterLink('Terminos', route: '/terminos'),
          _FooterLink('Privacidad', route: '/privacidad'),
          _FooterLink('Contacto'),
        ]),
        _footerCol('Soporte', [
          _FooterLink('Centro de ayuda'),
          _FooterLink('WhatsApp'),
          _FooterLink('soporte@beautycita.com'),
        ]),
      ],
    );
  }

  Widget _footerCol(String title, List<_FooterLink> links) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 16),
        ...links.map((l) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                if (l.key != null) {
                  _scrollToSection(l.key!);
                } else if (l.route != null) {
                  context.go(l.route!);
                }
              },
              child: Text(l.label, style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.5))),
            ),
          ),
        )),
      ],
    );
  }

  Widget _footerContact() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Contacto', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.5))),
        const SizedBox(height: 8),
        Text('+52 (720) 677-7800', style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _sectionHeader(String? title, String subtitle, {Widget? richTitle, Widget? richTitleSuffix}) {
    return Column(
      children: [
        if (title != null)
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: _textPrimary)),
        if (richTitle != null) ...[
          richTitle,
          if (richTitleSuffix != null) richTitleSuffix,
        ],
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, color: _textSecondary)),
        ),
      ],
    );
  }

  void _launchUrl(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

// ── Section Wrapper (fade+slide animation) ───────────────────────────────────

class _SectionWrapper extends StatelessWidget {
  final GlobalKey? sectionKey;
  final AnimationController anim;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _SectionWrapper({
    this.sectionKey,
    required this.anim,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final defaultPadding = const EdgeInsets.symmetric(vertical: 100, horizontal: 24);
    return SizedBox(
      key: sectionKey,
      width: double.infinity,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: Padding(
            padding: padding ?? defaultPadding,
            child: FadeTransition(
              opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
                    .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hover Scale Button ───────────────────────────────────────────────────────

class _HoverScaleButton extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;
  const _HoverScaleButton({this.onTap, required this.child});
  @override
  State<_HoverScaleButton> createState() => _HoverScaleButtonState();
}

class _HoverScaleButtonState extends State<_HoverScaleButton> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovered ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              boxShadow: _hovered
                  ? [BoxShadow(color: _brandPurple.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 4))]
                  : [],
              borderRadius: BorderRadius.circular(16),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

// ── Hover Container (for footer social icons etc) ────────────────────────────

class _HoverContainer extends StatefulWidget {
  final BoxDecoration normalDecoration;
  final BoxDecoration hoverDecoration;
  final Widget child;
  const _HoverContainer({required this.normalDecoration, required this.hoverDecoration, required this.child});
  @override
  State<_HoverContainer> createState() => _HoverContainerState();
}

class _HoverContainerState extends State<_HoverContainer> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: _hovered ? widget.hoverDecoration : widget.normalDecoration,
        child: widget.child,
      ),
    );
  }
}

// ── Phone Mockup (floating) ──────────────────────────────────────────────────

class _PhoneFloating extends StatefulWidget {
  final Widget child;
  const _PhoneFloating({required this.child});
  @override
  State<_PhoneFloating> createState() => _PhoneFloatingState();
}

class _PhoneFloatingState extends State<_PhoneFloating> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 3500))..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: 0, end: -10).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
      animation: _floatAnim,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _floatAnim.value),
        child: child,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: _textPrimary,
          borderRadius: BorderRadius.circular(36),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 60, offset: const Offset(0, 24))],
        ),
        padding: const EdgeInsets.all(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
          ),
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 0.5,
            child: widget.child,
          ),
        ),
      ),
    ),
    );
  }
}

// ── Comparison Row Widget ────────────────────────────────────────────────────

enum _CellType { check, checkText, free, warn, cross, plain }

class _CompRow {
  final String feature;
  final String? bcText;
  final String col2Text;
  final String col3Text;
  final _CellType bcType;
  final _CellType col2Type;
  final _CellType col3Type;
  const _CompRow(this.feature, this.bcText, this.col2Text, this.col3Text,
      {this.bcType = _CellType.check, this.col2Type = _CellType.plain, this.col3Type = _CellType.plain});
}

class _ComparisonRow extends StatefulWidget {
  final _CompRow row;
  final bool isEven;
  const _ComparisonRow({required this.row, required this.isEven});
  @override
  State<_ComparisonRow> createState() => _ComparisonRowState();
}

class _ComparisonRowState extends State<_ComparisonRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = _hovered
        ? _brandPurple.withValues(alpha: 0.03)
        : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        color: bgColor,
        child: Row(
          children: [
            // Feature name
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _cardBorder)),
                ),
                child: Text(widget.row.feature, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textPrimary)),
              ),
            ),
            // BC column (clean, no background tint)
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _cardBorder)),
                ),
                child: Center(child: _buildCell(widget.row.bcType, widget.row.bcText)),
              ),
            ),
            // AgendaPro
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _cardBorder)),
                ),
                child: Center(child: _buildCell(widget.row.col2Type, widget.row.col2Text)),
              ),
            ),
            // Booksy
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _cardBorder)),
                ),
                child: Center(child: _buildCell(widget.row.col3Type, widget.row.col3Text)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(_CellType type, String? text) {
    switch (type) {
      case _CellType.check:
        return const Text('\u2713', style: TextStyle(color: _checkGreen, fontWeight: FontWeight.w700, fontSize: 18));
      case _CellType.checkText:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('\u2713 ', style: TextStyle(color: _checkGreen, fontWeight: FontWeight.w700, fontSize: 18)),
            Flexible(child: Text(text ?? '', style: const TextStyle(fontSize: 14, color: _textSecondary))),
          ],
        );
      case _CellType.free:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_checkGreen.withValues(alpha: 0.1), _checkGreen.withValues(alpha: 0.05)]),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(text ?? 'GRATIS', style: const TextStyle(color: _checkGreen, fontWeight: FontWeight.w700, fontSize: 13)),
        );
      case _CellType.warn:
        return Text(text ?? '', style: const TextStyle(color: _warnAmber, fontWeight: FontWeight.w600, fontSize: 13));
      case _CellType.cross:
        return Text(text ?? 'No', style: const TextStyle(color: _crossRed, fontWeight: FontWeight.w600));
      case _CellType.plain:
        return Text(text ?? '', style: const TextStyle(fontSize: 14, color: _textSecondary));
    }
  }
}

// ── Feature Card (For Salons) ────────────────────────────────────────────────

class _Feature {
  final IconData icon;
  final String title;
  final String description;
  final String detailTitle;
  final List<String> detailBullets;
  final String? detailNote;
  const _Feature(this.icon, this.title, this.description, {
    required this.detailTitle,
    required this.detailBullets,
    this.detailNote,
  });
}

class _FeatureCard extends StatefulWidget {
  final _Feature feature;
  final void Function(Offset globalPosition)? onTapUp;
  const _FeatureCard({required this.feature, this.onTapUp});
  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapUp: (details) => widget.onTapUp?.call(details.globalPosition),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _cardBorder),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [_hovered ? _cardShadowHover : _cardShadow],
          ),
          transform: _hovered ? (Matrix4.translationValues(0.0, -4.0, 0.0)) : Matrix4.identity(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_brandPink.withValues(alpha: 0.1), _brandPurple.withValues(alpha: 0.1)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(child: Icon(widget.feature.icon, color: _brandPurple, size: 24)),
              ),
              const SizedBox(height: 16),
              Text(widget.feature.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary)),
              const SizedBox(height: 8),
              Text(widget.feature.description, style: const TextStyle(fontSize: 14, color: _textSecondary, height: 1.6)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Circle Clipper (Radial Burst) ────────────────────────────────────────────

class _CircleClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;
  _CircleClipper({required this.center, required this.radius});

  @override
  Path getClip(Size size) =>
      Path()..addOval(Rect.fromCircle(center: center, radius: radius));

  @override
  bool shouldReclip(covariant _CircleClipper old) =>
      old.radius != radius || old.center != center;
}

// ── Feature Detail Popup ─────────────────────────────────────────────────────

class _FeatureDetailPopup extends StatelessWidget {
  final _Feature feature;
  final VoidCallback? onDemo;
  const _FeatureDetailPopup({required this.feature, this.onDemo});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
                BoxShadow(
                  color: _brandPurple.withValues(alpha: 0.08),
                  blurRadius: 60,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                _brandPink.withValues(alpha: 0.15),
                                _brandPurple.withValues(alpha: 0.15),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Center(
                            child: Icon(feature.icon, color: _brandPurple, size: 30),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _GradientText(
                              feature.detailTitle,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: _cardBorder),
                            ),
                            child: const Center(
                              child: Icon(Icons.close, size: 18, color: _textSecondary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Scrollable bullet list
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...feature.detailBullets.map((bullet) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 7),
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [_brandPink, _brandPurple],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    bullet,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: _textPrimary,
                                      height: 1.7,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                          // Optional note
                          if (feature.detailNote != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _brandPurple.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _brandPurple.withValues(alpha: 0.12),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: _brandPurple.withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      feature.detailNote!,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _textSecondary,
                                        height: 1.6,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // CTA buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: GestureDetector(
                            onTap: onDemo,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                gradient: _brandGradient,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: _brandPink.withValues(alpha: 0.3),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text(
                                  'Probar Demo',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).pop();
                              GoRouter.of(context).go('/demo');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _brandPurple.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Ver en el demo',
                                  style: TextStyle(
                                    color: _brandPurple,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Client Card ──────────────────────────────────────────────────────────────

class _ClientCard {
  final IconData icon;
  final String title;
  final String description;
  const _ClientCard(this.icon, this.title, this.description);
}

class _ClientCardWidget extends StatefulWidget {
  final _ClientCard card;
  const _ClientCardWidget({required this.card});
  @override
  State<_ClientCardWidget> createState() => _ClientCardWidgetState();
}

class _ClientCardWidgetState extends State<_ClientCardWidget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _cardBorder),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [_hovered ? _cardShadowHover : _cardShadow],
        ),
        transform: _hovered ? (Matrix4.translationValues(0.0, -4.0, 0.0)) : Matrix4.identity(),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_brandPink.withValues(alpha: 0.1), _brandPurple.withValues(alpha: 0.1)],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(child: Icon(widget.card.icon, color: _brandPurple, size: 28)),
            ),
            const SizedBox(height: 20),
            Text(widget.card.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _textPrimary)),
            const SizedBox(height: 12),
            Text(widget.card.description, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: _textSecondary, height: 1.7)),
          ],
        ),
      ),
    );
  }
}

// ── Testimonial Card ─────────────────────────────────────────────────────────

class _Testimonial {
  final String initials;
  final String name;
  final String role;
  final String text;
  const _Testimonial(this.initials, this.name, this.role, this.text);
}

class _TestimonialCard extends StatefulWidget {
  final _Testimonial testimonial;
  const _TestimonialCard({required this.testimonial});
  @override
  State<_TestimonialCard> createState() => _TestimonialCardState();
}

class _TestimonialCardState extends State<_TestimonialCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _cardBorder),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [_hovered ? _cardShadowHover : _cardShadow],
        ),
        transform: _hovered ? (Matrix4.translationValues(0.0, -2.0, 0.0)) : Matrix4.identity(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stars
            Row(
              children: List.generate(5, (_) => const Padding(
                padding: EdgeInsets.only(right: 2),
                child: Icon(Icons.star, color: _warnAmber, size: 16),
              )),
            ),
            const SizedBox(height: 16),
            Text(
              widget.testimonial.text,
              style: const TextStyle(fontSize: 15, color: Color(0xFF444444), height: 1.7, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_brandPink.withValues(alpha: 0.2), _brandPurple.withValues(alpha: 0.2)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(widget.testimonial.initials, style: const TextStyle(fontWeight: FontWeight.w700, color: _brandPurple, fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.testimonial.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _textPrimary)),
                    Text(widget.testimonial.role, style: const TextStyle(fontSize: 13, color: _textHint)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Demo Phone Input ─────────────────────────────────────────────────────────

class _DemoPhoneInput extends StatefulWidget {
  final TextEditingController controller;
  final String? error;
  const _DemoPhoneInput({required this.controller, this.error});
  @override
  State<_DemoPhoneInput> createState() => _DemoPhoneInputState();
}

class _DemoPhoneInputState extends State<_DemoPhoneInput> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focused ? _brandPurple : _cardBorder,
          width: 2,
        ),
        boxShadow: _focused
            ? [BoxShadow(color: _brandPurple.withValues(alpha: 0.1), blurRadius: 8, spreadRadius: 2)]
            : [],
      ),
      child: Focus(
        onFocusChange: (f) => setState(() => _focused = f),
        child: TextField(
          controller: widget.controller,
          keyboardType: TextInputType.phone,
          style: const TextStyle(fontSize: 16, color: _textPrimary),
          decoration: InputDecoration(
            hintText: '+52 (___) ___-____',
            hintStyle: const TextStyle(color: Color(0xFFBBBBBB)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            border: InputBorder.none,
            errorText: null,
          ),
          onChanged: (value) {
            // Format phone number
            String v = value.replaceAll(RegExp(r'\D'), '');
            if (v.startsWith('52')) v = v.substring(2);
            if (v.length > 10) v = v.substring(0, 10);
            String formatted = '+52 ';
            if (v.isNotEmpty) formatted += '(${v.substring(0, v.length.clamp(0, 3))}';
            if (v.length >= 3) formatted += ') ${v.substring(3, v.length.clamp(3, 6))}';
            if (v.length >= 6) formatted += '-${v.substring(6, v.length.clamp(6, 10))}';

            if (formatted != value) {
              widget.controller.value = TextEditingValue(
                text: formatted,
                selection: TextSelection.collapsed(offset: formatted.length),
              );
            }
          },
        ),
      ),
    );
  }
}

// ── QR Placeholder Painter ───────────────────────────────────────────────────

class _StyledQrPainter extends CustomPainter {
  final String data;
  _StyledQrPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final qrCode = QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M);
    final qrImage = QrImage(qrCode);
    final moduleCount = qrImage.moduleCount;
    final dark = Paint()..color = _textPrimary;
    final white = Paint()..color = Colors.white;
    final cellSize = size.width / moduleCount;
    final radius = Radius.circular(cellSize * 0.3);

    // Draw data modules (skip finder pattern areas — we draw those custom)
    for (int row = 0; row < moduleCount; row++) {
      for (int col = 0; col < moduleCount; col++) {
        // Skip the 3 finder pattern regions (7x7 + 1 separator)
        if (_isFinderPattern(row, col, moduleCount)) continue;

        if (qrImage.isDark(row, col)) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(col * cellSize, row * cellSize, cellSize, cellSize),
              radius,
            ),
            dark,
          );
        }
      }
    }

    // Draw styled corner finder patterns (same rounded style as original)
    final finderSize = 7 * cellSize;
    _drawCornerSquare(canvas, 0, 0, finderSize, dark, white);
    _drawCornerSquare(canvas, (moduleCount - 7) * cellSize, 0, finderSize, dark, white);
    _drawCornerSquare(canvas, 0, (moduleCount - 7) * cellSize, finderSize, dark, white);
  }

  bool _isFinderPattern(int row, int col, int count) {
    // Top-left 8x8
    if (row < 8 && col < 8) return true;
    // Top-right 8x8
    if (row < 8 && col >= count - 8) return true;
    // Bottom-left 8x8
    if (row >= count - 8 && col < 8) return true;
    return false;
  }

  void _drawCornerSquare(Canvas canvas, double x, double y, double size, Paint dark, Paint white) {
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, size, size), const Radius.circular(3)), dark);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + size * 0.2, y + size * 0.2, size * 0.6, size * 0.6), const Radius.circular(2)), white);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + size * 0.32, y + size * 0.32, size * 0.36, size * 0.36), const Radius.circular(1)), dark);
  }

  @override
  bool shouldRepaint(covariant _StyledQrPainter oldDelegate) => oldDelegate.data != data;
}

// ── Footer Link Model ────────────────────────────────────────────────────────

class _FooterLink {
  final String label;
  final GlobalKey? key;
  final String? route;
  const _FooterLink(this.label, {this.key, this.route});
}
