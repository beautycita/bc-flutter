import 'package:flutter/material.dart';
import 'package:beautycita/config/app_transitions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../config/theme_extension.dart';
import '../models/chat_message.dart';
import '../providers/chat_provider.dart';
import '../providers/feature_toggle_provider.dart';
import '../services/supabase_client.dart';
import 'package:beautycita/services/toast_service.dart';
import 'package:beautycita/widgets/media_viewer.dart';
import 'package:beautycita/services/media_service.dart';

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
  final List<ChatMessage> _optimisticMessages = [];
  String? _resolvedContactType;

  @override
  void initState() {
    super.initState();
    _resetUnread();
  }

  /// Reset unread count to 0 when user opens the conversation.
  void _resetUnread() {
    SupabaseClientService.client
        .from('chat_threads')
        .update({'unread_count': 0})
        .eq('id', widget.threadId)
        .then((_) {}, onError: (_) {});
  }

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

  bool get _isSupport => _resolvedContactType == 'support';
  bool get _isAphrodite => _resolvedContactType == 'aphrodite';
  bool get _isEros => _resolvedContactType == 'support_ai';

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;
    if (_resolvedContactType == null) return; // Thread not loaded yet

    _textController.clear();

    // Optimistically show user's message immediately
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

    if (_isEros) {
      await ref.read(sendErosMessageProvider.notifier).send(widget.threadId, text);
    } else if (_isSupport) {
      await ref.read(sendSupportMessageProvider.notifier).send(widget.threadId, text);
    } else if (_isAphrodite) {
      await ref.read(sendMessageProvider.notifier).send(widget.threadId, text);
    } else if (_resolvedContactType == 'salon') {
      await ref.read(sendSalonMessageProvider.notifier).send(widget.threadId, text);
    } else {
      await _sendDirectMessage(text);
    }

    if (mounted) {
      setState(() {
        _optimisticMessages.clear();
        _isSending = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _sendDirectMessage(String text) async {
    try {
      final client = SupabaseClientService.client;
      final userId = SupabaseClientService.currentUserId;
      await client.from('chat_messages').insert({
        'thread_id': widget.threadId,
        'sender_type': 'user',
        'sender_id': userId,
        'content_type': 'text',
        'text_content': text,
      });
      // Update thread's last message
      await client.from('chat_threads').update({
        'last_message_text': text,
        'last_message_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', widget.threadId);
    } catch (e, stack) {
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
    }
  }

  Future<void> _escalateToHuman() async {
    final supportThread = await ref.read(supportThreadProvider.future);
    if (supportThread != null && mounted) {
      context.pushReplacement('/chat/${supportThread.id}');
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

    // Update resolved contact type for _sendMessage() routing
    if (thread != null) {
      _resolvedContactType = thread.contactType;
    }
    final toggles = ref.watch(featureTogglesProvider);
    final isAphrodite = (thread?.isAphrodite ?? false) && toggles.isEnabled('enable_aphrodite_ai');
    final isSupport = thread?.isSupport ?? false;
    final isEros = (thread?.isEros ?? false) && toggles.isEnabled('enable_eros_support');
    final title = isAphrodite ? 'Afrodita' : isSupport ? 'Soporte en Vivo' : (thread?.displayName ?? 'Chat');

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/chat/list'),
        ),
        titleSpacing: 0,
        actions: [
          if (isEros)
            TextButton.icon(
              onPressed: () => _escalateToHuman(),
              icon: const Icon(Icons.support_agent_rounded, size: 18),
              label: Text(
                'Humano',
                style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFC2185B),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          IconButton(
            icon: Icon(
              Icons.forum_outlined,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              size: 22,
            ),
            tooltip: 'Todos los mensajes',
            onPressed: () => context.go('/chat/list'),
          ),
        ],
        title: Row(
          children: [
            if (isEros) ...[
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Text('🏹', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 10),
            ] else if (isAphrodite) ...[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: Theme.of(context).extension<BCThemeExtension>()!.accentGradient,
                ),
                child: const Center(
                  child: Text('🏛️', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 10),
            ] else if (isSupport) ...[
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF7B1038), Color(0xFFC2185B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.support_agent_rounded, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 10),
            ] else ...[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
                child: Center(
                  child: Icon(Icons.storefront_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
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
                if (isEros)
                  Text(
                    'Soporte inteligente',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: const Color(0xFF1565C0).withValues(alpha: 0.7),
                    ),
                  ),
                if (isAphrodite)
                  Text(
                    'Asesora de belleza divina',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                if (isSupport)
                  Text(
                    'Soporte en Vivo',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: const Color(0xFFC2185B).withValues(alpha: 0.7),
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
                // Merge stream messages with optimistic ones (dedup by matching text+sender)
                final streamIds = messages.map((m) => m.id).toSet();
                final pendingOptimistic = _optimisticMessages
                    .where((o) => !streamIds.contains(o.id) &&
                        !messages.any((m) =>
                            m.senderType == 'user' &&
                            m.textContent == o.textContent &&
                            m.createdAt.difference(o.createdAt).inSeconds.abs() < 10))
                    .toList();
                final allMessages = [...messages, ...pendingOptimistic];
                allMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

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
                  itemCount: allMessages.length + (_isSending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == allMessages.length && _isSending) {
                      return _TypingIndicator();
                    }
                    final msg = allMessages[index];
                    return _MessageBubble(
                      message: msg,
                      isAphroditeThread: isAphrodite,
                      isSupportThread: isSupport,
                      isErosThread: isEros,
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

          // Quick action chips (Aphrodite only, not support)
          if (isAphrodite && !_isSending)
            _QuickActionChips(onAction: _onQuickAction),

          // Input bar
          _InputBar(
            controller: _textController,
            isSending: _isSending,
            isAphrodite: isAphrodite,
            showCamera: isAphrodite, // camera only for Aphrodite
            onSend: _sendMessage,
            onCamera: () => _handleCamera(),
          ),
        ],
      ),
    );
  }

  void _handleCamera() {
    showBurstBottomSheet(
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
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Estudio Virtual',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Prueba un nuevo look con IA',
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StudioOption(
                  icon: Icons.color_lens_rounded,
                  label: 'Color',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/studio?tab=hair_color');
                  },
                ),
                _StudioOption(
                  icon: Icons.face_retouching_natural,
                  label: 'Peinado',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/studio?tab=hairstyle');
                  },
                ),
                _StudioOption(
                  icon: Icons.portrait_rounded,
                  label: 'Headshot',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/studio?tab=headshot');
                  },
                ),
                _StudioOption(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Look Swap',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/studio?tab=look_swap');
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
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
  final bool isSupportThread;
  final bool isErosThread;

  const _MessageBubble({
    required this.message,
    required this.isAphroditeThread,
    this.isSupportThread = false,
    this.isErosThread = false,
  });

  void _openImageViewer(BuildContext context, ChatMessage message) {
    final mediaService = MediaService();
    final item = MediaItem(
      id: message.id,
      userId: message.senderId ?? '',
      mediaType: 'image',
      source: message.isTryOnResult ? 'lightx' : 'chat',
      sourceRef: message.threadId,
      url: message.mediaUrl!,
      metadata: message.metadata,
      section: 'chat',
      createdAt: message.createdAt,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MediaViewer(
          items: [item],
          initialIndex: 0,
          onSaveToGallery: (item) async {
            final ok = await mediaService.saveUrlToGallery(item.url);
            if (ok) {
              ToastService.showSuccess('Imagen guardada');
            }
          },
          onShare: (item) async {
            await mediaService.shareImage(
              item.url,
              text: 'BeautyCita',
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.isFromUser;
    final alignment = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final colors = Theme.of(context).colorScheme;

    // Support/Eros agent messages get colored bubbles
    final bool isSupportAgent = message.isFromSupport;
    final bool isErosAgent = message.senderType == 'eros';
    final bubbleColor = isUser
        ? colors.primary
        : isErosAgent
            ? const Color(0xFF1565C0)
            : isSupportAgent
                ? const Color(0xFF7B1038)
                : colors.surface;
    final textColor = isUser
        ? colors.onPrimary
        : (isErosAgent || isSupportAgent)
            ? Colors.white
            : colors.onSurface;

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
                color: colors.surface,
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
                  GestureDetector(
                    onTap: () => _openImageViewer(context, message),
                    child: Stack(
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
                            errorBuilder: (_, _, _) => Container(
                              height: 200,
                              color: Theme.of(context).colorScheme.surface,
                              child: const Center(
                                child: Icon(Icons.image_not_supported, size: 48),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.zoom_in_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
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
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                        if (message.textContent != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            message.textContent!,
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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
              child: GestureDetector(
                onTap: () => _openImageViewer(context, message),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        message.mediaUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          height: 150,
                          color: Theme.of(context).colorScheme.surface,
                          child: const Center(
                            child: Icon(Icons.broken_image, size: 48),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.zoom_in_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
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
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
              color: Theme.of(context).colorScheme.surface,
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
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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
      color: Theme.of(context).colorScheme.surface,
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
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
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
                color: Theme.of(context).colorScheme.primary,
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
  final bool showCamera;
  final VoidCallback onSend;
  final VoidCallback onCamera;

  const _InputBar({
    required this.controller,
    required this.isSending,
    required this.isAphrodite,
    this.showCamera = true,
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
        color: Theme.of(context).scaffoldBackgroundColor,
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
          // Camera button
          if (showCamera) ...[
            GestureDetector(
              onTap: isSending ? null : onCamera,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  color: isSending
                      ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
                      : Theme.of(context).colorScheme.primary,
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
                color: Theme.of(context).colorScheme.surface,
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
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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
                    : Theme.of(context).extension<BCThemeExtension>()!.primaryGradient,
                color: isSending ? Theme.of(context).dividerColor : null,
                shape: BoxShape.circle,
              ),
              child: isSending
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
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

class _StudioOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _StudioOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.primary.withValues(alpha: 0.1),
                    colors.secondary.withValues(alpha: 0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: colors.primary, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

