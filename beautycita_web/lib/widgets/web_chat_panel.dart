import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/models.dart';
import 'package:beautycita_core/theme.dart';

import '../providers/support_provider.dart';

/// Desktop-optimized chat panel with tabs for Eros AI and Human Support.
class WebChatPanel extends ConsumerStatefulWidget {
  const WebChatPanel({super.key});

  @override
  ConsumerState<WebChatPanel> createState() => _WebChatPanelState();
}

class _WebChatPanelState extends ConsumerState<WebChatPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(SupportTab tab, String? threadId) async {
    final text = _controller.text.trim();
    if (text.isEmpty || threadId == null) return;

    _controller.clear();
    _focusNode.requestFocus();

    if (tab == SupportTab.eros) {
      await ref.read(sendErosMessageProvider.notifier).send(threadId, text);
    } else {
      await ref.read(sendHumanMessageProvider.notifier).send(threadId, text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(supportTabProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BCSpacing.radiusSm),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Tab bar ──
          _buildTabBar(tab, colors),
          const Divider(height: 1),

          // ── Chat area ──
          Expanded(
            child: tab == SupportTab.eros
                ? _buildErosChat(colors)
                : _buildHumanChat(colors),
          ),

          // ── Input area ──
          _buildInputArea(tab, colors),
        ],
      ),
    );
  }

  Widget _buildTabBar(SupportTab activeTab, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.all(BCSpacing.sm),
      child: Row(
        children: [
          _TabButton(
            icon: Icons.auto_awesome,
            label: 'Eros IA',
            isActive: activeTab == SupportTab.eros,
            activeColor: const Color(0xFF00897B), // teal
            onTap: () =>
                ref.read(supportTabProvider.notifier).state = SupportTab.eros,
          ),
          const SizedBox(width: BCSpacing.sm),
          _TabButton(
            icon: Icons.headset_mic_rounded,
            label: 'Soporte Humano',
            isActive: activeTab == SupportTab.human,
            activeColor: const Color(0xFF7B1038), // maroon
            onTap: () =>
                ref.read(supportTabProvider.notifier).state = SupportTab.human,
          ),
        ],
      ),
    );
  }

  Widget _buildErosChat(ColorScheme colors) {
    final threadAsync = ref.watch(erosThreadProvider);

    return threadAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (thread) {
        if (thread == null) {
          return const Center(child: Text('No se pudo iniciar el chat'));
        }
        return _buildMessageList(thread.id, const Color(0xFF00897B));
      },
    );
  }

  Widget _buildHumanChat(ColorScheme colors) {
    final threadAsync = ref.watch(humanSupportThreadProvider);

    return threadAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (thread) {
        if (thread == null) {
          return const Center(child: Text('No se pudo iniciar el chat'));
        }
        return _buildMessageList(thread.id, const Color(0xFF7B1038));
      },
    );
  }

  Widget _buildMessageList(String threadId, Color agentColor) {
    final messagesAsync = ref.watch(chatMessagesProvider(threadId));

    return messagesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (messages) {
        _scrollToBottom();
        if (messages.isEmpty) {
          return const Center(
            child: Text(
              'Escribe un mensaje para comenzar',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(BCSpacing.md),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            return _MessageBubble(
              message: messages[index],
              agentColor: agentColor,
            );
          },
        );
      },
    );
  }

  Widget _buildInputArea(SupportTab tab, ColorScheme colors) {
    final erosThread = ref.watch(erosThreadProvider).valueOrNull;
    final humanThread = ref.watch(humanSupportThreadProvider).valueOrNull;
    final threadId =
        tab == SupportTab.eros ? erosThread?.id : humanThread?.id;

    final erosSend = ref.watch(sendErosMessageProvider);
    final humanSend = ref.watch(sendHumanMessageProvider);
    final isSending = tab == SupportTab.eros
        ? erosSend.isSending
        : humanSend.isSending;

    final agentColor = tab == SupportTab.eros
        ? const Color(0xFF00897B)
        : const Color(0xFF7B1038);

    return Container(
      padding: const EdgeInsets.all(BCSpacing.md),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.outline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Quick action chips (Eros only)
          if (tab == SupportTab.eros) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _QuickChip(
                    label: 'Como reservo?',
                    onTap: () => _sendQuick(threadId, 'Como reservo una cita?'),
                  ),
                  _QuickChip(
                    label: 'Problema con pago',
                    onTap: () => _sendQuick(
                        threadId, 'Tengo un problema con un pago'),
                  ),
                  _QuickChip(
                    label: 'Cancelar cita',
                    onTap: () => _sendQuick(
                        threadId, 'Como cancelo una cita?'),
                  ),
                  _QuickChip(
                    label: 'Hablar con humano',
                    onTap: () => ref.read(supportTabProvider.notifier).state =
                        SupportTab.human,
                  ),
                ],
              ),
            ),
            const SizedBox(height: BCSpacing.sm),
          ],
          // Text input + send
          Row(
            children: [
              Expanded(
                child: KeyboardListener(
                  focusNode: FocusNode(),
                  onKeyEvent: (event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.enter &&
                        !HardwareKeyboard.instance.isShiftPressed) {
                      _sendMessage(tab, threadId);
                    }
                  },
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: tab == SupportTab.eros
                          ? 'Pregunta a Eros...'
                          : 'Escribe al equipo de soporte...',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(BCSpacing.radiusSm),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: BCSpacing.md,
                        vertical: BCSpacing.sm,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: BCSpacing.sm),
              IconButton.filled(
                onPressed: isSending
                    ? null
                    : () => _sendMessage(tab, threadId),
                icon: isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: agentColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 48),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _sendQuick(String? threadId, String text) {
    if (threadId == null) return;
    _controller.text = text;
    _sendMessage(SupportTab.eros, threadId);
  }
}

// ── Tab button ───────────────────────────────────────────────────────────────

class _TabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _TabButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? activeColor.withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(BCSpacing.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BCSpacing.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BCSpacing.md,
            vertical: BCSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: isActive ? activeColor : Colors.grey),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? activeColor : Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Message bubble ───────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final Color agentColor;

  const _MessageBubble({required this.message, required this.agentColor});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isFromUser;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: BCSpacing.sm),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: agentColor.withValues(alpha: 0.15),
              child: Icon(
                message.isFromEros ? Icons.auto_awesome : Icons.headset_mic,
                size: 16,
                color: agentColor,
              ),
            ),
            const SizedBox(width: BCSpacing.sm),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              padding: const EdgeInsets.symmetric(
                horizontal: BCSpacing.md,
                vertical: BCSpacing.sm + 2,
              ),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(BCSpacing.radiusSm),
                  topRight: const Radius.circular(BCSpacing.radiusSm),
                  bottomLeft: Radius.circular(isUser ? BCSpacing.radiusSm : 4),
                  bottomRight:
                      Radius.circular(isUser ? 4 : BCSpacing.radiusSm),
                ),
                border: isUser
                    ? Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2))
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    message.textContent ?? '',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: BCSpacing.sm),
            CircleAvatar(
              radius: 16,
              backgroundColor:
                  theme.colorScheme.primary.withValues(alpha: 0.15),
              child: Icon(
                Icons.person,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ── Quick action chip ────────────────────────────────────────────────────────

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onPressed: onTap,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
