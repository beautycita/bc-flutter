import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../config/theme_extension.dart';
import '../../../models/chat_thread.dart';
import '../../../providers/chat_provider.dart';
import 'mo_widgets.dart';

class MOChatListScreen extends ConsumerStatefulWidget {
  const MOChatListScreen({super.key});

  @override
  ConsumerState<MOChatListScreen> createState() => _MOChatListScreenState();
}

class _MOChatListScreenState extends ConsumerState<MOChatListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(aphroditeThreadProvider));
  }

  @override
  Widget build(BuildContext context) {
    final mo = MOColors.of(context);
    final threadsAsync = ref.watch(chatThreadsProvider);

    return Scaffold(
      backgroundColor: mo.surface,
      appBar: AppBar(
        backgroundColor: mo.card,
        elevation: 0,
        title: Text(
          'Mensajes',
          style: GoogleFonts.quicksand(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: mo.orchidPink,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: mo.orchidPink),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search_rounded, color: mo.orchidPurple),
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
                  mo.orchidPink.withValues(alpha: 0.0),
                  mo.orchidPink.withValues(alpha: 0.4),
                  mo.orchidPink.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ),
      body: threadsAsync.when(
        data: (threads) {
          if (threads.isEmpty) {
            return _MOEmptyState(mo: mo, onTapAphrodite: _openAphroditeChat);
          }
          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(top: 12, bottom: 80, left: 12, right: 12),
            itemCount: threads.length,
            itemBuilder: (context, index) {
              final thread = threads[index];
              final row = thread.isAphrodite
                  ? _MOAphroditeRow(
                      thread: thread,
                      mo: mo,
                      onTap: () => context.push('/chat/${thread.id}'),
                    )
                  : _MOThreadRow(
                      thread: thread,
                      mo: mo,
                      onTap: () => context.push('/chat/${thread.id}'),
                    );
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Dismissible(
                  key: ValueKey(thread.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
                  ),
                  confirmDismiss: (_) => _confirmDelete(context, thread.displayName, mo),
                  onDismissed: (_) {
                    ref.read(aphroditeServiceProvider).deleteThread(thread.id);
                  },
                  child: row,
                ),
              );
            },
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: mo.orchidPink),
        ),
        error: (err, _) => Center(
          child: Text('Error', style: GoogleFonts.quicksand(color: mo.orchidPink)),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: mo.orchidGradient,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: mo.orchidPink.withValues(alpha: 0.35),
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
                    style: GoogleFonts.quicksand(
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

  Future<bool> _confirmDelete(BuildContext context, String name, MOColors mo) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: mo.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: mo.orchidPurple.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                gradient: mo.orchidGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Icon(Icons.delete_outline, size: 44, color: mo.orchidPink),
            const SizedBox(height: 12),
            Text(
              'Eliminar conversacion?',
              style: GoogleFonts.quicksand(fontSize: 17, fontWeight: FontWeight.w700, color: mo.text),
            ),
            const SizedBox(height: 8),
            Text(
              'Se eliminara la conversacion con $name.',
              style: GoogleFonts.quicksand(fontSize: 13, color: mo.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text('Cancelar', style: GoogleFonts.quicksand(color: mo.textSecondary)),
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: mo.orchidGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(
                        'Eliminar',
                        style: GoogleFonts.quicksand(fontWeight: FontWeight.w700, color: Colors.white),
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

class _MOAphroditeRow extends StatelessWidget {
  final ChatThread thread;
  final MOColors mo;
  final VoidCallback onTap;

  const _MOAphroditeRow({required this.thread, required this.mo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: mo.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: mo.orchidPink.withValues(alpha: 0.2), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: mo.orchidPink.withValues(alpha: 0.08),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              // Orchid bloom gradient ring
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: mo.orchidGradient,
                  boxShadow: [
                    BoxShadow(
                      color: mo.orchidPink.withValues(alpha: 0.35),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2.5),
                  child: Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, color: mo.card),
                    child: const Center(child: Text('🏛️', style: TextStyle(fontSize: 24))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Afrodita',
                          style: GoogleFonts.quicksand(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: mo.orchidLight,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            gradient: mo.orchidGradient,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'AI',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      thread.lastMessageText ?? 'Tu asesora de belleza divina',
                      style: GoogleFonts.quicksand(
                        fontSize: 13,
                        color: thread.unreadCount > 0 ? mo.text : mo.textSecondary,
                        fontWeight: thread.unreadCount > 0 ? FontWeight.w700 : FontWeight.w500,
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
                    _moFormatTime(thread.lastMessageAt),
                    style: GoogleFonts.quicksand(
                      fontSize: 11,
                      color: thread.unreadCount > 0 ? mo.orchidPink : mo.textSecondary,
                    ),
                  ),
                  if (thread.unreadCount > 0) ...[
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: mo.orchidGradient,
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
      ),
    );
  }
}

// ─── Thread Row ────────────────────────────────────────────────────────────────

class _MOThreadRow extends StatelessWidget {
  final ChatThread thread;
  final MOColors mo;
  final VoidCallback onTap;

  const _MOThreadRow({required this.thread, required this.mo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: mo.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mo.orchidDeep.withValues(alpha: 0.3), width: 0.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: mo.orchidDeep.withValues(alpha: 0.4),
                  border: Border.all(color: mo.orchidPurple.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Text(
                    thread.contactType == 'salon' ? '💇' : '👤',
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      thread.displayName,
                      style: GoogleFonts.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: mo.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      thread.lastMessageText ?? '',
                      style: GoogleFonts.quicksand(
                        fontSize: 13,
                        color: thread.unreadCount > 0 ? mo.text : mo.textSecondary,
                        fontWeight: thread.unreadCount > 0 ? FontWeight.w700 : FontWeight.w500,
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
                    _moFormatTime(thread.lastMessageAt),
                    style: GoogleFonts.quicksand(fontSize: 11, color: mo.textSecondary),
                  ),
                  if (thread.unreadCount > 0) ...[
                    const SizedBox(height: 5),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: mo.orchidPink,
                        boxShadow: [
                          BoxShadow(color: mo.orchidPink.withValues(alpha: 0.5), blurRadius: 6),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty State ───────────────────────────────────────────────────────────────

class _MOEmptyState extends StatelessWidget {
  final MOColors mo;
  final VoidCallback onTapAphrodite;

  const _MOEmptyState({required this.mo, required this.onTapAphrodite});

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
                  BoxShadow(color: mo.orchidPink.withValues(alpha: 0.4), blurRadius: 24),
                ],
              ),
              child: const Center(child: Text('🏛️', style: TextStyle(fontSize: 48))),
            ),
            const SizedBox(height: 24),
            Text(
              'Sin conversaciones',
              style: GoogleFonts.quicksand(fontSize: 18, fontWeight: FontWeight.w700, color: mo.text),
            ),
            const SizedBox(height: 8),
            Text(
              'Tus mensajes aparecerán aquí',
              style: GoogleFonts.quicksand(fontSize: 14, color: mo.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: mo.orchidGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: mo.orchidPink.withValues(alpha: 0.35), blurRadius: 16),
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
                      style: GoogleFonts.quicksand(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.white,
                      ),
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

String _moFormatTime(DateTime? dt) {
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
