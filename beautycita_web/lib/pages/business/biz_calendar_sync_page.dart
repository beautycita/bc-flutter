import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';

import '../../config/breakpoints.dart';
import '../../config/web_theme.dart';
import '../../providers/business_portal_provider.dart';
import '../../providers/demo_providers.dart';
import '../../widgets/web_design_system.dart';

/// Business portal page for managing external calendar connections,
/// ICS export/import, and sync settings.
class BizCalendarSyncPage extends ConsumerStatefulWidget {
  const BizCalendarSyncPage({super.key});

  @override
  ConsumerState<BizCalendarSyncPage> createState() =>
      _BizCalendarSyncPageState();
}

class _BizCalendarSyncPageState extends ConsumerState<BizCalendarSyncPage> {
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isSyncing = false;
  bool _isExportingGoogle = false;
  bool _isConnecting = false;
  bool _isDisconnecting = false;
  bool _googleConnected = false;
  String? _googleLastSync;
  String? _googleError;
  String? _feedUrl;
  String? _bizFeedUrl;

  @override
  void initState() {
    super.initState();
    _checkGoogleStatus();
  }

  Future<void> _checkGoogleStatus() async {
    try {
      final response = await BCSupabase.client.functions.invoke(
        'google-calendar-connect',
        body: {'action': 'status'},
      );
      final data = response.data;
      if (data is Map && mounted) {
        setState(() {
          _googleConnected = data['connected'] == true;
          _googleLastSync = data['last_synced_at'] as String?;
          _googleError = data['sync_error'] as String?;
        });
      }
    } catch (_) {
      // Silently fail — status check is best-effort
    }
  }

