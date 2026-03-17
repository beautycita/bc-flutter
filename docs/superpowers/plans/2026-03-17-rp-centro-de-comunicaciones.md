# RP Centro de Comunicaciones Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the RP bottom-sheet salon detail with a full-screen Centro de Comunicaciones — a per-salon command post with BC-branded WhatsApp/Email chat, manual onboarding checklist, meeting scheduling, and close-out process.

**Architecture:** Three new Flutter screens (Centro, Chat, Checklist sheet) + expanded rp_provider.dart + one new migration (rp_checklist + rp_meetings tables + rp_assignments columns) + auth expansion on outreach-contact edge function. All communication flows through existing outreach-contact function and salon_outreach_log table. No new edge functions needed.

**Tech Stack:** Flutter/Riverpod, go_router, Supabase (Postgres + Edge Functions), existing outreach-contact edge function, beautypi WA API.

**Spec:** `docs/superpowers/specs/2026-03-17-rp-centro-de-comunicaciones-design.md`

---

## File Structure

### New Files
```
beautycita_app/lib/screens/rp/rp_centro_screen.dart    # Full-screen per-salon command post
beautycita_app/lib/screens/rp/rp_chat_screen.dart       # Chat view (WA and Email modes)
beautycita_app/supabase/migrations/20260317000000_rp_centro.sql  # New tables + columns
```

### Modified Files
```
beautycita_app/lib/screens/rp/rp_shell_screen.dart      # Slim down: remove bottom sheet, tap → Centro
beautycita_app/lib/providers/rp_provider.dart            # Add checklist, meetings, chat, close-out providers
beautycita_app/lib/config/routes.dart                    # Add routes for Centro + Chat screens
beautycita_app/supabase/functions/outreach-contact/index.ts  # Expand auth to accept 'rp' role
```

---

## Task 1: Database Migration — rp_checklist, rp_meetings, rp_assignments columns

**Files:**
- Create: `beautycita_app/supabase/migrations/20260317000000_rp_centro.sql`

- [ ] **Step 1: Write the migration file**

```sql
-- RP Centro de Comunicaciones — new tables + columns
-- rp_checklist: manual onboarding checklist per salon
-- rp_meetings: meeting scheduling between RP and salon
-- rp_assignments: add close-out columns

-- ── rp_checklist ──

CREATE TABLE IF NOT EXISTS rp_checklist (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  discovered_salon_id uuid NOT NULL REFERENCES discovered_salons(id) ON DELETE CASCADE,
  rp_user_id uuid NOT NULL REFERENCES profiles(id),
  item_key text NOT NULL,
  checked_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT rp_checklist_unique UNIQUE (discovered_salon_id, item_key)
);

CREATE INDEX idx_rp_checklist_salon ON rp_checklist(discovered_salon_id);

ALTER TABLE rp_checklist ENABLE ROW LEVEL SECURITY;

-- RPs can CRUD their own checklist items
CREATE POLICY rp_checklist_rp_select ON rp_checklist FOR SELECT USING (
  rp_user_id = auth.uid()
  OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'superadmin'))
);
CREATE POLICY rp_checklist_rp_insert ON rp_checklist FOR INSERT WITH CHECK (
  rp_user_id = auth.uid()
  OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'superadmin'))
);
CREATE POLICY rp_checklist_rp_update ON rp_checklist FOR UPDATE USING (
  rp_user_id = auth.uid()
  OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'superadmin'))
);
CREATE POLICY rp_checklist_rp_delete ON rp_checklist FOR DELETE USING (
  rp_user_id = auth.uid()
  OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'superadmin'))
);

-- ── rp_meetings ──

CREATE TABLE IF NOT EXISTS rp_meetings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  discovered_salon_id uuid NOT NULL REFERENCES discovered_salons(id) ON DELETE CASCADE,
  rp_user_id uuid NOT NULL REFERENCES profiles(id),
  proposed_at timestamptz NOT NULL,
  confirmed_at timestamptz,
  salon_proposed_at timestamptz,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'denied', 'rescheduled')),
  note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_rp_meetings_salon ON rp_meetings(discovered_salon_id);
CREATE INDEX idx_rp_meetings_rp ON rp_meetings(rp_user_id);

ALTER TABLE rp_meetings ENABLE ROW LEVEL SECURITY;

CREATE POLICY rp_meetings_rp_select ON rp_meetings FOR SELECT USING (
  rp_user_id = auth.uid()
  OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'superadmin'))
);
CREATE POLICY rp_meetings_rp_insert ON rp_meetings FOR INSERT WITH CHECK (
  rp_user_id = auth.uid()
  OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'superadmin'))
);
CREATE POLICY rp_meetings_rp_update ON rp_meetings FOR UPDATE USING (
  rp_user_id = auth.uid()
  OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'superadmin'))
);
CREATE POLICY rp_meetings_rp_delete ON rp_meetings FOR DELETE USING (
  rp_user_id = auth.uid()
  OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'superadmin'))
);

-- ── rp_assignments: add close-out columns ──

ALTER TABLE rp_assignments
  ADD COLUMN IF NOT EXISTS closed_at timestamptz,
  ADD COLUMN IF NOT EXISTS close_outcome text CHECK (close_outcome IN ('completed', 'not_converted')),
  ADD COLUMN IF NOT EXISTS close_reason text;
```

- [ ] **Step 2: Run migration on production**

```bash
ssh www-bc "cd /var/www/beautycita.com/bc-flutter/supabase-docker && \
  docker exec -i supabase-db psql -U postgres -d postgres" < \
  beautycita_app/supabase/migrations/20260317000000_rp_centro.sql
```

Expected: Tables created, columns added, no errors.

- [ ] **Step 3: Verify tables exist**

```bash
ssh www-bc "cd /var/www/beautycita.com/bc-flutter/supabase-docker && \
  docker exec supabase-db psql -U postgres -d postgres -c \"\dt rp_*\""
```

Expected: rp_assignments, rp_checklist, rp_meetings, rp_visits all listed.

- [ ] **Step 4: Commit**

