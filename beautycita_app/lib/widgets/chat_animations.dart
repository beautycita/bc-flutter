import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Animated message bubble wrapper — slides in from left (incoming) or right (outgoing)
/// with a subtle scale + fade, matching WhatsApp's native message entrance.
class AnimatedBubbleEntrance extends StatefulWidget {
  final Widget child;
  final bool isFromUser;
  final Duration duration;
  final Duration delay;

  const AnimatedBubbleEntrance({
    super.key,
    required this.child,
    required this.isFromUser,
    this.duration = const Duration(milliseconds: 280),
    this.delay = Duration.zero,
  });

  @override
  State<AnimatedBubbleEntrance> createState() => _AnimatedBubbleEntranceState();
}

class _AnimatedBubbleEntranceState extends State<AnimatedBubbleEntrance>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    // Slide from the sender's side (user = right, other = left)
    final slideBegin = widget.isFromUser ? 40.0 : -40.0;
    _slideAnimation = Tween<double>(begin: slideBegin, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.6, curve: Curves.easeOut)),
    );

    // Subtle scale from 0.92 → 1.0 (like WA's bubble pop-in)
    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    if (widget.delay > Duration.zero) {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_slideAnimation.value, 0),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            alignment: widget.isFromUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// WA-style send button that morphs between mic (voice) and send (arrow).
/// When text is empty → shows mic icon. When text exists → morphs to send arrow.
class MorphingSendButton extends StatelessWidget {
  final bool hasText;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback? onVoiceStart;
  final Gradient? activeGradient;

  const MorphingSendButton({
    super.key,
    required this.hasText,
    required this.isSending,
    required this.onSend,
    this.onVoiceStart,
    this.activeGradient,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (isSending) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colors.primary,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: hasText ? onSend : onVoiceStart,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: hasText ? activeGradient : null,
          color: hasText ? null : colors.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) {
            return ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: hasText
              ? const Icon(Icons.send_rounded, key: ValueKey('send'), color: Colors.white, size: 20)
              : Icon(Icons.mic_rounded, key: const ValueKey('mic'), color: colors.primary, size: 22),
        ),
      ),
    );
  }
}

/// WA-style typing indicator with wave animation (three dots that pulse in wave).
class WaveTypingIndicator extends StatefulWidget {
  final Color? dotColor;
  final Color? backgroundColor;

  const WaveTypingIndicator({super.key, this.dotColor, this.backgroundColor});

  @override
  State<WaveTypingIndicator> createState() => _WaveTypingIndicatorState();
}

class _WaveTypingIndicatorState extends State<WaveTypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dotColor = widget.dotColor ?? colors.onSurface.withValues(alpha: 0.4);
    final bgColor = widget.backgroundColor ?? colors.surface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    // Each dot is offset by 0.2 in the animation cycle
                    final phase = (_controller.value + i * 0.2) % 1.0;
                    // Sine wave for smooth up-down
                    final y = -4.0 * sin(phase * pi);
                    final opacity = 0.3 + 0.7 * sin(phase * pi).abs();

                    return Padding(
                      padding: EdgeInsets.only(left: i > 0 ? 4 : 0),
                      child: Transform.translate(
                        offset: Offset(0, y),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: dotColor.withValues(alpha: opacity),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated delivery checkmark (single → double → blue double, like WA).
class DeliveryCheckmark extends StatelessWidget {
  /// 'sent', 'delivered', 'read'
  final String status;
  final double size;

  const DeliveryCheckmark({
    super.key,
    required this.status,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    final isRead = status == 'read';
    final isDelivered = status == 'delivered' || isRead;
    final color = isRead ? const Color(0xFF53BDEB) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35);

    return SizedBox(
      width: isDelivered ? size * 1.4 : size,
      height: size,
      child: Stack(
        children: [
          Icon(Icons.check, size: size, color: color),
          if (isDelivered)
            Positioned(
              left: size * 0.4,
              child: Icon(Icons.check, size: size, color: color),
            ),
        ],
      ),
    );
  }
}

/// Image send animation — scales up from thumbnail with a progress ring overlay.
/// Matches WA UI 04 (Image Send) animation pattern.
class AnimatedImageSend extends StatefulWidget {
  final Widget child;
  final bool isSending;

  const AnimatedImageSend({
    super.key,
    required this.child,
    this.isSending = false,
  });

  @override
  State<AnimatedImageSend> createState() => _AnimatedImageSendState();
}

class _AnimatedImageSendState extends State<AnimatedImageSend>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          widget.child,
          if (widget.isSending)
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Voice recording bar — slides up from the input bar when recording starts.
/// Matches WA UI 06 (Voice Chat) animation: pulsing green mic, timer, slide-to-cancel.
class VoiceRecordingBar extends StatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback onSend;
  final Duration elapsed;

  const VoiceRecordingBar({
    super.key,
    required this.onCancel,
    required this.onSend,
    required this.elapsed,
  });

  @override
  State<VoiceRecordingBar> createState() => _VoiceRecordingBarState();
}

class _VoiceRecordingBarState extends State<VoiceRecordingBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    // Haptic feedback when recording starts
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
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
          // Pulsing red recording dot
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              return Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.5 + 0.5 * _pulseController.value),
                  shape: BoxShape.circle,
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          // Timer
          Text(
            _formatDuration(widget.elapsed),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const Spacer(),
          // Slide to cancel hint
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chevron_left, size: 18, color: colors.onSurface.withValues(alpha: 0.4)),
              Text(
                'Desliza para cancelar',
                style: TextStyle(
                  fontSize: 13,
                  color: colors.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          const Spacer(),
          // Send voice button (green mic, matches WA)
          GestureDetector(
            onTap: widget.onSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFF25D366), // WA green
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
