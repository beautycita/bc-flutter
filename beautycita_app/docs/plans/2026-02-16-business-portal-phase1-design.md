# Business Portal Phase 1 — Design Doc

## Overview
Complete operational management tool for salon owners/stylists. Replaces the thin read-only dashboard with a full interactive portal covering day-to-day salon operations.

**Target user:** Salon owner on their phone, managing their business throughout the day.

**Entry point:** Storefront icon on home screen (auto-detected for stylist role + business owner). Route: `/business`.

**Architecture:** BusinessShellScreen with drawer navigation (already exists). Replace/rebuild the 6 tab screens with full interactive versions.

---

## Section 1: Calendar & Scheduling (rebuild)

The screen the owner opens every morning. Must be fast, interactive, and actionable.

### Day View (default)
- Vertical timeline from business open → close (e.g. 9:00 - 20:00)
- Appointment blocks positioned by time, colored by status
- Staff filter chips at top — show all staff or filter to one
- Blocked time (lunch, breaks) shown as grey hatched blocks
- Empty slots are tappable → "Add walk-in appointment" flow

### Week View
- 7-column compact grid, each day shows appointment count + colored dots
- Tap a day → switches to day view for that date

### Appointment Actions (tap → bottom sheet)
- **Confirm** (pending → confirmed)
- **Complete** (confirmed → completed)
- **Cancel** → reason picker (business-initiated), auto-refund based on policy
- **Reschedule** → date+time picker → updates appointment, notifies client
- **Mark No-Show** → triggers no-show flow:
  - If deposit was collected: keep deposit, refund remainder (or configurable)
  - If no deposit: mark as no-show, flag client for future reference
  - Client gets notification with dispute option

### Block Time
- FAB or "+" button → "Bloquear Horario"
- Pick staff member (or "Todo el salon")
- Pick date range + time range
- Reason: Almuerzo / Dia libre / Vacaciones / Otro
- Creates entry in `staff_schedule_blocks` table (new)
- Blocked time appears on calendar, prevents bookings

### Walk-in Add
- Tap empty slot → pick service → pick staff → set time → create appointment with status "confirmed"

### Data
- Provider: `businessAppointmentsProvider(date range)` — already exists
- New table: `staff_schedule_blocks` (staff_id, business_id, start_at, end_at, reason, is_recurring)
- Writes: direct Supabase updates with provider invalidation

---

## Section 2: Services & Pricing (enhance existing)

### Service List
- Grouped by category, each card shows: name, price, duration, active toggle
- Tap → edit form (bottom sheet)
- Swipe left → delete with confirmation
- FAB → new service

### Service Form (bottom sheet)
- Name, category (dropdown), subcategory
- **Price** (MXN) — base price
- **Duration** (minutes) + **buffer time** (minutes between appointments)
- **Deposit required** toggle + deposit percentage (per-service override)
- **Description** (optional)
- **Active** toggle

### Staff Price Overrides
- In staff detail → assigned services list
- Each service shows base price + option to set custom price/duration for that staff member
- Stored in `staff_services.custom_price` / `staff_services.custom_duration` (already exist)

---

## Section 3: Staff Management (enhance existing)

### Staff List
- Card per staff: name, avatar initial, rating, active toggle
- Tap → staff detail bottom sheet (already exists but needs expansion)

### Staff Detail (DraggableScrollableSheet)
- **Profile section:** name, phone, experience years, edit button
- **Weekly Schedule:**
  - 7 rows (Mon-Sun), each with: available toggle, start time, end time
  - Editable inline — tap time to change via TimePicker
  - Save button persists to `staff_schedules` table
- **Assigned Services:**
  - List of services this person can do
  - "Assign service" button → multi-select from business services
  - Each shows base price + custom override fields
  - Saves to `staff_services` table
- **Time Off:**
  - List of upcoming blocked time for this staff member
  - "Add time off" → date range + reason
- **Performance:**
  - Average rating, total reviews, bookings this month (read-only stats)

### Add Staff (bottom sheet)
- First name, last name, phone, experience years
- Creates staff row → then user can edit schedule and assign services

---

## Section 4: Disputes & Refunds

### Dispute List
- Shows disputes where `business_id` matches (via appointment → business)
- Card: status chip, client name (from user_id → profiles), reason preview, date
- Status filter: Abierta / Resuelta / Todas

### Dispute Detail (bottom sheet)
- Full reason text
- Client evidence (text)
- **Business response section:**
  - Text field for business's side of the story
  - Photo upload option (evidence)
  - Submit response → updates `stylist_evidence` field
- Resolution status (read-only if admin already resolved)
- If no-show dispute: shows deposit amount, refund options

### No-Show Refund Flow
- When staff marks appointment as no-show:
  1. Check if deposit was collected
  2. If yes: auto-forfeit deposit per policy, refund rest
  3. If no deposit: just mark no-show
  4. Client receives notification
  5. Client has 48h to dispute
- Business can see no-show history per client

---

## Section 5: Walk-in QR System

### QR Generator Screen
- Auto-generates URL: `beautycita.com/walkin/{business_id}`
- Displays QR code (large, centered)
- "Download" button → saves QR as image to gallery
- "Share" button → share via WhatsApp/etc
- Salon name + "Escanea para reservar" text below QR
- Print-friendly layout option (white background, logo + QR + instructions)

### Walk-in Landing (client-side, web)
- Client scans QR → opens beautycita.com/walkin/{id}
- Shows salon info + service list
- Client picks service → picks available time → books directly
- Bypasses intelligent booking engine — goes straight to this salon

### Data
- QR URL is deterministic (business ID), no table needed
- Walk-in route: new web page in beautycita_web OR deep link to app

---

## Section 6: Business Settings (enhance existing)

### Operating Hours
- Per-day (Mon-Sun): open time, close time, closed toggle
- **Break windows:** add lunch/break per day (start, end)
- Stored in businesses.hours (jsonb) — already exists

### Policies
- Cancellation window (hours before appointment)
- No-show policy: forfeit deposit / full refund / partial
- Auto-confirm: toggle per service category or global

### Profile
- Name, phone, address, city (already done)
- Social links (already done)
- Business photo

---

## Database Changes

### New table: `staff_schedule_blocks`
```sql
CREATE TABLE staff_schedule_blocks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES businesses(id),
  staff_id uuid REFERENCES staff(id), -- null = whole salon
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL,
  reason text, -- 'lunch', 'day_off', 'vacation', 'other'
  note text,
  is_recurring boolean DEFAULT false,
  recurrence_rule text, -- 'weekly_mon_12:00_13:00' etc
  created_at timestamptz DEFAULT now()
);
```

### Modify businesses.hours jsonb structure
```json
{
  "monday": {"open": "09:00", "close": "20:00", "breaks": [{"start": "14:00", "end": "15:00"}]},
  "tuesday": {"open": "09:00", "close": "20:00", "breaks": []},
  ...
  "sunday": null
}
```

### New RLS policies needed
- `staff_schedule_blocks`: business owner can CRUD for their business
- Existing tables already have owner-based RLS

---

## Phase 2 (deferred)
- Marketing: coupons, discount codes, push promos
- Video consultation: request + schedule + video link
- Before/after photos: camera capture tied to appointments
- Advanced analytics: revenue trends, popular services, peak hours
- Client CRM: notes per client, visit history, preferences

---

## Implementation Approach
- Rebuild existing 6 screens in `screens/business/` — replace thin versions
- Add `staff_schedule_blocks` table via SQL on www-bc
- Enhance `business_provider.dart` with new providers
- Add walk-in QR screen
- Wire dispute view for business side
- Total: ~8-10 files modified/created