```bash
git add beautycita_app/supabase/migrations/20260317000000_rp_centro.sql
git commit -m "feat: add rp_checklist + rp_meetings tables, close-out columns on rp_assignments"
```

---

## Task 2: Expand outreach-contact auth for RP role

**Files:**
- Modify: `beautycita_app/supabase/functions/outreach-contact/index.ts`

The spec says RPs get: send_wa, send_email, get_history, get_templates. They do NOT get: upload_recording, transcribe. log_call should also be available (RPs log visits/calls).

- [ ] **Step 1: Replace verifyAdmin with verifyUser that accepts admin + rp**

In `outreach-contact/index.ts`, rename `verifyAdmin` to `verifyAuthorized` and expand the role check:

```typescript
// ── Auth: verify admin/superadmin/rp ──

const RP_ALLOWED_ACTIONS = new Set([
  "send_wa", "send_email", "send_sms", "log_call",
  "get_history", "get_templates",
]);

const ADMIN_ONLY_ACTIONS = new Set([
  "upload_recording", "transcribe",
]);

async function verifyAuthorized(
  token: string,
  serviceClient: ReturnType<typeof createClient>,
  action: string,
): Promise<{ user: { id: string; role: string }; error?: Response }> {
  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const {
    data: { user },
    error: authError,
  } = await userClient.auth.getUser();

  if (authError || !user) {
    return { user: null as any, error: jsonResponse({ error: "Unauthorized" }, 401) };
  }

  const { data: profile } = await serviceClient
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .single();

  if (!profile) {
    return { user: null as any, error: jsonResponse({ error: "Profile not found" }, 403) };
  }

  const isAdmin = ["admin", "superadmin"].includes(profile.role);
  const isRp = profile.role === "rp";

  if (isAdmin) {
    return { user: { id: user.id, role: profile.role } };
  }

  if (isRp && RP_ALLOWED_ACTIONS.has(action)) {
    return { user: { id: user.id, role: profile.role } };
  }

  return { user: null as any, error: jsonResponse({ error: "Access denied" }, 403) };
}
```

- [ ] **Step 2: Update the call site**

Replace line ~152:
```typescript
// Old:
const { user, error: authErr } = await verifyAdmin(token, serviceClient);

// New:
const { user, error: authErr } = await verifyAuthorized(token, serviceClient, action);
```

- [ ] **Step 3: Add rp_user_id to salon_outreach_log inserts**

In the `send_wa` and `send_email` handlers, ensure `rp_user_id: user.id` is included in the insert to `salon_outreach_log`. Check if it's already there — the column exists from the outreach_command_center migration. If the insert already has it, no change needed.

- [ ] **Step 4: Deploy edge function**

```bash
rsync -avz beautycita_app/supabase/functions/ www-bc:/var/www/beautycita.com/bc-flutter/supabase-docker/volumes/functions/
ssh www-bc "cd /var/www/beautycita.com/bc-flutter/supabase-docker && docker compose restart functions"
```

- [ ] **Step 5: Commit**

```bash
git add beautycita_app/supabase/functions/outreach-contact/index.ts
git commit -m "feat: expand outreach-contact auth to allow RP role (send, log, history, templates)"
```

---

## Task 3: Expand rp_provider.dart — checklist, meetings, chat, close-out

**Files:**
- Modify: `beautycita_app/lib/providers/rp_provider.dart` (currently 161 lines)

- [ ] **Step 1: Add checklist providers and functions**

Append to `rp_provider.dart`. **IMPORTANT:** This file uses `SupabaseClientService.client` (not `Supabase.instance.client`). The import is already at the top: `import 'package:beautycita/services/supabase_client.dart';`

```dart
// ── Checklist ──

/// All 12 checklist item keys (7 required + 5 optional)
const kRpChecklistRequired = [
  'datos_negocio',
  'servicios',
  'staff',
  'horario_semanal',
  'rfc',
  'stripe_express',
  'info_dispersion',
];

const kRpChecklistOptional = [
  'instagram',
  'portfolio',
  'fotos_antes_despues',
  'calendario_sync',
  'licencia',
];

const kRpChecklistLabels = {
  'datos_negocio': 'Datos del negocio',
  'servicios': 'Servicios configurados',
  'staff': 'Staff registrado',
  'horario_semanal': 'Horario semanal',
  'rfc': 'RFC registrado',
  'stripe_express': 'Stripe Express completado',
  'info_dispersion': 'Información de dispersión',
  'instagram': 'Instagram importado',
  'portfolio': 'Portfolio curado',
  'fotos_antes_despues': 'Fotos antes/después',
  'calendario_sync': 'Calendario sincronizado',
  'licencia': 'Licencia de funcionamiento',
};

final rpChecklistProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, salonId) async {
    final sb = SupabaseClientService.client;
    final res = await sb
        .from('rp_checklist')
        .select()
        .eq('discovered_salon_id', salonId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(res);
  },
);

Future<void> rpToggleChecklistItem({
  required String salonId,
  required String itemKey,
  required bool checked,
  String? notes,
}) async {
  final sb = SupabaseClientService.client;
  final userId = SupabaseClientService.currentUserId!;

  if (checked) {
    await sb.from('rp_checklist').upsert({
      'discovered_salon_id': salonId,
      'rp_user_id': userId,
      'item_key': itemKey,
      'checked_at': DateTime.now().toIso8601String(),
      if (notes != null) 'notes': notes,
    }, onConflict: 'discovered_salon_id,item_key');
  } else {
    await sb
        .from('rp_checklist')
        .delete()
        .eq('discovered_salon_id', salonId)
        .eq('item_key', itemKey);
  }
}
```

- [ ] **Step 2: Add meetings providers and functions**