  Future<void> _connectGoogle() async {
    setState(() => _isConnecting = true);
    try {
      final response = await BCSupabase.client.functions.invoke(
        'google-calendar-connect',
        body: {'action': 'oauth_url'},
      );
      final data = response.data;
      if (data is Map && data['url'] is String) {
        final url = data['url'] as String;
        // Navigate to Google OAuth consent screen
        web.window.location.href = url;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _disconnectGoogle() async {
    setState(() => _isDisconnecting = true);
    try {
      await BCSupabase.client.functions.invoke(
        'google-calendar-connect',
        body: {'action': 'disconnect'},
      );
      if (mounted) {
        setState(() {
          _googleConnected = false;
          _googleLastSync = null;
          _googleError = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google Calendar desconectado'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isDisconnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bizAsync = ref.watch(currentBusinessProvider);
    final isDemo = ref.watch(isDemoProvider);

    return bizAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (biz) {
        if (biz == null) {
          return const Center(child: Text('No tienes un negocio registrado.'));
        }
        return _Content(
          bizId: biz['id'] as String,
          bizName: biz['name'] as String? ?? '',
          isDemo: isDemo,
          isExporting: _isExporting,
          isImporting: _isImporting,
          isSyncing: _isSyncing,
          isConnecting: _isConnecting,
          isDisconnecting: _isDisconnecting,
          googleConnected: _googleConnected,
          googleLastSync: _googleLastSync,
          googleError: _googleError,
          feedUrl: _feedUrl,
          bizFeedUrl: _bizFeedUrl,
          onExport: isDemo ? null : _exportICS,
          onImport: isDemo ? null : _importICS,
          onGetFeedUrl: isDemo ? null : _getFeedUrl,
          onSyncGoogle: isDemo ? null : _syncGoogle,
          onExportGoogle: isDemo ? null : _exportToGoogle,
          isExportingGoogle: _isExportingGoogle,
          onConnectGoogle: isDemo ? null : _connectGoogle,
          onDisconnectGoogle: isDemo ? null : _disconnectGoogle,
        );
      },
    );
  }

  Future<void> _exportICS() async {
    setState(() => _isExporting = true);
    try {
      final response = await BCSupabase.client.functions.invoke(
        'calendar-ics',
        body: {'action': 'export'},
      );
      final data = response.data as Map<String, dynamic>;
      final ics = data['ics'] as String;

      // Trigger browser download
      final bytes = utf8.encode(ics);
      final blob = web.Blob(
        [bytes.toJS].toJS,
        web.BlobPropertyBag(type: 'text/calendar'),
      );
      final url = web.URL.createObjectURL(blob);
      (web.document.createElement('a') as web.HTMLAnchorElement
            ..href = url
            ..download = 'beautycita-calendar.ics')
          .click();
      web.URL.revokeObjectURL(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Exportado ${data['events_count']} eventos'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _importICS() async {
    // Use file input to select .ics file
    final input = web.document.createElement('input') as web.HTMLInputElement
      ..type = 'file'
      ..accept = '.ics,.ical';

    final changeCompleter = Completer<void>();
    void onInputChange(web.Event _) => changeCompleter.complete();
    input.addEventListener('change', onInputChange.toJS);
    input.click();
    await changeCompleter.future;

    final files = input.files;
    if (files == null || files.length == 0) return;

    setState(() => _isImporting = true);
    try {
      final file = files.item(0)!;
      final reader = web.FileReader();
      final loadCompleter = Completer<void>();
      void onReaderLoad(web.Event _) => loadCompleter.complete();
      reader.addEventListener('load', onReaderLoad.toJS);
      reader.readAsText(file);
      await loadCompleter.future;
      final content = (reader.result as JSString).toDart;

      final response = await BCSupabase.client.functions.invoke(
        'calendar-ics',
        body: {'action': 'import', 'ics_content': content},
      );
      final data = response.data as Map<String, dynamic>;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Importado: ${data['imported']} eventos '
              '(${data['skipped_past']} pasados omitidos)',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _getFeedUrl() async {
    try {
      final response = await BCSupabase.client.functions.invoke(
        'calendar-ics',
        body: {'action': 'feed_url'},
      );
      final data = response.data as Map<String, dynamic>;
      setState(() {
        _feedUrl = data['staff_feed_url'] as String?;
        _bizFeedUrl = data['business_feed_url'] as String?;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _syncGoogle() async {
    setState(() => _isSyncing = true);
    try {
      final response = await BCSupabase.client.functions.invoke(
        'google-calendar-sync',
        body: {'days': 30},
      );
      final data = response.data as Map<String, dynamic>;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sincronizado: ${data['appointments_saved']} eventos de Google Calendar',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _exportToGoogle() async {
    setState(() => _isExportingGoogle = true);
    try {
      final response = await BCSupabase.client.functions.invoke(
        'google-calendar-sync',
        body: {'action': 'export', 'days': 30},
      );
      final data = response.data as Map<String, dynamic>;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Exportado a Google: ${data['created']} nuevos, ${data['updated']} actualizados',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingGoogle = false);
    }
  }
}

// ── Page content ────────────────────────────────────────────────────────────

class _Content extends StatelessWidget {
  const _Content({
    required this.bizId,
    required this.bizName,
    required this.isDemo,
    required this.isExporting,
    required this.isImporting,
    required this.isSyncing,
    required this.isConnecting,
    required this.isDisconnecting,
    required this.googleConnected,
    required this.googleLastSync,
    required this.googleError,
    required this.feedUrl,
    required this.bizFeedUrl,
    required this.onExport,
    required this.onImport,
    required this.onGetFeedUrl,
    required this.onSyncGoogle,
    required this.onExportGoogle,
    required this.isExportingGoogle,
    required this.onConnectGoogle,
    required this.onDisconnectGoogle,
  });

  final String bizId;
  final String bizName;
  final bool isDemo;
  final bool isExporting;
  final bool isImporting;
  final bool isSyncing;
  final bool isConnecting;
  final bool isDisconnecting;
  final bool googleConnected;
  final String? googleLastSync;
  final String? googleError;
  final String? feedUrl;
  final String? bizFeedUrl;
  final VoidCallback? onExport;
  final VoidCallback? onImport;
  final VoidCallback? onGetFeedUrl;
  final VoidCallback? onSyncGoogle;
  final VoidCallback? onExportGoogle;
  final bool isExportingGoogle;
  final VoidCallback? onConnectGoogle;
  final VoidCallback? onDisconnectGoogle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isDesktop = WebBreakpoints.isDesktop(constraints.maxWidth);
      final hPad = isDesktop ? 40.0 : 20.0;

      return SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            WebSectionHeader(
              label: 'Integraciones',
              title: 'Calendario Externo',
              subtitle: 'Conecta, importa y exporta tu calendario. Compatible con Google Calendar, Apple Calendar, Outlook y cualquier app que soporte formato ICS.',
              centered: false,
              titleSize: 28,
            ),
            const SizedBox(height: 32),

            // ICS section
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _ExportCard(this)),
                  const SizedBox(width: 16),
                  Expanded(child: _ImportCard(this)),
                  const SizedBox(width: 16),
                  Expanded(child: _FeedCard(this)),
                ],
              )
            else ...[
              _ExportCard(this),
              const SizedBox(height: 16),
              _ImportCard(this),
              const SizedBox(height: 16),
              _FeedCard(this),
            ],

            const SizedBox(height: 32),

            // Connected calendars section
            WebSectionHeader(
              label: 'Conexiones',
              title: 'Calendarios conectados',
              centered: false,
              titleSize: 22,
            ),
            const SizedBox(height: 16),

            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _GoogleCalendarCard(this)),
                  const SizedBox(width: 16),
                  Expanded(child: _AppleCalendarCard(isDemo: isDemo)),
                  const SizedBox(width: 16),
                  Expanded(child: _OutlookCalendarCard(isDemo: isDemo)),
                ],
              )
            else ...[
              _GoogleCalendarCard(this),
              const SizedBox(height: 16),
              _AppleCalendarCard(isDemo: isDemo),
              const SizedBox(height: 16),
              _OutlookCalendarCard(isDemo: isDemo),
            ],

            const SizedBox(height: 32),

            // How it works
            _HowItWorks(isDesktop: isDesktop),
          ],
        ),
      );
    });
  }
}

// ── Export card ──────────────────────────────────────────────────────────────

class _ExportCard extends StatelessWidget {
  const _ExportCard(this.parent);
  final _Content parent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: kWebPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.download_outlined, size: 18, color: kWebPrimary),
              ),
              const SizedBox(width: 10),
              Text(
                'Exportar ICS',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: kWebTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Descarga tu calendario de citas en formato .ics. Compatible con Google Calendar, Apple Calendar, Outlook y mas.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: kWebTextSecondary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: WebGradientButton(
              onPressed: parent.isExporting ? null : parent.onExport,
              isLoading: parent.isExporting,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!parent.isExporting) const Icon(Icons.download_outlined, size: 18, color: Colors.white),
                  if (!parent.isExporting) const SizedBox(width: 8),
                  Text(parent.isExporting ? 'Exportando...' : 'Descargar .ics'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Import card ─────────────────────────────────────────────────────────────

class _ImportCard extends StatelessWidget {
  const _ImportCard(this.parent);
  final _Content parent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: kWebTertiary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.upload_file_outlined, size: 18, color: kWebTertiary),
              ),
              const SizedBox(width: 10),
              Text(
                'Importar ICS',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: kWebTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Sube un archivo .ics para importar eventos de otro calendario. Los eventos se muestran como bloques de ocupado.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: kWebTextSecondary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: WebOutlinedButton(
              onPressed: parent.isImporting ? null : parent.onImport,
              isLoading: parent.isImporting,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!parent.isImporting) const Icon(Icons.upload_file_outlined, size: 18, color: kWebPrimary),
                  if (!parent.isImporting) const SizedBox(width: 8),
                  Text(parent.isImporting ? 'Importando...' : 'Subir archivo .ics'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Feed URL card ───────────────────────────────────────────────────────────

class _FeedCard extends StatelessWidget {
  const _FeedCard(this.parent);
  final _Content parent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: kWebSecondary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.rss_feed_outlined, size: 18, color: kWebSecondary),
              ),
              const SizedBox(width: 10),
              Text(
                'Feed ICS',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: kWebTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'URL publica que se actualiza automaticamente. Suscribete desde Google Calendar, Apple Calendar o Outlook.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: kWebTextSecondary,
            ),
          ),
          const SizedBox(height: 16),
          if (parent.feedUrl != null) ...[
            _CopyField(label: 'Mi calendario', url: parent.feedUrl!),
            if (parent.bizFeedUrl != null) ...[
              const SizedBox(height: 8),
              _CopyField(label: 'Salon completo', url: parent.bizFeedUrl!),
            ],
          ] else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: parent.onGetFeedUrl,
                icon: const Icon(Icons.link_outlined, size: 18),
                label: const Text('Obtener URL de feed'),
              ),
            ),
        ],
      ),
    );
  }
}

