import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../config/theme.dart';
import '../services/lightx_service.dart';

/// Tool metadata for each studio tab.
class _StudioTool {
  final String id;
  final IconData icon;
  final String label;
  final String description;
  final String defaultPrompt;

  const _StudioTool({
    required this.id,
    required this.icon,
    required this.label,
    required this.description,
    required this.defaultPrompt,
  });
}

const _tools = [
  _StudioTool(id: 'hair_color', icon: Icons.palette, label: 'Color', description: 'Prueba un nuevo color de cabello', defaultPrompt: 'Rubio platino'),
  _StudioTool(id: 'hairstyle', icon: Icons.content_cut, label: 'Peinado', description: 'Prueba un peinado diferente', defaultPrompt: 'Bob corto moderno'),
  _StudioTool(id: 'headshot', icon: Icons.camera_alt, label: 'Retrato', description: 'Foto profesional estilo headshot', defaultPrompt: 'Professional corporate headshot'),
  _StudioTool(id: 'avatar', icon: Icons.face, label: 'Avatar', description: 'Crea un avatar estilizado', defaultPrompt: 'Glamorous portrait style'),
  _StudioTool(id: 'face_swap', icon: Icons.swap_horiz, label: 'Cambio', description: 'Prueba un look completamente nuevo', defaultPrompt: 'Celebrity glam look'),
];

class VirtualStudioScreen extends ConsumerStatefulWidget {
  final int initialTab;

  const VirtualStudioScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<VirtualStudioScreen> createState() => _VirtualStudioScreenState();
}

class _VirtualStudioScreenState extends ConsumerState<VirtualStudioScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tools.length,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, _tools.length - 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0EB),
      appBar: AppBar(
        backgroundColor: BeautyCitaTheme.backgroundWhite,
        title: Text(
          'Estudio Virtual',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: BeautyCitaTheme.primaryRose,
          unselectedLabelColor: BeautyCitaTheme.textLight,
          indicatorColor: BeautyCitaTheme.primaryRose,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          tabs: _tools.map((t) => Tab(
            icon: Icon(t.icon, size: 20),
            text: t.label,
          )).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tools.map((tool) => _ToolView(tool: tool)).toList(),
      ),
    );
  }
}

/// Individual tool tab content: upload → prompt → process → result.
class _ToolView extends ConsumerStatefulWidget {
  final _StudioTool tool;

  const _ToolView({required this.tool});

  @override
  ConsumerState<_ToolView> createState() => _ToolViewState();
}

class _ToolViewState extends ConsumerState<_ToolView>
    with AutomaticKeepAliveClientMixin {
  final _promptController = TextEditingController();
  Uint8List? _imageBytes;
  String? _resultUrl;
  bool _isProcessing = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _promptController.text = widget.tool.defaultPrompt;
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _pickImage({ImageSource source = ImageSource.gallery}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.front,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _resultUrl = null;
      _error = null;
    });
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: BeautyCitaTheme.primaryRose),
                title: Text('Tomar selfie', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(source: ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: BeautyCitaTheme.primaryRose),
                title: Text('Elegir de galeria', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(source: ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _process() async {
    if (_imageBytes == null || _isProcessing) return;
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final service = LightXService();
      final url = await service.processTryOn(
        imageBytes: _imageBytes!,
        stylePrompt: prompt,
        tryOnTypeId: widget.tool.id,
      );
      if (mounted) {
        setState(() {
          _resultUrl = url;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isProcessing = false;
        });
      }
    }
  }

  void _reset() {
    setState(() {
      _imageBytes = null;
      _resultUrl = null;
      _error = null;
      _promptController.text = widget.tool.defaultPrompt;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Result state
    if (_resultUrl != null) {
      return _buildResult();
    }

    // Processing state
    if (_isProcessing) {
      return _buildProcessing();
    }

    // Empty / upload state
    return _buildUpload();
  }

  Widget _buildUpload() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Description
          Text(
            widget.tool.description,
            style: GoogleFonts.nunito(
              fontSize: 15,
              color: BeautyCitaTheme.textLight,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Upload area
          GestureDetector(
            onTap: _showImageSourcePicker,
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: _imageBytes != null
                      ? Border.all(color: BeautyCitaTheme.primaryRose, width: 2)
                      : null,
                ),
                child: _imageBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Stack(
                          children: [
                            Center(
                              child: Image.memory(_imageBytes!, fit: BoxFit.contain),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: _showImageSourcePicker,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.edit, color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : CustomPaint(
                        painter: _DashedBorderPainter(
                          color: BeautyCitaTheme.textLight.withValues(alpha: 0.3),
                          radius: 16,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo_rounded,
                                size: 48,
                                color: BeautyCitaTheme.primaryRose.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Sube tu foto o toma una selfie',
                                style: GoogleFonts.nunito(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: BeautyCitaTheme.textLight,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Toca para seleccionar',
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  color: BeautyCitaTheme.textLight.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Prompt field
          TextField(
            controller: _promptController,
            style: GoogleFonts.nunito(fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Describe el look',
              labelStyle: GoogleFonts.nunito(fontSize: 14),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: BeautyCitaTheme.dividerLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: BeautyCitaTheme.dividerLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: BeautyCitaTheme.primaryRose, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 20),

          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _error!,
                style: GoogleFonts.nunito(fontSize: 13, color: Colors.red.shade700),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Process button
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _imageBytes != null ? _process : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: BeautyCitaTheme.primaryRose,
                foregroundColor: Colors.white,
                disabledBackgroundColor: BeautyCitaTheme.dividerLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Procesar',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessing() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_imageBytes != null)
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(_imageBytes!, fit: BoxFit.cover),
              ),
            ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(
            color: BeautyCitaTheme.primaryRose,
          ),
          const SizedBox(height: 16),
          Text(
            'Procesando tu imagen...',
            style: GoogleFonts.nunito(
              fontSize: 16,
              color: BeautyCitaTheme.textLight,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Before / After
          Row(
            children: [
              // Before
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Antes',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: BeautyCitaTheme.textLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 3 / 4,
                        child: Image.memory(_imageBytes!, fit: BoxFit.contain),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // After
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Despues',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: BeautyCitaTheme.primaryRose,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 3 / 4,
                        child: Image.network(
                          _resultUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Container(
                            color: BeautyCitaTheme.surfaceCream,
                            child: const Center(
                              child: Icon(Icons.broken_image, size: 48),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Probar otro'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BeautyCitaTheme.primaryRose,
                    side: const BorderSide(color: BeautyCitaTheme.primaryRose),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dashed border painter for the upload area.
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(radius),
      ));

    const dashWidth = 8.0;
    const dashSpace = 5.0;
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(
          metric.extractPath(distance, end),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
