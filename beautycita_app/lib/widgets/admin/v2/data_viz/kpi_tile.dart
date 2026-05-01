// Admin v2 KpiTile — point-in-time number with optional unit + delta hint.

import 'package:flutter/material.dart';

import '../tokens.dart';

class AdminKpiTile extends StatelessWidget {
  const AdminKpiTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.deltaHint,
    this.deltaPositive,
  });

  final String label;
  final String value;
  final String? unit;
  final String? deltaHint;
  final bool? deltaPositive;

  @override
  Widget build(BuildContext context) {
    final deltaColor = deltaPositive == null
        ? AdminV2Tokens.subtle(context)
        : (deltaPositive! ? AdminV2Tokens.success(context) : AdminV2Tokens.destructive(context));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AdminV2Tokens.muted(context)),
        const SizedBox(height: AdminV2Tokens.spacingXS),
        RichText(
          text: TextSpan(
            text: value,
            style: AdminV2Tokens.kpiNumber(context),
            children: [
              if (unit != null)
                TextSpan(
                  text: ' $unit',
                  style: AdminV2Tokens.muted(context).copyWith(fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ),
        if (deltaHint != null) ...[
          const SizedBox(height: AdminV2Tokens.spacingXS),
          Text(deltaHint!, style: AdminV2Tokens.muted(context).copyWith(color: deltaColor)),
        ],
      ],
    );
  }
}
