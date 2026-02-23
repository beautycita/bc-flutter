import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/constants.dart';
import '../../models/chat_thread.dart';
import '../../models/chat_message.dart';
import '../../providers/chat_provider.dart';
import '../../services/supabase_client.dart';

/// Admin chat terminal — WhatsApp-style with BeautyCita branding.
/// Shows all admin threads on the left, conversation on the right (or full-screen on phone).
class AdminChatScreen extends ConsumerStatefulWidget {
  const AdminChatScreen({super.key});

  @override
  ConsumerState<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends ConsumerState<AdminChatScreen> {
  String? _activeThreadId;
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

  @override
  Widget build(BuildContext context) {
    final threadsAsync = ref.watch(chatThreadsProvider);
    final isWide = MediaQuery.of(context).size.width > 600;

    if (isWide) {
      // Tablet/wide: side-by-side list + conversation
      return Row(
        children: [
          SizedBox(
            width: 300,
            child: _ThreadList(
              threadsAsync: threadsAsync,
              activeThreadId: _activeThreadId,
              onSelectThread: (id) => setState(() => _activeThreadId = id),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _activeThreadId != null
                ? _ConversationPane(
                    key: ValueKey(_activeThreadId),
                    threadId: _activeThreadId!,
                    onBack: () => setState(() => _activeThreadId = null),
                  )
                : _EmptyConversation(),
          ),
        ],
      );
    }

    // Phone: show list or conversation
    if (_activeThreadId != null) {
      return _ConversationPane(
        key: ValueKey(_activeThreadId),
        threadId: _activeThreadId!,
        onBack: () => setState(() => _activeThreadId = null),
      );
    }

    return _ThreadList(
      threadsAsync: threadsAsync,
      activeThreadId: _activeThreadId,
      onSelectThread: (id) => setState(() => _activeThreadId = id),
    );
  }
}

/// Thread list panel.
class _ThreadList extends StatelessWidget {
  final AsyncValue<List<ChatThread>> threadsAsync;
  final String? activeThreadId;
  final ValueChanged<String> onSelectThread;

  const _ThreadList({
    required this.threadsAsync,
    required this.activeThreadId,
    required this.onSelectThread,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppConstants.radiusMD),
              topRight: Radius.circular(AppConstants.radiusMD),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.chat_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                'BeautyCita Chat',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        // Thread list
        Expanded(
          child: threadsAsync.when(
            data: (threads) {
              if (threads.isEmpty) {
                return Center(
                  child: Text(
                    'Sin conversaciones',
                    style: GoogleFonts.nunito(
                        fontSize: 14, color: Colors.grey[500]),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.only(top: 4),
                itemCount: threads.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  indent: 72,
                  endIndent: 16,
                ),
                itemBuilder: (context, i) {
                  final thread = threads[i];
                  final isActive = thread.id == activeThreadId;
                  return _ThreadTile(
                    thread: thread,
                    isActive: isActive,
                    onTap: () => onSelectThread(thread.id),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }
}

/// Single thread tile in the list.
class _ThreadTile extends StatelessWidget {
  final ChatThread thread;
  final bool isActive;
  final VoidCallback onTap;

  const _ThreadTile({
    required this.thread,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    IconData avatarIcon;
    Color avatarColor;
    if (thread.isAphrodite) {
      avatarIcon = Icons.auto_awesome;
      avatarColor = colors.secondary;
    } else if (thread.isSupport) {
      avatarIcon = Icons.support_agent_rounded;
      avatarColor = const Color(0xFFC2185B);
    } else {
      avatarIcon = Icons.storefront_rounded;
      avatarColor = colors.primary;
    }

    return Material(
      color: isActive ? colors.primary.withValues(alpha: 0.08) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: avatarColor.withValues(alpha: 0.12),
                ),
                child: Icon(avatarIcon, size: 22, color: avatarColor),
              ),
              const SizedBox(width: 12),
              // Name + last message
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            thread.displayName,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: thread.unreadCount > 0
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: colors.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (thread.lastMessageAt != null)
                          Text(
                            _formatTime(thread.lastMessageAt!),
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              color: thread.unreadCount > 0
                                  ? colors.primary
                                  : Colors.grey[500],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            thread.lastMessageText ?? '',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              color: Colors.grey[600],
                              fontWeight: thread.unreadCount > 0
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (thread.unreadCount > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${thread.unreadCount}',
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return DateFormat.Hm().format(local);
    if (diff.inDays < 7) return DateFormat.E().format(local);
    return DateFormat.MMMd().format(local);
  }
}

/// Conversation pane — messages + input bar.
class _ConversationPane extends ConsumerStatefulWidget {
  final String threadId;
  final VoidCallback onBack;

  const _ConversationPane({
    super.key,
    required this.threadId,
    required this.onBack,
  });

  @override
  ConsumerState<_ConversationPane> createState() => _ConversationPaneState();
}

class _ConversationPaneState extends ConsumerState<_ConversationPane> {
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
      await client.from('chat_threads').update({
        'last_message_text': text,
        'last_message_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', widget.threadId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }

    if (mounted) {
      setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.threadId));
    final threadsAsync = ref.watch(chatThreadsProvider);
    final colors = Theme.of(context).colorScheme;

    final thread = threadsAsync.whenOrNull(
      data: (threads) {
        try {
          return threads.firstWhere((t) => t.id == widget.threadId);
        } catch (_) {
          return null;
        }
      },
    );
    final title = thread?.displayName ?? 'Chat';

    return Column(
      children: [
        // Conversation header
        Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
          decoration: BoxDecoration(
            color: colors.primary,
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                onPressed: widget.onBack,
                tooltip: 'Volver a chats',
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (thread != null)
                Text(
                  thread.contactType,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
            ],
          ),
        ),
        // Messages
        Expanded(
          child: Container(
            // WhatsApp-like chat background
            decoration: BoxDecoration(
              color: const Color(0xFFF0ECE5),
              image: DecorationImage(
                image: const AssetImage('assets/images/chat_bg_pattern.png'),
                repeat: ImageRepeat.repeat,
                opacity: 0.04,
                onError: (_, __) {},
              ),
            ),
            child: messagesAsync.when(
              data: (messages) {
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                return ListView.builder(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[i];
                    return _ChatBubble(message: msg);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ),
        // Input bar
        Container(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            top: 8,
            bottom: MediaQuery.of(context).padding.bottom + 8,
          ),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3FF),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _textController,
                    enabled: !_isSending,
                    maxLines: 4,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    style: GoogleFonts.nunito(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      hintStyle: GoogleFonts.nunito(fontSize: 15, color: Colors.grey[400]),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _isSending ? null : _sendMessage,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _isSending ? Colors.grey[300] : colors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: _isSending
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.primary,
                          ),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Chat bubble — WhatsApp style.
class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isFromUser;
    final isSystem = message.senderType == 'system';

    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              message.textContent ?? '',
              style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final alignment = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = isUser ? const Color(0xFFDCF8C6) : Colors.white;
    final textColor = const Color(0xFF303030);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(isUser ? 12 : 2),
                bottomRight: Radius.circular(isUser ? 2 : 12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isUser)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      message.senderType == 'aphrodite'
                          ? 'Afrodita'
                          : message.senderType == 'support'
                              ? 'Soporte'
                              : message.senderType,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                Text(
                  message.textContent ?? '',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: textColor,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat.Hm().format(message.createdAt.toLocal()),
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state when no conversation is selected.
class _EmptyConversation extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 56, color: colors.primary.withValues(alpha: 0.25)),
          const SizedBox(height: 16),
          Text(
            'Selecciona una conversacion',
            style: GoogleFonts.nunito(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}
