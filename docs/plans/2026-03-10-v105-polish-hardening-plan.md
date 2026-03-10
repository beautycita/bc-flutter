# v1.0.5 Polish & Hardening — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Production-polish all screens, fix theme to brand gradient with hollow CTA buttons, wire disconnected features, sweep technical debt, ship v1.0.5.

**Architecture:** 8 tasks across mobile app theme, 2 screens, 1 static HTML page, 2 new edge functions, 3 edge function consistency fixes, 2 migrations, a full analyzer sweep, and an anon user cleanup cron. All Dart-only (no native changes), so Shorebird patch for deploy.

**Tech Stack:** Flutter 3.38.9, Dart, Supabase edge functions (Deno/TS), static HTML/CSS, UptimeRobot API, nginx.

**Design doc:** `docs/plans/2026-03-10-v105-polish-hardening-design.md`

---

## Task 1: Privacy Web Page (`beautycita.com/privacy`)

**Files:**
- Create: `beautycita_app/supabase/privacy.html` (static HTML, deployed manually)

**Context:** Google Play Data Safety form requires a URL to a privacy policy. The content already exists in `legal_screens.dart` (16-section LFPDPPP Aviso de Privacidad). We need a standalone HTML page at `beautycita.com/privacy`.

**Step 1: Create static HTML page**

Create `beautycita_app/supabase/privacy.html` with the full 16-section LFPDPPP privacy policy content extracted from `legal_screens.dart:601-919`. Style with:
- Brand gradient header (`#ec4899 → #9333ea → #3b82f6`)
- Responsive layout (max-width 800px centered)
- Spanish only
- Clean typography (system fonts, no external deps)
- BeautyCita S.A. de C.V. branding
- All 16 sections with proper headings
- Last updated: 10 de marzo de 2026

Read the `_privacySections` constant from `beautycita_app/lib/screens/legal_screens.dart` (lines 601-919) for the authoritative content. Translate the Dart list structure into HTML sections.

**Step 2: Deploy to server**

```bash
scp beautycita_app/supabase/privacy.html www-bc:/var/www/beautycita.com/bc/privacy.html
```

**Step 3: Add nginx location block**

```bash
ssh www-bc "sudo nano /etc/nginx/sites-available/beautycita.com"
```

Add this block inside the server block (near the other `location ^~ /bc/` block):

```nginx
location = /privacy {
    alias /var/www/beautycita.com/bc/privacy.html;
    add_header Content-Type text/html;
}
```

Then reload:
```bash
ssh www-bc "sudo nginx -t && sudo systemctl reload nginx"
```

**Step 4: Verify**

```bash
curl -s -o /dev/null -w "%{http_code}" https://beautycita.com/privacy
```
Expected: `200`

**Step 5: Commit**

```bash
git add beautycita_app/supabase/privacy.html
git commit -m "feat: static privacy policy web page (LFPDPPP)"
```

---

## Task 2: Theme — Rose Gradient to Brand Gradient + Hollow CTAs

**Files:**
- Modify: `beautycita_app/lib/config/palettes.dart:144-196` (Rose & Gold palette)
- Modify: `packages/beautycita_core/lib/src/theme/palettes.dart` (same changes, keep in sync)

**Context:** The default Rose & Gold palette uses `primary: #660033` (dark rose) and `primaryGradient: [#660033, #990033]`. BC wants the brand gradient `#ec4899 → #9333ea → #3b82f6` (pink → purple → blue) as the default. CTA buttons should be hollow/outlined (like the "Cerrar Sesión" button in settings_screen.dart:235-244) using brand primary instead of red, with a shimmer-on-tap animation.

**Step 1: Update Rose & Gold palette colors**

In `beautycita_app/lib/config/palettes.dart`, change the `roseGoldPalette` constant (lines 144-196):

