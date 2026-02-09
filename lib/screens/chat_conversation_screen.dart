import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/chat_message.dart';
import '../providers/chat_provider.dart';

class ChatConversationScreen extends ConsumerStatefulWidget {
  final String threadId;

  const ChatConversationScreen({super.key, required this.threadId});

  @override
  ConsumerState<ChatConversationScreen> createState() =>
      _ChatConversationScreenState();
}

class _ChatConversationScreenState
    extends ConsumerState<ChatConversationScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

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
    setState(() => _isSending = true);

    await ref.read(sendMessageProvider.notifier).send(widget.threadId, text);

    if (mounted) {
      setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  void _onQuickAction(String text) {
    _textController.text = text;
    _sendMessage();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.threadId));
    final threadsAsync = ref.watch(chatThreadsProvider);

    // Find this thread's info
    final thread = threadsAsync.whenOrNull(
      data: (threads) {
        try {
          return threads.firstWhere((t) => t.id == widget.threadId);
        } catch (_) {
          return null;
        }
      },
    );

    final isAphrodite = thread?.isAphrodite ?? false;
    final title = isAphrodite ? 'Afrodita' : (thread?.displayName ?? 'Chat');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0EB),
      appBar: AppBar(
        backgroundColor: BeautyCitaTheme.backgroundWhite,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/home'),
        ),
        titleSpacing: 0,
        actions: [
          if (isAphrodite)
            IconButton(
              icon: Icon(
                Icons.forum_outlined,
                color: BeautyCitaTheme.textLight,
                size: 22,
              ),
              tooltip: 'Todos los mensajes',
              onPressed: () => context.push('/chat/list'),
            ),
        ],
        title: Row(
          children: [
            if (isAphrodite) ...[
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFB300), Color(0xFFFFD54F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Text('🏛️', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isAphrodite)
                  Text(
                    'Asesora de belleza divina',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: BeautyCitaTheme.textLight,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });
                return ListView.builder(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  itemCount: messages.length + (_isSending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == messages.length && _isSending) {
                      return _TypingIndicator();
                    }
                    final msg = messages[index];
                    return _MessageBubble(
                      message: msg,
                      isAphroditeThread: isAphrodite,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Error: $err'),
              ),
            ),
          ),

          // Quick action chips (Aphrodite only)
          if (isAphrodite && !_isSending)
            _QuickActionChips(onAction: _onQuickAction),

          // Input bar
          _InputBar(
            controller: _textController,
            isSending: _isSending,
            isAphrodite: isAphrodite,
            onSend: _sendMessage,
            onCamera: () => _handleCamera(),
          ),
        ],
      ),
    );
  }

  void _handleCamera() {
    const tools = [
      ('hair_color', 'Color de Cabello', Icons.palette, 'Prueba un nuevo color'),
      ('hairstyle', 'Nuevo Peinado', Icons.content_cut, 'Prueba un estilo diferente'),
      ('headshot', 'Retrato Pro', Icons.camera_alt, 'Foto profesional'),
      ('avatar', 'Mi Avatar', Icons.face, 'Crea un avatar estilizado'),
      ('face_swap', 'Cambio de Look', Icons.swap_horiz, 'Look completamente nuevo'),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: BeautyCitaTheme.dividerLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE91E63), Color(0xFFC2185B)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estudio Virtual',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Prueba un nuevo look con inteligencia artificial',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...tools.map((tool) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/studio?tab=${tool.$1}');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: BeautyCitaTheme.surfaceCream,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(tool.$3, color: BeautyCitaTheme.primaryRose, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tool.$2,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              tool.$4,
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: BeautyCitaTheme.textLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: BeautyCitaTheme.textLight),
                    ],
                  ),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

