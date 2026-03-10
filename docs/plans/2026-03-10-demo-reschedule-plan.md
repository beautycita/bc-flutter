# Demo Reschedule Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the web demo calendar's drag-and-drop reschedule functional, sending real labeled WhatsApp messages to the demo user's verified phone showing what stylists and clients would experience.

**Architecture:** New `demo-reschedule` edge function handles WhatsApp delivery with 20s delay. Calendar page conditionally enables drag in demo mode when user has verified phone. No DB writes, no production code modification. Phone verification gate turns every demo user into a registered account.

**Tech Stack:** Flutter Web (beautycita_web), Supabase edge functions (Deno/TS), WhatsApp API via beautypi, Riverpod providers.

**Design doc:** `docs/plans/2026-03-10-demo-reschedule-design.md`

---

## Task 1: Create `demo-reschedule` Edge Function

**Files:**
- Create: `beautycita_app/supabase/functions/demo-reschedule/index.ts`

**Context:** This edge function receives fake appointment data from the demo calendar drop, fetches the user's verified phone from their profile, and sends two labeled WhatsApp messages (stylist first, then client 20 seconds later). No DB writes.

**Step 1: Create the edge function**

Create `beautycita_app/supabase/functions/demo-reschedule/index.ts`:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const WA_API_URL = Deno.env.get("BEAUTYPI_WA_URL") ?? "";
const WA_API_TOKEN = Deno.env.get("BEAUTYPI_WA_TOKEN") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "https://beautycita.com",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, content-type, apikey",
};

// Rate limit: 3 demo reschedules per user per 10 minutes
const rateLimitMap = new Map<string, number[]>();
const RATE_WINDOW_MS = 10 * 60 * 1000;
const RATE_MAX = 3;

