# Admin Salones & Pipeline Screens — Design Spec

**Date:** 2026-02-28
**Author:** BC + Claude
**Status:** Approved
**Platform:** Mobile-first (Flutter). Web adaptation built separately later.

---

## Overview

Replace the current `salon_management_screen.dart` (two-tab registered salons list + pipeline stats) with two independent, purpose-built screens:

1. **Salones** — Intelligent search across all registered salons with full admin control
2. **Pipeline** — Lead control center for discovered/scraped salons, outreach tracking, conversion funnel

Both screens share an export system supporting CSV, Excel (.xlsx), JSON, PDF, and vCard (.vcf) contact lists.

---

## Screen 1: Salones (Intelligent Admin Search)

### Purpose
Find any registered salon instantly by typing anything — name, phone fragment, city alias, address, state. One search bar that intelligently figures out what the admin wants.

### Layout (top to bottom)

#### A. Search Bar
- Full width, always visible at top, auto-focus on screen entry
- Placeholder: "Buscar salon... (nombre, tel, ciudad, etc.)"
- Export icon button to the right of the search field
- Minimum 2 characters to trigger search
- Debounced: 300ms after last keystroke

#### B. Results List
- Appears as admin types
- Each card shows:
  - Active/inactive dot (green/red, left edge)
  - Salon name (primary text)
  - City, State (secondary text)
  - Phone number
  - Tier badge (color-coded: Tier 1 grey, Tier 2 blue, Tier 3 rose)
  - Rating stars + review count (if available)
- Before typing: show recently viewed salons (local cache)
- No results: "No se encontraron salones"
- Results capped at 50, with "load more" pagination

#### C. Salon Detail (tapped card → full-screen push or large bottom sheet)

**Header section:**
- Photo (or placeholder)
- Salon name (editable)
- Tier selector: tap to change between 1/2/3
- Active/Inactive toggle switch
- City, State

**Stats row (compact):**
- Average rating + review count
- Total appointments
- Total revenue (MXN)
- Member since date

**Scrollable sections:**

1. **Contact**
   - Phone (tap to call)
   - WhatsApp (tap to open chat)
   - Address (tap for map)
   - Website, Instagram, Facebook links

2. **Business Info**
   - Service categories
   - Business hours (formatted)
   - Cancellation policy (hours)
   - Deposit settings (required, percentage)
   - Auto-confirm, walk-ins accepted

3. **Owner**
   - Owner name + profile link
   - Tap to view full user profile

4. **Recent Appointments** (last 10)
   - Date, service, client name, status, amount
   - Tap for full appointment detail

5. **Open Disputes**
   - List of unresolved disputes
   - Tap to navigate to dispute detail

6. **Recent Reviews** (last 10)
   - Rating, client name, date, text preview
   - Tap for full review

**Action buttons (bottom fixed):**
- Contact Owner (WhatsApp)
- Edit Salon Info
- Suspend Salon (with confirmation dialog)

### Search RPC Function: `search_salons`

**Server-side PostgreSQL function** that handles all search intelligence.

**Input:** `query text, result_limit int default 50, result_offset int default 0`

**Logic:**
1. Tokenize input into words (split on whitespace)
2. Strip non-digit characters from tokens that look like phone numbers
3. Look up each token in a city aliases table/dictionary:
   - `htown`, `hou` → Houston
   - `gdl` → Guadalajara
   - `cdmx`, `df` → Ciudad de Mexico
   - `cabo` → Cabo San Lucas
   - `pvr`, `vallarta` → Puerto Vallarta
   - `mty`, `monterrey` → Monterrey
   - `tj`, `tijuana` → Tijuana
   - etc. (extensible via a `city_aliases` table or embedded in the function)
4. For each token, match against: `name`, `phone`, `whatsapp`, `city`, `state`, `address`
5. Ranking: exact match > prefix match > contains match
6. All tokens must match (AND logic) — "htown 832" means city=Houston AND phone starts with 832
7. Return: `id, name, phone, city, state, tier, is_active, average_rating, total_reviews, photo_url`

