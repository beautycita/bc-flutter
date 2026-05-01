// Admin v2 ConfirmSheet — destructive-action confirmation with explicit verb.
//
// Returns a String? — the captured reason if [requireReason] is true,
// or '' on accept without reason, or null on cancel.

import 'package:flutter/material.dart';

import '../tokens.dart';
import 'action_button.dart';

class AdminConfirmSheet extends StatefulWidget {
  const AdminConfirmSheet({
    super.key,
    required this.title,
    required this.body,
    required this.acceptVerb,
    this.cancelVerb = 'Cancelar',
    this.requireReason = false,
    this.reasonOptions,
    this.minReasonLength = 3,
    this.destructive = true,
  });

  final String title;
  final String body;
  final String acceptVerb;
  final String cancelVerb;
  final bool requireReason;
  final List<String>? reasonOptions;
  final int minReasonLength;
  final bool destructive;

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String body,
    required String acceptVerb,
    String cancelVerb = 'Cancelar',
    bool requireReason = false,
    List<String>? reasonOptions,
    int minReasonLength = 3,
    bool destructive = true,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AdminConfirmSheet(
        title: title,
        body: body,
        acceptVerb: acceptVerb,
        cancelVerb: cancelVerb,
        requireReason: requireReason,
        reasonOptions: reasonOptions,
        minReasonLength: minReasonLength,
        destructive: destructive,
      ),
    );
  }

  @override
  State<AdminConfirmSheet> createState() => _AdminConfirmSheetState();
}

class _AdminConfirmSheetState extends State<AdminConfirmSheet> {
  final _reasonCtrl = TextEditingController();
  String? _selectedOption;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  String _composedReason() {
    final freeText = _reasonCtrl.text.trim();
    if (widget.reasonOptions == null) return freeText;
    if (_selectedOption == null) return freeText;
    if (_selectedOption == 'Otro' && freeText.isNotEmpty) return 'otro: $freeText';
    return _selectedOption!;
  }

  bool get _isValid {
    if (!widget.requireReason) return true;
    final composed = _composedReason();
    if (composed.length < widget.minReasonLength) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AdminV2Tokens.spacingLG,
          right: AdminV2Tokens.spacingLG,
          top: AdminV2Tokens.spacingLG,
          bottom: AdminV2Tokens.spacingLG + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: AdminV2Tokens.title(context)),
            const SizedBox(height: AdminV2Tokens.spacingSM),
            Text(widget.body, style: AdminV2Tokens.body(context)),
            if (widget.requireReason) ...[
              const SizedBox(height: AdminV2Tokens.spacingMD),
              if (widget.reasonOptions != null) ...[
                Text('Motivo', style: AdminV2Tokens.muted(context)),
                const SizedBox(height: AdminV2Tokens.spacingSM),
                Wrap(
                  spacing: AdminV2Tokens.spacingSM,
                  runSpacing: AdminV2Tokens.spacingSM,
                  children: widget.reasonOptions!.map((opt) {
                    final selected = _selectedOption == opt;
                    return ChoiceChip(
                      label: Text(opt),
                      selected: selected,
                      onSelected: (_) => setState(() => _selectedOption = opt),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AdminV2Tokens.spacingSM),
              ],
              TextField(
                controller: _reasonCtrl,
                onChanged: (_) => setState(() {}),
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: widget.reasonOptions == null ? 'Motivo' : 'Detalles (opcional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AdminV2Tokens.radiusSM)),
                ),
              ),
            ],
            const SizedBox(height: AdminV2Tokens.spacingLG),
            Row(
              children: [
                Expanded(
                  child: AdminActionButton(
                    label: widget.cancelVerb,
                    variant: AdminActionVariant.secondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: AdminV2Tokens.spacingMD),
                Expanded(
                  child: AdminActionButton(
                    label: widget.acceptVerb,
                    variant: widget.destructive ? AdminActionVariant.destructive : AdminActionVariant.primary,
                    onPressed: _isValid ? () => Navigator.of(context).pop(_composedReason()) : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