function formatDateEs(isoDate: string): { date: string; time: string } {
  const d = new Date(isoDate);
  const days = ["dom", "lun", "mar", "mie", "jue", "vie", "sab"];
  const months = [
    "ene", "feb", "mar", "abr", "may", "jun",
    "jul", "ago", "sep", "oct", "nov", "dic",
  ];
  const day = days[d.getDay()];
  const month = months[d.getMonth()];
  const date = `${day}, ${d.getDate()} ${month}, ${d.getFullYear()}`;
  const hours = d.getHours();
  const minutes = d.getMinutes().toString().padStart(2, "0");
  const ampm = hours >= 12 ? "PM" : "AM";
  const h12 = hours % 12 || 12;
  const time = `${h12}:${minutes} ${ampm}`;
  return { date, time };
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    // Auth: require authenticated user
    const authHeader = req.headers.get("authorization") ?? "";
    const token = authHeader.replace("Bearer ", "");
    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: `Bearer ${token}` } },
    });
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Rate limit
    const now = Date.now();
    const timestamps = rateLimitMap.get(user.id) ?? [];
    const recent = timestamps.filter((t) => now - t < RATE_WINDOW_MS);
    if (recent.length >= RATE_MAX) {
      return new Response(
        JSON.stringify({ error: "Demo limit reached. Try again in a few minutes." }),
        { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    recent.push(now);
    rateLimitMap.set(user.id, recent);

    // Get user's verified phone from profile
    const adminClient = createClient(
      SUPABASE_URL,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );
    const { data: profile } = await adminClient
      .from("profiles")
      .select("phone")
      .eq("id", user.id)
      .single();

    if (!profile?.phone) {
      return new Response(
        JSON.stringify({ error: "Phone not verified" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Parse request body
    const {
      service_name,
      client_name,
      staff_name,
      salon_name,
      new_start,
      salon_phone,
    } = await req.json();

    if (!service_name || !new_start) {
      return new Response(
        JSON.stringify({ error: "Missing required fields" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { date, time } = formatDateEs(new_start);
    const phone = profile.phone.replace(/\D/g, "");

    // Message 1: Stylist (immediate)
    const stylistMsg = [
      `⚡ *[DEMO] Mensaje para la estilista*`,
      ``,
      `*BeautyCita - Cita Reagendada*`,
      `La cita de ${service_name} con tu cliente ${client_name || "Cliente"} ha sido movida.`,
      ``,
      `📅 Nueva fecha: ${date}, ${time}`,
      `📍 Salon: ${salon_name || "Tu Salon"}`,
      ``,
      `_Este mensaje se envia automaticamente cuando un gerente mueve una cita en el calendario._`,
    ].join("\n");

    await fetch(`${WA_API_URL}/api/wa/send`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${WA_API_TOKEN}`,
      },
      body: JSON.stringify({ phone, message: stylistMsg }),
    });

    console.log(`[demo-reschedule] Stylist msg sent to ${phone.slice(-4)}`);

    // Message 2: Client (20 second delay)
    await new Promise((resolve) => setTimeout(resolve, 20000));

    const clientMsg = [
      `⚡ *[DEMO] Mensaje para el/la cliente*`,
      ``,
      `*BeautyCita - Cita Reagendada*`,
      `Tu cita de ${service_name} ha sido reagendada.`,
      ``,
      `📅 Nueva fecha: ${date}, ${time}`,
      `💇 Estilista: ${staff_name || "Tu Estilista"}`,
      `📍 Salon: ${salon_name || "Tu Salon"}`,
      ``,
      `Si no puedes asistir, contacta al salon:`,
      `📞 ${salon_phone || "+52 322 142 9800"} | 💬 WhatsApp`,
      ``,
      `_Este mensaje se envia automaticamente para que tu cliente siempre este informado._`,
    ].join("\n");

    await fetch(`${WA_API_URL}/api/wa/send`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${WA_API_TOKEN}`,
      },
      body: JSON.stringify({ phone, message: clientMsg }),
    });

    console.log(`[demo-reschedule] Client msg sent to ${phone.slice(-4)}`);

    return new Response(
      JSON.stringify({ success: true, messages_sent: 2 }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (e) {
    console.error("[demo-reschedule] Error:", e);
    return new Response(
      JSON.stringify({ error: "Failed to send demo messages" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
```

**Step 2: Commit**

```bash
cd /home/bc/futureBeauty
git add beautycita_app/supabase/functions/demo-reschedule/index.ts
git commit -m "feat: demo-reschedule edge function — labeled WhatsApp messages"
```

---

## Task 2: Add Phone Verification State to Demo Providers

**Files:**
- Modify: `beautycita_web/lib/providers/demo_providers.dart`

**Context:** We need a provider that tracks whether the demo user has a verified phone. This is separate from `isDemoProvider` — it gates the interactive calendar features.

**Step 1: Add demo phone verified provider**

In `beautycita_web/lib/providers/demo_providers.dart`, add after line 11 (after `isDemoProvider`):

```dart
/// Whether the current user has a verified phone number.
/// In demo mode, this gates interactive features like drag-and-drop reschedule.
final demoPhoneVerifiedProvider = FutureProvider<bool>((ref) async {
  final user = BCSupabase.client.auth.currentUser;
  if (user == null) return false;
  final res = await BCSupabase.client
      .from('profiles')
      .select('phone')
      .eq('id', user.id)
      .maybeSingle();
  final phone = res?['phone'] as String?;
  return phone != null && phone.isNotEmpty;
});
```

Add required import at top:
```dart
import 'package:beautycita_core/beautycita_core.dart';
```

**Step 2: Verify**

```bash
cd /home/bc/futureBeauty/beautycita_web && /home/bc/flutter/bin/flutter analyze lib/providers/demo_providers.dart
```

**Step 3: Commit**

```bash
cd /home/bc/futureBeauty
git add beautycita_web/lib/providers/demo_providers.dart
git commit -m "feat: add demoPhoneVerifiedProvider for calendar gate"
```

---

## Task 3: Enable Drag in Demo Mode + Phone Verification Gate

**Files:**
- Modify: `beautycita_web/lib/pages/business/biz_calendar_page.dart`

**Context:** Line 816 currently has `enableDrag: !isDemo` which completely disables drag in demo mode. We need to conditionally enable it when the user has a verified phone, and show a verification modal when they don't.

**Step 1: Change the enableDrag line**

Find line 816 in `biz_calendar_page.dart`:
```dart
enableDrag: !isDemo,
```

The surrounding code needs access to the phone verification state. In the widget where `isDemo` is read (around line 676), also read the phone verified state:

```dart
final isDemo = ref.watch(isDemoProvider);
final phoneVerifiedAsync = ref.watch(demoPhoneVerifiedProvider);
final demoPhoneVerified = phoneVerifiedAsync.valueOrNull ?? false;
```

Add import at top of file:
```dart
import '../../providers/demo_providers.dart';
```

Change line 816 from:
```dart
enableDrag: !isDemo,
```
to:
```dart
enableDrag: !isDemo || demoPhoneVerified,
```

Pass `demoPhoneVerified` down to the widget that contains line 816 if needed (through constructor parameters).

**Step 2: Add phone verification modal**

If the user tries to interact with the calendar in demo mode WITHOUT a verified phone, show a modal. Add a method in the calendar content widget:

```dart
void _showPhoneVerificationGate(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Verifica tu WhatsApp'),
      content: const Text(
        'Para experimentar la reprogramacion en vivo, necesitamos verificar '
        'tu numero de WhatsApp.\n\n'
        'Recibiras los mismos mensajes que recibirian tu estilista y tu cliente.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Ahora no'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            context.go('/auth/verify');
          },
          child: const Text('Verificar'),
        ),
      ],
    ),
  );
}
```

Add a GestureDetector wrapper or onTap handler on the calendar area that triggers this modal when `isDemo && !demoPhoneVerified` and the user taps/tries to interact.

**Step 3: Add the pulsing tooltip**

When `isDemo && demoPhoneVerified`, show a pulsing tooltip over the calendar: "Arrastra una cita para reprogramar". Use a `Positioned` widget with an animated opacity that pulses. Dismiss after first successful drag.

```dart
if (isDemo && demoPhoneVerified && !_hasCompletedDemoDrag)
  Positioned(
    top: 8,
    left: 0,
    right: 0,
    child: Center(
      child: _PulsingTooltip(
        text: 'Arrastra una cita para reprogramar',
        onDismiss: () => setState(() => _hasCompletedDemoDrag = true),
      ),
    ),
  ),
```

Create a `_PulsingTooltip` widget with a repeating fade animation (1.5s cycle, opacity 0.6→1.0):

```dart
class _PulsingTooltip extends StatefulWidget {
  const _PulsingTooltip({required this.text, this.onDismiss});
  final String text;
  final VoidCallback? onDismiss;

  @override
  State<_PulsingTooltip> createState() => _PulsingTooltipState();
}

class _PulsingTooltipState extends State<_PulsingTooltip>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.6, end: 1.0).animate(_ctrl),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFec4899), Color(0xFF9333ea), Color(0xFF3b82f6)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9333ea).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          widget.text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
```

**Step 4: Verify**

```bash
cd /home/bc/futureBeauty/beautycita_web && /home/bc/flutter/bin/flutter analyze lib/pages/business/biz_calendar_page.dart
```

**Step 5: Commit**

```bash
cd /home/bc/futureBeauty
git add beautycita_web/lib/pages/business/biz_calendar_page.dart
git commit -m "feat: enable demo calendar drag with phone verification gate"
```

---

## Task 4: Override Drop Handler in Demo Mode

**Files:**
- Modify: `beautycita_web/lib/pages/business/biz_calendar_page.dart`

**Context:** When a valid drop occurs in demo mode, we must NOT write to the database. Instead: call `demo-reschedule` edge function, locally move the appointment in the demo data, show success feedback, and revert after 60 seconds.

**Step 1: Modify the drop handler**

Find the `_executeReschedule` method (line 586). Add a demo mode branch at the very top of the method:

```dart
Future<void> _executeReschedule(
  String id,
  String newStaffId,
  String newStaffFirstName,
  String newStaffLastName,
  DateTime newStart,
  DateTime newEnd,
) async {
  final isDemo = ref.read(isDemoProvider);

  if (isDemo) {
    await _executeDemoReschedule(
      id, newStaffId, newStaffFirstName, newStaffLastName, newStart, newEnd,
    );
    return;
  }

  // ... existing production code unchanged ...
}
```

**Step 2: Create the demo reschedule method**

Add this new method after `_executeReschedule`:

```dart
Future<void> _executeDemoReschedule(
  String id,
  String newStaffId,
  String newStaffFirstName,
  String newStaffLastName,
  DateTime newStart,
  DateTime newEnd,
) async {
  // Find the appointment in demo data
  final apptIndex = DemoData.appointments.indexWhere((a) => a['id'] == id);
  if (apptIndex == -1) return;

  final appt = Map<String, dynamic>.from(DemoData.appointments[apptIndex]);
  final oldStart = appt['starts_at'] as String;
  final oldStaffId = appt['staff_id'] as String;
  final oldStaffName = appt['staff_name'] as String;

  // Locally update demo data (in memory only)
  DemoData.appointments[apptIndex] = {
    ...appt,
    'starts_at': newStart.toIso8601String(),
    'ends_at': newEnd.toIso8601String(),
    'staff_id': newStaffId,
    'staff_name': '$newStaffFirstName $newStaffLastName'.trim(),
  };

  // Refresh UI
  ref.invalidate(businessAppointmentsProvider);

  // Dismiss pulsing tooltip
  if (mounted) setState(() => _hasCompletedDemoDrag = true);

  // Call demo-reschedule edge function (fire-and-forget)
  try {
    await BCSupabase.client.functions.invoke('demo-reschedule', body: {
      'service_name': appt['service_name'] ?? 'Servicio',
      'client_name': appt['client_name'] ?? appt['profiles']?['full_name'] ?? 'Cliente',
      'staff_name': '$newStaffFirstName $newStaffLastName'.trim(),
      'salon_name': 'Salon de Vallarta',
      'new_start': newStart.toIso8601String(),
      'salon_phone': '+52 322 142 9800',
    });
  } catch (e) {
    debugPrint('[DemoReschedule] Edge function error: $e');
  }

  // Show success feedback
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('✅ Mensajes enviados a tu WhatsApp'),
        backgroundColor: const Color(0xFF9333ea),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Revert after 60 seconds
  Future.delayed(const Duration(seconds: 60), () {
    if (!mounted) return;
    final idx = DemoData.appointments.indexWhere((a) => a['id'] == id);
    if (idx == -1) return;
    DemoData.appointments[idx] = {
      ...DemoData.appointments[idx],
      'starts_at': oldStart,
      'ends_at': appt['ends_at'],
      'staff_id': oldStaffId,
      'staff_name': oldStaffName,
    };
    ref.invalidate(businessAppointmentsProvider);
  });
}
```

Add required imports:
```dart
import '../../data/demo_data.dart';
import '../../providers/demo_providers.dart';
```

**Step 3: Add `_hasCompletedDemoDrag` state variable**

In the stateful widget's State class, add:
```dart
bool _hasCompletedDemoDrag = false;
```

**Step 4: Verify**

```bash
cd /home/bc/futureBeauty/beautycita_web && /home/bc/flutter/bin/flutter analyze lib/pages/business/biz_calendar_page.dart
```

**Step 5: Commit**

```bash
cd /home/bc/futureBeauty
git add beautycita_web/lib/pages/business/biz_calendar_page.dart
git commit -m "feat: demo drop handler — WhatsApp messages + ephemeral move + auto-revert"
```

---

## Task 5: Deploy & Test

**Files:** None (deployment only)

**Step 1: Deploy edge function**

```bash
rsync -avz /home/bc/futureBeauty/beautycita_app/supabase/functions/ \
  www-bc:/var/www/beautycita.com/bc-flutter/supabase-docker/volumes/functions/
ssh www-bc "cd /var/www/beautycita.com/bc-flutter/supabase-docker && docker compose restart functions"
```

**Step 2: Build and deploy web**

```bash
cd /home/bc/futureBeauty/beautycita_web
/home/bc/flutter/bin/flutter build web --release --no-tree-shake-icons
rsync -avz --delete --exclude sativa build/web/ www-bc:/var/www/beautycita.com/frontend/dist/
```

**Step 3: Test the flow**

1. Open `beautycita.com/demo/calendar` in incognito
2. Try to drag an appointment → should show phone verification modal
3. Verify phone via the modal flow
4. Return to demo calendar → pulsing tooltip should appear
5. Drag an appointment to a new time slot
6. Confirm: WhatsApp message 1 arrives within 5 seconds (stylist label)
7. Confirm: WhatsApp message 2 arrives ~20 seconds later (client label)
8. Confirm: appointment visually moved in calendar
9. Wait 60 seconds → appointment silently reverts
10. Try dragging to an invalid slot (wrong service/collision) → red ghost block, no drop

**Step 4: Commit any fixes**

```bash
git add -A
git commit -m "fix: demo reschedule adjustments from testing"
```

**Step 5: Push**

```bash
git push origin main
```
