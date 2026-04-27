/// Business-side chat inbox — list every customer conversation scoped
/// to the current business owner's shops. Companion to the customer's
/// /chat/list; RLS guarantees each owner only sees their own threads.
library;

import 'package:beautycita/widgets/cached_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/fonts.dart';
import '../../providers/business_chat_provider.dart';
import '../../widgets/empty_state.dart';

class BusinessChatListScreen extends ConsumerWidget {
  const BusinessChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(businessChatThreadsProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Bandeja',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: threadsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 40, color: colors.error),
                const SizedBox(height: 12),
                Text(
                  'No se pudo cargar la bandeja',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  e.toString(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (threads) {
          if (threads.isEmpty) {
            return const EmptyState(
              icon: Icons.inbox_rounded,
              message:
                  'Aun no hay conversaciones.\nCuando una clienta te escriba desde tu perfil, vas a verla aqui.',
            );
          }
          return ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: threads.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              thickness: 0.5,
              color: colors.outline.withValues(alpha: 0.2),
              indent: 76,
            ),
            itemBuilder: (ctx, i) =>
                _ThreadTile(entry: threads[i]),
          );
        },
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  final BusinessThread entry;

  const _ThreadTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final thread = entry.thread;
    final hasUnread = thread.unreadCount > 0;
    final timestamp = thread.lastMessageAt ?? thread.createdAt;

    return InkWell(
      onTap: () {
        context.push('/negocio/bandeja/${thread.id}');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _Avatar(
              name: entry.customerName,
              avatarUrl: entry.customerAvatarUrl,
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.customerName,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: hasUnread
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: colors.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimestamp(timestamp),
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: hasUnread
                              ? colors.primary
                              : colors.onSurface.withValues(alpha: 0.55),
                          fontWeight: hasUnread
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.lastMessageText ?? 'Sin mensajes todavia',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            color: hasUnread
                                ? colors.onSurface
                                : colors.onSurface.withValues(alpha: 0.6),
                            fontWeight: hasUnread
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${thread.unreadCount}',
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: colors.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// WhatsApp-style relative timestamps: today→HH:mm, yesterday→"ayer",
  /// this week→weekday, older→dd/MM.
  String _formatTimestamp(DateTime when) {
    final now = DateTime.now();
    final local = when.toLocal();
    final sameDay = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (sameDay) {
      return DateFormat.Hm().format(local);
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day) {
      return 'ayer';
    }
    final daysAgo = now.difference(local).inDays;
    if (daysAgo < 7) {
      return DateFormat.E('es').format(local); // lun, mar, mie…
    }
    return DateFormat('d/M').format(local);
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double size;

  const _Avatar({
    required this.name,
    required this.avatarUrl,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return ClipOval(
        child: CachedImage(
          avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _initialsCircle(colors),
          loadingBuilder: (ctx, child, progress) {
            if (progress == null) return child;
            return _initialsCircle(colors);
          },
        ),
      );
    }
    return _initialsCircle(colors);
  }

  Widget _initialsCircle(ColorScheme colors) {
    final initials = _initials(name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.primaryContainer,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.poppins(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          color: colors.onPrimaryContainer,
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
