# Profile Avatar & Media Manager Improvements

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix profile avatar editing, add media manager upload, make BC media library the default image picker, and add LightX AI avatar prompts.

**Architecture:** Create a reusable `BCImagePickerSheet` widget that shows BC media library as the first tab, then device gallery/camera options. Add upload FAB to media manager. Enhance AI avatar flow with premade style prompts.

**Tech Stack:** Flutter, Riverpod, Supabase Storage, LightX API via edge function

---

## Task 1: Create BC Image Picker Sheet Widget

**Files:**
- Create: `lib/widgets/bc_image_picker_sheet.dart`
- Modify: `lib/providers/media_provider.dart` (add provider for picker)

**Step 1: Write the widget file**

```dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import '../providers/media_provider.dart';
import '../services/media_service.dart';

/// Result from BC Image Picker
class BCImagePickerResult {
  final Uint8List bytes;
  final String? sourceUrl; // If from media library, original URL
  final String source; // 'library', 'gallery', 'camera'

  BCImagePickerResult({
    required this.bytes,
    this.sourceUrl,
    required this.source,
  });
}

/// Shows BC Media Library first, then device gallery/camera options.
/// Returns [BCImagePickerResult] or null if cancelled.
Future<BCImagePickerResult?> showBCImagePicker(
  BuildContext context, {
  String title = 'Seleccionar imagen',
  bool allowCamera = true,
  int maxWidth = 1024,
  int maxHeight = 1024,
  int imageQuality = 90,
}) async {
  return showModalBottomSheet<BCImagePickerResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _BCImagePickerSheet(
      title: title,
      allowCamera: allowCamera,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    ),
  );
}

class _BCImagePickerSheet extends ConsumerStatefulWidget {
  final String title;
  final bool allowCamera;
  final int maxWidth;
  final int maxHeight;
  final int imageQuality;

  const _BCImagePickerSheet({
    required this.title,
    required this.allowCamera,
    required this.maxWidth,
    required this.maxHeight,
    required this.imageQuality,
  });

  @override
  ConsumerState<_BCImagePickerSheet> createState() => _BCImagePickerSheetState();
}

class _BCImagePickerSheetState extends ConsumerState<_BCImagePickerSheet> {
  bool _loading = false;

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: widget.maxWidth.toDouble(),
      maxHeight: widget.maxHeight.toDouble(),
      imageQuality: widget.imageQuality,
    );
    if (image == null || !mounted) return;

    setState(() => _loading = true);
    final bytes = await image.readAsBytes();
    if (!mounted) return;

    Navigator.pop(context, BCImagePickerResult(
      bytes: bytes,
      source: 'gallery',
    ));
  }

  Future<void> _pickFromCamera() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: widget.maxWidth.toDouble(),
      maxHeight: widget.maxHeight.toDouble(),
      imageQuality: widget.imageQuality,
      preferredCameraDevice: CameraDevice.front,
    );
    if (image == null || !mounted) return;

    setState(() => _loading = true);
    final bytes = await image.readAsBytes();
    if (!mounted) return;

    Navigator.pop(context, BCImagePickerResult(
      bytes: bytes,
      source: 'camera',
    ));
  }

  Future<void> _selectFromLibrary(MediaItem item) async {
    setState(() => _loading = true);
    try {
      final response = await Uri.parse(item.url).run();
      // Download the image bytes
      final httpClient = await HttpClient().getUrl(Uri.parse(item.url));
      final httpResponse = await httpClient.close();
      final bytes = await httpResponse.fold<List<int>>(
        <int>[],
        (prev, chunk) => prev..addAll(chunk),
      );
      if (!mounted) return;

      Navigator.pop(context, BCImagePickerResult(
        bytes: Uint8List.fromList(bytes),
        sourceUrl: item.url,
        source: 'library',
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaAsync = ref.watch(personalMediaProvider);
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.75,
      decoration: const BoxDecoration(
        color: BeautyCitaTheme.backgroundWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  widget.title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Source buttons row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _SourceButton(
                    icon: Icons.photo_library_outlined,
                    label: 'Galeria',
                    onTap: _pickFromGallery,
                  ),
                ),
                if (widget.allowCamera) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SourceButton(
                      icon: Icons.camera_alt_outlined,
                      label: 'Camara',
                      onTap: _pickFromCamera,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Divider with label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: Divider(color: Colors.grey.shade300)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Tu biblioteca',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: BeautyCitaTheme.textLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey.shade300)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Media library grid
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : mediaAsync.when(
                    data: (items) {
                      if (items.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.photo_library_outlined,
                                size: 48,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Tu biblioteca esta vacia',
                                style: GoogleFonts.nunito(
                                  color: BeautyCitaTheme.textLight,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                        ),
                        itemCount: items.length,
                        itemBuilder: (ctx, i) => _LibraryThumbnail(
                          item: items[i],
                          onTap: () => _selectFromLibrary(items[i]),
                        ),
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (e, _) => Center(
                      child: Text('Error: $e'),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BeautyCitaTheme.surfaceCream,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, size: 28, color: BeautyCitaTheme.primaryRose),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryThumbnail extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;

  const _LibraryThumbnail({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          item.thumbnailUrl ?? item.url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.grey.shade200,
            child: const Icon(Icons.broken_image, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}
```

