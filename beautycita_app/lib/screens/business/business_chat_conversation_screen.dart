/// Business-side chat conversation. Renders messages from both parties
/// with the business's own bubbles aligned right (sender_type='salon'),
/// the customer's aligned left. Sends via sender_type='salon' which is
/// gated by the chat_messages_business_insert RLS policy.
library;

import 'package:beautycita/widgets/cached_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../config/fonts.dart';
import '../../config/theme_extension.dart';
import '../../models/chat_message.dart';
import '../../providers/chat_provider.dart';
import '../../providers/business_chat_provider.dart';
import '../../services/supabase_client.dart';
import '../../services/toast_service.dart';
import '../../widgets/chat_animations.dart';

class BusinessChatConversationScreen extends ConsumerStatefulWidget {
  final String threadId;

  const BusinessChatConversationScreen({super.key, required this.threadId});

  @override
  ConsumerState<BusinessChatConversationScreen> createState() =>
      _BusinessChatConversationScreenState();
}

class _BusinessChatConversationScreenState
    extends ConsumerState<BusinessChatConversationScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  DateTime? _lastSentAt;
  final List<ChatMessage> _optimistic = [];

  @override
  void initState() {
    super.initState();
    // Reset unread count for this thread as soon as the owner opens it.
    markBusinessThreadRead(widget.threadId);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;
    final now = DateTime.now();
    if (_lastSentAt != null &&
        now.difference(_lastSentAt!).inMilliseconds < 1000) {
      return;
    }
    _lastSentAt = now;
    _textController.clear();

    final optimistic = ChatMessage(
      id: const Uuid().v4(),
      threadId: widget.threadId,
      senderType: 'salon',
      senderId: SupabaseClientService.currentUserId,
      contentType: 'text',
      textContent: text,
      createdAt: DateTime.now().toUtc(),
    );
    setState(() {
      _optimistic.add(optimistic);
      _isSending = true;
    });
    _scrollToBottom();

    final ok =
        await ref.read(sendBusinessMessageProvider.notifier).send(widget.threadId, text);

    if (!mounted) return;
    setState(() {
      _optimistic.clear();
      _isSending = false;
    });
    if (!ok) {
      ToastService.showError('No se pudo enviar el mensaje');
    }
    _scrollToBottom();
  }

  String _customerNameFor(String threadId) {
    final threadsAsync = ref.read(businessChatThreadsProvider);
    return threadsAsync.maybeWhen(
      data: (rows) {
        for (final r in rows) {
          if (r.thread.id == threadId) return r.customerName;
        }
        return 'Cliente';
      },
      orElse: () => 'Cliente',
    );
  }

  String? _customerAvatarFor(String threadId) {
    final threadsAsync = ref.read(businessChatThreadsProvider);
    return threadsAsync.maybeWhen(
      data: (rows) {
        for (final r in rows) {
          if (r.thread.id == threadId) return r.customerAvatarUrl;
        }
        return null;
      },
      orElse: () => null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.threadId));
    final colors = Theme.of(context).colorScheme;
    final name = _customerNameFor(widget.threadId);
    final avatarUrl = _customerAvatarFor(widget.threadId);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/negocio/bandeja');
            }
          },
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            _CustomerAvatar(name: name, avatarUrl: avatarUrl, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Error al cargar mensajes: $e'),
                ),
              ),
              data: (messages) {
                final streamIds = messages.map((m) => m.id).toSet();
                final pending = _optimistic
                    .where((o) => !streamIds.contains(o.id))
                    .toList();
                final merged = [...messages, ...pending];
                merged.sort((a, b) => a.createdAt.compareTo(b.createdAt));

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                if (merged.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Aun no hay mensajes. Salúdala para empezar.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: colors.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  itemCount: merged.length + (_isSending ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == merged.length && _isSending) {
                      return const WaveTypingIndicator();
                    }
                    final msg = merged[i];
                    final isRecent = i >= merged.length - 3;
                    final bubble = _BusinessBubble(message: msg);
                    if (!isRecent) return bubble;
                    return AnimatedBubbleEntrance(
                      // Business-side: our messages align right, so we
                      // reuse the isFromUser axis with "business = right".
                      isFromUser: msg.senderType == 'salon',
                      child: bubble,
                    );
                  },
                );
              },
            ),
          ),
          _InputBar(
            controller: _textController,
            isSending: _isSending,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

/// Message bubble oriented from the business owner's perspective:
/// sender_type='salon' aligns right (our outbound), anything else left.
class _BusinessBubble extends StatelessWidget {
  final ChatMessage message;

  const _BusinessBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isMine = message.senderType == 'salon';
    final align = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = isMine ? colors.primary : colors.surface;
    final textColor = isMine ? colors.onPrimary : colors.onSurface;

    // Image message
    if (message.contentType == 'image' && message.mediaUrl != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: align,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedImage(
                message.mediaUrl!,
                width: MediaQuery.of(context).size.width * 0.6,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  height: 150,
                  color: colors.surface,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image, size: 48),
                ),
              ),
            ),
            const SizedBox(height: 2),
            _TimeStamp(time: message.createdAt),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMine ? 16 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context)
                      .shadowColor
                      .withValues(alpha: 0.04),
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

class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

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
            color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: widget.controller,
                enabled: !widget.isSending,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.nunito(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  hintStyle: GoogleFonts.nunito(
                    fontSize: 15,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) => widget.onSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          MorphingSendButton(
            hasText: _hasText,
            isSending: widget.isSending,
            onSend: widget.onSend,
            activeGradient: Theme.of(context)
                .extension<BCThemeExtension>()
                ?.primaryGradient,
          ),
        ],
      ),
    );
  }
}

class _CustomerAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double size;

  const _CustomerAvatar({
    required this.name,
    required this.avatarUrl,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return ClipOval(
        child: CachedImage(
          avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _initials(colors),
        ),
      );
    }
    return _initials(colors);
  }

  Widget _initials(ColorScheme colors) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    String initials;
    if (parts.isEmpty) {
      initials = '?';
    } else if (parts.length == 1) {
      initials = parts.first.substring(0, 1).toUpperCase();
    } else {
      initials = (parts.first.substring(0, 1) + parts.last.substring(0, 1))
          .toUpperCase();
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.primaryContainer,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.poppins(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          color: colors.onPrimaryContainer,
        ),
      ),
    );
  }
}
