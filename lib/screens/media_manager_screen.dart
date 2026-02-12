import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../providers/media_provider.dart';
import '../services/media_service.dart';
import '../widgets/bc_image_picker_sheet.dart';
import '../widgets/media_grid.dart';

class MediaManagerScreen extends ConsumerStatefulWidget {
  const MediaManagerScreen({super.key});

  @override
  ConsumerState<MediaManagerScreen> createState() => _MediaManagerScreenState();
}

class _MediaManagerScreenState extends ConsumerState<MediaManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onShare(MediaItem item) {
    final service = ref.read(mediaServiceProvider);
    service.shareImage(item.url, text: 'BeautyCita');
  }

  void _onSaveToGallery(MediaItem item) async {
    final service = ref.read(mediaServiceProvider);
    final success = await service.saveUrlToGallery(item.url);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Guardado en galeria' : 'Error al guardar',
            style: GoogleFonts.nunito(),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              success ? BeautyCitaTheme.primaryRose : Colors.red.shade400,
        ),
      );
    }
  }

  void _onDelete(MediaItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Eliminar', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Eliminar este archivo?', style: GoogleFonts.nunito()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Eliminar', style: TextStyle(color: Colors.red.shade400)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final service = ref.read(mediaServiceProvider);
    await service.deleteMedia(item.id);
    // Refresh the data
    ref.invalidate(personalMediaProvider);
    ref.invalidate(businessMediaProvider);
    if (mounted) {
      Navigator.pop(context); // close viewer
    }
  }

  Future<void> _onUpload() async {
    // Determine section based on current tab index
    // 0 = personal, 1 = business, 2 = chats (don't upload to chats)
    final tabIndex = _tabController.index;
    if (tabIndex == 2) {
      // Chats tab - show info snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No puedes subir a chats',
            style: GoogleFonts.nunito(),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: BeautyCitaTheme.textLight,
        ),
      );
      return;
    }

    final section = tabIndex == 0 ? 'personal' : 'business';

    // Show image picker
    final result = await showBCImagePicker(context: context, ref: ref);
    if (result == null || !mounted) return;

    // Show loading snackbar
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text('Subiendo...', style: GoogleFonts.nunito()),
          ],
        ),
        duration: const Duration(seconds: 30),
        behavior: SnackBarBehavior.floating,
        backgroundColor: BeautyCitaTheme.primaryRose,
      ),
    );

    // Upload
    final service = ref.read(mediaServiceProvider);
    final uploaded = await service.uploadMedia(
      bytes: result.bytes,
      section: section,
    );

    if (!mounted) return;

    // Clear loading snackbar and show result
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (uploaded != null) {
      // Invalidate providers to refresh the grid
      ref.invalidate(personalMediaProvider);
      ref.invalidate(businessMediaProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Subido exitosamente',
            style: GoogleFonts.nunito(),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: BeautyCitaTheme.primaryRose,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al subir',
            style: GoogleFonts.nunito(),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade400,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BeautyCitaTheme.backgroundWhite,
      appBar: AppBar(
        backgroundColor: BeautyCitaTheme.backgroundWhite,
        title: Text(
          'Media Manager',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: BeautyCitaTheme.primaryRose,
          unselectedLabelColor: BeautyCitaTheme.textLight,
          indicatorColor: BeautyCitaTheme.primaryRose,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'Tus Medios'),
            Tab(text: 'Negocio'),
            Tab(text: 'Chats'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PersonalTab(
            onShare: _onShare,
            onDelete: _onDelete,
            onSaveToGallery: _onSaveToGallery,
          ),
          _BusinessTab(
            onShare: _onShare,
            onDelete: _onDelete,
            onSaveToGallery: _onSaveToGallery,
          ),
          _ChatsTab(
            onShare: _onShare,
            onSaveToGallery: _onSaveToGallery,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onUpload,
        backgroundColor: BeautyCitaTheme.primaryRose,
        child: const Icon(
          Icons.add_photo_alternate,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Personal media tab — LightX results, selfies, uploads.
class _PersonalTab extends ConsumerWidget {
  final void Function(MediaItem) onShare;
  final void Function(MediaItem) onDelete;
  final void Function(MediaItem) onSaveToGallery;

  const _PersonalTab({
    required this.onShare,
    required this.onDelete,
    required this.onSaveToGallery,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAsync = ref.watch(personalMediaProvider);
    return mediaAsync.when(
      data: (items) => MediaGrid(
        items: items,
        onShare: onShare,
        onDelete: onDelete,
        onSaveToGallery: onSaveToGallery,
      ),
      loading: () => const Center(
        child: CircularProgressIndicator(color: BeautyCitaTheme.primaryRose),
      ),
      error: (err, _) => Center(
        child: Text('Error: $err', style: GoogleFonts.nunito()),
      ),
    );
  }
}

/// Business media tab — portfolio, client media, reviews.
class _BusinessTab extends ConsumerWidget {
  final void Function(MediaItem) onShare;
  final void Function(MediaItem) onDelete;
  final void Function(MediaItem) onSaveToGallery;

  const _BusinessTab({
    required this.onShare,
    required this.onDelete,
    required this.onSaveToGallery,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAsync = ref.watch(businessMediaProvider);
    return mediaAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.store_outlined,
                  size: 64,
                  color: BeautyCitaTheme.textLight.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  'Sin medios de negocio',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    color: BeautyCitaTheme.textLight,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Los medios de tu salon apareceran aqui',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: BeautyCitaTheme.textLight.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          );
        }
        return MediaGrid(
          items: items,
          onShare: onShare,
          onDelete: onDelete,
          onSaveToGallery: onSaveToGallery,
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: BeautyCitaTheme.primaryRose),
      ),
      error: (err, _) => Center(
        child: Text('Error: $err', style: GoogleFonts.nunito()),
      ),
    );
  }
}

/// Chat media tab — grouped by thread.
class _ChatsTab extends ConsumerWidget {
  final void Function(MediaItem) onShare;
  final void Function(MediaItem) onSaveToGallery;

  const _ChatsTab({
    required this.onShare,
    required this.onSaveToGallery,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatAsync = ref.watch(chatMediaProvider);
    return chatAsync.when(
      data: (grouped) {
        if (grouped.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: BeautyCitaTheme.textLight.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  'Sin medios en chats',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    color: BeautyCitaTheme.textLight,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Las imagenes de tus conversaciones apareceran aqui',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: BeautyCitaTheme.textLight.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        return ListView(
          children: grouped.entries.map((entry) {
            return ChatMediaSection(
              threadLabel: entry.key,
              items: entry.value,
              onShare: onShare,
              onSaveToGallery: onSaveToGallery,
            );
          }).toList(),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: BeautyCitaTheme.primaryRose),
      ),
      error: (err, _) => Center(
        child: Text('Error: $err', style: GoogleFonts.nunito()),
      ),
    );
  }
}
