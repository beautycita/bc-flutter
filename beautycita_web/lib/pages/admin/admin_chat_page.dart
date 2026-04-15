import 'package:beautycita_core/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../config/breakpoints.dart';
import '../../config/web_theme.dart';
import '../../providers/admin_chat_provider.dart';

/// Admin Chat page — desktop split layout.
///
/// Left sidebar (300px): scrollable list of all chat_threads with unread badges.
/// Right panel: selected thread's messages + send input at the bottom.
/// Thread filter bar at the top of the sidebar.
class AdminChatPage extends ConsumerWidget {
  const AdminChatPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < WebBreakpoints.tabletSmall;

        if (isMobile) {
          return _MobileLayout();
        }
        return _DesktopLayout();
      },
    );
  }
}

// ── Desktop: sidebar + conversation panel ─────────────────────────────────────

class _DesktopLayout extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(adminSelectedThreadProvider);

    return Row(
      children: [
        // Left sidebar — fixed 300px
        SizedBox(
          width: 300,
          child: _ThreadSidebar(),
        ),
        // Vertical divider
        Container(width: 1, color: kWebCardBorder),
        // Right panel
        Expanded(
          child: selected == null
              ? _EmptyConversation()
              : _ConversationPanel(thread: selected),
        ),
      ],
    );
  }
}

// ── Mobile: thread list first, conversation on selection ─────────────────────

class _MobileLayout extends ConsumerStatefulWidget {
  @override
  ConsumerState<_MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends ConsumerState<_MobileLayout> {
  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(adminSelectedThreadProvider);

    if (selected != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: kWebSurface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => ref
                .read(adminSelectedThreadProvider.notifier)
                .state = null,
          ),
          title: Text(
            selected.displayName,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        body: _ConversationPanel(thread: selected),
      );
    }
    return _ThreadSidebar();
  }
}

// ── Thread sidebar ────────────────────────────────────────────────────────────

