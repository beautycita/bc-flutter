import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:beautycita/services/toast_service.dart';
import '../providers/media_provider.dart';
import '../providers/business_provider.dart';
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
  TabController? _tabController;
  bool _isBusinessOwner = false;

  void _initTabs(bool isOwner) {
    if (_tabController != null && _isBusinessOwner == isOwner) return;
    _isBusinessOwner = isOwner;
    _tabController?.dispose();
    _tabController = TabController(
      length: isOwner ? 3 : 2,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _onShare(MediaItem item) {
    final service = ref.read(mediaServiceProvider);
    service.shareImage(item.url, text: 'BeautyCita');
  }

  void _onSaveToGallery(MediaItem item) async {
    final service = ref.read(mediaServiceProvider);
    final success = await service.saveUrlToGallery(item.url);
    if (success) {
      ToastService.showSuccess('Guardado en galeria');
    } else {
      ToastService.showError('Error al guardar');
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

  /// Map tab index to section name based on whether business tab is shown.
  String? _sectionForTab(int tabIndex) {
    if (_isBusinessOwner) {
      // 0=personal, 1=business, 2=chats
      return switch (tabIndex) { 0 => 'personal', 1 => 'business', _ => null };
    } else {
      // 0=personal, 1=chats
      return tabIndex == 0 ? 'personal' : null;
    }
  }

  Future<void> _onUpload() async {
    debugPrint('MediaManager: _onUpload called');
    final tabIndex = _tabController?.index ?? 0;
    final section = _sectionForTab(tabIndex);

    if (section == null) {
      ToastService.showWarning('No puedes subir a chats');
      return;
    }
    debugPrint('MediaManager: section = $section');

    // Show image picker
    final result = await showBCImagePicker(context: context, ref: ref);
    debugPrint('MediaManager: picker result = ${result?.source}, bytes = ${result?.bytes.length}');
    if (result == null || !mounted) {
      debugPrint('MediaManager: result null or not mounted');
      return;
    }

    HapticFeedback.lightImpact();
    ToastService.showInfo('Subiendo...');

    // Upload
    final service = ref.read(mediaServiceProvider);
    final uploaded = await service.uploadMedia(
      bytes: result.bytes,
      section: section,
    );

    if (uploaded != null) {
      // Invalidate providers to refresh the grid
      ref.invalidate(personalMediaProvider);
      ref.invalidate(businessMediaProvider);

      ToastService.showSuccess('Subido exitosamente');
    } else {
      ToastService.showError('Error al subir');
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onSurfaceLight = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    // Watch business owner status and rebuild tabs when it resolves
    final isOwnerAsync = ref.watch(isBusinessOwnerProvider);
    final isOwner = isOwnerAsync.valueOrNull ?? false;
    _initTabs(isOwner);

    final tabCtrl = _tabController;
    if (tabCtrl == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final tabs = <Tab>[
      const Tab(text: 'Tus Medios'),
      if (isOwner) const Tab(text: 'Negocio'),
      const Tab(text: 'Chats'),
    ];

    final tabViews = <Widget>[
      _PersonalTab(
        onShare: _onShare,
        onDelete: _onDelete,
        onSaveToGallery: _onSaveToGallery,
      ),
      if (isOwner)
        _BusinessTab(
          onShare: _onShare,
          onDelete: _onDelete,
          onSaveToGallery: _onSaveToGallery,
        ),
      _ChatsTab(
        onShare: _onShare,
        onSaveToGallery: _onSaveToGallery,
      ),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          'Media Manager',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: TabBar(
          controller: tabCtrl,
          labelColor: primary,
          unselectedLabelColor: onSurfaceLight,
          indicatorColor: primary,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          tabs: tabs,
        ),
      ),
      body: TabBarView(
        controller: tabCtrl,
        children: tabViews,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onUpload,
        backgroundColor: primary,
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
    final primary = Theme.of(context).colorScheme.primary;
    final mediaAsync = ref.watch(personalMediaProvider);
    return mediaAsync.when(
      data: (items) => MediaGrid(
        items: items,
        onShare: onShare,
        onDelete: onDelete,
        onSaveToGallery: onSaveToGallery,
      ),
      loading: () => Center(
        child: CircularProgressIndicator(color: primary),
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
    final primary = Theme.of(context).colorScheme.primary;
    final onSurfaceLight = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
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
                  color: onSurfaceLight.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  'Sin medios de negocio',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    color: onSurfaceLight,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Los medios de tu salon apareceran aqui',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: onSurfaceLight.withValues(alpha: 0.6),
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
      loading: () => Center(
        child: CircularProgressIndicator(color: primary),
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
    final primary = Theme.of(context).colorScheme.primary;
    final onSurfaceLight = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
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
                  color: onSurfaceLight.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  'Sin medios en chats',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    color: onSurfaceLight,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Las imagenes de tus conversaciones apareceran aqui',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: onSurfaceLight.withValues(alpha: 0.6),
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
      loading: () => Center(
        child: CircularProgressIndicator(color: primary),
      ),
      error: (err, _) => Center(
        child: Text('Error: $err', style: GoogleFonts.nunito()),
      ),
    );
  }
}