**Step 2: Run build to verify no errors**

Run: `cd /home/bc/futureBeauty/beautycita_app && flutter build apk --debug 2>&1 | tail -20`

**Step 3: Commit**

```bash
git add lib/widgets/bc_image_picker_sheet.dart
git commit -m "feat: add BC image picker sheet with media library"
```

---

## Task 2: Fix BC Image Picker HTTP Import

**Files:**
- Modify: `lib/widgets/bc_image_picker_sheet.dart`

**Step 1: Fix the HTTP download code**

Replace the `_selectFromLibrary` method with proper http import:

```dart
// Add at top of file:
import 'package:http/http.dart' as http;

// Replace _selectFromLibrary method:
Future<void> _selectFromLibrary(MediaItem item) async {
  setState(() => _loading = true);
  try {
    final response = await http.get(Uri.parse(item.url));
    if (response.statusCode != 200) {
      throw Exception('Failed to download image');
    }
    if (!mounted) return;

    Navigator.pop(context, BCImagePickerResult(
      bytes: response.bodyBytes,
      sourceUrl: item.url,
      source: 'library',
    ));
  } catch (e) {
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
```

**Step 2: Run build to verify**

Run: `cd /home/bc/futureBeauty/beautycita_app && flutter build apk --debug 2>&1 | tail -20`

**Step 3: Commit**

```bash
git add lib/widgets/bc_image_picker_sheet.dart
git commit -m "fix: correct http import in BC image picker"
```

---

## Task 3: Add Upload FAB to Media Manager

**Files:**
- Modify: `lib/screens/media_manager_screen.dart`
- Modify: `lib/services/media_service.dart` (add uploadMedia method)

**Step 1: Add uploadMedia method to MediaService**

Add to `lib/services/media_service.dart`:

```dart
/// Uploads an image to user_media storage and creates a record.
Future<MediaItem?> uploadMedia({
  required Uint8List bytes,
  required String section, // 'personal' or 'business'
  String? description,
}) async {
  if (!SupabaseClientService.isInitialized) return null;
  final userId = SupabaseClientService.currentUserId;
  if (userId == null) return null;

  try {
    final client = SupabaseClientService.client;
    final fileName = 'upload_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = '$userId/$fileName';

    // Upload to storage
    await client.storage.from('user-media').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
    );

    final url = client.storage.from('user-media').getPublicUrl(path);

    // Create database record
    final result = await client.from('user_media').insert({
      'user_id': userId,
      'media_type': 'image',
      'source': 'upload',
      'url': url,
      'section': section,
      'metadata': description != null ? {'description': description} : null,
    }).select().single();

    return MediaItem(
      id: result['id'] as String,
      url: url,
      thumbnailUrl: url,
      source: 'upload',
      createdAt: DateTime.parse(result['created_at'] as String),
    );
  } catch (e) {
    debugPrint('MediaService.uploadMedia error: $e');
    return null;
  }
}
```

**Step 2: Add FAB to MediaManagerScreen**

Modify `lib/screens/media_manager_screen.dart` - add to Scaffold:

```dart
// Add import at top:
import '../widgets/bc_image_picker_sheet.dart';

// In Scaffold, add floatingActionButton:
floatingActionButton: FloatingActionButton(
  backgroundColor: BeautyCitaTheme.primaryRose,
  onPressed: _uploadMedia,
  child: const Icon(Icons.add_photo_alternate, color: Colors.white),
),

// Add method to _MediaManagerScreenState:
Future<void> _uploadMedia() async {
  final section = _tabController.index == 1 ? 'business' : 'personal';

  final result = await showBCImagePicker(
    context,
    title: 'Subir a ${section == 'business' ? 'Negocio' : 'Tus Medios'}',
  );
  if (result == null || !mounted) return;

  // Show loading
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Subiendo...'),
      duration: Duration(seconds: 1),
    ),
  );

  final service = ref.read(mediaServiceProvider);
  final item = await service.uploadMedia(
    bytes: result.bytes,
    section: section,
  );

  if (!mounted) return;

  if (item != null) {
    // Refresh providers
    ref.invalidate(personalMediaProvider);
    ref.invalidate(businessMediaProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Imagen subida'),
        backgroundColor: Colors.green.shade600,
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Error al subir imagen'),
        backgroundColor: Colors.red.shade600,
      ),
    );
  }
}
```

**Step 3: Run build to verify**

Run: `cd /home/bc/futureBeauty/beautycita_app && flutter build apk --debug 2>&1 | tail -20`

