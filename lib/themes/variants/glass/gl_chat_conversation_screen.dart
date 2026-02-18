import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../models/chat_message.dart';
import '../../../providers/chat_provider.dart';
import '../../../services/supabase_client.dart';
import 'gl_widgets.dart';

class GLChatConversationScreen extends ConsumerStatefulWidget {
  final String threadId;
  const GLChatConversationScreen({super.key, required this.threadId});

  @override
  ConsumerState<GLChatConversationScreen> createState() => _GLChatConversationScreenState();
}

class _GLChatConversationScreenState extends ConsumerState<GLChatConversationScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  final List<ChatMessage> _optimisticMessages = [];

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(_scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;
    _textController.clear();
    final optimisticMsg = ChatMessage(
      id: const Uuid().v4(),
      threadId: widget.threadId,
      senderType: 'user',
      senderId: SupabaseClientService.currentUserId,
      contentType: 'text',
      textContent: text,
      createdAt: DateTime.now().toUtc(),
    );
    setState(() { _optimisticMessages.add(optimisticMsg); _isSending = true; });
    _scrollToBottom();
    await ref.read(sendMessageProvider.notifier).send(widget.threadId, text);
    if (mounted) { setState(() { _optimisticMessages.clear(); _isSending = false; }); _scrollToBottom(); }
  }

  void _onQuickAction(String text) { _textController.text = text; _sendMessage(); }

  @override
  Widget build(BuildContext context) {
    final gl = GlColors.of(context);
    final messagesAsync = ref.watch(chatMessagesProvider(widget.threadId));
    final threadsAsync = ref.watch(chatThreadsProvider);
    final thread = threadsAsync.whenOrNull(data: (threads) {
      try { return threads.firstWhere((t) => t.id == widget.threadId); } catch (_) { return null; }
    });
    final isAphrodite = thread?.isAphrodite ?? false;
    final title = isAphrodite ? 'Afrodita' : (thread?.displayName ?? 'Chat');

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
                color: gl.bgDeep.withValues(alpha: 0.75),
                border: Border(bottom: BorderSide(color: gl.borderWhite, width: 0.5)),
              ),
            ),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: gl.neonCyan),
          onPressed: () => context.go('/home'),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            if (isAphrodite) ...[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [gl.neonPink, gl.neonPurple, gl.neonCyan]),
                  boxShadow: [BoxShadow(color: gl.neonPink.withValues(alpha: 0.4), blurRadius: 8)],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: ClipOval(child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(color: gl.bgMid.withValues(alpha: 0.8), child: const Center(child: Text('🏛️', style: TextStyle(fontSize: 14)))),
                  )),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (b) => LinearGradient(colors: [gl.neonPink, gl.neonPurple]).createShader(b),
                  child: Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
                if (isAphrodite)
                  Text('Asesora de belleza divina', style: GoogleFonts.nunito(fontSize: 11, color: gl.textMuted)),
              ],
            ),
          ],
        ),
        actions: [
          if (isAphrodite)
            IconButton(
              icon: Icon(Icons.forum_outlined, color: gl.textSecondary, size: 22),
              onPressed: () => context.push('/chat/list'),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Ambient background blobs
          Positioned(top: 60, right: -40, child: _GLAmbientBlob(color: gl.neonPink.withValues(alpha: 0.08), size: 200)),
          Positioned(bottom: 120, left: -30, child: _GLAmbientBlob(color: gl.neonCyan.withValues(alpha: 0.07), size: 180)),
          Column(
            children: [
              SizedBox(height: MediaQuery.of(context).padding.top + 60),
              Expanded(
                child: messagesAsync.when(
                  data: (messages) {
                    final streamIds = messages.map((m) => m.id).toSet();
                    final pendingOptimistic = _optimisticMessages.where((o) =>
                        !streamIds.contains(o.id) &&
                        !messages.any((m) => m.senderType == 'user' && m.textContent == o.textContent && m.createdAt.difference(o.createdAt).inSeconds.abs() < 10)
                    ).toList();
                    final allMessages = [...messages, ...pendingOptimistic];
                    allMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                    return ListView.builder(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      itemCount: allMessages.length + (_isSending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == allMessages.length && _isSending) return _GLTypingIndicator(gl: gl);
                        return _GLMessageBubble(message: allMessages[index], isAphroditeThread: isAphrodite, gl: gl);
                      },
                    );
                  },
                  loading: () => Center(child: CircularProgressIndicator(color: gl.neonPink)),
                  error: (err, _) => Center(child: Text('Error: $err', style: GoogleFonts.poppins(color: gl.text))),
                ),
              ),
              if (isAphrodite && !_isSending) _GLQuickActionChips(gl: gl, onAction: _onQuickAction),
              _GLInputBar(gl: gl, controller: _textController, isSending: _isSending, isAphrodite: isAphrodite, onSend: _sendMessage, onCamera: _handleCamera),
            ],
          ),
        ],
      ),
    );
  }

  void _handleCamera() {
    final gl = GlColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: gl.bgMid.withValues(alpha: 0.85),
              border: Border(top: BorderSide(color: gl.borderWhite)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () { Navigator.pop(ctx); context.push('/studio'); },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [gl.neonPink, gl.neonPurple]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Estudio Virtual', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                        Text('Prueba un nuevo look', style: GoogleFonts.nunito(fontSize: 12, color: Colors.white70)),
                      ])),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () { Navigator.pop(ctx); _pickAndSendAttachment(); },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: gl.tint,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: gl.borderWhite),
                    ),
                    child: Row(children: [
                      Icon(Icons.attach_file_rounded, color: gl.neonCyan, size: 22),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Adjuntar archivo', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: gl.text)),
                        Text('Enviar una foto', style: GoogleFonts.nunito(fontSize: 12, color: gl.textMuted)),
                      ])),
                      Icon(Icons.chevron_right_rounded, color: gl.textMuted),
                    ]),
                  ),
                ),
                SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndSendAttachment() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (image == null) return;
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adjuntos disponibles pronto')));
  }
}