class _CopyField extends StatelessWidget {
  const _CopyField({required this.label, required this.url});
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                Text(
                  url,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18),
            tooltip: 'Copiar URL',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('URL copiada'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Google Calendar card ────────────────────────────────────────────────────

class _GoogleCalendarCard extends StatelessWidget {
  const _GoogleCalendarCard(this.parent);
  final _Content parent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connected = parent.googleConnected;

    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WebInfoRow(
            icon: Icons.g_mobiledata_outlined,
            iconColor: const Color(0xFF4285F4),
            label: connected
                ? 'Conectado — importa y exporta citas'
                : 'Conecta tu calendario de Google',
            value: 'Google Calendar',
          ),
          const SizedBox(height: 12),

          // Status badge
          if (connected) ...[
            _CompatBadge(label: 'Conectado'),
            if (parent.googleLastSync != null) ...[
              const SizedBox(height: 6),
              Text(
                'Ultima sincronizacion: ${_formatDate(parent.googleLastSync!)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: kWebTextSecondary,
                  fontSize: 11,
                ),
              ),
            ],
            if (parent.googleError != null) ...[
              const SizedBox(height: 6),
              Text(
                'Error: ${parent.googleError}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFEF4444),
                  fontSize: 11,
                ),
              ),
            ],
          ],