/// Individual message bubble.
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isAphroditeThread;

  const _MessageBubble({
    required this.message,
    required this.isAphroditeThread,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isFromUser;
    final alignment = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = isUser
        ? BeautyCitaTheme.primaryRose
        : Colors.white;
    final textColor = isUser ? Colors.white : BeautyCitaTheme.textDark;

    // Try-on result card
    if (message.isTryOnResult && message.mediaUrl != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: alignment,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: Image.network(
                      message.mediaUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 200,
                      errorBuilder: (_, __, ___) => Container(
                        height: 200,
                        color: BeautyCitaTheme.surfaceCream,
                        child: const Center(
                          child: Icon(Icons.image_not_supported, size: 48),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '✨ Prueba Virtual',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFFFB300),
                          ),
                        ),
                        if (message.textContent != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            message.textContent!,
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              color: BeautyCitaTheme.textLight,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            _TimeStamp(time: message.createdAt),
          ],
        ),
      );
    }

    // Image message
    if (message.contentType == 'image' && message.mediaUrl != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: alignment,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.65,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  message.mediaUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 150,
                    color: BeautyCitaTheme.surfaceCream,
                    child: const Center(
                      child: Icon(Icons.broken_image, size: 48),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            _TimeStamp(time: message.createdAt),
          ],
        ),
      );
    }

    // Text message (default)
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              message.textContent ?? '',
              style: GoogleFonts.nunito(
                fontSize: 15,
                color: textColor,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 2),
          _TimeStamp(time: message.createdAt),
        ],
      ),
    );
  }
}

/// Small timestamp below messages.
class _TimeStamp extends StatelessWidget {
  final DateTime time;

  const _TimeStamp({required this.time});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        DateFormat.Hm().format(time.toLocal()),
        style: GoogleFonts.nunito(
          fontSize: 11,
          color: BeautyCitaTheme.textLight.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

/// Typing indicator (three bouncing dots).
class _TypingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _BouncingDot(delay: 0),
                const SizedBox(width: 4),
                _BouncingDot(delay: 150),
                const SizedBox(width: 4),
                _BouncingDot(delay: 300),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Single bouncing dot for the typing indicator.
class _BouncingDot extends StatefulWidget {
  final int delay;

  const _BouncingDot({required this.delay});

  @override
  State<_BouncingDot> createState() => _BouncingDotState();
}

class _BouncingDotState extends State<_BouncingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: child,
        );
      },
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: BeautyCitaTheme.textLight.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Quick action chips above the input bar.
class _QuickActionChips extends StatelessWidget {
  final void Function(String text) onAction;

  const _QuickActionChips({required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F0EB),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _ActionChip(
              label: 'Recomienda un look',
              icon: '💇',
              onTap: () => onAction('Recomienda un look para mí'),
            ),
            const SizedBox(width: 8),
            _ActionChip(
              label: 'Prueba virtual',
              icon: '📸',
              onTap: () => onAction('Quiero probar un nuevo look virtual'),
            ),
            const SizedBox(width: 8),
            _ActionChip(
              label: '¿Qué servicio necesito?',
              icon: '🤔',
              onTap: () => onAction('No sé qué servicio necesito, ayúdame'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final String icon;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: BeautyCitaTheme.primaryRose.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: BeautyCitaTheme.primaryRose,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom input bar with text field, camera, and send button.
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final bool isAphrodite;
  final VoidCallback onSend;
  final VoidCallback onCamera;

  const _InputBar({
    required this.controller,
    required this.isSending,
    required this.isAphrodite,
    required this.onSend,
    required this.onCamera,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: BeautyCitaTheme.backgroundWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Camera button (Aphrodite only)
          if (isAphrodite) ...[
            GestureDetector(
              onTap: isSending ? null : onCamera,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: BeautyCitaTheme.surfaceCream,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  color: isSending
                      ? BeautyCitaTheme.textLight
                      : BeautyCitaTheme.primaryRose,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Text field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: BeautyCitaTheme.surfaceCream,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: controller,
                enabled: !isSending,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.nunito(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  hintStyle: GoogleFonts.nunito(
                    fontSize: 15,
                    color: BeautyCitaTheme.textLight,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send button
          GestureDetector(
            onTap: isSending ? null : onSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: isSending
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFFE91E63), Color(0xFFC2185B)],
                      ),
                color: isSending ? BeautyCitaTheme.dividerLight : null,
                shape: BoxShape.circle,
              ),
              child: isSending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: BeautyCitaTheme.primaryRose,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

