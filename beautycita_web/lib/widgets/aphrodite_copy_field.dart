import 'package:flutter/material.dart';
import 'package:beautycita_core/supabase.dart';

/// AI-assisted text field with an "Aphrodite" generation bar.
/// Calls the `aphrodite-chat` edge function with `action: generate_copy`.
class AphroditeCopyField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final String fieldType;
  final Map<String, String> context;
  final bool autoGenerate;

  const AphroditeCopyField({
    super.key,
    required this.controller,
    required this.label,
    required this.fieldType,
    this.hint = '',
    this.icon = Icons.edit_rounded,
    this.maxLines = 3,
    this.context = const {},
    this.autoGenerate = true,
  });

  @override
  State<AphroditeCopyField> createState() => _AphroditeCopyFieldState();
}

class _AphroditeCopyFieldState extends State<AphroditeCopyField>
    with SingleTickerProviderStateMixin {
  bool _generating = false;
  late AnimationController _spinCtrl;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    if (widget.autoGenerate && widget.controller.text.isEmpty) {
      _generate();
    }
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_generating) return;
    setState(() => _generating = true);
    _spinCtrl.repeat();

    try {
      final response = await BCSupabase.client.functions.invoke(
        'aphrodite-chat',
        body: {
          'action': 'generate_copy',
          'field_type': widget.fieldType,
          'context': widget.context,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.status == 429 && mounted) {
        final data = response.data as Map<String, dynamic>?;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data?['text'] as String? ?? 'Limite alcanzado'),
            backgroundColor: Colors.orange.shade700,
          ),
        );
        return;
      }

      if (response.status == 200 && mounted) {
        final data = response.data as Map<String, dynamic>?;
        final text = data?['text'] as String? ?? '';
        if (text.isNotEmpty) {
          widget.controller.text = text;
          widget.controller.selection = TextSelection.fromPosition(
            TextPosition(offset: text.length),
          );
        }
      }
    } catch (_) {
      // Silent fail — field stays editable
    } finally {
      if (mounted) {
        _spinCtrl.stop();
        _spinCtrl.reset();
        setState(() => _generating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              TextField(
                controller: widget.controller,
                maxLines: widget.maxLines,
                style: theme.textTheme.bodyMedium,
                decoration: InputDecoration(
                  labelText: widget.label,
                  labelStyle: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.5),
                  ),
                  hintText: widget.hint,
                  hintStyle: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.3),
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    child: Icon(widget.icon, size: 18, color: colors.primary),
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.fromLTRB(0, 14, 12, 14),
                ),
              ),
              // Aphrodite bar
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.04),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        size: 14,
                        color: colors.primary.withValues(alpha: 0.6)),
                    const SizedBox(width: 4),
                    Text(
                      'Aphrodite',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: colors.primary.withValues(alpha: 0.5),
                      ),
                    ),
                    const Spacer(),
                    MouseRegion(
                      cursor: _generating
                          ? SystemMouseCursors.basic
                          : SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: _generating ? null : _generate,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_generating)
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: RotationTransition(
                                  turns: _spinCtrl,
                                  child: Icon(Icons.refresh_rounded,
                                      size: 14,
                                      color: colors.primary
                                          .withValues(alpha: 0.5)),
                                ),
                              )
                            else
                              Icon(Icons.refresh_rounded,
                                  size: 14,
                                  color:
                                      colors.primary.withValues(alpha: 0.5)),
                            const SizedBox(width: 4),
                            Text(
                              _generating ? 'Generando...' : 'Generar nuevo',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colors.primary.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
