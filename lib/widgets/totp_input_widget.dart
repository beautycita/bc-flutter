import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reusable 6-digit TOTP code input with auto-advance and backspace support.
class TotpInputWidget extends StatefulWidget {
  final ValueChanged<String> onComplete;
  final bool isLoading;
  final String? error;

  const TotpInputWidget({
    super.key,
    required this.onComplete,
    this.isLoading = false,
    this.error,
  });

  @override
  State<TotpInputWidget> createState() => _TotpInputWidgetState();
}

class _TotpInputWidgetState extends State<TotpInputWidget> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _onChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    _checkComplete();
  }

  void _onKey(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _checkComplete() {
    final code = _controllers.map((c) => c.text).join();
    if (code.length == 6) {
      widget.onComplete(code);
    }
  }

  void clear() {
    for (final c in _controllers) c.clear();
    _focusNodes[0].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasError = widget.error != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (i) {
            return Container(
              width: 44,
              height: 52,
              margin: EdgeInsets.only(
                left: i == 0 ? 0 : (i == 3 ? 12 : 6),
                right: 0,
              ),
              child: KeyboardListener(
                focusNode: FocusNode(),
                onKeyEvent: (event) => _onKey(i, event),
                child: TextField(
                  controller: _controllers[i],
                  focusNode: _focusNodes[i],
                  enabled: !widget.isLoading,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: hasError ? Colors.red : colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: hasError
                            ? Colors.red
                            : colorScheme.onSurface.withValues(alpha: 0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: hasError ? Colors.red : const Color(0xFFF7931A),
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: colorScheme.surface,
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) => _onChanged(i, v),
                ),
              ),
            );
          }),
        ),
        if (hasError) ...[
          const SizedBox(height: 8),
          Text(
            widget.error!,
            style: const TextStyle(color: Colors.red, fontSize: 13),
          ),
        ],
        if (widget.isLoading) ...[
          const SizedBox(height: 12),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      ],
    );
  }
}
