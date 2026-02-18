import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../config/theme_extension.dart';
import '../../../models/chat_thread.dart';
import '../../../providers/chat_provider.dart';
import 'bg_widgets.dart';

class BGChatListScreen extends ConsumerStatefulWidget {
  const BGChatListScreen({super.key});

  @override
  ConsumerState<BGChatListScreen> createState() => _BGChatListScreenState();
}

class _BGChatListScreenState extends ConsumerState<BGChatListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(aphroditeThreadProvider));
  }

  @override
  Widget build(BuildContext context) {
    final bg = BGColors.of(context);
    final threadsAsync = ref.watch(chatThreadsProvider);

    return Scaffold(
      backgroundColor: bg.surface0,
      appBar: AppBar(
        backgroundColor: bg.surface1,
        elevation: 0,
        title: BGGoldShimmer(
          child: Text(
            'MENSAJES',
            style: GoogleFonts.lato(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: bg.goldMid,
              letterSpacing: 3.0,
            ),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: bg.goldMid),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search_rounded, color: bg.goldMid.withValues(alpha: 0.7)),
            onPressed: () {},
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 0.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  bg.goldMid.withValues(alpha: 0.0),
                  bg.goldMid.withValues(alpha: 0.5),
                  bg.goldMid.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ),
      body: threadsAsync.when(
        data: (threads) {
          if (threads.isEmpty) {
            return _BGEmptyState(bg: bg, onTapAphrodite: _openAphroditeChat);
          }
          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: threads.length,
            itemBuilder: (context, index) {
              final thread = threads[index];
              final row = thread.isAphrodite
                  ? _BGAphroditeRow(
                      thread: thread,
                      bg: bg,
                      onTap: () => context.push('/chat/${thread.id}'),
                    )
                  : _BGThreadRow(
                      thread: thread,
                      bg: bg,
                      onTap: () => context.push('/chat/${thread.id}'),
                    );
              return Column(
                children: [
                  Dismissible(
                    key: ValueKey(thread.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      color: Colors.red.shade900,
                      child: Icon(Icons.delete_outline, color: bg.goldMid, size: 28),
                    ),
                    confirmDismiss: (_) => _confirmDelete(context, thread.displayName, bg),
                    onDismissed: (_) {
                      ref.read(aphroditeServiceProvider).deleteThread(thread.id);
                    },
                    child: row,
                  ),
                  // Gold divider
                  Padding(
                    padding: const EdgeInsets.only(left: 80, right: 16),
                    child: Container(
                      height: 0.5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            bg.goldMid.withValues(alpha: 0.0),
                            bg.goldMid.withValues(alpha: 0.2),
                            bg.goldMid.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: bg.goldMid),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: bg.goldDark),
              const SizedBox(height: 16),
              Text(
                'Error cargando mensajes',
                style: GoogleFonts.lato(fontSize: 16, color: bg.textSecondary),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: bgGoldGradient,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: bg.goldMid.withValues(alpha: 0.4),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: _openAphroditeChat,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('✨', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    'Habla con Afrodita',
                    style: GoogleFonts.lato(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: bg.surface0,
                      letterSpacing: 1.0,
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

  Future<bool> _confirmDelete(BuildContext context, String name, BGColors bg) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: bg.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: bg.goldMid.withValues(alpha: 0.25), width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 3,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                gradient: bgGoldGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Icon(Icons.delete_outline, size: 44, color: bg.goldDark),
            const SizedBox(height: 12),
            Text(
              'Eliminar conversacion?',
              style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.w900, color: bg.text),
            ),
            const SizedBox(height: 8),
            Text(
              'Se eliminara la conversacion con $name.',
              style: GoogleFonts.lato(fontSize: 14, color: bg.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text('Cancelar', style: GoogleFonts.lato(color: bg.textSecondary)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: bgGoldGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(
                        'Eliminar',
                        style: GoogleFonts.lato(
                          fontWeight: FontWeight.w900,
                          color: bg.surface0,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  void _openAphroditeChat() async {
    final aphThread = await ref.read(aphroditeThreadProvider.future);
    if (aphThread != null && mounted) {
      context.push('/chat/${aphThread.id}');
    }
  }
}

// ─── Aphrodite Row ─────────────────────────────────────────────────────────────

class _BGAphroditeRow extends StatelessWidget {
  final ChatThread thread;
  final BGColors bg;
  final VoidCallback onTap;

  const _BGAphroditeRow({required this.thread, required this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Gold ring avatar
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: bgGoldGradient,
                boxShadow: [
                  BoxShadow(
                    color: bg.goldMid.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(2.5),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: bg.surface2,
                  ),
                  child: const Center(
                    child: Text('🏛️', style: TextStyle(fontSize: 26)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Afrodita',
                        style: GoogleFonts.lato(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: bg.goldLight,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          border: Border.all(color: bg.goldMid.withValues(alpha: 0.6), width: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'AI',
                          style: GoogleFonts.lato(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: bg.goldMid,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    thread.lastMessageText ?? 'Tu asesora de belleza divina',
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      color: thread.unreadCount > 0 ? bg.textSecondary : bg.textMuted,
                      fontWeight: thread.unreadCount > 0 ? FontWeight.w700 : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _bgFormatTime(thread.lastMessageAt),
                  style: GoogleFonts.lato(
                    fontSize: 11,
                    color: thread.unreadCount > 0 ? bg.goldMid : bg.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                if (thread.unreadCount > 0) ...[
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: bgGoldGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${thread.unreadCount}',
                      style: GoogleFonts.lato(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: bgSurface0,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Thread Row ────────────────────────────────────────────────────────────────

class _BGThreadRow extends StatelessWidget {
  final ChatThread thread;
  final BGColors bg;
  final VoidCallback onTap;

  const _BGThreadRow({required this.thread, required this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bg.surface3,
                border: Border.all(color: bg.goldMid.withValues(alpha: 0.2), width: 0.5),
              ),
              child: Center(
                child: Text(
                  thread.contactType == 'salon' ? '💇' : '👤',
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    thread.displayName,
                    style: GoogleFonts.lato(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: bg.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    thread.lastMessageText ?? '',
                    style: GoogleFonts.lato(
                      fontSize: 13,
                      color: thread.unreadCount > 0 ? bg.textSecondary : bg.textMuted,
                      fontWeight: thread.unreadCount > 0 ? FontWeight.w700 : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _bgFormatTime(thread.lastMessageAt),
                  style: GoogleFonts.lato(
                    fontSize: 11,
                    color: bg.textMuted,
                    letterSpacing: 0.3,
                  ),
                ),
                if (thread.unreadCount > 0) ...[
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: bgGoldGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${thread.unreadCount}',
                      style: GoogleFonts.lato(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: bgSurface0,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty State ───────────────────────────────────────────────────────────────

class _BGEmptyState extends StatelessWidget {
  final BGColors bg;
  final VoidCallback onTapAphrodite;

  const _BGEmptyState({required this.bg, required this.onTapAphrodite});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: ext.accentGradient,
                boxShadow: [
                  BoxShadow(
                    color: bg.goldMid.withValues(alpha: 0.4),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Center(child: Text('🏛️', style: TextStyle(fontSize: 48))),
            ),
            const SizedBox(height: 24),
            Text(
              'Sin conversaciones',
              style: GoogleFonts.lato(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: bg.text,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tus mensajes con salones aparecerán aquí',
              style: GoogleFonts.lato(fontSize: 14, color: bg.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            BGGoldButton(label: 'Habla con Afrodita', onTap: onTapAphrodite),
          ],
        ),
      ),
    );
  }
}

String _bgFormatTime(DateTime? dt) {
  if (dt == null) return '';
  final now = DateTime.now();
  final local = dt.toLocal();
  final diff = now.difference(local);
  if (diff.inMinutes < 1) return 'ahora';
  if (diff.inHours < 1) return '${diff.inMinutes}m';
  if (diff.inDays < 1) return DateFormat.Hm().format(local);
  if (diff.inDays < 7) return DateFormat.E().format(local);
  return DateFormat.MMMd().format(local);
}