```dart
// CHANGE these lines:
//   primary: Color(0xFF660033),        → Color(0xFFec4899),
//   secondary: Color(0xFFFFB300),      → Color(0xFF9333ea),
//   shimmerColor: Color(0xFFFFB300),   → Color(0xFF9333ea),
//   primaryGradient colors:            → [#ec4899, #9333ea, #3b82f6]
//   accentGradient colors:             → [#ec4899, #7e22ce] (CTA gradient, used internally)
//   cinematicPrimary: Color(0xFF660033) → Color(0xFFec4899),
//   cinematicAccent: Color(0xFFFFB300)  → Color(0xFF9333ea),

const roseGoldPalette = BCPalette(
  id: 'rose_gold',
  nameEs: 'Rosa y Oro',
  nameEn: 'Rose & Gold',
  brightness: Brightness.light,
  primary: Color(0xFFec4899),          // pink-500 (brand)
  onPrimary: Color(0xFFFFFFFF),
  secondary: Color(0xFF9333ea),        // purple-500 (brand)
  onSecondary: Color(0xFFFFFFFF),
  surface: Color(0xFFFFF8F0),
  onSurface: Color(0xFF212121),
  scaffoldBackground: Color(0xFFFFFFFF),
  error: Color(0xFFD32F2F),
  onError: Color(0xFFFFFFFF),
  cardColor: Color(0xFFFFF8F0),
  cardBorderColor: Color(0xFFEEEEEE),
  divider: Color(0xFFEEEEEE),
  textPrimary: Color(0xFF212121),
  textSecondary: Color(0xFF757575),
  textHint: Color(0xFF9E9E9E),
  shimmerColor: Color(0xFF9333ea),
  success: Color(0xFF4CAF50),
  warning: Color(0xFFFFA000),
  info: Color(0xFF2196F3),
  primaryGradient: LinearGradient(
    colors: [Color(0xFFec4899), Color(0xFF9333ea), Color(0xFF3b82f6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  accentGradient: LinearGradient(
    colors: [Color(0xFFec4899), Color(0xFF7e22ce)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  goldGradientStops: kGoldStops,
  goldGradientPositions: kGoldPositions,
  categoryColors: [
    Color(0xFFE91E63), // nails
    Color(0xFF8D6E63), // hair
    Color(0xFF9C27B0), // lashes_brows
    Color(0xFFFF5252), // makeup
    Color(0xFF26A69A), // facial
    Color(0xFF5C6BC0), // body_spa
    Color(0xFFFFA726), // specialized
    Color(0xFF37474F), // barberia
  ],
  cinematicPrimary: Color(0xFFec4899),
  cinematicAccent: Color(0xFF9333ea),
  statusBarColor: Color(0x00000000),
  statusBarIconBrightness: Brightness.dark,
  navigationBarColor: Color(0xFFFFFFFF),
  navigationBarIconBrightness: Brightness.dark,
);
```

**Step 2: Mirror changes in shared package**

Apply identical changes to `packages/beautycita_core/lib/src/theme/palettes.dart` (the Rose & Gold palette definition there). Keep both files in sync.

**Step 3: Verify theme builds**

```bash
cd /home/bc/futureBeauty/beautycita_app && /home/bc/flutter/bin/flutter analyze lib/config/palettes.dart
```
Expected: No issues found

**Step 4: Commit**

```bash
git add beautycita_app/lib/config/palettes.dart packages/beautycita_core/lib/src/theme/palettes.dart
git commit -m "feat: update default theme to brand gradient (pink→purple→blue)"
```

**Step 5: Create shimmer CTA button widget**

Create a reusable `ShimmerOutlinedButton` widget. This button is hollow/outlined (1px border, brand primary text, transparent fill). On tap, a shimmer animation runs across the text before executing the callback.

Add this widget to a new file: `beautycita_app/lib/widgets/shimmer_outlined_button.dart`

