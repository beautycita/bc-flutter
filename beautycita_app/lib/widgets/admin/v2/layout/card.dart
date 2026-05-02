// Admin v2 Card primitive.
//
// Single Card primitive for the entire admin v2. No per-screen Card variants —
// if a screen "needs" a custom card, extend the props here, do not fork.

import 'package:flutter/material.dart';

import '../tokens.dart';

class AdminCard extends StatelessWidget {
  const AdminCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(AdminV2Tokens.spacingMD),
    this.margin = const EdgeInsets.only(bottom: AdminV2Tokens.spacingMD),
    this.onTap,
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AdminV2Tokens.radiusMD);
    final inner = Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AdminV2Tokens.spacingMD),
              child: Row(
                children: [
                  Expanded(child: Text(title!, style: AdminV2Tokens.subtitle(context))),
                  ?trailing,
                ],
              ),
            ),
          child,
        ],
      ),
    );
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: AdminV2Tokens.cardBg(context),
        borderRadius: radius,
        border: Border.all(color: AdminV2Tokens.cardBorder(context), width: 1),
      ),
      clipBehavior: onTap == null ? Clip.none : Clip.antiAlias,
      child: onTap == null
          ? inner
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: radius,
                child: inner,
              ),
            ),
    );
  }
}

class AdminCardSkeleton extends StatelessWidget {
  const AdminCardSkeleton({super.key, this.heightHint = 80});
  final double heightHint;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: heightHint,
      margin: const EdgeInsets.only(bottom: AdminV2Tokens.spacingMD),
      decoration: BoxDecoration(
        color: AdminV2Tokens.cardBg(context),
        borderRadius: BorderRadius.circular(AdminV2Tokens.radiusMD),
        border: Border.all(color: AdminV2Tokens.cardBorder(context), width: 1),
      ),
      child: const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
