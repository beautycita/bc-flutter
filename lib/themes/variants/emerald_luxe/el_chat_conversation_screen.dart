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
import 'el_widgets.dart';

class ELChatConversationScreen extends ConsumerStatefulWidget {
  final String threadId;
  const ELChatConversationScreen({super.key, required this.threadId});

  @override
  ConsumerState<ELChatConversationScreen> createState() => _ELChatConversationScreenState();
}

class _ELChatConversationScreenState extends ConsumerState<ELChatConversationScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  final List<ChatMessage> _optimisticMessages = [];
  DateTime? _lastDateGroupDate;

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
    final el = ELColors.of(context);
    final messagesAsync = ref.watch(chatMessagesProvider(widget.threadId));
    final threadsAsync = ref.watch(chatThreadsProvider);
    final thread = threadsAsync.whenOrNull(data: (threads) {
      try { return threads.firstWhere((t) => t.id == widget.threadId); } catch (_) { return null; }
    });
    final isAphrodite = thread?.isAphrodite ?? false;
    final title = isAphrodite ? 'Afrodita' : (thread?.displayName ?? 'Chat');

    return Scaffold(
      backgroundColor: el.bg,
      appBar: AppBar(
        backgroundColor: el.surface,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: el.gold), onPressed: () => context.go('/home')),
        titleSpacing: 0,
        title: Row(
          children: [
            if (isAphrodite) ...[
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [el.gold, el.emerald, el.goldLight]),
                  border: Border.all(color: el.gold.withValues(alpha: 0.5), width: 0.5),
                  boxShadow: [BoxShadow(color: el.gold.withValues(alpha: 0.3), blurRadius: 8)],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, color: el.surface2),
                    child: const Center(child: Text('🏛️', style: TextStyle(fontSize: 16))),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.cinzel(fontSize: 14, fontWeight: FontWeight.w700, color: el.gold)),
                if (isAphrodite)
                  Text('Asesora de belleza', style: GoogleFonts.raleway(fontSize: 10, color: el.textSecondary)),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 0.5, decoration: BoxDecoration(
            gradient: LinearGradient(colors: [el.gold.withValues(alpha: 0.0), el.gold.withValues(alpha: 0.4), el.gold.withValues(alpha: 0.0)]),
          )),
        ),
        actions: [
          if (isAphrodite)
            IconButton(icon: Icon(Icons.forum_outlined, color: el.textSecondary, size: 22), onPressed: () => context.push('/chat/list')),
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
                _lastDateGroupDate = null;
                return ListView.builder(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  itemCount: allMessages.length + (_isSending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == allMessages.length && _isSending) return _ELTypingIndicator(el: el);
                    final msg = allMessages[index];
                    final msgDate = msg.createdAt.toLocal();
                    final dateOnly = DateTime(msgDate.year, msgDate.month, msgDate.day);
                    final showDate = _lastDateGroupDate == null || dateOnly.isAfter(_lastDateGroupDate!);
                    if (showDate) _lastDateGroupDate = dateOnly;
                    return Column(
                      children: [
                        if (showDate) _ELDateDivider(date: dateOnly, el: el),
                        _ELMessageBubble(message: msg, isAphroditeThread: isAphrodite, el: el),
                      ],
                    );
                  },
                );
              },
              loading: () => Center(child: CircularProgressIndicator(color: el.gold)),
              error: (err, _) => Center(child: Text('Error: $err', style: GoogleFonts.raleway(color: el.gold))),
            ),
          ),
          if (isAphrodite && !_isSending) _ELQuickActionChips(el: el, onAction: _onQuickAction),
          _ELInputBar(el: el, controller: _textController, isSending: _isSending, isAphrodite: isAphrodite, onSend: _sendMessage, onCamera: _handleCamera),
        ],
      ),
    );
  }

  void _handleCamera() {
    final el = ELColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: el.surface,
          border: Border(
            top: BorderSide(color: el.gold.withValues(alpha: 0.3), width: 0.5),
            left: BorderSide(color: el.emerald.withValues(alpha: 0.2), width: 0.5),
            right: BorderSide(color: el.emerald.withValues(alpha: 0.2), width: 0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ELGoldenDividerRow(el: el),
            const SizedBox(height: 16),
            InkWell(
              onTap: () { Navigator.pop(ctx); context.push('/studio'); },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: el.goldGradient,
                  border: Border.all(color: el.emerald.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.auto_awesome, color: el.bg, size: 22),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Estudio Virtual', style: GoogleFonts.cinzel(fontSize: 14, fontWeight: FontWeight.w700, color: el.bg)),
                    Text('Prueba un nuevo look', style: GoogleFonts.raleway(fontSize: 12, color: el.bg.withValues(alpha: 0.7))),
                  ])),
                  Icon(Icons.chevron_right_rounded, color: el.bg.withValues(alpha: 0.7)),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () { Navigator.pop(ctx); _pickAndSendAttachment(); },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: el.surface2,
                  border: Border.all(color: el.emerald.withValues(alpha: 0.25)),
                ),
                child: Row(children: [
                  Icon(Icons.attach_file_rounded, color: el.gold, size: 22),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Adjuntar archivo', style: GoogleFonts.cinzel(fontSize: 13, fontWeight: FontWeight.w600, color: el.text)),
                    Text('Enviar una foto', style: GoogleFonts.raleway(fontSize: 12, color: el.textSecondary)),
                  ])),
                  Icon(Icons.chevron_right_rounded, color: el.textSecondary),
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

