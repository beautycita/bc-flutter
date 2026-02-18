import 'dart:math' as math;
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
import 'on_widgets.dart';

class ONChatConversationScreen extends ConsumerStatefulWidget {
  final String threadId;
  const ONChatConversationScreen({super.key, required this.threadId});

  @override
  ConsumerState<ONChatConversationScreen> createState() => _ONChatConversationScreenState();
}

class _ONChatConversationScreenState extends ConsumerState<ONChatConversationScreen> {
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
    final on = ONColors.of(context);
    final messagesAsync = ref.watch(chatMessagesProvider(widget.threadId));
    final threadsAsync = ref.watch(chatThreadsProvider);
    final thread = threadsAsync.whenOrNull(data: (threads) {
      try { return threads.firstWhere((t) => t.id == widget.threadId); } catch (_) { return null; }
    });
    final isAphrodite = thread?.isAphrodite ?? false;
    final title = isAphrodite ? 'AFRODITA' : (thread?.displayName?.toUpperCase() ?? 'CHAT');

    return Scaffold(
      backgroundColor: on.surface0,
      appBar: AppBar(
        backgroundColor: on.surface1,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: on.cyan), onPressed: () => context.go('/home')),
        titleSpacing: 0,
        title: Row(
          children: [
            if (isAphrodite) ...[
              ClipPath(
                clipper: const ONAngularClipper(clipSize: 8),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(gradient: on.cyanGradient),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: ClipPath(
                      clipper: const ONAngularClipper(clipSize: 6),
                      child: Container(color: on.surface1, child: const Center(child: Text('🏛️', style: TextStyle(fontSize: 14)))),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFontsHelper.rajdhani(fontSize: 15, fontWeight: FontWeight.w700, color: on.cyan, letterSpacing: 2.0)),
                if (isAphrodite)
                  Text('ASESORA DE BELLEZA', style: GoogleFontsHelper.rajdhani(fontSize: 10, color: on.textMuted, letterSpacing: 1.5)),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, decoration: BoxDecoration(
            gradient: LinearGradient(colors: [on.cyan.withValues(alpha: 0.0), on.cyan.withValues(alpha: 0.4), on.cyan.withValues(alpha: 0.0)]),
          )),
        ),
        actions: [
          if (isAphrodite)
            IconButton(icon: Icon(Icons.forum_outlined, color: on.textMuted, size: 22), onPressed: () => context.push('/chat/list')),
        ],
      ),
      body: Column(
        children: [
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
                    if (index == allMessages.length && _isSending) return _ONTerminalTyping(on: on);
                    return _ONMessageBubble(message: allMessages[index], isAphroditeThread: isAphrodite, on: on);
                  },
                );
              },
              loading: () => Center(child: ONDataDots()),
              error: (err, _) => Center(child: Text('ERROR: $err', style: GoogleFontsHelper.rajdhani(color: on.red, fontSize: 14))),
            ),
          ),
          if (isAphrodite && !_isSending) _ONQuickActionChips(on: on, onAction: _onQuickAction),
          _ONInputBar(on: on, controller: _textController, isSending: _isSending, isAphrodite: isAphrodite, onSend: _sendMessage, onCamera: _handleCamera),
        ],
      ),
    );
  }

  void _handleCamera() {
    final on = ONColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: on.surface2,
          border: Border(top: BorderSide(color: on.cyan.withValues(alpha: 0.3), width: 1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 2, color: on.cyan.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            InkWell(
              onTap: () { Navigator.pop(ctx); context.push('/studio'); },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(gradient: on.cyanGradient, boxShadow: [BoxShadow(color: on.cyan.withValues(alpha: 0.3), blurRadius: 12)]),
                child: Row(children: [
                  Icon(Icons.auto_awesome, color: on.surface0, size: 22),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('ESTUDIO VIRTUAL', style: GoogleFontsHelper.rajdhani(fontSize: 14, fontWeight: FontWeight.w700, color: on.surface0, letterSpacing: 1.5)),
                    Text('Prueba un nuevo look', style: GoogleFonts.sourceSans3(fontSize: 12, color: on.surface0.withValues(alpha: 0.7))),
                  ])),
                  Icon(Icons.chevron_right_rounded, color: on.surface0.withValues(alpha: 0.7)),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () { Navigator.pop(ctx); _pickAndSendAttachment(); },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: on.surface3,
                  border: Border.all(color: on.cyan.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  Icon(Icons.attach_file_rounded, color: on.cyan, size: 22),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('ADJUNTAR', style: GoogleFontsHelper.rajdhani(fontSize: 14, fontWeight: FontWeight.w700, color: on.text, letterSpacing: 1)),
                    Text('Enviar una foto', style: GoogleFonts.sourceSans3(fontSize: 12, color: on.textMuted)),
                  ])),
                  Icon(Icons.chevron_right_rounded, color: on.textMuted),
                ]),
              ),
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
          ],
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

