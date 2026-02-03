import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/chat_message.dart';
import '../providers/chat_provider.dart';
import '../providers/user_preferences_provider.dart';

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
  bool _onboardingChecked = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Start the onboarding flow if it hasn't been completed yet.
  /// Called once when the Aphrodite thread loads.
  void _checkOnboarding(bool isAphrodite) {
    if (_onboardingChecked || !isAphrodite) return;
    _onboardingChecked = true;

    final prefs = ref.read(userPrefsProvider);
    if (prefs.onboardingComplete) return;

    // Insert intro + first preference card after a short delay
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _insertOnboardingIntro();
    });
  }

  Future<void> _insertOnboardingIntro() async {
    final service = ref.read(aphroditeServiceProvider);
    await service.insertLocalMessage(
      threadId: widget.threadId,
      senderType: 'aphrodite',
      textContent:
          'Antes de empezar, dejame conocerte un poco... '
          'Asi te puedo recomendar los mejores lugares.',
    );
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    await service.insertLocalMessage(
      threadId: widget.threadId,
      senderType: 'aphrodite',
      contentType: 'preference_card',
      textContent: 'Tu presupuesto para belleza',
      metadata: {
        'pref_type': 'price_comfort',
        'options': [
          {'value': 'budget', 'label': '\$', 'description': 'Economico'},
          {'value': 'moderate', 'label': '\$\$', 'description': 'Buen balance'},
          {'value': 'premium', 'label': '\$\$\$', 'description': 'Premium'},
        ],
        'selected': null,
      },
    );
    _scrollToBottom();
  }

  Future<void> _onPreferenceSelected(
    ChatMessage message,
    String prefType,
    dynamic value,
    String displayText,
  ) async {
    final service = ref.read(aphroditeServiceProvider);
    final prefsNotifier = ref.read(userPrefsProvider.notifier);

    // Save the preference
    switch (prefType) {
      case 'price_comfort':
        await prefsNotifier.setPriceComfort(value as String);
      case 'quality_speed':
        await prefsNotifier.setQualitySpeed(value as double);
      case 'explore_loyal':
        await prefsNotifier.setExploreLoyalty(value as double);
    }

    // Insert user choice as text
    await service.insertLocalMessage(
      threadId: widget.threadId,
      senderType: 'user',
      textContent: displayText,
    );

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    // Insert Aphrodite reaction + next card (or finish)
    final reaction = _getReaction(prefType, value);
    await service.insertLocalMessage(
      threadId: widget.threadId,
      senderType: 'aphrodite',
      textContent: reaction,
    );

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    // Determine next step
    if (prefType == 'price_comfort') {
      await service.insertLocalMessage(
        threadId: widget.threadId,
        senderType: 'aphrodite',
        contentType: 'preference_card',
        textContent: 'Calidad o rapidez?',
        metadata: {
          'pref_type': 'quality_speed',
          'options': [
            {'value': 0.0, 'label': 'Rapido', 'description': 'Lo mas rapido posible'},
            {'value': 0.5, 'label': 'Balance', 'description': 'Un poco de todo'},
            {'value': 1.0, 'label': 'Calidad', 'description': 'Solo lo mejor'},
          ],
          'selected': null,
        },
      );
    } else if (prefType == 'quality_speed') {
      await service.insertLocalMessage(
        threadId: widget.threadId,
        senderType: 'aphrodite',
        contentType: 'preference_card',
        textContent: 'Explorar o quedarte con tus favoritos?',
        metadata: {
          'pref_type': 'explore_loyal',
          'options': [
            {'value': 0.0, 'label': 'Explorar', 'description': 'Nuevos lugares'},
            {'value': 0.5, 'label': 'Flexible', 'description': 'Depende del dia'},
            {'value': 1.0, 'label': 'Fiel', 'description': 'Mis lugares de siempre'},
          ],
          'selected': null,
        },
      );
    } else if (prefType == 'explore_loyal') {
      // Onboarding complete!
      await prefsNotifier.setOnboardingComplete(true);
      await service.insertLocalMessage(
        threadId: widget.threadId,
        senderType: 'aphrodite',
        textContent:
            'Listo, ya te conozco. Ahora si, preguntame lo que quieras '
            'o reserva un servicio. Estoy aqui... porque no tengo opcion.',
      );
    }
    _scrollToBottom();
  }

  String _getReaction(String prefType, dynamic value) {
    switch (prefType) {
      case 'price_comfort':
        return switch (value as String) {
          'budget' =>
            '*asiente* Economia inteligente. No te preocupes, conozco tesoros escondidos...',
          'moderate' =>
            'Mmm, equilibrio... como yo, perfecta en todo. Buena eleccion.',
          'premium' =>
            '*sonrisa divina* Al fin alguien con buen gusto. Ya nos entendemos.',
          _ => 'Interesante...',
        };
      case 'quality_speed':
        final v = value as double;
        if (v < 0.35) {
          return 'Prisa, prisa... Los mortales y su tiempo. Bueno, te consigo algo rapido y decente.';
        } else if (v > 0.65) {
          return 'La perfeccion toma tiempo, como yo. Respeto.';
        }
        return 'Un poco de todo, clasico mortal. Puedo trabajar con eso.';
      case 'explore_loyal':
        final v = value as double;
        if (v < 0.35) {
          return 'Aventurera... Me gusta. Hay tantos lugares que no conoces.';
        } else if (v > 0.65) {
          return 'Fiel a tus lugares. Eso dice algo bueno de ti.';
        }
        return 'Flexible, me parece bien.';
      default:
        return 'Interesante...';
    }
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
    final sendState = ref.watch(sendMessageProvider);

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

    // Trigger onboarding check once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOnboarding(isAphrodite);
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0EB),
      appBar: AppBar(
        backgroundColor: BeautyCitaTheme.backgroundWhite,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
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
                    if (msg.isPreferenceCard) {
                      return _PreferenceCard(
                        message: msg,
                        onSelected: (value, displayText) {
                          final prefType =
                              msg.metadata['pref_type'] as String? ?? '';
                          _onPreferenceSelected(
                              msg, prefType, value, displayText);
                        },
                      );
                    }
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
            onSend: _sendMessage,
            onCamera: () => _handleCamera(),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCamera() async {
    // Show try-on options bottom sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _TryOnOptionsSheet(
        onSelect: (stylePrompt) {
          Navigator.pop(ctx);
          // For now, send a text message about trying on
          _textController.text = 'Quiero una prueba virtual: $stylePrompt';
          _sendMessage();
        },
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

/// Preference card shown during Aphrodite onboarding.
/// Displays tappable options for setting a preference.
class _PreferenceCard extends StatelessWidget {
  final ChatMessage message;
  final void Function(dynamic value, String displayText) onSelected;

  const _PreferenceCard({
    required this.message,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final title = message.textContent ?? '';
    final options = (message.metadata['options'] as List<dynamic>?) ?? [];
    final selected = message.metadata['selected'];
    final isAnswered = selected != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFFB300).withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFB300).withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: BeautyCitaTheme.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: options.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final opt = entry.value as Map<String, dynamic>;
                    final optValue = opt['value'];
                    final label = opt['label'] as String? ?? '';
                    final desc = opt['description'] as String? ?? '';
                    final isSelected = isAnswered && selected == optValue;

                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: idx > 0 ? 8 : 0,
                        ),
                        child: GestureDetector(
                          onTap: isAnswered
                              ? null
                              : () => onSelected(optValue, '$label - $desc'),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFFFB300).withValues(alpha: 0.15)
                                  : isAnswered
                                      ? Colors.grey.shade100
                                      : BeautyCitaTheme.surfaceCream,
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected
                                  ? Border.all(
                                      color: const Color(0xFFFFB300),
                                      width: 2,
                                    )
                                  : Border.all(
                                      color: Colors.transparent,
                                      width: 2,
                                    ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  label,
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: isAnswered && !isSelected
                                        ? BeautyCitaTheme.textLight
                                        : BeautyCitaTheme.textDark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  desc,
                                  style: GoogleFonts.nunito(
                                    fontSize: 11,
                                    color: isAnswered && !isSelected
                                        ? BeautyCitaTheme.textLight
                                        : BeautyCitaTheme.textDark,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
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
  final VoidCallback onSend;
  final VoidCallback onCamera;

  const _InputBar({
    required this.controller,
    required this.isSending,
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
          // Camera button
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

/// Try-on options bottom sheet.
class _TryOnOptionsSheet extends StatelessWidget {
  final void Function(String stylePrompt) onSelect;

  const _TryOnOptionsSheet({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 20),
          Text(
            '✨ Prueba Virtual',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Elige qué quieres probar',
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: BeautyCitaTheme.textLight,
            ),
          ),
          const SizedBox(height: 20),
          _TryOnOption(
            icon: '🎨',
            title: 'Prueba de Color',
            subtitle: 'Prueba un nuevo color de cabello',
            onTap: () => onSelect('Cambio de color de cabello'),
          ),
          const SizedBox(height: 12),
          _TryOnOption(
            icon: '💄',
            title: 'Prueba de Maquillaje',
            subtitle: 'Ve cómo te queda un look',
            onTap: () => onSelect('Prueba de maquillaje'),
          ),
          const SizedBox(height: 12),
          _TryOnOption(
            icon: '💇',
            title: 'Mi Nuevo Look',
            subtitle: 'Transformación completa',
            onTap: () => onSelect('Transformación de look completa'),
          ),
        ],
      ),
    );
  }
}

class _TryOnOption extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _TryOnOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BeautyCitaTheme.surfaceCream,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: BeautyCitaTheme.textLight,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: BeautyCitaTheme.textLight,
            ),
          ],
        ),
      ),
    );
  }
}