// ─── Art Deco Date Divider ─────────────────────────────────────────────────────

class _ELDateDivider extends StatelessWidget {
  final DateTime date;
  final ELColors el;
  const _ELDateDivider({required this.date, required this.el});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: _ELGoldenDividerRow(el: el)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: el.gold.withValues(alpha: 0.4), width: 0.5),
            ),
            child: Text(
              DateFormat.MMMd().format(date),
              style: GoogleFonts.cinzel(fontSize: 10, fontWeight: FontWeight.w700, color: el.gold.withValues(alpha: 0.7), letterSpacing: 1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _ELGoldenDividerRow(el: el)),
        ],
      ),
    );
  }
}

class _ELGoldenDividerRow extends StatelessWidget {
  final ELColors el;
  const _ELGoldenDividerRow({required this.el});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 0.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [el.gold.withValues(alpha: 0.0), el.gold.withValues(alpha: 0.3)]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Transform.rotate(
            angle: 0.785,
            child: Container(width: 4, height: 4, color: el.gold.withValues(alpha: 0.4)),
          ),
        ),
        Expanded(
          child: Container(
            height: 0.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [el.gold.withValues(alpha: 0.3), el.gold.withValues(alpha: 0.0)]),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Message Bubble ────────────────────────────────────────────────────────────

class _ELMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isAphroditeThread;
  final ELColors el;
  const _ELMessageBubble({required this.message, required this.isAphroditeThread, required this.el});

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
                color: el.surface,
                border: Border.all(color: el.gold.withValues(alpha: 0.3), width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.network(message.mediaUrl!, fit: BoxFit.cover, height: 200, width: double.infinity,
                      errorBuilder: (_, __, ___) => Container(height: 200, color: el.surface2, child: Icon(Icons.image_not_supported, size: 48, color: el.gold))),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Prueba Virtual', style: GoogleFonts.cinzel(fontSize: 13, fontWeight: FontWeight.w700, color: el.gold)),
                  ),
                ],
              ),
            ),
            _ELTimeStamp(time: message.createdAt, el: el),
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
              decoration: BoxDecoration(border: isUser ? Border.all(color: el.gold.withValues(alpha: 0.3), width: 0.5) : null),
              child: Image.network(message.mediaUrl!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(height: 150, color: el.surface2, child: Icon(Icons.broken_image, size: 48, color: el.gold))),
            ),
            _ELTimeStamp(time: message.createdAt, el: el),
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
            // User: dark emerald with gold left accent line
            Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                color: el.surface2,
                border: Border(
                  left: BorderSide(color: el.gold, width: 2),
                  top: BorderSide(color: el.gold.withValues(alpha: 0.15), width: 0.5),
                  bottom: BorderSide(color: el.gold.withValues(alpha: 0.15), width: 0.5),
                  right: BorderSide(color: el.emerald.withValues(alpha: 0.1), width: 0.5),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Text(message.textContent ?? '', style: GoogleFonts.raleway(fontSize: 14, color: el.text, height: 1.4)),
            )
          else
            // AI: dark emerald, no gold accent
            Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                color: el.surface,
                border: Border.all(color: el.emerald.withValues(alpha: 0.2), width: 0.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Text(message.textContent ?? '', style: GoogleFonts.raleway(fontSize: 14, color: el.textSecondary, height: 1.4)),
            ),
          const SizedBox(height: 2),
          _ELTimeStamp(time: message.createdAt, el: el),
        ],
      ),
    );
  }
}

// ─── Typing Indicator (gold metallic pulsing) ─────────────────────────────────