```dart
// ── Meetings ──

final rpNextMeetingProvider = FutureProvider.family<Map<String, dynamic>?, String>(
  (ref, salonId) async {
    final sb = SupabaseClientService.client;
    final res = await sb
        .from('rp_meetings')
        .select()
        .eq('discovered_salon_id', salonId)
        .inFilter('status', ['pending', 'confirmed', 'rescheduled'])
        .gte('proposed_at', DateTime.now().toIso8601String())
        .order('proposed_at')
        .limit(1)
        .maybeSingle();
    return res;
  },
);

Future<String> rpCreateMeeting({
  required String salonId,
  required DateTime proposedAt,
  String? note,
}) async {
  final sb = SupabaseClientService.client;
  final userId = SupabaseClientService.currentUserId!;
  final res = await sb.from('rp_meetings').insert({
    'discovered_salon_id': salonId,
    'rp_user_id': userId,
    'proposed_at': proposedAt.toIso8601String(),
    'note': note,
  }).select('id').single();
  return res['id'] as String;
}

Future<void> rpUpdateMeetingStatus({
  required String meetingId,
  required String status,
  DateTime? salonProposedAt,
}) async {
  final sb = SupabaseClientService.client;
  await sb.from('rp_meetings').update({
    'status': status,
    'updated_at': DateTime.now().toIso8601String(),
    if (status == 'confirmed') 'confirmed_at': DateTime.now().toIso8601String(),
    if (salonProposedAt != null) 'salon_proposed_at': salonProposedAt.toIso8601String(),
  }).eq('id', meetingId);
}
```

- [ ] **Step 3: Add chat history provider (reads from salon_outreach_log)**

```dart
// ── Chat History ──

final rpChatHistoryProvider = FutureProvider.family<List<Map<String, dynamic>>, ({String salonId, String? channel})>(
  (ref, params) async {
    final sb = SupabaseClientService.client;
    final res = await sb.functions.invoke('outreach-contact', body: {
      'action': 'get_history',
      'discovered_salon_id': params.salonId,
    });
    if (res.status != 200) return [];
    final data = res.data;
    final history = List<Map<String, dynamic>>.from(data['history'] ?? []);
    if (params.channel != null) {
      return history.where((h) => h['channel'] == params.channel).toList();
    }
    return history;
  },
);

final rpTemplatesProvider = FutureProvider.family<List<Map<String, dynamic>>, String?>(
  (ref, channel) async {
    final sb = SupabaseClientService.client;
    final res = await sb.functions.invoke('outreach-contact', body: {
      'action': 'get_templates',
      if (channel != null) 'channel': channel,
    });
    if (res.status != 200) return [];
    return List<Map<String, dynamic>>.from(res.data['templates'] ?? []);
  },
);
```

- [ ] **Step 4: Add send message function**

```dart
// ── Send Message ──

Future<bool> rpSendMessage({
  required String salonId,
  required String channel, // 'whatsapp' or 'email'
  required String message,
  String? subject, // email only
  String? templateId,
}) async {
  final sb = SupabaseClientService.client;
  final profile = await sb.from('profiles').select('display_name, phone').eq('id', sb.auth.currentUser!.id).single();

  final action = channel == 'email' ? 'send_email' : 'send_wa';
  final res = await sb.functions.invoke('outreach-contact', body: {
    'action': action,
    'discovered_salon_id': salonId,
    'message': message,
    if (subject != null) 'subject': subject,
    if (templateId != null) 'template_id': templateId,
    'rp_name': profile['display_name'] ?? 'RP',
    'rp_phone': profile['phone'] ?? '',
  });
  return res.status == 200 && (res.data['sent'] == true || res.data['logged'] == true);
}
```

- [ ] **Step 5: Add close-out function**

```dart
// ── Close Process ──

Future<void> rpCloseProcess({
  required String salonId,
  required String assignmentId,
  required String outcome, // 'completed' or 'not_converted'
  String? reason, // required when not_converted
}) async {
  final sb = SupabaseClientService.client;

  // Update assignment
  await sb.from('rp_assignments').update({
    'closed_at': DateTime.now().toIso8601String(),
    'close_outcome': outcome,
    if (reason != null) 'close_reason': reason,
  }).eq('id', assignmentId);

  if (outcome == 'not_converted') {
    // Unassign: clear RP, reset status
    await sb.from('discovered_salons').update({
      'assigned_rp_id': null,
      'rp_status': 'unassigned',
    }).eq('id', salonId);
  } else {
    // Mark converted
    await sb.from('discovered_salons').update({
      'rp_status': 'converted',
    }).eq('id', salonId);
  }
}
```

- [ ] **Step 6: Commit**

```bash
git add beautycita_app/lib/providers/rp_provider.dart
git commit -m "feat: expand rp_provider — checklist, meetings, chat, send, close-out"
```

---

## Task 4: Add routes for Centro + Chat screens

**Files:**
- Modify: `beautycita_app/lib/config/routes.dart`

- [ ] **Step 1: Add imports and route constants**

At top of routes.dart, add import lines:
```dart
import 'package:beautycita/screens/rp/rp_centro_screen.dart';
import 'package:beautycita/screens/rp/rp_chat_screen.dart';
```

Add route path constants (find where `static const rp = '/rp'` is defined):
```dart
static const rpCentro = '/rp/centro';
static const rpChat = '/rp/chat';
```

- [ ] **Step 2: Add GoRoute entries after the existing rp route**

```dart
GoRoute(
  path: rpCentro,
  name: 'rp-centro',
  pageBuilder: (context, state) {
    final salon = state.extra as Map<String, dynamic>;
    return CustomTransitionPage(
      key: state.pageKey,
      child: RPCentroScreen(salon: salon),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeInOutCubic));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  },
),
GoRoute(
  path: rpChat,
  name: 'rp-chat',
  pageBuilder: (context, state) {
    final args = state.extra as Map<String, dynamic>;
    return CustomTransitionPage(
      key: state.pageKey,
      child: RPChatScreen(
        salon: args['salon'] as Map<String, dynamic>,
        channel: args['channel'] as String,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeInOutCubic));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  },
),
```

- [ ] **Step 3: Commit**

```bash
git add beautycita_app/lib/config/routes.dart
git commit -m "feat: add routes for RP Centro + Chat screens"
```

---

