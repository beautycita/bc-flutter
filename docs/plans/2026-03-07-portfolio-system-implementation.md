# Portfolio System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a white-label personal website system for salons with before/after camera flow, 5 HTML themes, and portfolio management in both mobile and web.

**Architecture:** Hybrid static HTML + dynamic data. Portfolio pages are lightweight HTML/CSS templates served by nginx, hydrated via JS fetch from a Supabase public API endpoint. Management UI lives in the mobile app and web business portal. Data models in `beautycita_core`.

**Tech Stack:** Flutter (mobile + web), Supabase (DB + Storage + Edge Functions), vanilla HTML/CSS/JS (portfolio themes), nginx (routing), Riverpod (state), image_picker (camera)

---

## Task 1: Database Migration

**Files:**
- Create: `beautycita_app/supabase/migrations/20260307000000_portfolio_system.sql`

**Step 1: Write migration**

```sql
-- Portfolio system: new columns + tables
-- =========================================

-- 1. New columns on businesses
ALTER TABLE public.businesses
  ADD COLUMN IF NOT EXISTS portfolio_slug text UNIQUE,
  ADD COLUMN IF NOT EXISTS portfolio_public boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS portfolio_theme text NOT NULL DEFAULT 'portfolio',
  ADD COLUMN IF NOT EXISTS portfolio_bio text,
  ADD COLUMN IF NOT EXISTS portfolio_tagline text;

-- Auto-generate slug from name on insert (if not provided)
CREATE OR REPLACE FUNCTION public.generate_portfolio_slug()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.portfolio_slug IS NULL OR NEW.portfolio_slug = '' THEN
    NEW.portfolio_slug := lower(regexp_replace(
      regexp_replace(NEW.name, '[^a-zA-Z0-9\s-]', '', 'g'),
      '\s+', '-', 'g'
    ));
    -- Handle duplicates by appending random suffix
    WHILE EXISTS (SELECT 1 FROM public.businesses WHERE portfolio_slug = NEW.portfolio_slug AND id != NEW.id) LOOP
      NEW.portfolio_slug := NEW.portfolio_slug || '-' || substr(gen_random_uuid()::text, 1, 4);
    END LOOP;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER businesses_portfolio_slug
  BEFORE INSERT OR UPDATE OF name, portfolio_slug ON public.businesses
  FOR EACH ROW EXECUTE FUNCTION public.generate_portfolio_slug();

-- 2. New columns on staff
ALTER TABLE public.staff
  ADD COLUMN IF NOT EXISTS bio text,
  ADD COLUMN IF NOT EXISTS specialties text[];

-- 3. Portfolio photos table
CREATE TABLE IF NOT EXISTS public.portfolio_photos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  staff_id uuid REFERENCES public.staff(id) ON DELETE SET NULL,
  before_url text,
  after_url text NOT NULL,
  photo_type text NOT NULL DEFAULT 'after_only' CHECK (photo_type IN ('before_after', 'after_only')),
  service_category text,
  caption text,
  product_tags jsonb,
  sort_order integer NOT NULL DEFAULT 0,
  is_visible boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_portfolio_photos_business ON public.portfolio_photos(business_id);
CREATE INDEX idx_portfolio_photos_staff ON public.portfolio_photos(staff_id);
CREATE INDEX idx_portfolio_photos_visible ON public.portfolio_photos(business_id, is_visible) WHERE is_visible = true;

-- RLS for portfolio_photos
ALTER TABLE public.portfolio_photos ENABLE ROW LEVEL SECURITY;

-- Public can read visible photos from public portfolios
CREATE POLICY "Public read visible portfolio photos"
  ON public.portfolio_photos FOR SELECT
  USING (
    is_visible = true
    AND EXISTS (
      SELECT 1 FROM public.businesses b
      WHERE b.id = business_id AND b.portfolio_public = true
    )
  );

-- Business owner can CRUD their own photos
CREATE POLICY "Owner manages portfolio photos"
  ON public.portfolio_photos FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.businesses b
      WHERE b.id = business_id
      AND b.owner_id = auth.uid()
    )
  );

-- 4. Portfolio agreements table
CREATE TABLE IF NOT EXISTS public.portfolio_agreements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  agreement_type text NOT NULL,
  agreement_version text NOT NULL,
  accepted_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(business_id, agreement_type, agreement_version)
);

ALTER TABLE public.portfolio_agreements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Owner manages own agreements"
  ON public.portfolio_agreements FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.businesses b
      WHERE b.id = business_id AND b.owner_id = auth.uid()
    )
  );

-- 5. Generate slugs for existing businesses
UPDATE public.businesses SET portfolio_slug = portfolio_slug WHERE portfolio_slug IS NULL;
```