**Indexes needed:**
- `businesses(name)` — trigram GIN index for fuzzy matching
- `businesses(phone)` — btree for prefix matching
- `businesses(city)` — btree
- `businesses(state)` — btree

---

## Screen 2: Pipeline (Lead Control Center)

### Purpose
Manage the salon acquisition funnel. Every discovered salon is a lead. Track outreach across all channels (WhatsApp, SMS, Email, radio, in-person, etc.), move leads through statuses, bulk-process efficiently on mobile.

### Layout (top to bottom)

#### A. Collapsible Metrics Header
**Collapsed (default):** Single compact row with 4 key numbers:
- Total leads
- Outreach sent (this week)
- Registered (this month)
- Conversion rate %

**Expanded (tap to toggle):** Full funnel breakdown:
- discovered: count (grey)
- selected: count (blue)
- outreach_sent: count (orange)
- registered: count (green)
- declined: count (red)
- unreachable: count (grey)

#### B. Search Bar
- Same intelligent search as Salones but queries `discovered_salons` table
- Matches against: name, phone, city, state, address
- Same alias resolution (htown → Houston, etc.)

#### C. Filter Chips Row
Horizontally scrollable chips:
- **Status:** discovered | selected | outreach_sent | registered | declined | unreachable
- **City:** dropdown with all cities, grouped by country
- **Has WhatsApp:** verified WA number exists
- **Has Interest:** interest_count > 0
- **Source:** google_maps | facebook | bing | manual
- Active filters show filled/colored chip. Tap to toggle/select.

#### D. Bulk Action Bar
Appears when 1+ leads are selected (long-press a card to enter selection mode, then tap more):
- **Send Outreach** — choose channel (WA/SMS/Email), uses template
- **Change Status** — pick new status from dropdown
- **Export Selection** — export selected leads
- **Delete** — with confirmation

Shows count: "X seleccionados"

#### E. Lead List
Each card shows:
- Salon name (primary text)
- City, State (secondary text)
- Source badge: small colored tag (Google Maps=red, Facebook=blue, Bing=teal, Manual=grey)
- Status badge: color-coded by status
- Phone number + WhatsApp verified checkmark (if verified)
- Interest count (if > 0): "X interesadas" in rose badge
- Last outreach: date + channel icon (WA/SMS/Email/etc.)
- Checkbox on right edge for bulk selection

**Long-press:** enters selection mode
**Tap:** opens lead detail

#### F. Lead Detail (bottom sheet, large)

**Header:**
- Name (editable inline)
- Status selector (tap to change)
- City, State
- Source badge
- Phone + WhatsApp (tap to call/message)

**Salon Info:**
- Address, map link
- Rating, review count (from scraped data)
- Business hours
- Website, Instagram, Facebook
- Categories

**Outreach Timeline (chronological, newest first):**
Each entry:
- Date + time
- Channel icon + label (WhatsApp, SMS, Email, Radio, Phone Call, In-Person, Social Ad, Flyer, Referral, Other)
- Message/note preview
- Result/outcome (if logged)

Automated entries (WA/SMS/Email sent via the system) appear automatically.
Manual entries (radio, in-person, etc.) are added via the "Log Outreach" button.

**Log New Outreach (button):**
- Channel dropdown: WhatsApp, SMS, Email, Phone Call, In-Person Visit, Radio Ad, Social Media Ad, Flyer/Print, Referral, Other
- Notes field (freeform text)
- Date (defaults to now, can backdate)
- Saves to `salon_outreach_log` table

**Actions:**
- Send WhatsApp (opens compose with template)
- Send SMS
- Send Email
- Mark Registered (links to existing business or creates new one)
- Mark Declined
- Mark Unreachable
- Delete Lead

### Pipeline Search RPC: `search_discovered_salons`

Same pattern as `search_salons` but queries `discovered_salons` table.

**Additional filters (passed as parameters):**
- `status_filter text[]` — filter by one or more statuses
- `city_filter text` — exact city match
- `has_whatsapp boolean` — phone verified on WhatsApp
- `has_interest boolean` — interest_count > 0
- `source_filter text` — filter by source

