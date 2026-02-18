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
import 'cb_widgets.dart';

class CBChatConversationScreen extends ConsumerStatefulWidget {
  final String threadId;
  const CBChatConversationScreen({super.key, required this.threadId});

  @override
  ConsumerState<CBChatConversationScreen> createState() => _CBChatConversationScreenState();
}

class _CBChatConversationScreenState extends ConsumerState<CBChatConversationScreen> {
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
    final cb = CBColors.of(context);
    final messagesAsync = ref.watch(chatMessagesProvider(widget.threadId));
    final threadsAsync = ref.watch(chatThreadsProvider);
    final thread = threadsAsync.whenOrNull(data: (threads) {
      try { return threads.firstWhere((t) => t.id == widget.threadId); } catch (_) { return null; }
    });
    final isAphrodite = thread?.isAphrodite ?? false;
    final title = isAphrodite ? 'Afrodita' : (thread?.displayName ?? 'Chat');

    return Scaffold(
      backgroundColor: cb.bg,
      appBar: AppBar(
        backgroundColor: cb.card,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: cb.pink), onPressed: () => context.go('/home')),
        titleSpacing: 0,
        title: Row(
          children: [
            if (isAphrodite) ...[
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [cb.pink, cb.lavender]),
                  boxShadow: [BoxShadow(color: cb.pink.withValues(alpha: 0.3), blurRadius: 8)],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, color: cb.card),
                    child: const Center(child: Text('🏛️', style: TextStyle(fontSize: 16))),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.cormorantGaramond(fontSize: 18, fontWeight: FontWeight.w600, color: cb.text)),
                if (isAphrodite)
                  Text('Asesora de belleza divina', style: GoogleFonts.nunito(fontSize: 11, color: cb.textSoft)),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, decoration: BoxDecoration(
            gradient: LinearGradient(colors: [cb.pink.withValues(alpha: 0.0), cb.pink.withValues(alpha: 0.2), cb.pink.withValues(alpha: 0.0)]),
          )),
        ),
        actions: [
          if (isAphrodite)
            IconButton(icon: Icon(Icons.forum_outlined, color: cb.textSoft, size: 22), onPressed: () => context.push('/chat/list')),
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
                    if (index == allMessages.length && _isSending) return _CBTypingIndicator(cb: cb);
                    return _CBMessageBubble(message: allMessages[index], isAphroditeThread: isAphrodite, cb: cb);
                  },
                );
              },
              loading: () => Center(child: CircularProgressIndicator(color: cb.pink)),
              error: (err, _) => Center(child: Text('Error: $err', style: GoogleFonts.nunito(color: cb.pink))),
            ),
          ),
          if (isAphrodite && !_isSending) _CBQuickActionChips(cb: cb, onAction: _onQuickAction),
          _CBInputBar(cb: cb, controller: _textController, isSending: _isSending, isAphrodite: isAphrodite, onSend: _sendMessage, onCamera: _handleCamera),
        ],
      ),
    );
  }

  void _handleCamera() {
    final cb = CBColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cb.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: cb.border, width: 1)),
          boxShadow: [BoxShadow(color: cb.pink.withValues(alpha: 0.1), blurRadius: 20, spreadRadius: 2)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 3, decoration: BoxDecoration(color: cb.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () { Navigator.pop(ctx); context.push('/studio'); },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [cb.pink, cb.lavender]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(children: [
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Estudio Virtual', style: GoogleFonts.cormorantGaramond(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                    Text('Prueba un nuevo look con IA', style: GoogleFonts.nunito(fontSize: 12, color: Colors.white70)),
                  ])),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white70),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () { Navigator.pop(ctx); _pickAndSendAttachment(); },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cb.pinkLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  Icon(Icons.attach_file_rounded, color: cb.pink, size: 22),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Adjuntar archivo', style: GoogleFonts.cormorantGaramond(fontSize: 16, fontWeight: FontWeight.w600, color: cb.text)),
                    Text('Enviar una foto', style: GoogleFonts.nunito(fontSize: 12, color: cb.textSoft)),
                  ])),
                  Icon(Icons.chevron_right_rounded, color: cb.textSoft),
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