// ─── Message Bubble ────────────────────────────────────────────────────────────

class _ONMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isAphroditeThread;
  final ONColors on;
  const _ONMessageBubble({required this.message, required this.isAphroditeThread, required this.on});

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
            Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                color: on.surface2,
                border: Border.all(color: on.cyan.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.network(message.mediaUrl!, fit: BoxFit.cover, height: 200, width: double.infinity,
                      errorBuilder: (_, __, ___) => Container(height: 200, color: on.surface3, child: Icon(Icons.image_not_supported, size: 48, color: on.cyan))),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text('PRUEBA VIRTUAL', style: GoogleFontsHelper.rajdhani(fontSize: 12, fontWeight: FontWeight.w700, color: on.cyan, letterSpacing: 2)),
                  ),
                ],
              ),
            ),
            _ONTimeStamp(time: message.createdAt, on: on),
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
            ClipPath(
              clipper: ONAngularClipper(clipSize: isUser ? 12 : 8),
              child: Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
                child: Image.network(message.mediaUrl!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(height: 150, color: on.surface3, child: Icon(Icons.broken_image, size: 48, color: on.cyan))),
              ),
            ),
            _ONTimeStamp(time: message.createdAt, on: on),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          if (isUser)
            // User: angular clipped with cyan left border
            ClipPath(
              clipper: const ONAngularClipper(clipSize: 12),
              child: Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                decoration: BoxDecoration(
                  color: on.surface3,
                  border: Border(left: BorderSide(color: on.cyan, width: 2)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Text(message.textContent ?? '', style: GoogleFonts.sourceSans3(fontSize: 14, color: on.text, height: 1.4)),
              ),
            )
          else
            // AI: flat-cornered container, subtle cyan tint on right border
            Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                color: on.surface2,
                border: Border(right: BorderSide(color: on.cyan.withValues(alpha: 0.3), width: 1)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Text(message.textContent ?? '', style: GoogleFonts.sourceSans3(fontSize: 14, color: on.textSecondary, height: 1.4)),
            ),
          const SizedBox(height: 2),
          _ONTimeStamp(time: message.createdAt, on: on),
        ],
      ),
    );
  }
}

// ─── Terminal Typing (block cursor blink) ─────────────────────────────────────

class _ONTerminalTyping extends StatelessWidget {
  final ONColors on;
  const _ONTerminalTyping({required this.on});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 80),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: on.surface2,
          border: Border(left: BorderSide(color: on.cyan.withValues(alpha: 0.5), width: 1.5)),
        ),
        child: _ONBlockCursor(on: on),
      ),
    );
  }
}

class _ONBlockCursor extends StatefulWidget {
  final ONColors on;
  const _ONBlockCursor({required this.on});

  @override
  State<_ONBlockCursor> createState() => _ONBlockCursorState();
}

