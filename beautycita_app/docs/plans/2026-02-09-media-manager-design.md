# Media Manager Design

## Overview

A media management hub accessible from Settings. Three tabs: personal media, business media, chat media. LightX virtual studio results auto-save to device gallery.

## Navigation

Settings screen > "Media Manager" tile > `/media-manager` route. Three tabs via `TabBar`:

- **Tus Medios** (personal): LightX results, selfies, uploads
- **Negocio** (business, salon owners only): portfolio, client media, review images
- **Chats**: all media from chat threads grouped by thread

## Data Model

New `user_media` table indexes all media items:

```sql
CREATE TABLE user_media (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  media_type TEXT NOT NULL DEFAULT 'image' CHECK (media_type IN ('image','video')),
  source TEXT NOT NULL CHECK (source IN ('lightx','chat','upload','review','portfolio')),
  source_ref UUID,
  url TEXT NOT NULL,
  thumbnail_url TEXT,
  metadata JSONB DEFAULT '{}',
  section TEXT NOT NULL CHECK (section IN ('personal','business','chat')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_user_media_user_section ON user_media(user_id, section);
ALTER TABLE user_media ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users see own media" ON user_media FOR ALL USING (auth.uid() = user_id);
```

Chat media tab queries `chat_messages` directly (no duplication).

## Auto-Save Flow

When LightX returns a result in virtual studio:
1. Insert row into `user_media` (source=lightx, section=personal)
2. Download image bytes from result URL
3. Save to device gallery via `image_gallery_saver`
4. Show toast "Guardado en galeria"

## UI Layout

Each tab: vertical scroll, sections grouped by source type or thread. Grid of 3-column square thumbnails. Tap opens full-screen viewer with swipe + share/delete actions. Long-press for multi-select.

Business tab hidden for non-salon-owners. Shows CTA "Registra tu salon" for regular users.

## Files

**New:**
- `lib/screens/media_manager_screen.dart` - main screen with 3 tabs
- `lib/widgets/media_grid.dart` - reusable thumbnail grid
- `lib/widgets/media_viewer.dart` - full-screen image viewer
- `lib/providers/media_provider.dart` - Riverpod providers
- `lib/services/media_service.dart` - download, save, share, delete
- `supabase/migrations/20260209000000_user_media.sql` - table + RLS

**Modified:**
- `lib/screens/virtual_studio_screen.dart` - auto-save LightX results
- `lib/screens/settings_screen.dart` - add Media Manager tile
- `lib/config/routes.dart` - add /media-manager route
- `pubspec.yaml` - add image_gallery_saver, share_plus, path_provider

## New Packages
- `image_gallery_saver` - save to device gallery
- `share_plus` - native share sheet
- `path_provider` - temp file paths
