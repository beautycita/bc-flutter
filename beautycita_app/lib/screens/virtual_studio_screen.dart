import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:beautycita/services/toast_service.dart';
import '../services/lightx_service.dart';
import '../services/media_service.dart';

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
  _StudioTool(id: 'face_swap', icon: Icons.swap_horiz, label: 'Cambio', description: 'Tu cara sobre una foto de referencia', defaultPrompt: ''),
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
    final primary = Theme.of(context).colorScheme.primary;
    final onSurfaceLight = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
          labelColor: primary,
          unselectedLabelColor: onSurfaceLight,
          indicatorColor: primary,
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
        children: _tools.map((tool) =>
          tool.id == 'face_swap'
            ? _FaceSwapView(tool: tool)
            : _ToolView(tool: tool),
        ).toList(),
      ),
    );
  }
}

/// Individual tool tab content: upload -> prompt -> process -> result.
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
    final primary = Theme.of(context).colorScheme.primary;
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
                leading: Icon(Icons.camera_alt, color: primary),
                title: Text('Tomar selfie', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(source: ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: primary),
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
        // Auto-save to gallery and user_media
        _autoSave(url, widget.tool.id, prompt);
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

  void _autoSave(String resultUrl, String toolType, String stylePrompt) async {
    try {
      final mediaService = MediaService();
      final saved = await mediaService.saveLightXResult(
        resultUrl: resultUrl,
        toolType: toolType,
        stylePrompt: stylePrompt,
      );
      if (saved != null) {
        ToastService.showSuccess('Guardado automaticamente');
      } else {
        ToastService.showWarning('No se pudo guardar (inicia sesion)');
      }
    } catch (e, stack) {
      debugPrint('Auto-save error: $e');
      ToastService.showErrorWithDetails(ToastService.friendlyError(e), e, stack);
    }
  }

  void _saveToGallery() async {
    if (_resultUrl == null) return;
    try {
      final mediaService = MediaService();
      final success = await mediaService.saveUrlToGallery(_resultUrl!);
      if (success) {
        ToastService.showSuccess('Guardado en galeria');
      } else {
        ToastService.showError('Error al guardar');
      }
    } catch (e) {
      debugPrint('Save to gallery error: $e');
    }
  }

  void _shareResult() async {
    if (_resultUrl == null) return;
    try {
      final mediaService = MediaService();
      await mediaService.shareImage(_resultUrl!, text: 'Mi look en BeautyCita');
    } catch (e) {
      debugPrint('Share error: $e');
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
    final primary = Theme.of(context).colorScheme.primary;
    final onSurfaceLight = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    final dividerColor = Theme.of(context).dividerColor;

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
              color: onSurfaceLight,
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
                      ? Border.all(color: primary, width: 2)
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
                          color: onSurfaceLight.withValues(alpha: 0.3),
                          radius: 16,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo_rounded,
                                size: 48,
                                color: primary.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Sube tu foto o toma una selfie',
                                style: GoogleFonts.nunito(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: onSurfaceLight,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Toca para seleccionar',
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  color: onSurfaceLight.withValues(alpha: 0.6),
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
                borderSide: BorderSide(color: dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primary, width: 2),
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
                backgroundColor: primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: dividerColor,
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
    final primary = Theme.of(context).colorScheme.primary;
    final onSurfaceLight = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

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
          CircularProgressIndicator(
            color: primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Procesando tu imagen...',
            style: GoogleFonts.nunito(
              fontSize: 16,
              color: onSurfaceLight,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final primary = Theme.of(context).colorScheme.primary;
    final onSurfaceLight = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    final surface = Theme.of(context).colorScheme.surface;

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
                        color: onSurfaceLight,
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
                        color: primary,
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
                            color: surface,
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

          // Actions row 1: Save & Share
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saveToGallery,
                  icon: const Icon(Icons.download, size: 20),
                  label: Text('Guardar', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareResult,
                  icon: const Icon(Icons.share, size: 20),
                  label: Text('Compartir', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primary,
                    side: BorderSide(color: primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Actions row 2: Try another
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh, size: 20),
                  label: Text('Probar otro', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: onSurfaceLight,
                    side: BorderSide(color: onSurfaceLight.withValues(alpha: 0.4)),
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

/// Hairstyle sample: preview shown to user + hair-only template sent to API.
class _HairstyleSample {
  final String id;
  final String label;
  final String previewUrl;    // Full model photo (shown in UI)
  final String templateUrl;   // Hair-only PNG (sent to LightX)

  const _HairstyleSample({
    required this.id,
    required this.label,
    required this.previewUrl,
    required this.templateUrl,
  });
}

const _r2 = 'https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/hairstyles';

const _hairstyleSamples = [
  _HairstyleSample(id: 'rubioOndulado', label: 'Rubio Ondulado', previewUrl: '$_r2/rubioOndulado.png', templateUrl: '$_r2/rubioOndulado.png'),
  _HairstyleSample(id: 'balayageLargo', label: 'Balayage Largo', previewUrl: '$_r2/balayageLargo.png', templateUrl: '$_r2/balayageLargo.png'),
  _HairstyleSample(id: 'bobOndulado', label: 'Bob Ondulado', previewUrl: '$_r2/bobOndulado.png', templateUrl: '$_r2/bobOndulado.png'),
  _HairstyleSample(id: 'lacioLargo', label: 'Lacio Largo', previewUrl: '$_r2/lacioLargo.png', templateUrl: '$_r2/lacioLargo.png'),
  _HairstyleSample(id: 'pixieElegante', label: 'Pixie Elegante', previewUrl: '$_r2/pixieElegante.png', templateUrl: '$_r2/pixieElegante.png'),
  _HairstyleSample(id: 'rizosMedianos', label: 'Rizos Medianos', previewUrl: '$_r2/rizosMedianos.png', templateUrl: '$_r2/rizosMedianos.png'),
];

/// Look Swap view: selfie upload -> pick hairstyle from samples or upload custom -> process.
class _FaceSwapView extends ConsumerStatefulWidget {
  final _StudioTool tool;

  const _FaceSwapView({required this.tool});

  @override
  ConsumerState<_FaceSwapView> createState() => _FaceSwapViewState();
}

class _FaceSwapViewState extends ConsumerState<_FaceSwapView>
    with AutomaticKeepAliveClientMixin {
  Uint8List? _selfieBytes;
  _HairstyleSample? _selectedSample;
  Uint8List? _customReferenceBytes; // If user uploads their own
  String? _resultUrl;
  bool _isProcessing = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  Future<void> _pickSelfie({ImageSource source = ImageSource.gallery}) async {
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
      _selfieBytes = bytes;
      _resultUrl = null;
      _error = null;
    });
  }

  void _showSelfiePicker() {
    final primary = Theme.of(context).colorScheme.primary;
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
                leading: Icon(Icons.camera_alt, color: primary),
                title: Text('Tomar selfie', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickSelfie(source: ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: primary),
                title: Text('Elegir de galeria', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickSelfie(source: ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickCustomReference() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 85);
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _customReferenceBytes = bytes;
      _selectedSample = null;
      _resultUrl = null;
      _error = null;
    });
  }

  void _selectSample(_HairstyleSample sample) {
    setState(() {
      _selectedSample = sample;
      _customReferenceBytes = null;
      _resultUrl = null;
      _error = null;
    });
  }

  bool get _canProcess =>
      _selfieBytes != null && (_selectedSample != null || _customReferenceBytes != null);

  Future<void> _process() async {
    if (!_canProcess || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final service = LightXService();
      Uint8List referenceBytes;

      if (_selectedSample != null) {
        final response = await http.get(Uri.parse(_selectedSample!.templateUrl));
        referenceBytes = response.bodyBytes;
      } else {
        referenceBytes = _customReferenceBytes!;
      }

      // imageUrl = user's photo (base), modelReferenceUrl = hairstyle reference
      final url = await service.processTryOn(
        imageBytes: _selfieBytes!,
        stylePrompt: '',
        tryOnTypeId: 'face_swap',
        targetImageBytes: referenceBytes,
      );
      if (mounted) {
        setState(() {
          _resultUrl = url;
          _isProcessing = false;
        });
        _autoSave(url);
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

  void _autoSave(String resultUrl) async {
    try {
      final mediaService = MediaService();
      final saved = await mediaService.saveLightXResult(
        resultUrl: resultUrl,
        toolType: 'face_swap',
        stylePrompt: _selectedSample?.label ?? 'Custom look swap',
      );
      if (saved != null) {
        ToastService.showSuccess('Guardado automaticamente');
      } else {
        ToastService.showWarning('No se pudo guardar (inicia sesion)');
      }
    } catch (e) {
      debugPrint('Auto-save error: $e');
    }
  }

  void _saveToGallery() async {
    if (_resultUrl == null) return;
    try {
      final mediaService = MediaService();
      final success = await mediaService.saveUrlToGallery(_resultUrl!);
      if (success) {
        ToastService.showSuccess('Guardado en galeria');
      } else {
        ToastService.showError('Error al guardar');
      }
    } catch (e) {
      debugPrint('Save to gallery error: $e');
    }
  }

  void _shareResult() async {
    if (_resultUrl == null) return;
    try {
      final mediaService = MediaService();
      await mediaService.shareImage(_resultUrl!, text: 'Mi look en BeautyCita');
    } catch (e) {
      debugPrint('Share error: $e');
    }
  }

  void _reset() {
    setState(() {
      _selfieBytes = null;
      _selectedSample = null;
      _customReferenceBytes = null;
      _resultUrl = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_resultUrl != null) return _buildResult();
    if (_isProcessing) return _buildProcessing();
    return _buildUpload();
  }

  Widget _buildUpload() {
    final primary = Theme.of(context).colorScheme.primary;
    final onSurfaceLight = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surface = Theme.of(context).colorScheme.surface;
    final dividerColor = Theme.of(context).dividerColor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sube tu foto y elige un peinado para ver como te queda',
            style: GoogleFonts.nunito(fontSize: 15, color: onSurfaceLight),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Step 1: Selfie
          Text(
            '1. Tu foto',
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _showSelfiePicker,
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: _selfieBytes != null
                    ? Border.all(color: primary, width: 2)
                    : null,
              ),
              child: _selfieBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Stack(
                        children: [
                          Center(child: Image.memory(_selfieBytes!, fit: BoxFit.contain, height: 156)),
                          Positioned(
                            top: 8, right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.edit, color: Colors.white, size: 16),
                            ),
                          ),
                        ],
                      ),
                    )
                  : CustomPaint(
                      painter: _DashedBorderPainter(
                        color: onSurfaceLight.withValues(alpha: 0.3),
                        radius: 16,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.face, size: 40, color: primary.withValues(alpha: 0.5)),
                            const SizedBox(height: 8),
                            Text('Tomar selfie o elegir foto', style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: onSurfaceLight)),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),

          // Step 2: Choose hairstyle
          Text(
            '2. Elige un peinado',
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          // Sample hairstyles grid
          SizedBox(
            height: 130,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // "Upload custom" option -- first
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: _pickCustomReference,
                    child: Container(
                      width: 90,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _customReferenceBytes != null
                              ? primary
                              : dividerColor,
                          width: _customReferenceBytes != null ? 3 : 1,
                        ),
                      ),
                      child: _customReferenceBytes != null
                          ? Column(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                                    child: Image.memory(_customReferenceBytes!, fit: BoxFit.cover, width: double.infinity),
                                  ),
                                ),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: primary,
                                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
                                  ),
                                  child: Text(
                                    'Tu foto',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                ),
                              ],
                            )
                          : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_outlined, size: 32, color: primary.withValues(alpha: 0.5)),
                                  const SizedBox(height: 4),
                                  Text('Subir\nreferencia', textAlign: TextAlign.center, style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w600, color: onSurfaceLight)),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
                // Samples
                ..._hairstyleSamples.map((sample) => Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () => _selectSample(sample),
                    child: Container(
                      width: 90,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedSample?.id == sample.id
                              ? primary
                              : dividerColor,
                          width: _selectedSample?.id == sample.id ? 3 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                              child: Image.network(
                                sample.previewUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.broken_image, size: 24),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                            decoration: BoxDecoration(
                              color: _selectedSample?.id == sample.id
                                  ? primary
                                  : surface,
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
                            ),
                            child: Text(
                              sample.label,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.nunito(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _selectedSample?.id == sample.id ? Colors.white : onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )),
              ],
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
              onPressed: _canProcess ? _process : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: dividerColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Procesar',
                style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessing() {
    final primary = Theme.of(context).colorScheme.primary;
    final onSurfaceLight = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_selfieBytes != null)
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
              child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(_selfieBytes!, fit: BoxFit.cover)),
            ),
          const SizedBox(height: 24),
          CircularProgressIndicator(color: primary),
          const SizedBox(height: 16),
          Text(
            'Procesando cambio de look...',
            style: GoogleFonts.nunito(fontSize: 16, color: onSurfaceLight, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final primary = Theme.of(context).colorScheme.primary;
    final onSurfaceLight = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    final surface = Theme.of(context).colorScheme.surface;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text('Tu foto', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: onSurfaceLight)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(aspectRatio: 3 / 4, child: Image.memory(_selfieBytes!, fit: BoxFit.contain)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    Text('Resultado', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: primary)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 3 / 4,
                        child: Image.network(
                          _resultUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Container(
                            color: surface,
                            child: const Center(child: Icon(Icons.broken_image, size: 48)),
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
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saveToGallery,
                  icon: const Icon(Icons.download, size: 20),
                  label: Text('Guardar', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareResult,
                  icon: const Icon(Icons.share, size: 20),
                  label: Text('Compartir', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primary,
                    side: BorderSide(color: primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh, size: 20),
            label: Text('Probar otro', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              foregroundColor: onSurfaceLight,
              side: BorderSide(color: onSurfaceLight.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
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