// ─── Ambient Blob ──────────────────────────────────────────────────────────────

class _GLAmbientBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _GLAmbientBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}

// ─── Message Bubble ────────────────────────────────────────────────────────────

class _GLMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isAphroditeThread;
  final GlColors gl;
  const _GLMessageBubble({required this.message, required this.isAphroditeThread, required this.gl});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isFromUser;
    final alignment = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    if (message.isTryOnResult && message.mediaUrl != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                  decoration: BoxDecoration(
                    color: gl.tint,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: gl.neonPink.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: Image.network(message.mediaUrl!, fit: BoxFit.cover, height: 200, width: double.infinity,
                            errorBuilder: (_, __, ___) => Container(height: 200, color: gl.surface2, child: Icon(Icons.image_not_supported, size: 48, color: gl.neonPink))),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: ShaderMask(
                          shaderCallback: (b) => LinearGradient(colors: [gl.neonPink, gl.neonPurple]).createShader(b),
                          child: Text('Prueba Virtual', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _GLTimeStamp(time: message.createdAt, gl: gl),
          ],
        ),
      );
    }

    if (message.contentType == 'image' && message.mediaUrl != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: alignment,
          children: [
            Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
                  border: isUser ? Border.all(color: gl.neonPink.withValues(alpha: 0.4)) : null),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(message.mediaUrl!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(height: 150, color: gl.surface2, child: Icon(Icons.broken_image, size: 48, color: gl.neonPink))),
              ),
            ),
            _GLTimeStamp(time: message.createdAt, gl: gl),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                decoration: BoxDecoration(
                  color: isUser ? gl.neonPink.withValues(alpha: 0.15) : gl.tint,
                  border: isUser
                      ? Border.all(color: gl.neonPink.withValues(alpha: 0.4))
                      : Border.all(color: gl.borderWhite),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 16),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Text(
                  message.textContent ?? '',
                  style: GoogleFonts.nunito(fontSize: 14, color: gl.text, height: 1.4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          _GLTimeStamp(time: message.createdAt, gl: gl),
        ],
      ),
    );
  }
}

// ─── Typing Indicator (neon color cycling dots) ────────────────────────────────

class _GLTypingIndicator extends StatelessWidget {
  final GlColors gl;
  const _GLTypingIndicator({required this.gl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4), topRight: Radius.circular(14),
          bottomLeft: Radius.circular(14), bottomRight: Radius.circular(14),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: gl.tint,
              border: Border.all(color: gl.borderWhite),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4), topRight: Radius.circular(14),
                bottomLeft: Radius.circular(14), bottomRight: Radius.circular(14),
              ),
            ),
            child: _GLNeonDots(gl: gl),
          ),
        ),
      ),
    );
  }
}

