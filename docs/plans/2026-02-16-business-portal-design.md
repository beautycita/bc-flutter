# Business Portal Design — beautycita_app

## Overview
A mobile-first business portal for salon owners/stylists to manage their business from the BeautyCita app. Auto-detected by role — if user is a `stylist` who owns a `business`, a "Mi Negocio" button appears on the home screen.

## Architecture
- `BusinessShellScreen` with horizontal scrollable tabs (same pattern as `AdminShellScreen`)
- Route: `/business` — pushed from home screen header button
- 6 tab screens, all `ConsumerWidget`/`ConsumerStatefulWidget`
- Data via `FutureProvider` filtered by owner's `business_id` (same pattern as admin)
- Writes go direct to Supabase with provider invalidation

## Navigation Entry
- Home screen header: when `profiles.role == 'stylist'` AND user owns a business, show a "Mi Negocio" icon button (storefront icon) next to chat/settings buttons
- Provider: `currentBusinessProvider` — fetches business where `owner_id == auth.uid`
- If no business found, button navigates to `/registro` (onboarding) instead

## Screens

### 1. Dashboard (`business_dashboard_screen.dart`)
- Today's appointment count + list (next 3 upcoming with time, client, service)
- Stat cards: Bookings this week, Revenue this month, Average rating, Pending confirmations
- Quick action buttons: "Ver Calendario", "Agregar Servicio"

### 2. Calendar (`business_calendar_screen.dart`)
- Day/Week toggle view
- Day view: vertical timeline with appointment blocks color-coded by status
- Week view: 7-column grid showing appointment density per day
- Tap appointment → bottom sheet with details + actions (Confirmar/Completar/Cancelar)
- Status colors: pending=amber, confirmed=blue, completed=green, cancelled=red, no_show=grey

### 3. Services (`business_services_screen.dart`)
- ListView of services grouped by category
- Each card: name, price (MXN), duration, active toggle
- FAB to add new service → bottom sheet form (name, category, subcategory, price, duration, description)
- Swipe to delete (with confirmation)
- Edit via tap → same form pre-filled

### 4. Staff (`business_staff_screen.dart`)
- ListView of staff members with avatar, name, rating, service count
- Tap → staff detail with:
  - Weekly schedule grid (Mon-Sun, start/end time per day, available toggle)
  - Assigned services list with custom price/duration overrides
- FAB to add staff member
- Toggle staff active/inactive

### 5. Payments (`business_payments_screen.dart`)
- Revenue summary card: This month total, last month, pending payouts
- Stripe status banner: onboarding progress, charges_enabled, payouts_enabled
- If not onboarded: prominent "Conectar Stripe" button → launches Stripe onboarding
- Transaction list: recent payments with amount, date, status, appointment link

### 6. Settings (`business_settings_screen.dart`)
- Business profile: name, phone, address, hours (per-day open/close)
- Photo management (business photo URL)
- Cancellation policy: hours notice required, deposit percentage
- Toggles: auto_confirm, accept_walkins
- Save button → Supabase update

## Database Tables Used
All tables already exist with RLS policies:
- `businesses` (owner's business profile)
- `staff` (team members)
- `services` (service catalog)
- `staff_services` (service assignments)
- `staff_schedules` (weekly availability)
- `appointments` (bookings for this business)
- `payments` (transaction records)
- `reviews` (customer reviews)

## Providers Needed (in `business_provider.dart`)
- `currentBusinessProvider` — business where owner_id == auth.uid
- `businessStatsProvider` — aggregated stats for dashboard
- `businessAppointmentsProvider(date)` — appointments for a date range
- `businessServicesProvider` — services for this business
- `businessStaffProvider` — staff for this business
- `businessPaymentsProvider` — recent payments
- `businessReviewsProvider` — reviews for this business

## Key Patterns
- Match existing code style: GoogleFonts via theme, AppConstants, colorScheme
- Theme-aware (no hardcoded colors)
- Pull-to-refresh on all list screens
- Optimistic updates where possible (toggles)
- Toast notifications for success/error
