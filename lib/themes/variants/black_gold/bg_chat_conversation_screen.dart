import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../config/theme_extension.dart';
import '../../../models/chat_message.dart';
import '../../../providers/chat_provider.dart';
import '../../../services/supabase_client.dart';
import 'bg_widgets.dart';

class BGChatConversationScreen extends ConsumerStatefulWidget {
  final String threadId;
  const BGChatConversationScreen({super.key, required this.threadId});

  @override
  ConsumerState<BGChatConversationScreen> createState() => _BGChatConversationScreenState();
}

class _BGChatConversationScreenState extends ConsumerState<BGChatConversationScreen> {
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
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
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
    setState(() {
      _optimisticMessages.add(optimisticMsg);
      _isSending = true;
    });
    _scrollToBottom();
    await ref.read(sendMessageProvider.notifier).send(widget.threadId, text);
    if (mounted) {
      setState(() {
        _optimisticMessages.clear();
        _isSending = false;
      });
      _scrollToBottom();
    }
  }

  void _onQuickAction(String text) {
    _textController.text = text;
    _sendMessage();
  }

  @override
  Widget build(BuildContext context) {
    final bg = BGColors.of(context);
    final messagesAsync = ref.watch(chatMessagesProvider(widget.threadId));
    final threadsAsync = ref.watch(chatThreadsProvider);
    final thread = threadsAsync.whenOrNull(data: (threads) {
      try { return threads.firstWhere((t) => t.id == widget.threadId); } catch (_) { return null; }
    });
    final isAphrodite = thread?.isAphrodite ?? false;
    final title = isAphrodite ? 'Afrodita' : (thread?.displayName ?? 'Chat');

    return Scaffold(
      backgroundColor: bg.surface0,
      appBar: AppBar(
        backgroundColor: bg.surface1,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: bg.goldMid),
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
                  gradient: bgGoldGradient,
                  boxShadow: [BoxShadow(color: bg.goldMid.withValues(alpha: 0.4), blurRadius: 8)],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: bgSurface1),
                    child: const Center(child: Text('🏛️', style: TextStyle(fontSize: 16))),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w900, color: bg.text),
                ),
                if (isAphrodite)
                  Text(
                    'Asesora de belleza divina',
                    style: GoogleFonts.lato(fontSize: 11, color: bg.goldMid.withValues(alpha: 0.7)),
                  ),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(
            height: 0.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [bg.goldMid.withValues(alpha: 0.0), bg.goldMid.withValues(alpha: 0.4), bg.goldMid.withValues(alpha: 0.0)],
              ),
            ),
          ),
        ),
        actions: [
          if (isAphrodite)
            IconButton(
              icon: Icon(Icons.forum_outlined, color: bg.goldMid.withValues(alpha: 0.6), size: 22),
              onPressed: () => context.push('/chat/list'),
            ),
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
                    if (index == allMessages.length && _isSending) {
                      return _BGTypingIndicator(bg: bg);
                    }
                    return _BGMessageBubble(message: allMessages[index], isAphroditeThread: isAphrodite, bg: bg);
                  },
                );
              },
              loading: () => Center(child: CircularProgressIndicator(color: bg.goldMid)),
              error: (err, _) => Center(child: Text('Error: $err', style: GoogleFonts.lato(color: bg.textSecondary))),
            ),
          ),
          if (isAphrodite && !_isSending)
            _BGQuickActionChips(bg: bg, onAction: _onQuickAction),
          _BGInputBar(
            bg: bg,
            controller: _textController,
            isSending: _isSending,
            isAphrodite: isAphrodite,
            onSend: _sendMessage,
            onCamera: _handleCamera,
          ),
        ],
      ),
    );
  }

  void _handleCamera() {
    final bg = BGColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bg.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: bg.goldMid.withValues(alpha: 0.2), width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () { Navigator.pop(ctx); context.push('/studio'); },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: bgGoldGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: bg.surface0, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Estudio Virtual', style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w900, color: bg.surface0)),
                          Text('Prueba un nuevo look', style: GoogleFonts.lato(fontSize: 12, color: bg.surface0.withValues(alpha: 0.7))),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: bg.surface0),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () { Navigator.pop(ctx); _pickAndSendAttachment(); },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: bg.surface3,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: bg.goldMid.withValues(alpha: 0.2), width: 0.5),
                ),
                child: Row(
                  children: [
                    Icon(Icons.attach_file_rounded, color: bg.goldMid, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Adjuntar archivo', style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w700, color: bg.text)),
                          Text('Enviar una foto', style: GoogleFonts.lato(fontSize: 12, color: bg.textMuted)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: bg.textMuted),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndSendAttachment() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (image == null) return;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adjuntos disponibles pronto')));
    }
  }
}

// ─── Message Bubble ────────────────────────────────────────────────────────────

