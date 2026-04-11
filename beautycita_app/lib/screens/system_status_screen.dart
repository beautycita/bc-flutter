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

// Map display names to bpi-admin service IDs (only for manageable services)
const _bpiServiceMap = {
  'Lead Generator': 'lead-generator',
  'WA Enrichment': 'wa-enrichment',
  'IG Enrichment': 'ig-enrichment',
  'GuestKey': 'guestkey',
  'WA Validator': 'wa-validator',
};

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
                      bpiServiceId: _bpiServiceMap[entry.key],
                      onRefresh: _fetchHealth,
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
    final colorScheme = Theme.of(context).colorScheme;
    final (gradient, icon, dotColor, label) = switch (overall) {
      'operational' => (
          LinearGradient(
            colors: [ext.successColor, ext.successColor.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          Icons.check_circle_rounded,
          ext.successColor.withValues(alpha: 0.6),
          'Todos los sistemas operativos',
        ),
      'degraded' => (
          LinearGradient(
            colors: [ext.warningColor, ext.warningColor.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          Icons.warning_rounded,
          ext.warningColor.withValues(alpha: 0.6),
          'Algunos servicios con problemas',
        ),
      'down' => (
          LinearGradient(
            colors: [colorScheme.error, colorScheme.error.withValues(alpha: 0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          Icons.error_rounded,
          colorScheme.error.withValues(alpha: 0.5),
          'Problemas detectados',
        ),
      _ => (
          ext.primaryGradient,
          Icons.help_outline_rounded,
          Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
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
              color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.onPrimary,
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
                    color: Theme.of(context).colorScheme.onPrimary,
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

class _ServiceCard extends ConsumerStatefulWidget {
  const _ServiceCard({
    required this.name,
    required this.status,
    required this.uptime,
    required this.ext,
    this.bpiServiceId,
    this.onRefresh,
  });

  final String name;
  final String status;
  final String uptime;
  final BCThemeExtension ext;
  final String? bpiServiceId;
  final VoidCallback? onRefresh;

  @override
  ConsumerState<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends ConsumerState<_ServiceCard> {
  bool _actionLoading = false;
  String? _actionResult;

  Future<void> _autoRepair() async {
    setState(() {
      _actionLoading = true;
      _actionResult = null;
    });
    try {
      if (widget.bpiServiceId != null) {
        // Beautypi service — use bpi-admin repair action
        final res = await Supabase.instance.client.functions.invoke(
          'bpi-admin',
          body: {'action': 'repair', 'service': widget.bpiServiceId},
        );
        final data = res.data as Map<String, dynamic>?;
        final result = data?['result'] as Map<String, dynamic>?;
        final success = result?['success'] == true;
        final msg = result?['message'] ?? (success ? 'Reparado' : 'Fallo');
        if (mounted) {
          setState(() {
            _actionLoading = false;
            _actionResult = success
                ? 'Servicio reparado y funcionando'
                : 'No se pudo reparar automaticamente.\n$msg\n${result?['error_output'] ?? ''}';
          });
        }
      } else {
        // Server service (DB, Auth, Storage, etc.) — restart edge functions
        // For now, just re-check health
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          setState(() {
            _actionLoading = false;
            _actionResult = 'Verificando servicio...';
          });
        }
      }
      await Future.delayed(const Duration(seconds: 2));
      widget.onRefresh?.call();
    } catch (e) {
      if (mounted) {
        setState(() {
          _actionLoading = false;
          _actionResult = 'Error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSuperAdmin = ref.watch(isSuperAdminProvider).valueOrNull ?? false;
    final isDown = widget.status == 'down' || widget.status == 'degraded';
    final canRepair = isSuperAdmin && isDown && widget.bpiServiceId != null;

    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    final (badgeColor, badgeBg, badgeBorder, badgeLabel, dotColor, statusIcon) =
        switch (widget.status) {
      'operational' => (
          ext.successColor,
          ext.successColor.withValues(alpha: 0.08),
          ext.successColor.withValues(alpha: 0.3),
          'Operativo',
          ext.successColor,
          Icons.check_circle_outline_rounded,
        ),
      'degraded' => (
          ext.warningColor,
          ext.warningColor.withValues(alpha: 0.08),
          ext.warningColor.withValues(alpha: 0.3),
          'Degradado',
          ext.warningColor,
          Icons.warning_amber_rounded,
        ),
      'down' => (
          colorScheme.error,
          colorScheme.error.withValues(alpha: 0.06),
          colorScheme.error.withValues(alpha: 0.3),
          'Fuera de linea',
          colorScheme.error,
          Icons.cancel_outlined,
        ),
      _ => (
          colorScheme.onSurface.withValues(alpha: 0.5),
          colorScheme.surface,
          colorScheme.onSurface.withValues(alpha: 0.15),
          'Desconocido',
          colorScheme.onSurface.withValues(alpha: 0.4),
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
        border: Border.all(color: widget.ext.cardBorderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: dotColor, size: AppConstants.iconSizeMD),
              const SizedBox(width: AppConstants.paddingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (widget.uptime.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.uptime.contains('ms')
                            ? 'Respuesta: ${widget.uptime}'
                            : widget.uptime.contains('%')
                                ? 'Disponibilidad 30d: ${widget.uptime}'
                                : widget.uptime,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppConstants.paddingSM),
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

          // Auto-repair button — only shows when service is down and superadmin
          if (canRepair) ...[
            const SizedBox(height: 10),
            if (_actionLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _autoRepair,
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                  label: Text(
                    'Auto-reparar',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.error,
                    foregroundColor: colorScheme.onError,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
          ],

          // Action result output
          if (_actionResult != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _actionResult = null),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Text(
                    _actionResult!,
                    style: GoogleFonts.firaCode(
                      fontSize: 10,
                      color: colorScheme.onSurface.withValues(alpha: 0.8),
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
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
    final isSuperAdmin = ref.watch(isSuperAdminProvider).valueOrNull ?? false;
    if (!isSuperAdmin) return const SizedBox.shrink();

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
        if (_results.isNotEmpty) ...[
          // Summary bar
          if (!_running) ...[
            Builder(builder: (context) {
              final ext = Theme.of(context).extension<BCThemeExtension>()!;
              final cs = Theme.of(context).colorScheme;
              final allPassed = _results.where((r) => !r.isSection && !r.passed).isEmpty;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: allPassed
                      ? ext.successColor.withValues(alpha: 0.08)
                      : cs.error.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: allPassed
                        ? ext.successColor.withValues(alpha: 0.3)
                        : cs.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${_results.where((r) => !r.isSection && r.passed).length} passed, '
                  '${_results.where((r) => !r.isSection && !r.passed).length} failed — '
                  '${_results.where((r) => !r.isSection).length} total',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: allPassed ? ext.successColor : cs.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            }),
          ],
          ...(_results.map((r) => _TestResultTile(result: r))),
        ],
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
    // 3s pause between edge function calls to avoid container overload
    const pause = Duration(milliseconds: 3000);

    // ── INFRAESTRUCTURA (direct DB/auth — no edge functions) ──
    await _section('INFRAESTRUCTURA');

    await _test('Base de datos (lectura)', () async {
      final res = await client.from('app_config').select('key').limit(1);
      if ((res as List).isEmpty) throw Exception('Sin datos');
    });

    await _test('Base de datos (escritura)', () async {
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception('Sin usuario');
      await client.from('profiles').update({
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);
    });

    await _test('Autenticacion', () async {
      if (client.auth.currentUser == null) throw Exception('Sin sesion');
    });

    await _test('Almacenamiento', () async {
      await client.storage.from('user-media').list(path: '');
    });

    await _test('Perfil de usuario', () async {
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception('Sin usuario');
      final res = await client.from('profiles').select('id, role').eq('id', userId).single();
      if (res['role'] == null) throw Exception('Sin rol');
    });

    // ── EDGE FUNCTIONS (one at a time, 3s gaps) ──
    await _section('EDGE FUNCTIONS');
    await Future.delayed(pause);

    await _test('system-health', () async {
      await _invokeAlive(client, 'system-health');
    });
    await Future.delayed(pause);

    await _test('feed-public', () async {
      await _invokeAlive(client, 'feed-public', method: HttpMethod.get);
    });
    await Future.delayed(pause);

    await _test('curate-results (motor de reservas)', () async {
      await _invokeAlive(client, 'curate-results', body: {
        'location': {'lat': 20.6534, 'lng': -105.2253},
        'service_type': 'balayage',
        'transport_mode': 'car',
      });
    });
    await Future.delayed(pause);

    await _test('outreach-discovered-salon', () async {
      await _invokeAlive(client, 'outreach-discovered-salon', body: {
        'action': 'search',
        'query': 'salon',
        'lat': 20.6534,
        'lng': -105.2253,
      });
    });
    await Future.delayed(pause);

    await _test('aphrodite-chat (AI)', () async {
      await _invokeAlive(client, 'aphrodite-chat', body: {
        'action': 'send_message',
        'message': 'test diagnostico',
        'language': 'es',
      });
    });
    await Future.delayed(pause);

    await _test('send-push-notification', () async {
      await _invokeAlive(client, 'send-push-notification', body: {
        'user_id': client.auth.currentUser?.id ?? '',
        'title': 'test',
        'body': 'diagnostico',
      });
    });
    await Future.delayed(pause);

    await _test('create-payment-intent (Stripe)', () async {
      await _invokeAlive(client, 'create-payment-intent', body: {
        'amount': 100,
        'booking_id': 'test-diag',
      });
    });
    await Future.delayed(pause);

    await _test('outreach-contact', () async {
      await _invokeAlive(client, 'outreach-contact', body: {
        'action': 'get_templates',
      });
    });
    await Future.delayed(pause);

    await _test('places-proxy (Google)', () async {
      await _invokeAlive(client, 'places-proxy', body: {
        'query': 'salon puerto vallarta',
        'lat': 20.6534,
        'lng': -105.2253,
      });
    });
    await Future.delayed(pause);

    await _test('bpi-admin (beautypi)', () async {
      await _invokeAlive(client, 'bpi-admin', body: {
        'action': 'diagnose',
        'service': 'guestkey',
      });
    });

    setState(() => _running = false);
  }

  /// Invoke an edge function and consider it alive if it responds (even with 4xx).
  /// Only 500+ or network errors count as failure.
  Future<void> _invokeAlive(
    SupabaseClient client,
    String function, {
    Map<String, dynamic>? body,
    HttpMethod method = HttpMethod.post,
  }) async {
    try {
      final res = await client.functions.invoke(function, body: body ?? {}, method: method);
      if (res.status >= 500) throw Exception('HTTP ${res.status}');
    } catch (e) {
      final msg = e.toString().toLowerCase();
      // 4xx responses mean the function is alive — it responded with a validation error
      if (msg.contains('400') || msg.contains('401') || msg.contains('403') ||
          msg.contains('404') || msg.contains('405') || msg.contains('409') ||
          msg.contains('429') || msg.contains('bad request') ||
          msg.contains('method not allowed') || msg.contains('unauthorized') ||
          msg.contains('forbidden') || msg.contains('not found')) {
        return; // Function is alive, just rejected our test payload
      }
      rethrow; // Real failure (500, network error, timeout)
    }
  }

  Future<void> _section(String name) async {
    setState(() => _results.add(_TestResult(
      name: name,
      passed: true,
      elapsed: 0,
      isSection: true,
    )));
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
  final bool isSection;

  const _TestResult({
    required this.name,
    required this.passed,
    required this.elapsed,
    this.error,
    this.isSection = false,
  });
}

class _TestResultTile extends StatelessWidget {
  final _TestResult result;
  const _TestResultTile({required this.result, super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Section header
    if (result.isSection) {
      return Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4, left: 2),
        child: Text(
          result.name,
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: colorScheme.primary,
          ),
        ),
      );
    }

    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: result.passed
              ? ext.successColor.withValues(alpha: 0.3)
              : colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            result.passed ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: result.passed ? ext.successColor : colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.name,
                    style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.w500)),
                if (result.error != null)
                  Text(result.error!,
                      style: GoogleFonts.nunito(
                          fontSize: 10, color: colorScheme.error),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Text('${result.elapsed}ms',
              style: GoogleFonts.nunito(
                  fontSize: 10,
                  color: colorScheme.onSurface.withValues(alpha: 0.4))),
        ],
      ),
    );
  }
}
