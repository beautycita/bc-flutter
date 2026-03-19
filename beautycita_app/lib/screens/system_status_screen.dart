import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/constants.dart';
import '../config/theme_extension.dart';
import '../providers/admin_provider.dart';
import '../services/supabase_client.dart';

// ─────────────────────────────────────────────────────────────
// System Status Screen — live monitoring via system-health edge function
// ─────────────────────────────────────────────────────────────

class SystemStatusScreen extends ConsumerStatefulWidget {
  const SystemStatusScreen({super.key});

  @override
  ConsumerState<SystemStatusScreen> createState() => _SystemStatusScreenState();
}

class _SystemStatusScreenState extends ConsumerState<SystemStatusScreen> {
  bool _loading = true;
  bool _error = false;
  String _overall = 'unknown';
  Map<String, dynamic> _services = {};
  String? _checkedAt;

  @override
  void initState() {
    super.initState();
    _fetchHealth();
  }

  Future<void> _fetchHealth() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final response = await Supabase.instance.client.functions
          .invoke('system-health');
      final data = response.data as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _overall = (data['overall'] as String?) ?? 'unknown';
        _services =
            (data['services'] as Map<String, dynamic>?) ?? {};
        _checkedAt = data['checked_at'] as String?;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Estado del sistema',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchHealth,
        color: colorScheme.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.screenPaddingHorizontal,
            vertical: AppConstants.paddingMD,
          ),
          children: [
            // ── Hero Status Card ──
            if (_loading)
              _ShimmerCard(ext: ext, height: 140)
            else if (_error)
              _ErrorCard(
                colorScheme: colorScheme,
                onRetry: _fetchHealth,
              )
            else
              _HeroCard(overall: _overall, ext: ext),

            const SizedBox(height: AppConstants.paddingLG),

            // ── Services Section Header ──
            if (!_error) ...[
              Padding(
                padding: const EdgeInsets.only(
                    left: 2, bottom: AppConstants.paddingSM),
                child: Text(
                  'SERVICIOS',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: colorScheme.primary,
                  ),
                ),
              ),

              // ── Service Cards ──
              if (_loading)
                ...List.generate(
                  5,
                  (_) => Padding(
                    padding:
                        const EdgeInsets.only(bottom: AppConstants.paddingSM),
                    child: _ShimmerCard(ext: ext, height: 72),
                  ),
                )
              else
                ..._services.entries.map(
                  (entry) => Padding(
                    padding:
                        const EdgeInsets.only(bottom: AppConstants.paddingSM),
                    child: _ServiceCard(
                      name: entry.key,
                      status: _parseStatus(entry.value),
                      uptime: _parseUptime(entry.value),
                      ext: ext,
                    ),
                  ),
                ),
            ],

            const SizedBox(height: AppConstants.paddingLG),

            // ── Smoke Test (admin only) ──
            _SmokeTestSection(ref: ref),

            const SizedBox(height: AppConstants.paddingLG),

            // ── Last checked timestamp ──
            if (_checkedAt != null && !_loading && !_error)
              Center(
                child: Text(
                  'Ultima verificacion: ${_formatTimestamp(_checkedAt!)}',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ),

            const SizedBox(height: AppConstants.paddingSM),

            // ── Footer ──
            Center(
              child: Text(
                'Para reportar un problema, contacta\nsoporte@beautycita.com',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: colorScheme.onSurface.withValues(alpha: 0.45),
                  height: 1.6,
                ),
              ),
            ),

            const SizedBox(height: AppConstants.paddingLG),
          ],
        ),
      ),
    );
  }

  String _parseStatus(dynamic value) {
    if (value is Map<String, dynamic>) {
      return (value['status'] as String?) ?? 'unknown';
    }
    return 'unknown';
  }

  String _parseUptime(dynamic value) {
    if (value is Map<String, dynamic>) {
      return (value['uptime'] as String?) ?? '';
    }
    return '';
  }

  String _formatTimestamp(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final mo = dt.month.toString().padLeft(2, '0');
      return '$d/$mo/${dt.year} $h:$m';
    } catch (_) {
      return iso;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Hero Card — overall status
// ─────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.overall, required this.ext});

  final String overall;
  final BCThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final (gradient, icon, dotColor, label) = switch (overall) {
      'operational' => (
          const LinearGradient(
            colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          Icons.check_circle_rounded,
          const Color(0xFF4ADE80),
          'Todos los sistemas operativos',
        ),
      'degraded' => (
          const LinearGradient(
            colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          Icons.warning_rounded,
          const Color(0xFFFCD34D),
          'Algunos servicios con problemas',
        ),
      'down' => (
          const LinearGradient(
            colors: [Color(0xFFDC2626), Color(0xFFF87171)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          Icons.error_rounded,
          const Color(0xFFFCA5A5),
          'Problemas detectados',
        ),
      _ => (
          ext.primaryGradient,
          Icons.help_outline_rounded,
          Colors.white70,
          'Estado desconocido',
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingLG,
        vertical: AppConstants.paddingXL,
      ),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: AppConstants.iconSizeLG,
            ),
          ),
          const SizedBox(height: AppConstants.paddingMD),
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: dotColor.withValues(alpha: 0.5),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppConstants.paddingSM),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Error Card with retry
// ─────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.colorScheme, required this.onRetry});

  final ColorScheme colorScheme;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.paddingLG),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(
          color: colorScheme.error.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: AppConstants.iconSizeXL,
            color: colorScheme.error.withValues(alpha: 0.6),
          ),
          const SizedBox(height: AppConstants.paddingMD),
          Text(
            'No se pudo verificar el estado',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppConstants.paddingSM),
          Text(
            'Verifica tu conexion e intenta de nuevo',
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: AppConstants.paddingMD),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(
              'Reintentar',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Service Card — individual service row
// ─────────────────────────────────────────────────────────────

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.name,
    required this.status,
    required this.uptime,
    required this.ext,
  });

  final String name;
  final String status;
  final String uptime;
  final BCThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final (badgeColor, badgeBg, badgeBorder, badgeLabel, dotColor, statusIcon) =
        switch (status) {
      'operational' => (
          const Color(0xFF16A34A),
          const Color(0xFFF0FDF4),
          const Color(0xFFBBF7D0),
          'Operativo',
          const Color(0xFF22C55E),
          Icons.check_circle_outline_rounded,
        ),
      'degraded' => (
          const Color(0xFFD97706),
          const Color(0xFFFFFBEB),
          const Color(0xFFFDE68A),
          'Degradado',
          const Color(0xFFF59E0B),
          Icons.warning_amber_rounded,
        ),
      'down' => (
          const Color(0xFFDC2626),
          const Color(0xFFFEF2F2),
          const Color(0xFFFECACA),
          'Fuera de linea',
          const Color(0xFFEF4444),
          Icons.cancel_outlined,
        ),
      _ => (
          const Color(0xFF6B7280),
          const Color(0xFFF9FAFB),
          const Color(0xFFE5E7EB),
          'Desconocido',
          const Color(0xFF9CA3AF),
          Icons.help_outline_rounded,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMD,
        vertical: AppConstants.paddingMD,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: ext.cardBorderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Status icon
          Icon(statusIcon, color: dotColor, size: AppConstants.iconSizeMD),
          const SizedBox(width: AppConstants.paddingMD),

          // Name + uptime
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (uptime.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    uptime.contains('ms')
                        ? 'Respuesta: $uptime'
                        : 'Disponibilidad 30d: $uptime%',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: AppConstants.paddingSM),

          // Status badge chip
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingSM,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: badgeBg,
              border: Border.all(color: badgeBorder, width: 1),
              borderRadius: BorderRadius.circular(AppConstants.radiusFull),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  badgeLabel,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shimmer Loading Card
// ─────────────────────────────────────────────────────────────

class _ShimmerCard extends StatefulWidget {
  const _ShimmerCard({required this.ext, required this.height});

  final BCThemeExtension ext;
  final double height;

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppConstants.shimmerAnimation,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusMD),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
              end: Alignment(1.0 + 2.0 * _controller.value, 0),
              colors: [
                widget.ext.shimmerColor.withValues(alpha: 0.3),
                widget.ext.shimmerColor.withValues(alpha: 0.6),
                widget.ext.shimmerColor.withValues(alpha: 0.3),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Smoke Test Section — admin only, tests live flows
// ─────────────────────────────────────────────────────────────

class _SmokeTestSection extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _SmokeTestSection({required this.ref});

  @override
  ConsumerState<_SmokeTestSection> createState() => _SmokeTestSectionState();
}

class _SmokeTestSectionState extends ConsumerState<_SmokeTestSection> {
  bool _running = false;
  final List<_TestResult> _results = [];

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider).valueOrNull ?? false;
    if (!isAdmin) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: AppConstants.paddingSM),
          child: Row(
            children: [
              Text(
                'DIAGNOSTICO',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: colorScheme.primary,
                ),
              ),
              const Spacer(),
              if (!_running)
                TextButton.icon(
                  onPressed: _runSmokeTests,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: Text('Ejecutar', style: GoogleFonts.poppins(fontSize: 12)),
                ),
            ],
          ),
        ),
        if (_running && _results.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        if (_results.isNotEmpty)
          ...(_results.map((r) => _TestResultTile(result: r))),
        if (!_running && _results.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Text(
              'Toca "Ejecutar" para verificar que todos los flujos funcionan correctamente.',
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Future<void> _runSmokeTests() async {
    setState(() {
      _running = true;
      _results.clear();
    });

    final client = SupabaseClientService.client;

    // Test 1: DB read
    await _test('Base de datos (lectura)', () async {
      final res = await client.from('app_config').select('key').limit(1);
      if ((res as List).isEmpty) throw Exception('No config rows');
    });

    // Test 2: DB write (insert + delete a test row)
    await _test('Base de datos (escritura)', () async {
      final res = await client.from('contact_submissions').insert({
        'name': '_smoke_test_',
        'email': 'test@smoke.test',
        'subject': 'Smoke test',
        'message': 'Auto-generated smoke test — safe to delete',
      }).select('id').single();
      final id = res['id'] as String;
      await client.from('contact_submissions').delete().eq('id', id);
    });

    // Test 3: Auth check
    await _test('Autenticacion', () async {
      final user = client.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');
    });

    // Test 4: Edge function invocation
    await _test('Edge functions', () async {
      final res = await client.functions.invoke('system-health');
      if (res.status != 200) throw Exception('HTTP ${res.status}');
    });

    // Test 5: Feed public (unauthenticated endpoint)
    await _test('Feed publico', () async {
      final res = await client.functions.invoke('feed-public', body: {
        'action': 'feed',
        'limit': 1,
      });
      if (res.status != 200) throw Exception('HTTP ${res.status}');
    });

    // Test 6: Curate results (booking engine)
    await _test('Motor de reservas', () async {
      final res = await client.functions.invoke('curate-results', body: {
        'lat': 20.6534,
        'lng': -105.2253,
        'service_type': 'corte_cabello',
        'limit': 1,
      });
      if (res.status != 200) throw Exception('HTTP ${res.status}');
    });

    // Test 7: Outreach discovered salons (search)
    await _test('Busqueda de salones', () async {
      final res = await client.functions.invoke('outreach-discovered-salon', body: {
        'action': 'search',
        'query': 'test',
        'lat': 20.6534,
        'lng': -105.2253,
      });
      if (res.status != 200) throw Exception('HTTP ${res.status}');
    });

    // Test 8: Storage access
    await _test('Almacenamiento', () async {
      final buckets = await client.storage.listBuckets();
      if (buckets.isEmpty) throw Exception('No buckets');
    });

    // Test 9: Profile read
    await _test('Perfil de usuario', () async {
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception('No user');
      final res = await client.from('profiles').select('id, role').eq('id', userId).single();
      if (res['role'] == null) throw Exception('No role');
    });

    // Test 10: Outreach templates
    await _test('Plantillas de outreach', () async {
      final res = await client.functions.invoke('outreach-contact', body: {
        'action': 'get_templates',
      });
      if (res.status != 200) throw Exception('HTTP ${res.status}');
    });

    setState(() => _running = false);
  }

  Future<void> _test(String name, Future<void> Function() check) async {
    final start = DateTime.now();
    try {
      await check().timeout(const Duration(seconds: 15));
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      setState(() => _results.add(_TestResult(
        name: name,
        passed: true,
        elapsed: elapsed,
      )));
    } catch (e) {
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      setState(() => _results.add(_TestResult(
        name: name,
        passed: false,
        elapsed: elapsed,
        error: e.toString(),
      )));
    }
  }
}

class _TestResult {
  final String name;
  final bool passed;
  final int elapsed;
  final String? error;

  const _TestResult({
    required this.name,
    required this.passed,
    required this.elapsed,
    this.error,
  });
}

class _TestResultTile extends StatelessWidget {
  final _TestResult result;
  const _TestResultTile({required this.result, super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: result.passed ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            result.passed ? Icons.check_circle : Icons.cancel,
            size: 18,
            color: result.passed ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.name,
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                if (result.error != null)
                  Text(result.error!,
                      style: GoogleFonts.nunito(
                          fontSize: 11, color: Colors.red.shade700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Text('${result.elapsed}ms',
              style: GoogleFonts.nunito(
                  fontSize: 11,
                  color: colorScheme.onSurface.withValues(alpha: 0.4))),
        ],
      ),
    );
  }
}