```dart
import 'package:flutter/material.dart';
import '../config/constants.dart';

/// Hollow outlined button with shimmer-on-tap animation.
/// Matches the "Cerrar Sesión" style from settings but uses theme primary
/// instead of red, and adds a brand gradient shimmer on press.
class ShimmerOutlinedButton extends StatefulWidget {
  const ShimmerOutlinedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  State<ShimmerOutlinedButton> createState() => _ShimmerOutlinedButtonState();
}

class _ShimmerOutlinedButtonState extends State<ShimmerOutlinedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerCtrl;
  bool _shimmering = false;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _shimmerCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _shimmering = false);
        _shimmerCtrl.reset();
        widget.onPressed?.call();
      }
    });
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onPressed == null || _shimmering) return;
    setState(() => _shimmering = true);
    _shimmerCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: widget.onPressed != null ? _handleTap : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(
            vertical: AppConstants.paddingMD,
          ),
        ),
        child: AnimatedBuilder(
          animation: _shimmerCtrl,
          builder: (context, child) {
            if (!_shimmering) return child!;
            final offset = -1.0 + 2.0 * _shimmerCtrl.value;
            return ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) {
                return LinearGradient(
                  begin: Alignment(offset - 1.0, 0),
                  end: Alignment(offset + 1.0, 0),
                  colors: const [
                    Color(0xFFec4899),
                    Color(0xFF9333ea),
                    Color(0xFF3b82f6),
                    Color(0xFF9333ea),
                    Color(0xFFec4899),
                  ],
                  stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                ).createShader(bounds);
              },
              child: child!,
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 20),
                const SizedBox(width: 8),
              ],
              Text(widget.label),
            ],
          ),
        ),
      ),
    );
  }
}
```

**Step 6: Commit**

```bash
git add beautycita_app/lib/widgets/shimmer_outlined_button.dart
git commit -m "feat: ShimmerOutlinedButton — hollow CTA with shimmer-on-tap"
```

---

## Task 3: System Status Screen — Live Data via UptimeRobot

**Files:**
- Create: `beautycita_app/supabase/functions/system-health/index.ts`
- Rewrite: `beautycita_app/lib/screens/system_status_screen.dart`

**Context:** Current system_status_screen.dart (513 lines) is 100% static mock data. All services hardcoded as "Operativo". Replace with real monitoring data from UptimeRobot API + Supabase self-ping. We have 4 UptimeRobot monitors already.

**Step 1: Get UptimeRobot API key**

BC needs to provide the UptimeRobot read-only API key. It's in the UptimeRobot dashboard under My Settings → API Settings → Read-Only API Key. This key will be stored as a Deno env var `UPTIMEROBOT_API_KEY` on the server.

If not available immediately, use a placeholder and the function will return graceful fallback data.

**Step 2: Create system-health edge function**

Create `beautycita_app/supabase/functions/system-health/index.ts`:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const UPTIMEROBOT_KEY = Deno.env.get("UPTIMEROBOT_API_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, content-type, apikey",
  "Cache-Control": "public, max-age=60",
};