**Step 2: Verify migration syntax**

Run: `cat beautycita_app/supabase/migrations/20260307000000_portfolio_system.sql | head -5`

**Step 3: Commit**

```bash
git add beautycita_app/supabase/migrations/20260307000000_portfolio_system.sql
git commit -m "feat: portfolio system DB migration — photos, agreements, slug generation"
```

---

## Task 2: Data Models in beautycita_core

**Files:**
- Create: `packages/beautycita_core/lib/src/models/portfolio_photo.dart`
- Create: `packages/beautycita_core/lib/src/models/portfolio_config.dart`
- Modify: `packages/beautycita_core/lib/src/models/provider.dart`
- Modify: `packages/beautycita_core/lib/beautycita_core.dart` (export new models)

**Step 1: Create PortfolioPhoto model**

```dart
class PortfolioPhoto {
  final String id;
  final String businessId;
  final String? staffId;
  final String? beforeUrl;
  final String afterUrl;
  final String photoType; // 'before_after' or 'after_only'
  final String? serviceCategory;
  final String? caption;
  final Map<String, dynamic>? productTags;
  final int sortOrder;
  final bool isVisible;
  final DateTime createdAt;

  const PortfolioPhoto({
    required this.id,
    required this.businessId,
    this.staffId,
    this.beforeUrl,
    required this.afterUrl,
    required this.photoType,
    this.serviceCategory,
    this.caption,
    this.productTags,
    this.sortOrder = 0,
    this.isVisible = true,
    required this.createdAt,
  });

  factory PortfolioPhoto.fromJson(Map<String, dynamic> json) => PortfolioPhoto(
    id: json['id'] as String,
    businessId: json['business_id'] as String,
    staffId: json['staff_id'] as String?,
    beforeUrl: json['before_url'] as String?,
    afterUrl: json['after_url'] as String,
    photoType: json['photo_type'] as String? ?? 'after_only',
    serviceCategory: json['service_category'] as String?,
    caption: json['caption'] as String?,
    productTags: json['product_tags'] as Map<String, dynamic>?,
    sortOrder: json['sort_order'] as int? ?? 0,
    isVisible: json['is_visible'] as bool? ?? true,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'business_id': businessId,
    'staff_id': staffId,
    'before_url': beforeUrl,
    'after_url': afterUrl,
    'photo_type': photoType,
    'service_category': serviceCategory,
    'caption': caption,
    'product_tags': productTags,
    'sort_order': sortOrder,
    'is_visible': isVisible,
    'created_at': createdAt.toIso8601String(),
  };
}
```

**Step 2: Create PortfolioConfig model**

```dart
class PortfolioConfig {
  final String? slug;
  final bool isPublic;
  final String theme;
  final String? bio;
  final String? tagline;

  const PortfolioConfig({
    this.slug,
    this.isPublic = false,
    this.theme = 'portfolio',
    this.bio,
    this.tagline,
  });

  factory PortfolioConfig.fromJson(Map<String, dynamic> json) => PortfolioConfig(
    slug: json['portfolio_slug'] as String?,
    isPublic: json['portfolio_public'] as bool? ?? false,
    theme: json['portfolio_theme'] as String? ?? 'portfolio',
    bio: json['portfolio_bio'] as String?,
    tagline: json['portfolio_tagline'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'portfolio_slug': slug,
    'portfolio_public': isPublic,
    'portfolio_theme': theme,
    'portfolio_bio': bio,
    'portfolio_tagline': tagline,
  };
}
```

**Step 3: Add portfolio fields to Provider model**

In `packages/beautycita_core/lib/src/models/provider.dart`, add fields:
- `portfolioSlug`, `portfolioPublic`, `portfolioTheme`, `portfolioBio`, `portfolioTagline`
- Update `fromJson` and `toJson`

**Step 4: Export new models from barrel file**

**Step 5: Commit**

```bash
git add packages/beautycita_core/
git commit -m "feat: portfolio data models — PortfolioPhoto, PortfolioConfig"
```

---

## Task 3: Portfolio Photo Service (Mobile App)

**Files:**
- Create: `beautycita_app/lib/services/portfolio_service.dart`
- Create: `beautycita_app/lib/providers/portfolio_provider.dart`

**Step 1: Create PortfolioService**

Handles:
- Upload before/after photos to `staff-media` storage bucket
- Insert/update/delete `portfolio_photos` rows
- Auto-correct images (brightness, saturation, exposure) using Flutter image processing
- Select best image from a set (sharpness score)
- Reorder photos
- Toggle visibility
- Bulk upload from gallery