## Task 5: Build RPCentroScreen — the full-screen per-salon command post

**Files:**
- Create: `beautycita_app/lib/screens/rp/rp_centro_screen.dart`

This is the main screen. Sections: header, 2x2 action grid, último contacto, próxima reunión, quick links, cerrar proceso.

- [ ] **Step 1: Create the screen scaffold with header**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:beautycita/config/constants.dart';
import 'package:beautycita/config/routes.dart';
import 'package:beautycita/providers/rp_provider.dart';
import 'package:beautycita/services/toast_service.dart';

class RPCentroScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> salon;
  const RPCentroScreen({super.key, required this.salon});

  @override
  ConsumerState<RPCentroScreen> createState() => _RPCentroScreenState();
}

class _RPCentroScreenState extends ConsumerState<RPCentroScreen> {
  Map<String, dynamic> get salon => widget.salon;
  String get salonId => salon['id'] as String;

  @override
  Widget build(BuildContext context) {
    final checklist = ref.watch(rpChecklistProvider(salonId));
    final nextMeeting = ref.watch(rpNextMeetingProvider(salonId));
    final chatHistory = ref.watch(rpChatHistoryProvider((salonId: salonId, channel: null)));

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(salon['business_name'] ?? 'Salon', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(rpChecklistProvider(salonId));
          ref.invalidate(rpNextMeetingProvider(salonId));
          ref.invalidate(rpChatHistoryProvider((salonId: salonId, channel: null)));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildActionGrid(),
            const SizedBox(height: 20),
            _buildUltimoContacto(chatHistory),
            const SizedBox(height: 16),
            _buildProximaReunion(nextMeeting),
            const SizedBox(height: 16),
            _buildQuickLinks(),
            const SizedBox(height: 32),
            _buildCerrarProceso(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 2: Build header section**

```dart
  Widget _buildHeader() {
    final city = salon['location_city'] ?? '';
    final state = salon['location_state'] ?? '';
    final rating = salon['rating_average'];
    final reviews = salon['rating_count'] ?? 0;
    final status = salon['rp_status'] ?? 'unassigned';

    // Checklist progress
    final checklist = ref.watch(rpChecklistProvider(salonId));
    final checkedCount = checklist.whenOrNull(
      data: (items) => items.where((i) => i['checked_at'] != null).length,
    ) ?? 0;
    final requiredChecked = checklist.whenOrNull(
      data: (items) => items
          .where((i) => kRpChecklistRequired.contains(i['item_key']) && i['checked_at'] != null)
          .length,
    ) ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (city.isNotEmpty || state.isNotEmpty)
          Text('$city${city.isNotEmpty && state.isNotEmpty ? ', ' : ''}$state',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Row(
          children: [
            if (rating != null) ...[
              Icon(Icons.star, size: 16, color: Colors.amber.shade700),
              const SizedBox(width: 4),
              Text('$rating', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
              Text(' ($reviews)', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade500)),
              const SizedBox(width: 12),
            ],
            _statusBadge(status),
            const Spacer(),
            Text('$requiredChecked/7 requeridos',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
          ],
        ),
      ],
    );
  }

  Widget _statusBadge(String status) {
    final labels = {
      'unassigned': 'Sin asignar',
      'assigned': 'Sin visitar',
      'visited': 'Contactado',
      'contacted': 'Contactado',
      'onboarding': 'En onboarding',
      'onboarding_complete': 'Completado',
      'converted': 'Convertido',
      'declined': 'Rechazado',
    };
    final colors = {
      'unassigned': Colors.grey,
      'assigned': Colors.blue,
      'visited': Colors.orange,
      'contacted': Colors.orange,
      'onboarding': Colors.purple,
      'onboarding_complete': Colors.green,
      'converted': Colors.green.shade800,
      'declined': Colors.red,
    };
    final label = labels[status] ?? status;
    final color = colors[status] ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
```

- [ ] **Step 3: Build 2x2 action grid**

```dart
  Widget _buildActionGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _actionCard(
                icon: Icons.chat,
                label: 'BC WhatsApp',
                subtitle: 'Enviar como BeautyCita',
                gradient: const [Color(0xFF25D366), Color(0xFF128C7E)],
                onTap: () => context.push(AppRoutes.rpChat, extra: {'salon': salon, 'channel': 'whatsapp'}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionCard(
                icon: Icons.email,
                label: 'Email',
                subtitle: 'Enviar como BeautyCita',
                gradient: const [Color(0xFF2196F3), Color(0xFF1565C0)],
                onTap: () => context.push(AppRoutes.rpChat, extra: {'salon': salon, 'channel': 'email'}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _actionCardOutline(
                icon: Icons.checklist,
                label: 'Checklist',
                subtitle: _checklistSubtitle(),
                onTap: () => _showChecklist(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionCardOutline(
                icon: Icons.calendar_month,
                label: 'Agendar',
                subtitle: 'Solicitar reunión',
                onTap: () => _showMeetingDialog(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _checklistSubtitle() {
    final checklist = ref.watch(rpChecklistProvider(salonId));
    final count = checklist.whenOrNull(
      data: (items) => items
          .where((i) => kRpChecklistRequired.contains(i['item_key']) && i['checked_at'] != null)
          .length,
    ) ?? 0;
    return '$count de 7 requeridos';
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 8),
              Text(label, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
              Text(subtitle, style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionCardOutline({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.grey.shade700, size: 28),
              const SizedBox(height: 8),
              Text(label, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
              Text(subtitle, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ),
      ),
    );
  }
```

- [ ] **Step 4: Build último contacto + próxima reunión sections**

```dart
  Widget _buildUltimoContacto(AsyncValue<List<Map<String, dynamic>>> chatHistory) {
    return chatHistory.when(
      data: (history) {
        if (history.isEmpty) {
          return _sectionCard('Último Contacto', child: Text('Sin contacto registrado',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400)));
        }
        final last = history.first;
        final channel = last['channel'] ?? '';
        final time = last['sent_at'] ?? '';
        final text = last['message_text'] ?? last['notes'] ?? '';
        final icon = channel == 'whatsapp' ? Icons.chat : channel == 'email' ? Icons.email : Icons.person;
        final timeAgo = _timeAgo(time);

        return _sectionCard('Último Contacto', child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey.shade500),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text.length > 80 ? '${text.substring(0, 80)}...' : text,
                style: GoogleFonts.poppins(fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(timeAgo, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade400)),
          ],
        ));
      },
      loading: () => _sectionCard('Último Contacto', child: const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      error: (e, _) => _sectionCard('Último Contacto', child: Text('Error', style: GoogleFonts.poppins(fontSize: 13, color: Colors.red))),
    );
  }

  Widget _buildProximaReunion(AsyncValue<Map<String, dynamic>?> nextMeeting) {
    return nextMeeting.when(
      data: (meeting) {
        if (meeting == null) {
          return _sectionCard('Próxima Reunión', child: Text('Sin reuniones programadas',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade400)));
        }
        final date = DateTime.tryParse(meeting['proposed_at'] ?? '');
        final status = meeting['status'] ?? 'pending';
        final note = meeting['note'] ?? '';
        final statusColors = {
          'pending': Colors.amber,
          'confirmed': Colors.green,
          'denied': Colors.red,
          'rescheduled': Colors.orange,
        };
        final statusLabels = {
          'pending': 'Pendiente',
          'confirmed': 'Confirmada',
          'denied': 'Rechazada',
          'rescheduled': 'Reagendada',
        };

        return _sectionCard('Próxima Reunión', child: Row(
          children: [
            Icon(Icons.calendar_today, size: 18, color: Colors.grey.shade500),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (date != null)
                    Text(DateFormat('dd MMM yyyy, HH:mm', 'es').format(date),
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
                  if (note.isNotEmpty)
                    Text(note, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (statusColors[status] ?? Colors.grey).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(statusLabels[status] ?? status,
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600,
                      color: statusColors[status] ?? Colors.grey)),
            ),
          ],
        ));
      },
      loading: () => _sectionCard('Próxima Reunión', child: const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      error: (e, _) => _sectionCard('Próxima Reunión', child: Text('Error', style: GoogleFonts.poppins(fontSize: 13, color: Colors.red))),
    );
  }

  Widget _sectionCard(String title, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  String _timeAgo(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    if (diff.inDays < 7) return 'hace ${diff.inDays}d';
    return DateFormat('dd MMM').format(dt);
  }
```

- [ ] **Step 5: Build quick links + cerrar proceso**

```dart
  Widget _buildQuickLinks() {
    final web = salon['website'] as String?;
    final ig = salon['instagram_url'] as String?;
    final fb = salon['facebook_url'] as String?;
    final lat = salon['latitude'];
    final lng = salon['longitude'];

    final links = <Widget>[];
    if (web != null && web.isNotEmpty) {
      links.add(_linkChip(Icons.language, 'Web', web));
    }
    if (ig != null && ig.isNotEmpty) {
      links.add(_linkChip(Icons.camera_alt, 'Instagram', ig));
    }
    if (fb != null && fb.isNotEmpty) {
      links.add(_linkChip(Icons.facebook, 'Facebook', fb));
    }
    if (lat != null && lng != null) {
      links.add(_linkChip(Icons.navigation, 'Navegar', 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'));
    }

    if (links.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 8, runSpacing: 8, children: links);
  }

  Widget _linkChip(IconData icon, String label, String url) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: GoogleFonts.poppins(fontSize: 12)),
      onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    );
  }

  Widget _buildCerrarProceso() {
    return OutlinedButton.icon(
      onPressed: () => _showCerrarDialog(),
      icon: const Icon(Icons.close, color: Colors.red),
      label: Text('Cerrar Proceso', style: GoogleFonts.poppins(color: Colors.red)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.red),
        padding: const EdgeInsets.symmetric(vertical: 14),
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
```

- [ ] **Step 6: Build checklist bottom sheet dialog**

```dart
  void _showChecklist() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ChecklistSheet(salonId: salonId, ref: ref),
    );
  }
```

Create the `_ChecklistSheet` as a private StatefulWidget within the same file:

```dart
class _ChecklistSheet extends ConsumerStatefulWidget {
  final String salonId;
  final WidgetRef ref;
  const _ChecklistSheet({required this.salonId, required this.ref});

  @override
  ConsumerState<_ChecklistSheet> createState() => _ChecklistSheetState();
}

class _ChecklistSheetState extends ConsumerState<_ChecklistSheet> {
  @override
  Widget build(BuildContext context) {
    final checklist = ref.watch(rpChecklistProvider(widget.salonId));
    final checkedKeys = checklist.whenOrNull(
      data: (items) => {for (final i in items) if (i['checked_at'] != null) i['item_key'] as String},
    ) ?? <String>{};

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          controller: scrollController,
          children: [
            Text('Checklist de Onboarding', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Text('Requeridos', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            ...kRpChecklistRequired.map((key) => _checkItem(key, checkedKeys.contains(key))),
            const SizedBox(height: 16),
            Text('Opcionales', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            ...kRpChecklistOptional.map((key) => _checkItem(key, checkedKeys.contains(key))),
          ],
        ),
      ),
    );
  }

  Widget _checkItem(String key, bool checked) {
    return CheckboxListTile(
      value: checked,
      title: Text(kRpChecklistLabels[key] ?? key, style: GoogleFonts.poppins(fontSize: 14)),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      onChanged: (val) async {
        await rpToggleChecklistItem(salonId: widget.salonId, itemKey: key, checked: val ?? false);
        ref.invalidate(rpChecklistProvider(widget.salonId));
      },
    );
  }
}
```

- [ ] **Step 7: Build meeting request dialog**

```dart
  void _showMeetingDialog() {
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Solicitar Reunión', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(selectedDate != null
                    ? DateFormat('dd MMM yyyy').format(selectedDate!)
                    : 'Seleccionar fecha'),
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (d != null) setDialogState(() => selectedDate = d);
                },
              ),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: Text(selectedTime != null
                    ? selectedTime!.format(ctx)
                    : 'Seleccionar hora'),
                onTap: () async {
                  final t = await showTimePicker(context: ctx, initialTime: const TimeOfDay(hour: 10, minute: 0));
                  if (t != null) setDialogState(() => selectedTime = t);
                },
              ),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(hintText: 'Nota (opcional)'),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: (selectedDate == null || selectedTime == null)
                  ? null
                  : () async {
                      final proposedAt = DateTime(
                        selectedDate!.year, selectedDate!.month, selectedDate!.day,
                        selectedTime!.hour, selectedTime!.minute,
                      );
                      await rpCreateMeeting(salonId: salonId, proposedAt: proposedAt, note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
                      ref.invalidate(rpNextMeetingProvider(salonId));
                      if (ctx.mounted) Navigator.pop(ctx);
                      ToastService.show(context, 'Reunión solicitada');

                      // Send WA to salon about the meeting
                      final salonName = salon['business_name'] ?? '';
                      final fecha = DateFormat('dd MMM yyyy').format(proposedAt);
                      final hora = DateFormat('HH:mm').format(proposedAt);
                      final nota = noteCtrl.text.trim();
                      final msg = 'Hola $salonName, somos BeautyCita. Nos gustaría visitarte el $fecha a las $hora${nota.isNotEmpty ? ' para $nota' : ''}. ¿Te funciona? Puedes responder con: Sí / No / Proponer otro horario';
                      await rpSendMessage(salonId: salonId, channel: 'whatsapp', message: msg);
                    },
              child: const Text('Solicitar'),
            ),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 8: Build cerrar proceso dialog**

```dart
  void _showCerrarDialog() {
    String? outcome;
    String? reason;
    final reasonCtrl = TextEditingController();
    final reasons = ['No interesado', 'Ya tiene sistema', 'Cerró el negocio', 'No contactable', 'Otro'];
    String? selectedReason;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Cerrar Proceso', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('¿El salón se registró en BeautyCita?', style: GoogleFonts.poppins(fontSize: 14)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Sí, completado'),
                      selected: outcome == 'completed',
                      onSelected: (_) => setDialogState(() { outcome = 'completed'; selectedReason = null; }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('No'),
                      selected: outcome == 'not_converted',
                      onSelected: (_) => setDialogState(() => outcome = 'not_converted'),
                    ),
                  ),
                ],
              ),
              if (outcome == 'not_converted') ...[
                const SizedBox(height: 16),
                Text('Razón:', style: GoogleFonts.poppins(fontSize: 14)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: reasons.map((r) => ChoiceChip(
                    label: Text(r, style: GoogleFonts.poppins(fontSize: 12)),
                    selected: selectedReason == r,
                    onSelected: (_) => setDialogState(() => selectedReason = r),
                  )).toList(),
                ),
                if (selectedReason == 'Otro') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonCtrl,
                    decoration: const InputDecoration(hintText: 'Especificar razón'),
                  ),
                ],
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: outcome == null || (outcome == 'not_converted' && selectedReason == null)
                  ? null
                  : () async {
                      final assignmentId = await getActiveAssignmentId(salonId);
                      if (assignmentId == null) {
                        ToastService.show(context, 'No se encontró asignación activa');
                        return;
                      }
                      final finalReason = selectedReason == 'Otro' ? reasonCtrl.text.trim() : selectedReason;
                      await rpCloseProcess(
                        salonId: salonId,
                        assignmentId: assignmentId,
                        outcome: outcome!,
                        reason: outcome == 'not_converted' ? finalReason : null,
                      );
                      ref.invalidate(rpAssignedSalonsProvider);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ToastService.show(context, outcome == 'completed' ? 'Proceso cerrado: Convertido' : 'Proceso cerrado');
                        context.pop();
                      }
                    },
              child: const Text('Cerrar Proceso'),
            ),
          ],
        ),
      ),
    );
  }
} // end _RPCentroScreenState
```

- [ ] **Step 9: Verify it compiles**

```bash
cd beautycita_app && /home/bc/flutter/bin/flutter analyze lib/screens/rp/rp_centro_screen.dart
```

Expected: No errors (warnings OK for now).

- [ ] **Step 10: Commit**

```bash
git add beautycita_app/lib/screens/rp/rp_centro_screen.dart
git commit -m "feat: RPCentroScreen — full-screen per-salon command post with action grid, checklist, meetings, close-out"
```

---

## Task 6: Build RPChatScreen — WA and Email chat view

**Files:**
- Create: `beautycita_app/lib/screens/rp/rp_chat_screen.dart`

Full-screen chat page with message thread, template picker, visit log, and text input.

- [ ] **Step 1: Create the chat screen scaffold**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:beautycita/providers/rp_provider.dart';
import 'package:beautycita/services/toast_service.dart';

class RPChatScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> salon;
  final String channel; // 'whatsapp' or 'email'

  const RPChatScreen({super.key, required this.salon, required this.channel});

  @override
  ConsumerState<RPChatScreen> createState() => _RPChatScreenState();
}

class _RPChatScreenState extends ConsumerState<RPChatScreen> {
  final _messageCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  String get salonId => widget.salon['id'] as String;
  String get salonName => widget.salon['business_name'] as String? ?? 'Salon';
  bool get isEmail => widget.channel == 'email';
  Color get channelColor => isEmail ? const Color(0xFF1565C0) : const Color(0xFF25D366);

  @override
  void dispose() {
    _messageCtrl.dispose();
    _subjectCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(rpChatHistoryProvider((salonId: salonId, channel: widget.channel)));

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: channelColor,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Color(0xFFec4899), Color(0xFF9333ea)]),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${isEmail ? "Email" : "BC WhatsApp"} — $salonName',
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildThread(history)),
          _buildInputArea(),
        ],
      ),
    );
  }
```

