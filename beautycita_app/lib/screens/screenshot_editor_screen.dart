import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:google_fonts/google_fonts.dart';
import '../services/screenshot_sender_service.dart';
import '../services/toast_service.dart';

// ─── Data Model ──────────────────────────────────────────────────

enum AnnotationTool { pen, arrow, circle, rectangle, text }

class Annotation {
  final AnnotationTool tool;
  Offset start;
  Offset end;
  final Color color;
  final double strokeWidth;
  // For pen tool — freehand path points
  final List<Offset>? points;
  // For text tool
  final String? text;

  Annotation({
    required this.tool,
    required this.start,
    required this.end,
    this.color = Colors.red,
    this.strokeWidth = 3.0,
    this.points,
    this.text,
  });

  Annotation copyWith({Offset? start, Offset? end, List<Offset>? points}) {
    return Annotation(
      tool: tool,
      start: start ?? this.start,
      end: end ?? this.end,
      color: color,
      strokeWidth: strokeWidth,
      points: points ?? this.points,
      text: text,
    );
  }
}

enum _DragMode { moveText, moveArrow, rotateArrow, moveShape }

// ─── Editor Screen ───────────────────────────────────────────────

class ScreenshotEditorScreen extends StatefulWidget {
  final Uint8List screenshotBytes;

  const ScreenshotEditorScreen({super.key, required this.screenshotBytes});

  @override
  State<ScreenshotEditorScreen> createState() =>
      _ScreenshotEditorScreenState();
}