class _ThreadSidebar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(adminChatThreadsProvider);
    final search = ref.watch(adminChatSearchProvider);
    final selected = ref.watch(adminSelectedThreadProvider);
    final theme = Theme.of(context);

    return Container(
      color: kWebSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                Text(
                  'Soporte',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: kWebTextPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh_outlined, size: 18),
                  tooltip: 'Actualizar',
                  onPressed: () =>
                      ref.invalidate(adminChatThreadsProvider),
                  color: kWebTextSecondary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar...',
                hintStyle: theme.textTheme.bodySmall?.copyWith(
                  color: kWebTextHint,
                ),
                prefixIcon:
                    const Icon(Icons.search, size: 18, color: kWebTextHint),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                filled: true,
                fillColor: kWebBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: kWebCardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: kWebCardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: kWebPrimary, width: 1.5),
                ),
              ),
              style: theme.textTheme.bodySmall,
              onChanged: (v) =>
                  ref.read(adminChatSearchProvider.notifier).state = v,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: kWebCardBorder),

          // Thread list
          Expanded(
            child: threadsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Error cargando threads:\n$e',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
              data: (threads) {
                final filtered = search.isEmpty
                    ? threads
                    : threads
                        .where((t) => t.displayName
                            .toLowerCase()
                            .contains(search.toLowerCase()))
                        .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Sin resultados',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: kWebTextHint,
                        ),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    indent: 16,
                    color: kWebCardBorder,
                  ),
                  itemBuilder: (context, index) {
                    final thread = filtered[index];
                    return _ThreadTile(
                      thread: thread,
                      isSelected: selected?.id == thread.id,
                      onTap: () => ref
                          .read(adminSelectedThreadProvider.notifier)
                          .state = thread,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Thread tile ───────────────────────────────────────────────────────────────

class _ThreadTile extends StatefulWidget {
  const _ThreadTile({
    required this.thread,
    required this.isSelected,
    required this.onTap,
  });

  final ChatThread thread;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_ThreadTile> createState() => _ThreadTileState();
}

class _ThreadTileState extends State<_ThreadTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thread = widget.thread;
    final timeFormat = DateFormat('HH:mm');

    final bgColor = widget.isSelected
        ? kWebPrimary.withValues(alpha: 0.08)
        : _hovering
            ? kWebPrimary.withValues(alpha: 0.04)
            : Colors.transparent;

    final typeColor = switch (thread.contactType) {
      'support' || 'support_ai' => kWebSecondary,
      'salon' => kWebTertiary,
      _ => kWebTextSecondary,
    };

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: bgColor,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: typeColor.withValues(alpha: 0.12),
                child: Text(
                  thread.displayName.isNotEmpty
                      ? thread.displayName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: typeColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            thread.displayName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: thread.unreadCount > 0
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: kWebTextPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (thread.lastMessageAt != null)
                          Text(
                            timeFormat.format(thread.lastMessageAt!),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: kWebTextHint,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            thread.lastMessageText ?? 'Sin mensajes',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: thread.unreadCount > 0
                                  ? kWebTextPrimary
                                  : kWebTextHint,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (thread.unreadCount > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: kWebPrimary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${thread.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
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
}

// ── Empty state when no thread selected ──────────────────────────────────────

class _EmptyConversation extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 72,
            color: kWebTextHint.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 16),
          Text(
            'Cola de soporte',
            style: theme.textTheme.titleMedium?.copyWith(
              color: kWebTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Selecciona un hilo para responder como Soporte BeautyCita',
            style: theme.textTheme.bodySmall?.copyWith(
              color: kWebTextHint,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Conversation panel ────────────────────────────────────────────────────────

class _ConversationPanel extends ConsumerStatefulWidget {
  const _ConversationPanel({required this.thread});
  final ChatThread thread;

  @override
  ConsumerState<_ConversationPanel> createState() =>
      _ConversationPanelState();
}

class _ConversationPanelState
    extends ConsumerState<_ConversationPanel> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    final ok = await ref
        .read(adminChatSendProvider.notifier)
        .send(widget.thread.id, text);
    if (ok) _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final messagesAsync =
        ref.watch(adminChatMessagesProvider(widget.thread.id));
    final sendState = ref.watch(adminChatSendProvider);

    final typeColor = switch (widget.thread.contactType) {
      'support' || 'support_ai' => kWebSecondary,
      'salon' => kWebTertiary,
      _ => kWebTextSecondary,
    };

    return Column(
      children: [
        // Conversation header
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: const BoxDecoration(
            color: kWebSurface,
            border: Border(
              bottom: BorderSide(color: kWebCardBorder),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: typeColor.withValues(alpha: 0.12),
                child: Text(
                  widget.thread.displayName.isNotEmpty
                      ? widget.thread.displayName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: typeColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.thread.displayName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: kWebTextPrimary,
                      ),
                    ),
                    Text(
                      widget.thread.contactType,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: kWebTextHint,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_outlined, size: 18),
                tooltip: 'Actualizar mensajes',
                onPressed: () => ref.invalidate(
                    adminChatMessagesProvider(widget.thread.id)),
                color: kWebTextSecondary,
              ),
            ],
          ),
        ),

        // Messages
        Expanded(
          child: messagesAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                'Error cargando mensajes:\n$e',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),
            data: (messages) {
              if (messages.isEmpty) {
                return Center(
                  child: Text(
                    'Sin mensajes aún',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: kWebTextHint,
                    ),
                  ),
                );
              }
              _scrollToBottom();
              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  return _MessageBubble(message: messages[index]);
                },
              );
            },
          ),
        ),

        // Error banner
        if (sendState.error != null)
          Container(
            color: theme.colorScheme.error.withValues(alpha: 0.1),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.error_outline,
                    size: 16, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sendState.error!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(adminChatSendProvider.notifier).clearError(),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          ),

        // Input bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: kWebSurface,
            border: Border(
              top: BorderSide(color: kWebCardBorder),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  maxLines: 3,
                  minLines: 1,
                  textInputAction: TextInputAction.newline,
                  style: theme.textTheme.bodySmall,
                  decoration: InputDecoration(
                    hintText: 'Responder como Soporte BeautyCita...',
                    hintStyle: theme.textTheme.bodySmall?.copyWith(
                      color: kWebTextHint,
                    ),
                    filled: true,
                    fillColor: kWebBackground,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: kWebCardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: kWebCardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: kWebPrimary, width: 1.5),
                    ),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              sendState.isSending
                  ? const SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : FilledButton(
                      onPressed: _send,
                      style: FilledButton.styleFrom(
                        backgroundColor: kWebPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(12),
                        minimumSize: const Size(44, 44),
                      ),
                      child: const Icon(Icons.send_rounded,
                          size: 18, color: Colors.white),
                    ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOutbound = message.senderType == 'support' ||
        message.senderType == 'admin';
    final timeFormat = DateFormat('HH:mm · d MMM', 'es');

    final bubbleColor =
        isOutbound ? kWebPrimary : kWebBackground;
    final textColor =
        isOutbound ? Colors.white : kWebTextPrimary;
    final timeColor =
        isOutbound ? Colors.white70 : kWebTextHint;

    return Align(
      alignment:
          isOutbound ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isOutbound ? 12 : 2),
            bottomRight: Radius.circular(isOutbound ? 2 : 12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isOutbound
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            // Sender label
            if (!isOutbound)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  _senderLabel(message.senderType),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: kWebTextSecondary,
                  ),
                ),
              ),

            // Message text or media
            if (message.textContent != null)
              SelectableText(
                message.textContent!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: textColor,
                ),
              )
            else if (message.mediaUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  message.mediaUrl!,
                  width: 240,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Text(
                    '[imagen no disponible]',
                    style: TextStyle(color: textColor, fontSize: 12),
                  ),
                ),
              )
            else
              Text(
                '[${message.contentType}]',
                style: TextStyle(
                  color: timeColor,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),

            const SizedBox(height: 4),
            Text(
              timeFormat.format(message.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: timeColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _senderLabel(String senderType) {
    return switch (senderType) {
      'user' => 'Usuario',
      'aphrodite' => 'Afrodita',
      'eros' => 'Eros',
      'support' || 'admin' => 'Soporte BeautyCita',
      'system' => 'Sistema',
      _ => senderType,
    };
  }
}