- [ ] **Step 2: Build message thread**

```dart
  Widget _buildThread(AsyncValue<List<Map<String, dynamic>>> history) {
    return history.when(
      data: (messages) {
        if (messages.isEmpty) {
          return Center(
            child: Text('Sin mensajes — envía el primero',
                style: GoogleFonts.poppins(color: Colors.grey.shade400)),
          );
        }
        // Messages come newest-first from API; reverse for chat display
        final reversed = messages.reversed.toList();
        return ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: reversed.length,
          itemBuilder: (_, i) {
            final msg = reversed[i];
            final prev = i > 0 ? reversed[i - 1] : null;
            return _buildMessage(msg, prev);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg, Map<String, dynamic>? prev) {
    final channel = msg['channel'] ?? '';
    final text = msg['message_text'] ?? msg['notes'] ?? '';
    final sentAt = msg['sent_at'] ?? '';
    final rpName = msg['rp_display_name'] ?? '';
    final isVisit = channel == 'in_person' || channel == 'phone_call';
    // All salon_outreach_log entries are outbound (inbound WA goes to chat_messages table)
    const isInbound = false;

    // Date separator
    Widget? dateSeparator;
    final msgDate = DateTime.tryParse(sentAt);
    final prevDate = prev != null ? DateTime.tryParse(prev['sent_at'] ?? '') : null;
    if (msgDate != null && (prevDate == null || !_sameDay(msgDate, prevDate))) {
      dateSeparator = Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(DateFormat('dd MMM yyyy').format(msgDate),
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade700)),
          ),
        ),
      );
    }

    // Visit/call system card
    if (isVisit) {
      return Column(
        children: [
          if (dateSeparator != null) dateSeparator,
          _systemCard(msg),
        ],
      );
    }

    // Chat bubble
    final isOutbound = !isInbound;
    return Column(
      children: [
        if (dateSeparator != null) dateSeparator,
        Align(
          alignment: isOutbound ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isOutbound ? channelColor.withValues(alpha: 0.9) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: GoogleFonts.poppins(fontSize: 14, color: isOutbound ? Colors.white : Colors.black87)),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (rpName.isNotEmpty && isOutbound) ...[
                      Text('— $rpName', style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFFec4899))),
                      const SizedBox(width: 8),
                    ],
                    Text(msgDate != null ? DateFormat('HH:mm').format(msgDate) : '',
                        style: GoogleFonts.poppins(fontSize: 10, color: isOutbound ? Colors.white70 : Colors.grey.shade400)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _systemCard(Map<String, dynamic> msg) {
    final channel = msg['channel'] ?? '';
    final notes = msg['notes'] ?? '';
    final outcome = msg['outcome'] ?? '';
    final sentAt = msg['sent_at'] ?? '';
    final rpName = msg['rp_display_name'] ?? '';
    final icon = channel == 'in_person' ? Icons.person_pin : Icons.phone;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade500),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (outcome.isNotEmpty)
                  Text(outcome, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                if (notes.isNotEmpty)
                  Text(notes, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
                Text('$rpName — ${_formatTime(sentAt)}',
                    style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade400)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime? b) => b != null && a.year == b.year && a.month == b.month && a.day == b.day;
  String _formatTime(String iso) {
    final dt = DateTime.tryParse(iso);
    return dt != null ? DateFormat('dd MMM HH:mm').format(dt) : '';
  }
```