class _BGMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isAphroditeThread;
  final BGColors bg;
  const _BGMessageBubble({required this.message, required this.isAphroditeThread, required this.bg});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isFromUser;
    final alignment = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    if (message.isTryOnResult && message.mediaUrl != null) {
      return _BGTryOnCard(message: message, bg: bg);
    }

    if (message.contentType == 'image' && message.mediaUrl != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: alignment,
          children: [
            Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: isUser ? Border.all(color: bg.goldMid.withValues(alpha: 0.4), width: 0.5) : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(message.mediaUrl!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(height: 150, color: bg.surface3, child: Icon(Icons.broken_image, color: bg.goldDark, size: 48))),
              ),
            ),
            const SizedBox(height: 2),
            _BGTimeStamp(time: message.createdAt, bg: bg),
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
            // User bubble: dark surface with gold gradient left border
            Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                color: bg.surface3,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
                border: Border(
                  left: BorderSide(
                    color: bg.goldMid,
                    width: 2,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Text(
                message.textContent ?? '',
                style: GoogleFonts.lato(fontSize: 14, color: bg.text, height: 1.4),
              ),
            )
          else
            // AI bubble: slightly lighter, no border
            Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                color: bg.surface2,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Text(
                message.textContent ?? '',
                style: GoogleFonts.lato(fontSize: 14, color: bg.textSecondary, height: 1.4),
              ),
            ),
          const SizedBox(height: 2),
          _BGTimeStamp(time: message.createdAt, bg: bg),
        ],
      ),
    );
  }
}

class _BGTryOnCard extends StatelessWidget {
  final ChatMessage message;
  final BGColors bg;
  const _BGTryOnCard({required this.message, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: bg.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: bg.goldMid.withValues(alpha: 0.3), width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Image.network(message.mediaUrl!, fit: BoxFit.cover, width: double.infinity, height: 200,
                      errorBuilder: (_, __, ___) => Container(height: 200, color: bg.surface3, child: Icon(Icons.image_not_supported, size: 48, color: bg.goldDark))),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BGGoldShimmer(
                        child: Text('Prueba Virtual', style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w900, color: bg.goldMid)),
                      ),
                      if (message.textContent != null) ...[
                        const SizedBox(height: 4),
                        Text(message.textContent!, style: GoogleFonts.lato(fontSize: 12, color: bg.textMuted)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          _BGTimeStamp(time: message.createdAt, bg: bg),
        ],
      ),
    );
  }
}

// ─── Typing Indicator (gold pulsing dots) ─────────────────────────────────────

class _BGTypingIndicator extends StatelessWidget {
  final BGColors bg;
  const _BGTypingIndicator({required this.bg});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 80),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg.surface2,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(14),
            bottomRight: Radius.circular(14),
          ),
        ),
        child: const BGGoldDots(),
      ),
    );
  }
}

// ─── Timestamp ────────────────────────────────────────────────────────────────

class _BGTimeStamp extends StatelessWidget {
  final DateTime time;
  final BGColors bg;
  const _BGTimeStamp({required this.time, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        DateFormat.Hm().format(time.toLocal()),
        style: GoogleFonts.lato(fontSize: 10, color: bg.textMuted, letterSpacing: 0.5),
      ),
    );
  }
}

// ─── Quick Action Chips ────────────────────────────────────────────────────────

class _BGQuickActionChips extends StatelessWidget {
  final BGColors bg;
  final void Function(String) onAction;
  const _BGQuickActionChips({required this.bg, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bg.surface1,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _BGActionChip(bg: bg, label: 'Recomienda un look', icon: '💇', onTap: () => onAction('Recomienda un look para mí')),
            const SizedBox(width: 8),
            _BGActionChip(bg: bg, label: 'Prueba virtual', icon: '📸', onTap: () => onAction('Quiero probar un nuevo look virtual')),
            const SizedBox(width: 8),
            _BGActionChip(bg: bg, label: 'Qué servicio necesito?', icon: '🤔', onTap: () => onAction('No sé qué servicio necesito, ayúdame')),
          ],
        ),
      ),
    );
  }
}

class _BGActionChip extends StatelessWidget {
  final BGColors bg;
  final String label;
  final String icon;
  final VoidCallback onTap;
  const _BGActionChip({required this.bg, required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg.surface3,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: bg.goldMid.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w700, color: bg.goldMid),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Input Bar ────────────────────────────────────────────────────────────────

class _BGInputBar extends StatelessWidget {
  final BGColors bg;
  final TextEditingController controller;
  final bool isSending;
  final bool isAphrodite;
  final VoidCallback onSend;
  final VoidCallback onCamera;
  const _BGInputBar({required this.bg, required this.controller, required this.isSending, required this.isAphrodite, required this.onSend, required this.onCamera});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 12, right: 12, top: 8, bottom: MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: bg.surface1,
        border: Border(top: BorderSide(color: bg.goldMid.withValues(alpha: 0.15), width: 0.5)),
      ),
      child: Row(
        children: [
          if (isAphrodite) ...[
            GestureDetector(
              onTap: isSending ? null : onCamera,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bg.surface3,
                  border: Border.all(color: bg.goldMid.withValues(alpha: 0.2), width: 0.5),
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  color: isSending ? bg.textMuted : bg.goldMid,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: bg.surface3,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: bg.goldMid.withValues(alpha: 0.2), width: 0.5),
              ),
              child: TextField(
                controller: controller,
                enabled: !isSending,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.lato(fontSize: 14, color: bg.text),
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  hintStyle: GoogleFonts.lato(fontSize: 14, color: bg.textMuted),
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: isSending ? null : bgGoldGradient,
                color: isSending ? bg.surface3 : null,
                shape: BoxShape.circle,
                boxShadow: isSending ? null : [BoxShadow(color: bg.goldMid.withValues(alpha: 0.4), blurRadius: 10)],
              ),
              child: isSending
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2, color: bg.goldMid),
                    )
                  : Icon(Icons.send_rounded, color: bg.surface0, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