---

## Export System (Shared by Both Screens)

### Trigger
Export icon button on search bar. Exports whatever the current search/filter results are.

### Format Selection
Bottom sheet with format options:
- **CSV** — comma-separated, UTF-8 with BOM for Excel compatibility
- **Excel (.xlsx)** — formatted workbook with bold headers, auto-column widths, freeze top row. If grouped (by city/tier), each group gets its own sheet.
- **JSON** — structured array of objects, pretty-printed
- **PDF** — branded report: BC logo header, title, date generated, formatted table with page numbers, footer
- **Contactos (.vcf)** — vCard 3.0 format. Each salon → one contact card: name, phone, address, website. Importable to phone contacts.

### Export Templates
After selecting format, choose what to export:

**Salones templates:**
- Directorio completo (all fields)
- Por ciudad (grouped by city, subtotals)
- Por tier (grouped by tier)
- Revenue report (name, city, appointments, revenue, avg ticket)
- Inactivos (inactive or no bookings in 30+ days)
- Custom (pick columns)

**Pipeline templates:**
- All leads (full data)
- Outreach report (contacts this week/month, by channel, results)
- Conversion funnel (by city, source, channel)
- Hot leads (sorted by interest, WA-verified)
- Custom (pick columns)

### Delivery
File generated locally → system share sheet (WhatsApp, email, save to Files, AirDrop, etc.)

---

## Database Changes

### New table: `city_aliases`
```sql
create table public.city_aliases (
  alias    text primary key,
  city     text not null,
  state    text,
  country  text not null default 'MX'
);
```
Seeded with common aliases (htown→Houston, gdl→Guadalajara, etc.). Extensible by admin.

### New RPC: `search_salons(query text, result_limit int, result_offset int)`
PostgreSQL function with trigram matching, alias resolution, phone prefix matching. Returns ranked results from `businesses` table.

### New RPC: `search_discovered_salons(query text, status_filter text[], city_filter text, has_whatsapp boolean, has_interest boolean, source_filter text, result_limit int, result_offset int)`
Same search intelligence for `discovered_salons` table with additional filter parameters.

### New indexes
- `CREATE INDEX idx_businesses_name_trgm ON businesses USING gin (name gin_trgm_ops);`
- `CREATE INDEX idx_businesses_phone ON businesses (phone);`
- `CREATE INDEX idx_businesses_city ON businesses (city);`
- `CREATE INDEX idx_discovered_salons_name_trgm ON discovered_salons USING gin (name gin_trgm_ops);`
- `CREATE INDEX idx_discovered_salons_phone ON discovered_salons (phone);`
- `CREATE INDEX idx_discovered_salons_city ON discovered_salons (city);`
- `CREATE INDEX idx_discovered_salons_status ON discovered_salons (status);`

### Outreach log extension
The existing `salon_outreach_log` table needs a `channel` column if it doesn't have one, plus support for manual entries (non-automated channels).

---

## Admin Shell Tab Changes

**Current tabs to modify:**
- **"Salones"** tab → points to new `admin_salones_screen.dart` (intelligent search)
- **New "Pipeline"** tab → points to new `admin_pipeline_screen.dart` (lead control center)
- **"Mensajes Salones"** tab → can be removed (functionality absorbed into Pipeline)

---

## Mobile-First Constraints

- All actions reachable with one thumb (bottom 60% priority)
- No horizontal scrolling for data (chips row is the exception)
- Bottom sheets over full-screen pushes where possible
- Bulk actions bar sticks to bottom when active
- Search keyboard dismisses on scroll
- Export share sheet is native OS share (works with any app)

---

## Out of Scope (Future)

- Triage queue mode (Tinder-style lead review) — fun secondary mode, build after core Pipeline is solid
- Web adaptation — separate project, desktop-first, independent codebase
- Automated outreach scheduling (send X messages per day automatically)
- AI-powered lead scoring