          const SizedBox(height: 16),

          if (!parent.isDemo) ...[
            if (!connected) ...[
              // Connect button
              SizedBox(
                width: double.infinity,
                child: WebGradientButton(
                  onPressed: parent.isConnecting ? null : parent.onConnectGoogle,
                  isLoading: parent.isConnecting,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!parent.isConnecting) const Icon(Icons.link_outlined, size: 18, color: Colors.white),
                      if (!parent.isConnecting) const SizedBox(width: 8),
                      Text(parent.isConnecting ? 'Conectando...' : 'Conectar Google Calendar'),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Import + Export + Disconnect buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: parent.isSyncing ? null : parent.onSyncGoogle,
                      icon: parent.isSyncing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.cloud_download_outlined, size: 18),
                      label: Text(parent.isSyncing ? 'Importando...' : 'Importar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: parent.isExportingGoogle ? null : parent.onExportGoogle,
                      icon: parent.isExportingGoogle
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.cloud_upload_outlined, size: 18),
                      label: Text(parent.isExportingGoogle ? 'Exportando...' : 'Exportar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: parent.isDisconnecting ? null : parent.onDisconnectGoogle,
                    icon: parent.isDisconnecting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.link_off_outlined, size: 18),
                    tooltip: 'Desconectar',
                    style: IconButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
                  ),
                ],
              ),
            ],
          ] else
            _DemoBadge(),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

// ── Apple Calendar card ─────────────────────────────────────────────────────

class _AppleCalendarCard extends StatelessWidget {
  const _AppleCalendarCard({required this.isDemo});
  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WebInfoRow(
            icon: Icons.apple_outlined,
            iconColor: kWebTextPrimary,
            label: 'Via CalDAV o suscripcion ICS',
            value: 'Apple Calendar',
          ),
          const SizedBox(height: 12),
          Text(
            'Usa el Feed ICS de arriba para suscribirte desde Apple Calendar. Tu calendario se actualiza automaticamente.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: kWebTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _CompatBadge(label: 'Compatible via ICS'),
        ],
      ),
    );
  }
}

// ── Outlook card ────────────────────────────────────────────────────────────

class _OutlookCalendarCard extends StatelessWidget {
  const _OutlookCalendarCard({required this.isDemo});
  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WebInfoRow(
            icon: Icons.mail_outlined,
            iconColor: const Color(0xFF0078D4),
            label: 'Via Microsoft Graph o suscripcion ICS',
            value: 'Outlook / Microsoft 365',
          ),
          const SizedBox(height: 12),
          Text(
            'Suscribete al Feed ICS desde Outlook para sincronizar automaticamente. O importa/exporta archivos .ics manualmente.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: kWebTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _CompatBadge(label: 'Compatible via ICS'),
        ],
      ),
    );
  }
}

// ── How it works section ────────────────────────────────────────────────────

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({required this.isDesktop});
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final steps = [
      (Icons.download_rounded, 'Exportar', 'Descarga tus citas como .ics e importalo en cualquier app de calendario.'),
      (Icons.upload_file_rounded, 'Importar', 'Sube un .ics de otro calendario. Los eventos bloquean disponibilidad automaticamente.'),
      (Icons.rss_feed_rounded, 'Suscribir', 'Copia la URL del feed ICS y pegala en Google/Apple/Outlook. Se actualiza solo.'),
      (Icons.sync_rounded, 'Sync OAuth', 'Conecta Google Calendar con un clic. Importa y exporta citas en ambas direcciones.'),
    ];

    return WebCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WebSectionHeader(
            label: 'Guia',
            title: 'Como funciona',
            centered: false,
            titleSize: 20,
          ),
          const SizedBox(height: 16),
          if (isDesktop)
            Row(
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  if (i > 0) const SizedBox(width: 16),
                  Expanded(child: _StepItem(
                    icon: steps[i].$1,
                    title: steps[i].$2,
                    desc: steps[i].$3,
                  )),
                ],
              ],
            )
          else
            Column(
              children: [
                for (final s in steps) ...[
                  _StepItem(icon: s.$1, title: s.$2, desc: s.$3),
                  const SizedBox(height: 12),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  const _StepItem({
    required this.icon,
    required this.title,
    required this.desc,
  });
  final IconData icon;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: kWebPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: kWebPrimary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: kWebTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Badges ──────────────────────────────────────────────────────────────────

class _DemoBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.tertiary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Solo lectura en demo',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.tertiary,
        ),
      ),
    );
  }
}

class _CompatBadge extends StatelessWidget {
  const _CompatBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final green = const Color(0xFF22C55E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: green.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outlined, size: 14, color: green),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: green,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