class _CBMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isAphroditeThread;
  final CBColors cb;
  const _CBMessageBubble({required this.message, required this.isAphroditeThread, required this.cb});

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
                color: cb.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cb.border),
                boxShadow: [BoxShadow(color: cb.pink.withValues(alpha: 0.1), blurRadius: 12)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: Image.network(message.mediaUrl!, fit: BoxFit.cover, height: 200, width: double.infinity,
                        errorBuilder: (_, __, ___) => Container(height: 200, color: cb.pinkLight, child: Icon(Icons.image_not_supported, size: 48, color: cb.pink))),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Prueba Virtual', style: GoogleFonts.cormorantGaramond(fontSize: 14, fontWeight: FontWeight.w600, color: cb.pink)),
                  ),
                ],
              ),
            ),
            _CBTimeStamp(time: message.createdAt, cb: cb),
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
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: cb.pink.withValues(alpha: 0.1), blurRadius: 10)]),
              child: ClipRRect(borderRadius: BorderRadius.circular(20),
                  child: Image.network(message.mediaUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(height: 150, color: cb.pinkLight, child: Icon(Icons.broken_image, size: 48, color: cb.pink)))),
            ),
            _CBTimeStamp(time: message.createdAt, cb: cb),
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
            // User: soft pink gradient fill, very rounded
            Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cb.pink.withValues(alpha: 0.85), cb.lavender.withValues(alpha: 0.85)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.all(Radius.circular(22)),
                boxShadow: [BoxShadow(color: cb.pink.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(message.textContent ?? '', style: GoogleFonts.nunito(fontSize: 14, color: Colors.white, height: 1.4)),
            )
          else
            // AI: white card with gentle pink shadow
            Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                color: cb.card,
                borderRadius: const BorderRadius.all(Radius.circular(22)),
                boxShadow: [BoxShadow(color: cb.pink.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 2))],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(message.textContent ?? '', style: GoogleFonts.nunito(fontSize: 14, color: cb.text, height: 1.4)),
            ),
          const SizedBox(height: 2),
          _CBTimeStamp(time: message.createdAt, cb: cb),
        ],
      ),
    );
  }
}

// ─── Typing Indicator (soft pink gentle bounce) ────────────────────────────────

class _CBTypingIndicator extends StatelessWidget {
  final CBColors cb;
  const _CBTypingIndicator({required this.cb});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 80),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cb.card,
          borderRadius: const BorderRadius.all(Radius.circular(22)),
          boxShadow: [BoxShadow(color: cb.pink.withValues(alpha: 0.08), blurRadius: 10)],
        ),
        child: _CBBouncingDots(cb: cb),
      ),
    );
  }
}

class _CBBouncingDots extends StatefulWidget {
  final CBColors cb;
  const _CBBouncingDots({required this.cb});

  @override
  State<_CBBouncingDots> createState() => _CBBouncingDotsState();
}

class _CBBouncingDotsState extends State<_CBBouncingDots> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final v = ((_ctrl.value - delay) % 1.0).clamp(0.0, 1.0);
            final t = math.sin(v * math.pi);
            final dy = -t * 5.0;
            return Transform.translate(
              offset: Offset(0, dy),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.cb.pink.withValues(alpha: 0.6 + t * 0.4),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _CBTimeStamp extends StatelessWidget {
  final DateTime time;
  final CBColors cb;
  const _CBTimeStamp({required this.time, required this.cb});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(DateFormat.Hm().format(time.toLocal()), style: GoogleFonts.nunito(fontSize: 11, color: cb.textSoft)),
    );
  }
}

// ─── Quick Action Chips ────────────────────────────────────────────────────────

class _CBQuickActionChips extends StatelessWidget {
  final CBColors cb;
  final void Function(String) onAction;
  const _CBQuickActionChips({required this.cb, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cb.card,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(children: [
          _CBActionChip(cb: cb, label: 'Recomienda un look', icon: '💇', onTap: () => onAction('Recomienda un look para mí')),
          const SizedBox(width: 8),
          _CBActionChip(cb: cb, label: 'Prueba virtual', icon: '📸', onTap: () => onAction('Quiero probar un nuevo look virtual')),
          const SizedBox(width: 8),
          _CBActionChip(cb: cb, label: 'Qué servicio?', icon: '🤔', onTap: () => onAction('No sé qué servicio necesito, ayúdame')),
        ]),
      ),
    );
  }
}

class _CBActionChip extends StatelessWidget {
  final CBColors cb;
  final String label;
  final String icon;
  final VoidCallback onTap;
  const _CBActionChip({required this.cb, required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cb.pinkLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cb.pink.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: cb.pink)),
          ],
        ),
      ),
    );
  }
}

// ─── Input Bar ────────────────────────────────────────────────────────────────

class _CBInputBar extends StatelessWidget {
  final CBColors cb;
  final TextEditingController controller;
  final bool isSending;
  final bool isAphrodite;
  final VoidCallback onSend;
  final VoidCallback onCamera;
  const _CBInputBar({required this.cb, required this.controller, required this.isSending, required this.isAphrodite, required this.onSend, required this.onCamera});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 12, right: 12, top: 8, bottom: MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: cb.card,
        boxShadow: [BoxShadow(color: cb.pink.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -2))],
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
                  color: cb.pinkLight,
                ),
                child: Icon(Icons.camera_alt_rounded, color: isSending ? cb.textSoft : cb.pink, size: 20),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: cb.bg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: cb.pink.withValues(alpha: 0.15)),
              ),
              child: TextField(
                controller: controller,
                enabled: !isSending,
                maxLines: 4, minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.nunito(fontSize: 14, color: cb.text),
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  hintStyle: GoogleFonts.nunito(fontSize: 14, color: cb.textSoft),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isSending ? null : onSend,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: isSending ? null : LinearGradient(colors: [cb.pink, cb.lavender]),
                color: isSending ? cb.pinkLight : null,
                shape: BoxShape.circle,
                boxShadow: isSending ? null : [BoxShadow(color: cb.pink.withValues(alpha: 0.3), blurRadius: 10)],
              ),
              child: isSending
                  ? Padding(padding: const EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: cb.pink))
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
