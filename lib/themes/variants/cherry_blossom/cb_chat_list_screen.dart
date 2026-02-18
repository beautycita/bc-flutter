import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../config/theme_extension.dart';
import '../../../models/chat_thread.dart';
import '../../../providers/chat_provider.dart';
import 'cb_widgets.dart';

class CBChatListScreen extends ConsumerStatefulWidget {
  const CBChatListScreen({super.key});

  @override
  ConsumerState<CBChatListScreen> createState() => _CBChatListScreenState();
}

class _CBChatListScreenState extends ConsumerState<CBChatListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(aphroditeThreadProvider));
  }

  @override
  Widget build(BuildContext context) {
    final cb = CBColors.of(context);
    final threadsAsync = ref.watch(chatThreadsProvider);

    return Scaffold(
      backgroundColor: cb.bg,
      appBar: AppBar(
        backgroundColor: cb.card,
        elevation: 0,
        title: Text(
          'Mensajes',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: cb.text,
            letterSpacing: 0.5,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: cb.pink),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search_rounded, color: cb.pink.withValues(alpha: 0.6)),
            onPressed: () {},
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cb.pink.withValues(alpha: 0.0),
                  cb.pink.withValues(alpha: 0.25),
                  cb.pink.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ),
      body: threadsAsync.when(
        data: (threads) {
          if (threads.isEmpty) {
            return _CBEmptyState(cb: cb, onTapAphrodite: _openAphroditeChat);
          }
          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: threads.length,
            itemBuilder: (context, index) {
              final thread = threads[index];
              final row = thread.isAphrodite
                  ? _CBAphroditeRow(
                      thread: thread,
                      cb: cb,
                      onTap: () => context.push('/chat/${thread.id}'),
                    )
                  : _CBThreadRow(
                      thread: thread,
                      cb: cb,
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
                      color: Colors.pink.shade50,
                      child: Icon(Icons.delete_outline, color: cb.pink, size: 26),
                    ),
                    confirmDismiss: (_) => _confirmDelete(context, thread.displayName, cb),
                    onDismissed: (_) {
                      ref.read(aphroditeServiceProvider).deleteThread(thread.id);
                    },
                    child: row,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 80, right: 16),
                    child: Container(
                      height: 1,
                      color: cb.border,
                    ),
                  ),
                ],
              );
            },
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: cb.pink),
        ),
        error: (err, _) => Center(
          child: Text('Error', style: GoogleFonts.cormorantGaramond(color: cb.pink)),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cb.pink, cb.lavender],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: cb.pink.withValues(alpha: 0.3),
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
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.white,
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

  Future<bool> _confirmDelete(BuildContext context, String name, CBColors cb) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cb.card,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: cb.border),
          boxShadow: [
            BoxShadow(color: cb.pink.withValues(alpha: 0.1), blurRadius: 24, spreadRadius: 2),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 3,
              decoration: BoxDecoration(
                color: cb.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Icon(Icons.delete_outline, size: 44, color: cb.pink),
            const SizedBox(height: 12),
            Text(
              'Eliminar conversacion?',
              style: GoogleFonts.cormorantGaramond(fontSize: 18, fontWeight: FontWeight.w600, color: cb.text),
            ),
            const SizedBox(height: 8),
            Text(
              'Se eliminara la conversacion con $name.',
              style: GoogleFonts.nunito(fontSize: 13, color: cb.textSoft),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text('Cancelar', style: GoogleFonts.nunito(color: cb.textSoft)),
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [cb.pink, cb.lavender]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(
                        'Eliminar',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: Colors.white),
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

class _CBAphroditeRow extends StatelessWidget {
  final ChatThread thread;
  final CBColors cb;
  final VoidCallback onTap;

  const _CBAphroditeRow({required this.thread, required this.cb, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Romantic pink gradient ring avatar
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [cb.pink, cb.lavender],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: cb.pink.withValues(alpha: 0.25),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(2.5),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cb.card,
                  ),
                  child: const Center(child: Text('🏛️', style: TextStyle(fontSize: 24))),
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
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: cb.text,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: cb.pinkLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'AI',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: cb.pink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    thread.lastMessageText ?? 'Tu asesora de belleza divina',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: thread.unreadCount > 0 ? cb.text : cb.textSoft,
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
                  _cbFormatTime(thread.lastMessageAt),
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: thread.unreadCount > 0 ? cb.pink : cb.textSoft,
                  ),
                ),
                if (thread.unreadCount > 0) ...[
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: cb.pink,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${thread.unreadCount}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
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

class _CBThreadRow extends StatelessWidget {
  final ChatThread thread;
  final CBColors cb;
  final VoidCallback onTap;

  const _CBThreadRow({required this.thread, required this.cb, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: cb.pinkLight,
              child: Text(
                thread.contactType == 'salon' ? '💇' : '👤',
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    thread.displayName,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: cb.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    thread.lastMessageText ?? '',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: thread.unreadCount > 0 ? cb.text : cb.textSoft,
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
                  _cbFormatTime(thread.lastMessageAt),
                  style: GoogleFonts.nunito(fontSize: 11, color: cb.textSoft),
                ),
                if (thread.unreadCount > 0) ...[
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: cb.pink.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${thread.unreadCount}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: cb.pink,
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

class _CBEmptyState extends StatelessWidget {
  final CBColors cb;
  final VoidCallback onTapAphrodite;

  const _CBEmptyState({required this.cb, required this.onTapAphrodite});

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
                  BoxShadow(color: cb.pink.withValues(alpha: 0.25), blurRadius: 20),
                ],
              ),
              child: const Center(child: Text('🏛️', style: TextStyle(fontSize: 48))),
            ),
            const SizedBox(height: 24),
            Text(
              'Sin conversaciones',
              style: GoogleFonts.cormorantGaramond(fontSize: 20, fontWeight: FontWeight.w600, color: cb.text),
            ),
            const SizedBox(height: 8),
            Text(
              'Tus mensajes aparecerán aquí',
              style: GoogleFonts.nunito(fontSize: 14, color: cb.textSoft),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [cb.pink, cb.lavender]),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: cb.pink.withValues(alpha: 0.3), blurRadius: 16),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: onTapAphrodite,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    child: Text(
                      'Habla con Afrodita',
                      style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white),
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
}

String _cbFormatTime(DateTime? dt) {
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
