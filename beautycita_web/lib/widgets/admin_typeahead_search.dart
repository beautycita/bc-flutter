import 'dart:async';

import 'package:beautycita_core/supabase.dart';
import 'package:beautycita_core/theme.dart';
import 'package:flutter/material.dart';

/// Reusable typeahead search field for admin panels.
///
/// After [minChars] characters, debounces [debounceMs]ms, then queries
/// [tableName] for [searchColumn] ILIKE matches. Shows up to [maxResults]
/// suggestions in a dropdown overlay. On selection, calls [onSelected].
/// Also calls [onChanged] on every keystroke for live filtering.
class AdminTypeaheadSearch extends StatefulWidget {
  const AdminTypeaheadSearch({
    super.key,
    required this.hintText,
    required this.tableName,
    required this.searchColumn,
    this.additionalColumns = const [],
    this.onSelected,
    this.onChanged,
    this.controller,
    this.minChars = 3,
    this.debounceMs = 300,
    this.maxResults = 8,
    this.statusFilter,
  });

  final String hintText;
  final String tableName;
  final String searchColumn;
  final List<String> additionalColumns;
  final void Function(Map<String, dynamic> item)? onSelected;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final int minChars;
  final int debounceMs;
  final int maxResults;
  final Map<String, dynamic>? statusFilter;

  @override
  State<AdminTypeaheadSearch> createState() => _AdminTypeaheadSearchState();
}

class _AdminTypeaheadSearchState extends State<AdminTypeaheadSearch> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  Timer? _debounce;
  List<Map<String, dynamic>> _suggestions = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 150), _removeOverlay);
    }
  }

  void _onTextChanged(String value) {
    widget.onChanged?.call(value);
    _debounce?.cancel();

    if (value.trim().length < widget.minChars) {
      _removeOverlay();
      setState(() => _suggestions = []);
      return;
    }

    _debounce = Timer(Duration(milliseconds: widget.debounceMs), () {
      _fetchSuggestions(value.trim());
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    if (!BCSupabase.isInitialized) return;
    setState(() => _loading = true);

    try {
      final cols = [widget.searchColumn, ...widget.additionalColumns].join(', ');
      final sanitized = query.replaceAll("'", "''");

      var q = BCSupabase.client
          .from(widget.tableName)
          .select(cols)
          .ilike(widget.searchColumn, '%$sanitized%');

      if (widget.statusFilter != null) {
        for (final entry in widget.statusFilter!.entries) {
          q = q.eq(entry.key, entry.value);
        }
      }

      final data = await q.limit(widget.maxResults);

      if (mounted) {
        _suggestions = (data as List).cast<Map<String, dynamic>>();
        _loading = false;
        if (_suggestions.isNotEmpty && _focusNode.hasFocus) {
          _showOverlay();
        } else {
          _removeOverlay();
        }
        setState(() {});
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = OverlayEntry(builder: (context) {
      final theme = Theme.of(context);
      return Positioned(
        width: _getFieldWidth(),
        child: CompositedTransformFollower(
          link: _layerLink,
          offset: const Offset(0, 42),
          showWhenUnlinked: false,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final item = _suggestions[index];
                  final mainText = item[widget.searchColumn]?.toString() ?? '';
                  final subParts = widget.additionalColumns
                      .map((c) => item[c]?.toString() ?? '')
                      .where((s) => s.isNotEmpty)
                      .toList();

                  return InkWell(
                    onTap: () {
                      _controller.text = mainText;
                      widget.onSelected?.call(item);
                      _removeOverlay();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mainText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subParts.isNotEmpty)
                            Text(
                              subParts.join(' · '),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    });
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  double _getFieldWidth() {
    final renderBox = context.findRenderObject() as RenderBox?;
    return renderBox?.size.width ?? 300;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: _onTextChanged,
        style: theme.textTheme.bodySmall,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurface.withValues(alpha: 0.4),
          ),
          prefixIcon: const Icon(Icons.search, size: 18),
          suffixIcon: _loading
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _controller.clear();
                        widget.onChanged?.call('');
                        _removeOverlay();
                        setState(() => _suggestions = []);
                      },
                    )
                  : null,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
            borderSide: BorderSide(color: colors.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
            borderSide: BorderSide(color: colors.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(BCSpacing.radiusXs),
            borderSide: BorderSide(color: colors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}
