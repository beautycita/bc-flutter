# RP Salon Assignment & Outreach System — Design

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable admins to assign discovered salons to field RP (Public Relations) agents by geographic area, and give RPs a dedicated map-first panel to visit, onboard, and track salons.

**Architecture:** Extend existing AdminPipelineScreen with geographic search + RP assignment. New RPShellScreen with map and list views for assigned salons. New DB tables for assignment tracking and visit logging.

**Tech Stack:** Flutter (mobile app), Supabase (Postgres + RLS), Google Maps Flutter plugin, existing admin_provider infrastructure.

---

## Data Model

### New table: `rp_assignments`
| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| discovered_salon_id | uuid FK | → discovered_salons |
| rp_user_id | uuid FK | → profiles (role='rp') |
| assigned_by | uuid FK | → profiles (admin who assigned) |
| assigned_at | timestamptz | default now() |
| unassigned_at | timestamptz | null = currently active |

- Partial unique index: `(discovered_salon_id) WHERE unassigned_at IS NULL` — one active RP per salon
- History preserved: unassigning sets unassigned_at, new row for reassignment

### New table: `rp_visits`
| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| rp_assignment_id | uuid FK | → rp_assignments |
| discovered_salon_id | uuid FK | → discovered_salons (denorm for queries) |
| rp_user_id | uuid FK | → profiles (denorm) |
| visited_at | timestamptz | default now() |
| verbal_contact | boolean NOT NULL | Required: spoke to salon administrator? |
| onboarding_complete | boolean | default false |
| interest_level | smallint | 0-5, null if onboarding_complete=true |
| notes | text | optional |

### Modify `discovered_salons`
- Add `assigned_rp_id` uuid FK → profiles (null = unassigned, denormalized)
- Add `rp_status` text: 'unassigned' (default), 'assigned', 'visited', 'onboarding_complete'

### Fix `profiles` table constraint
- Update CHECK to: `role IN ('customer', 'admin', 'superadmin', 'rp')`

---

## Admin Side: Enhanced Pipeline Screen

### Geographic search (additions to existing screen)
1. **City dropdown** — uses existing city_aliases infrastructure
2. **Pin drop** — map dialog, tap to place pin, radius selector (5/10/25/50km), filters by haversine distance against discovered_salons.latitude/longitude
3. **Area code** — 3-digit numeric query matches phone prefix

### Assignment workflow
1. **New filters:** "Unassigned" / "Assigned to [RP]" / "All" + rp_status filter
2. **Bulk assign:** Select salons → "Assign to RP" → picker of role='rp' users → confirm
3. **Bulk unassign:** Select salons → "Unassign" → sets unassigned_at, clears assigned_rp_id
4. **Visual:** Each salon card shows RP name badge + color (gray=unassigned, blue=assigned, orange=visited, green=complete)

### Updated RPC
Extend `search_discovered_salons` with: `assigned_rp_id`, `rp_status_filter`, `pin_lat`, `pin_lng`, `radius_km`

---

## RP Panel: RPShellScreen

Separate shell, accessed when `profile.role == 'rp'`. Two tabs.

### Tab 1: Map View (default)
- Google Map centered on RP's current location
- Pins for all assigned salons, color-coded: blue=not visited, orange=visited, green=onboarding complete, gray=no interest (0)
- Tap pin → bottom sheet: name, address, rating, categories, hours, website, social links, visit history
- "Navigate" → opens Google Maps/Waze external intent
- "Nearby" → highlights 5 closest unvisited salons to selected pin with distance labels
- Pin clustering when zoomed out

### Tab 2: List View (grouped)
- Sections: "Not Visited", "Visited — Follow Up" (interest 1-5), "Onboarding Complete", "No Interest" (0)
- Cards: name, address, rating, last visit date, interest badge
- Tap → same detail bottom sheet

### Visit Logging (from either view)
- Required: "Verbal contact with administrator?" toggle
- If complete onboarding done: "Onboarding Complete" checkbox
- If not complete: interest slider 0-5
- Optional: notes text field
- Submit → insert rp_visits row + update denormalized fields on discovered_salons

### RP Permissions
- Can only see their own assigned salons
- Cannot modify salon data, delete salons, access admin features, or see other RPs' work
- RLS enforced: `rp_visits WHERE rp_user_id = auth.uid()`, `rp_assignments WHERE rp_user_id = auth.uid()`

---

## RLS Policies

- **rp_assignments:** admins full CRUD, RPs read-only on their own rows
- **rp_visits:** admins read all, RPs full CRUD on their own rows
- **discovered_salons:** existing admin policies stay; add SELECT for RPs WHERE assigned_rp_id = auth.uid()
