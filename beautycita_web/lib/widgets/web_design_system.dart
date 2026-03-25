import 'package:flutter/material.dart';

// ============================================================================
// Web Design System Components
//
// Reusable widgets implementing the approved BeautyCita web redesign spec.
// Desktop-first. Warm minimal theme. Brand gradient: pink -> purple -> blue.
// ============================================================================

// ── Brand constants (duplicated here to avoid coupling to palette) ──────────

const _kPrimary = Color(0xFFEC4899);
const _kSecondary = Color(0xFF9333EA);
const _kTertiary = Color(0xFF3B82F6);
const _kCardBorder = Color(0xFFF0EBE6);
const _kTextPrimary = Color(0xFF1A1A1A);
const _kTextSecondary = Color(0xFF666666);

const _kBrandGradient = LinearGradient(
  colors: [_kPrimary, _kSecondary, _kTertiary],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// ════════════════════════════════════════════════════════════════════════════
// WebGradientHero
// ════════════════════════════════════════════════════════════════════════════

/// Full-width container with brand gradient, rounded corners, and optional
/// decorative blurred circles.
class WebGradientHero extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;

  /// Show decorative blurred circles for visual flair.
  final bool showDecorations;

  const WebGradientHero({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(48),
    this.borderRadius = 24,
    this.showDecorations = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: _kBrandGradient,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (showDecorations) ...[
            // Top-right decorative circle
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            // Bottom-left decorative circle
            Positioned(
              bottom: -60,
              left: -30,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            // Mid-center smaller circle
            Positioned(
              top: 60,
              left: 200,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
          ],
          Padding(
            padding: padding,
            child: child,
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// WebCard
// ════════════════════════════════════════════════════════════════════════════

/// White card with warm border, dual-layer shadow, and hover lift animation.
class WebCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double borderRadius;

  const WebCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(24),
    this.borderRadius = 16,
  });

  @override
  State<WebCard> createState() => _WebCardState();
}

class _WebCardState extends State<WebCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hovering ? -4 : 0, 0),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(color: _kCardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hovering ? 0.06 : 0.03),
                blurRadius: _hovering ? 16 : 10,
                offset: Offset(0, _hovering ? 6 : 2),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: _hovering ? 0.04 : 0.02),
                blurRadius: _hovering ? 30 : 20,
                offset: Offset(0, _hovering ? 10 : 4),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// WebSectionHeader
// ════════════════════════════════════════════════════════════════════════════

/// Section header: small uppercase gradient label + large bold title + optional subtitle.
class WebSectionHeader extends StatelessWidget {
  final String label;
  final String title;
  final String? subtitle;

  /// If true, text is centered. Otherwise left-aligned.
  final bool centered;

  /// Title font size (defaults to 38).
  final double titleSize;

  const WebSectionHeader({
    super.key,
    required this.label,
    required this.title,
    this.subtitle,
    this.centered = true,
    this.titleSize = 38,
  });

  @override
  Widget build(BuildContext context) {
    final alignment = centered ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final textAlign = centered ? TextAlign.center : TextAlign.start;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        // Gradient uppercase label
        ShaderMask(
          shaderCallback: (bounds) => _kBrandGradient.createShader(bounds),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
              color: Colors.white, // masked by shader
              fontFamily: 'system-ui',
            ),
            textAlign: textAlign,
          ),
        ),
        const SizedBox(height: 12),

        // Large title
        Text(
          title,
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.w800,
            color: _kTextPrimary,
            height: 1.2,
            fontFamily: 'system-ui',
          ),
          textAlign: textAlign,
        ),

        // Optional subtitle
        if (subtitle != null) ...[
          const SizedBox(height: 12),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w400,
              color: _kTextSecondary,
              height: 1.6,
              fontFamily: 'system-ui',
            ),
            textAlign: textAlign,
          ),
        ],
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// WebFeatureCard
// ════════════════════════════════════════════════════════════════════════════

/// Card with: icon in colored box, title, description. Hover lift via WebCard.
class WebFeatureCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final VoidCallback? onTap;

  const WebFeatureCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return WebCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon box: 48x48, 12px radius, colored bg at 10% opacity
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _kTextPrimary,
              fontFamily: 'system-ui',
            ),
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            description,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: _kTextSecondary,
              height: 1.7,
              fontFamily: 'system-ui',
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// WebInfoRow
// ════════════════════════════════════════════════════════════════════════════

/// Icon box + Column(label, value) + optional trailing widget.
/// Same visual pattern as mobile but sized for desktop.
class WebInfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Widget? trailing;

  const WebInfoRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Icon box: 34x34, radius 10, colored bg
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),

        // Label + value column
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _kTextSecondary,
                  fontFamily: 'system-ui',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _kTextPrimary,
                  fontFamily: 'system-ui',
                ),
              ),
            ],
          ),
        ),

        if (trailing != null) trailing!,
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// WebGradientButton
// ════════════════════════════════════════════════════════════════════════════

/// Gradient background button with hover glow + scale, loading spinner state.
class WebGradientButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool isLoading;
  final EdgeInsets padding;

  const WebGradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isLoading = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
  });

  @override
  State<WebGradientButton> createState() => _WebGradientButtonState();
}

