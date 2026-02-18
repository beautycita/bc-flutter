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
import 'mo_widgets.dart';

class MOChatConversationScreen extends ConsumerStatefulWidget {
  final String threadId;
  const MOChatConversationScreen({super.key, required this.threadId});

  @override
  ConsumerState<MOChatConversationScreen> createState() => _MOChatConversationScreenState();
}

class _MOChatConversationScreenState extends ConsumerState<MOChatConversationScreen> {
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
    final mo = MOColors.of(context);
    final messagesAsync = ref.watch(chatMessagesProvider(widget.threadId));
    final threadsAsync = ref.watch(chatThreadsProvider);
    final thread = threadsAsync.whenOrNull(data: (threads) {
      try { return threads.firstWhere((t) => t.id == widget.threadId); } catch (_) { return null; }
    });
    final isAphrodite = thread?.isAphrodite ?? false;
    final title = isAphrodite ? 'Afrodita' : (thread?.displayName ?? 'Chat');

    return Scaffold(
      backgroundColor: mo.surface,
      appBar: AppBar(
        backgroundColor: mo.card,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: mo.orchidPink),
          onPressed: () => context.go('/home'),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            if (isAphrodite) ...[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: mo.orchidGradient,
                  boxShadow: [BoxShadow(color: mo.orchidPink.withValues(alpha: 0.4), blurRadius: 8)],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, color: mo.card),
                    child: const Center(child: Text('🏛️', style: TextStyle(fontSize: 16))),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.quicksand(fontSize: 16, fontWeight: FontWeight.w700, color: mo.orchidLight)),
                if (isAphrodite)
                  Text('Asesora de belleza divina', style: GoogleFonts.quicksand(fontSize: 11, color: mo.textSecondary)),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, decoration: BoxDecoration(
            gradient: LinearGradient(colors: [mo.orchidPink.withValues(alpha: 0.0), mo.orchidPink.withValues(alpha: 0.3), mo.orchidPink.withValues(alpha: 0.0)]),
          )),
        ),
        actions: [
          if (isAphrodite)
            IconButton(icon: Icon(Icons.forum_outlined, color: mo.textSecondary, size: 22), onPressed: () => context.push('/chat/list')),
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
                    if (index == allMessages.length && _isSending) return _MOTypingIndicator(mo: mo);
                    return _MOMessageBubble(message: allMessages[index], isAphroditeThread: isAphrodite, mo: mo);
                  },
                );
              },
              loading: () => Center(child: CircularProgressIndicator(color: mo.orchidPink)),
              error: (err, _) => Center(child: Text('Error: $err', style: GoogleFonts.quicksand(color: mo.orchidPink))),
            ),
          ),
          if (isAphrodite && !_isSending) _MOQuickActionChips(mo: mo, onAction: _onQuickAction),
          _MOInputBar(mo: mo, controller: _textController, isSending: _isSending, isAphrodite: isAphrodite, onSend: _sendMessage, onCamera: _handleCamera),
        ],
      ),
    );
  }

  void _handleCamera() {
    final mo = MOColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: mo.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: mo.orchidPurple.withValues(alpha: 0.3), width: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 3, decoration: BoxDecoration(gradient: mo.orchidGradient, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            InkWell(
              onTap: () { Navigator.pop(ctx); context.push('/studio'); },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(gradient: mo.orchidGradient, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Estudio Virtual', style: GoogleFonts.quicksand(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text('Prueba un nuevo look', style: GoogleFonts.quicksand(fontSize: 12, color: Colors.white70)),
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
                  color: mo.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: mo.orchidPurple.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  Icon(Icons.attach_file_rounded, color: mo.orchidPink, size: 22),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Adjuntar archivo', style: GoogleFonts.quicksand(fontSize: 15, fontWeight: FontWeight.w700, color: mo.text)),
                    Text('Enviar una foto', style: GoogleFonts.quicksand(fontSize: 12, color: mo.textSecondary)),
                  ])),
                  Icon(Icons.chevron_right_rounded, color: mo.textSecondary),
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

class _MOMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isAphroditeThread;
  final MOColors mo;
  const _MOMessageBubble({required this.message, required this.isAphroditeThread, required this.mo});

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
                color: mo.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: mo.orchidPink.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: Image.network(message.mediaUrl!, fit: BoxFit.cover, height: 200, width: double.infinity,
                        errorBuilder: (_, __, ___) => Container(height: 200, color: mo.surface, child: Icon(Icons.image_not_supported, size: 48, color: mo.orchidPink))),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Prueba Virtual', style: GoogleFonts.quicksand(fontSize: 13, fontWeight: FontWeight.w700, color: mo.orchidPink)),
                  ),
                ],
              ),
            ),
            _MOTimeStamp(time: message.createdAt, mo: mo),
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
                  border: isUser ? Border.all(color: mo.orchidPink.withValues(alpha: 0.3)) : null),
              child: ClipRRect(borderRadius: BorderRadius.circular(20),
                  child: Image.network(message.mediaUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(height: 150, color: mo.card, child: Icon(Icons.broken_image, size: 48, color: mo.orchidPink)))),
            ),
            _MOTimeStamp(time: message.createdAt, mo: mo),
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
            // User: orchid gradient border, dark purple fill, extra round
            Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                color: mo.orchidDeep.withValues(alpha: 0.8),
                borderRadius: const BorderRadius.all(Radius.circular(20)),
                border: Border.all(color: mo.orchidPink.withValues(alpha: 0.5), width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(message.textContent ?? '', style: GoogleFonts.quicksand(fontSize: 14, color: mo.text, height: 1.4, fontWeight: FontWeight.w500)),
            )
          else
            // AI: soft purple fill, no border, extra round
            Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                color: mo.card,
                borderRadius: const BorderRadius.all(Radius.circular(20)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(message.textContent ?? '', style: GoogleFonts.quicksand(fontSize: 14, color: mo.textSecondary, height: 1.4)),
            ),
          const SizedBox(height: 2),
          _MOTimeStamp(time: message.createdAt, mo: mo),
        ],
      ),
    );
  }
}

