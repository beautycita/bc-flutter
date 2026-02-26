# BeautyCita Web — Marketing Site + Salon Registration (Phase 1)

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a cinematic, mobile-first marketing website for BeautyCita that converts visitors into app users and salon partners — with looping background videos, the APK's rose-gold-cream aesthetic, and a polished salon registration flow that replaces the current edge-function HTML form.

**Architecture:** Flutter web app, single-page marketing layout with smooth scroll sections + separate routes for salon registration, privacy policy, and terms. Media served from Cloudflare R2 bucket. Deployed to the existing beautycita.com server replacing the old React frontend. Salon registration POSTs to the existing `salon-registro` Supabase edge function.

**Tech Stack:** Flutter 3.38 (web target), Dart, Google Fonts (Poppins + Nunito), Supabase client for salon registration, video_player_web for background videos, Cloudflare R2 for media CDN.

---

## Context for the Implementing Engineer

### Brand Theme (must match APK exactly)

| Token | Value | Usage |
|-------|-------|-------|
| `primaryRose` | `#C2185B` | CTAs, headings, accents |
| `secondaryGold` | `#FFB300` | Highlights, badges, stars |
| `surfaceCream` | `#FFF8F0` | Page background |
| `backgroundWhite` | `#FFFFFF` | Cards, elevated surfaces |
| `textDark` | `#212121` | Body text |
| `textLight` | `#757575` | Secondary text |
| `dividerLight` | `#EEEEEE` | Separators |
| Primary gradient | `#C2185B` to `#D81B60` | Buttons, hero overlay |
| Accent gradient | `#FFB300` to `#FFC107` | Gold accents |

**Fonts:** Poppins (headings, weights 600-700), Nunito (body, weights 400-600).

### R2 Media Bucket

- **Public URL:** `https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev`
- **Videos (use these as backgrounds):**
  - `media/vid/hero0-mobile.mp4` (0.9 MB) — hero section, salon interior
  - `media/vid/salon-mobile.mp4` (0.9 MB) — salon wide shot
  - `media/vid/stylist-mobile.mp4` (0.5 MB) — stylist working
  - `media/vid/makeup-mobile.mp4` (0.3 MB) — makeup application
  - `media/vid/dancing-mobile.mp4` (3.9 MB) — happy client
  - `media/vid/lavar-mobile.mp4` (0.8 MB) — hair washing
  - `media/vid/massage-mobile.mp4` (0.4 MB) — massage/spa
  - `media/vid/event-mobile.mp4` (0.6 MB) — event/celebration
  - `beautycita/videos/bcStartup.mp4` (24.7 MB) — brand intro (desktop only)
  - `beautycita/videos/bcApp.mp4` (7.9 MB) — app demo
  - `beautycita/videos/happy-clients.mp4` (6.4 MB) — testimonial vibes
  - `beautycita/videos/pastels.mp4` (4.9 MB) — pastel beauty shots
- **Poster images (video fallbacks):**
  - `media/vid/hero0-poster.jpg`, `salon-poster.jpg`, `stylist-poster.jpg`, etc.
- **Brand images:**
  - `media/brand/logo.png` — logo
  - `media/brand/aphrodite0.png` — mascot (1.8 MB)
  - `media/brand/2.png` through `media/brand/10.png` — brand imagery
- **Audio:**
  - `audio/backgroundsong1.mp3` (2.3 MB), `audio/backgroundsong2.mp3` (2.5 MB)

### Server / Deployment

