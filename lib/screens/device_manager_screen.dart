import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/config/theme.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/services/supabase_client.dart';

class DeviceSession {
  final String id;
  final String deviceName;
  final DateTime linkedAt;

  DeviceSession({
    required this.id,
    required this.deviceName,
    required this.linkedAt,
  });
}

final deviceSessionsProvider =
    StateNotifierProvider<DeviceSessionsNotifier, AsyncValue<List<DeviceSession>>>((ref) {
  return DeviceSessionsNotifier();
});

class DeviceSessionsNotifier extends StateNotifier<AsyncValue<List<DeviceSession>>> {
  DeviceSessionsNotifier() : super(const AsyncValue.loading()) {
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    state = const AsyncValue.loading();

    if (!SupabaseClientService.isInitialized || !SupabaseClientService.isAuthenticated) {
      state = const AsyncValue.data([]);
      return;
    }

    try {
      final response = await SupabaseClientService.client.functions.invoke(
        'qr-auth',
        body: {'action': 'list_sessions'},
      );

      if (response.status != 200) {
        state = const AsyncValue.data([]);
        return;
      }

      final data = response.data as Map<String, dynamic>;
      final sessions = (data['sessions'] as List<dynamic>?) ?? [];

      state = AsyncValue.data(
        sessions.map((s) {
          final map = s as Map<String, dynamic>;
          final linkedAt = DateTime.tryParse(map['linked_at'] as String? ?? '') ?? DateTime.now();
          return DeviceSession(
            id: map['id'] as String,
            deviceName: 'Sesion Web',
            linkedAt: linkedAt,
          );
        }).toList(),
      );
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> revokeSession(String sessionId) async {
    final currentSessions = state.value;
    if (currentSessions == null) return;

    // Optimistic UI update
    state = AsyncValue.data(
      currentSessions.where((s) => s.id != sessionId).toList(),
    );

    try {
      await SupabaseClientService.client.functions.invoke(
        'qr-auth',
        body: {'action': 'revoke', 'session_id': sessionId},
      );
    } catch (_) {
      // Reload to get accurate state
      await _loadSessions();
    }
  }

  Future<void> refresh() async {
    await _loadSessions();
  }
}

class DeviceManagerScreen extends ConsumerWidget {
  const DeviceManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(deviceSessionsProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: BeautyCitaTheme.backgroundWhite,
      appBar: AppBar(
        title: const Text('Dispositivos conectados'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.read(deviceSessionsProvider.notifier).refresh();
            },
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingLG),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, size: 64, color: Colors.red.shade400),
                const SizedBox(height: BeautyCitaTheme.spaceMD),
                Text(
                  'Error al cargar dispositivos',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        data: (sessions) {
          return ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenPaddingHorizontal,
              vertical: BeautyCitaTheme.spaceMD,
            ),
            children: [
              // Current device (always shown)
              _CurrentDeviceCard(),
              const SizedBox(height: BeautyCitaTheme.spaceMD),

              if (sessions.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: BeautyCitaTheme.spaceSM),
                  child: Text(
                    'Sesiones web vinculadas',
                    style: textTheme.titleSmall?.copyWith(
                      color: BeautyCitaTheme.textLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ...sessions.map((session) => _WebSessionCard(
                  session: session,
                  onRevoke: () => _showRevokeConfirmation(context, ref, session),
                )),
              ] else ...[
                const SizedBox(height: 32),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.devices_other_rounded,
                        size: 48,
                        color: BeautyCitaTheme.textLight.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No hay sesiones web vinculadas',
                        style: textTheme.bodyMedium?.copyWith(color: BeautyCitaTheme.textLight),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _showRevokeConfirmation(BuildContext context, WidgetRef ref, DeviceSession session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMD)),
        title: const Text('Cerrar sesion web'),
        content: const Text('Esta sesion web se desvinculara. El navegador debera vincular de nuevo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(deviceSessionsProvider.notifier).revokeSession(session.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Sesion cerrada'),
                    backgroundColor: Colors.green.shade600,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: const Text('Cerrar sesion'),
          ),
        ],
      ),
    );
  }
}

class _CurrentDeviceCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: BeautyCitaTheme.primaryRose.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: BeautyCitaTheme.primaryRose.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: BeautyCitaTheme.primaryRose.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
            ),
            child: const Icon(Icons.phone_android_rounded, color: BeautyCitaTheme.primaryRose, size: 24),
          ),
          const SizedBox(width: BeautyCitaTheme.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Este dispositivo', style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    'Activo',
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.green.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
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

class _WebSessionCard extends StatelessWidget {
  final DeviceSession session;
  final VoidCallback onRevoke;

  const _WebSessionCard({required this.session, required this.onRevoke});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final timeAgo = _formatTimeAgo(session.linkedAt);

    return Container(
      margin: const EdgeInsets.only(bottom: BeautyCitaTheme.spaceSM),
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
            ),
            child: Icon(Icons.computer_rounded, color: Colors.blue.shade400, size: 24),
          ),
          const SizedBox(width: BeautyCitaTheme.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.deviceName, style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  'Vinculado hace $timeAgo',
                  style: textTheme.bodySmall?.copyWith(color: BeautyCitaTheme.textLight),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onRevoke,
            style: TextButton.styleFrom(
              foregroundColor: Colors.red.shade600,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inSeconds < 60) return 'unos segundos';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min';
    if (difference.inHours < 24) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';
    if (difference.inDays < 30) return '${(difference.inDays / 7).floor()} sem';
    return '${(difference.inDays / 30).floor()} mes${(difference.inDays / 30).floor() > 1 ? 'es' : ''}';
  }
}
