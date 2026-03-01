import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/config/theme_extension.dart';

enum BCToastType { success, error, warning, info }

class BCToastOverlay extends StatefulWidget {
  final BCToastType type;
  final String message;
  final String? technicalDetails;
  final String? screenName;
  final VoidCallback onDismiss;
  final Future<void> Function(String details)? onReport;

  const BCToastOverlay({
    super.key,
    required this.type,
    required this.message,
    this.technicalDetails,
    this.screenName,
    required this.onDismiss,
    this.onReport,
  });

  bool get canExpand =>
      (type == BCToastType.error || type == BCToastType.warning) &&
      technicalDetails != null &&
      technicalDetails!.isNotEmpty;

  @override
  State<BCToastOverlay> createState() => _BCToastOverlayState();
}

class _BCToastOverlayState extends State<BCToastOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  late final AnimationController _fadeController;
  Timer? _autoDismissTimer;
  bool _expanded = false;
  bool _isReporting = false;
  bool _reported = false;

  Duration get _autoDismissDuration {
    switch (widget.type) {
      case BCToastType.success:
      case BCToastType.info:
        return const Duration(milliseconds: 3500);
      case BCToastType.warning:
        return const Duration(seconds: 5);
      case BCToastType.error:
        return const Duration(seconds: 6);
    }
  }

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      value: 1.0,
    );

    _slideController.forward();
    _startAutoDismiss();
  }

  void _startAutoDismiss() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(_autoDismissDuration, _dismiss);
  }

  void _cancelAutoDismiss() {
    _autoDismissTimer?.cancel();
  }

  Future<void> _dismiss() async {
    _cancelAutoDismiss();
    await _fadeController.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Color _accentColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<BCThemeExtension>();
    switch (widget.type) {
      case BCToastType.error:
        return cs.error;
      case BCToastType.warning:
        return ext?.warningColor ?? Colors.orange.shade600;
      case BCToastType.success:
        return ext?.successColor ?? Colors.green.shade600;
      case BCToastType.info:
        return ext?.infoColor ?? Colors.blue.shade600;
    }
  }

  IconData _icon() {
    switch (widget.type) {
      case BCToastType.error:
        return Icons.error_outline_rounded;
      case BCToastType.warning:
        return Icons.warning_amber_rounded;
      case BCToastType.success:
        return Icons.check_circle_outline_rounded;
      case BCToastType.info:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor(context);
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<BCThemeExtension>();
    final textTheme = Theme.of(context).textTheme;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeController,
        child: GestureDetector(
          onVerticalDragUpdate: widget.canExpand
              ? (details) {
                  if (details.primaryDelta == null) return;
                  if (details.primaryDelta! > 3 && !_expanded) {
                    setState(() => _expanded = true);
                    HapticFeedback.mediumImpact();
                    _cancelAutoDismiss();
                  } else if (details.primaryDelta! < -3 && _expanded) {
                    setState(() => _expanded = false);
                    _startAutoDismiss();
                  }
                }
              : null,
          onTap: widget.canExpand && !_expanded
              ? () {
                  setState(() => _expanded = true);
                  HapticFeedback.mediumImpact();
                  _cancelAutoDismiss();
                }
              : null,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.97),
                borderRadius: BorderRadius.circular(AppConstants.radiusMD),
                border: Border(
                  left: BorderSide(color: accent, width: 4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Gold shimmer line at top
                  if (ext != null)
                    Container(
                      height: 1.5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: ext.goldGradientStops,
                          stops: ext.goldGradientPositions,
                        ),
                      ),
                    ),

                  // Main toast content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 0),
                    child: Row(
                      children: [
                        Icon(_icon(), color: accent, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.message,
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: _dismiss,
                          icon: Icon(Icons.close_rounded,
                              size: 18,
                              color: cs.onSurface.withValues(alpha: 0.4)),
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ],
                    ),
                  ),

                  // Drag handle indicator (error/warning only)
                  if (widget.canExpand && !_expanded)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 4),
                      child: Container(
                        width: 32,
                        height: 3,
                        decoration: BoxDecoration(
                          color: cs.onSurface.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    )
                  else if (!widget.canExpand)
                    const SizedBox(height: 12),

                  // Expanded detail panel
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOutCubic,
                    alignment: Alignment.topCenter,
                    child: _expanded
                        ? _buildExpandedPanel(context, accent)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedPanel(BuildContext context, Color accent) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final details = widget.technicalDetails ?? '';

    // Take first 8 lines max
    final lines = details.split('\n');
    final truncated =
        lines.take(8).join('\n') + (lines.length > 8 ? '\n...' : '');

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collapse handle
          Center(
            child: GestureDetector(
              onTap: () {
                setState(() => _expanded = false);
                _startAutoDismiss();
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),

          Text(
            'DETALLES TECNICOS',
            style: textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 6),

          // Technical details in dark box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(AppConstants.radiusSM),
            ),
            child: SelectableText(
              truncated,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.5,
                color: Color(0xFFCCCCCC),
              ),
            ),
          ),

          if (widget.screenName != null) ...[
            const SizedBox(height: 6),
            Text(
              'Pantalla: ${widget.screenName}',
              style: textTheme.labelSmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Report button
          SizedBox(
            width: double.infinity,
            child: _reported
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.08),
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusSM),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            size: 16, color: accent),
                        const SizedBox(width: 6),
                        Text(
                          'Reporte enviado',
                          style: textTheme.labelMedium?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: _isReporting ? null : _handleReport,
                    icon: _isReporting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.bug_report_rounded, size: 16),
                    label: Text(_isReporting ? 'Enviando...' : 'Reportar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusSM),
                      ),
                      textStyle: textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleReport() async {
    if (widget.onReport == null || _isReporting || _reported) return;
    setState(() => _isReporting = true);
    try {
      await widget.onReport!(widget.technicalDetails ?? widget.message);
      if (mounted) {
        setState(() {
          _isReporting = false;
          _reported = true;
        });
        HapticFeedback.mediumImpact();
        // Auto-dismiss after report sent
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _dismiss();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isReporting = false);
    }
  }
}
