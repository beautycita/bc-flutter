// Admin v2 ListRow primitive.
//
// label · value · optional edit affordance · optional trailing widget.

import 'package:flutter/material.dart';

import '../tokens.dart';

class AdminListRow extends StatelessWidget {
  const AdminListRow({
    super.key,
    required this.label,
    this.value,
    this.onEdit,
    this.trailing,
    this.editable = false,
    this.dense = false,
  });

  final String label;
  final String? value;
  final VoidCallback? onEdit;
  final Widget? trailing;
  final bool editable;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? AdminV2Tokens.spacingXS : AdminV2Tokens.spacingSM),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: AdminV2Tokens.muted(context)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value?.isNotEmpty == true ? value! : '—',
              style: AdminV2Tokens.body(context).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (editable && onEdit != null)
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: AdminV2Tokens.minTapHeight, minHeight: AdminV2Tokens.minTapHeight),
              child: IconButton(
                icon: Icon(Icons.edit_outlined, size: 18, color: AdminV2Tokens.subtle(context)),
                onPressed: onEdit,
                tooltip: 'Editar',
              ),
            ),
          ?trailing,
        ],
      ),
    );
  }
}