class _ELTypingIndicator extends StatelessWidget {
  final ELColors el;
  const _ELTypingIndicator({required this.el});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 90),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: el.surface,
          border: Border.all(color: el.gold.withValues(alpha: 0.2), width: 0.5),
        ),
        child: _ELGoldPulsingDots(el: el),
      ),
    );
  }
}

class _ELGoldPulsingDots extends StatefulWidget {
  final ELColors el;
  const _ELGoldPulsingDots({required this.el});

  @override
  State<_ELGoldPulsingDots> createState() => _ELGoldPulsingDotsState();
}

class _ELGoldPulsingDotsState extends State<_ELGoldPulsingDots> with SingleTickerProviderStateMixin {
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
    // Three dots: gold colors — goldDim, gold, goldLight cycling
    final dotColors = [widget.el.goldDim, widget.el.gold, widget.el.goldLight];
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.22;
            final v = ((_ctrl.value - delay) % 1.0).clamp(0.0, 1.0);
            final t = math.sin(v * math.pi);
            final opacity = 0.4 + t * 0.6;
            final scale = 0.7 + t * 0.5;
            return Transform.scale(
              scale: scale,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColors[i].withValues(alpha: opacity),
                  boxShadow: [BoxShadow(color: widget.el.gold.withValues(alpha: opacity * 0.5), blurRadius: 6)],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _ELTimeStamp extends StatelessWidget {
  final DateTime time;
  final ELColors el;
  const _ELTimeStamp({required this.time, required this.el});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(DateFormat.Hm().format(time.toLocal()), style: GoogleFonts.raleway(fontSize: 10, color: el.textSecondary)),
    );
  }
}

// ─── Quick Action Chips ────────────────────────────────────────────────────────

class _ELQuickActionChips extends StatelessWidget {
  final ELColors el;
  final void Function(String) onAction;
  const _ELQuickActionChips({required this.el, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: el.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(children: [
          _ELActionChip(el: el, label: 'Recomienda un look', icon: '💇', onTap: () => onAction('Recomienda un look para mí')),
          const SizedBox(width: 8),
          _ELActionChip(el: el, label: 'Prueba virtual', icon: '📸', onTap: () => onAction('Quiero probar un nuevo look virtual')),
          const SizedBox(width: 8),
          _ELActionChip(el: el, label: 'Qué servicio?', icon: '🤔', onTap: () => onAction('No sé qué servicio necesito, ayúdame')),
        ]),
      ),
    );
  }
}

class _ELActionChip extends StatelessWidget {
  final ELColors el;
  final String label;
  final String icon;
  final VoidCallback onTap;
  const _ELActionChip({required this.el, required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: el.surface2,
          border: Border.all(color: el.gold.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.raleway(fontSize: 12, fontWeight: FontWeight.w700, color: el.gold)),
          ],
        ),
      ),
    );
  }
}

// ─── Input Bar ────────────────────────────────────────────────────────────────

class _ELInputBar extends StatelessWidget {
  final ELColors el;
  final TextEditingController controller;
  final bool isSending;
  final bool isAphrodite;
  final VoidCallback onSend;
  final VoidCallback onCamera;
  const _ELInputBar({required this.el, required this.controller, required this.isSending, required this.isAphrodite, required this.onSend, required this.onCamera});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 12, right: 12, top: 10, bottom: MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: el.surface,
        border: Border(
          top: BorderSide(color: el.gold.withValues(alpha: 0.25), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          if (isAphrodite) ...[
            GestureDetector(
              onTap: isSending ? null : onCamera,
              child: Container(
                width: 44, height: 44,
                color: el.surface2,
                child: Icon(Icons.camera_alt_rounded, color: isSending ? el.textSecondary : el.gold, size: 20),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: el.surface2,
                border: Border.all(color: el.gold.withValues(alpha: 0.2), width: 0.5),
              ),
              child: TextField(
                controller: controller,
                enabled: !isSending,
                maxLines: 4, minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.raleway(fontSize: 14, color: el.text),
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  hintStyle: GoogleFonts.raleway(fontSize: 14, color: el.textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                gradient: isSending ? null : el.goldGradient,
                color: isSending ? el.surface3 : null,
                shape: BoxShape.circle,
                boxShadow: isSending ? null : [BoxShadow(color: el.gold.withValues(alpha: 0.35), blurRadius: 10)],
              ),
              child: isSending
                  ? Padding(padding: const EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: el.gold))
                  : Icon(Icons.send_rounded, color: el.bg, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
