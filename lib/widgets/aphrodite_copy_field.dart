import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/aphrodite_service.dart';

/// A text field with an Aphrodite AI copy-generation button.
/// Shows pre-generated text and a refresh icon to generate new suggestions.
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
  final _aphrodite = AphroditeService();
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
      final text = await _aphrodite.generateCopy(
        fieldType: widget.fieldType,
        context: widget.context,
      );
      if (mounted && text.isNotEmpty) {
        widget.controller.text = text;
        widget.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: text.length),
        );
      }
    } on AphroditeException catch (e) {
      if (mounted && e.statusCode == 429) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.orange.shade700,
          ),
        );
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              TextField(
                controller: widget.controller,
                maxLines: widget.maxLines,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
                decoration: InputDecoration(
                  labelText: widget.label,
                  labelStyle: GoogleFonts.nunito(
                    fontSize: 13,
                    color: colors.onSurface.withValues(alpha: 0.5),
                  ),
                  hintText: widget.hint,
                  hintStyle: GoogleFonts.nunito(
                    fontSize: 13,
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.04),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 14,
                      color: colors.primary.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Aphrodite',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                        color: colors.primary.withValues(alpha: 0.5),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
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
                                child: Icon(
                                  Icons.refresh_rounded,
                                  size: 14,
                                  color: colors.primary.withValues(alpha: 0.5),
                                ),
                              ),
                            )
                          else
                            Icon(
                              Icons.refresh_rounded,
                              size: 14,
                              color: colors.primary.withValues(alpha: 0.5),
                            ),
                          const SizedBox(width: 4),
                          Text(
                            _generating ? 'Generando...' : 'Generar nuevo',
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colors.primary.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
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