- [ ] **Step 3: Build input area with chips and text field**

```dart
  Widget _buildInputArea() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 12, right: 12, top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quick-action chips
          Row(
            children: [
              ActionChip(
                avatar: const Icon(Icons.description, size: 16),
                label: Text('Plantillas', style: GoogleFonts.poppins(fontSize: 12)),
                onPressed: () => _showTemplates(),
              ),
              const SizedBox(width: 8),
              ActionChip(
                avatar: const Icon(Icons.person_pin_circle, size: 16),
                label: Text('Registrar visita', style: GoogleFonts.poppins(fontSize: 12)),
                onPressed: () => _showVisitLog(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Subject line for email
          if (isEmail) ...[
            TextField(
              controller: _subjectCtrl,
              decoration: InputDecoration(
                hintText: 'Asunto',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(height: 8),
          ],
          // Message input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageCtrl,
                  decoration: InputDecoration(
                    hintText: 'Escribe un mensaje...',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  style: GoogleFonts.poppins(fontSize: 14),
                  maxLines: 4,
                  minLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: channelColor),
                icon: _sending
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send, color: Colors.white),
                onPressed: _sending ? null : _send,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      final sent = await rpSendMessage(
        salonId: salonId,
        channel: widget.channel,
        message: text,
        subject: isEmail ? _subjectCtrl.text.trim() : null,
      );
      if (sent) {
        _messageCtrl.clear();
        if (isEmail) _subjectCtrl.clear();
        ref.invalidate(rpChatHistoryProvider((salonId: salonId, channel: widget.channel)));
        ToastService.show(context, 'Enviado');
      } else {
        ToastService.show(context, 'Error al enviar');
      }
    } catch (e) {
      ToastService.show(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
```

