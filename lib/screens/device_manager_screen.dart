import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita/config/theme.dart';
import 'package:beautycita/config/constants.dart';

// Model for a device/session
class DeviceSession {
  final String id;
  final String deviceName;
  final String deviceType;
  final DateTime lastActive;
  final bool isCurrentDevice;

  DeviceSession({
    required this.id,
    required this.deviceName,
    required this.deviceType,
    required this.lastActive,
    required this.isCurrentDevice,
  });
}

// Placeholder provider for device sessions
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

    // Simulate API call delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Placeholder data - replace with actual Supabase query
    state = AsyncValue.data([
      DeviceSession(
        id: '1',
        deviceName: 'Galaxy S24',
        deviceType: 'mobile',
        lastActive: DateTime.now(),
        isCurrentDevice: true,
      ),
      DeviceSession(
        id: '2',
        deviceName: 'Chrome en Windows',
        deviceType: 'desktop',
        lastActive: DateTime.now().subtract(const Duration(hours: 2)),
        isCurrentDevice: false,
      ),
      DeviceSession(
        id: '3',
        deviceName: 'Safari en iPhone',
        deviceType: 'mobile',
        lastActive: DateTime.now().subtract(const Duration(days: 1)),
        isCurrentDevice: false,
      ),
      DeviceSession(
        id: '4',
        deviceName: 'Chrome en Android',
        deviceType: 'tablet',
        lastActive: DateTime.now().subtract(const Duration(days: 7)),
        isCurrentDevice: false,
      ),
    ]);
  }

  Future<void> revokeSession(String sessionId) async {
    final currentSessions = state.value;
    if (currentSessions == null) return;

    // Optimistically update UI
    state = AsyncValue.data(
      currentSessions.where((session) => session.id != sessionId).toList(),
    );

    // TODO: Implement actual Supabase session revocation
    // await supabase.auth.admin.deleteUser(sessionId);
    await Future.delayed(const Duration(milliseconds: 300));
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
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingLG),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 64,
                  color: Colors.red.shade400,
                ),
                const SizedBox(height: BeautyCitaTheme.spaceMD),
                Text(
                  'Error al cargar dispositivos',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: BeautyCitaTheme.spaceSM),
                Text(
                  error.toString(),
                  style: textTheme.bodySmall?.copyWith(
                    color: BeautyCitaTheme.textLight,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.paddingLG),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.devices_other_rounded,
                      size: 64,
                      color: BeautyCitaTheme.textLight.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: BeautyCitaTheme.spaceMD),
                    Text(
                      'No hay dispositivos conectados',
                      style: textTheme.titleMedium?.copyWith(
                        color: BeautyCitaTheme.textLight,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.screenPaddingHorizontal,
              vertical: BeautyCitaTheme.spaceMD,
            ),
            children: [
              // Info text
              Padding(
                padding: const EdgeInsets.only(bottom: BeautyCitaTheme.spaceMD),
                child: Text(
                  'Gestiona las sesiones activas en tus dispositivos. Puedes cerrar sesion en cualquier dispositivo que no reconozcas.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: BeautyCitaTheme.textLight,
                  ),
                ),
              ),
              // Sessions list
              ...sessions.map((session) {
                return _DeviceSessionCard(
                  session: session,
                  onRevoke: () {
                    _showRevokeConfirmation(context, ref, session);
                  },
                );
              }),
            ],
          );
        },
      ),
    );
  }

  void _showRevokeConfirmation(
    BuildContext context,
    WidgetRef ref,
    DeviceSession session,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        ),
        title: const Text('Confirmacion'),
        content: Text(
          '¿Cerrar sesion en "${session.deviceName}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();

              try {
                await ref
                    .read(deviceSessionsProvider.notifier)
                    .revokeSession(session.id);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Sesion cerrada exitosamente'),
                      backgroundColor: Colors.green.shade600,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al cerrar sesion: $e'),
                      backgroundColor: Colors.red.shade600,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            child: const Text('Cerrar sesion'),
          ),
        ],
      ),
    );
  }
}

class _DeviceSessionCard extends StatelessWidget {
  final DeviceSession session;
  final VoidCallback onRevoke;

  const _DeviceSessionCard({
    required this.session,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final timeAgo = _formatTimeAgo(session.lastActive);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: BeautyCitaTheme.spaceSM),
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: session.isCurrentDevice
            ? BeautyCitaTheme.primaryRose.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMD),
        border: Border.all(
          color: session.isCurrentDevice
              ? BeautyCitaTheme.primaryRose.withValues(alpha: 0.2)
              : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Device icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: BeautyCitaTheme.primaryRose.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
            ),
            child: Icon(
              _getDeviceIcon(session.deviceType),
              color: BeautyCitaTheme.primaryRose,
              size: 24,
            ),
          ),
          const SizedBox(width: BeautyCitaTheme.spaceMD),
          // Device info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        session.deviceName,
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Activo hace $timeAgo',
                  style: textTheme.bodySmall?.copyWith(
                    color: BeautyCitaTheme.textLight,
                  ),
                ),
                if (session.isCurrentDevice) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.green.shade200,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Este dispositivo',
                      style: textTheme.bodySmall?.copyWith(
                        color: Colors.green.shade700,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Revoke button
          if (!session.isCurrentDevice) ...[
            const SizedBox(width: BeautyCitaTheme.spaceSM),
            TextButton(
              onPressed: onRevoke,
              style: TextButton.styleFrom(
                foregroundColor: Colors.red.shade600,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              child: const Text('Cerrar'),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getDeviceIcon(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'mobile':
        return Icons.phone_android_rounded;
      case 'tablet':
        return Icons.tablet_rounded;
      case 'desktop':
        return Icons.computer_rounded;
      default:
        return Icons.devices_rounded;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'unos segundos';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minuto${difference.inMinutes > 1 ? 's' : ''}';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hora${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} dia${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks semana${weeks > 1 ? 's' : ''}';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months mes${months > 1 ? 'es' : ''}';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ano${years > 1 ? 's' : ''}';
    }
  }
}