// ─── Typing Indicator (orchid pulsing, floating) ──────────────────────────────

class _MOTypingIndicator extends StatelessWidget {
  final MOColors mo;
  const _MOTypingIndicator({required this.mo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 80),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: mo.card,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
        ),
        child: _MOOrchidDots(mo: mo),
      ),
    );
  }
}

class _MOOrchidDots extends StatefulWidget {
  final MOColors mo;
  const _MOOrchidDots({required this.mo});

  @override
  State<_MOOrchidDots> createState() => _MOOrchidDotsState();
}

class _MOOrchidDotsState extends State<_MOOrchidDots> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
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
            final delay = i * 0.25;
            final v = ((_ctrl.value - delay) % 1.0).clamp(0.0, 1.0);
            final t = math.sin(v * math.pi);
            final opacity = t.clamp(0.3, 1.0);
            final dy = -t * 5.0;
            return Transform.translate(
              offset: Offset(0, dy),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.mo.orchidPink.withValues(alpha: opacity),
                  boxShadow: [BoxShadow(color: widget.mo.orchidPink.withValues(alpha: opacity * 0.5), blurRadius: 6)],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _MOTimeStamp extends StatelessWidget {
  final DateTime time;
  final MOColors mo;
  const _MOTimeStamp({required this.time, required this.mo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(DateFormat.Hm().format(time.toLocal()), style: GoogleFonts.quicksand(fontSize: 11, color: mo.textSecondary)),
    );
  }
}

// ─── Quick Action Chips ────────────────────────────────────────────────────────

class _MOQuickActionChips extends StatelessWidget {
  final MOColors mo;
  final void Function(String) onAction;
  const _MOQuickActionChips({required this.mo, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: mo.card,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(children: [
          _MOActionChip(mo: mo, label: 'Recomienda un look', icon: '💇', onTap: () => onAction('Recomienda un look para mí')),
          const SizedBox(width: 8),
          _MOActionChip(mo: mo, label: 'Prueba virtual', icon: '📸', onTap: () => onAction('Quiero probar un nuevo look virtual')),
          const SizedBox(width: 8),
          _MOActionChip(mo: mo, label: 'Qué servicio?', icon: '🤔', onTap: () => onAction('No sé qué servicio necesito, ayúdame')),
        ]),
      ),
    );
  }
}

class _MOActionChip extends StatelessWidget {
  final MOColors mo;
  final String label;
  final String icon;
  final VoidCallback onTap;
  const _MOActionChip({required this.mo, required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: mo.orchidDeep.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: mo.orchidPurple.withValues(alpha: 0.4), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.quicksand(fontSize: 12, fontWeight: FontWeight.w700, color: mo.orchidPink)),
          ],
        ),
      ),
    );
  }
}

// ─── Input Bar ────────────────────────────────────────────────────────────────

class _MOInputBar extends StatelessWidget {
  final MOColors mo;
  final TextEditingController controller;
  final bool isSending;
  final bool isAphrodite;
  final VoidCallback onSend;
  final VoidCallback onCamera;
  const _MOInputBar({required this.mo, required this.controller, required this.isSending, required this.isAphrodite, required this.onSend, required this.onCamera});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 12, right: 12, top: 8, bottom: MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: mo.card,
        border: Border(top: BorderSide(color: mo.orchidPurple.withValues(alpha: 0.2), width: 0.5)),
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
                  color: mo.surface,
                  border: Border.all(color: mo.orchidPurple.withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.camera_alt_rounded, color: isSending ? mo.textSecondary : mo.orchidPink, size: 20),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: mo.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: mo.orchidPurple.withValues(alpha: 0.25), width: 0.5),
              ),
              child: TextField(
                controller: controller,
                enabled: !isSending,
                maxLines: 4, minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.quicksand(fontSize: 14, color: mo.text),
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  hintStyle: GoogleFonts.quicksand(fontSize: 14, color: mo.textSecondary),
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
                gradient: isSending ? null : mo.orchidGradient,
                color: isSending ? mo.surface : null,
                shape: BoxShape.circle,
                boxShadow: isSending ? null : [BoxShadow(color: mo.orchidPink.withValues(alpha: 0.4), blurRadius: 10)],
              ),
              child: isSending
                  ? Padding(padding: const EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: mo.orchidPink))
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
