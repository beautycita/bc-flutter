# BeautyCita — Intelligent Booking Engine: Complete Design Document

> **For Claude:** This document is the authoritative design specification for BeautyCita. It supersedes the original Vagaro clone plan (`2026-01-31-beautycita-flutter-vagaro-clone.md`). The original plan's infrastructure (Flutter project, Supabase schema, navigation shell) remains valid as a foundation, but the UX, intelligence engine, and core booking flow described here replace the traditional booking app approach entirely.
>
> **REQUIRED SUB-SKILL:** Use superpowers:executing-plans to implement this design task-by-task.

**Goal:** Build a beauty services booking app that eliminates the traditional search-browse-select-schedule flow. The user selects what service they want, and the app gives them the answer — the 3 best options, each bookable in one tap, with optional round-trip Uber integration.

**Architecture:** Flutter mobile app (Android API 29+, Web, Linux Desktop) with Supabase backend. The core innovation is a service-type-driven intelligence engine that runs as a single Supabase Edge Function (`curate-results`), combining PostGIS proximity search, time inference, traffic-aware transport routing, Bayesian rating analysis, and service-specific ranking weights — all tunable via an admin panel. The entire user flow is 4-6 taps, under 30 seconds, zero keyboard input.

**Tech Stack:**
- Flutter 3.38.9 (stable) + Riverpod + GoRouter
- Supabase (PostgreSQL + PostGIS, Auth, Realtime, Storage, Edge Functions)
- Google Routes API (traffic-aware travel times, public transit routing)
- Uber API (ride scheduling, fare estimates)
- Stripe (MXN, OXXO, cards)
- Twilio (WhatsApp Business API + SMS)
- Firebase (FCM push notifications)
- Cloudflare R2 (media CDN)

**Target Market:** Mexico. Spanish-first. MXN currency. WhatsApp as primary communication channel.

---

## Table of Contents