**Step 4: Commit**

```bash
git add lib/screens/media_manager_screen.dart lib/services/media_service.dart
git commit -m "feat: add upload FAB to media manager"
```

---

## Task 4: Update Profile Avatar to Use BC Image Picker

**Files:**
- Modify: `lib/screens/profile_screen.dart`

**Step 1: Replace _pickAndCropAvatar to use BCImagePicker**

```dart
// Add import at top:
import 'package:beautycita/widgets/bc_image_picker_sheet.dart';

// Replace _pickAndCropAvatar method:
Future<void> _pickAndCropAvatar({required bool useAI}) async {
  final result = await showBCImagePicker(
    context,
    title: 'Seleccionar foto',
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 90,
  );
  if (result == null || !mounted) return;

  // Show crop editor
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
```

**Step 2: Run build to verify**

Run: `cd /home/bc/futureBeauty/beautycita_app && flutter build apk --debug 2>&1 | tail -20`

**Step 3: Commit**

```bash
git add lib/screens/profile_screen.dart
git commit -m "feat: use BC image picker for avatar selection"
```

---

## Task 5: Add LightX AI Avatar Style Prompts

**Files:**
- Modify: `lib/screens/profile_screen.dart`

**Step 1: Add AI style constants and picker method**

Add after the class definition:

```dart
/// Premade AI avatar style prompts for LightX headshot
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
```

**Step 2: Add style picker method to _ProfileScreenState**

```dart
Future<void> _showAIStylePicker(Uint8List croppedBytes) async {
  final style = await showModalBottomSheet<_AIAvatarStyle>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Elige un estilo',
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tu avatar sera creado con IA en este estilo',
              style: TextStyle(color: BeautyCitaTheme.textLight),
            ),
            const SizedBox(height: 20),
            ..._aiAvatarStyles.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: s.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => Navigator.pop(ctx, s),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: s.color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(s.icon, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          s.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.chevron_right, color: Colors.grey.shade400),
                      ],
                    ),
                  ),
                ),
              ),
            )),
          ],
        ),
      ),
    ),
  );

  if (style == null || !mounted) return;
  await _processAIAvatar(croppedBytes, style.prompt);
}
```

**Step 3: Update _processAIAvatar to accept prompt parameter**

```dart
Future<void> _processAIAvatar(Uint8List croppedBytes, String stylePrompt) async {
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
      stylePrompt: stylePrompt,
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
```

**Step 4: Run build to verify**

Run: `cd /home/bc/futureBeauty/beautycita_app && flutter build apk --debug 2>&1 | tail -20`

**Step 5: Commit**

```bash
git add lib/screens/profile_screen.dart
git commit -m "feat: add AI avatar style prompts (Professional, Artistic, Cyberpunk, Fantasy)"
```

---

## Task 6: Create user-media Storage Bucket (if needed)

**Files:**
- Check: Supabase storage buckets

**Step 1: Verify bucket exists via Supabase CLI or dashboard**

Run on server:
```bash
ssh www-bc "cd /var/www/beautycita.com/bc-flutter/supabase-docker && docker exec supabase-db psql -U postgres -d postgres -c \"SELECT name FROM storage.buckets WHERE name = 'user-media';\""
```

**Step 2: Create bucket if not exists**

```sql
INSERT INTO storage.buckets (id, name, public)
VALUES ('user-media', 'user-media', true)
ON CONFLICT (id) DO NOTHING;
```

**Step 3: Add RLS policy**

```sql
CREATE POLICY "Users can upload their own media"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'user-media' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Public read access for user-media"
ON storage.objects FOR SELECT
USING (bucket_id = 'user-media');

CREATE POLICY "Users can delete their own media"
ON storage.objects FOR DELETE
USING (bucket_id = 'user-media' AND auth.uid()::text = (storage.foldername(name))[1]);
```

---

## Task 7: Build and Test Release APK

**Step 1: Build release APK**

Run: `cd /home/bc/futureBeauty/beautycita_app && flutter build apk --release`

**Step 2: Install on device**

Run: `adb -s 192.168.0.26:36931 install -r build/app/outputs/flutter-apk/app-release.apk`

**Step 3: Test scenarios**

1. Profile → Tap avatar → "Subir foto" → Should show BC media library first
2. Profile → Tap avatar → "Crear avatar IA" → Should show 4 style options
3. Media Manager → Tap FAB → Should show BC image picker → Upload works
4. All uploaded images appear in Media Manager

---

## Summary

| Task | Description |
|------|-------------|
| 1 | Create BCImagePickerSheet widget |
| 2 | Fix HTTP import in picker |
| 3 | Add upload FAB to Media Manager |
| 4 | Update profile to use BC picker |
| 5 | Add AI avatar style prompts |
| 6 | Create user-media storage bucket |
| 7 | Build and test release |

**Estimated commits:** 5
