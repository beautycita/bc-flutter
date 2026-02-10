import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:beautycita/config/theme.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/providers/auth_provider.dart';
import 'package:beautycita/providers/profile_provider.dart';
import 'package:http/http.dart' as http;
import 'package:beautycita/services/lightx_service.dart';
import 'package:beautycita/services/media_service.dart';
import 'package:beautycita/services/username_generator.dart';
import 'package:beautycita/widgets/settings_widgets.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _editingName = false;
  bool _editingUsername = false;
  bool _usernameAvailable = true;
  bool _checkingUsername = false;
  String? _usernameError;
  List<String> _usernameSuggestions = [];
  Timer? _usernameDebounce;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _usernameDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final profile = ref.watch(profileProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: BeautyCitaTheme.backgroundWhite,
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.screenPaddingHorizontal,
          vertical: BeautyCitaTheme.spaceMD,
        ),
        children: [
          // ── Avatar ──
          Center(
            child: GestureDetector(
              onTap: _showAvatarOptions,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: BeautyCitaTheme.surfaceCream,
                    backgroundImage: profile.avatarUrl != null
                        ? NetworkImage(profile.avatarUrl!)
                        : null,
                    child: profile.avatarUrl == null
                        ? const Icon(Icons.person_outline,
                            size: 48, color: BeautyCitaTheme.textLight)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: BeautyCitaTheme.primaryRose,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: BeautyCitaTheme.spaceMD),

          // ── Username (tappable to edit) ──
          if (_editingUsername)
            _buildUsernameEditor(textTheme)
          else
            Center(
              child: GestureDetector(
                onTap: _startEditingUsername,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      authState.username ?? 'Usuario',
                      style: textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.edit_outlined,
                        size: 16, color: BeautyCitaTheme.textLight),
                  ],
                ),
              ),
            ),

          const SizedBox(height: BeautyCitaTheme.spaceLG),

          // ── Full Name ──
          const SectionHeader(label: 'Informacion personal'),
          const SizedBox(height: BeautyCitaTheme.spaceXS),

          if (_editingName)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.paddingSM,
                vertical: AppConstants.paddingSM,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Tu nombre completo',
                        isDense: true,
                      ),
                      onSubmitted: (_) => _saveName(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.check_rounded,
                        color: BeautyCitaTheme.primaryRose),
                    onPressed: _saveName,
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: Colors.grey.shade500),
                    onPressed: () => setState(() => _editingName = false),
                  ),
                ],
              ),
            )
          else
            SettingsTile(
              icon: Icons.badge_outlined,
              label: profile.fullName ?? 'Agregar nombre',
              trailing: profile.fullName != null
                  ? Icon(Icons.edit_outlined, size: 16, color: BeautyCitaTheme.textLight)
                  : Text(
                      'Agregar',
                      style: textTheme.bodySmall
                          ?.copyWith(color: BeautyCitaTheme.primaryRose),
                    ),
              onTap: () {
                _nameController.text = profile.fullName ?? '';
                setState(() => _editingName = true);
              },
            ),

          const SizedBox(height: BeautyCitaTheme.spaceLG),

          // ── Contenido ──
          const SectionHeader(label: 'Contenido'),
          const SizedBox(height: BeautyCitaTheme.spaceXS),

          SettingsTile(
            icon: Icons.perm_media_rounded,
            label: 'Media Manager',
            onTap: () => context.push('/media-manager'),
          ),

          const SizedBox(height: BeautyCitaTheme.spaceLG),
        ],
      ),
    );
  }

  // ── Username editing ──

  void _startEditingUsername() {
    final current = ref.read(authStateProvider).username ?? '';
    _usernameController.text = current;
    _usernameSuggestions =
        UsernameGenerator.generateSuggestions(count: 4, withSuffix: true);
    setState(() {
      _editingUsername = true;
      _usernameError = null;
      _usernameAvailable = true;
      _checkingUsername = false;
    });
  }

  Widget _buildUsernameEditor(TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingSM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _usernameController,
                  autofocus: true,
                  maxLength: 30,
                  decoration: InputDecoration(
                    hintText: 'Nombre de usuario',
                    isDense: true,
                    counterText: '',
                    errorText: _usernameError,
                    suffixIcon: _checkingUsername
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _usernameController.text.length >= 3
                            ? Icon(
                                _usernameAvailable
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color: _usernameAvailable
                                    ? Colors.green
                                    : Colors.red,
                                size: 20,
                              )
                            : null,
                  ),
                  onChanged: _onUsernameChanged,
                  onSubmitted: (_) => _saveUsername(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.check_rounded,
                    color: BeautyCitaTheme.primaryRose),
                onPressed:
                    _usernameAvailable && _usernameError == null
                        ? _saveUsername
                        : null,
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: Colors.grey.shade500),
                onPressed: () => setState(() => _editingUsername = false),
              ),
            ],
          ),
          const SizedBox(height: BeautyCitaTheme.spaceXS),
          // Suggestion chips
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: _usernameSuggestions
                .map(
                  (s) => ActionChip(
                    label: Text(s, style: const TextStyle(fontSize: 12)),
                    onPressed: () {
                      _usernameController.text = s;
                      _onUsernameChanged(s);
                    },
                    backgroundColor: BeautyCitaTheme.surfaceCream,
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: BeautyCitaTheme.spaceXS),
        ],
      ),
    );
  }

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    final trimmed = value.trim();

    // Inline validation
    if (trimmed.length < 3) {
      setState(() {
        _usernameError = trimmed.isEmpty ? null : 'Minimo 3 caracteres';
        _usernameAvailable = false;
        _checkingUsername = false;
      });
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(trimmed)) {
      setState(() {
        _usernameError = 'Solo letras y numeros';
        _usernameAvailable = false;
        _checkingUsername = false;
      });
      return;
    }

    setState(() {
      _usernameError = null;
      _checkingUsername = true;
    });

    // Debounced uniqueness check
    _usernameDebounce = Timer(const Duration(milliseconds: 400), () async {
      final available = await ref
          .read(profileProvider.notifier)
          .checkUsernameAvailable(trimmed);
      if (!mounted) return;
      setState(() {
        _usernameAvailable = available;
        _checkingUsername = false;
        if (!available) _usernameError = 'Ya esta en uso';
      });
    });
  }

  Future<void> _saveUsername() async {
    final username = _usernameController.text.trim();
    if (username.length < 3 || !_usernameAvailable) return;

    final success =
        await ref.read(profileProvider.notifier).updateUsername(username);
    if (!mounted) return;

    if (success) {
      await ref.read(authStateProvider.notifier).updateUsername(username);
      if (!mounted) return;
      setState(() => _editingUsername = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Usuario actualizado'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error al actualizar usuario'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Avatar options ──

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppConstants.radiusXL)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.paddingLG,
              AppConstants.paddingMD,
              AppConstants.paddingLG,
              AppConstants.paddingLG,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildSheetHeader(ctx, 'Cambiar foto de perfil'),
                SettingsTile(
                  icon: Icons.photo_library_outlined,
                  label: 'Subir foto',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndCropAvatar(useAI: false);
                  },
                ),
                SettingsTile(
                  icon: Icons.auto_awesome,
                  label: 'Crear avatar IA',
                  iconColor: Colors.deepPurple,
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndCropAvatar(useAI: true);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndCropAvatar({required bool useAI}) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 90,
    );
    if (image == null || !mounted) return;

    final bytes = await image.readAsBytes();

    // Show crop editor
    final cropped = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _AvatarCropEditor(imageBytes: bytes),
      ),
    );
    if (cropped == null || !mounted) return;

    if (useAI) {
      await _processAIAvatar(cropped);
    } else {
      await _uploadCroppedAvatar(cropped);
    }
  }

  Future<void> _uploadCroppedAvatar(Uint8List bytes) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Subiendo foto (${(bytes.length / 1024).toStringAsFixed(0)} KB)...'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );

    final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.png';
    final url =
        await ref.read(profileProvider.notifier).uploadAvatar(bytes, fileName);
    if (!mounted) return;

    if (url != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Foto actualizada'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      final error = ref.read(profileProvider).error ?? 'Error desconocido';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _processAIAvatar(Uint8List croppedBytes) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Creando tu avatar...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final lightx = LightXService();
      final resultUrl = await lightx.processTryOn(
        imageBytes: croppedBytes,
        tryOnTypeId: 'headshot',
        stylePrompt: 'Professional beauty headshot',
      );

      // Download the result image so we can upload to permanent storage
      final response = await http.get(Uri.parse(resultUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download AI result');
      }
      final resultBytes = response.bodyBytes;

      if (!mounted) return;

      // Upload to Supabase storage as permanent avatar
      final fileName = 'avatar_ai_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final permanentUrl = await ref
          .read(profileProvider.notifier)
          .uploadAvatar(resultBytes, fileName);

      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading

      if (permanentUrl == null) {
        throw Exception('Failed to upload avatar');
      }

      // Save to user_media for media manager
      try {
        final mediaService = MediaService();
        await mediaService.saveLightXResult(
          resultUrl: permanentUrl,
          toolType: 'headshot',
          stylePrompt: 'Professional beauty headshot',
        );
      } catch (_) {
        // Non-critical — avatar is already saved
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Avatar IA creado'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Name editing ──

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    await ref.read(profileProvider.notifier).updateFullName(name);
    if (!mounted) return;
    setState(() => _editingName = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Nombre actualizado'),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ── Avatar Crop Editor ──

class _AvatarCropEditor extends StatefulWidget {
  final Uint8List imageBytes;

  const _AvatarCropEditor({required this.imageBytes});

  @override
  State<_AvatarCropEditor> createState() => _AvatarCropEditorState();
}

class _AvatarCropEditorState extends State<_AvatarCropEditor> {
  final TransformationController _transformController =
      TransformationController();
  final GlobalKey _viewerKey = GlobalKey();
  bool _processing = false;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final circleSize = screenWidth * 0.80;

    return Scaffold(
      backgroundColor: BeautyCitaTheme.textDark,
      appBar: AppBar(
        backgroundColor: BeautyCitaTheme.textDark,
        foregroundColor: Colors.white,
        title: const Text('Recortar foto'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: ClipRect(
                child: SizedBox(
                  width: screenWidth,
                  height: screenWidth,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Zoomable/pannable image
                      RepaintBoundary(
                        key: _viewerKey,
                        child: InteractiveViewer(
                          transformationController: _transformController,
                          boundaryMargin: const EdgeInsets.all(200),
                          minScale: 0.5,
                          maxScale: 4.0,
                          child: Image.memory(
                            widget.imageBytes,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      // Circle mask overlay
                      IgnorePointer(
                        child: CustomPaint(
                          size: Size(screenWidth, screenWidth),
                          painter: _CircleMaskPainter(
                            circleSize: circleSize,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Confirm button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.paddingLG),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _processing ? null : _cropAndReturn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BeautyCitaTheme.primaryRose,
                    foregroundColor: Colors.white,
                    minimumSize:
                        const Size(0, AppConstants.minTouchHeight),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusLG),
                    ),
                  ),
                  child: _processing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Confirmar',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cropAndReturn() async {
    setState(() => _processing = true);

    try {
      final boundary = _viewerKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        Navigator.pop(context);
        return;
      }

      // Capture the viewer area at 512x512
      final image = await boundary.toImage(pixelRatio: 512.0 / boundary.size.width);
      final screenWidth = boundary.size.width;
      final circleSize = screenWidth * 0.80;
      final offset = (screenWidth - circleSize) / 2.0;
      final ratio = 512.0 / boundary.size.width;

      // Crop to circle area
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final srcRect = Rect.fromLTWH(
        offset * ratio,
        offset * ratio,
        circleSize * ratio,
        circleSize * ratio,
      );
      const dstRect = Rect.fromLTWH(0, 0, 512, 512);

      // Clip to circle
      canvas.clipPath(
        Path()..addOval(dstRect),
      );
      canvas.drawImageRect(image, srcRect, dstRect, Paint());

      final croppedImage = await recorder.endRecording().toImage(512, 512);
      final byteData =
          await croppedImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null && mounted) {
        Navigator.pop(context, byteData.buffer.asUint8List());
      } else if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al recortar: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ── Circle Mask Painter ──

class _CircleMaskPainter extends CustomPainter {
  final double circleSize;

  _CircleMaskPainter({required this.circleSize});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = circleSize / 2;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // saveLayer required for BlendMode.clear to punch through
    canvas.saveLayer(rect, Paint());

    // Fill entire area with semi-transparent black
    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.6);
    canvas.drawRect(rect, bgPaint);

    // Punch transparent circle hole
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    canvas.drawCircle(center, radius, clearPaint);

    canvas.restore();

    // Draw thin white circle border
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _CircleMaskPainter oldDelegate) =>
      circleSize != oldDelegate.circleSize;
}