class _GLNeonDots extends StatefulWidget {
  final GlColors gl;
  const _GLNeonDots({required this.gl});

  @override
  State<_GLNeonDots> createState() => _GLNeonDotsState();
}

class _GLNeonDotsState extends State<_GLNeonDots> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final colors = [widget.gl.neonPink, widget.gl.neonPurple, widget.gl.neonCyan];
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final v = ((_ctrl.value - delay) % 1.0).clamp(0.0, 1.0);
            final opacity = (math.sin(v * math.pi)).clamp(0.2, 1.0);
            final color = colors[(_ctrl.value * 3 + i).floor() % 3];
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 8, height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: opacity),
                boxShadow: [BoxShadow(color: color.withValues(alpha: opacity * 0.6), blurRadius: 6)],
              ),
            );
          }),
        );
      },
    );
  }
}

// ─── Timestamp ────────────────────────────────────────────────────────────────

class _GLTimeStamp extends StatelessWidget {
  final DateTime time;
  final GlColors gl;
  const _GLTimeStamp({required this.time, required this.gl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        DateFormat.Hm().format(time.toLocal()),
        style: GoogleFonts.nunito(fontSize: 11, color: gl.textMuted),
      ),
    );
  }
}

// ─── Quick Action Chips ────────────────────────────────────────────────────────

class _GLQuickActionChips extends StatelessWidget {
  final GlColors gl;
  final void Function(String) onAction;
  const _GLQuickActionChips({required this.gl, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          color: gl.bgDeep.withValues(alpha: 0.6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _GLActionChip(gl: gl, label: 'Recomienda un look', icon: '💇', onTap: () => onAction('Recomienda un look para mí')),
                const SizedBox(width: 8),
                _GLActionChip(gl: gl, label: 'Prueba virtual', icon: '📸', onTap: () => onAction('Quiero probar un nuevo look virtual')),
                const SizedBox(width: 8),
                _GLActionChip(gl: gl, label: 'Qué servicio?', icon: '🤔', onTap: () => onAction('No sé qué servicio necesito, ayúdame')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GLActionChip extends StatelessWidget {
  final GlColors gl;
  final String label;
  final String icon;
  final VoidCallback onTap;
  const _GLActionChip({required this.gl, required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: gl.neonPink.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: gl.neonPink.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(icon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(label, style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: gl.neonPink)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Input Bar ────────────────────────────────────────────────────────────────

class _GLInputBar extends StatelessWidget {
  final GlColors gl;
  final TextEditingController controller;
  final bool isSending;
  final bool isAphrodite;
  final VoidCallback onSend;
  final VoidCallback onCamera;
  const _GLInputBar({required this.gl, required this.controller, required this.isSending, required this.isAphrodite, required this.onSend, required this.onCamera});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(left: 12, right: 12, top: 8, bottom: MediaQuery.of(context).padding.bottom + 8),
          decoration: BoxDecoration(
            color: gl.bgDeep.withValues(alpha: 0.7),
            border: Border(top: BorderSide(color: gl.borderWhite, width: 0.5)),
          ),
          child: Row(
            children: [
              if (isAphrodite) ...[
                GestureDetector(
                  onTap: isSending ? null : onCamera,
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: gl.tint,
                      border: Border.all(color: gl.borderWhite),
                    ),
                    child: Icon(Icons.camera_alt_rounded, color: isSending ? gl.textMuted : gl.neonCyan, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: gl.tint,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: gl.borderWhite),
                      ),
                      child: TextField(
                        controller: controller,
                        enabled: !isSending,
                        maxLines: 4, minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        style: GoogleFonts.nunito(fontSize: 14, color: gl.text),
                        decoration: InputDecoration(
                          hintText: 'Escribe un mensaje...',
                          hintStyle: GoogleFonts.nunito(fontSize: 14, color: gl.textMuted),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onSubmitted: (_) => onSend(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: isSending ? null : onSend,
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    gradient: isSending ? null : LinearGradient(colors: [gl.neonPink, gl.neonPurple]),
                    color: isSending ? gl.tint : null,
                    shape: BoxShape.circle,
                    boxShadow: isSending ? null : [BoxShadow(color: gl.neonPink.withValues(alpha: 0.5), blurRadius: 12)],
                  ),
                  child: isSending
                      ? Padding(padding: const EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: gl.neonPink))
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
