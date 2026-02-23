import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beautycita/widgets/bc_image_picker_sheet.dart';
import 'package:beautycita/config/constants.dart';
import 'package:beautycita/providers/auth_provider.dart';
import 'package:beautycita/providers/profile_provider.dart';
import 'package:beautycita/widgets/location_picker_sheet.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:beautycita/services/lightx_service.dart';
import 'package:beautycita/services/media_service.dart';
import 'package:beautycita/services/username_generator.dart';
import 'package:beautycita/widgets/settings_widgets.dart';

// ── AI Avatar Style Model ──

class _AIAvatarStyle {
  final String id;
  final String name;
  final IconData icon;
  final String prompt;
  final Color color;

  const _AIAvatarStyle({
    required this.id,
    required this.name,
    required this.icon,
    required this.prompt,
    required this.color,
  });
}

const _aiAvatarStyles = [
  _AIAvatarStyle(
    id: 'professional',
    name: 'Profesional',
    icon: Icons.work_outline,
    prompt: 'Professional corporate headshot, clean background, studio lighting, confident expression, business attire',
    color: Color(0xFF1976D2),
  ),
  _AIAvatarStyle(
    id: 'artistic',
    name: 'Artistico',
    icon: Icons.palette_outlined,
    prompt: 'Stylized artistic portrait, vibrant colors, painterly effect, creative lighting, artistic interpretation',
    color: Color(0xFFE91E63),
  ),
  _AIAvatarStyle(
    id: 'cyberpunk',
    name: 'Cyberpunk',
    icon: Icons.electric_bolt,
    prompt: 'Cyberpunk sci-fi portrait, neon lights, futuristic style, holographic effects, dystopian aesthetic, tech vibes',
    color: Color(0xFF00BCD4),
  ),
  _AIAvatarStyle(
    id: 'fantasy',
    name: 'Fantasia',
    icon: Icons.auto_awesome,
    prompt: 'Fantasy mythical portrait, ethereal glow, magical aura, enchanted forest background, fairy tale aesthetic',
    color: Color(0xFF9C27B0),
  ),
];

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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.screenPaddingHorizontal,
          vertical: AppConstants.paddingMD,
        ),
        children: [
          // ── Avatar ──
          Center(
            child: GestureDetector(
              onTap: _showAvatarOptions,
              child: Stack(
                children: [
                  CircleAvatar(
                    key: ValueKey(profile.avatarUrl),
                    radius: 48,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    backgroundImage: profile.avatarUrl != null
                        ? NetworkImage(profile.avatarUrl!)
                        : null,
                    child: profile.avatarUrl == null
                        ? Icon(Icons.person_outline,
                            size: 48, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
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

          const SizedBox(height: AppConstants.paddingMD),

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
                        size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                  ],
                ),
              ),
            ),

          const SizedBox(height: AppConstants.paddingLG),

          // ── Full Name ──
          const SectionHeader(label: 'Informacion personal'),
          const SizedBox(height: AppConstants.paddingXS),

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
                    icon: Icon(Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary),
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
              iconColor: profile.fullName != null ? Colors.green.shade600 : null,
              label: profile.fullName ?? 'Agregar nombre',
              trailing: profile.fullName != null
                  ? Icon(Icons.check_circle, size: 20, color: Colors.green.shade600)
                  : Text(
                      'Agregar',
                      style: textTheme.bodySmall
                          ?.copyWith(color: Theme.of(context).colorScheme.primary),
                    ),
              onTap: () {
                _nameController.text = profile.fullName ?? '';
                setState(() => _editingName = true);
              },
            ),

          // ── Phone ──
          SettingsTile(
            icon: Icons.phone_outlined,
            iconColor: profile.hasVerifiedPhone
                ? Colors.green.shade600
                : profile.phone != null ? Colors.orange.shade600 : null,
            label: profile.phone ?? 'Agregar telefono',
            trailing: profile.hasVerifiedPhone
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Verificado', style: textTheme.bodySmall?.copyWith(
                        color: Colors.green.shade600, fontSize: 11)),
                      const SizedBox(width: 6),
                      Icon(Icons.check_circle, color: Colors.green.shade600, size: 18),
                    ],
                  )
                : profile.phone != null
                    ? GestureDetector(
                        onTap: () => _showOtpSheet(context),
                        child: Text('Verificar', style: textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
                      )
                    : Text('Requerido', style: textTheme.bodySmall?.copyWith(
                        color: Colors.red.shade400, fontSize: 11)),
            onTap: () => _showPhoneSheet(context),
          ),

          // ── Birthday ──
          SettingsTile(
            icon: Icons.cake_outlined,
            iconColor: profile.birthday != null ? Colors.green.shade600 : null,
            label: profile.birthday != null
                ? DateFormat('d MMM yyyy', 'es').format(profile.birthday!)
                : 'Fecha de nacimiento',
            trailing: profile.birthday != null
                ? Icon(Icons.check_circle, size: 18, color: Colors.green.shade600)
                : null,
            onTap: () => _showBirthdayPicker(context),
          ),

          // ── Gender ──
          SettingsTile(
            icon: Icons.person_outline_rounded,
            iconColor: profile.gender != null ? Colors.green.shade600 : null,
            label: profile.gender != null
                ? _genderLabel(profile.gender!)
                : 'Genero',
            trailing: profile.gender != null
                ? Icon(Icons.check_circle, size: 18, color: Colors.green.shade600)
                : null,
            onTap: () => _showGenderSheet(context),
          ),

          const SizedBox(height: AppConstants.paddingLG),

          // ── Ubicacion temporal ──
          const SectionHeader(label: 'Buscar desde otra ubicacion'),
          const SizedBox(height: AppConstants.paddingXS),

          _buildTempLocationTile(context, textTheme),

          const SizedBox(height: AppConstants.paddingLG),

          // ── Contenido ──
          const SectionHeader(label: 'Contenido'),
          const SizedBox(height: AppConstants.paddingXS),

          SettingsTile(
            icon: Icons.perm_media_rounded,
            label: 'Media Manager',
            onTap: () => context.push('/media-manager'),
          ),

          const SizedBox(height: AppConstants.paddingLG),
        ],
      ),
    );
  }

  // ── Username editing ──

  void _startEditingUsername() {
    final current = ref.read(authStateProvider).username ?? '';
    _usernameController.text = current;
    _usernameSuggestions =
        UsernameGenerator.generateSuggestions(count: 4, withSuffix: false);
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
                icon: Icon(Icons.check_rounded,
                    color: Theme.of(context).colorScheme.primary),
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
          const SizedBox(height: AppConstants.paddingXS),
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
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppConstants.paddingXS),
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
    final result = await showBCImagePicker(
      context: context,
      ref: ref,
    );
    if (result == null || !mounted) return;

    // Show crop editor with the picked image bytes
    final cropped = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _AvatarCropEditor(imageBytes: result.bytes),
      ),
    );
    if (cropped == null || !mounted) return;

    if (useAI) {
      await _showAIStylePicker(cropped);
    } else {
      await _uploadCroppedAvatar(cropped);
    }
  }

  Future<void> _showAIStylePicker(Uint8List croppedBytes) async {
    final selectedStyle = await showModalBottomSheet<_AIAvatarStyle>(
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
                buildSheetHeader(ctx, 'Elige un estilo'),
                ..._aiAvatarStyles.map((style) => ListTile(
                      leading: Icon(style.icon, color: style.color, size: 28),
                      title: Text(
                        style.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: Icon(Icons.chevron_right,
                          color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.5)),
                      onTap: () => Navigator.pop(ctx, style),
                    )),
              ],
            ),
          ),
        );
      },
    );

    if (selectedStyle == null || !mounted) return;
    await _processAIAvatar(croppedBytes, selectedStyle.prompt);
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

  Future<void> _processAIAvatar(Uint8List croppedBytes, String stylePrompt) async {
    if (!mounted) return;
    debugPrint('[Avatar] Starting AI avatar creation — ${croppedBytes.length} bytes, style: $stylePrompt');
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
      debugPrint('[Avatar] Calling LightX edge function (headshot)...');
      final lightx = LightXService();
      final resultUrl = await lightx.processTryOn(
        imageBytes: croppedBytes,
        tryOnTypeId: 'headshot',
        stylePrompt: stylePrompt,
      );
      debugPrint('[Avatar] LightX returned result: $resultUrl');

      // Download the result image so we can upload to permanent storage
      debugPrint('[Avatar] Downloading result image...');
      final response = await http.get(Uri.parse(resultUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download AI result (HTTP ${response.statusCode})');
      }
      final resultBytes = response.bodyBytes;
      debugPrint('[Avatar] Downloaded ${resultBytes.length} bytes');

      if (!mounted) return;

      // Upload to Supabase storage as permanent avatar
      debugPrint('[Avatar] Uploading to Supabase storage...');
      final fileName = 'avatar_ai_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final permanentUrl = await ref
          .read(profileProvider.notifier)
          .uploadAvatar(resultBytes, fileName);

      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading

      if (permanentUrl == null) {
        throw Exception('Failed to upload avatar');
      }
      debugPrint('[Avatar] Avatar saved: $permanentUrl');

      // Save to user_media for media manager
      try {
        final mediaService = MediaService();
        await mediaService.saveLightXResult(
          resultUrl: permanentUrl,
          toolType: 'headshot',
          stylePrompt: stylePrompt,
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
    } catch (e, st) {
      debugPrint('[Avatar] ERROR: $e');
      debugPrint('[Avatar] Stack trace: $st');
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  // ── Temp location tile ──

  Widget _buildTempLocationTile(BuildContext context, TextTheme textTheme) {
    final tempLoc = ref.watch(tempSearchLocationProvider);

    if (tempLoc != null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: AppConstants.paddingSM),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(AppConstants.radiusSM),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.location_on, color: Colors.amber.shade700, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tempLoc.address,
                    style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('Temporal — se reinicia al cerrar la app',
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.amber.shade800, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => ref.read(tempSearchLocationProvider.notifier).state = null,
              child: Icon(Icons.close_rounded, color: Colors.grey.shade500, size: 20),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingSM),
          child: Text(
            'Si estaras en otro lugar (boda, viaje, etc.), busca estilistas cerca de esa direccion. Se reinicia al cerrar la app.',
            style: textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SettingsTile(
          icon: Icons.add_location_alt_outlined,
          label: 'Elegir ubicacion temporal',
          onTap: () => _pickTempLocation(context),
        ),
      ],
    );
  }

  Future<void> _pickTempLocation(BuildContext context) async {
    final location = await showLocationPicker(
      context: context,
      ref: ref,
      title: 'Buscar desde esta ubicacion',
    );
    if (location != null && mounted) {
      ref.read(tempSearchLocationProvider.notifier).state = location;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Buscando desde: ${location.address}'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ── Phone ──

  void _showPhoneSheet(BuildContext context) {
    final controller = TextEditingController(
      text: ref.read(profileProvider).phone ?? '+52 ',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildSheetHeader(context, 'Telefono'),
              Text(
                'Necesario para confirmar reservas y recibir alertas por SMS.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '+52 33 1234 5678',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final phone = controller.text.trim().replaceAll(' ', '');
                    if (phone.length < 12) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Numero invalido'),
                          backgroundColor: Colors.red.shade600,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    final success = await ref.read(profileProvider.notifier).updatePhone(phone);
                    if (success && mounted) {
                      _showOtpSheet(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusSM)),
                  ),
                  child: const Text('Guardar y verificar'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showOtpSheet(BuildContext context) async {
    final sent = await ref.read(profileProvider.notifier).sendPhoneOtp();
    if (!sent || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No se pudo enviar el codigo'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    final otpController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildSheetHeader(context, 'Verificar telefono'),
              Text(
                'Ingresa el codigo de 6 digitos que enviamos a ${ref.read(profileProvider).phone}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                autofocus: true,
                maxLength: 6,
                decoration: const InputDecoration(
                  hintText: '000000',
                  prefixIcon: Icon(Icons.sms_outlined),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final otp = otpController.text.trim();
                    if (otp.length != 6) return;
                    Navigator.pop(ctx);
                    final ok = await ref.read(profileProvider.notifier).verifyPhoneOtp(otp);
                    if (ok && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Telefono verificado'),
                          backgroundColor: Colors.green.shade600,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusSM)),
                  ),
                  child: const Text('Verificar'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Birthday ──

  Future<void> _showBirthdayPicker(BuildContext context) async {
    final current = ref.read(profileProvider).birthday;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 13)),
      locale: const Locale('es'),
    );
    if (picked != null && mounted) {
      await ref.read(profileProvider.notifier).updateBirthday(picked);
      if (mounted && ref.read(profileProvider).error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Fecha de nacimiento guardada'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // ── Gender ──

  String _genderLabel(String gender) {
    switch (gender) {
      case 'female': return 'Mujer';
      case 'male': return 'Hombre';
      case 'non_binary': return 'No binario';
      case 'prefer_not_say': return 'Prefiero no decir';
      default: return gender;
    }
  }

  void _showGenderSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildSheetHeader(context, 'Genero'),
                for (final g in ['female', 'male', 'non_binary', 'prefer_not_say'])
                  OptionTile(
                    emoji: g == 'female' ? '♀' : g == 'male' ? '♂' : g == 'non_binary' ? '⚧' : '—',
                    label: _genderLabel(g),
                    subtitle: '',
                    selected: ref.read(profileProvider).gender == g,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await ref.read(profileProvider.notifier).updateGender(g);
                      if (mounted && ref.read(profileProvider).error == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Genero guardado'),
                            backgroundColor: Colors.green.shade600,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
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
      backgroundColor: Theme.of(context).colorScheme.onSurface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.onSurface,
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
                    backgroundColor: Theme.of(context).colorScheme.primary,
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