1. [Core Philosophy](#1-core-philosophy)
2. [User Flow — The 4-6 Tap Experience](#2-user-flow)
3. [Service Category Tree](#3-service-category-tree)
4. [Service Intelligence Profiles](#4-service-intelligence-profiles)
5. [Time Inference Engine](#5-time-inference-engine)
6. [The Intelligence Engine — Technical Architecture](#6-intelligence-engine)
7. [The Result Card — Adaptive Display](#7-result-card)
8. [Transport Integration — Car, Transit, Uber Round-Trip](#8-transport-integration)
9. [Review Intelligence](#9-review-intelligence)
10. [Admin Panel — Dynamic Engine Tuning](#10-admin-panel)
11. [Salon Onboarding — Three Tiers](#11-salon-onboarding)
12. [Grassroots Growth — Salon Acquisition via WhatsApp](#12-grassroots-growth)
13. [Database Schema Additions](#13-database-schema)
14. [Edge Functions](#14-edge-functions)
15. [Notification System](#15-notifications)
16. [Implementation Priority](#16-implementation-priority)

---

## 1. Core Philosophy

BeautyCita is not a booking app. It is an intelligent booking agent.

Every existing booking platform (Vagaro, Fresha, StyleSeat, Booksy) follows the same paradigm: search for salons → browse services → pick a provider → pick a time → confirm. This is a control panel. It forces the user to make 15-20 decisions to accomplish one thing: get their nails done.

BeautyCita inverts this. The user tells us what they want done. We give them the answer.

**The difference:**

| Traditional Booking App | BeautyCita |
|---|---|
| "Here are 47 salons near you" | "Maria at Salon Bella, tomorrow 2pm, $280, 8 min away" |
| User searches, filters, scrolls, compares | User taps a category, taps a service, sees the answer |
| 15-20 decisions | 4-6 taps |
| 3-5 minutes | Under 30 seconds |
| Keyboard input required | Zero typing |
| User does the thinking | Engine does the thinking |

The intelligence is invisible. The user never sees weights, algorithms, or scores. They see three cards. The best one is on top. They tap RESERVAR. Their afternoon is planned.

---

## 2. User Flow — The 4-6 Tap Experience

The entire interaction happens in the bottom 60% of the screen — the thumb zone. Nothing critical is at the top of the screen where users would need to shift grip. The app is designed to be operated one-handed, while brushing teeth, putting kids to bed, lying in bed at 11pm on a Wednesday.

### Flow Diagram

```
OPEN APP
  │
  ▼
HOME SCREEN
  Category grid (8-10 large icons)
  Bottom 60% of screen, thumb-friendly
  │
  │ Tap: 💅 Uñas                          ← TAP 1
  ▼
SUBCATEGORY SHEET
  Bottom sheet rises over dimmed home
  Large tappable pills
  │
  │ Tap: [Relleno]                         ← TAP 2
  ▼
FOLLOW-UP QUESTIONS                        ← TAP 3 (only if service requires it)
  Visual cards, not text fields             0 questions for nail fill-in
  Photos for lash types, etc.              1-3 questions for specialist services
  │
  │ (for nail fill-in, skip this entirely)
  ▼
TRANSPORT QUESTION
  "¿Cómo llegas?"
  Three visual cards: 🚗 Auto | 🚕 Uber | 🚌 Me llevo yo
  │
  │ Tap: 🚕 Uber                          ← TAP 3 (or 4 if follow-ups existed)
  ▼
RESULTS — THREE CURATED CARDS
  200-400ms to appear
  Stacked cards, best on top
  Swipe top card away to see #2 and #3
  Each card is the complete decision
  │
  │ Tap: [RESERVAR]                        ← TAP 4 (or 5)
  ▼
CONFIRMATION
  Summary + Uber round-trip details
  Payment method (already saved)
  │
  │ Tap: [CONFIRMAR TODO]                  ← TAP 5 (or 6)
  ▼
DONE
  Appointment booked
  Uber scheduled (both legs)
  Notifications queued
  ✓
```

### Screen Layouts

**Home Screen:**
```
┌─────────────────────────────┐
│                             │
│      BeautyCita             │
│   Hola, buenas noches       │
│                             │
├─────────────────────────────┤
│                             │
│  💅 Uñas    ✂️ Cabello      │
│                             │
│  👁️ Pestañas  💆 Facial    │
│                             │
│  💄 Maquillaje  🧖 Spa     │
│                             │
│  💪 Cuerpo    🧴 Cuidado   │
│                             │
└─────────────────────────────┘
```

The greeting adapts to time of day: "Buenos días" / "Buenas tardes" / "Buenas noches". No search bar. No map. No "explore." Just the grid. The user knows why they opened the app.

**Subcategory Sheet (Uñas selected):**
```
┌─────────────────────────────┐
│      (home dimmed)          │
├─────────────────────────────┤
│  ¿Qué tipo de servicio?    │
│                             │
│  [Manicure]    [Pedicure]   │
│                             │
│  [Acrílicas]   [Gel]        │
│                             │
│  [Nail Art]    [Reparar]    │
│                             │
│  [Relleno]     [Retiro]     │
│                             │
└─────────────────────────────┘
```

If a subcategory has sub-services (e.g., Manicure → Clásico, Gel, Francés, etc.), a second sheet slides up with those options. Never more than 3 taps to reach a leaf node.

**Follow-Up Questions (only for services that need them):**

For visual selections (e.g., lash type):
```
┌─────────────────────────────┐
│  ¿Qué estilo?              │
├─────────────────────────────┤
│  ┌───────┐ ┌───────┐ ┌───────┐
│  │ photo │ │ photo │ │ photo │
│  │       │ │       │ │       │
│  │Clásico│ │Híbrido│ │Volumen│
│  └───────┘ └───────┘ └───────┘
└─────────────────────────────┘
```

Photos, not words. The user sees what they're choosing. One tap.

For event-driven services (e.g., bridal makeup):
- "¿Cuándo es tu evento?" → Date picker
- "¿En salón o a domicilio?" → Two visual cards
- "¿Necesitas prueba previa?" → Sí / No

Each question is one screen, one tap. Never a form. Never a keyboard.

**Transport Selection:**
```
┌─────────────────────────────┐
│  ¿Cómo llegas?              │
├─────────────────────────────┤
│  ┌───────┐ ┌───────┐ ┌───────┐
│  │  🚗   │ │  🚕   │ │  🚌   │
│  │       │ │       │ │       │
│  │Voy en │ │Pide un│ │Me     │
│  │mi auto│ │ Uber  │ │llevo  │
│  │       │ │       │ │yo     │
│  └───────┘ └───────┘ └───────┘
└─────────────────────────────┘
```

Asked every booking, not stored as a persistent setting. How you get there TODAY affects which salon is best for you TODAY. The selection feeds into the intelligence engine's transport scoring.

The third option — "Me llevo yo" — is deliberately neutral and dignified. It covers public transit, taxi, walking, getting a ride from someone. It does not make the user feel lesser for not having private transportation. When selected, the engine uses Google Transit API for travel times, and cards show transit routing ("🚌 22 min · Línea 1 → transbordo Línea 3").

**Results — Three Curated Cards:**

Described in detail in Section 7.

---

## 3. Service Category Tree

The taxonomy the user navigates. Exhaustive enough to cover what Mexican salons actually offer, shallow enough that no path is more than 3 taps deep before the intelligence engine takes over.

Each leaf node maps to a row in the `service_profiles` table (Section 4). Each leaf node has its own intelligence profile with tunable weights.

```
💅 Uñas
├── Manicure
│   ├── Clásico/Básico
│   ├── Gel
│   ├── Francés
│   ├── Dip Powder
│   ├── Acrílico
│   ├── Spa/Luxury
│   ├── Japonés
│   ├── Parafina
│   └── Ruso
├── Pedicure
│   ├── Clásico/Básico
│   ├── Spa/Luxury
│   ├── Gel
│   ├── Médico
│   └── Parafina
├── Nail Art
├── Cambio de Esmalte
├── Reparación de Uña
├── Relleno (Acrílico/Gel)
└── Retiro (Acrílico/Gel/Dip)

✂️ Cabello
├── Corte
│   ├── Mujer
│   ├── Hombre
│   └── Niño/a
├── Color
│   ├── Tinte Completo
│   ├── Retoque de Raíz
│   ├── Mechas/Highlights
│   ├── Balayage
│   ├── Ombré
│   ├── Corrección de Color
│   └── Decoloración
├── Tratamiento
│   ├── Keratina/Alisado
│   ├── Botox Capilar
│   ├── Hidratación Profunda
│   ├── Olaplex/Reconstructor
│   └── Tratamiento Anticaída
├── Peinado
│   ├── Blowout/Secado
│   ├── Planchado
│   ├── Ondas/Rizos
│   ├── Recogido (Evento)
│   └── Trenzas
└── Extensiones
    ├── Clip-In
    ├── Cosidas
    ├── Fusión/Keratina
    └── Cinta/Tape-In

👁️ Pestañas y Cejas
├── Pestañas
│   ├── Extensiones Clásicas
│   ├── Extensiones Híbridas
│   ├── Extensiones Volumen
│   ├── Mega Volumen
│   ├── Lifting de Pestañas
│   ├── Tinte de Pestañas
│   ├── Relleno (2-3 semanas)
│   └── Retiro
├── Cejas
│   ├── Diseño/Depilación
│   ├── Microblading
│   ├── Micropigmentación
│   ├── Laminado de Cejas
│   ├── Tinte de Cejas
│   └── Henna
└── Combo Pestañas + Cejas

💄 Maquillaje
├── Social/Casual
├── Evento/Fiesta
├── Novia
├── XV Años
├── Editorial/Fotográfico
├── Clase de Automaquillaje
└── Prueba de Maquillaje

💆 Facial
├── Limpieza Facial
│   ├── Básica
│   ├── Profunda
│   └── Hidrafacial
├── Tratamiento Anti-Edad
├── Tratamiento Anti-Acné
├── Microdermoabrasión
├── Dermapen/Microneedling
├── Peeling Químico
├── Radiofrecuencia Facial
├── LED Terapia
└── Mascarilla Especializada

🧖 Cuerpo y Spa
├── Masaje
│   ├── Relajante
│   ├── Descontracturante/Deportivo
│   ├── Piedras Calientes
│   ├── Prenatal
│   ├── Reflexología
│   └── Drenaje Linfático
├── Depilación
│   ├── Cera (zona) → follow-up: ¿qué zona?
│   ├── Láser (zona) → follow-up: ¿qué zona?
│   ├── Hilo/Threading
│   └── Sugaring
├── Tratamiento Corporal
│   ├── Exfoliación
│   ├── Envolvimiento
│   ├── Radiofrecuencia Corporal
│   ├── Cavitación
│   └── Mesoterapia
└── Bronceado
    ├── Spray Tan
    └── Cama de Bronceado

🧴 Cuidado Especializado
├── Micropigmentación de Labios
├── Remoción de Tatuajes
├── Blanqueamiento Dental
├── Barbería Premium
│   ├── Corte + Barba
│   ├── Afeitado Clásico
│   ├── Diseño de Barba
│   └── Tratamiento de Barba
└── Consulta Virtual
```

**Depth rules:**
- Category (tap 1): Uñas, Cabello, Pestañas, Maquillaje, Facial, Cuerpo, Cuidado Especializado
- Subcategory (tap 2): Manicure, Corte, Extensiones, Masaje, etc.
- Specific service (tap 3, only when subcategory has variants): Clásico vs Gel vs Francés
- Never 4 taps. The engine always takes over after the final selection.

---

## 4. Service Intelligence Profiles

Every leaf node in the category tree maps to a service profile. The profile is the DNA of the service — it tells the engine how to behave for this specific service type. All attributes are stored in the database and tunable by admin (Section 10).

### Profile Schema

```sql
CREATE TABLE service_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_type TEXT NOT NULL UNIQUE,
  category TEXT NOT NULL,
  subcategory TEXT,
  display_name_es TEXT NOT NULL,
  display_name_en TEXT NOT NULL,
  icon TEXT,

  -- Service characteristics
  availability_level NUMERIC(3,2) DEFAULT 0.80,
  typical_duration_min INTEGER DEFAULT 60,
  skill_criticality NUMERIC(3,2) DEFAULT 0.30,
  price_variance NUMERIC(3,2) DEFAULT 0.20,
  portfolio_importance NUMERIC(3,2) DEFAULT 0.00,

  -- Time inference
  typical_lead_time TEXT DEFAULT 'same_day'
    CHECK (typical_lead_time IN ('same_day','next_day','this_week','next_week','months')),
  is_event_driven BOOLEAN DEFAULT false,

  -- Search behavior
  search_radius_km NUMERIC(5,1) DEFAULT 8.0,
  radius_auto_expand BOOLEAN DEFAULT true,
  radius_max_multiplier NUMERIC(3,1) DEFAULT 3.0,
  max_follow_up_questions INTEGER DEFAULT 0,

  -- Ranking weights (MUST sum to 1.0)
  weight_proximity NUMERIC(3,2) DEFAULT 0.40,
  weight_availability NUMERIC(3,2) DEFAULT 0.25,
  weight_rating NUMERIC(3,2) DEFAULT 0.20,
  weight_price NUMERIC(3,2) DEFAULT 0.15,
  weight_portfolio NUMERIC(3,2) DEFAULT 0.00,

  -- Card display rules
  show_price_comparison BOOLEAN DEFAULT false,
  show_portfolio_carousel BOOLEAN DEFAULT false,
  show_experience_years BOOLEAN DEFAULT false,
  show_certification_badge BOOLEAN DEFAULT false,
  show_walkin_indicator BOOLEAN DEFAULT true,

  -- Meta
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  updated_by UUID REFERENCES auth.users(id),

  -- Constraint: weights must sum to 1.0
  CONSTRAINT weights_sum_one CHECK (
    ABS((weight_proximity + weight_availability + weight_rating +
         weight_price + weight_portfolio) - 1.0) < 0.01
  )
);
```

### Example Profiles

| Service | availability | duration | skill_crit | portfolio | lead_time | radius | follow_ups | prox_w | avail_w | rating_w | price_w | portf_w |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Manicure Clásico | 0.90 | 30 | 0.15 | 0.00 | same_day | 6.0 | 0 | 0.45 | 0.25 | 0.15 | 0.15 | 0.00 |
| Manicure Gel | 0.75 | 50 | 0.30 | 0.10 | same_day | 8.0 | 0 | 0.40 | 0.25 | 0.20 | 0.15 | 0.00 |
| Relleno (Acrílico/Gel) | 0.80 | 45 | 0.25 | 0.00 | same_day | 8.0 | 0 | 0.40 | 0.25 | 0.20 | 0.15 | 0.00 |
| Nail Art | 0.40 | 75 | 0.70 | 0.80 | this_week | 15.0 | 0 | 0.15 | 0.15 | 0.25 | 0.15 | 0.30 |
| Corte Mujer | 0.85 | 45 | 0.35 | 0.10 | same_day | 8.0 | 0 | 0.40 | 0.25 | 0.20 | 0.15 | 0.00 |
| Balayage | 0.35 | 180 | 0.85 | 0.90 | this_week | 20.0 | 0 | 0.10 | 0.10 | 0.30 | 0.15 | 0.35 |
| Corrección de Color | 0.20 | 240 | 0.95 | 0.90 | this_week | 25.0 | 1 | 0.05 | 0.10 | 0.30 | 0.15 | 0.40 |
| Ext. Pestañas Clásicas | 0.30 | 150 | 0.80 | 0.85 | this_week | 20.0 | 1 | 0.10 | 0.10 | 0.35 | 0.15 | 0.30 |
| Ext. Pestañas Volumen | 0.20 | 180 | 0.90 | 0.90 | this_week | 25.0 | 1 | 0.10 | 0.10 | 0.30 | 0.15 | 0.35 |
| Maquillaje Novia | 0.30 | 120 | 0.90 | 0.85 | months | 30.0 | 3 | 0.05 | 0.10 | 0.30 | 0.15 | 0.40 |
| Maquillaje XV Años | 0.35 | 90 | 0.80 | 0.80 | next_week | 25.0 | 2 | 0.10 | 0.10 | 0.30 | 0.15 | 0.35 |
| Masaje Relajante | 0.70 | 60 | 0.30 | 0.00 | next_day | 10.0 | 0 | 0.35 | 0.30 | 0.20 | 0.15 | 0.00 |
| Keratina/Alisado | 0.45 | 180 | 0.75 | 0.50 | this_week | 15.0 | 0 | 0.15 | 0.15 | 0.30 | 0.20 | 0.20 |
| Microblading | 0.25 | 120 | 0.95 | 0.95 | next_week | 30.0 | 1 | 0.05 | 0.10 | 0.25 | 0.15 | 0.45 |
| Depilación Láser | 0.40 | 45 | 0.60 | 0.10 | this_week | 15.0 | 1 | 0.25 | 0.20 | 0.25 | 0.20 | 0.10 |

### How Profiles Drive Card Display

Card display rules are derived from profile attributes, making the card adaptive:

| Profile attribute | Threshold | Card element shown |
|---|---|---|
| `price_variance > 0.30` | | Price vs area average ("prom: $320") |
| `portfolio_importance > 0.50` | | Portfolio carousel (3-4 photos of stylist's work) |
| `skill_criticality > 0.50` | | Stylist experience years |
| `is_event_driven == true` | | Event date context ("3 días antes de tu evento") |
| `availability_level > 0.70` AND salon accepts walk-ins | | "Se aceptan sin cita" badge |
| Service has certification relevance | | "Certificada en [X]" badge |
| `typical_lead_time == 'same_day'` AND slot is today | | "Disponible hoy" urgency badge |

These rules can also be explicitly overridden per profile via the `show_*` boolean fields.

---

## 5. Time Inference Engine

The user never picks a date or time. The engine infers when they probably want the appointment based on when they're browsing, what service they selected, and their personal booking history.

### The Inference Matrix

Stored in the database as `time_inference_rules`. Admin-editable. The engine looks up the rule matching the current hour range + day-of-week and gets a booking window with weighted time preferences.

```sql
CREATE TABLE time_inference_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  hour_start SMALLINT NOT NULL,     -- 0-23
  hour_end SMALLINT NOT NULL,       -- 0-23
  day_of_week_start SMALLINT NOT NULL, -- 0=Sun, 6=Sat
  day_of_week_end SMALLINT NOT NULL,

  -- What the engine assumes
  window_description TEXT NOT NULL,  -- human-readable for admin
  window_offset_days_min INTEGER DEFAULT 0,  -- earliest day (0=today)
  window_offset_days_max INTEGER DEFAULT 1,  -- latest day
  preferred_hour_start SMALLINT DEFAULT 10,  -- preferred window start
  preferred_hour_end SMALLINT DEFAULT 16,    -- preferred window end
  preference_peak_hour SMALLINT DEFAULT 11,  -- highest preference score

  is_active BOOLEAN DEFAULT true,
  updated_at TIMESTAMPTZ DEFAULT now()
);
```

**Default rules:**

| Hours | Days | Engine assumes | Window |
|---|---|---|---|
| 6-9 AM | Any | Morning planners, want it today | Today 10 AM - 5 PM, peak at 10 AM |
| 9 AM-1 PM | Mon-Thu | Today if available, else tomorrow | Today-tomorrow, 10 AM - 5 PM, peak at 11 AM |
| 9 AM-1 PM | Fri | Pre-weekend urgency, want it today | Today, 1 PM - 7 PM, peak at 2 PM |
| 9 AM-1 PM | Sat | Already out, want it now | Today, next 3 hours, peak at earliest |
| 1-5 PM | Mon-Thu | Planning for tomorrow | Tomorrow, 10 AM - 4 PM, peak at 11 AM |
| 1-5 PM | Fri | Today if available, else Saturday | Today 4 PM - 7 PM or Sat 10 AM - 2 PM |
| 1-5 PM | Sat | Still time today | Today, next 2-4 hours |
| 5-9 PM | Mon-Wed | Evening browsing = weekend prep | Thu-Fri, 10 AM - 5 PM, peak at 2 PM |
| 5-9 PM | Thu | Weekend is imminent | Fri-Sat, 10 AM - 5 PM |
| 5-9 PM | Fri | Too late for today | Saturday, 10 AM - 2 PM, peak at 10 AM |
| 5-9 PM | Sat | Weekend's gone, planning ahead | Mon-Fri next week, 10 AM - 5 PM |
| 9 PM-6 AM | Sun-Wed | Late night = weekend planning | Thu-Fri this week, 10 AM - 4 PM, peak at 2 PM |
| 9 PM-6 AM | Thu-Sat | Tomorrow or next weekend | Tomorrow or next Sat, 10 AM - 2 PM |
| Any | Sun | Weekly planning mode | Mon-Fri coming week, 10 AM - 5 PM |

### Service Profile Override

The inference matrix produces a raw window. The service profile's `typical_lead_time` modifies it:

- `same_day`: Window contracts to today and tomorrow only. If matrix said "this week," override to next 48 hours.
- `next_day`: Window is tomorrow through day-after-tomorrow.
- `this_week`: Window expands to 5-7 days from now, regardless of matrix.
- `next_week`: Window is 7-14 days from now.
- `months` + `is_event_driven`: Matrix is ignored entirely. The user provides an event date in a follow-up question. The engine searches relative to that date.

### Returning User Pattern Override

After 3+ bookings of the same service type at similar times, the engine builds a user-specific pattern:

```sql
CREATE TABLE user_booking_patterns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  service_category TEXT NOT NULL,

  preferred_day_of_week SMALLINT,   -- most common booking day
  preferred_hour SMALLINT,          -- most common booking hour
  booking_count INTEGER DEFAULT 0,
  confidence NUMERIC(3,2) DEFAULT 0.0,  -- 0.0 to 1.0, based on consistency

  last_updated TIMESTAMPTZ DEFAULT now()
);
```

When `confidence > 0.6` (meaning the user is consistent), their personal pattern is blended with the matrix output. At `confidence > 0.85`, personal pattern dominates entirely. "Maria always gets her nails done Friday 2 PM" → show Friday 2 PM slots first, even if she's browsing Tuesday morning.

### Booking Window Output

The inference step produces a weighted window — an array of datetime slots with preference scores:

```typescript
interface BookingWindow {
  primary_date: string;        // "2026-02-06"
  primary_time: string;        // "14:00"
  slots: Array<{
    datetime: string;          // ISO 8601
    preference: number;        // 0.0 to 1.0
  }>;
  window_start: string;        // earliest considered
  window_end: string;          // latest considered
}
```

Example output for Wednesday 10:47 PM, nail fill-in:
```
Thu 10:00 AM  → 0.90 (peak)
Thu 11:00 AM  → 0.85
Thu 12:00 PM  → 0.70
Thu 2:00 PM   → 0.80
Thu 3:00 PM   → 0.75
Fri 10:00 AM  → 0.65
Fri 11:00 AM  → 0.60
Fri 2:00 PM   → 0.55
```

These preference scores feed into the availability component of the ranking formula (Section 6). A salon with a Thursday 10 AM slot scores higher than one with only a Friday 3 PM slot.

### When the Engine Is Wrong — The Escape Hatch

The inferred time appears on the card:

```
  Jueves 2:00 PM
  ¿Otro horario?
```

"¿Otro horario?" is a subtle tappable link. Tap it and a minimal time picker appears:

```
┌─────────────────────────────┐
│ ¿Cuándo prefieres?          │
│                             │
│ [Hoy] [Mañana] [Esta semana]│
│                             │
│ [Próx. semana] [Elegir fecha]│
│                             │
│ Horario:                    │
│ [Mañana] [Tarde] [Noche]   │
└─────────────────────────────┘
```

Two taps: "Próxima semana" + "Tarde" → engine re-runs with new window. Cards re-sort. Still no calendar grid, no scrolling through 30 days of time slots. Only "Elegir fecha" opens an actual date picker — and even then, the engine picks the best time on that date.

### Learning from Corrections

Every time a user taps "¿Otro horario?" the engine logs:
- Service type
- Original inferred window
- User's correction
- Current time + day of week

If corrections cluster (e.g., 40% of users booking "Masaje Relajante" on Tuesday evenings override to "this weekend" instead of the inferred "tomorrow morning"), the time inference rules for that combination auto-adjust. This is stored as a delta on the base rules, not a rewrite.

```sql
CREATE TABLE time_inference_corrections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_type TEXT NOT NULL,
  original_hour_range TEXT NOT NULL,
  original_day_range TEXT NOT NULL,
  correction_to TEXT NOT NULL,       -- what the user picked instead
  correction_count INTEGER DEFAULT 1,
  total_bookings INTEGER DEFAULT 1,  -- total bookings in this slot
  correction_rate NUMERIC(3,2),      -- correction_count / total_bookings
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
```

When `correction_rate > 0.30` for a specific combination, the engine surfaces a suggestion to the admin: "30% of Masaje Relajante users booking Tuesday evening override to weekend. Consider adjusting the default rule."

---

## 6. The Intelligence Engine — Technical Architecture

### Overview

A single Supabase Edge Function (`curate-results`) that receives the user's service selection, location, and transport preference, and returns 3 fully-formed result cards in 200-400ms.

### Request / Response Contract

**Request:**
```typescript
interface CurateRequest {
  service_type: string;              // "nail_fill_in"
  user_id: string | null;           // null for unauthenticated
  location: { lat: number; lng: number };
  transport_mode: "car" | "uber" | "transit";
  follow_up_answers: Record<string, string>;  // empty for 0-question services
  override_window: {                // null = engine infers
    range: "today" | "tomorrow" | "this_week" | "next_week" | string;
    time_of_day: "morning" | "afternoon" | "evening" | null;
    specific_date: string | null;   // ISO date, only if user picked a date
  } | null;
}
```

**Response:**
```typescript
interface CurateResponse {
  booking_window: {
    primary_date: string;
    primary_time: string;
    window_start: string;
    window_end: string;
  };
  results: Array<{
    rank: number;                   // 1, 2, or 3
    score: number;                  // 0.0 to 1.0
    business: {
      id: string;
      name: string;
      photo_url: string;
      address: string;
      lat: number;
      lng: number;
      whatsapp: string;
    };
    staff: {
      id: string;
      name: string;
      avatar_url: string;
      experience_years: number;
      rating: number;
      total_reviews: number;
    };
    service: {
      id: string;
      name: string;
      price: number;
      duration_minutes: number;
      currency: string;
    };
    slot: {
      starts_at: string;           // ISO 8601
      ends_at: string;
    };
    transport: {
      mode: string;
      duration_min: number;
      distance_km: number;
      traffic_level: string;       // "light" | "moderate" | "heavy"
      uber_estimate_min: number | null;
      uber_estimate_max: number | null;
      transit_summary: string | null;  // "Línea 1 → transbordo Línea 3"
      transit_stops: number | null;
    };
    review_snippet: {
      text: string;
      author_name: string;
      days_ago: number;
      rating: number;
    } | null;
    badges: string[];              // ["walk_in_ok", "new_on_platform", etc.]
    area_avg_price: number;
    scoring_breakdown: {           // for admin debug, not shown to users
      proximity: number;
      availability: number;
      rating: number;
      price: number;
      portfolio: number;
    };
  }>;
}
```

### The 6 Steps

```
┌──────────────────────────────────────────────────────┐
│                   curate-results                      │
│                                                       │
│  ┌────────────┐  ┌────────────┐  ┌─────────────────┐│
│  │1. Profile  │→│2. Time     │→│3. Candidate      ││
│  │   Lookup   │ │   Infer    │ │   Query          ││
│  │   <1ms     │ │   <5ms     │ │   50-100ms       ││
│  └────────────┘  └────────────┘  └─────────────────┘│
│                                          ↓           │
│  ┌────────────┐  ┌────────────┐  ┌─────────────────┐│
│  │6. Build    │←│5. Pick     │←│4. Score &        ││
│  │   Response │ │   Top 3    │ │   Rank           ││
│  │   <5ms     │ │   <5ms     │ │   50-150ms       ││
│  └────────────┘  └────────────┘  └─────────────────┘│
│                                                       │
│  Total budget: 200-400ms                              │
└──────────────────────────────────────────────────────┘
```

**Step 1 — Profile Lookup (<1ms)**

Single row fetch from `service_profiles`. Cached in edge function memory after first request per service type — these change only when admin adjusts weights.

```sql
SELECT * FROM service_profiles WHERE service_type = $1 AND is_active = true;
```

**Step 2 — Time Inference (<5ms)**

Pure computation. Takes current timestamp + service profile's `typical_lead_time` + matching `time_inference_rules` row + optional `user_booking_patterns` row. Produces the `BookingWindow` with weighted slot preferences.

No database I/O if the user has no booking history (first-time user). One additional query for returning users to check their pattern.

**Step 3 — Candidate Query (50-100ms)**

One SQL query. Finds businesses offering the service, with available staff, within the time window, within the search radius.

```sql
WITH service_match AS (
  SELECT
    b.id AS business_id,
    b.name AS business_name,
    b.photo_url AS business_photo,
    b.address,
    b.latitude, b.longitude,
    b.whatsapp,
    b.average_rating AS business_rating,
    b.total_reviews AS business_reviews,
    b.cancellation_hours,
    b.deposit_required,
    b.auto_confirm,
    s.id AS service_id,
    s.name AS service_name,
    s.price,
    s.duration_minutes,
    s.buffer_minutes,
    st.id AS staff_id,
    st.first_name || ' ' || COALESCE(LEFT(st.last_name, 1) || '.', '') AS staff_name,
    st.avatar_url AS staff_avatar,
    st.experience_years,
    st.average_rating AS staff_rating,
    st.total_reviews AS staff_reviews,
    COALESCE(ss.custom_price, s.price) AS effective_price,
    COALESCE(ss.custom_duration, s.duration_minutes) AS effective_duration,
    ST_Distance(
      b.location,
      ST_MakePoint($lng, $lat)::geography
    ) AS distance_m
  FROM businesses b
  JOIN services s ON s.business_id = b.id
  JOIN staff_services ss ON ss.service_id = s.id
  JOIN staff st ON st.id = ss.staff_id
  WHERE s.service_type = $service_type
    AND s.is_active = true
    AND st.is_active = true
    AND st.accept_online_booking = true
    AND b.is_active = true
    AND ST_DWithin(
      b.location,
      ST_MakePoint($lng, $lat)::geography,
      $radius_meters
    )
),
available_candidates AS (
  SELECT
    sm.*,
    slots.slot_start,
    slots.slot_start + (sm.effective_duration || ' minutes')::interval AS slot_end
  FROM service_match sm
  CROSS JOIN LATERAL find_available_slots(
    sm.staff_id,
    sm.effective_duration + sm.buffer_minutes,
    $window_start::timestamptz,
    $window_end::timestamptz
  ) slots
)
SELECT DISTINCT ON (business_id)
  *
FROM available_candidates
ORDER BY business_id, distance_m ASC
LIMIT 50;
```

`find_available_slots` is a PostgreSQL function that generates available slots by subtracting booked appointments and blocked times from staff working hours (derived from training manual Section 7).

**Auto-radius expansion:** If query returns fewer than 3 results, the function re-queries with `radius * 1.5`. Repeats up to `radius_max_multiplier` times (default 3x). This ensures the user always sees 3 options, even for rare services.

**Step 4 — Score & Rank (50-150ms)**

The variable time is due to the external transport API call.

```typescript
async function scoreCandidates(
  candidates: Candidate[],
  profile: ServiceProfile,
  window: BookingWindow,
  transportMode: string,
  userLocation: LatLng
): Promise<ScoredCandidate[]> {

  // Batch transport time lookup — single API call for all candidates
  // Google Routes API: batch up to 25 destinations
  // Uber Estimates API: batch pricing
  const transportTimes = await getTransportTimes(
    userLocation,
    candidates.map(c => ({ lat: c.latitude, lng: c.longitude })),
    transportMode
  );

  // Calculate area median price from all candidates
  const areaMedianPrice = median(candidates.map(c => c.effective_price));

  return candidates.map((c, i) => {
    const transport = transportTimes[i];

    // Normalize each signal to 0.0 - 1.0
    const proximityScore = normalizeInverse(transport.duration_min, 5, 45);
    const availabilityScore = window.getPreference(c.slot_start);
    const ratingScore = bayesianRating(c.staff_rating, c.staff_reviews, 4.3, 10);
    const priceScore = normalizePriceToMedian(c.effective_price, areaMedianPrice);
    const portfolioScore = c.portfolio_count > 0
      ? normalizePortfolio(c.portfolio_quality_score)
      : 0.5;  // neutral if no portfolio

    // Weighted composite using service profile weights
    const score =
      proximityScore   * profile.weight_proximity +
      availabilityScore * profile.weight_availability +
      ratingScore       * profile.weight_rating +
      priceScore        * profile.weight_price +
      portfolioScore    * profile.weight_portfolio;

    return {
      ...c,
      score,
      transport,
      area_avg_price: areaMedianPrice,
      breakdown: {
        proximity: proximityScore * profile.weight_proximity,
        availability: availabilityScore * profile.weight_availability,
        rating: ratingScore * profile.weight_rating,
        price: priceScore * profile.weight_price,
        portfolio: portfolioScore * profile.weight_portfolio,
      }
    };
  });
}
```

**Normalization functions:**

```typescript
// Inverse normalization: lower input = higher score
function normalizeInverse(value: number, best: number, worst: number): number {
  return Math.max(0, Math.min(1, (worst - value) / (worst - best)));
}

// Bayesian average: prevents low-volume 5-star bias
function bayesianRating(R: number, v: number, C: number, m: number): number {
  const weighted = (R * v + C * m) / (v + m);
  return weighted / 5.0;  // normalize to 0-1
}

// Price score: at median = 1.0, 50% above median = 0.3
function normalizePriceToMedian(price: number, median: number): number {
  const ratio = price / median;
  if (ratio <= 1.0) return 1.0;  // at or below median is great
  return Math.max(0, 1.0 - (ratio - 1.0) * 1.4);
}
```

**Transport mode affects proximity scoring:**

When `transportMode === "uber"`, the proximity weight is automatically reduced by 30% and redistributed to rating and availability. Rationale: when someone else is driving you, distance matters less — quality and timing matter more.

```typescript
if (transportMode === "uber") {
  const reduction = profile.weight_proximity * 0.30;
  adjustedWeights.proximity -= reduction;
  adjustedWeights.rating += reduction * 0.6;
  adjustedWeights.availability += reduction * 0.4;
}
```

**Step 5 — Pick Top 3 + Best Slot (<5ms)**

Sort by score descending. Deduplicate by business (if same business appears twice via different staff, keep higher-scoring staff). Take top 3. For each, select the single slot with the highest `availabilityScore` — that's THE time shown on the card.

**Step 6 — Build Response (<5ms)**

For each result:
- Fetch pre-scored review snippet for this service type (single indexed query, see Section 9)
- Assemble badges based on profile display rules
- Package the complete card payload

### Database Indexes

```sql
-- Spatial search (the hot path)
CREATE INDEX idx_businesses_location ON businesses USING GIST(location);

-- Service type lookup
CREATE INDEX idx_services_type_active
  ON services(service_type) WHERE is_active = true;

-- Staff-service join
CREATE INDEX idx_staff_services_service
  ON staff_services(service_id);

-- Availability check
CREATE INDEX idx_appointments_staff_time
  ON appointments(staff_id, starts_at)
  WHERE status NOT IN ('cancelled_customer', 'cancelled_business', 'no_show');

-- Staff schedule
CREATE INDEX idx_staff_schedules_lookup
  ON staff_schedules(staff_id, day_of_week) WHERE is_available = true;

-- Review snippet fetch
CREATE INDEX idx_reviews_service_type_recent
  ON reviews(service_type, created_at DESC) WHERE is_visible = true;

-- Service profile cache
CREATE INDEX idx_service_profiles_type
  ON service_profiles(service_type) WHERE is_active = true;
```

### Data Flow Diagram

```
User taps "Relleno" + "Uber"
           │
           ▼
    ┌─────────────┐
    │  Flutter App │
    │  (Riverpod)  │
    └──────┬──────┘
           │ POST /functions/v1/curate-results
           ▼
    ┌─────────────────────────────────────┐
    │      curate-results Edge Function    │
    │                                      │
    │  1. Profile lookup (cached)          │
    │  2. Time inference (computed)        │
    │            │                         │
    │            ▼                         │
    │  3. Candidate SQL ──► PostgreSQL     │
    │     (PostGIS)           + PostGIS    │
    │            │                         │
    │            ▼                         │
    │  4. Score candidates                 │
    │     ├──► Google Routes API (batch)   │
    │     └──► Uber Estimates API (batch)  │
    │            │                         │
    │            ▼                         │
    │  5. Top 3 + best slot each          │
    │  6. Build response + review snippets │
    └──────────────┬──────────────────────┘
                   │
                   ▼
            ┌─────────────┐
            │  3 Cards     │
            │  200-400ms   │
            └─────────────┘
```

---

## 7. The Result Card — Adaptive Display

Each result card is the complete decision. Everything the user needs to say yes is on a single card. No tapping into a detail screen to find the price. No scrolling to find the address. It's all there.

### Base Card Layout

```
┌─────────────────────────────────┐
│ [salon photo - full width]      │
│                                 │
│  Salon Name          ⭐ 4.9 (87)│
│  Stylist Name · experience      │
│                                 │
│  Jueves 2:00 PM                 │
│  ¿Otro horario?                 │
│                                 │
│  $280 MXN                       │
│  🚗 8 min · poco tráfico        │
│                                 │
│  "Review snippet text here      │
│   that's specific to service"   │
│   — Name, hace N días  ⭐⭐⭐⭐⭐  │
│                                 │
│  [ ♥ ]            [ RESERVAR ]  │
└─────────────────────────────────┘
```

### Conditional Elements

Elements that appear based on service profile thresholds:

**Price comparison** (when `price_variance > 0.30`):
```
  $280 MXN (prom. zona: $320)
```

**Portfolio carousel** (when `portfolio_importance > 0.50`):
```
  [photo] [photo] [photo] [photo]
  ← swipe to see stylist's work →
```

**Experience years** (when `skill_criticality > 0.50`):
```
  María G. · 12 años de experiencia
```

**Urgency badge** (when `typical_lead_time == 'same_day'` AND slot is today):
```
  ┌──────────────┐
  │ Disponible hoy│
  └──────────────┘
```

**Event context** (when `is_event_driven == true`):
```
  Miércoles 12 de febrero
  3 días antes de tu evento
```

**Walk-in indicator** (when `availability_level > 0.70` AND salon setting):
```
  Se aceptan sin cita ✓
```

**Certification badge** (when relevant for service):
```
  ✓ Certificada en depilación láser
```

**New on platform** (when salon has < 5 reviews):
```
  🆕 Nuevo en BeautyCita · 12 fotos
```

### Transport Display by Mode

**Car:**
```
  🚗 8 min · poco tráfico
```

**Transit:**
```
  🚌 22 min · Línea 1 → transbordo Línea 3
```

**Uber:**
```
  🚕 12 min · ~$55-$75 ida + ~$55-$75 vuelta
  Total est.: $390-$430 MXN
```

The Uber card includes the full round-trip cost estimate alongside the service price, so the user sees the real total cost of the outing.

### Card Interactions

- **Tap RESERVAR** → Confirmation screen (Section 8 for Uber flow)
- **Tap ♥** → Add to favorites
- **Swipe left** → Dismiss, reveal next card
- **Tap salon photo** → Full business detail screen (traditional view for users who want more info)
- **Tap stylist name** → Staff detail with portfolio
- **Tap "¿Otro horario?"** → Minimal time override (Section 5)
- **Tap review snippet** → All reviews for this business
- **Tap transport info** → Map with route visualization

### Cards Stack Behavior

Three cards stacked. Top card is fully visible. Cards 2 and 3 peek from behind (5px offset each, slight scale reduction). Swipe top card left to dismiss → card 2 animates to top. After dismissing all 3, show: "¿Más opciones?" with a button to load 3 more (engine returns rank 4-6).

---

## 8. Transport Integration — Car, Transit, Uber Round-Trip

### Transport Selection

Asked during every booking, after service selection, before results. Three visual cards:

```
┌─────────┐ ┌─────────┐ ┌─────────┐
│   🚗    │ │   🚕    │ │   🚌    │
│         │ │         │ │         │
│ Voy en  │ │ Pide un │ │Me llevo │
│ mi auto │ │  Uber   │ │  yo     │
└─────────┘ └─────────┘ └─────────┘
```

Not a persistent setting. Asked every time because how you get there TODAY changes which salon is best TODAY.

### Mode: "Voy en mi auto"

- Engine uses Google Routes API with traffic for drive times
- Card shows: "🚗 8 min · poco tráfico"
- Ranking uses raw drive time for proximity scoring
- No additional transport cost

### Mode: "Me llevo yo"

Neutral, dignified phrasing. Covers public transit, taxi, walking, getting a ride.

- Engine uses Google Transit API for travel times
- Card shows: "🚌 22 min · Línea 1 → transbordo Línea 3"
- Shows nearest transit stop to salon
- Ranking uses transit time (can dramatically re-sort results — a salon 5km away might be 45 min by transit)
- Optionally shows: "🚕 Taxi ~$45" as supplementary info

### Mode: "Pide un Uber" — The Full Integration

When the user selects Uber, BeautyCita doesn't just show an estimate — it schedules the entire round trip.

**On the result card:**
```
  🚕 ~$55-$75 MXN ida · ~$55-$75 vuelta
  Total estimado: $390-$430 MXN
```

Total = service price + Uber round-trip estimate. Full transparency.

**On the confirmation screen:**
```
┌─────────────────────────────────┐
│ Resumen de Reserva              │
├─────────────────────────────────┤
│ 📍 Salon Bella                  │
│ ✂️ Relleno de Uñas — María G.  │
│ 📅 Jue 6 de febrero, 2:00 PM   │
│ 💰 $280 MXN                    │
├─────────────────────────────────┤
│ 🚕 Transporte Uber              │
│                                 │
│ Ida:                            │
│  📍 Tu casa → Salon Bella      │
│  🕐 Recogida: 1:45 PM          │
│  💰 ~$55-$75 MXN               │
│                                 │
│ Vuelta:                         │
│  📍 Salon Bella → Tu casa      │
│  🕐 Recogida: ~2:50 PM         │
│  💰 ~$55-$75 MXN               │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ 📍 ¿Volver a otra dirección?│ │
│ │ (si vas a algún lugar       │ │
│ │  después de tu cita)        │ │
│ └─────────────────────────────┘ │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ Usar mi cuenta Uber ✓       │ │
│ │ ana.garcia@gmail.com        │ │
│ └─────────────────────────────┘ │
│                                 │
├─────────────────────────────────┤
│ Servicio:          $280 MXN     │
│ Uber (est.):    ~$110-$150 MXN  │
│ Total estimado: ~$390-$430 MXN  │
├─────────────────────────────────┤
│                                 │
│       [ CONFIRMAR TODO ]        │
└─────────────────────────────────┘
```

**"¿Volver a otra dirección?"** — Because the user might not be going home after the salon. Dinner, a friend's house, an event. One tap to change the return destination.

### Uber Scheduling Logic

**Pickup TO salon:**
- Appointment at 2:00 PM
- Uber estimates 12 min ride
- Add 3 min buffer
- Schedule pickup at 1:45 PM from user's home/current location

**Pickup FROM salon:**
- Service duration: 45 min
- Add 5 min buffer for checkout
- Schedule pickup at 2:50 PM from salon address
- Destination: user's home (default) or custom return address

**If appointment reschedules:** Both Uber rides auto-adjust. User gets notification: "Tu cita se movió a las 3:00 PM. Tus Ubers se actualizaron automáticamente."

**If appointment cancels:** Both Ubers cancelled automatically. Notification confirms.

### Uber Day-Of Notifications

```
2 hours before:
🔔 Recordatorio: Relleno de uñas hoy a las 2:00 PM
   Tu Uber te recoge a la 1:45 PM

15 min before pickup:
🔔 Tu Uber llega en 15 minutos
   [VER EN UBER]

5 min before pickup:
🔔 Tu Uber está cerca
   Juan · Nissan Versa · Placas ABC-123
   [VER EN UBER]

During appointment:
🔔 Tu servicio está por terminar
   Tu Uber de regreso llega en ~10 min

After appointment:
🔔 Tu Uber de regreso está en camino
   [VER EN UBER]  [CAMBIAR DESTINO]
```

"CAMBIAR DESTINO" at the end — plans change. One tap to redirect the return ride.

### Salon-Side Uber Signal

When the user's Uber is en route to the salon:

```
🔔 Tu clienta Ana está en camino
   Llega en ~10 min para su relleno de uñas con María
```

This replaces the typical check-in button. The salon knows the client is coming before they walk in.

### Uber API Integration

Uses Uber's Ride Request API:
- `POST /v1.2/requests/estimate` — fare estimate (during card display)
- `POST /v1.2/requests` — schedule ride (at booking confirmation)
- `DELETE /v1.2/requests/{id}` — cancel ride (appointment cancel/reschedule)
- `PATCH /v1.2/requests/{id}` — update destination (return address change)
- `GET /v1.2/requests/{id}` — ride status (for notifications)

Authentication: Uber OAuth 2.0 with user's existing Uber account on device. The app uses Uber's deep link SDK to authenticate without re-entering credentials.

### How Uber Mode Affects Ranking

When transport mode is Uber, the engine automatically adjusts the proximity weight downward by 30% and redistributes to rating and availability. Rationale: when someone else is driving, distance matters less — quality and timing matter more.

```
Original weights (nail fill-in): prox=0.40, avail=0.25, rating=0.20, price=0.15
Uber-adjusted:                   prox=0.28, avail=0.30, rating=0.27, price=0.15
```

This means a higher-rated salon 20 min away can beat a mediocre salon 5 min away when the user is taking Uber. Makes sense — they're not driving, so why compromise on quality?

---

## 9. Review Intelligence

### The Problem with Reviews

Every booking app shows reviews the same way: most recent first, 5 stars, "Excelente servicio." This is noise. Nobody reads 200 reviews to decide on a manicure.

### The Solution: Curated Review Snippets

The result card shows exactly one review. The engine picks the review that is most likely to close the deal for THIS specific booking decision.

### Selection Criteria (Priority Order)

1. **Service type match.** The review mentions the same service the user selected. A review about haircuts is irrelevant on a nail fill-in card.

2. **Recency.** Last 30 days preferred. Last 90 days acceptable. Beyond that only if nothing better exists.

3. **Substance.** Minimum 20 words. Filters "Muy bien 5 estrellas" noise. Favors reviews containing:
   - A specific outcome ("me quedaron perfectas")
   - An emotional moment ("me salvó antes de mi boda")
   - A named stylist (matches the staff member on the card)
   - A comparison ("mejor que donde iba antes")

4. **Sentiment intensity.** Not just positive — enthusiastic. "Estuvo bien" = flat. "No puedo dejar de ver mis uñas" = deal-closer.

5. **Reviewer similarity.** Bias toward reviews from users with similar profiles (age range, service history) if data available.

### How Reviews Are Tagged at Submission

When a user writes a review, the system already knows the appointment details (service type, staff, business). At write time, the review text is tagged:

```sql
CREATE TABLE review_tags (
  review_id UUID REFERENCES reviews(id) ON DELETE CASCADE,
  service_type TEXT NOT NULL,             -- from the appointment's service
  staff_id UUID REFERENCES staff(id),    -- from the appointment
  detected_keywords TEXT[],               -- extracted service keywords
  sentiment_score NUMERIC(3,2),           -- 0.0 to 1.0
  word_count INTEGER,
  has_specific_outcome BOOLEAN DEFAULT false,
  has_emotional_moment BOOLEAN DEFAULT false,
  has_staff_mention BOOLEAN DEFAULT false,
  has_comparison BOOLEAN DEFAULT false,
  snippet_quality_score NUMERIC(3,2),     -- composite quality for ranking
  PRIMARY KEY (review_id, service_type)
);
```

**Keyword detection:** Simple pattern matching against a curated list per service category. "uñas", "gel", "relleno", "color", "mechas", "pestañas", "lifting", etc. Not AI — deterministic, fast, cheap.

**Sentiment scoring:** Word count + positive keyword density + exclamation marks + superlatives ("increíble", "perfecta", "lo mejor"). Simple weighted sum. No ML model needed.

**Snippet quality score:** Composite of word_count (normalized), sentiment_score, boolean flags (outcome, emotion, staff mention). Pre-computed so the engine can grab the best snippet in O(1) at query time.

### Engine Fetches Snippet

At Step 6 of the intelligence engine, for each of the top 3 results:

```sql
SELECT r.staff_review, r.overall_rating,
       p.first_name || ' ' || LEFT(p.last_name, 1) || '.' AS author_name,
       EXTRACT(DAY FROM now() - r.created_at)::integer AS days_ago
FROM reviews r
JOIN review_tags rt ON rt.review_id = r.id
JOIN profiles p ON p.id = r.customer_id
WHERE rt.service_type = $service_type
  AND r.business_id = $business_id
  AND r.is_visible = true
ORDER BY rt.snippet_quality_score DESC,
         r.created_at DESC
LIMIT 1;
```

One indexed query per result. Fast.

### Fallback When No Good Review Exists

**No service-type match but has reviews:**
```
  ⭐ 4.9 · 87 reseñas
  Recomendado en uñas
```

"Recomendado en [category]" generated when 60%+ of reviews mention that category and average is above 4.5.

**No reviews at all (new salon):**
```
  🆕 Nuevo en BeautyCita
  📸 12 fotos de trabajos
```

Redirects attention to portfolio. If neither reviews nor portfolio exist, the card omits the review section entirely — doesn't show fake or empty content.

---

## 10. Admin Panel — Dynamic Engine Tuning

Dedicated admin-only screen for tuning every parameter of the intelligence engine. All changes take effect immediately (service profiles are cache-busted on save).

### Access

Admin role check via Supabase Auth + RLS. Only users with `role = 'admin'` in the `profiles` table can access `/admin/engine`.

### Layout

**Main screen — Service profile list:**
```
┌─────────────────────────────────┐
│ ⚙ Motor de Inteligencia         │
│ Perfiles de Servicio            │
├─────────────────────────────────┤
│ 🔍 [buscar servicio...]        │
│                                 │
│ ▼ 💅 Uñas                      │
│   ├─ Manicure Clásico           │
│   ├─ Manicure Gel               │
│   ├─ Relleno                    │
│   ├─ Nail Art                   │
│   └─ ...                        │
│ ▶ ✂️ Cabello                    │
│ ▶ 👁️ Pestañas y Cejas          │
│ ▶ 💄 Maquillaje                │
│ ▶ 💆 Facial                    │
│ ▶ 🧖 Cuerpo y Spa              │
│ ▶ 🧴 Cuidado Especializado     │
│                                 │
│ [+ Nuevo Perfil de Servicio]    │
└─────────────────────────────────┘
```

### Profile Editor (expanded)

Every attribute has a slider (0.0-1.0 scale) or input field, plus help text in Spanish explaining what it controls and what it affects.

```
┌─────────────────────────────────┐
│ Relleno de Uñas                 │
│ service_type: nail_fill_in      │
├─────────────────────────────────┤
│                                 │
│ ═══ CARACTERÍSTICAS ═══         │
│                                 │
│ Disponibilidad           [0.80] │
│ ──────────────●───── 0.0 → 1.0 │
│ ℹ️ Qué tan fácil es encontrar  │
│ este servicio. 0.0 = solo       │
│ especialistas. 1.0 = cualquier  │
│ salón. Afecta: radio de         │
│ búsqueda (más disponible = radio│
│ más corto) y peso de proximidad.│
│                                 │
│ Duración típica (min)     [ 45] │
│ ℹ️ Duración promedio. Se usa    │
│ para verificar horarios y       │
│ estimar hora de finalización.   │
│ También determina el horario de │
│ recogida del Uber de regreso.   │
│                                 │
│ Criticidad de habilidad  [0.30] │
│ ──●──────────────── 0.0 → 1.0  │
│ ℹ️ Qué tanto importa la        │
│ habilidad. 0.0 = difícil de    │
│ arruinar. 1.0 = un error es    │
│ desastroso. Afecta: peso de     │
│ rating y portafolio. Servicios  │
│ con alta criticidad priorizan   │
│ calificaciones sobre proximidad.│
│                                 │
│ Varianza de precio       [0.20] │
│ ─●───────────────── 0.0 → 1.0  │
│ ℹ️ Qué tanto varía el precio   │
│ entre salones. 0.0 = todos      │
│ cobran similar. 1.0 = rango     │
│ enorme. Afecta: si se muestra   │
│ "vs promedio" en la tarjeta y   │
│ el peso de precio en el ranking.│
│                                 │
│ Importancia portafolio   [0.00] │
│ ●──────────────────  0.0 → 1.0 │
│ ℹ️ Necesidad de ver trabajos    │
│ previos. 0.0 = no necesario.    │
│ 1.0 = imprescindible. Cuando    │
│ > 0.5 la tarjeta incluye        │
│ carrusel de fotos. Afecta peso  │
│ de portafolio en el ranking.    │
│                                 │
│ ═══ INFERENCIA DE TIEMPO ═══    │
│                                 │
│ Lead time típico [same_day  ▼]  │
│ ℹ️ Cuánto antes se reserva.    │
│ same_day = lo quieren hoy.      │
│ months = planean con meses      │
│ (novia, XV años). Afecta la     │
│ ventana temporal del motor.     │
│                                 │
│ ¿Servicio para evento?    [ No] │
│ ℹ️ Si sí, el motor pregunta la │
│ fecha del evento y busca        │
│ relativo a esa fecha.           │
│                                 │
│ ═══ BÚSQUEDA ═══                │
│                                 │
│ Radio de búsqueda (km)    [8.0] │
│ ──────●─────────── 3.0 → 50.0  │
│ ℹ️ Radio máximo inicial. Si no │
│ encuentra 3 resultados, se      │
│ expande automáticamente hasta   │
│ el multiplicador máximo.        │
│                                 │
│ Auto-expandir radio       [ Sí] │
│ ℹ️ Permite al motor ampliar el │
│ radio si no hay suficientes     │
│ resultados.                     │
│                                 │
│ Multiplicador máximo      [3.0] │
│ ─────────●──────── 1.5 → 5.0   │
│ ℹ️ Hasta cuántas veces se      │
│ multiplica el radio base en     │
│ auto-expansión. 3.0 = el radio  │
│ puede triplicarse.              │
│                                 │
│ Preguntas de seguimiento  [  0] │
│ ℹ️ Cuántas preguntas antes de  │
│ resultados. 0 = directo. 1-3 =  │
│ necesita clarificación (tipo de │
│ pestañas, fecha de evento).     │
│                                 │
│ ═══ PESOS DE RANKING ═══        │
│ (deben sumar 1.00)              │
│                                 │
│ Proximidad             [0.40]   │
│ ────────────────●── 0.0 → 1.0  │
│ ℹ️ Importancia de cercanía.    │
│ Alto = el más cercano gana.     │
│ Bajo = vale la pena ir lejos.   │
│ Nota: en modo Uber este peso    │
│ se reduce 30% automáticamente.  │
│                                 │
│ Disponibilidad         [0.25]   │
│ ──────────●──────── 0.0 → 1.0  │
│ ℹ️ Importancia de que el       │
│ horario coincida con la ventana │
│ inferida. Alto = prioriza el    │
│ horario perfecto.               │
│                                 │
│ Calificación           [0.20]   │
│ ────────●────────── 0.0 → 1.0  │
│ ℹ️ Peso de estrellas y reseñas.│
│ Usa promedio bayesiano: 300     │
│ reseñas a 4.7 > 3 reseñas a    │
│ 5.0. Ponderado por recencia.    │
│                                 │
│ Precio                 [0.15]   │
│ ─────●─────────────  0.0 → 1.0 │
│ ℹ️ Importancia del precio.     │
│ Se compara contra el promedio   │
│ del área. Cerca del promedio =  │
│ puntaje alto.                   │
│                                 │
│ Portafolio             [0.00]   │
│ ●──────────────────  0.0 → 1.0 │
│ ℹ️ Peso de calidad visual del  │
│ trabajo. Requiere fotos en      │
│ perfil del estilista. Relevante │
│ para servicios donde el         │
│ resultado es visible.           │
│                                 │
│ Suma actual: [1.00] ✅           │
│                                 │
│ ═══ VISUALIZACIÓN ═══           │
│                                 │
│ Mostrar comparación precio [No] │
│ ℹ️ Muestra "prom. zona: $X"   │
│ junto al precio en la tarjeta.  │
│                                 │
│ Mostrar carrusel portafolio[No] │
│ ℹ️ Muestra fotos del trabajo   │
│ del estilista en la tarjeta.    │
│                                 │
│ Mostrar años experiencia  [No]  │
│ ℹ️ Muestra "X años exp" junto  │
│ al nombre del estilista.        │
│                                 │
│ Mostrar badge certificación[No] │
│ ℹ️ Muestra "Certificada en X"  │
│ para servicios que lo requieren.│
│                                 │
│ Mostrar indicador sin cita [Sí] │
│ ℹ️ Muestra "Se aceptan sin     │
│ cita" para salones que lo       │
│ permiten.                       │
│                                 │
│ ═══ HISTORIAL ═══               │
│                                 │
│ Última edición: hace 2 min      │
│ Por: BC (admin)                 │
│ Cambios recientes:              │
│  • weight_proximity: 0.45→0.40  │
│  • search_radius_km: 10.0→8.0  │
│                                 │
│ ═══ PRUEBA EN VIVO ═══          │
│                                 │
│ [🔍 PROBAR CON MI UBICACIÓN]   │
│ Ejecuta el motor con estos      │
│ pesos y tu ubicación actual.    │
│ Muestra los 3 resultados que    │
│ verían los usuarios.            │
│                                 │
│ [RESTABLECER]       [GUARDAR]   │
└─────────────────────────────────┘
```

### Admin Panel Features

**Weight sum validation:** Won't save if the 5 weights don't sum to 1.00 (±0.01 tolerance). Running total shown with green checkmark or red warning.

**Live preview ("Probar"):** After saving, tap "Probar con mi ubicación" to run the engine with current weights and admin's location. Shows the top 3 results exactly as users would see them. Validates changes before they hit production.

**Audit trail:** Every change records who, what, when. Viewable in the history section. Allows tracing a weird ranking back to a specific weight adjustment.

**Reset to defaults:** One tap to revert any profile to factory defaults.

**Correction rate alerts:** When `time_inference_corrections.correction_rate > 0.30` for a service type, a banner appears on that profile: "⚠️ 34% de usuarios cambian el horario sugerido. Considere ajustar la inferencia de tiempo."

**New profile creation:** Admin can add new service types as the market evolves. Create profile, set all weights, activate it, and it appears in the category tree.

### Additional Admin Screens

All admin screens share the same pattern: list view, expandable editor, sliders/inputs with Spanish help text, save with validation, audit trail.

---

#### Admin Screen: Engine Global Settings

Parameters that apply engine-wide, not per service type. Stored in `engine_settings` table (key-value).

```
┌─────────────────────────────────┐
│ ⚙ Configuración Global          │
│ del Motor                       │
├─────────────────────────────────┤
│                                 │
│ ═══ RESULTADOS ═══              │
│                                 │
│ Resultados mostrados       [ 3] │
│ ────●─────────────── 1 → 10    │
│ ℹ️ Cuántas tarjetas ve el      │
│ usuario. 3 es el punto ideal:  │
│ suficiente para comparar, poco │
│ para no abrumar.               │
│                                 │
│ Resultados de respaldo    [  6] │
│ ──────●──────────── 3 → 20     │
│ ℹ️ Pre-cargados para "¿Más    │
│ opciones?" Sin espera extra.   │
│                                 │
│ Candidatos mínimos         [ 3] │
│ ────●─────────────── 1 → 10    │
│ ℹ️ Si hay menos que este       │
│ número, el radio se expande    │
│ automáticamente.               │
│                                 │
│ Tiempo objetivo (ms)     [ 400] │
│ ─────────────●──── 200 → 1000  │
│ ℹ️ Presupuesto de tiempo para  │
│ el motor. Afecta timeout de    │
│ APIs externas (Google, Uber).  │
│                                 │
│ ═══ ALGORITMO DE SCORING ═══   │
│                                 │
│ Bayesiano: media prior  [ 4.3] │
│ ────────────●──── 3.0 → 5.0    │
│ ℹ️ Rating promedio asumido     │
│ para salones con pocas reseñas.│
│ "Inocente hasta demostrar lo   │
│ contrario." 4.3 = ligeramente  │
│ optimista.                     │
│                                 │
│ Bayesiano: peso prior    [ 10] │
│ ──────●──────────── 1 → 50     │
│ ℹ️ Cuántas reseñas             │
│ equivalentes vale la prior.    │
│ 10 = necesitas ~10 reseñas     │
│ para que tu rating real domine.│
│ Más alto = más conservador con │
│ salones nuevos.                │
│                                 │
│ Curva de precio          [1.4] │
│ ───────●─────────── 0.5 → 3.0  │
│ ℹ️ Qué tan fuerte penaliza    │
│ precios por encima del promedio.│
│ 1.0 = lineal. 2.0+ = penaliza │
│ mucho los caros. 0.5 = tolera  │
│ precios altos.                 │
│                                 │
│ ═══ MODO UBER ═══              │
│                                 │
│ Reducción proximidad     [0.30]│
│ ──────────●──────── 0.0 → 0.60│
│ ℹ️ Cuánto se reduce el peso   │
│ de proximidad cuando el usuario│
│ elige Uber. 0.30 = se reduce   │
│ 30%. La reducción se redistri- │
│ buye a rating y disponibilidad.│
│                                 │
│ → A rating             [0.60]  │
│ ─────────────●──── 0.0 → 1.0  │
│ ℹ️ De la reducción, qué %     │
│ va al peso de rating.          │
│                                 │
│ → A disponibilidad     [0.40]  │
│ ────────────●───── 0.0 → 1.0  │
│ ℹ️ De la reducción, qué %     │
│ va al peso de disponibilidad.  │
│ (rating + disponibilidad deben │
│  sumar 1.0)                    │
│                                 │
│ ═══ TRANSPORTE ═══             │
│                                 │
│ Buffer pickup ida (min)  [  3] │
│ ───●───────────────── 0 → 15   │
│ ℹ️ Minutos extra antes de la  │
│ hora de cita para calcular     │
│ recogida del Uber de ida.      │
│ 3 = recoge 3 min antes de lo   │
│ necesario.                     │
│                                 │
│ Buffer salida salón (min)[  5] │
│ ────●──────────────── 0 → 15   │
│ ℹ️ Minutos extra después de   │
│ la cita para el Uber de vuelta.│
│ 5 = programa recogida 5 min    │
│ después de la hora estimada de │
│ finalización.                  │
│                                 │
│ ═══ RESEÑAS ═══                │
│                                 │
│ Recencia preferida (días)[  30]│
│ ──────●──────────── 7 → 90     │
│ ℹ️ Reseñas dentro de este     │
│ rango tienen prioridad máxima  │
│ para el snippet en la tarjeta. │
│                                 │
│ Recencia máxima (días)  [  90] │
│ ───────────●───── 30 → 365     │
│ ℹ️ Reseñas más antiguas que   │
│ esto se ignoran para snippets. │
│ Solo se usan si no hay nada    │
│ más reciente.                  │
│                                 │
│ Palabras mínimas snippet [ 20] │
│ ──────●──────────── 5 → 50     │
│ ℹ️ Filtra reseñas cortas tipo │
│ "Muy bien 5 estrellas". Solo   │
│ reseñas con sustancia se usan  │
│ como snippet.                  │
│                                 │
│ ═══ PATRONES DE USUARIO ═══   │
│                                 │
│ Umbral blend            [0.60] │
│ ──────────●──────── 0.3 → 0.9 │
│ ℹ️ Confidence mínima para     │
│ mezclar el patrón personal del │
│ usuario con la inferencia      │
│ global. 0.6 = necesita ser     │
│ bastante consistente.          │
│                                 │
│ Umbral dominancia       [0.85] │
│ ───────────────●── 0.6 → 1.0  │
│ ℹ️ Confidence mínima para que │
│ el patrón personal reemplace   │
│ completamente la inferencia.   │
│ 0.85 = muy consistente.        │
│                                 │
│ Alerta corrección        [0.30]│
│ ──────────●──────── 0.1 → 0.6 │
│ ℹ️ Si este % de usuarios      │
│ cambian el horario sugerido,   │
│ se muestra alerta al admin.    │
│                                 │
│                                 │
│ [RESTABLECER]       [GUARDAR]  │
└─────────────────────────────────┘
```

**Schema:**
```sql
CREATE TABLE engine_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  data_type TEXT NOT NULL DEFAULT 'number'
    CHECK (data_type IN ('number', 'integer', 'boolean')),
  min_value NUMERIC,
  max_value NUMERIC,
  description_es TEXT,
  description_en TEXT,
  group_name TEXT NOT NULL,
  sort_order INTEGER DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT now(),
  updated_by UUID REFERENCES auth.users(id)
);
```

---

#### Admin Screen: Card Display Thresholds

Controls which conditional elements appear on result cards. These override the defaults in Section 7.

```
┌─────────────────────────────────┐
│ ⚙ Umbrales de Tarjeta           │
├─────────────────────────────────┤
│                                 │
│ Comparación de precio    [0.30] │
│ ──────────●──────── 0.1 → 0.8  │
│ ℹ️ Cuando price_variance del   │
│ servicio supera este umbral, la│
│ tarjeta muestra "prom. zona:   │
│ $X". Más bajo = más tarjetas   │
│ muestran comparación.          │
│                                 │
│ Carrusel portafolio      [0.50] │
│ ────────────●──── 0.2 → 0.9    │
│ ℹ️ Cuando portfolio_importance │
│ del servicio supera este       │
│ umbral, la tarjeta incluye     │
│ fotos del trabajo. Más bajo =  │
│ más servicios muestran fotos.  │
│                                 │
│ Años de experiencia      [0.50] │
│ ────────────●──── 0.2 → 0.9    │
│ ℹ️ Cuando skill_criticality   │
│ supera este umbral, la tarjeta │
│ muestra "X años de exp" del    │
│ estilista.                     │
│                                 │
│ Indicador "sin cita"     [0.70] │
│ ──────────────●── 0.3 → 0.9    │
│ ℹ️ Cuando availability_level  │
│ del servicio supera este       │
│ umbral Y el salón lo permite,  │
│ muestra "Se aceptan sin cita". │
│                                 │
│ Reseñas "nuevo en BC"    [  5] │
│ ────●─────────────── 1 → 20    │
│ ℹ️ Salones con menos de estas │
│ reseñas muestran badge "Nuevo  │
│ en BeautyCita" en lugar de     │
│ snippet de reseña.             │
│                                 │
│ [RESTABLECER]       [GUARDAR]  │
└─────────────────────────────────┘
```

---

#### Admin Screen: Category Tree Manager

CRUD for the service category tree (Section 3). Controls what users see on the home screen and subcategory sheets.

```
┌─────────────────────────────────┐
│ ⚙ Árbol de Categorías           │
├─────────────────────────────────┤
│ 🔍 [buscar...]                 │
│                                 │
│ ⇅ Drag to reorder              │
│                                 │
│ ▼ 💅 Uñas          [activa] ✏️│
│   ⇅ ├─ Manicure    [activa] ✏️│
│   ⇅ │  ├─ Clásico  [activa] ✏️│
│   ⇅ │  ├─ Gel      [activa] ✏️│
│   ⇅ │  └─ ...                  │
│   ⇅ ├─ Pedicure    [activa] ✏️│
│   ⇅ └─ Nail Art    [activa] ✏️│
│ ▶ ✂️ Cabello        [activa] ✏️│
│ ...                             │
│                                 │
│ [+ Nueva Categoría]             │
│ [+ Nueva Subcategoría]          │
│ [+ Nuevo Servicio (hoja)]       │
└─────────────────────────────────┘
```

**Edit category popup:**
```
┌─────────────────────────────────┐
│ Editar: Manicure Gel            │
├─────────────────────────────────┤
│ Nombre (ES) [Manicure Gel     ]│
│ Nombre (EN) [Gel Manicure     ]│
│ Ícono       [💅              ]│
│ Slug        [manicure_gel     ]│
│ ¿Activa?    [Sí]               │
│                                 │
│ Perfil vinculado:               │
│ [manicure_gel ▼] ← solo hojas  │
│                                 │
│ [CANCELAR]         [GUARDAR]   │
└─────────────────────────────────┘
```

**Rules:**
- Only leaf nodes link to service profiles
- Deactivating a branch deactivates all children (with confirmation)
- Reorder is drag-and-drop, saved immediately
- Cannot delete categories that have active bookings — only deactivate
- New categories require a linked service profile (or create one inline)

---

#### Admin Screen: Time Inference Rules

Editable grid of all time inference rules (Section 5). Each row is a time-of-day × day-of-week combination.

```
┌───────────────────────────────────────────────┐
│ ⚙ Reglas de Inferencia de Tiempo               │
├───────────────────────────────────────────────┤
│                                               │
│ Horas      │ Días      │ Ventana    │ Pico    │
│────────────┼───────────┼────────────┼─────────│
│ 6-9 AM     │ Cualquier │ Hoy 10-17  │ 10 AM  │
│ 9-13       │ Lun-Jue   │ Hoy-mañ    │ 11 AM  │
│ 9-13       │ Vie       │ Hoy 13-19  │ 2 PM   │
│ 9-13       │ Sáb       │ Hoy +3h    │ ASAP   │
│ 13-17      │ Lun-Jue   │ Mañana     │ 11 AM  │
│ ...        │ ...       │ ...        │ ...    │
│                                               │
│ [+ Nueva Regla]                               │
└───────────────────────────────────────────────┘
```

**Tap any row to expand editor:**
```
┌─────────────────────────────────┐
│ Regla: 9-13 / Lun-Jue           │
├─────────────────────────────────┤
│ Hora inicio            [   9]  │
│ Hora fin               [  13]  │
│ Día inicio (0=Dom)     [   1]  │
│ Día fin                [   4]  │
│                                 │
│ Descripción:                    │
│ [Hoy si hay, sino mañana      ]│
│                                 │
│ Offset días mín         [  0]  │
│ ℹ️ 0 = hoy es válido          │
│                                 │
│ Offset días máx         [  1]  │
│ ℹ️ 1 = hasta mañana           │
│                                 │
│ Hora preferida inicio   [ 10]  │
│ Hora preferida fin      [ 17]  │
│ Hora pico               [ 11]  │
│                                 │
│ ¿Activa?                [Sí]   │
│                                 │
│ ═══ ALERTAS ═══                │
│ ⚠️ 28% de correcciones en      │
│ "Masaje Relajante" para esta    │
│ regla. Usuarios prefieren       │
│ "fin de semana".                │
│                                 │
│ [CANCELAR]          [GUARDAR]  │
└─────────────────────────────────┘
```

**Validation:** Rules cannot have overlapping hour+day ranges. New rules must cover gaps identified in coverage audit.

---

#### Admin Screen: Review Intelligence

Manage keyword lists and sentiment configuration per service category.

```
┌─────────────────────────────────┐
│ ⚙ Inteligencia de Reseñas       │
├─────────────────────────────────┤
│                                 │
│ ═══ KEYWORDS POR CATEGORÍA ═══ │
│                                 │
│ ▼ 💅 Uñas                      │
│   uñas, gel, acrílico, relleno,│
│   nail art, esmalte, color,    │
│   manicure, pedicure, diseño   │
│   [✏️ editar lista]            │
│                                 │
│ ▶ ✂️ Cabello                    │
│ ▶ 👁️ Pestañas                  │
│ ...                             │
│                                 │
│ ═══ SENTIMIENTO ═══            │
│                                 │
│ Palabras positivas:             │
│ increíble, perfecta, lo mejor, │
│ encanta, hermosa, profesional, │
│ recomiendo, excelente, arte,   │
│ maravilla, salvó...            │
│ [✏️ editar lista]              │
│                                 │
│ Peso: longitud          [0.25] │
│ Peso: keywords positivos[0.30] │
│ Peso: exclamaciones     [0.10] │
│ Peso: resultado concreto[0.20] │
│ Peso: mención estilista [0.15] │
│                                 │
│ ═══ VISTA PREVIA ═══           │
│                                 │
│ [Ver top snippets por servicio] │
│ Muestra los mejores snippets   │
│ que el motor seleccionaría     │
│ ahora, para verificar calidad. │
│                                 │
│ [GUARDAR]                      │
└─────────────────────────────────┘
```

---

#### Admin Screen: Salon Management

View and manage all registered businesses. No editing of salon content (that's the salon owner's job) — only platform-level controls.

```
┌─────────────────────────────────┐
│ ⚙ Gestión de Salones             │
├─────────────────────────────────┤
│ 🔍 [buscar salón...]           │
│ Filtros: [Tier ▼] [Estado ▼]   │
│          [Categoría ▼]         │
│                                 │
│ 327 salones · 89 Tier 1 ·      │
│ 201 Tier 2 · 37 Tier 3         │
│                                 │
│ ┌───────────────────────────┐   │
│ │ Salon Bella     ⭐4.9 (87)│   │
│ │ Tier 2 · Uñas, Cabello   │   │
│ │ 📍 Col. Centro, GDL      │   │
│ │ Estado: Activo ✅          │   │
│ │ [VER] [SUSPENDER] [TIER]  │   │
│ └───────────────────────────┘   │
│                                 │
│ ┌───────────────────────────┐   │
│ │ Rosa Nails        ⭐ Nuevo│   │
│ │ Tier 1 · Uñas             │   │
│ │ 📍 Col. Providencia, GDL │   │
│ │ Estado: Activo ✅          │   │
│ │ [VER] [SUSPENDER] [TIER]  │   │
│ └───────────────────────────┘   │
│ ...                             │
└─────────────────────────────────┘
```

**Salon detail (admin view):**
```
┌─────────────────────────────────┐
│ Salon Bella — Admin View        │
├─────────────────────────────────┤
│ Tier actual: 2                  │
│ [Cambiar a Tier ▼]             │
│                                 │
│ Estado: Activo                  │
│ [SUSPENDER]  [DESACTIVAR]      │
│ Razón: [________________________]
│                                 │
│ ═══ ESTADÍSTICAS ═══           │
│ Reservas totales:        1,247  │
│ Reservas este mes:          89  │
│ Tasa cancelación:         4.2%  │
│ Rating promedio:          4.87  │
│ Reseñas totales:            87  │
│ Referido por:     @ana.garcia   │
│ Registrado:    2026-01-15       │
│                                 │
│ ═══ APARICIONES EN MOTOR ═══  │
│ Veces en top 3:            312  │
│ Veces seleccionado:        187  │
│ Tasa conversión:         59.9%  │
│                                 │
│ ═══ NOTAS ADMIN ═══           │
│ [                              ]│
│ [                              ]│
│ [GUARDAR NOTA]                  │
└─────────────────────────────────┘
```

**Tier management rules:**
- Tier promotion is automatic when requirements are met (notification to admin for review)
- Tier demotion requires admin action + notification to salon
- Suspension hides salon from engine results immediately
- Deactivation removes salon entirely (with data retention for audit)

---

#### Admin Screen: User Booking Patterns

Aggregated view of user booking behavior patterns. No individual user data exposed — only statistical aggregates for engine tuning.

```
┌─────────────────────────────────┐
│ ⚙ Patrones de Reserva           │
├─────────────────────────────────┤
│                                 │
│ ═══ POR SERVICIO ═══           │
│                                 │
│ Manicure Clásico                │
│  Día más popular: Viernes       │
│  Hora más popular: 2:00 PM     │
│  Usuarios con patrón: 47       │
│  Confianza promedio: 0.72      │
│                                 │
│ Relleno (Acrílico/Gel)          │
│  Día más popular: Jueves        │
│  Hora más popular: 11:00 AM    │
│  Usuarios con patrón: 23       │
│  Confianza promedio: 0.81      │
│ ...                             │
│                                 │
│ ═══ CORRECCIONES ═══           │
│                                 │
│ ⚠️ Masaje Relajante (Mar 17-21h)│
│  Corrección: 34% → fin de sem  │
│  [AJUSTAR REGLA]  [IGNORAR]    │
│                                 │
│ ⚠️ Keratina (Lun-Mie 9-13h)    │
│  Corrección: 28% → próx semana │
│  [AJUSTAR REGLA]  [IGNORAR]    │
│                                 │
│ ═══ ACCIONES ═══               │
│                                 │
│ [RESETEAR PATRONES USUARIO]    │
│ ℹ️ Borra todos los patrones   │
│ aprendidos. Útil después de    │
│ cambios grandes en inferencia. │
│                                 │
└─────────────────────────────────┘
```

---

#### Admin Screen: Notification Templates

Edit WhatsApp, SMS, push, and email templates. Variables use `{curly_braces}` placeholder syntax.

```
┌─────────────────────────────────┐
│ ⚙ Plantillas de Notificación    │
├─────────────────────────────────┤
│ Canal: [WhatsApp ▼]             │
│                                 │
│ ▼ Reserva confirmada            │
│   "Tu cita está confirmada:    │
│   {service} con {stylist} el   │
│   {date} a las {time} en       │
│   {salon}."                     │
│   [✏️ EDITAR]                   │
│                                 │
│ ▶ Recordatorio 24h              │
│ ▶ Uber en camino                │
│ ▶ Recordatorio Uber 2h         │
│ ▶ Servicio terminando           │
│ ▶ Pedir reseña                  │
│ ▶ Cancelación                   │
│ ▶ Reprogramación                │
│ ▶ Invitación salón              │
│                                 │
│ Variables disponibles:          │
│ {service} {stylist} {salon}     │
│ {date} {time} {client}         │
│ {price} {uber_time} {link}     │
│                                 │
│ [PREVISUALIZAR]  [GUARDAR]     │
└─────────────────────────────────┘
```

**Validation:**
- Templates must contain all required variables for their event type
- WhatsApp templates must comply with Meta's template approval rules (no promotional content in transactional templates)
- Preview shows rendered template with sample data

---

#### Admin Screen: Engine Analytics Dashboard

Real-time and historical metrics for monitoring engine health and tuning effectiveness.

```
┌──────────────────────────────────────────┐
│ ⚙ Analítica del Motor                    │
├──────────────────────────────────────────┤
│                                          │
│ ═══ RENDIMIENTO ═══                      │
│                                          │
│ Tiempo promedio respuesta:     287ms  ✅ │
│ P95 tiempo respuesta:          412ms  ⚠️│
│ P99 tiempo respuesta:          623ms  ❌│
│ Solicitudes hoy:               1,247     │
│ Errores hoy:                       3     │
│ Tasa de error:                 0.24%  ✅ │
│                                          │
│ ═══ CONVERSIÓN ═══                       │
│                                          │
│ Búsquedas → Reserva:          34.2%     │
│ ┌──────────────────────────┐             │
│ │ Manicure Clásico   42.1% │  ████████  │
│ │ Relleno            38.7% │  ███████   │
│ │ Corte Mujer        35.2% │  ███████   │
│ │ Masaje Relajante   31.0% │  ██████    │
│ │ Balayage           22.4% │  ████      │
│ │ Ext. Pestañas      19.8% │  ████      │
│ └──────────────────────────┘             │
│                                          │
│ ═══ INFERENCIA DE TIEMPO ═══            │
│                                          │
│ "¿Otro horario?" global:      11.3%     │
│ ┌──────────────────────────┐             │
│ │ Masaje Relajante   28.4% │ ⚠️         │
│ │ Keratina           22.1% │ ⚠️         │
│ │ Maquillaje Novia   18.9% │             │
│ │ Manicure Clásico    4.2% │ ✅         │
│ │ Relleno             5.1% │ ✅         │
│ └──────────────────────────┘             │
│                                          │
│ ═══ TRANSPORTE ═══                       │
│                                          │
│ 🚗 Auto:      58%                        │
│ 🚕 Uber:      24%                        │
│ 🚌 Me llevo:  18%                        │
│                                          │
│ Uber reservas completadas: 87.3%        │
│ Uber cancelaciones: 12.7%               │
│                                          │
│ ═══ COBERTURA ═══                        │
│                                          │
│ Radio expandido:               8.4%     │
│ Servicios sin resultados:                │
│ ┌──────────────────────────┐             │
│ │ Remoción Tatuajes    47 búsq│          │
│ │ Micropigmentación    31 búsq│          │
│ │ Depilación Láser     28 búsq│          │
│ └──────────────────────────┘             │
│ ℹ️ Servicios más buscados sin           │
│ salones que los ofrezcan. Oportunidad   │
│ de crecimiento.                          │
│                                          │
│ ═══ CALIDAD DE RESULTADOS ═══           │
│                                          │
│ Card #1 seleccionada:         71.2%     │
│ Card #2 seleccionada:         19.8%     │
│ Card #3 seleccionada:          6.3%     │
│ "Más opciones" solicitado:     2.7%     │
│                                          │
│ ℹ️ Si Card #1 baja del 60%, los        │
│ pesos necesitan ajuste. Si "Más         │
│ opciones" supera el 10%, el motor       │
│ no está encontrando buenos matches.     │
│                                          │
│ ═══ SALONES ═══                         │
│                                          │
│ Total activos:               327        │
│ Nuevos este mes:              14        │
│ Referidos por usuarios:       23        │
│ Referidos registrados:        11 (48%) │
│ Promedio: registros/día:     1.2        │
│                                          │
│ Periodo: [Esta semana ▼] [Exportar CSV] │
└──────────────────────────────────────────┘
```

**Key health indicators:**
- Response time P95 > 400ms → yellow warning. P99 > 600ms → red alert.
- "¿Otro horario?" rate > 20% for any service → time inference rules need adjustment (highlighted in orange with link to rule editor).
- Card #1 selection < 60% → ranking weights may be off (link to service profile editor).
- "Más opciones" > 10% → engine quality issue.
- Radius expansion > 15% → service radius is too tight OR salon coverage gap.
- Services with no results → opportunity list for salon outreach campaigns.

---

## 11. Salon Onboarding — Three Tiers

### The Problem

The smartest intelligence engine is useless with zero salons. Mexican salon owners are busy. Many are single-operator businesses. Onboarding must be as effortless as the user booking experience.

### Tier 1 — "Ponme en el mapa" (60 seconds)

**Minimum to exist in BeautyCita:**
- Business name
- WhatsApp number
- Address (or drop pin on map)
- Select service categories they offer (tap from the same grid users see)

**That's it.** They're live. No bank account, no schedule, no pricing. The engine surfaces them with basic info. Users contact via WhatsApp to book. BeautyCita is the discovery layer.

**What the card looks like for Tier 1 salons:**
```
  Salon Rosa
  ⭐ Nuevo · 📍 2.3 km

  💬 Contactar por WhatsApp
```

No RESERVAR button — just WhatsApp contact. Still valuable for the user (they found a salon). Still valuable for the salon (they got a customer).

### Tier 2 — "Quiero reservas" (10 minutes)

Add:
- Services with prices and durations (select from pre-built tree, fill in their price)
- Working hours (visual weekly grid, drag to set)
- Staff members (name + which services)
- At least 1 photo

Now they get full engine integration — availability checking, online RESERVAR button, appointment lifecycle. BeautyCita manages the booking.

### Tier 3 — "Quiero crecer" (when ready)

Add:
- Stripe Connect for accepting payments through the app
- Portfolio photos per staff member
- Promotions and offers
- Review responses

Revenue features. Added when the salon sees value — not as a barrier to entry.

### Onboarding Flow (Tier 1)

```
WhatsApp message or in-app invite →
  Tap link →
    Business name [                    ]
    WhatsApp      [+52                 ]
    📍 [Buscar dirección o usar GPS]

    ¿Qué servicios ofreces?
    [💅 Uñas] [✂️ Cabello] [👁️ Pestañas]
    [💄 Maquillaje] [💆 Facial] [🧖 Spa]

    [REGISTRARME GRATIS]
```

One screen. No email verification. No password. WhatsApp IS the authentication (OTP via Twilio WhatsApp). 60 seconds to live.

---

## 12. Grassroots Growth — Salon Discovery & Acquisition Pipeline

### The Problem with Manual Referrals

The original design asked users to type a salon name and WhatsApp number. This fails because users don't know numbers by heart. Leaving the app to find a number and returning to paste it crosses the threshold of what an average user will do. The flow is dead on arrival.

### The Solution: Pre-Scraped Business Database + One-Tap Invite

BeautyCita maintains a database of beauty businesses scraped from multiple public sources. When a user can't find their stylist, we show them nearby businesses NOT YET on BeautyCita — styled like a WhatsApp contact list — and let them invite with a single tap.

### Data Sources (Multi-Source Scraper)

Three primary sources, cross-referenced to maximize coverage:

| Source | What it provides | Coverage in Mexico | Cost |
|---|---|---|---|
| Google Maps | Name, phone, address, coords, rating, reviews, photos, hours, category | Excellent | Free (scrape) |
| Facebook Business Pages | Name, phone, address, photos, category, hours, reviews | Excellent (nearly universal in MX) | Free (Graph API free tier + scrape) |
| Bing Maps | Name, phone, address, coords, rating, category | Good | Free (scrape) |

**Why three sources:** Each fills gaps the others miss. Cross-referencing by phone number + coordinates (within 50m) deduplicates across sources. Expected result: capturing virtually every beauty service business that has any online presence.

**Scraper infrastructure:**
- Python + Playwright, running on a local box or beautypi (Raspberry Pi via Tailscale)
- Basic VPN for source rotation — no need for expensive rotating proxies at this scale
- Search queries per area: "salón de belleza", "estética", "uñas", "peluquería", "spa", "pestañas", "barbería", "maquillaje"
- Output format: CSV matching `data/discovered_salons_template.csv` schema
- Schedule: initial bulk scrape per metro area, monthly refresh for active cities
- Import pipeline: CSV → validation → deduplication → `discovered_salons` table

**Data template:** `data/discovered_salons_template.csv` and `data/discovered_salons_schema.json` define the exact fields, formats, and validation rules.

**Fields captured per listing:**
```
source, source_id, name, phone, whatsapp, address, city, state,
country, lat, lng, photo_url, rating, reviews_count,
business_category, service_categories, hours, website,
facebook_url, instagram_handle, scraped_at
```

### The Invite Flow — User Side

When a user taps "¿No encuentras a tu estilista?" anywhere in the app (after results, on home screen, in search):

```
┌─────────────────────────────────┐
│ Estilistas cerca de ti          │
│ que aún no están en BeautyCita  │
├─────────────────────────────────┤  WhatsApp-styled:
│ 🔍 [buscar por nombre...]      │  #075E54 header
│                                 │  #DCF8C6 card tint
│ ┌───────────────────────────┐   │  #25D366 invite btn
│ │ [photo]  Salon Rosa       │   │
│ │          ⭐ 4.6 · 1.2 km  │   │
│ │         [INVITAR 💬]      │   │
│ └───────────────────────────┘   │
│ ┌───────────────────────────┐   │
│ │ [photo]  Nails by Lupita  │   │
│ │          ⭐ 4.8 · 3.4 km  │   │
│ │         [INVITAR 💬]      │   │
│ └───────────────────────────┘   │
│ ┌───────────────────────────┐   │
│ │ [ 👤 ]  Estética Diana    │   │  ← no photo =
│ │          ⭐ 4.2 · 5.1 km  │   │    default avatar
│ │         [INVITAR 💬]      │   │
│ └───────────────────────────┘   │
│                                 │
│ ~50 km radius · 372 estilistas │
└─────────────────────────────────┘
```

The list is styled to look like WhatsApp contacts — green color scheme (#075E54 header, #25D366 buttons), business photo as avatar (or default WhatsApp silhouette placeholder if no photo), familiar visual language that Mexican users instantly recognize.

**When user taps "INVITAR":**

Two things happen simultaneously:

```
TAP "INVITAR"
  │
  ├── CLIENT SIDE:
  │   Open WhatsApp via deep link:
  │   wa.me/52XXXXXXXXXX?text={pre-filled invitation}
  │   User sees pre-filled message, may tap send or not
  │
  └── SERVER SIDE (API call):
      ├── Upsert discovered_salons record
      ├── Insert salon_interest_signals (unique per user+salon)
      ├── Increment interest_count
      └── Evaluate outreach rules → queue platform message
```

**Pre-filled WhatsApp message (user's phone):**
```
Hola! Soy clienta tuya y me encantaría poder reservar
contigo desde BeautyCita. Es gratis para ti y te llegan
clientes nuevos. Regístrate en 60 seg:
beautycita.com/registro?ref={code}
```

The user may or may not tap send. It doesn't matter — the server-side flow runs regardless.

### The Outreach Flow — Platform Side

BeautyCita also contacts the salon directly via Twilio (WhatsApp > SMS > email, in that order). Each subsequent user who selects the same salon triggers an updated message with an escalating client count.

**Outreach escalation:**

| Unique users | Platform message |
|---|---|
| 1st | "Una clienta quiere reservar contigo en BeautyCita. Regístrate gratis en 60 seg: {link}" |
| 3rd | "3 clientas te buscan en BeautyCita. No pierdas reservas. Regístrate: {link}" |
| 5th | "5 personas intentaron reservar contigo esta semana. BeautyCita te conecta con ellas, gratis: {link}" |
| 10th | "10 clientas te buscan. Estás perdiendo reservas cada semana. 60 seg y listo: {link}" |
| 20th | "20 clientas y contando. Los salones registrados reciben su primera reserva en promedio en 48 hrs: {link}" |

**Outreach rules:**
- Send on user counts: 1, 3, 5, 10, 20, then every 10 after
- Never more than 1 outreach per 48 hours (even if 5 users tap in one day)
- Stop after salon status = `declined` or `unreachable`
- Stop after 10 attempts with no registration
- Channel preference: WhatsApp first (via Twilio), SMS fallback, email if found on listing

**Why this works:**
- **Dual-channel pressure:** Personal message from their own customer + professional message from BeautyCita with social proof
- **Real numbers:** The client count is genuine, not fabricated. Real people want to book with them.
- **Escalating urgency:** "1 clienta" is a nice-to-have. "10 clientas" is revenue they're losing.
- **Zero friction resolution:** Every message links to the 60-second Tier 1 onboarding

### Database Schema

```sql
-- Scraped business listings from Google Maps, Facebook, Bing, etc.
CREATE TABLE discovered_salons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Source identification
  source TEXT NOT NULL CHECK (source IN (
    'google_maps', 'facebook', 'bing', 'foursquare',
    'seccion_amarilla', 'manual'
  )),
  source_id TEXT,
  UNIQUE (source, source_id),

  -- Business data
  name TEXT NOT NULL,
  phone TEXT,                    -- E.164 format
  whatsapp TEXT,                 -- E.164 format, often same as phone
  address TEXT,
  city TEXT NOT NULL,
  state TEXT NOT NULL,
  country TEXT NOT NULL DEFAULT 'MX',
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  location GEOGRAPHY(POINT, 4326),  -- PostGIS, computed from lat/lng
  photo_url TEXT,                -- downloaded to R2 at import
  rating NUMERIC(2,1),
  reviews_count INTEGER,
  business_category TEXT,
  service_categories TEXT[],     -- mapped to BC categories at import
  hours TEXT,
  website TEXT,
  facebook_url TEXT,
  instagram_handle TEXT,

  -- Deduplication
  dedup_key TEXT GENERATED ALWAYS AS (
    COALESCE(phone, '') || ':' ||
    ROUND(COALESCE(lat,0)::numeric, 3)::text || ',' ||
    ROUND(COALESCE(lng,0)::numeric, 3)::text
  ) STORED,

  -- Outreach tracking
  interest_count INTEGER DEFAULT 0,
  first_selected_at TIMESTAMPTZ,
  last_selected_at TIMESTAMPTZ,
  last_outreach_at TIMESTAMPTZ,
  outreach_count INTEGER DEFAULT 0,
  outreach_channel TEXT,

  -- Status
  status TEXT DEFAULT 'discovered' CHECK (status IN (
    'discovered',       -- scraped, never selected by a user
    'selected',         -- at least 1 user tapped invite
    'outreach_sent',    -- platform message sent
    'registered',       -- salon signed up on BeautyCita
    'declined',         -- salon explicitly said no
    'unreachable'       -- phone invalid / no response after 10 attempts
  )),
  registered_business_id UUID REFERENCES businesses(id),
  registered_at TIMESTAMPTZ,

  scraped_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_discovered_salons_location
  ON discovered_salons USING GIST(location);
CREATE INDEX idx_discovered_salons_dedup
  ON discovered_salons(dedup_key);
CREATE INDEX idx_discovered_salons_city_status
  ON discovered_salons(city, status);
CREATE INDEX idx_discovered_salons_interest
  ON discovered_salons(interest_count DESC)
  WHERE status = 'selected' OR status = 'outreach_sent';

-- Track which users selected which salons (unique per user+salon)
CREATE TABLE salon_interest_signals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  discovered_salon_id UUID NOT NULL REFERENCES discovered_salons(id),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (discovered_salon_id, user_id)
);
```

The `UNIQUE` constraint on `salon_interest_signals` ensures the same user tapping the same salon twice doesn't inflate the count. Only unique users count toward outreach escalation.

The `dedup_key` column enables automatic deduplication when the same salon appears across multiple sources — same phone number within ~100m = same business.

### Growth Flywheel

```
User can't find stylist → Sees nearby salons from scraped DB
  → Taps invite (WhatsApp opens + server records interest)
    → Salon gets personal message from customer
    → Salon gets platform message with client count
      → Salon registers (60 seconds, Tier 1)
        → Salon appears in engine results
          → More users book → More salons see value
            → Salons upgrade tiers → Better data → Smarter engine
```

### Admin Visibility

The Salon Management admin screen (Section 10) includes a "Pipeline" tab showing:
- Discovered salons by city and status
- Top salons by interest count (highest demand, not yet registered)
- Outreach conversion funnel: discovered → selected → outreach_sent → registered
- Scraper health: last run per source per city, records added/updated

---

## 13. Database Schema Additions

These tables are IN ADDITION to the core schema from the original plan (profiles, businesses, services, staff, appointments, reviews, payments, notifications, favorites, promotions, loyalty_points, messages). The original migrations remain valid.

### New Tables

**service_profiles** — Intelligence engine configuration per service type (Section 4, full schema above)

**service_categories_tree** — The visual category tree for the UI:
```sql
CREATE TABLE service_categories_tree (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id UUID REFERENCES service_categories_tree(id),
  slug TEXT NOT NULL UNIQUE,
  display_name_es TEXT NOT NULL,
  display_name_en TEXT NOT NULL,
  icon TEXT,
  sort_order INTEGER DEFAULT 0,
  depth INTEGER NOT NULL CHECK (depth BETWEEN 0 AND 2),
  is_leaf BOOLEAN DEFAULT false,
  service_type TEXT REFERENCES service_profiles(service_type),  -- only for leaf nodes
  is_active BOOLEAN DEFAULT true
);
```

**service_follow_up_questions** — Questions asked between service selection and results:
```sql
CREATE TABLE service_follow_up_questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_type TEXT NOT NULL REFERENCES service_profiles(service_type),
  question_order INTEGER NOT NULL,
  question_key TEXT NOT NULL,
  question_text_es TEXT NOT NULL,
  question_text_en TEXT NOT NULL,
  answer_type TEXT NOT NULL CHECK (answer_type IN ('visual_cards', 'date_picker', 'yes_no')),
  options JSONB,       -- for visual_cards: [{label_es, label_en, image_url, value}]
  is_required BOOLEAN DEFAULT true
);
```

**time_inference_rules** — Time inference matrix (Section 5, full schema above)

**time_inference_corrections** — Learning from user corrections (Section 5, full schema above)

**user_booking_patterns** — Returning user pattern detection (Section 5, full schema above)

**review_tags** — Pre-computed review snippet scoring (Section 9, full schema above)

**discovered_salons** — Scraped business listings from Google Maps, Facebook, Bing with outreach tracking (Section 12, full schema above)

**salon_interest_signals** — Tracks which users selected which salons for invitation, unique per user+salon (Section 12, full schema above)

**engine_settings** — Global engine configuration (key-value store, Section 10):
```sql
CREATE TABLE engine_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  data_type TEXT NOT NULL DEFAULT 'number'
    CHECK (data_type IN ('number', 'integer', 'boolean')),
  min_value NUMERIC,
  max_value NUMERIC,
  description_es TEXT,
  description_en TEXT,
  group_name TEXT NOT NULL,
  sort_order INTEGER DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT now(),
  updated_by UUID REFERENCES auth.users(id)
);
```

Default rows: `results_count` (3), `backup_results_count` (6), `min_candidates_before_expand` (3), `response_time_target_ms` (400), `bayesian_prior_mean` (4.3), `bayesian_prior_weight` (10), `price_normalization_steepness` (1.4), `uber_proximity_reduction` (0.30), `uber_rating_redistribution` (0.60), `uber_availability_redistribution` (0.40), `uber_pickup_buffer_min` (3), `uber_checkout_buffer_min` (5), `review_recency_preferred_days` (30), `review_recency_max_days` (90), `review_min_word_count` (20), `user_pattern_blend_threshold` (0.60), `user_pattern_dominate_threshold` (0.85), `correction_rate_alert_threshold` (0.30), `card_price_comparison_threshold` (0.30), `card_portfolio_carousel_threshold` (0.50), `card_experience_years_threshold` (0.50), `card_walkin_availability_threshold` (0.70), `card_new_salon_review_threshold` (5).

**notification_templates** — Editable notification templates per channel and event:
```sql
CREATE TABLE notification_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type TEXT NOT NULL,
  channel TEXT NOT NULL CHECK (channel IN ('whatsapp', 'sms', 'push', 'email', 'in_app')),
  recipient_type TEXT NOT NULL CHECK (recipient_type IN ('customer', 'salon')),
  template_es TEXT NOT NULL,
  template_en TEXT NOT NULL,
  required_variables TEXT[] NOT NULL DEFAULT '{}',
  is_active BOOLEAN DEFAULT true,
  updated_at TIMESTAMPTZ DEFAULT now(),
  updated_by UUID REFERENCES auth.users(id),
  UNIQUE (event_type, channel, recipient_type)
);
```

**engine_analytics_events** — Event log for analytics dashboard:
```sql
CREATE TABLE engine_analytics_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type TEXT NOT NULL CHECK (event_type IN (
    'search', 'booking', 'time_override', 'more_options',
    'card_selected', 'radius_expanded', 'no_results'
  )),
  service_type TEXT,
  transport_mode TEXT,
  card_position INTEGER,           -- 1, 2, or 3 (for card_selected)
  response_time_ms INTEGER,
  radius_expanded BOOLEAN DEFAULT false,
  user_id UUID,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Partitioned by month for performance
CREATE INDEX idx_analytics_events_type_date
  ON engine_analytics_events(event_type, created_at DESC);
CREATE INDEX idx_analytics_events_service
  ON engine_analytics_events(service_type, created_at DESC)
  WHERE service_type IS NOT NULL;
```

**admin_notes** — Admin notes on salons and users:
```sql
CREATE TABLE admin_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  target_type TEXT NOT NULL CHECK (target_type IN ('business', 'user')),
  target_id UUID NOT NULL,
  note TEXT NOT NULL,
  created_by UUID NOT NULL REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_admin_notes_target ON admin_notes(target_type, target_id);
```

**user_transport_preferences** — Last used transport mode (for pre-selection, not default):
```sql
CREATE TABLE user_transport_preferences (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id),
  last_transport_mode TEXT DEFAULT 'car'
    CHECK (last_transport_mode IN ('car', 'uber', 'transit')),
  uber_linked BOOLEAN DEFAULT false,
  home_address_lat DOUBLE PRECISION,
  home_address_lng DOUBLE PRECISION,
  home_address_text TEXT,
  updated_at TIMESTAMPTZ DEFAULT now()
);
```

**uber_scheduled_rides** — Tracking Uber bookings tied to appointments:
```sql
CREATE TABLE uber_scheduled_rides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  appointment_id UUID NOT NULL REFERENCES appointments(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  leg TEXT NOT NULL CHECK (leg IN ('outbound', 'return')),
  uber_request_id TEXT,              -- from Uber API
  pickup_lat DOUBLE PRECISION NOT NULL,
  pickup_lng DOUBLE PRECISION NOT NULL,
  pickup_address TEXT,
  dropoff_lat DOUBLE PRECISION NOT NULL,
  dropoff_lng DOUBLE PRECISION NOT NULL,
  dropoff_address TEXT,
  scheduled_pickup_at TIMESTAMPTZ NOT NULL,
  estimated_fare_min NUMERIC(10,2),
  estimated_fare_max NUMERIC(10,2),
  currency TEXT DEFAULT 'MXN',
  status TEXT DEFAULT 'scheduled'
    CHECK (status IN ('scheduled', 'requested', 'accepted', 'arriving', 'in_progress', 'completed', 'cancelled')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
```

### Modified Tables

**services** — Add `service_type` column linking to service_profiles:
```sql
ALTER TABLE services ADD COLUMN service_type TEXT REFERENCES service_profiles(service_type);
CREATE INDEX idx_services_service_type ON services(service_type) WHERE is_active = true;
```

**reviews** — Add `service_type` column for snippet matching:
```sql
ALTER TABLE reviews ADD COLUMN service_type TEXT;
```

**profiles** — Add admin role and home location:
```sql
ALTER TABLE profiles ADD COLUMN role TEXT DEFAULT 'customer'
  CHECK (role IN ('customer', 'admin'));
ALTER TABLE profiles ADD COLUMN home_lat DOUBLE PRECISION;
ALTER TABLE profiles ADD COLUMN home_lng DOUBLE PRECISION;
ALTER TABLE profiles ADD COLUMN home_address TEXT;
```

**staff** — Add experience_years:
```sql
ALTER TABLE staff ADD COLUMN experience_years INTEGER;
```

---

## 14. Edge Functions

### curate-results (THE core function)

Described in full in Section 6. The intelligence engine.

### schedule-uber

Handles Uber ride scheduling when a booking is confirmed with Uber transport:
- Creates both outbound and return ride requests via Uber API
- Stores ride IDs in `uber_scheduled_rides`
- Returns confirmation with fare estimates

### update-uber-rides

Triggered when an appointment is rescheduled or cancelled:
- Reschedule: updates both Uber ride pickup times
- Cancel: cancels both Uber rides
- Sends notification to user about the changes

### tag-review

Triggered on review insert (via Supabase database webhook):
- Extracts service keywords from review text
- Computes sentiment score
- Detects staff mention, specific outcomes, emotional moments
- Inserts into `review_tags` with pre-computed `snippet_quality_score`

### outreach-discovered-salon

Triggered when a user taps "INVITAR" on a discovered salon:
- Upserts `discovered_salons` record, increments `interest_count`
- Inserts `salon_interest_signals` (unique per user+salon)
- Evaluates outreach rules (count thresholds, 48h cooldown, attempt limits)
- If outreach warranted: sends escalating message via Twilio (WhatsApp > SMS)
- Updates salon status and outreach tracking fields

### Original Edge Functions (from base plan, still needed)

- **book-appointment** — validates availability, creates appointment, charges deposit if needed, sends notifications. NOW ALSO: schedules Uber rides if transport_mode was uber.
- **cancel-appointment** — validates cancellation window, processes refund, cancels Uber rides.
- **process-payment** — Stripe integration (cards, OXXO).
- **search-businesses** — REPLACED by curate-results for user-facing search. Kept for admin/debug use.
- **send-notification** — multi-channel dispatch (push, SMS, WhatsApp, email).
- **check-availability** — ABSORBED into curate-results. Kept as standalone for reschedule flow.

---

## 15. Notification System

### Booking Lifecycle Notifications

All notifications sent via `send-notification` edge function, which checks user preferences before dispatching on each channel.

**Channels:** Push (FCM), WhatsApp (Twilio), SMS (Twilio fallback), Email, In-App.

**WhatsApp is primary for Mexico.** Push is secondary. Email is tertiary. SMS is last resort (costs money per message).

| Event | User Notification | Salon Notification |
|---|---|---|
| Booking confirmed | "Tu cita está confirmada: [service] con [stylist] el [date] a las [time]" | "Nueva reserva: [client] para [service] el [date] a las [time]" |
| 24h reminder | "Recordatorio: [service] mañana a las [time] en [salon]" | "Recordatorio: [client] mañana a las [time]" |
| 2h reminder (Uber) | "Tu Uber te recoge en 2 horas para tu cita" | — |
| Uber en route | "Tu Uber está en camino" | "Tu clienta [name] está en camino (~10 min)" |
| Appointment started | — | — (salon knows client is there) |
| Appointment completing | "Tu servicio está por terminar. Tu Uber de regreso llega pronto." | — |
| Uber return en route | "Tu Uber de regreso está en camino" | — |
| Appointment completed | "¿Cómo estuvo tu [service]? Deja una reseña" | "Cita completada: [client] · [service]" |
| Cancellation | "Tu cita fue cancelada. [refund info if applicable]" | "Cita cancelada: [client] · [service] · [date]" |
| Reschedule | "Tu cita se movió a [new date/time]. Tus Ubers se actualizaron." | "Cita reprogramada: [client] → [new date/time]" |
| Review received | — | "Nueva reseña de [client]: ⭐⭐⭐⭐⭐" |
| Salon invited | — | "Una clienta te recomendó en BeautyCita. Regístrate gratis: [link]" |

---

## 16. Implementation Priority

This design is built on top of the existing Flutter project at `/home/bc/beautycita/beautycita-app/`. The 139 Dart files, 12 migrations, and 7 edge functions from the base plan provide the foundation. This design adds the intelligence layer and redesigns the UX.

### Phase 1: Make It Work (Foundation)
1. Fix Supabase connection (init, config, link to project, apply migrations, seed)
2. Add new schema (service_profiles, categories_tree, follow_up_questions, time_inference_rules)
3. Seed service profiles with default weights for all leaf nodes
4. Seed category tree
5. Seed time inference rules

### Phase 2: The Engine
6. Build `curate-results` edge function (the 6 steps)
7. Build `find_available_slots` PostgreSQL function
8. Integrate Google Routes API (car + transit)
9. Build time inference logic
10. Build scoring + ranking logic

### Phase 3: The UX
11. Replace home screen with category grid
12. Build subcategory bottom sheet flow
13. Build follow-up question cards
14. Build transport selection cards
15. Build result cards (adaptive, stacked, swipeable)
16. Build confirmation screen
17. Build "¿Otro horario?" override flow
18. Wire auth to work without full Supabase (anonymous sign-in for browsing)

### Phase 4: Intelligence
19. Build review tagging system (tag-review edge function)
20. Build review snippet selection in curate-results
21. Build user booking pattern detection
22. Build time inference correction tracking
23. Build Bayesian rating calculation

### Phase 5: Uber Integration
24. Uber OAuth flow + account linking
25. Build schedule-uber edge function
26. Build update-uber-rides edge function
27. Add Uber scheduling to booking confirmation
28. Add Uber status notifications
29. Add return destination change flow

### Phase 6: Admin Panel
30. Build admin access control (role check, RLS for admin tables, /admin route guard)
31. Build service profile editor with sliders, help text, weight sum validation
32. Build live preview ("Probar con mi ubicación") — runs curate-results with admin's location
33. Build audit trail (profile change history)
34. Build engine global settings editor (engine_settings CRUD, grouped layout)
35. Build card display thresholds editor
36. Build category tree manager (CRUD, drag-to-reorder, activate/deactivate)
37. Build time inference rules editor (grid + expanded editor per rule)
38. Build review intelligence config (keyword lists, sentiment weights, snippet preview)
39. Build salon management screen (list, search, filter, tier management, suspension, admin notes)
40. Build user booking patterns viewer (aggregates, correction alerts, pattern reset)
41. Build notification template editor (per channel, variable validation, preview)
42. Build engine analytics dashboard (performance, conversion, inference, transport, coverage, quality metrics)
43. Seed engine_settings with all default values
44. Seed notification_templates with all event types + channels

### Phase 7: Growth — Salon Discovery & Acquisition
45. Build multi-source scraper (Python + Playwright, targeting Google Maps, Facebook, Bing)
46. Set up scraper on beautypi (Raspberry Pi M400 via Tailscale, Surfshark VPN)
47. Build CSV import pipeline (validate, deduplicate, populate `discovered_salons`)
48. Build WhatsApp-styled "¿No encuentras a tu estilista?" invite UI
49. Build `outreach-discovered-salon` edge function (interest tracking + escalating Twilio outreach)
50. Build salon onboarding (Tier 1 — 60 second, WhatsApp OTP auth)
51. Build salon upgrade path (Tier 1 → 2 → 3)
52. Build admin pipeline tab (discovered → selected → outreach → registered funnel)
53. Initial bulk scrape: Guadalajara, Puerto Vallarta, Cabo San Lucas metro areas

---

*This document is the complete design specification for BeautyCita's intelligent booking engine. It was collaboratively designed in a brainstorming session between BC (project owner) and Claude (architect) on 2026-01-31. Admin panel completeness review performed 2026-02-01 — added 9 new admin screens, 4 new database tables, expanded implementation plan from 40 to 49 tasks. Salon acquisition pipeline redesigned 2026-02-01 — replaced manual referral flow with multi-source scraper + WhatsApp-styled invite UI + escalating outreach system, expanded to 53 tasks. Every section was validated by BC before inclusion.*

*The core innovation — service-type-driven intelligence with adaptive cards, time inference, and integrated Uber round-trips — makes BeautyCita fundamentally different from every existing booking app. It doesn't show you options. It gives you the answer.*