- **Server:** beautycita.com (nginx + Let's Encrypt SSL)
- **SSH:** `ssh www-bc` (user: www-data, key: ~/.ssh/beautycita_key)
- **Current frontend path:** `/var/www/beautycita.com/frontend/dist/`
- **Nginx:** SPA routing (`try_files $uri /index.html`), Supabase at `/supabase/`
- **Supabase edge functions:** Already deployed at `https://beautycita.com/supabase/functions/v1/`
  - `salon-registro` — accepts GET (HTML form) and POST (create business)
- **Deploy strategy:** `flutter build web --release`, rsync `build/web/` to server

### Product Philosophy (from the design spec)

BeautyCita is NOT a booking app. It is an **intelligent booking agent**. The website must communicate this distinction clearly. Key messaging:

1. You don't search. You tell us what you want. We give you the answer.
2. 4-6 taps, under 30 seconds, zero keyboard.
3. Service type drives everything — each service has its own intelligence.
4. Transport included — Uber round-trip scheduled automatically.
5. Salons onboard in 60 seconds via WhatsApp. Zero cost. Clients arrive.

---

## Site Map

```
/                 — Single-page landing (6 scroll sections)
/registro         — Salon registration form (standalone page)
/registro?ref=ID  — Salon registration with referral from invite
/privacidad       — Privacy policy
/terminos         — Terms of service
```

## Page Layout: Landing (`/`)

```
┌─────────────────────────────────────────────┐
│  NAV BAR (floating, transparent → solid)     │
│  Logo        Salones | Descargar | Registrar │
├─────────────────────────────────────────────┤
│  HERO (100vh, video bg + dark rose overlay)  │
│                                              │
│  "Tu agente de                               │
│   belleza inteligente"                       │
│                                              │
│  "No buscas. No filtras. Reservas."          │
│                                              │
│  [DESCARGAR APP]  [SOY SALON]               │
│                                              │
├─────────────────────────────────────────────┤
│  HOW IT WORKS (cream bg)                     │
│                                              │
│  "Reserva en 30 segundos"                    │
│                                              │
│  ┌──────┐  ┌──────┐  ┌──────┐              │
│  │ vid  │  │ vid  │  │ vid  │              │
│  │ bg   │  │ bg   │  │ bg   │              │
│  │      │  │      │  │      │              │
│  │Elige │  │El    │  │Un    │              │
│  │tu    │  │agente│  │tap.  │              │
│  │ser-  │  │elige │  │Reser-│              │
│  │vicio │  │por ti│  │vado. │              │
│  └──────┘  └──────┘  └──────┘              │
│                                              │
├─────────────────────────────────────────────┤
│  FOR CLIENTS (video bg + filter, side-by-side)│
│                                              │
│  [video: stylist]  │ "Inteligencia que      │
│                    │  entiende belleza"       │
│                    │                          │
│                    │  - Hora inferida         │
│                    │  - Uber incluido         │
│                    │  - 3 mejores opciones    │
│                    │                          │
│                    │  [DESCARGAR]             │
│                                              │
├─────────────────────────────────────────────┤
│  FOR SALONS (rose gradient bg)               │
│                                              │
│  "295+ salones ya reciben clientas"          │
│                                              │
│  60 seg     $0         WhatsApp              │
│  registro   siempre    reservas              │
│                                              │
│  [REGISTRAR MI SALON]                        │
│                                              │
├─────────────────────────────────────────────┤
│  DOWNLOAD (cream bg, centered)               │
│                                              │
│  App mockup image    QR code                 │
│                                              │
│  [DESCARGAR APK]                             │
│                                              │
│  "Proximamente en App Store y Google Play"   │
│                                              │
├─────────────────────────────────────────────┤
│  FOOTER                                      │
│  Logo  |  Privacidad  |  Terminos  |  IG    │
│  © 2026 BeautyCita                           │
└─────────────────────────────────────────────┘
```

## Page Layout: Salon Registration (`/registro`)

```
┌─────────────────────────────────────────────┐
│  NAV BAR (solid rose)                        │
│  Logo              ← Inicio                  │
├─────────────────────────────────────────────┤
│  HEADER (rose gradient)                      │
│                                              │
│  "Registra tu salon"                         │
│  "Recibe clientas nuevas por BeautyCita"     │
│  [Gratis · 60 segundos · Sin tarjeta]        │
│                                              │
├─────────────────────────────────────────────┤
│  FORM (card on cream bg, max-width 480px)    │
│                                              │
│  Nombre del salon  [___________________]     │
│  WhatsApp          [+52 _______________]     │
│  Direccion         [___________________]     │
│                                              │
│  Que servicios ofreces?                      │
│  [Unas] [Cabello] [Pestanas] [Maquillaje]  │
│  [Facial] [Spa] [Especializado]             │
│                                              │
│  [REGISTRARME GRATIS]                        │
│                                              │
│  Al registrarte aceptas los terminos...      │
├─────────────────────────────────────────────┤
│  SUCCESS (replaces form on submit)           │
│  ✓ Bienvenido a BeautyCita!                 │
│  Tu salon ya esta visible para clientas...   │
└─────────────────────────────────────────────┘
```

---

## Task 1: Create Flutter Web Project

**Files:** Create project at `/home/bc/futureBeauty/beautycita-web/`

**Step 1: Create the project**

```bash
cd /home/bc/futureBeauty
flutter create beautycita_web --org com.beautycita --platforms web
cd beautycita_web
```

**Step 2: Add dependencies to `pubspec.yaml`**

```yaml
dependencies:
  flutter:
    sdk: flutter
  google_fonts: ^6.1.0
  url_launcher: ^6.2.0
  supabase_flutter: ^2.3.0
  flutter_dotenv: ^5.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
```

Run: `flutter pub get`

**Step 3: Create `.env` file**

```
SUPABASE_URL=https://beautycita.com/supabase
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0
R2_PUBLIC_URL=https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev
```

**Step 4: Configure `web/index.html`**

Replace the default `web/index.html` with proper meta tags, Open Graph, Google Fonts preconnect, and the BeautyCita branding. Set `<title>BeautyCita - Tu agente de belleza inteligente</title>`. Add Google Analytics tag `G-TD6W79YRLJ`.

**Step 5: Initialize git**

```bash
cd /home/bc/futureBeauty/beautycita_web
git init
git add .
git commit -m "feat: init flutter web project for beautycita-web"
```

**Step 6: Verify**

```bash
flutter build web --release
```

Expected: Build succeeds, `build/web/` contains `index.html`.

---

## Task 2: Create Theme System

**Files:**
- Create: `lib/theme/colors.dart`
- Create: `lib/theme/typography.dart`
- Create: `lib/theme/theme.dart`

**Step 1: Create `lib/theme/colors.dart`**

```dart
import 'package:flutter/material.dart';

class BCColors {
  BCColors._();

  static const Color primaryRose = Color(0xFFC2185B);
  static const Color primaryRoseLight = Color(0xFFD81B60);
  static const Color secondaryGold = Color(0xFFFFB300);
  static const Color secondaryGoldLight = Color(0xFFFFC107);
  static const Color surfaceCream = Color(0xFFFFF8F0);
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF212121);
  static const Color textLight = Color(0xFF757575);
  static const Color dividerLight = Color(0xFFEEEEEE);
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFD32F2F);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryRose, primaryRoseLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroOverlay = LinearGradient(
    colors: [
      Color(0xCC1A0A10), // dark rose-black 80%
      Color(0x991A0A10), // dark rose-black 60%
    ],
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [secondaryGold, secondaryGoldLight],
  );
}
```

**Step 2: Create `lib/theme/typography.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class BCTypography {
  BCTypography._();

  // Display — hero headlines
  static TextStyle displayLarge = GoogleFonts.poppins(
    fontSize: 56,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    height: 1.1,
    letterSpacing: -1.5,
  );

  static TextStyle displayMedium = GoogleFonts.poppins(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    color: BCColors.textDark,
    height: 1.15,
    letterSpacing: -1.0,
  );

  // Headings
  static TextStyle h1 = GoogleFonts.poppins(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: BCColors.textDark,
    height: 1.2,
  );

  static TextStyle h2 = GoogleFonts.poppins(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: BCColors.textDark,
    height: 1.3,
  );

  static TextStyle h3 = GoogleFonts.poppins(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: BCColors.textDark,
    height: 1.4,
  );

  // Body
  static TextStyle bodyLarge = GoogleFonts.nunito(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    color: BCColors.textDark,
    height: 1.6,
  );

  static TextStyle body = GoogleFonts.nunito(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: BCColors.textDark,
    height: 1.5,
  );

  static TextStyle bodySmall = GoogleFonts.nunito(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: BCColors.textLight,
    height: 1.5,
  );

  // Labels
  static TextStyle label = GoogleFonts.nunito(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: BCColors.textDark,
  );

  static TextStyle button = GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );
}
```

**Step 3: Create `lib/theme/theme.dart`**

```dart
import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';

export 'colors.dart';
export 'typography.dart';

class BCTheme {
  BCTheme._();

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: BCColors.surfaceCream,
    colorScheme: const ColorScheme.light(
      primary: BCColors.primaryRose,
      secondary: BCColors.secondaryGold,
      surface: BCColors.backgroundWhite,
      onPrimary: Colors.white,
      onSecondary: BCColors.textDark,
      onSurface: BCColors.textDark,
    ),
  );
}
```

**Step 4: Commit**

```bash
git add lib/theme/
git commit -m "feat: add brand theme system (colors, typography)"
```

---

## Task 3: Create Shared Widgets

**Files:**
- Create: `lib/widgets/video_background.dart`
- Create: `lib/widgets/bc_button.dart`
- Create: `lib/widgets/nav_bar.dart`
- Create: `lib/widgets/footer.dart`
- Create: `lib/widgets/section_container.dart`

**Step 1: Create `lib/widgets/video_background.dart`**

A widget that plays a looping, muted video behind content with a gradient overlay. On web, use an HTML `<video>` element via `dart:html` for best performance (Flutter's video_player on web has overhead). Falls back to a poster image while loading.

```dart
import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import '../theme/theme.dart';

class VideoBackground extends StatefulWidget {
  final String videoUrl;
  final String? posterUrl;
  final Widget child;
  final Gradient? overlay;

  const VideoBackground({
    super.key,
    required this.videoUrl,
    this.posterUrl,
    required this.child,
    this.overlay,
  });

  @override
  State<VideoBackground> createState() => _VideoBackgroundState();
}

class _VideoBackgroundState extends State<VideoBackground> {
  late final String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'video-bg-${widget.videoUrl.hashCode}';

    // Register HTML video element
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int id) {
      final video = html.VideoElement()
        ..src = widget.videoUrl
        ..autoplay = true
        ..loop = true
        ..muted = true
        ..setAttribute('playsinline', 'true')
        ..style.objectFit = 'cover'
        ..style.width = '100%'
        ..style.height = '100%';
      if (widget.posterUrl != null) {
        video.poster = widget.posterUrl!;
      }
      video.play();
      return video;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        HtmlElementView(viewType: _viewId),
        // Overlay gradient
        Container(
          decoration: BoxDecoration(
            gradient: widget.overlay ?? BCColors.heroOverlay,
          ),
        ),
        // Content
        widget.child,
      ],
    );
  }
}
```

**Step 2: Create `lib/widgets/bc_button.dart`**

Two variants: primary (rose gradient, white text) and outline (transparent, rose border).

```dart
import 'package:flutter/material.dart';
import '../theme/theme.dart';

enum BCButtonVariant { primary, outline, gold }

class BCButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final BCButtonVariant variant;
  final IconData? icon;
  final bool loading;

  const BCButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = BCButtonVariant.primary,
    this.icon,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isPrimary = variant == BCButtonVariant.primary;
    final isGold = variant == BCButtonVariant.gold;
    final isOutline = variant == BCButtonVariant.outline;

    return Container(
      decoration: isPrimary
          ? BoxDecoration(
              gradient: BCColors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: BCColors.primaryRose.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            )
          : isGold
              ? BoxDecoration(
                  gradient: BCColors.accentGradient,
                  borderRadius: BorderRadius.circular(14),
                )
              : BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(14),
                ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: BCTypography.button.copyWith(
                          color: isOutline ? Colors.white : Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
```

**Step 3: Create `lib/widgets/nav_bar.dart`**

Floating nav bar that starts transparent and becomes solid on scroll. Logo left, links right. Mobile: hamburger menu.

```dart
import 'package:flutter/material.dart';
import '../theme/theme.dart';

class BCNavBar extends StatelessWidget {
  final bool isScrolled;
  final VoidCallback? onSalonesPressed;
  final VoidCallback? onDescargarPressed;
  final VoidCallback? onRegistrarPressed;

  const BCNavBar({
    super.key,
    this.isScrolled = false,
    this.onSalonesPressed,
    this.onDescargarPressed,
    this.onRegistrarPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: isScrolled ? BCColors.backgroundWhite.withOpacity(0.95) : Colors.transparent,
        boxShadow: isScrolled
            ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
            : [],
      ),
      child: Row(
        children: [
          // Logo
          Text(
            'BeautyCita',
            style: BCTypography.h2.copyWith(
              color: isScrolled ? BCColors.primaryRose : Colors.white,
            ),
          ),
          const Spacer(),
          if (!isMobile) ...[
            _NavLink('Salones', onSalonesPressed, isScrolled),
            const SizedBox(width: 32),
            _NavLink('Descargar', onDescargarPressed, isScrolled),
            const SizedBox(width: 24),
            BCButton(
              label: 'SOY SALON',
              onPressed: onRegistrarPressed,
              variant: isScrolled ? BCButtonVariant.primary : BCButtonVariant.outline,
            ),
          ] else ...[
            IconButton(
              icon: Icon(
                Icons.menu,
                color: isScrolled ? BCColors.textDark : Colors.white,
              ),
              onPressed: () => _showMobileMenu(context),
            ),
          ],
        ],
      ),
    );
  }

  void _showMobileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: BCColors.backgroundWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: BCColors.dividerLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.storefront, color: BCColors.primaryRose),
              title: Text('Para Salones', style: BCTypography.body),
              onTap: () { Navigator.pop(ctx); onSalonesPressed?.call(); },
            ),
            ListTile(
              leading: const Icon(Icons.download, color: BCColors.primaryRose),
              title: Text('Descargar App', style: BCTypography.body),
              onTap: () { Navigator.pop(ctx); onDescargarPressed?.call(); },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: BCButton(
                label: 'REGISTRAR MI SALON',
                onPressed: () { Navigator.pop(ctx); onRegistrarPressed?.call(); },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isDark;

  const _NavLink(this.label, this.onTap, this.isDark);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: BCTypography.label.copyWith(
          color: isDark ? BCColors.textDark : Colors.white,
        ),
      ),
    );
  }
}
```

**Step 4: Create `lib/widgets/footer.dart`**

Simple footer with logo, legal links, social links, copyright.

```dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/theme.dart';

class BCFooter extends StatelessWidget {
  const BCFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BCColors.textDark,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        children: [
          Text(
            'BeautyCita',
            style: BCTypography.h2.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Tu agente de belleza inteligente',
            style: BCTypography.bodySmall.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 24,
            children: [
              _footerLink('Privacidad', '/privacidad', context),
              _footerLink('Terminos', '/terminos', context),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '© 2026 BeautyCita. Todos los derechos reservados.',
            style: BCTypography.bodySmall.copyWith(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _footerLink(String label, String route, BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).pushNamed(route),
      child: Text(
        label,
        style: BCTypography.label.copyWith(color: Colors.white70),
      ),
    );
  }
}
```

**Step 5: Create `lib/widgets/section_container.dart`**

Wrapper for consistent section padding and max-width.

```dart
import 'package:flutter/material.dart';
import '../theme/theme.dart';

class SectionContainer extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final EdgeInsets? padding;
  final double maxWidth;

  const SectionContainer({
    super.key,
    required this.child,
    this.backgroundColor,
    this.padding,
    this.maxWidth = 1200,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor ?? BCColors.surfaceCream,
      width: double.infinity,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}
```

**Step 6: Commit**

```bash
git add lib/widgets/
git commit -m "feat: add shared widgets (video bg, button, nav, footer, section)"
```

---

## Task 4: Build Landing Page Sections

**Files:**
- Create: `lib/pages/landing/hero_section.dart`
- Create: `lib/pages/landing/how_it_works_section.dart`
- Create: `lib/pages/landing/for_clients_section.dart`
- Create: `lib/pages/landing/for_salons_section.dart`
- Create: `lib/pages/landing/download_section.dart`
- Create: `lib/pages/landing/landing_page.dart`

**Step 1: Create `hero_section.dart`**

Full-viewport hero with video background, headline, subtitle, two CTA buttons.

- Video: `media/vid/hero0-mobile.mp4` (mobile) or `beautycita/videos/bcStartup.mp4` (desktop)
- Poster fallback: `media/img/hero0-poster.jpg`
- Headline: "Tu agente de belleza inteligente"
- Subtitle: "No buscas. No filtras. Reservas."
- CTAs: "DESCARGAR APP" (primary) + "SOY SALON" (outline)
- Full viewport height (`100vh`), centered content

**Step 2: Create `how_it_works_section.dart`**

3-column layout (stacks on mobile). Each column is a card with:
- Small video loop behind a rounded container with overlay
- Step number badge (gold circle)
- Title and description

Cards:
1. Video: `makeup-mobile.mp4` — "Elige tu servicio" / "Toca lo que necesitas. Corte, unas, pestanas, lo que sea."
2. Video: `salon-mobile.mp4` — "El agente elige por ti" / "Analiza 50+ salones en tu zona. Te da las 3 mejores opciones."
3. Video: `stylist-mobile.mp4` — "Un tap. Reservado." / "Sin calendario, sin telefono, sin espera."

Cream background (`surfaceCream`).

**Step 3: Create `for_clients_section.dart`**

Side-by-side: video left, content right (stacks on mobile).

- Video: `dancing-mobile.mp4` with rounded corners and shadow
- Content: headline "Inteligencia que entiende belleza"
- 4 bullet points with gold icons:
  - "Hora inferida — no eliges horario, el agente sabe cuando quieres ir"
  - "Uber incluido — ida y vuelta programados automaticamente"
  - "3 opciones curadas — no 100 resultados, las 3 mejores para ti"
  - "30 segundos — de abrir la app a tener cita confirmada"
- CTA: "DESCARGAR APP" (primary)

**Step 4: Create `for_salons_section.dart`**

Rose gradient background. Centered content.

- Headline: "Recibe clientas nuevas. Gratis. Siempre."
- Subtitle: "295+ salones ya estan en BeautyCita"
- 3 stat cards in a row:
  - "60 seg" / "Para registrarte"
  - "$0" / "Sin costo, sin comision"
  - "WhatsApp" / "Reservas directo a tu cel"
- CTA: "REGISTRAR MI SALON" (gold button, links to `/registro`)

**Step 5: Create `download_section.dart`**

Cream background, centered.

- App icon/mockup image (use `media/brand/logo.png`)
- "Descarga BeautyCita"
- "Disponible para Android"
- CTA: "DESCARGAR APK" (links to latest APK on R2 or server)
- Small text: "Proximamente en App Store y Google Play"

**Step 6: Create `landing_page.dart`**

Assembles all sections into a `CustomScrollView` or `ListView`. Manages scroll position for nav bar opacity change. Includes `BCNavBar` as an overlay and `BCFooter` at bottom.

**Step 7: Commit**

```bash
git add lib/pages/landing/
git commit -m "feat: build landing page with 5 scroll sections"
```

---

## Task 5: Build Salon Registration Page

**Files:**
- Create: `lib/pages/registro/registro_page.dart`
- Create: `lib/services/registration_service.dart`

**Step 1: Create `lib/services/registration_service.dart`**

Calls the existing `salon-registro` edge function via POST. Accepts name, phone, address, categories, ref code. Returns success/error.

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class RegistrationService {
  Future<Map<String, dynamic>> registerSalon({
    required String name,
    required String phone,
    String? address,
    required List<String> categories,
    String? refCode,
  }) async {
    final response = await Supabase.instance.client.functions.invoke(
      'salon-registro',
      body: {
        'name': name,
        'phone': phone,
        'address': address,
        'categories': categories,
        'ref': refCode,
      },
    );

    if (response.status != 200) {
      final error = response.data?['error'] ?? 'Error al registrar';
      throw Exception(error);
    }

    return response.data as Map<String, dynamic>;
  }
}
```

**Step 2: Create `lib/pages/registro/registro_page.dart`**

Full registration page matching the layout described above. A `StatefulWidget` with form validation.

- Rose gradient header with title
- Card-based form on cream background
- Fields: salon name (min 2 chars), WhatsApp (min 10 digits, auto-prefix +52), address (optional)
- Category chips (multi-select, at least 1 required)
- Submit button (disabled until valid, shows loading spinner)
- On success: replace form with animated success message (green check, "Bienvenido a BeautyCita!")
- Read `ref` from URL query parameter for referral tracking
- Categories: Unas, Cabello, Pestanas y Cejas, Maquillaje, Facial, Cuerpo y Spa, Especializado

**Step 3: Commit**

```bash
git add lib/pages/registro/ lib/services/
git commit -m "feat: add salon registration page + service"
```

---

## Task 6: Build Privacy Policy and Terms Pages

**Files:**
- Create: `lib/pages/legal/privacy_page.dart`
- Create: `lib/pages/legal/terms_page.dart`

**Step 1: Create privacy policy page**

Standard privacy policy for a Mexican beauty services platform. In Spanish. Covers:
- Data collection (name, phone, location, booking history)
- How data is used (matching with salons, improving recommendations)
- Data sharing (only with booked salons, never sold)
- Data storage (Supabase, encrypted)
- User rights (access, deletion, correction — per Mexican LFPDPPP)
- Cookies (analytics only)
- Contact information

Style: scrollable text page with BCNavBar (solid) and BCFooter.

**Step 2: Create terms of service page**

Standard terms for BeautyCita. In Spanish. Covers:
- Service description (booking agent, not service provider)
- User responsibilities
- Salon responsibilities
- Cancellation policy
- Payment terms (Uber charges separate)
- Limitation of liability
- Governing law (Mexico)

Style: same as privacy page.

**Step 3: Commit**

```bash
git add lib/pages/legal/
git commit -m "feat: add privacy policy and terms pages"
```

---

## Task 7: Set Up Routing and App Entry Point

**Files:**
- Create: `lib/app.dart`
- Modify: `lib/main.dart`

**Step 1: Create `lib/app.dart`**

Set up `MaterialApp` with named routes:
- `/` → `LandingPage`
- `/registro` → `RegistroPage`
- `/privacidad` → `PrivacyPage`
- `/terminos` → `TermsPage`

Apply `BCTheme.light`. Handle URL strategy for clean URLs (no hash).

**Step 2: Modify `lib/main.dart`**

Initialize Supabase, load .env, set URL strategy, run `BCApp`.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy(); // Clean URLs, no hash

  await dotenv.load();

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const BCApp());
}
```

**Step 3: Commit**

```bash
git add lib/main.dart lib/app.dart
git commit -m "feat: set up routing and app entry point"
```

---

## Task 8: Web-Specific Optimizations

**Files:**
- Modify: `web/index.html`
- Create: `web/robots.txt`
- Create: `web/sitemap.xml`

**Step 1: Optimize `web/index.html`**

- Add SEO meta tags (description, keywords, author)
- Add Open Graph tags (og:title, og:description, og:image, og:url)
- Add Twitter Card meta tags
- Add Google Analytics `G-TD6W79YRLJ`
- Preconnect to `fonts.googleapis.com`, `fonts.gstatic.com`, R2 CDN
- Set theme-color to `#C2185B`
- Add PWA manifest
- Add favicon links

**Step 2: Create `web/robots.txt`**

```
User-agent: *
Allow: /
Sitemap: https://beautycita.com/sitemap.xml
```

**Step 3: Create `web/sitemap.xml`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://beautycita.com/</loc><priority>1.0</priority></url>
  <url><loc>https://beautycita.com/registro</loc><priority>0.8</priority></url>
  <url><loc>https://beautycita.com/privacidad</loc><priority>0.3</priority></url>
  <url><loc>https://beautycita.com/terminos</loc><priority>0.3</priority></url>
</urlset>
```

**Step 4: Commit**

```bash
git add web/
git commit -m "feat: add SEO, analytics, robots.txt, sitemap"
```

---

## Task 9: Build, Deploy, Verify

**Step 1: Build release**

```bash
cd /home/bc/futureBeauty/beautycita_web
flutter build web --release --web-renderer html
```

Use `html` renderer (not canvaskit) for better SEO, faster load, smaller bundle, and native text rendering.

**Step 2: Deploy to server**

```bash
# Backup current frontend
ssh www-bc "cp -r /var/www/beautycita.com/frontend/dist /var/www/beautycita.com/frontend/dist-backup-$(date +%Y%m%d)"

# Copy APK downloads to new build (preserve them)
ssh www-bc "mkdir -p /tmp/bc-downloads && cp -r /var/www/beautycita.com/frontend/dist/downloads /tmp/bc-downloads/"

# Upload new build
rsync -avz --delete build/web/ www-bc:/var/www/beautycita.com/frontend/dist/

# Restore downloads
ssh www-bc "cp -r /tmp/bc-downloads/downloads /var/www/beautycita.com/frontend/dist/"
```

**Step 3: Verify pages load**

```bash
curl -s -o /dev/null -w "%{http_code}" https://beautycita.com/
# Expected: 200

curl -s -o /dev/null -w "%{http_code}" https://beautycita.com/registro
# Expected: 200

curl -s -o /dev/null -w "%{http_code}" https://beautycita.com/privacidad
# Expected: 200

curl -s -o /dev/null -w "%{http_code}" https://beautycita.com/terminos
# Expected: 200
```

**Step 4: Test on mobile device**

Open `https://beautycita.com` on phone browser. Verify:
- Hero video plays
- Scroll sections load
- Nav bar transitions from transparent to solid
- Mobile hamburger menu works
- "SOY SALON" navigates to `/registro`
- Registration form works end-to-end
- Privacy and terms pages render

**Step 5: Final commit + tag**

```bash
git add .
git commit -m "feat: production build and deployment"
git tag v1.0.0
```

---

## Files Summary

**New files (15):**

| File | Purpose |
|------|---------|
| `lib/theme/colors.dart` | Brand color palette |
| `lib/theme/typography.dart` | Font styles (Poppins + Nunito) |
| `lib/theme/theme.dart` | MaterialApp theme data |
| `lib/widgets/video_background.dart` | Looping video behind content |
| `lib/widgets/bc_button.dart` | Primary/outline/gold buttons |
| `lib/widgets/nav_bar.dart` | Floating nav bar with scroll transition |
| `lib/widgets/footer.dart` | Site footer |
| `lib/widgets/section_container.dart` | Consistent section wrapper |
| `lib/pages/landing/hero_section.dart` | Hero with video + CTAs |
| `lib/pages/landing/how_it_works_section.dart` | 3-step feature cards |
| `lib/pages/landing/for_clients_section.dart` | Client value prop + features |
| `lib/pages/landing/for_salons_section.dart` | Salon value prop + stats |
| `lib/pages/landing/download_section.dart` | APK download section |
| `lib/pages/landing/landing_page.dart` | Assembles all sections |
| `lib/pages/registro/registro_page.dart` | Salon registration form |
| `lib/pages/legal/privacy_page.dart` | Privacy policy |
| `lib/pages/legal/terms_page.dart` | Terms of service |
| `lib/services/registration_service.dart` | Edge function caller |
| `lib/app.dart` | App widget + routing |
| `lib/main.dart` | Entry point |
| `web/robots.txt` | SEO crawl rules |
| `web/sitemap.xml` | SEO sitemap |
| `.env` | Environment variables |

---

## Task Order

```
Task 1 (Project setup) ───┐
                           │
Task 2 (Theme) ───────────┤── Sequential
                           │
Task 3 (Widgets) ─────────┤── Depends on 2
                           │
Task 4 (Landing sections) ┤── Depends on 3
                           │
Task 5 (Registration) ────┤── Depends on 2, 3
                           │
Task 6 (Legal pages) ─────┤── Depends on 2
                           │
Task 7 (Routing + main) ──┤── Depends on 4, 5, 6
                           │
Task 8 (Web optimizations) ┤── Depends on 7
                           │
Task 9 (Build + deploy) ──┘── Depends on 8
```

---

## Phase 2 (Future): Web Booking Agent

After Phase 1 is live and validated:
- Add service category grid + subcategory selection
- Connect to `curate-results` edge function
- Build result cards for web (responsive, wider layout)
- Add transport selection
- Add booking confirmation flow
- Web-specific auth (biometric via WebAuthn)

Phase 2 reuses the same Supabase backend and edge functions. No backend changes needed.

---

## Verification Checklist

- [ ] `flutter build web --release` succeeds
- [ ] Landing page loads at `https://beautycita.com/`
- [ ] Hero video plays and loops
- [ ] Nav bar transitions on scroll
- [ ] Mobile responsive (hamburger menu, stacked layout)
- [ ] "SOY SALON" navigates to `/registro`
- [ ] Registration form validates and submits
- [ ] Registration creates business record in Supabase
- [ ] Referral code links to discovered_salon
- [ ] Privacy policy renders at `/privacidad`
- [ ] Terms render at `/terminos`
- [ ] Google Analytics tracking active
- [ ] SEO meta tags present in page source
- [ ] All R2 videos load from CDN
- [ ] Page load under 3 seconds on mobile