Follow the upload pattern from `media_service.dart:210-295`:
- `client.storage.from('staff-media').uploadBinary(fileName, bytes, ...)`
- `client.from('portfolio_photos').insert(row).select().single()`

**Step 2: Create portfolio providers**

```dart
// Photos for a business
final portfolioPhotosProvider = FutureProvider.autoDispose
    .family<List<PortfolioPhoto>, String>((ref, businessId) async {
  final data = await SupabaseClientService.client
      .from('portfolio_photos')
      .select()
      .eq('business_id', businessId)
      .order('sort_order');
  return (data as List).map((e) => PortfolioPhoto.fromJson(e)).toList();
});

// Portfolio config for current business
final portfolioConfigProvider = FutureProvider.autoDispose<PortfolioConfig?>((ref) async {
  final biz = await ref.watch(currentBusinessProvider.future);
  if (biz == null) return null;
  return PortfolioConfig.fromJson(biz);
});
```

**Step 3: Commit**

```bash
git add beautycita_app/lib/services/portfolio_service.dart beautycita_app/lib/providers/portfolio_provider.dart
git commit -m "feat: portfolio service + providers — upload, CRUD, auto-correct"
```

---

## Task 4: Before/After Camera Screen (Mobile App)

**Files:**
- Create: `beautycita_app/lib/screens/business/portfolio_camera_screen.dart`

**Step 1: Build the camera screen**

Uses `image_picker` (already in pubspec). Screen flow:

1. First-time tips overlay (stored in SharedPreferences, show once)
   - Illustration of model on tape X with backdrop
   - "Para mejores resultados:" tips
   - Dismiss button

2. Before capture:
   - "¿La clienta autoriza la foto del antes?" — Yes/No
   - If yes: open camera, take as many as they want, show grid of thumbnails
   - If no: skip to after capture

3. After capture:
   - Open camera, take as many as they want
   - Show grid of thumbnails

4. System selects best from each set (sharpest image)
   - Stylist can tap to override selection
   - Auto-correct applied to selected images

5. Tagging:
   - Service category (dropdown from business services)
   - Staff member (dropdown from staff list)
   - Caption (optional text)
   - Product tags (optional, for future POS)

6. Save → calls `PortfolioService.uploadBeforeAfter()`

**Step 2: Wire camera launch from appointment flow**

Modify `beautycita_app/lib/screens/business/` appointment-related screens to add a "Tomar fotos" button when appointment is near/complete.

**Step 3: Push notification triggers**

Create edge function or modify existing appointment notification logic:
- 5-10 min before: "Tu cita con [client] es pronto. ¿Foto del antes?"
- On complete: "¡Servicio completado! ¿Foto del después?"

**Step 4: Commit**

```bash
git add beautycita_app/lib/screens/business/portfolio_camera_screen.dart
git commit -m "feat: before/after camera screen with guided capture + auto-correct"
```

---

## Task 5: Portfolio Management Screen (Mobile App)

**Files:**
- Create: `beautycita_app/lib/screens/business/portfolio_management_screen.dart`
- Modify: `beautycita_app/lib/screens/business/business_settings_screen.dart` (add portfolio section/link)

**Step 1: Build portfolio management screen**

Sections:
1. **Settings card** — public/private toggle, theme picker (5 options with preview), slug editor, bio/tagline text fields
2. **Photo grid** — draggable reorder, visibility toggle, delete, edit caption/tags, filter by staff member
3. **Bulk upload button** — opens gallery picker for existing photos
4. **Social import button** — pulls from discovered_salons.portfolio_images if available
5. **Team bios** — edit bio and specialties per staff member
6. **Hiring slot toggle** — "Estamos buscando..." on/off
7. **Portfolio agreement** — must accept before toggling public

Follow patterns from `business_settings_screen.dart` for card layout, form fields, save logic.
Follow patterns from `business_staff_screen.dart:420-441` for image picker + upload.

**Step 2: Add entry point in business settings**

Add a "Portafolio" card/button in `business_settings_screen.dart` that navigates to the portfolio management screen.

**Step 3: Commit**

```bash
git add beautycita_app/lib/screens/business/portfolio_management_screen.dart beautycita_app/lib/screens/business/business_settings_screen.dart
git commit -m "feat: portfolio management screen — settings, photos, team bios, import"
```

---

## Task 6: Portfolio Management Page (Web Business Portal)