- [ ] **Step 4: Build template picker bottom sheet**

```dart
  void _showTemplates() {
    final channel = widget.channel;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        final templates = ref.watch(rpTemplatesProvider(channel));
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) => Padding(
            padding: const EdgeInsets.all(20),
            child: templates.when(
              data: (list) {
                if (list.isEmpty) {
                  return Center(child: Text('Sin plantillas disponibles', style: GoogleFonts.poppins(color: Colors.grey)));
                }
                // Group by category
                final grouped = <String, List<Map<String, dynamic>>>{};
                for (final t in list) {
                  final cat = t['category'] as String? ?? 'general';
                  grouped.putIfAbsent(cat, () => []).add(t);
                }
                return ListView(
                  controller: scrollController,
                  children: [
                    Text('Plantillas', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    for (final entry in grouped.entries) ...[
                      Text(entry.key.toUpperCase(), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                      const SizedBox(height: 4),
                      ...entry.value.map((t) => ListTile(
                        title: Text(t['name'] ?? '', style: GoogleFonts.poppins(fontSize: 14)),
                        subtitle: Text(
                          (t['body_template'] ?? '').toString().substring(0, (t['body_template'] ?? '').toString().length.clamp(0, 60)),
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          // Substitute variables
                          var body = t['body_template'] as String? ?? '';
                          body = body
                              .replaceAll('{salon_name}', salonName)
                              .replaceAll('{city}', widget.salon['location_city'] ?? '')
                              .replaceAll('{rating}', '${widget.salon['rating_average'] ?? ''}')
                              .replaceAll('{review_count}', '${widget.salon['rating_count'] ?? ''}')
                              .replaceAll('{interest_count}', '${widget.salon['interest_count'] ?? 0}');
                          _messageCtrl.text = body;
                          if (isEmail && t['subject'] != null) {
                            _subjectCtrl.text = (t['subject'] as String)
                                .replaceAll('{salon_name}', salonName);
                          }
                          Navigator.pop(context);
                        },
                      )),
                      const Divider(),
                    ],
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        );
      },
    );
  }
```

