import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../config/theme_extension.dart';
import '../../../models/chat_thread.dart';
import '../../../providers/chat_provider.dart';
import 'on_widgets.dart';

class ONChatListScreen extends ConsumerStatefulWidget {
  const ONChatListScreen({super.key});

  @override
  ConsumerState<ONChatListScreen> createState() => _ONChatListScreenState();
}

class _ONChatListScreenState extends ConsumerState<ONChatListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(aphroditeThreadProvider));
  }

  @override
  Widget build(BuildContext context) {
    final on = ONColors.of(context);
    final threadsAsync = ref.watch(chatThreadsProvider);

    return Scaffold(
      backgroundColor: on.surface0,
      appBar: AppBar(
        backgroundColor: on.surface1,
        elevation: 0,
        title: Text(
          'MENSAJES',
          style: GoogleFontsHelper.rajdhani(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: on.cyan,
            letterSpacing: 3.0,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: on.cyan),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search_rounded, color: on.textSecondary),
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
                  on.cyan.withValues(alpha: 0.0),
                  on.cyan.withValues(alpha: 0.5),
                  on.cyan.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ),
      body: threadsAsync.when(
        data: (threads) {
          if (threads.isEmpty) {
            return _ONEmptyState(on: on, onTapAphrodite: _openAphroditeChat);
          }
          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(top: 8, bottom: 80, left: 12, right: 12),
            itemCount: threads.length,
            itemBuilder: (context, index) {
              final thread = threads[index];
              if (index == 0 && thread.isAphrodite) {
                // Section header for AI
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ONSectionHeader(label: 'ASISTENTE IA', on: on),
                    Dismissible(
                      key: ValueKey(thread.id),
                      direction: DismissDirection.endToStart,
                      background: _deleteBg(on),
                      confirmDismiss: (_) => _confirmDelete(context, thread.displayName, on),
                      onDismissed: (_) {
                        ref.read(aphroditeServiceProvider).deleteThread(thread.id);
                      },
                      child: _ONAphroditeRow(thread: thread, on: on, onTap: () => context.push('/chat/${thread.id}')),
                    ),
                    const SizedBox(height: 8),
                    if (threads.length > 1) _ONSectionHeader(label: 'CONVERSACIONES', on: on),
                  ],
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Dismissible(
                  key: ValueKey(thread.id),
                  direction: DismissDirection.endToStart,
                  background: _deleteBg(on),
                  confirmDismiss: (_) => _confirmDelete(context, thread.displayName, on),
                  onDismissed: (_) {
                    ref.read(aphroditeServiceProvider).deleteThread(thread.id);
                  },
                  child: _ONThreadRow(thread: thread, on: on, onTap: () => context.push('/chat/${thread.id}')),
                ),
              );
            },
          );
        },
        loading: () => Center(
          child: ONDataDots(),
        ),
        error: (err, _) => Center(
          child: Text('ERROR', style: GoogleFontsHelper.rajdhani(color: on.red, fontSize: 16, letterSpacing: 2)),
        ),
      ),
      floatingActionButton: ClipPath(
        clipper: const ONAngularClipper(clipSize: 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: on.cyanGradient,
            boxShadow: [
              BoxShadow(color: on.cyan.withValues(alpha: 0.3), blurRadius: 16),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openAphroditeChat,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('✨', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(
                      'AFRODITA',
                      style: GoogleFontsHelper.rajdhani(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: on.surface0,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _deleteBg(ONColors on) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      color: on.red.withValues(alpha: 0.3),
      child: Icon(Icons.delete_outline, color: on.red, size: 26),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, String name, ONColors on) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: on.surface2,
          border: Border.all(color: on.cyan.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 2,
              decoration: BoxDecoration(
                gradient: on.cyanGradient,
              ),
            ),
            const SizedBox(height: 20),
            Icon(Icons.delete_outline, size: 44, color: on.red),
            const SizedBox(height: 12),
            Text(
              'ELIMINAR CONVERSACION',
              style: GoogleFontsHelper.rajdhani(fontSize: 16, fontWeight: FontWeight.w700, color: on.text, letterSpacing: 2),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text('CANCELAR', style: GoogleFontsHelper.rajdhani(color: on.textSecondary, letterSpacing: 1)),
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: on.red.withValues(alpha: 0.7)),
                      color: on.red.withValues(alpha: 0.15),
                    ),
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(
                        'ELIMINAR',
                        style: GoogleFontsHelper.rajdhani(fontWeight: FontWeight.w700, color: on.red, letterSpacing: 1.5),
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

// ─── Section Header ────────────────────────────────────────────────────────────

class _ONSectionHeader extends StatelessWidget {
  final String label;
  final ONColors on;
  const _ONSectionHeader({required this.label, required this.on});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFontsHelper.rajdhani(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: on.cyan.withValues(alpha: 0.6),
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 0.5,
              color: on.cyan.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Aphrodite Row ─────────────────────────────────────────────────────────────

class _ONAphroditeRow extends StatelessWidget {
  final ChatThread thread;
  final ONColors on;
  final VoidCallback onTap;

  const _ONAphroditeRow({required this.thread, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ONHudFrame(
      bracketSize: 12,
      color: on.cyan,
      padding: EdgeInsets.zero,
      child: Material(
        color: on.surface2,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                // Angular-framed avatar
                ClipPath(
                  clipper: const ONAngularClipper(clipSize: 10),
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: on.cyanGradient,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: ClipPath(
                        clipper: const ONAngularClipper(clipSize: 8),
                        child: Container(
                          color: on.surface1,
                          child: const Center(child: Text('🏛️', style: TextStyle(fontSize: 24))),
                        ),
                      ),
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
                            'AFRODITA',
                            style: GoogleFontsHelper.rajdhani(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: on.cyan,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              border: Border.all(color: on.cyan.withValues(alpha: 0.6)),
                              color: on.cyan.withValues(alpha: 0.1),
                            ),
                            child: Text(
                              'AI',
                              style: GoogleFontsHelper.rajdhani(fontSize: 9, fontWeight: FontWeight.w700, color: on.cyan, letterSpacing: 1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        thread.lastMessageText ?? 'Tu asesora de belleza divina',
                        style: GoogleFonts.sourceSans3(
                          fontSize: 13,
                          color: thread.unreadCount > 0 ? on.text : on.textMuted,
                          fontWeight: thread.unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
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
                      _onFormatTime(thread.lastMessageAt),
                      style: GoogleFontsHelper.monospace(
                        fontSize: 10,
                        color: thread.unreadCount > 0 ? on.cyan : on.textMuted,
                      ),
                    ),
                    if (thread.unreadCount > 0) ...[
                      const SizedBox(height: 5),
                      _ONUnreadPulse(on: on),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Thread Row ────────────────────────────────────────────────────────────────

class _ONThreadRow extends StatelessWidget {
  final ChatThread thread;
  final ONColors on;
  final VoidCallback onTap;

  const _ONThreadRow({required this.thread, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: on.surface1,
        border: Border(
          left: BorderSide(color: on.cyan.withValues(alpha: 0.3), width: 1),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              ClipPath(
                clipper: const ONAngularClipper(clipSize: 8),
                child: Container(
                  width: 50,
                  height: 50,
                  color: on.surface3,
                  child: Center(
                    child: Text(
                      thread.contactType == 'salon' ? '💇' : '👤',
                      style: const TextStyle(fontSize: 22),
                    ),
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
                      style: GoogleFonts.sourceSans3(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: on.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      thread.lastMessageText ?? '',
                      style: GoogleFonts.sourceSans3(
                        fontSize: 12,
                        color: thread.unreadCount > 0 ? on.textSecondary : on.textMuted,
                        fontWeight: thread.unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
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
                    _onFormatTime(thread.lastMessageAt),
                    style: GoogleFontsHelper.monospace(fontSize: 10, color: on.textMuted),
                  ),
                  if (thread.unreadCount > 0) ...[
                    const SizedBox(height: 5),
                    _ONUnreadPulse(on: on),
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

// ─── Cyan Pulse Indicator ──────────────────────────────────────────────────────

class _ONUnreadPulse extends StatefulWidget {
  final ONColors on;
  const _ONUnreadPulse({required this.on});

  @override
  State<_ONUnreadPulse> createState() => _ONUnreadPulseState();
}

class _ONUnreadPulseState extends State<_ONUnreadPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.on.cyan.withValues(alpha: _opacity.value),
          boxShadow: [
            BoxShadow(color: widget.on.cyan.withValues(alpha: _opacity.value * 0.6), blurRadius: 6),
          ],
        ),
      ),
    );
  }
}

// ─── Empty State ───────────────────────────────────────────────────────────────

class _ONEmptyState extends StatelessWidget {
  final ONColors on;
  final VoidCallback onTapAphrodite;

  const _ONEmptyState({required this.on, required this.onTapAphrodite});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<BCThemeExtension>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipPath(
              clipper: const ONAngularClipper(clipSize: 16),
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(gradient: ext.accentGradient),
                child: const Center(child: Text('🏛️', style: TextStyle(fontSize: 48))),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'NO HAY CONVERSACIONES',
              style: GoogleFontsHelper.rajdhani(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: on.text,
                letterSpacing: 2.5,
              ),
            ),
            const SizedBox(height: 32),
            ONAngularButton(label: 'HABLA CON AFRODITA', onTap: onTapAphrodite),
          ],
        ),
      ),
    );
  }
}

String _onFormatTime(DateTime? dt) {
  if (dt == null) return '';
  final now = DateTime.now();
  final local = dt.toLocal();
  final diff = now.difference(local);
  if (diff.inMinutes < 1) return 'AHORA';
  if (diff.inHours < 1) return '${diff.inMinutes}m';
  if (diff.inDays < 1) return DateFormat.Hm().format(local);
  if (diff.inDays < 7) return DateFormat.E().format(local).toUpperCase();
  return DateFormat.MMMd().format(local).toUpperCase();
}
