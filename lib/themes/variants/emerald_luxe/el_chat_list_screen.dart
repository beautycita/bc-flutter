import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../config/theme_extension.dart';
import '../../../models/chat_thread.dart';
import '../../../providers/chat_provider.dart';
import 'el_widgets.dart';

class ELChatListScreen extends ConsumerStatefulWidget {
  const ELChatListScreen({super.key});

  @override
  ConsumerState<ELChatListScreen> createState() => _ELChatListScreenState();
}

class _ELChatListScreenState extends ConsumerState<ELChatListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(aphroditeThreadProvider));
  }

  @override
  Widget build(BuildContext context) {
    final el = ELColors.of(context);
    final threadsAsync = ref.watch(chatThreadsProvider);

    return Scaffold(
      backgroundColor: el.bg,
      appBar: AppBar(
        backgroundColor: el.surface,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ELDiamondOrnament(color: el.gold, size: 8),
            const SizedBox(width: 10),
            Text(
              'MENSAJES',
              style: GoogleFonts.cinzel(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: el.gold,
                letterSpacing: 2.5,
              ),
            ),
            const SizedBox(width: 10),
            _ELDiamondOrnament(color: el.gold, size: 8),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: el.gold),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search_rounded, color: el.gold.withValues(alpha: 0.6)),
            onPressed: () {},
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: _ELGeometricDivider(el: el),
        ),
      ),
      body: threadsAsync.when(
        data: (threads) {
          if (threads.isEmpty) {
            return _ELEmptyState(el: el, onTapAphrodite: _openAphroditeChat);
          }
          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(top: 12, bottom: 80, left: 12, right: 12),
            itemCount: threads.length,
            itemBuilder: (context, index) {
              final thread = threads[index];
              final row = thread.isAphrodite
                  ? _ELAphroditeRow(
                      thread: thread,
                      el: el,
                      onTap: () => context.push('/chat/${thread.id}'),
                    )
                  : _ELThreadRow(
                      thread: thread,
                      el: el,
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
                      color: Colors.red.shade900.withValues(alpha: 0.5),
                      child: Icon(Icons.delete_outline, color: el.gold, size: 26),
                    ),
                    confirmDismiss: (_) => _confirmDelete(context, thread.displayName, el),
                    onDismissed: (_) {
                      ref.read(aphroditeServiceProvider).deleteThread(thread.id);
                    },
                    child: row,
                  ),
                  const SizedBox(height: 4),
                  _ELGeometricDivider(el: el),
                  const SizedBox(height: 4),
                ],
              );
            },
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: el.gold),
        ),
        error: (err, _) => Center(
          child: Text('Error', style: GoogleFonts.cinzel(color: el.gold)),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: el.goldGradient,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: el.emerald.withValues(alpha: 0.4), width: 0.5),
          boxShadow: [
            BoxShadow(color: el.gold.withValues(alpha: 0.3), blurRadius: 16),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: _openAphroditeChat,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ELDiamondOrnament(color: el.bg, size: 6),
                  const SizedBox(width: 8),
                  Text(
                    'Habla con Afrodita',
                    style: GoogleFonts.raleway(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: el.bg,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ELDiamondOrnament(color: el.bg, size: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, String name, ELColors el) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: el.surface,
          border: Border.all(color: el.gold.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ELGeometricDivider(el: el),
            const SizedBox(height: 16),
            Icon(Icons.delete_outline, size: 44, color: el.gold),
            const SizedBox(height: 12),
            Text(
              'Eliminar conversacion?',
              style: GoogleFonts.cinzel(fontSize: 15, fontWeight: FontWeight.w700, color: el.text),
            ),
            const SizedBox(height: 8),
            Text(
              'Se eliminara la conversacion con $name.',
              style: GoogleFonts.raleway(fontSize: 13, color: el.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text('Cancelar', style: GoogleFonts.raleway(color: el.textSecondary)),
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: el.goldGradient,
                      border: Border.all(color: el.emerald.withValues(alpha: 0.3)),
                    ),
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(
                        'Eliminar',
                        style: GoogleFonts.raleway(fontWeight: FontWeight.w700, color: el.bg),
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

class _ELAphroditeRow extends StatelessWidget {
  final ChatThread thread;
  final ELColors el;
  final VoidCallback onTap;

  const _ELAphroditeRow({required this.thread, required this.el, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: el.surface,
        border: Border(
          left: BorderSide(color: el.gold, width: 2),
          top: BorderSide(color: el.gold.withValues(alpha: 0.2), width: 0.5),
          bottom: BorderSide(color: el.gold.withValues(alpha: 0.2), width: 0.5),
          right: BorderSide(color: el.emerald.withValues(alpha: 0.15), width: 0.5),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              // Gold+emerald avatar ring
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [el.gold, el.emerald, el.goldLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(color: el.gold.withValues(alpha: 0.3), blurRadius: 10),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2.5),
                  child: Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, color: el.surface2),
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
                          style: GoogleFonts.cinzel(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: el.gold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            border: Border.all(color: el.gold.withValues(alpha: 0.5), width: 0.5),
                          ),
                          child: Text(
                            'AI',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: el.gold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      thread.lastMessageText ?? 'Tu asesora de belleza divina',
                      style: GoogleFonts.raleway(
                        fontSize: 13,
                        color: thread.unreadCount > 0 ? el.text : el.textSecondary,
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
                    _elFormatTime(thread.lastMessageAt),
                    style: GoogleFonts.raleway(
                      fontSize: 11,
                      color: thread.unreadCount > 0 ? el.gold : el.textSecondary,
                    ),
                  ),
                  if (thread.unreadCount > 0) ...[
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: el.goldGradient,
                      ),
                      child: Text(
                        '${thread.unreadCount}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: el.bg),
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

class _ELThreadRow extends StatelessWidget {
  final ChatThread thread;
  final ELColors el;
  final VoidCallback onTap;

  const _ELThreadRow({required this.thread, required this.el, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: el.surface,
        border: Border(
          left: BorderSide(color: el.emerald.withValues(alpha: 0.4), width: 1),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: el.surface2,
                  border: Border.all(color: el.emerald.withValues(alpha: 0.3), width: 0.5),
                ),
                child: Center(
                  child: Text(
                    thread.contactType == 'salon' ? '💇' : '👤',
                    style: const TextStyle(fontSize: 22),
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
                      style: GoogleFonts.cinzel(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: el.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      thread.lastMessageText ?? '',
                      style: GoogleFonts.raleway(
                        fontSize: 13,
                        color: thread.unreadCount > 0 ? el.text : el.textSecondary,
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
                    _elFormatTime(thread.lastMessageAt),
                    style: GoogleFonts.raleway(fontSize: 11, color: el.textSecondary),
                  ),
                  if (thread.unreadCount > 0) ...[
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: el.goldGradient,
                      ),
                      child: Text(
                        '${thread.unreadCount}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: el.bg),
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

// ─── Supporting Widgets ────────────────────────────────────────────────────────

class _ELDiamondOrnament extends StatelessWidget {
  final Color color;
  final double size;
  const _ELDiamondOrnament({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.785,
      child: Container(
        width: size,
        height: size,
        color: color,
      ),
    );
  }
}

class _ELGeometricDivider extends StatelessWidget {
  final ELColors el;
  const _ELGeometricDivider({required this.el});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 0.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [el.gold.withValues(alpha: 0.0), el.gold.withValues(alpha: 0.3)],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _ELDiamondOrnament(color: el.gold.withValues(alpha: 0.4), size: 5),
        ),
        Expanded(
          child: Container(
            height: 0.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [el.gold.withValues(alpha: 0.3), el.gold.withValues(alpha: 0.0)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ELEmptyState extends StatelessWidget {
  final ELColors el;
  final VoidCallback onTapAphrodite;

  const _ELEmptyState({required this.el, required this.onTapAphrodite});

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
                border: Border.all(color: el.gold, width: 1.5),
                boxShadow: [
                  BoxShadow(color: el.gold.withValues(alpha: 0.3), blurRadius: 20),
                ],
              ),
              child: const Center(child: Text('🏛️', style: TextStyle(fontSize: 48))),
            ),
            const SizedBox(height: 24),
            Text(
              'Sin conversaciones',
              style: GoogleFonts.cinzel(fontSize: 16, fontWeight: FontWeight.w700, color: el.text),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: el.goldGradient,
                border: Border.all(color: el.emerald.withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(color: el.gold.withValues(alpha: 0.3), blurRadius: 16),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTapAphrodite,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    child: Text(
                      'Habla con Afrodita',
                      style: GoogleFonts.raleway(fontWeight: FontWeight.w700, fontSize: 14, color: el.bg),
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

String _elFormatTime(DateTime? dt) {
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