**Files:**
- Create: `beautycita_web/lib/pages/business/biz_portfolio_page.dart`
- Modify: `beautycita_web/lib/config/router.dart` (add route)
- Modify: `beautycita_web/lib/shells/business_shell.dart` (add nav item)

**Step 1: Build web portfolio page**

Desktop-first layout. Same capabilities as mobile but designed for wide screens:
- Left panel: settings (toggle, theme picker, slug, bio, tagline)
- Right panel: photo grid with drag-reorder, bulk upload, filters
- Bottom section: team bios editor

Follow patterns from `biz_staff_page.dart` for layout, file picker, upload.
DO NOT copy from mobile — design for desktop independently.

**Step 2: Add route**

In `router.dart`, add under business shell:
```dart
GoRoute(
  path: 'portfolio',
  builder: (context, state) => const BizPortfolioPage(),
),
```

**Step 3: Add nav item in business shell sidebar**

Add "Portafolio" with icon to the business navigation.

**Step 4: Commit**

```bash
git add beautycita_web/lib/pages/business/biz_portfolio_page.dart beautycita_web/lib/config/router.dart beautycita_web/lib/shells/business_shell.dart
git commit -m "feat: web portfolio management page — desktop-first, full CRUD"
```

---

## Task 7: Portfolio Public API (Edge Function)

**Files:**
- Create: `beautycita_app/supabase/functions/portfolio-public/index.ts`

**Step 1: Build the edge function**

Endpoint: `GET /portfolio-public?slug=salon-luna`

Returns JSON with all public portfolio data:
```typescript
{
  salon: { name, tagline, bio, photo_url, phone, whatsapp, address, city,
           website, instagram_handle, facebook_url, hours, lat, lng },
  theme: "portfolio",
  team: [{ first_name, last_name, avatar_url, bio, specialties,
           avg_services_week, average_rating, total_reviews, photo_count }],
  photos: [{ id, staff_id, before_url, after_url, photo_type,
             service_category, caption, product_tags, created_at }],
  services: [{ name, price, duration, category }],
  reviews: [{ rating, comment, client_name, created_at, staff_id }]
}
```

- Check `portfolio_public = true` first, return 404 if not
- Only return `is_visible = true` photos
- Calculate `avg_services_week` from appointments table
- Calculate `photo_count` per staff member
- No auth required (public endpoint)
- Cache-Control headers for performance

**Step 2: Commit**

```bash
git add beautycita_app/supabase/functions/portfolio-public/
git commit -m "feat: public portfolio API endpoint — returns full salon data for themes"
```

---

## Task 8: Portfolio HTML Themes

**Files:**
- Create: `beautycita_web/web/portfolio/portfolio.html`
- Create: `beautycita_web/web/portfolio/team-builder.html`
- Create: `beautycita_web/web/portfolio/storefront.html`
- Create: `beautycita_web/web/portfolio/gallery.html`
- Create: `beautycita_web/web/portfolio/local.html`
- Create: `beautycita_web/web/portfolio/shared.js` (data fetch + hydration)
- Create: `beautycita_web/web/portfolio/shared.css` (common base styles)

**Step 1: Build shared JS**

```javascript
// Fetch portfolio data from edge function
const slug = window.location.pathname.split('/s/')[1]?.split('?')[0];
const staffFilter = new URLSearchParams(window.location.search).get('staff');

fetch(`${SUPABASE_URL}/functions/v1/portfolio-public?slug=${slug}`)
  .then(r => r.ok ? r.json() : Promise.reject('not_found'))
  .then(data => hydrate(data, staffFilter))
  .catch(() => showNotAvailable());
```

Hydration populates DOM elements by data attribute: `[data-portfolio="salon-name"]`, `[data-portfolio="team"]`, etc. Sections with no data get `display: none`.

**Step 2: Build 5 themes**

Each theme is a complete HTML file with:
- Inline `<style>` for theme-specific CSS
- `<link>` to `shared.css` for base styles
- `<script src="shared.js">` for data fetch
- Semantic HTML structure with `data-portfolio` attributes
- Before/after slider component (CSS-only with `<input type="range">`)
- Responsive (desktop-first, works on mobile)
- Meta tags for SEO + social sharing (og:image, og:title, etc.)
- Tiny "powered by BeautyCita" footer

Theme visual differences per design doc:
- **Portfolio**: Solo-focused, big hero, personal bio prominent
- **Team Builder**: Team grid, stats, hiring slot
- **Storefront**: Services/prices lead, catalog feel
- **Gallery**: Minimal text, masonry photo grid dominates
- **Local**: Map prominent, reviews featured, warm feel

**Step 3: Commit**

