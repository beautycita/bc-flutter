import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../models/chat_thread.dart';
import '../../../providers/chat_provider.dart';
import 'gl_widgets.dart';

class GLChatListScreen extends ConsumerStatefulWidget {
  const GLChatListScreen({super.key});

  @override
  ConsumerState<GLChatListScreen> createState() => _GLChatListScreenState();
}

class _GLChatListScreenState extends ConsumerState<GLChatListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(aphroditeThreadProvider));
  }

  @override
  Widget build(BuildContext context) {
    final gl = GlColors.of(context);
    final threadsAsync = ref.watch(chatThreadsProvider);

    return Scaffold(
      backgroundColor: gl.bgDeep,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: gl.bgDeep.withValues(alpha: 0.7),
                border: Border(
                  bottom: BorderSide(color: gl.borderWhite, width: 0.5),
                ),
              ),
            ),
          ),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [gl.neonPink, gl.neonPurple, gl.neonCyan],
          ).createShader(bounds),
          child: Text(
            'Mensajes',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: gl.neonCyan),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search_rounded, color: gl.textSecondary),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          // Aurora ambient blobs
          Positioned(
            top: -60,
            left: -40,
            child: _AuroraBlob(color: gl.neonPink.withValues(alpha: 0.15), size: 260),
          ),
          Positioned(
            top: 180,
            right: -60,
            child: _AuroraBlob(color: gl.neonPurple.withValues(alpha: 0.12), size: 300),
          ),
          Positioned(
            bottom: 100,
            left: 20,
            child: _AuroraBlob(color: gl.neonCyan.withValues(alpha: 0.10), size: 220),
          ),
          // Content
          threadsAsync.when(
            data: (threads) {
              if (threads.isEmpty) {
                return _GLEmptyState(gl: gl, onTapAphrodite: _openAphroditeChat);
              }
              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 70,
                  bottom: 80,
                  left: 12,
                  right: 12,
                ),
                itemCount: threads.length,
                itemBuilder: (context, index) {
                  final thread = threads[index];
                  final row = thread.isAphrodite
                      ? _GLAphroditeRow(
                          thread: thread,
                          gl: gl,
                          onTap: () => context.push('/chat/${thread.id}'),
                        )
                      : _GLThreadRow(
                          thread: thread,
                          gl: gl,
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
                          color: Colors.red.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                        ),
                        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
                      ),
                      confirmDismiss: (_) => _confirmDelete(context, thread.displayName, gl),
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
              child: CircularProgressIndicator(color: gl.neonPink),
            ),
            error: (err, _) => Center(
              child: Text('Error', style: GoogleFonts.poppins(color: gl.text)),
            ),
          ),
        ],
      ),
      floatingActionButton: _GlassFab(gl: gl, onTap: _openAphroditeChat),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, String name, GlColors gl) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: gl.bgMid.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: gl.borderWhite),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [gl.neonPink, gl.neonCyan]),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Icon(Icons.delete_outline, size: 44, color: gl.neonPink),
                const SizedBox(height: 12),
                Text(
                  'Eliminar conversacion?',
                  style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: gl.text),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text('Cancelar', style: GoogleFonts.poppins(color: gl.textSecondary)),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [gl.neonPink, gl.neonPurple]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: Text(
                            'Eliminar',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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

// ─── Aurora ambient blob ───────────────────────────────────────────────────────

class _AuroraBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _AuroraBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}

// ─── Aphrodite Row ─────────────────────────────────────────────────────────────

class _GLAphroditeRow extends StatelessWidget {
  final ChatThread thread;
  final GlColors gl;
  final VoidCallback onTap;

  const _GLAphroditeRow({required this.thread, required this.gl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: gl.tint,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: gl.borderWhite),
            gradient: LinearGradient(
              colors: [
                gl.neonPink.withValues(alpha: 0.08),
                gl.neonPurple.withValues(alpha: 0.05),
                gl.neonCyan.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  // Neon gradient ring avatar
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [gl.neonPink, gl.neonPurple, gl.neonCyan],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: gl.neonPink.withValues(alpha: 0.4),
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
                          color: gl.bgMid,
                        ),
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
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: gl.text,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _NeonBadge(label: 'AI', gl: gl),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          thread.lastMessageText ?? 'Tu asesora de belleza divina',
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            color: thread.unreadCount > 0 ? gl.text : gl.textMuted,
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
                        _glFormatTime(thread.lastMessageAt),
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          color: thread.unreadCount > 0 ? gl.neonPink : gl.textMuted,
                        ),
                      ),
                      if (thread.unreadCount > 0) ...[
                        const SizedBox(height: 4),
                        _NeonUnreadBadge(count: thread.unreadCount, gl: gl),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Thread Row ────────────────────────────────────────────────────────────────

class _GLThreadRow extends StatelessWidget {
  final ChatThread thread;
  final GlColors gl;
  final VoidCallback onTap;

  const _GLThreadRow({required this.thread, required this.gl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: gl.tint,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: gl.borderWhite),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: gl.surface2,
                      border: Border.all(color: gl.borderWhite),
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
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: gl.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          thread.lastMessageText ?? '',
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            color: thread.unreadCount > 0 ? gl.textSecondary : gl.textMuted,
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
                        _glFormatTime(thread.lastMessageAt),
                        style: GoogleFonts.nunito(fontSize: 11, color: gl.textMuted),
                      ),
                      if (thread.unreadCount > 0) ...[
                        const SizedBox(height: 4),
                        _NeonUnreadBadge(count: thread.unreadCount, gl: gl),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Supporting widgets ────────────────────────────────────────────────────────

class _NeonBadge extends StatelessWidget {
  final String label;
  final GlColors gl;
  const _NeonBadge({required this.label, required this.gl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [gl.neonPink, gl.neonPurple]),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(color: gl.neonPink.withValues(alpha: 0.4), blurRadius: 6),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }
}

class _NeonUnreadBadge extends StatelessWidget {
  final int count;
  final GlColors gl;
  const _NeonUnreadBadge({required this.count, required this.gl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [gl.neonPink, gl.neonPurple]),
        boxShadow: [
          BoxShadow(color: gl.neonPink.withValues(alpha: 0.6), blurRadius: 6, spreadRadius: 1),
        ],
      ),
    );
  }
}

class _GlassFab extends StatelessWidget {
  final GlColors gl;
  final VoidCallback onTap;
  const _GlassFab({required this.gl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                gl.neonPink.withValues(alpha: 0.3),
                gl.neonPurple.withValues(alpha: 0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: gl.neonPink.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(color: gl.neonPink.withValues(alpha: 0.3), blurRadius: 20),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('✨', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      'Habla con Afrodita',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.white,
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
}

class _GLEmptyState extends StatelessWidget {
  final GlColors gl;
  final VoidCallback onTapAphrodite;

  const _GLEmptyState({required this.gl, required this.onTapAphrodite});

  @override
  Widget build(BuildContext context) {
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
                gradient: LinearGradient(
                  colors: [gl.neonPink, gl.neonPurple, gl.neonCyan],
                ),
                boxShadow: [
                  BoxShadow(color: gl.neonPink.withValues(alpha: 0.4), blurRadius: 24),
                ],
              ),
              child: const Center(child: Text('🏛️', style: TextStyle(fontSize: 48))),
            ),
            const SizedBox(height: 24),
            Text(
              'Sin conversaciones',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: gl.text),
            ),
            const SizedBox(height: 32),
            _GlassFab(gl: gl, onTap: onTapAphrodite),
          ],
        ),
      ),
    );
  }
}

String _glFormatTime(DateTime? dt) {
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