class _WebGradientButtonState extends State<WebGradientButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.isLoading;

    return MouseRegion(
      onEnter: (_) {
        if (enabled) setState(() => _hovering = true);
      },
      onExit: (_) => setState(() => _hovering = false),
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: Matrix4.identity()
              ..scaleByDouble(
                  _hovering ? 1.02 : 1.0, _hovering ? 1.02 : 1.0, 1.0, 1),
          transformAlignment: Alignment.center,
          padding: widget.padding,
          decoration: BoxDecoration(
            gradient: enabled ? _kBrandGradient : null,
            color: enabled ? null : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(12),
            boxShadow: _hovering
                ? [
                    BoxShadow(
                      color: _kPrimary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: widget.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : DefaultTextStyle(
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'system-ui',
                  ),
                  child: widget.child,
                ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// WebOutlinedButton
// ════════════════════════════════════════════════════════════════════════════

/// Outlined button: 2px primary border, transparent fill.
/// Hover: gradient fill at 10% opacity.
class WebOutlinedButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool isLoading;
  final EdgeInsets padding;

  const WebOutlinedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isLoading = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
  });

  @override
  State<WebOutlinedButton> createState() => _WebOutlinedButtonState();
}

class _WebOutlinedButtonState extends State<WebOutlinedButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.isLoading;

    return MouseRegion(
      onEnter: (_) {
        if (enabled) setState(() => _hovering = true);
      },
      onExit: (_) => setState(() => _hovering = false),
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: widget.padding,
          decoration: BoxDecoration(
            // On hover, fill with gradient at low opacity
            gradient: _hovering ? _kBrandGradient : null,
            color: _hovering ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled ? _kPrimary : Colors.grey.shade300,
              width: 2,
            ),
          ),
          // Layer an opacity on the gradient fill
          foregroundDecoration: _hovering
              ? BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(12),
                )
              : null,
          child: widget.isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(_kPrimary),
                  ),
                )
              : DefaultTextStyle(
                  style: TextStyle(
                    color: enabled ? _kPrimary : Colors.grey.shade400,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'system-ui',
                  ),
                  child: widget.child,
                ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// WebTrustBadge
// ════════════════════════════════════════════════════════════════════════════

/// Pill-shaped badge with icon + text. Gradient or outlined variant.
class WebTrustBadge extends StatelessWidget {
  final IconData icon;
  final String text;

  /// If true, uses gradient background + white text.
  /// If false, uses outlined style with gradient text.
  final bool filled;

  const WebTrustBadge({
    super.key,
    required this.icon,
    required this.text,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: _kBrandGradient,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'system-ui',
              ),
            ),
          ],
        ),
      );
    }

    // Outlined variant with gradient text
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _kCardBorder, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => _kBrandGradient.createShader(bounds),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 6),
          ShaderMask(
            shaderCallback: (bounds) => _kBrandGradient.createShader(bounds),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white, // masked by shader
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'system-ui',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lays out trust badges horizontally with consistent spacing.
class WebTrustBadgeRow extends StatelessWidget {
  final List<WebTrustBadge> badges;
  final double spacing;
  final MainAxisAlignment alignment;

  const WebTrustBadgeRow({
    super.key,
    required this.badges,
    this.spacing = 12,
    this.alignment = MainAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      alignment: alignment == MainAxisAlignment.center
          ? WrapAlignment.center
          : WrapAlignment.start,
      children: badges,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// WebComparisonTable
// ════════════════════════════════════════════════════════════════════════════

/// Feature comparison table with highlighted BC column.
///
/// [columns] - column header labels (first is the feature name column).
/// [highlightIndex] - index of the column to highlight (BC column).
/// [rows] - list of rows, each row is a list of widgets (one per column).
class WebComparisonTable extends StatelessWidget {
  final List<String> columns;
  final int highlightIndex;
  final List<List<Widget>> rows;

  /// Badge text shown above the highlighted column header.
  final String? highlightBadge;

  const WebComparisonTable({
    super.key,
    required this.columns,
    required this.rows,
    this.highlightIndex = 1,
    this.highlightBadge = 'RECOMENDADO',
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.of(context).size.width > 800
              ? 700
              : 500,
        ),
        child: Column(
          children: [
            // Header row
            _buildHeaderRow(),
            // Data rows
            for (int i = 0; i < rows.length; i++) _buildDataRow(i),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          for (int i = 0; i < columns.length; i++)
            Expanded(
              flex: i == 0 ? 2 : 1,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: i == highlightIndex
                    ? BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _kPrimary.withValues(alpha: 0.05),
                            _kSecondary.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        border: Border(
                          left: BorderSide(
                            color: _kPrimary.withValues(alpha: 0.3),
                            width: 2,
                          ),
                          right: BorderSide(
                            color: _kSecondary.withValues(alpha: 0.3),
                            width: 2,
                          ),
                          top: BorderSide(
                            color: _kPrimary.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        borderRadius: i == highlightIndex
                            ? const BorderRadius.vertical(
                                top: Radius.circular(12),
                              )
                            : null,
                      )
                    : null,
                child: Column(
                  children: [
                    if (i == highlightIndex && highlightBadge != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: _kBrandGradient,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          highlightBadge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            fontFamily: 'system-ui',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      columns[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: i == highlightIndex ? _kPrimary : _kTextPrimary,
                        fontFamily: 'system-ui',
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDataRow(int rowIndex) {
    final isEven = rowIndex.isEven;
    final row = rows[rowIndex];

    return _HoverableRow(
      baseColor: isEven ? Colors.white : const Color(0xFFFFFAF5),
      highlightIndex: highlightIndex,
      child: Row(
        children: [
          for (int i = 0; i < row.length; i++)
            Expanded(
              flex: i == 0 ? 2 : 1,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 12,
                ),
                decoration: i == highlightIndex
                    ? BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: _kPrimary.withValues(alpha: 0.3),
                            width: 2,
                          ),
                          right: BorderSide(
                            color: _kSecondary.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                      )
                    : null,
                child: row[i],
              ),
            ),
        ],
      ),
    );
  }
}

/// Internal hoverable row for the comparison table.
class _HoverableRow extends StatefulWidget {
  final Color baseColor;
  final int highlightIndex;
  final Widget child;

  const _HoverableRow({
    required this.baseColor,
    required this.highlightIndex,
    required this.child,
  });

  @override
  State<_HoverableRow> createState() => _HoverableRowState();
}

class _HoverableRowState extends State<_HoverableRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: _hovering
            ? _kPrimary.withValues(alpha: 0.04)
            : widget.baseColor,
        child: widget.child,
      ),
    );
  }
}

/// Green check icon for comparison tables.
class WebCheckIcon extends StatelessWidget {
  const WebCheckIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 22);
  }
}

/// Red cross icon for comparison tables.
class WebCrossIcon extends StatelessWidget {
  const WebCrossIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 22);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// StaggeredFadeIn
// ════════════════════════════════════════════════════════════════════════════

/// Wrapper that fades + slides children in with staggered delays.
///
/// Place this around a Column/Row/Wrap and provide the list of children.
/// Each child animates in sequence with [staggerDelay] between them.
class StaggeredFadeIn extends StatefulWidget {
  final List<Widget> children;

  /// Total animation duration for each child.
  final Duration duration;

  /// Delay between each child starting its animation.
  final Duration staggerDelay;

  /// Vertical offset for the slide-in (positive = slides up from below).
  final double slideOffset;

  /// Axis direction for the child layout.
  final Axis axis;

  /// Cross-axis alignment (only applies when axis is vertical).
  final CrossAxisAlignment crossAxisAlignment;

  /// Main-axis alignment.
  final MainAxisAlignment mainAxisAlignment;

  /// Spacing between children.
  final double spacing;

  const StaggeredFadeIn({
    super.key,
    required this.children,
    this.duration = const Duration(milliseconds: 400),
    this.staggerDelay = const Duration(milliseconds: 100),
    this.slideOffset = 20,
    this.axis = Axis.vertical,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.spacing = 0,
  });

  @override
  State<StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<StaggeredFadeIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    // Total duration = last child's start + individual duration
    final totalMs = widget.staggerDelay.inMilliseconds *
            (widget.children.length - 1) +
        widget.duration.inMilliseconds;

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs.clamp(1, 10000)),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = _controller.duration!.inMilliseconds;
    final itemDurationMs = widget.duration.inMilliseconds;
    final staggerMs = widget.staggerDelay.inMilliseconds;

    final animatedChildren = <Widget>[];

    for (int i = 0; i < widget.children.length; i++) {
      final startMs = staggerMs * i;
      final endMs = startMs + itemDurationMs;

      final begin = (startMs / totalMs).clamp(0.0, 1.0);
      final end = (endMs / totalMs).clamp(0.0, 1.0);

      final fadeAnimation = CurvedAnimation(
        parent: _controller,
        curve: Interval(begin, end, curve: Curves.easeOut),
      );

      final slideAnimation = CurvedAnimation(
        parent: _controller,
        curve: Interval(begin, end, curve: Curves.easeOutCubic),
      );

      if (i > 0 && widget.spacing > 0) {
        animatedChildren.add(
          widget.axis == Axis.vertical
              ? SizedBox(height: widget.spacing)
              : SizedBox(width: widget.spacing),
        );
      }

      animatedChildren.add(
        FadeTransition(
          opacity: fadeAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: widget.axis == Axis.vertical
                  ? Offset(0, widget.slideOffset / 100)
                  : Offset(widget.slideOffset / 100, 0),
              end: Offset.zero,
            ).animate(slideAnimation),
            child: widget.children[i],
          ),
        ),
      );
    }

    if (widget.axis == Axis.vertical) {
      return Column(
        crossAxisAlignment: widget.crossAxisAlignment,
        mainAxisAlignment: widget.mainAxisAlignment,
        mainAxisSize: MainAxisSize.min,
        children: animatedChildren,
      );
    }

    return Row(
      crossAxisAlignment: widget.axis == Axis.horizontal
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisAlignment: widget.mainAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: animatedChildren,
    );
  }
}