class _ONBlockCursorState extends State<_ONBlockCursor> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 530))..repeat();
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) setState(() => _visible = !_visible);
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 50),
      child: Container(
        width: 10,
        height: 16,
        color: widget.on.cyan,
      ),
    );
  }
}

// ─── Timestamp (Fira Code) ─────────────────────────────────────────────────────

class _ONTimeStamp extends StatelessWidget {
  final DateTime time;
  final ONColors on;
  const _ONTimeStamp({required this.time, required this.on});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        DateFormat.Hm().format(time.toLocal()),
        style: GoogleFontsHelper.monospace(fontSize: 10, color: on.textMuted),
      ),
    );
  }
}

// ─── Quick Action Chips ────────────────────────────────────────────────────────

class _ONQuickActionChips extends StatelessWidget {
  final ONColors on;
  final void Function(String) onAction;
  const _ONQuickActionChips({required this.on, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: on.surface1,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(children: [
          _ONActionChip(on: on, label: 'LOOK', icon: '💇', onTap: () => onAction('Recomienda un look para mí')),
          const SizedBox(width: 8),
          _ONActionChip(on: on, label: 'VIRTUAL', icon: '📸', onTap: () => onAction('Quiero probar un nuevo look virtual')),
          const SizedBox(width: 8),
          _ONActionChip(on: on, label: 'AYUDA', icon: '🤔', onTap: () => onAction('No sé qué servicio necesito, ayúdame')),
        ]),
      ),
    );
  }
}

class _ONActionChip extends StatelessWidget {
  final ONColors on;
  final String label;
  final String icon;
  final VoidCallback onTap;
  const _ONActionChip({required this.on, required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: on.surface2,
          border: Border.all(color: on.cyan.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Text(label, style: GoogleFontsHelper.rajdhani(fontSize: 11, fontWeight: FontWeight.w700, color: on.cyan, letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }
}

// ─── Input Bar ────────────────────────────────────────────────────────────────

class _ONInputBar extends StatelessWidget {
  final ONColors on;
  final TextEditingController controller;
  final bool isSending;
  final bool isAphrodite;
  final VoidCallback onSend;
  final VoidCallback onCamera;
  const _ONInputBar({required this.on, required this.controller, required this.isSending, required this.isAphrodite, required this.onSend, required this.onCamera});

  @override
  Widget build(BuildContext context) {
    return ONHudFrame(
      color: on.cyan,
      bracketSize: 10,
      padding: EdgeInsets.only(left: 12, right: 12, top: 10, bottom: MediaQuery.of(context).padding.bottom + 10),
      child: Container(
        color: on.surface1,
        child: Row(
          children: [
            if (isAphrodite) ...[
              GestureDetector(
                onTap: isSending ? null : onCamera,
                child: Container(
                  width: 40, height: 40,
                  color: on.surface2,
                  child: Icon(Icons.camera_alt_rounded, color: isSending ? on.textMuted : on.cyan, size: 18),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: on.surface0,
                  border: Border.all(color: on.cyan.withValues(alpha: 0.25)),
                ),
                child: TextField(
                  controller: controller,
                  enabled: !isSending,
                  maxLines: 4, minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  style: GoogleFonts.sourceSans3(fontSize: 14, color: on.text),
                  decoration: InputDecoration(
                    hintText: 'ESCRIBE UN MENSAJE...',
                    hintStyle: GoogleFontsHelper.rajdhani(fontSize: 12, color: on.textMuted, letterSpacing: 1),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: isSending ? null : onSend,
              child: ClipPath(
                clipper: const ONAngularClipper(clipSize: 8),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    gradient: isSending ? null : on.cyanGradient,
                    color: isSending ? on.surface3 : null,
                    boxShadow: isSending ? null : [BoxShadow(color: on.cyan.withValues(alpha: 0.35), blurRadius: 10)],
                  ),
                  child: isSending
                      ? Padding(padding: const EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: on.cyan))
                      : Icon(Icons.send_rounded, color: on.surface0, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