```bash
git add beautycita_web/web/portfolio/
git commit -m "feat: 5 portfolio HTML themes — portfolio, team-builder, storefront, gallery, local"
```

---

## Task 9: Nginx Configuration for Portfolio Routes

**Step 1: Add nginx location block on production server**

```nginx
# Portfolio pages — /s/<slug>
location ~ ^/s/([a-z0-9-]+)$ {
    # Fetch the theme for this slug from Supabase, serve appropriate template
    # For MVP: serve a generic loader that fetches theme + data client-side
    try_files /portfolio/loader.html =404;
}
```

**Step 2: Create loader.html**

A minimal HTML page that:
1. Extracts slug from URL
2. Fetches portfolio data (which includes the theme name)
3. Loads the correct theme template dynamically

This avoids needing server-side logic to pick the theme — it's all client-side.

**Step 3: Upload portfolio files to server**

```bash
scp -r beautycita_web/web/portfolio/ www-bc:/var/www/beautycita.com/frontend/dist/portfolio/
```

**Step 4: Update nginx config on server**

```bash
ssh www-bc "echo 'JUs3f2m3Fa' | sudo -S nginx -t && echo 'JUs3f2m3Fa' | sudo -S systemctl reload nginx"
```

**Step 5: Commit any local config changes**

---

## Task 10: Social Import Pipeline

**Files:**
- Create: `beautycita_app/lib/services/portfolio_import_service.dart`

**Step 1: Build import service**

Two import sources:

1. **discovered_salons.portfolio_images** — for salons that came through the scraper pipeline
   - Query `discovered_salons` by phone/name match
   - Download images from URLs
   - Upload to storage
   - Create `portfolio_photos` rows (all `after_only` type)
   - Present to owner for approval before making visible

2. **Manual bulk import** — owner selects photos from phone gallery
   - Uses `image_picker.pickMultiImage()`
   - Upload each to storage
   - Create rows with `is_visible = false` until owner reviews

**Step 2: Wire into portfolio management screen**

Add "Importar fotos" button that shows import sources:
- "Desde fotos descubiertas" (if discovered_salons match exists)
- "Desde galería" (always available)

**Step 3: Commit**

```bash
git add beautycita_app/lib/services/portfolio_import_service.dart
git commit -m "feat: portfolio import — discovered salons + gallery bulk upload"
```

---

## Task 11: Portfolio Agreement

**Files:**
- Modify: `beautycita_app/lib/screens/legal_screens.dart` (add portfolio agreement text)
- Wire into portfolio management screen — must accept before toggling public

**Step 1: Add agreement text**

Spanish legal text covering:
- Photo usage rights (salon owns uploaded content, grants BeautyCita display license)
- Content standards (no inappropriate content, professional photos only)
- Client consent obligations (salon responsible for getting client permission)
- Right to remove content that violates standards

**Step 2: Wire acceptance check**

When salon owner tries to toggle `portfolio_public = true`:
1. Check if they've accepted latest agreement version
2. If not, show agreement with checkbox
3. On accept, insert into `portfolio_agreements`, then toggle public

**Step 3: Commit**

```bash
git add beautycita_app/lib/screens/legal_screens.dart
git commit -m "feat: portfolio agreement — required before going public"
```

---

## Task 12: Integration Testing & Polish

**Step 1: Test full flow on mobile**
- Create a test salon → upload before/after photos → set theme → toggle public → visit URL

**Step 2: Test full flow on web**
- Open business portal → portfolio tab → manage photos → preview themes

**Step 3: Test all 5 themes**
- Verify each theme renders correctly with: full data, partial data (solo stylist), minimal data (name only)

**Step 4: Test privacy**
- Verify private portfolio returns "not available" page
- Verify RLS blocks unauthorized photo access

**Step 5: Test camera flow**
- Walk through appointment → notification → before capture → after capture → tag → save

**Step 6: Final commit**

```bash
git commit -m "feat: portfolio system complete — themes, camera, management, public pages"
```

---

## Dependency Order

```
Task 1 (DB migration)
  └→ Task 2 (models)
       └→ Task 3 (service + providers)
            ├→ Task 4 (camera screen)
            ├→ Task 5 (mobile management)
            ├→ Task 6 (web management)
            └→ Task 7 (public API)
                 └→ Task 8 (HTML themes)
                      └→ Task 9 (nginx)
Task 10 (social import) — after Task 3
Task 11 (agreement) — after Task 5
Task 12 (testing) — after all
```

Tasks 4, 5, 6 can run in parallel after Task 3.
Task 8 needs Task 7 (API) to test against.
