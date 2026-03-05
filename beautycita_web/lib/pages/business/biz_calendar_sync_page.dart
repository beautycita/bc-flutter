import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';

import '../../config/breakpoints.dart';
import '../../providers/business_portal_provider.dart';
import '../../providers/demo_providers.dart';

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
  String? _feedUrl;
  String? _bizFeedUrl;

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
          feedUrl: _feedUrl,
          bizFeedUrl: _bizFeedUrl,
          onExport: isDemo ? null : _exportICS,
          onImport: isDemo ? null : _importICS,
          onGetFeedUrl: isDemo ? null : _getFeedUrl,
          onSyncGoogle: isDemo ? null : _syncGoogle,
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
      final blob = html.Blob([bytes], 'text/calendar');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'beautycita-calendar.ics')
        ..click();
      html.Url.revokeObjectUrl(url);

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
    final input = html.FileUploadInputElement()..accept = '.ics,.ical';
    input.click();
    await input.onChange.first;

    final files = input.files;
    if (files == null || files.isEmpty) return;

    setState(() => _isImporting = true);
    try {
      final file = files.first;
      final reader = html.FileReader();
      reader.readAsText(file);
      await reader.onLoad.first;
      final content = reader.result as String;

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
    required this.feedUrl,
    required this.bizFeedUrl,
    required this.onExport,
    required this.onImport,
    required this.onGetFeedUrl,
    required this.onSyncGoogle,
  });

  final String bizId;
  final String bizName;
  final bool isDemo;
  final bool isExporting;
  final bool isImporting;
  final bool isSyncing;
  final String? feedUrl;
  final String? bizFeedUrl;
  final VoidCallback? onExport;
  final VoidCallback? onImport;
  final VoidCallback? onGetFeedUrl;
  final VoidCallback? onSyncGoogle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return LayoutBuilder(builder: (context, constraints) {
      final isDesktop = WebBreakpoints.isDesktop(constraints.maxWidth);
      final hPad = isDesktop ? 40.0 : 20.0;

      return SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Calendario Externo',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Conecta, importa y exporta tu calendario. Compatible con Google Calendar, Apple Calendar, Outlook y cualquier app que soporte formato ICS.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
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
            Text(
              'Calendarios conectados',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
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
    final colors = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.download_rounded, color: colors.primary),
                const SizedBox(width: 8),
                Text(
                  'Exportar ICS',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Descarga tu calendario de citas en formato .ics. Compatible con Google Calendar, Apple Calendar, Outlook y mas.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: parent.isExporting ? null : parent.onExport,
                icon: parent.isExporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded, size: 18),
                label: Text(
                    parent.isExporting ? 'Exportando...' : 'Descargar .ics'),
              ),
            ),
          ],
        ),
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
    final colors = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.upload_file_rounded, color: colors.tertiary),
                const SizedBox(width: 8),
                Text(
                  'Importar ICS',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Sube un archivo .ics para importar eventos de otro calendario. Los eventos se muestran como bloques de ocupado.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: parent.isImporting ? null : parent.onImport,
                icon: parent.isImporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_rounded, size: 18),
                label: Text(
                    parent.isImporting ? 'Importando...' : 'Subir archivo .ics'),
              ),
            ),
          ],
        ),
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
    final colors = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.rss_feed_rounded, color: colors.secondary),
                const SizedBox(width: 8),
                Text(
                  'Feed ICS',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'URL publica que se actualiza automaticamente. Suscribete desde Google Calendar, Apple Calendar o Outlook.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.6),
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
                  icon: const Icon(Icons.link_rounded, size: 18),
                  label: const Text('Obtener URL de feed'),
                ),
              ),
          ],
        ),
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
    final colors = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4285F4).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'G',
                      style: TextStyle(
                        color: Color(0xFF4285F4),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Google Calendar',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Sincronizacion bidireccional via OAuth',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!parent.isDemo) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: parent.onSyncGoogle,
                      icon: parent.isSyncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded, size: 18),
                      label: Text(parent.isSyncing ? 'Sincronizando...' : 'Sincronizar'),
                    ),
                  ),
                ],
              ),
            ] else
              _DemoBadge(),
          ],
        ),
      ),
    );
  }
}

// ── Apple Calendar card ─────────────────────────────────────────────────────

class _AppleCalendarCard extends StatelessWidget {
  const _AppleCalendarCard({required this.isDemo});
  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.apple_rounded,
                      size: 20,
                      color: colors.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Apple Calendar',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Via CalDAV o suscripcion ICS',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Usa el Feed ICS de arriba para suscribirte desde Apple Calendar. Tu calendario se actualiza automaticamente.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            _CompatBadge(label: 'Compatible via ICS'),
          ],
        ),
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
    final colors = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0078D4).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'O',
                      style: TextStyle(
                        color: Color(0xFF0078D4),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Outlook / Microsoft 365',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Via Microsoft Graph o suscripcion ICS',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Suscribete al Feed ICS desde Outlook para sincronizar automaticamente. O importa/exporta archivos .ics manualmente.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            _CompatBadge(label: 'Compatible via ICS'),
          ],
        ),
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final steps = [
      (Icons.download_rounded, 'Exportar', 'Descarga tus citas como .ics e importalo en cualquier app de calendario.'),
      (Icons.upload_file_rounded, 'Importar', 'Sube un .ics de otro calendario. Los eventos bloquean disponibilidad automaticamente.'),
      (Icons.rss_feed_rounded, 'Suscribir', 'Copia la URL del feed ICS y pegala en Google/Apple/Outlook. Se actualiza solo.'),
      (Icons.sync_rounded, 'Sync OAuth', 'Conecta Google Calendar con un clic. Sincronizacion automatica bidireccional.'),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Como funciona',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
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
    final colors = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colors.primary),
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
                  color: colors.onSurface.withValues(alpha: 0.6),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outlined, size: 14, color: Colors.green.shade700),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