interface Monitor {
  id: number;
  friendly_name: string;
  status: number; // 0=paused,1=not checked,2=up,8=seems down,9=down
  custom_uptime_ratio: string;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  try {
    const services: Record<string, { status: string; uptime: string }> = {};

    // 1. UptimeRobot monitors
    if (UPTIMEROBOT_KEY) {
      const res = await fetch("https://api.uptimerobot.com/v2/getMonitors", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          api_key: UPTIMEROBOT_KEY,
          format: "json",
          custom_uptime_ratios: "30",
        }),
      });
      const data = await res.json();
      if (data.monitors) {
        for (const m of data.monitors as Monitor[]) {
          const status = m.status === 2 ? "operational" :
                         m.status === 8 ? "degraded" :
                         m.status === 9 ? "down" : "unknown";
          services[m.friendly_name] = {
            status,
            uptime: m.custom_uptime_ratio ?? "—",
          };
        }
      }
    }

    // 2. Supabase self-ping (DB + REST)
    const dbStart = Date.now();
    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    const { error } = await supabase
      .from("app_config")
      .select("key")
      .limit(1)
      .single();
    const dbMs = Date.now() - dbStart;
    services["Base de Datos"] = {
      status: error ? "degraded" : "operational",
      uptime: `${dbMs}ms`,
    };

    // 3. Overall status
    const allStatuses = Object.values(services).map((s) => s.status);
    const overall = allStatuses.every((s) => s === "operational")
      ? "operational"
      : allStatuses.some((s) => s === "down")
        ? "down"
        : "degraded";

    return new Response(
      JSON.stringify({
        overall,
        services,
        checked_at: new Date().toISOString(),
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (e) {
    console.error("[system-health]", e);
    return new Response(
      JSON.stringify({ overall: "unknown", services: {}, checked_at: new Date().toISOString() }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
```

**Step 3: Rewrite system_status_screen.dart**

Rewrite `beautycita_app/lib/screens/system_status_screen.dart` to:
- Be a `ConsumerStatefulWidget` (needs Supabase client from Riverpod)
- Call `system-health` edge function on `initState`
- Show loading skeleton while fetching
- Render real status badges (green=operational, yellow=degraded, red=down)
- Show uptime percentages from UptimeRobot
- Show DB response time from self-ping
- Pull-to-refresh via `RefreshIndicator`
- "Last checked" timestamp at bottom
- Error state: "No se pudo verificar el estado" with retry button
- Keep the polished card-based layout, hero status card, service list

Internal services to display (map from UptimeRobot monitor names + DB ping):
- API Principal (UptimeRobot)
- Base de Datos (self-ping)
- Autenticacion (UptimeRobot)
- Notificaciones Push (UptimeRobot)
- Pagos (UptimeRobot)
- Any additional monitors found

**Step 4: Verify**

```bash
cd /home/bc/futureBeauty/beautycita_app && /home/bc/flutter/bin/flutter analyze lib/screens/system_status_screen.dart
```
Expected: No issues found

**Step 5: Commit**

```bash
git add beautycita_app/supabase/functions/system-health/index.ts beautycita_app/lib/screens/system_status_screen.dart
git commit -m "feat: live system status via UptimeRobot + Supabase health check"
```

---

## Task 4: Wire Report Problem Form

**Files:**
- Create: `beautycita_app/supabase/migrations/20260310100000_contact_submissions.sql`
- Modify: `beautycita_app/lib/screens/report_problem_screen.dart:49-62`

**Context:** The report form has working validation and UI but `_submit()` is a no-op (just shows a toast and pops). The `contact_submissions` table doesn't exist yet. We need: migration to create the table, then wire the form to insert + notify admin.

**Step 1: Create migration**

Create `beautycita_app/supabase/migrations/20260310100000_contact_submissions.sql`:

```sql
-- Contact submissions / problem reports from app users
CREATE TABLE IF NOT EXISTS contact_submissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  category text NOT NULL,
  description text NOT NULL,
  involved_user text,          -- optional: username or salon involved
  incident_date text,          -- optional: user-reported date string
  metadata jsonb DEFAULT '{}', -- device info, app version, etc.
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reviewing', 'resolved', 'dismissed')),
  admin_notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE contact_submissions ENABLE ROW LEVEL SECURITY;

-- Users can insert their own reports
CREATE POLICY "Users can insert own reports"
  ON contact_submissions FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Users can read their own reports
CREATE POLICY "Users can read own reports"
  ON contact_submissions FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Service role full access (admin)
CREATE POLICY "Service role full access"
  ON contact_submissions FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Auto-update updated_at
CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON contact_submissions
  FOR EACH ROW
  EXECUTE FUNCTION moddatetime(updated_at);

-- Index for admin queries
CREATE INDEX idx_contact_submissions_status ON contact_submissions(status);
CREATE INDEX idx_contact_submissions_created ON contact_submissions(created_at DESC);
```

**Step 2: Run migration on production**

```bash
ssh www-bc "docker exec supabase-db psql -U postgres -d postgres" < beautycita_app/supabase/migrations/20260310100000_contact_submissions.sql
```

**Step 3: Wire the _submit() method**

Replace `report_problem_screen.dart` lines 49-62 with:

```dart
Future<void> _submit() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _submitting = true);

  try {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    await supabase.from('contact_submissions').insert({
      'user_id': user?.id,
      'category': _selectedCategory,
      'description': _descriptionController.text.trim(),
      'involved_user': _involvedController.text.trim().isEmpty
          ? null
          : _involvedController.text.trim(),
      'incident_date': _dateController.text.trim().isEmpty
          ? null
          : _dateController.text.trim(),
      'metadata': {
        'app_version': AppConstants.version,
        'platform': Theme.of(context).platform.name,
      },
    });

    // Fire admin notification (best-effort, don't block on failure)
    try {
      await supabase.functions.invoke('send-push-notification', body: {
        'user_id': 'admin',
        'title': 'Nuevo reporte',
        'body': '[$_selectedCategory] ${_descriptionController.text.trim().substring(0, 50.clamp(0, _descriptionController.text.trim().length))}...',
      });
    } catch (_) {
      // Admin notification is best-effort
    }

    if (!mounted) return;
    setState(() => _submitting = false);
    ToastService.showSuccess('Reporte enviado. Lo revisaremos pronto.');
    Navigator.of(context).pop();
  } catch (e) {
    debugPrint('[ReportProblem] submit error: $e');
    if (!mounted) return;
    setState(() => _submitting = false);
    ToastService.showError('Error al enviar. Intenta de nuevo.');
  }
}
```

Add required imports at top of file:
```dart
import 'package:supabase_flutter/supabase_flutter.dart';
```

**Step 4: Verify**

```bash
cd /home/bc/futureBeauty/beautycita_app && /home/bc/flutter/bin/flutter analyze lib/screens/report_problem_screen.dart
```
Expected: No issues found

**Step 5: Commit**

```bash
git add beautycita_app/supabase/migrations/20260310100000_contact_submissions.sql beautycita_app/lib/screens/report_problem_screen.dart
git commit -m "feat: wire report problem form to contact_submissions table + admin push"
```

---

## Task 5: Toggle Consistency — Migrate 3 Edge Functions

**Files:**
- Modify: `beautycita_app/supabase/functions/create-product-payment/index.ts`
- Modify: `beautycita_app/supabase/functions/order-followup/index.ts`
- Modify: `beautycita_app/supabase/functions/process-no-show/index.ts`

**Context:** These 3 functions either lack toggle checks entirely (`create-product-payment`) or use manual `app_config` queries instead of the shared `requireFeature()` helper. Migrate all to the standard pattern from `_shared/check-toggle.ts`.

**Step 1: Fix create-product-payment**

Add after the CORS check (after the `if (req.method === "OPTIONS")` block):

```typescript
import { requireFeature } from "../_shared/check-toggle.ts";

// Add after OPTIONS check:
const blocked = await requireFeature("enable_pos");
if (blocked) return blocked;
```

**Step 2: Fix order-followup**

Replace the manual `app_config` query (around line 55-60) with:

```typescript
import { requireFeature } from "../_shared/check-toggle.ts";

// Replace manual check with:
const blocked = await requireFeature("enable_pos");
if (blocked) return blocked;
```

Remove the old manual query code that directly reads from `app_config`.

**Step 3: Fix process-no-show**

Replace the manual `app_config` query (around line 55-60) with:

```typescript
import { requireFeature } from "../_shared/check-toggle.ts";

// Replace manual check with:
const blocked = await requireFeature("enable_push_notifications");
if (blocked) return blocked;
```

Remove the old manual query code.

**Step 4: Deploy edge functions**

```bash
rsync -avz beautycita_app/supabase/functions/ www-bc:/var/www/beautycita.com/bc-flutter/supabase-docker/volumes/functions/
ssh www-bc "cd /var/www/beautycita.com/bc-flutter/supabase-docker && docker compose restart functions"
```

**Step 5: Commit**

```bash
git add beautycita_app/supabase/functions/create-product-payment/index.ts beautycita_app/supabase/functions/order-followup/index.ts beautycita_app/supabase/functions/process-no-show/index.ts
git commit -m "fix: migrate 3 edge functions to requireFeature() toggle helper"
```

---

## Task 6: Technical Debt Sweep — Zero Analyzer Issues

**Files:**
- Modify: Multiple files across `beautycita_app/lib/`

**Context:** The app has known analyzer warnings: curly brace issues, unused imports, unused variables, deprecated `withOpacity` calls. Goal is 0 issues.

**Step 1: Run full analyzer**

```bash
cd /home/bc/futureBeauty/beautycita_app && /home/bc/flutter/bin/flutter analyze 2>&1
```

**Step 2: Fix all issues**

For each issue, apply the minimal fix:
- **Missing curly braces:** Wrap single-line if/else bodies in `{}`
- **Unused imports:** Remove the import line
- **Unused variables:** Remove or prefix with `_` if needed for side effects
- **Deprecated withOpacity:** Replace `color.withOpacity(x)` with `color.withValues(alpha: x)`
- **Other warnings:** Fix per analyzer recommendation

Do NOT refactor, add comments, or clean up surrounding code. Only fix what the analyzer flags.

**Step 3: Re-run analyzer to confirm zero issues**

```bash
cd /home/bc/futureBeauty/beautycita_app && /home/bc/flutter/bin/flutter analyze 2>&1
```
Expected: `No issues found!`

**Step 4: Commit**

```bash
git add -A
git commit -m "fix: resolve all Flutter analyzer warnings (0 issues)"
```

---

## Task 7: Auto-Cleanup Anonymous Users

**Files:**
- Create: `beautycita_app/supabase/functions/cleanup-anon-users/index.ts`
- Create: `beautycita_app/supabase/migrations/20260310100001_cleanup_anon_users.sql`

**Context:** Anonymous users (no email, no phone) accumulate in the database from abandoned registrations. BC wants them auto-purged when: (a) there are 50+ anon users, OR (b) periodically every 24-48 hours. Only delete users who are NOT currently online (check `last_seen` > 1 hour ago). This keeps the users table clean and the admin panel usable.

**Step 1: Create SQL function for cleanup**

Create `beautycita_app/supabase/migrations/20260310100001_cleanup_anon_users.sql`:

```sql
-- Function to delete anonymous users (no email, no phone, not online)
-- Called by edge function on schedule or threshold trigger
CREATE OR REPLACE FUNCTION cleanup_anon_users()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  anon_count int;
  deleted_count int;
  deleted_ids uuid[];
BEGIN
  -- Count current anon users
  SELECT count(*) INTO anon_count
  FROM auth.users u
  JOIN profiles p ON p.id = u.id
  WHERE u.email IS NULL
    AND (p.phone IS NULL OR p.phone = '')
    AND (u.phone IS NULL OR u.phone = '');

  -- Only proceed if 50+ anon users exist
  IF anon_count < 50 THEN
    RETURN jsonb_build_object('skipped', true, 'anon_count', anon_count, 'reason', 'below threshold');
  END IF;

  -- Collect IDs of anon users who are offline (last_seen > 1 hour ago or null)
  SELECT array_agg(p.id) INTO deleted_ids
  FROM profiles p
  JOIN auth.users u ON u.id = p.id
  WHERE u.email IS NULL
    AND (p.phone IS NULL OR p.phone = '')
    AND (u.phone IS NULL OR u.phone = '')
    AND (p.last_seen IS NULL OR p.last_seen < now() - interval '1 hour')
    AND p.role = 'customer';  -- never delete business/admin accounts

  IF deleted_ids IS NULL OR array_length(deleted_ids, 1) IS NULL THEN
    RETURN jsonb_build_object('skipped', true, 'anon_count', anon_count, 'reason', 'all anon users currently online');
  END IF;

  deleted_count := array_length(deleted_ids, 1);

  -- Delete from profiles first (FK cascade will handle related tables)
  DELETE FROM profiles WHERE id = ANY(deleted_ids);

  -- Delete from auth.users
  DELETE FROM auth.users WHERE id = ANY(deleted_ids);

  -- Log to audit
  INSERT INTO audit_log (action, entity_type, details)
  VALUES ('cleanup_anon_users', 'user', jsonb_build_object(
    'deleted_count', deleted_count,
    'anon_count_before', anon_count,
    'timestamp', now()
  ));

  RETURN jsonb_build_object('deleted', deleted_count, 'anon_count_before', anon_count);
END;
$$;
```

**Step 2: Create edge function**

Create `beautycita_app/supabase/functions/cleanup-anon-users/index.ts`:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req: Request) => {
  // Only allow POST (from cron) or internal calls
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204 });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const { data, error } = await supabase.rpc("cleanup_anon_users");

    if (error) {
      console.error("[cleanup-anon-users] RPC error:", error);
      return new Response(
        JSON.stringify({ error: "Cleanup failed" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    console.log("[cleanup-anon-users] Result:", JSON.stringify(data));
    return new Response(
      JSON.stringify(data),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (e) {
    console.error("[cleanup-anon-users] Error:", e);
    return new Response(
      JSON.stringify({ error: "Internal error" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
```

**Step 3: Set up server cron**

```bash
ssh www-bc "crontab -l"
# Add this line (runs every 24 hours at 4 AM):
# 0 4 * * * curl -s -X POST http://localhost:8000/functions/v1/cleanup-anon-users -H "Authorization: Bearer $(cat /var/www/beautycita.com/bc-flutter/supabase-docker/.env | grep SERVICE_ROLE_KEY | cut -d= -f2)" >> /var/log/cleanup-anon.log 2>&1
```

**Step 4: Run migration on production**

```bash
ssh www-bc "docker exec supabase-db psql -U postgres -d postgres" < beautycita_app/supabase/migrations/20260310100001_cleanup_anon_users.sql
```

**Step 5: Commit**

```bash
git add beautycita_app/supabase/migrations/20260310100001_cleanup_anon_users.sql beautycita_app/supabase/functions/cleanup-anon-users/index.ts
git commit -m "feat: auto-cleanup anonymous users (50+ threshold, 24h cron)"
```

---

## Task 8: Build & Deploy v1.0.5

**Files:**
- Modify: `beautycita_app/pubspec.yaml:4` (version bump)

**Context:** All changes are Dart-only (no new native plugins), so Shorebird patch is appropriate. Bump version to `1.0.5+50016`.

**Step 1: Bump version**

Change `beautycita_app/pubspec.yaml` line 4:
```yaml
version: 1.0.5+50016
```

**Step 2: Commit version bump**

```bash
git add beautycita_app/pubspec.yaml
git commit -m "chore: bump version to 1.0.5+50016"
```

**Step 3: Build and deploy (DO NOT execute until BC says to build)**

```bash
# Shorebird patch (Dart-only)
cd /home/bc/futureBeauty/beautycita_app
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
/home/bc/.shorebird/bin/shorebird patch android

# Upload APK to R2
aws s3 cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk \
  s3://beautycita-medias/apk/beautycita.apk --profile r2 \
  --content-type application/vnd.android.package-archive

# Update version.json
echo '{"version":"1.0.5","build_number":50016,"required":false}' | \
  aws s3 cp - s3://beautycita-medias/apk/version.json --profile r2 \
  --content-type application/json

# Web deploy
cd /home/bc/futureBeauty/beautycita_web
/home/bc/flutter/bin/flutter build web --release --no-tree-shake-icons
rsync -avz --delete --exclude sativa build/web/ www-bc:/var/www/beautycita.com/frontend/dist/

# Edge functions deploy
rsync -avz /home/bc/futureBeauty/beautycita_app/supabase/functions/ \
  www-bc:/var/www/beautycita.com/bc-flutter/supabase-docker/volumes/functions/
ssh www-bc "cd /var/www/beautycita.com/bc-flutter/supabase-docker && docker compose restart functions"
```

**Step 4: Update memory**

Update `MEMORY.md` with new version: `1.0.5+50016`.
Update `build-queue.md` to reflect completed items.
Update `brand-colors.md` to note theme is now using brand gradient.