class _ScreenshotEditorScreenState extends State<ScreenshotEditorScreen>
    with SingleTickerProviderStateMixin {
  final List<Annotation> _annotations = [];
  Annotation? _currentDrag;
  AnnotationTool? _activeTool;
  Color _activeColor = Colors.red;
  double _activeStrokeWidth = 3.0;
  bool _isSending = false;

  // Freehand pen tracking
  List<Offset>? _currentPenPoints;

  // Annotation dragging (when no tool selected)
  int? _draggingIndex;
  _DragMode? _dragMode;
  Offset _dragStartOffset = Offset.zero;

  // For tracking image dimensions in the display
  final TransformationController _transformController =
      TransformationController();
  Size _imageDisplaySize = Size.zero;
  Size _imageNativeSize = Size.zero;
  ui.Image? _decodedImage;

  // Toolbar animation
  late final AnimationController _toolbarAnim;

  // Color presets
  static const _colorPresets = [
    Colors.red,
    Color(0xFFFFD600), // yellow
    Color(0xFF2979FF), // blue
    Colors.white,
    Color(0xFF00E676), // green
  ];

  // Stroke width presets
  static const _strokePresets = [2.0, 4.0, 7.0];
  static const _strokeLabels = ['Fino', 'Med', 'Grueso'];

  @override
  void initState() {
    super.initState();
    _toolbarAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    _decodeImage();
  }

  Future<void> _decodeImage() async {
    final codec = await ui.instantiateImageCodec(widget.screenshotBytes);
    final frame = await codec.getNextFrame();
    setState(() {
      _decodedImage = frame.image;
      _imageNativeSize = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
    });
  }

  @override
  void dispose() {
    _toolbarAnim.dispose();
    _transformController.dispose();
    _decodedImage?.dispose();
    super.dispose();
  }

  // ─── Drawing Interaction ─────────────────────────────────────

  static const _hitThreshold = 25.0;

  ({int index, _DragMode mode})? _hitTest(Offset pos) {
    for (int i = _annotations.length - 1; i >= 0; i--) {
      final a = _annotations[i];
      switch (a.tool) {
        case AnnotationTool.text:
          final fontSize = (a.strokeWidth * 6).clamp(14.0, 42.0);
          final estimatedWidth = a.text!.length * fontSize * 0.6;
          final rect = Rect.fromLTWH(
            a.start.dx - 10, a.start.dy - 10,
            estimatedWidth + 20, fontSize + 20,
          );
          if (rect.contains(pos)) {
            return (index: i, mode: _DragMode.moveText);
          }
        case AnnotationTool.arrow:
          final dist = _distToSegment(pos, a.start, a.end);
          if (dist <= _hitThreshold) {
            // Head half → move, tail half → rotate
            final distToHead = (pos - a.end).distance;
            final distToTail = (pos - a.start).distance;
            final mode = distToHead <= distToTail
                ? _DragMode.moveArrow
                : _DragMode.rotateArrow;
            return (index: i, mode: mode);
          }
        case AnnotationTool.circle:
          final center = Offset(
            (a.start.dx + a.end.dx) / 2,
            (a.start.dy + a.end.dy) / 2,
          );
          final radius = (a.start - a.end).distance / 2;
          final distFromCenter = (pos - center).distance;
          // Hit if near circumference OR inside circle
          if ((distFromCenter - radius).abs() <= _hitThreshold ||
              distFromCenter <= radius) {
            return (index: i, mode: _DragMode.moveShape);
          }
        case AnnotationTool.rectangle:
          final rect = Rect.fromPoints(a.start, a.end)
              .inflate(_hitThreshold / 2);
          if (rect.contains(pos)) {
            return (index: i, mode: _DragMode.moveShape);
          }
        case AnnotationTool.pen:
          break; // Pen strokes not draggable
      }
    }
    return null;
  }

  double _distToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final ap = p - a;
    final lenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lenSq < 0.001) return (p - a).distance;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / lenSq).clamp(0.0, 1.0);
    final closest = a + ab * t;
    return (p - closest).distance;
  }

  void _onPanStart(DragStartDetails details) {
    if (_activeTool == null) return;
    final pos = _toImageCoords(details.localPosition);

    if (_activeTool == AnnotationTool.pen) {
      _currentPenPoints = [pos];
      setState(() {
        _currentDrag = Annotation(
          tool: AnnotationTool.pen,
          start: pos,
          end: pos,
          color: _activeColor,
          strokeWidth: _activeStrokeWidth,
          points: _currentPenPoints,
        );
      });
    } else if (_activeTool == AnnotationTool.arrow) {
      final tailOffset = Offset.fromDirection(-pi / 4, 80);
      setState(() {
        _currentDrag = Annotation(
          tool: AnnotationTool.arrow,
          start: pos + tailOffset,
          end: pos,
          color: _activeColor,
          strokeWidth: _activeStrokeWidth,
        );
      });
    } else if (_activeTool == AnnotationTool.text) {
      // Text tool: show dialog at tap position
      _showTextDialog(pos);
    } else {
      setState(() {
        _currentDrag = Annotation(
          tool: _activeTool!,
          start: pos,
          end: pos,
          color: _activeColor,
          strokeWidth: _activeStrokeWidth,
        );
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_currentDrag == null) return;
    final pos = _toImageCoords(details.localPosition);

    setState(() {
      if (_currentDrag!.tool == AnnotationTool.pen) {
        _currentPenPoints?.add(pos);
        _currentDrag = _currentDrag!.copyWith(end: pos);
      } else if (_currentDrag!.tool == AnnotationTool.arrow) {
        _currentDrag = _currentDrag!.copyWith(start: pos);
      } else {
        _currentDrag = _currentDrag!.copyWith(end: pos);
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_currentDrag == null) return;
    setState(() {
      if (_currentDrag!.tool == AnnotationTool.pen && _currentPenPoints != null) {
        _annotations.add(Annotation(
          tool: AnnotationTool.pen,
          start: _currentPenPoints!.first,
          end: _currentPenPoints!.last,
          color: _currentDrag!.color,
          strokeWidth: _currentDrag!.strokeWidth,
          points: List.from(_currentPenPoints!),
        ));
      } else {
        _annotations.add(_currentDrag!);
      }
      _currentDrag = null;
      _currentPenPoints = null;
    });
    HapticFeedback.selectionClick();
  }

  void _showTextDialog(Offset position) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Agregar texto',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 50,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            hintText: 'Escribe aqui...',
            hintStyle: TextStyle(color: Colors.black.withValues(alpha: 0.4)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _activeColor),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _activeColor, width: 2),
            ),
            counterStyle: const TextStyle(color: Colors.black38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar',
                style: TextStyle(color: Colors.black.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text('Agregar', style: TextStyle(color: _activeColor)),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty && mounted) {
      setState(() {
        _annotations.add(Annotation(
          tool: AnnotationTool.text,
          start: position,
          end: position,
          color: _activeColor,
          strokeWidth: _activeStrokeWidth,
          text: result.trim(),
        ));
      });
      HapticFeedback.selectionClick();
    }
  }

  void _undo() {
    if (_annotations.isEmpty) return;
    setState(() {
      _annotations.removeLast();
    });
    HapticFeedback.lightImpact();
  }

  Offset _toImageCoords(Offset localPosition) {
    final matrix = _transformController.value;
    final inverted = Matrix4.inverted(matrix);
    final vector = inverted.transform3(
      Vector3(localPosition.dx, localPosition.dy, 0),
    );
    return Offset(vector.x, vector.y);
  }

  // ─── Close with confirmation ───────────────────────────────────

  Future<bool> _onWillPop() async {
    if (_annotations.isEmpty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Descartar cambios?',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Tienes ${_annotations.length} anotacion${_annotations.length == 1 ? '' : 'es'} sin enviar.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Seguir editando',
                style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Descartar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ─── Compositing & Sending ───────────────────────────────────

  Future<Uint8List> _renderAnnotatedScreenshot() async {
    final image = _decodedImage!;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    );

    canvas.drawImage(image, Offset.zero, Paint());

    final scaleX = _imageDisplaySize.width > 0
        ? image.width / _imageDisplaySize.width
        : 1.0;
    final scaleY = _imageDisplaySize.height > 0
        ? image.height / _imageDisplaySize.height
        : 1.0;
    canvas.scale(scaleX, scaleY);

    final painter = _AnnotationPainter(
      annotations: _annotations,
      currentDrag: null,
    );
    painter.paint(canvas, _imageDisplaySize);

    final picture = recorder.endRecording();
    final rendered = await picture.toImage(image.width, image.height);
    final byteData = await rendered.toByteData(format: ui.ImageByteFormat.png);
    rendered.dispose();
    return byteData!.buffer.asUint8List();
  }

  Future<void> _sendScreenshot() async {
    if (_isSending || _decodedImage == null) return;
    setState(() => _isSending = true);

    try {
      final annotatedBytes = await _renderAnnotatedScreenshot();
      final sent = await ScreenshotSenderService.sendToBC(annotatedBytes);

      if (mounted) {
        if (sent) {
          ToastService.showSuccess('Screenshot enviado');
          Navigator.of(context).pop();
        } else {
          ToastService.showError('No se pudo enviar');
        }
      }
    } catch (e) {
      if (mounted) {
        ToastService.showError('Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ─── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: _annotations.isEmpty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
            // ── Top bar ──
            _buildTopBar(),
            // ── Canvas area ──
            Expanded(child: _buildCanvas()),
            // ── Toolbar ──
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: _toolbarAnim,
                curve: Curves.easeOutCubic,
              )),
              child: _buildToolbar(bottomPad),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            // Close
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () async {
                if (_annotations.isEmpty) {
                  Navigator.of(context).pop();
                } else {
                  final shouldPop = await _onWillPop();
                  if (shouldPop && mounted) Navigator.of(context).pop();
                }
              },
            ),
            const Spacer(),
            // Title
            Text(
              'Editar',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            // Send button
            if (_isSending)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              )
            else
              _SendButton(
                enabled: _decodedImage != null,
                onTap: _sendScreenshot,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    if (_decodedImage == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final aspect = _imageNativeSize.width / _imageNativeSize.height;
        final containerAspect = constraints.maxWidth / constraints.maxHeight;

        double displayW, displayH;
        if (aspect > containerAspect) {
          displayW = constraints.maxWidth;
          displayH = displayW / aspect;
        } else {
          displayH = constraints.maxHeight;
          displayW = displayH * aspect;
        }
        _imageDisplaySize = Size(displayW, displayH);

        return Center(
          child: Listener(
            onPointerDown: (e) {
              if (_activeTool != null) return;
              final pos = _toImageCoords(e.localPosition);
              final hit = _hitTest(pos);
              if (hit != null) {
                setState(() {
                  _draggingIndex = hit.index;
                  _dragMode = hit.mode;
                  if (hit.mode == _DragMode.rotateArrow) {
                    // No offset — tail follows pointer directly
                    _dragStartOffset = Offset.zero;
                  } else {
                    _dragStartOffset =
                        pos - _annotations[hit.index].start;
                  }
                });
              }
            },
            onPointerMove: (e) {
              if (_draggingIndex == null) return;
              final pos = _toImageCoords(e.localPosition);
              setState(() {
                final a = _annotations[_draggingIndex!];
                switch (_dragMode!) {
                  case _DragMode.moveText:
                    _annotations[_draggingIndex!] = a.copyWith(
                      start: pos - _dragStartOffset,
                      end: pos - _dragStartOffset,
                    );
                  case _DragMode.moveArrow:
                    final delta =
                        (pos - _dragStartOffset) - a.start;
                    _annotations[_draggingIndex!] = a.copyWith(
                      start: a.start + delta,
                      end: a.end + delta,
                    );
                  case _DragMode.rotateArrow:
                    // Head stays fixed, tail follows pointer
                    _annotations[_draggingIndex!] =
                        a.copyWith(start: pos);
                  case _DragMode.moveShape:
                    final delta =
                        (pos - _dragStartOffset) - a.start;
                    _annotations[_draggingIndex!] = a.copyWith(
                      start: a.start + delta,
                      end: a.end + delta,
                    );
                }
              });
            },
            onPointerUp: (e) {
              if (_draggingIndex == null) return;
              setState(() {
                _draggingIndex = null;
                _dragMode = null;
              });
              HapticFeedback.selectionClick();
            },
            child: InteractiveViewer(
              transformationController: _transformController,
              panEnabled: _activeTool == null && _draggingIndex == null,
              scaleEnabled: _draggingIndex == null,
              minScale: 1.0,
              maxScale: 5.0,
              child: SizedBox(
                width: displayW,
                height: displayH,
                child: GestureDetector(
                  onPanStart:
                      _activeTool != null ? _onPanStart : null,
                  onPanUpdate:
                      _activeTool != null ? _onPanUpdate : null,
                  onPanEnd:
                      _activeTool != null ? _onPanEnd : null,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.memory(
                          widget.screenshotBytes,
                          fit: BoxFit.contain,
                        ),
                      ),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _AnnotationPainter(
                            annotations: _annotations,
                            currentDrag: _currentDrag,
                            draggingIndex: _draggingIndex,
                            dragMode: _dragMode,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildToolbar(double bottomPad) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(8, 14, 8, 10 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle indicator
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Tool buttons row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ToolButton(
                icon: Icons.draw_rounded,
                label: 'Dibujar',
                isActive: _activeTool == AnnotationTool.pen,
                activeColor: _activeColor,
                onTap: () => _selectTool(AnnotationTool.pen),
              ),
              _ToolButton(
                icon: Icons.arrow_forward_rounded,
                label: 'Flecha',
                isActive: _activeTool == AnnotationTool.arrow,
                activeColor: _activeColor,
                onTap: () => _selectTool(AnnotationTool.arrow),
              ),
              _ToolButton(
                icon: Icons.circle_outlined,
                label: 'Circulo',
                isActive: _activeTool == AnnotationTool.circle,
                activeColor: _activeColor,
                onTap: () => _selectTool(AnnotationTool.circle),
              ),
              _ToolButton(
                icon: Icons.rectangle_outlined,
                label: 'Rect',
                isActive: _activeTool == AnnotationTool.rectangle,
                activeColor: _activeColor,
                onTap: () => _selectTool(AnnotationTool.rectangle),
              ),
              _ToolButton(
                icon: Icons.text_fields_rounded,
                label: 'Texto',
                isActive: _activeTool == AnnotationTool.text,
                activeColor: _activeColor,
                onTap: () => _selectTool(AnnotationTool.text),
              ),
              _ToolButton(
                icon: Icons.undo_rounded,
                label: 'Deshacer',
                isActive: false,
                onTap: _annotations.isNotEmpty ? _undo : null,
                enabled: _annotations.isNotEmpty,
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Stroke width + color row
          Row(
            children: [
              // Stroke width chips
              ...List.generate(_strokePresets.length, (i) {
                final isActive = _activeStrokeWidth == _strokePresets[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _activeStrokeWidth = _strokePresets[i]);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isActive ? Colors.white38 : Colors.white12,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 16,
                            height: _strokePresets[i],
                            decoration: BoxDecoration(
                              color: isActive ? _activeColor : Colors.white38,
                              borderRadius: BorderRadius.circular(
                                  _strokePresets[i] / 2),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _strokeLabels[i],
                            style: GoogleFonts.nunito(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isActive ? Colors.white : Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const Spacer(),
              // Color presets
              ..._colorPresets.map((color) {
                final isSelected = _activeColor == color;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _activeColor = color);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: isSelected ? 32 : 24,
                    height: isSelected ? 32 : 24,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.white24,
                        width: isSelected ? 2.5 : 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  void _selectTool(AnnotationTool tool) {
    HapticFeedback.selectionClick();
    setState(() {
      _activeTool = _activeTool == tool ? null : tool;
    });
  }
}

// ─── Send Button ──────────────────────────────────────────────────

class _SendButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _SendButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: [Color(0xFFE91E63), Color(0xFFC2185B)],
                )
              : null,
          color: enabled ? null : Colors.white12,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.send_rounded,
              size: 16,
              color: enabled ? Colors.white : Colors.white38,
            ),
            const SizedBox(width: 6),
            Text(
              'Enviar',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: enabled ? Colors.white : Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tool Button ─────────────────────────────────────────────────

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;
  final bool enabled;
  final Color? activeColor;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.isActive,
    this.onTap,
    this.enabled = true,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isActive ? (activeColor ?? Colors.white) : null;
    final color = !enabled
        ? Colors.white24
        : isActive
            ? Colors.white
            : Colors.white54;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? (effectiveColor ?? Colors.white).withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isActive
              ? Border.all(
                  color: (effectiveColor ?? Colors.white)
                      .withValues(alpha: 0.3),
                )
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Annotation Painter ──────────────────────────────────────────

class _AnnotationPainter extends CustomPainter {
  final List<Annotation> annotations;
  final Annotation? currentDrag;
  final int? draggingIndex;
  final _DragMode? dragMode;

  _AnnotationPainter({
    required this.annotations,
    this.currentDrag,
    this.draggingIndex,
    this.dragMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < annotations.length; i++) {
      _drawAnnotation(canvas, annotations[i]);
      // Show pivot dot at arrowhead when rotating
      if (i == draggingIndex &&
          dragMode == _DragMode.rotateArrow &&
          annotations[i].tool == AnnotationTool.arrow) {
        final pivotPaint = Paint()
          ..color = annotations[i].color.withValues(alpha: 0.7)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(annotations[i].end, 6.0, pivotPaint);
        final ringPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(annotations[i].end, 6.0, ringPaint);
      }
    }
    if (currentDrag != null) {
      _drawAnnotation(canvas, currentDrag!);
    }
  }

  void _drawAnnotation(Canvas canvas, Annotation a) {
    final paint = Paint()
      ..color = a.color
      ..strokeWidth = a.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (a.tool) {
      case AnnotationTool.pen:
        _drawFreehand(canvas, a, paint);
      case AnnotationTool.arrow:
        _drawArrow(canvas, a.start, a.end, paint);
      case AnnotationTool.circle:
        final center = Offset(
          (a.start.dx + a.end.dx) / 2,
          (a.start.dy + a.end.dy) / 2,
        );
        final radius = (a.start - a.end).distance / 2;
        if (radius > 1) {
          canvas.drawCircle(center, radius, paint);
        }
      case AnnotationTool.rectangle:
        canvas.drawRect(Rect.fromPoints(a.start, a.end), paint);
      case AnnotationTool.text:
        _drawText(canvas, a);
    }
  }

  void _drawFreehand(Canvas canvas, Annotation a, Paint paint) {
    final pts = a.points;
    if (pts == null || pts.length < 2) return;

    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length; i++) {
      // Smooth with quadratic bezier using midpoints
      if (i < pts.length - 1) {
        final mid = Offset(
          (pts[i].dx + pts[i + 1].dx) / 2,
          (pts[i].dy + pts[i + 1].dy) / 2,
        );
        path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
      } else {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  void _drawArrow(Canvas canvas, Offset tail, Offset head, Paint paint) {
    canvas.drawLine(tail, head, paint);

    final direction = (head - tail).direction;
    const arrowLen = 20.0;
    const arrowAngle = 0.5;

    final p1 = head - Offset.fromDirection(direction - arrowAngle, arrowLen);
    final p2 = head - Offset.fromDirection(direction + arrowAngle, arrowLen);

    // Filled arrowhead
    final arrowPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;
    final arrowPath = Path()
      ..moveTo(head.dx, head.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    canvas.drawPath(arrowPath, arrowPaint);
  }

  void _drawText(Canvas canvas, Annotation a) {
    if (a.text == null || a.text!.isEmpty) return;

    final fontSize = (a.strokeWidth * 6).clamp(14.0, 42.0);

    final textPainter = TextPainter(
      text: TextSpan(
        text: a.text,
        style: TextStyle(
          color: a.color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 4,
              offset: const Offset(1, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, a.start);
  }

  @override
  bool shouldRepaint(_AnnotationPainter oldDelegate) {
    return oldDelegate.annotations != annotations ||
        oldDelegate.currentDrag != currentDrag ||
        oldDelegate.draggingIndex != draggingIndex ||
        oldDelegate.dragMode != dragMode;
  }
}