- [ ] **Step 5: Build visit log dialog**

```dart
  void _showVisitLog() {
    String? outcome;
    final notesCtrl = TextEditingController();
    final outcomes = ['Interesada', 'No interesada', 'Callback', 'Sin respuesta', 'Registrada'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Registrar Visita', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Resultado:', style: GoogleFonts.poppins(fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: outcomes.map((o) => ChoiceChip(
                  label: Text(o, style: GoogleFonts.poppins(fontSize: 12)),
                  selected: outcome == o,
                  onSelected: (_) => setDialogState(() => outcome = o),
                )).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(hintText: 'Notas (opcional)'),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: outcome == null
                  ? null
                  : () async {
                      final sb = SupabaseClientService.client;
                      await sb.functions.invoke('outreach-contact', body: {
                        'action': 'log_call',
                        'discovered_salon_id': salonId,
                        'channel': 'in_person',
                        'outcome': outcome!.toLowerCase().replaceAll(' ', '_'),
                        'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                      });
                      ref.invalidate(rpChatHistoryProvider((salonId: salonId, channel: widget.channel)));
                      if (ctx.mounted) Navigator.pop(ctx);
                      ToastService.show(context, 'Visita registrada');
                    },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
```

Add the SupabaseClientService import at the top of the file:
```dart
import 'package:beautycita/services/supabase_client.dart';
```

- [ ] **Step 6: Verify it compiles**

```bash
cd beautycita_app && /home/bc/flutter/bin/flutter analyze lib/screens/rp/rp_chat_screen.dart
```

- [ ] **Step 7: Commit**

```bash
git add beautycita_app/lib/screens/rp/rp_chat_screen.dart
git commit -m "feat: RPChatScreen — WA/Email chat view with templates, visit log, message thread"
```

---

## Task 7: Slim down rp_shell_screen.dart — remove bottom sheet, tap → Centro

**Files:**
- Modify: `beautycita_app/lib/screens/rp/rp_shell_screen.dart` (1045 lines → ~500 lines)

- [ ] **Step 1: Remove the bottom sheet method and all its sub-builders**

Delete these methods entirely:
- `_showSalonDetailSheet()` (~lines 400-900)
- `_buildInfoSection()`
- `_buildLinksSection()`
- `_buildPhoneSection()`
- `_buildVisitHistory()`
- `_buildActionButtons()`
- `_showLogVisitDialog()`

- [ ] **Step 2: Update salon card tap to navigate to Centro**

In `_buildSalonCard()`, change the `onTap` from `_showSalonDetailSheet(salon)` to:
```dart
onTap: () => context.push(AppRoutes.rpCentro, extra: salon),
```

- [ ] **Step 3: Update map pin tap to navigate to Centro**

In `_buildMapTab()`, find the marker onTap and change from `_showSalonDetailSheet` to:
```dart
onTap: () => context.push(AppRoutes.rpCentro, extra: salon),
```

- [ ] **Step 4: Add import for routes**

Ensure this import exists at top:
```dart
import 'package:beautycita/config/routes.dart';
```

- [ ] **Step 5: Keep _showNearbyUnvisited as-is** (it's useful for field routing per spec)

- [ ] **Step 6: Verify it compiles**

```bash
cd beautycita_app && /home/bc/flutter/bin/flutter analyze lib/screens/rp/rp_shell_screen.dart
```

- [ ] **Step 7: Commit**

```bash
git add beautycita_app/lib/screens/rp/rp_shell_screen.dart
git commit -m "refactor: slim rp_shell_screen — remove bottom sheet, tap navigates to Centro"
```

---

## Task 8: Full integration verify

- [ ] **Step 1: Run full app analysis**

```bash
cd beautycita_app && /home/bc/flutter/bin/flutter analyze
```

Fix any errors.

- [ ] **Step 2: Test the flow on device**

```bash
cd beautycita_app && /home/bc/flutter/bin/flutter run -d 192.168.0.25:5555
```

Test flow: Log in as RP → Map/List → tap salon → Centro opens → tap BC WhatsApp → Chat opens → type message → send → back → tap Checklist → check items → back → tap Agendar → set date/time → submit → verify meeting shows on Centro → Cerrar Proceso.

- [ ] **Step 3: Commit any fixes**

```bash
git add -A && git commit -m "fix: integration fixes for RP Centro de Comunicaciones"
```

---

## Dependency Order

```
Task 1 (migration) ──────────────────────────┐
Task 2 (edge function auth) ─────────────────┤
Task 3 (provider expansion) ─────────────────┤── can run in parallel
Task 4 (routes) ─────────────────────────────┘
Task 5 (Centro screen) ──── depends on Tasks 3, 4
Task 6 (Chat screen) ─────── depends on Tasks 3, 4
Task 7 (Shell slim-down) ── depends on Tasks 4, 5
Task 8 (integration) ─────── depends on all above
```

Tasks 1-4 are independent and can be built in parallel.
Tasks 5+6 depend on 3+4 but are independent of each other.
Task 7 depends on 5 (Centro must exist before shell navigates to it).
Task 8 is final integration.
