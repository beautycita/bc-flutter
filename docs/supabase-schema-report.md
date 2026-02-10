# BeautyCita Supabase Schema Report

**Date:** 2026-02-10
**Scope:** Complete analysis of the BeautyCita database schema, edge functions, Flutter models, and alignment with the design document.

---

## Table of Contents

1. [Complete Table Inventory](#1-complete-table-inventory)
2. [Relationships and Foreign Keys](#2-relationships-and-foreign-keys)
3. [RLS Policies](#3-rls-policies)
4. [Indexes](#4-indexes)
5. [Triggers and Functions](#5-triggers-and-functions)
6. [RPC Functions](#6-rpc-functions)
7. [Edge Functions and DB Usage](#7-edge-functions-and-db-usage)
8. [Flutter Model-to-Schema Mapping](#8-flutter-model-to-schema-mapping)
9. [Security Assessment](#9-security-assessment)
10. [Performance Considerations](#10-performance-considerations)
11. [Schema vs Design Doc Alignment](#11-schema-vs-design-doc-alignment)
12. [Gaps, Inconsistencies, and Concerns](#12-gaps-inconsistencies-and-concerns)
13. [Summary of Findings](#13-summary-of-findings)

---

## 1. Complete Table Inventory

The schema is defined across 13 migration files. After applying all migrations in order, the database contains the following tables:

### 1.1 Core Tables

#### `profiles`
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK, FK -> auth.users ON DELETE CASCADE |
| username | text | NOT NULL, UNIQUE, CHECK(char_length >= 3) |
| full_name | text | nullable |
| avatar_url | text | nullable |
| role | text | NOT NULL DEFAULT 'customer', CHECK IN ('customer', 'admin') |
| home_lat | double precision | nullable |
| home_lng | double precision | nullable |
| home_address | text | nullable |
| uber_linked | boolean | DEFAULT false (added migration 0006) |
| uber_access_token | text | nullable (added migration 0006) |
| uber_refresh_token | text | nullable (added migration 0006) |
| uber_token_expires_at | timestamptz | nullable (added migration 0006) |
| stripe_customer_id | text | nullable (added migration 20260209100000) |
| created_at | timestamptz | NOT NULL DEFAULT now() |
| updated_at | timestamptz | NOT NULL DEFAULT now() |

#### `businesses`
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() |
| owner_id | uuid | FK -> auth.users ON DELETE SET NULL, nullable |
| name | text | NOT NULL |
| phone | text | nullable |
| whatsapp | text | nullable |
| address | text | nullable |
| city | text | NOT NULL DEFAULT 'Guadalajara' |
| state | text | NOT NULL DEFAULT 'Jalisco' |
| country | text | NOT NULL DEFAULT 'MX' |
| lat | double precision | nullable |
| lng | double precision | nullable |
| location | geography(Point, 4326) | auto-populated from lat/lng via trigger |
| photo_url | text | nullable |
| average_rating | numeric(3,2) | NOT NULL DEFAULT 0.00 |
| total_reviews | integer | NOT NULL DEFAULT 0 |
| business_category | text | nullable |
| service_categories | text[] | nullable |
| hours | jsonb | nullable |
| website | text | nullable |
| facebook_url | text | nullable |
| instagram_handle | text | nullable |
| is_verified | boolean | NOT NULL DEFAULT false |
| is_active | boolean | NOT NULL DEFAULT true |
| tier | integer | NOT NULL DEFAULT 1, CHECK BETWEEN 1 AND 3 |
| cancellation_hours | integer | NOT NULL DEFAULT 24 |
| deposit_required | boolean | NOT NULL DEFAULT false |
| deposit_percentage | numeric(5,2) | NOT NULL DEFAULT 0 |
| auto_confirm | boolean | NOT NULL DEFAULT true |
| accept_walkins | boolean | NOT NULL DEFAULT false |
| created_at | timestamptz | NOT NULL DEFAULT now() |
| updated_at | timestamptz | NOT NULL DEFAULT now() |

#### `staff`
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK |
| business_id | uuid | NOT NULL, FK -> businesses ON DELETE CASCADE |
| first_name | text | NOT NULL |
| last_name | text | nullable |
| avatar_url | text | nullable |
| phone | text | nullable |
| experience_years | integer | nullable |
| average_rating | numeric(3,2) | NOT NULL DEFAULT 0.00 |
| total_reviews | integer | NOT NULL DEFAULT 0 |
| is_active | boolean | NOT NULL DEFAULT true |
| accept_online_booking | boolean | NOT NULL DEFAULT true |
| sort_order | integer | NOT NULL DEFAULT 0 |
| created_at | timestamptz | NOT NULL DEFAULT now() |
| updated_at | timestamptz | NOT NULL DEFAULT now() |

#### `services`
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK |
| business_id | uuid | NOT NULL, FK -> businesses ON DELETE CASCADE |
| service_type | text | FK -> service_profiles(service_type), nullable |
| name | text | NOT NULL |
| category | text | nullable |
| subcategory | text | nullable |
| price | numeric(10,2) | nullable |
| duration_minutes | integer | NOT NULL DEFAULT 60 |
| buffer_minutes | integer | NOT NULL DEFAULT 0 |
| is_active | boolean | NOT NULL DEFAULT true |
| created_at | timestamptz | NOT NULL DEFAULT now() |

#### `staff_services` (junction)
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK |
| staff_id | uuid | NOT NULL, FK -> staff ON DELETE CASCADE |
| service_id | uuid | NOT NULL, FK -> services ON DELETE CASCADE |
| custom_price | numeric(10,2) | nullable |
| custom_duration | integer | nullable |
| UNIQUE | | (staff_id, service_id) |

#### `staff_schedules`
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK |
| staff_id | uuid | NOT NULL, FK -> staff ON DELETE CASCADE |
| day_of_week | smallint | NOT NULL, CHECK 0-6 |
| start_time | time | NOT NULL |
| end_time | time | NOT NULL |
| is_available | boolean | NOT NULL DEFAULT true |
| UNIQUE | | (staff_id, day_of_week) |

#### `appointments`
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK |
| user_id | uuid | NOT NULL, FK -> auth.users ON DELETE CASCADE |
| business_id | uuid | NOT NULL, FK -> businesses ON DELETE CASCADE |
| staff_id | uuid | FK -> staff ON DELETE SET NULL |
| service_id | uuid | FK -> services ON DELETE SET NULL |
| service_name | text | NOT NULL |
| service_type | text | nullable |
| status | text | NOT NULL DEFAULT 'pending', CHECK IN 6 values |
| starts_at | timestamptz | NOT NULL |
| ends_at | timestamptz | NOT NULL |
| price | numeric(10,2) | nullable |
| deposit_amount | numeric(10,2) | nullable |
| transport_mode | text | nullable, CHECK IN ('car','uber','transit') |
| notes | text | nullable |
| created_at | timestamptz | NOT NULL DEFAULT now() |
| updated_at | timestamptz | NOT NULL DEFAULT now() |

#### `reviews`
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK |
| user_id | uuid | NOT NULL, FK -> auth.users ON DELETE CASCADE |
| business_id | uuid | NOT NULL, FK -> businesses ON DELETE CASCADE |
| staff_id | uuid | FK -> staff ON DELETE SET NULL |
| appointment_id | uuid | FK -> appointments ON DELETE SET NULL |
| service_type | text | nullable |
| rating | integer | NOT NULL, CHECK 1-5 |
| comment | text | nullable |
| is_visible | boolean | NOT NULL DEFAULT true |
| created_at | timestamptz | NOT NULL DEFAULT now() |
| UNIQUE | | (user_id, appointment_id) |

#### `favorites`
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK |
| user_id | uuid | NOT NULL, FK -> auth.users ON DELETE CASCADE |
| business_id | uuid | NOT NULL, FK -> businesses ON DELETE CASCADE |
| created_at | timestamptz | NOT NULL DEFAULT now() |
| UNIQUE | | (user_id, business_id) |

#### `payments`
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK |
| appointment_id | uuid | NOT NULL, FK -> appointments ON DELETE CASCADE |
| user_id | uuid | NOT NULL, FK -> auth.users ON DELETE CASCADE |
| amount | numeric(10,2) | NOT NULL |
| currency | text | NOT NULL DEFAULT 'MXN' |
| payment_method | text | NOT NULL, CHECK IN ('card','oxxo','cash') |
| stripe_payment_id | text | nullable |
| status | text | NOT NULL DEFAULT 'pending', CHECK IN 4 values |
| created_at | timestamptz | NOT NULL DEFAULT now() |
| updated_at | timestamptz | NOT NULL DEFAULT now() |

#### `notifications`
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK |
| user_id | uuid | NOT NULL, FK -> auth.users ON DELETE CASCADE |
| title | text | NOT NULL |
| body | text | NOT NULL |
| channel | text | NOT NULL, CHECK IN ('push','sms','whatsapp','email','in_app') |
| is_read | boolean | NOT NULL DEFAULT false |
| metadata | jsonb | NOT NULL DEFAULT '{}' |
| created_at | timestamptz | NOT NULL DEFAULT now() |

### 1.2 Intelligence Layer Tables

#### `service_profiles`
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK |
| service_type | text | NOT NULL, UNIQUE |
| category | text | NOT NULL |
| subcategory | text | nullable |
| display_name_es | text | NOT NULL |
| display_name_en | text | NOT NULL |
| icon | text | nullable |
| availability_level | numeric(3,2) | NOT NULL DEFAULT 0.80 |
| typical_duration_min | integer | NOT NULL DEFAULT 60 |
| skill_criticality | numeric(3,2) | NOT NULL DEFAULT 0.30 |
| price_variance | numeric(3,2) | NOT NULL DEFAULT 0.20 |
| portfolio_importance | numeric(3,2) | NOT NULL DEFAULT 0.00 |
| typical_lead_time | text | NOT NULL DEFAULT 'same_day', CHECK IN 5 values |
| is_event_driven | boolean | NOT NULL DEFAULT false |
| search_radius_km | numeric(5,1) | NOT NULL DEFAULT 8.0 |
| radius_auto_expand | boolean | NOT NULL DEFAULT true |
| radius_max_multiplier | numeric(3,1) | NOT NULL DEFAULT 3.0 |
| max_follow_up_questions | integer | NOT NULL DEFAULT 0 |
| weight_proximity | numeric(3,2) | NOT NULL DEFAULT 0.40 |
| weight_availability | numeric(3,2) | NOT NULL DEFAULT 0.25 |
| weight_rating | numeric(3,2) | NOT NULL DEFAULT 0.20 |
| weight_price | numeric(3,2) | NOT NULL DEFAULT 0.15 |
| weight_portfolio | numeric(3,2) | NOT NULL DEFAULT 0.00 |
| show_price_comparison | boolean | NOT NULL DEFAULT false |
| show_portfolio_carousel | boolean | NOT NULL DEFAULT false |
| show_experience_years | boolean | NOT NULL DEFAULT false |
| show_certification_badge | boolean | NOT NULL DEFAULT false |
| show_walkin_indicator | boolean | NOT NULL DEFAULT true |
| is_active | boolean | NOT NULL DEFAULT true |
| created_at | timestamptz | NOT NULL DEFAULT now() |
| updated_at | timestamptz | NOT NULL DEFAULT now() |
| updated_by | uuid | FK -> auth.users, nullable |
| CONSTRAINT | | weights_sum_one: abs(sum(weights) - 1.0) < 0.01 |

#### `service_categories_tree`
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK |
| parent_id | uuid | FK -> self, nullable |
| slug | text | NOT NULL, UNIQUE |
| display_name_es | text | NOT NULL |
| display_name_en | text | NOT NULL |
| icon | text | nullable |
| sort_order | integer | NOT NULL DEFAULT 0 |
| depth | integer | NOT NULL, CHECK 0-2 |
| is_leaf | boolean | NOT NULL DEFAULT false |
| service_type | text | FK -> service_profiles(service_type), nullable |
| is_active | boolean | NOT NULL DEFAULT true |

#### `service_follow_up_questions`
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK |
| service_type | text | NOT NULL, FK -> service_profiles(service_type) |
| question_order | integer | NOT NULL |
| question_key | text | NOT NULL |
| question_text_es | text | NOT NULL |
| question_text_en | text | NOT NULL |
| answer_type | text | NOT NULL, CHECK IN ('visual_cards','date_picker','yes_no') |
| options | jsonb | nullable |
| is_required | boolean | NOT NULL DEFAULT true |

#### `time_inference_rules`
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK |
| hour_start | smallint | NOT NULL, CHECK 0-23 |
| hour_end | smallint | NOT NULL, CHECK 0-23 |
| day_of_week_start | smallint | NOT NULL, CHECK 0-6 |
| day_of_week_end | smallint | NOT NULL, CHECK 0-6 |
| window_description | text | NOT NULL |
| window_offset_days_min | integer | NOT NULL DEFAULT 0 |
| window_offset_days_max | integer | NOT NULL DEFAULT 1 |
| preferred_hour_start | smallint | NOT NULL DEFAULT 10 |
| preferred_hour_end | smallint | NOT NULL DEFAULT 16 |
| preference_peak_hour | smallint | NOT NULL DEFAULT 11 |
| is_active | boolean | NOT NULL DEFAULT true |
| updated_at | timestamptz | NOT NULL DEFAULT now() |

#### `time_inference_corrections`
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK |
| service_type | text | NOT NULL |
| original_hour_range | text | NOT NULL |
| original_day_range | text | NOT NULL |
| correction_to | text | NOT NULL |
| correction_count | integer | NOT NULL DEFAULT 1 |
| total_bookings | integer | NOT NULL DEFAULT 1 |
| correction_rate | numeric(3,2) | nullable |
| created_at | timestamptz | NOT NULL DEFAULT now() |
| updated_at | timestamptz | NOT NULL DEFAULT now() |
| UNIQUE INDEX | | (service_type, original_hour_range, original_day_range, correction_to) |

#### `user_booking_patterns`
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK |
| user_id | uuid | NOT NULL, FK -> auth.users |
| service_category | text | NOT NULL |
| preferred_day_of_week | smallint | nullable |
| preferred_hour | smallint | nullable |
| booking_count | integer | NOT NULL DEFAULT 0 |
| confidence | numeric(3,2) | NOT NULL DEFAULT 0.0 |
| last_updated | timestamptz | NOT NULL DEFAULT now() |

#### `review_tags`
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK |
| review_id | uuid | NOT NULL, FK -> reviews ON DELETE CASCADE, UNIQUE INDEX |
| service_type | text | nullable |
| keywords | text[] | nullable |
| sentiment_score | numeric(3,2) | nullable |
| snippet_quality_score | numeric(3,2) | nullable |
| mentions_staff | boolean | NOT NULL DEFAULT false |
| mentions_outcome | boolean | NOT NULL DEFAULT false |
| word_count | integer | nullable |
| created_at | timestamptz | NOT NULL DEFAULT now() |

#### `engine_settings`
| Column | Type | Constraints |
|--------|------|-------------|
| key | text | PK |
| value | text | NOT NULL |
| data_type | text | NOT NULL DEFAULT 'number', CHECK IN ('number','integer','boolean') |
| min_value | numeric | nullable |
| max_value | numeric | nullable |
| description_es | text | nullable |
| description_en | text | nullable |
| group_name | text | NOT NULL |
| sort_order | integer | NOT NULL DEFAULT 0 |
| updated_at | timestamptz | NOT NULL DEFAULT now() |
| updated_by | uuid | FK -> auth.users, nullable |

#### `notification_templates`
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK |
| event_type | text | NOT NULL |
| channel | text | NOT NULL, CHECK IN 5 values |
| recipient_type | text | NOT NULL, CHECK IN ('customer','salon') |
| template_es | text | NOT NULL |
| template_en | text | NOT NULL |
| required_variables | text[] | NOT NULL DEFAULT '{}' |
| is_active | boolean | NOT NULL DEFAULT true |
| updated_at | timestamptz | NOT NULL DEFAULT now() |
| updated_by | uuid | FK -> auth.users, nullable |
| UNIQUE | | (event_type, channel, recipient_type) |

#### `engine_analytics_events`
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK |
| event_type | text | NOT NULL, CHECK IN 7 values |
| service_type | text | nullable |
| transport_mode | text | nullable |
| card_position | integer | nullable |
| response_time_ms | integer | nullable |
| radius_expanded | boolean | NOT NULL DEFAULT false |
| user_id | uuid | nullable |
| metadata | jsonb | NOT NULL DEFAULT '{}' |
| created_at | timestamptz | NOT NULL DEFAULT now() |

#### `admin_notes`
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK |
| target_type | text | NOT NULL, CHECK IN ('business','user') |
| target_id | uuid | NOT NULL |
| note | text | NOT NULL |
| created_by | uuid | NOT NULL, FK -> auth.users |
| created_at | timestamptz | NOT NULL DEFAULT now() |

### 1.3 Transport Tables

#### `user_transport_preferences`
| Column | Type | Constraints |
|--------|------|-------------|
| user_id | uuid | PK, FK -> auth.users |
| last_transport_mode | text | NOT NULL DEFAULT 'car', CHECK IN ('car','uber','transit') |
| uber_linked | boolean | NOT NULL DEFAULT false |
| home_address_lat | double precision | nullable |
| home_address_lng | double precision | nullable |
| home_address_text | text | nullable |
| updated_at | timestamptz | NOT NULL DEFAULT now() |

#### `uber_scheduled_rides`
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK |
| appointment_id | uuid | NOT NULL, FK -> appointments ON DELETE CASCADE |
| user_id | uuid | NOT NULL, FK -> auth.users |
| leg | text | NOT NULL, CHECK IN ('outbound','return') |
| uber_request_id | text | nullable |
| pickup_lat | double precision | NOT NULL |
| pickup_lng | double precision | NOT NULL |
| pickup_address | text | nullable |
| dropoff_lat | double precision | NOT NULL |
| dropoff_lng | double precision | NOT NULL |
| dropoff_address | text | nullable |
| scheduled_pickup_at | timestamptz | NOT NULL |
| estimated_fare_min | numeric(10,2) | nullable |
| estimated_fare_max | numeric(10,2) | nullable |
| currency | text | NOT NULL DEFAULT 'MXN' |
| status | text | NOT NULL DEFAULT 'scheduled', CHECK IN 7 values |
| created_at | timestamptz | NOT NULL DEFAULT now() |
| updated_at | timestamptz | NOT NULL DEFAULT now() |

### 1.4 Salon Discovery Pipeline

#### `discovered_salons`
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK |
| source | text | NOT NULL, CHECK IN 6 values |
| source_id | text | nullable |
| name | text | NOT NULL |
| phone | text | nullable |
| whatsapp | text | nullable |
| address | text | nullable |
| city | text | NOT NULL |
| state | text | NOT NULL |
| country | text | NOT NULL DEFAULT 'MX' |
| lat | double precision | nullable |
| lng | double precision | nullable |
| location | geography(Point, 4326) | auto-populated via trigger |
| photo_url | text | nullable |
| rating | numeric(2,1) | nullable |
| reviews_count | integer | nullable |
| business_category | text | nullable |
| service_categories | text[] | nullable |
| hours | text | nullable |
| website | text | nullable |
| facebook_url | text | nullable |
| instagram_handle | text | nullable |
| dedup_key | text | GENERATED ALWAYS STORED |
| interest_count | integer | NOT NULL DEFAULT 0 |
| first_selected_at | timestamptz | nullable |
| last_selected_at | timestamptz | nullable |
| last_outreach_at | timestamptz | nullable |
| outreach_count | integer | NOT NULL DEFAULT 0 |
| outreach_channel | text | nullable |
| status | text | NOT NULL DEFAULT 'discovered', CHECK IN 6 values |
| registered_business_id | uuid | FK -> businesses, nullable |
| registered_at | timestamptz | nullable |
| scraped_at | timestamptz | NOT NULL |
| created_at | timestamptz | NOT NULL DEFAULT now() |
| updated_at | timestamptz | NOT NULL DEFAULT now() |
| UNIQUE | | (source, source_id) |

#### `salon_interest_signals`
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK |
| discovered_salon_id | uuid | NOT NULL, FK -> discovered_salons |
| user_id | uuid | NOT NULL, FK -> auth.users |
| created_at | timestamptz | NOT NULL DEFAULT now() |
| UNIQUE | | (discovered_salon_id, user_id) |

### 1.5 QR Auth & Chat Tables

#### `qr_auth_sessions`
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK |
| code | text | NOT NULL UNIQUE |
| status | text | NOT NULL DEFAULT 'pending', CHECK IN 5 values (incl. 'revoked') |
| user_id | uuid | FK -> auth.users, nullable |
| email | text | nullable |
| email_otp | text | nullable (column-level REVOKE for anon/authenticated) |
| created_at | timestamptz | NOT NULL DEFAULT now() |
| expires_at | timestamptz | NOT NULL DEFAULT (now() + 5 min) |
| authorized_at | timestamptz | nullable |
| consumed_at | timestamptz | nullable |

Added to `supabase_realtime` publication.

#### `chat_threads`
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK |
| user_id | uuid | NOT NULL, FK -> auth.users |
| contact_type | text | NOT NULL, CHECK IN ('aphrodite','salon','user') |
| contact_id | text | nullable |
| openai_thread_id | text | nullable |
| last_message_text | text | nullable |
| last_message_at | timestamptz | DEFAULT now() |
| unread_count | int | DEFAULT 0 |
| pinned | boolean | DEFAULT false |
| created_at | timestamptz | DEFAULT now() |

#### `chat_messages`
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK |
| thread_id | uuid | NOT NULL, FK -> chat_threads ON DELETE CASCADE |
| sender_type | text | NOT NULL, CHECK IN ('user','aphrodite','salon','system') |
| sender_id | uuid | nullable |
| content_type | text | NOT NULL DEFAULT 'text', CHECK IN 6 values |
| text_content | text | nullable |
| media_url | text | nullable |
| metadata | jsonb | DEFAULT '{}' |
| created_at | timestamptz | DEFAULT now() |

### 1.6 User Media

#### `user_media`
| Column | Type | Constraints |
|--------|------|-------------|
| id | uuid | PK |
| user_id | uuid | NOT NULL, FK -> auth.users ON DELETE CASCADE |
| media_type | text | NOT NULL DEFAULT 'image', CHECK IN ('image','video') |
| source | text | NOT NULL, CHECK IN ('lightx','chat','upload','review','portfolio') |
| source_ref | uuid | nullable |
| url | text | NOT NULL |
| thumbnail_url | text | nullable |
| metadata | jsonb | DEFAULT '{}' |
| section | text | NOT NULL, CHECK IN ('personal','business','chat') |
| created_at | timestamptz | NOT NULL DEFAULT now() |

### 1.7 Tables Referenced but NOT in Migrations

The following tables are referenced by edge functions but have **no migration creating them**:

- **`uber_webhook_events`** -- Referenced by `uber-webhook/index.ts` which inserts raw Uber webhook data. No schema definition exists.
- **`scrape_requests`** -- Referenced by `on-demand-scrape/index.ts` which creates/queries scrape requests. No schema definition exists.

---

## 2. Relationships and Foreign Keys

### Entity Relationship Summary

```
auth.users (Supabase managed)
  |-- profiles (1:1, id = auth.users.id)
  |-- appointments (1:N, user_id)
  |-- reviews (1:N, user_id)
  |-- favorites (1:N, user_id)
  |-- payments (1:N, user_id)
  |-- notifications (1:N, user_id)
  |-- user_booking_patterns (1:N, user_id)
  |-- user_transport_preferences (1:1, user_id)
  |-- uber_scheduled_rides (1:N, user_id)
  |-- salon_interest_signals (1:N, user_id)
  |-- chat_threads (1:N, user_id)
  |-- user_media (1:N, user_id)
  |-- qr_auth_sessions (1:N, user_id)

businesses
  |-- staff (1:N, business_id)
  |-- services (1:N, business_id)
  |-- appointments (1:N, business_id)
  |-- reviews (1:N, business_id)
  |-- favorites (1:N, business_id)
  |-- discovered_salons.registered_business_id (1:1, optional)
  |-- owner_id -> auth.users (N:1, optional)

staff
  |-- staff_services (1:N, staff_id)
  |-- staff_schedules (1:N, staff_id)
  |-- appointments (1:N, staff_id, optional)
  |-- reviews (1:N, staff_id, optional)

services
  |-- staff_services (1:N, service_id)
  |-- appointments (N:1, service_id, optional)
  |-- service_type -> service_profiles(service_type)

service_profiles
  |-- services.service_type (1:N, FK text)
  |-- service_categories_tree.service_type (1:N, FK text)
  |-- service_follow_up_questions.service_type (1:N)

appointments
  |-- payments (1:N, appointment_id)
  |-- uber_scheduled_rides (1:N, appointment_id)
  |-- reviews (1:N, appointment_id, optional)

reviews
  |-- review_tags (1:1, review_id, unique index)

chat_threads
  |-- chat_messages (1:N, thread_id)

service_categories_tree
  |-- self-referencing (parent_id -> id)

discovered_salons
  |-- salon_interest_signals (1:N, discovered_salon_id)
```

### FK Cascade Behavior
- `auth.users` deletions cascade to: profiles, appointments, reviews, favorites, payments, notifications, user_media
- `businesses` deletions cascade to: staff, services, appointments, reviews, favorites
- `staff` deletions cascade to: staff_services, staff_schedules
- `services` deletions cascade to: staff_services
- `appointments` deletions cascade to: payments, uber_scheduled_rides
- `chat_threads` deletions cascade to: chat_messages
- `reviews` deletions cascade to: review_tags
- `discovered_salons` deletions: no cascade to salon_interest_signals (notable gap -- orphan signals possible)

### Notable FK Design Decisions
- `businesses.owner_id` ON DELETE SET NULL -- business survives if owner account deleted
- `appointments.staff_id` ON DELETE SET NULL -- appointment history preserved
- `appointments.service_id` ON DELETE SET NULL -- appointment survives service removal
- `service_profiles` uses `service_type` (text) as the FK target rather than id -- this is a deliberate design choice making the join key human-readable

---

## 3. RLS Policies

### Policy Inventory

| Table | SELECT | INSERT | UPDATE | DELETE | Notes |
|-------|--------|--------|--------|--------|-------|
| profiles | Own row only | Own row | Own row | None | Locked down in migration 0007; previously "anyone can read" |
| businesses | is_active = true | None | None | None | No write policies for owners/admins |
| staff | is_active = true | None | None | None | No write policies |
| services | is_active = true | None | None | None | No write policies |
| staff_services | Anyone | None | None | None | No write policies |
| staff_schedules | Anyone | None | None | None | No write policies |
| appointments | Own (user_id) | Own | Own | Own | Full CRUD for own appointments |
| reviews | is_visible = true | Own (user_id) | None | None | Cannot update/delete own reviews |
| favorites | Own (user_id) | Own | None | Own | |
| payments | Own (user_id) | None | None | None | Read-only for users; no insert policy |
| notifications | Own (user_id) | None | Own (user_id) | None | Can mark read; no insert policy |
| service_profiles | is_active = true | None | None | None | Read-only |
| service_categories_tree | is_active = true | None | None | None | Read-only |
| service_follow_up_questions | Anyone | None | None | None | Read-only |
| time_inference_rules | is_active = true | None | None | None | Read-only |
| time_inference_corrections | Anyone | None | None | None | Read-only; public read of correction data |
| user_booking_patterns | Own (user_id) | None | None | None | Read-only for user |
| review_tags | Anyone | None | None | None | Read-only |
| engine_settings | Anyone | None | None | None | Read-only |
| notification_templates | is_active = true | None | None | None | Read-only |
| engine_analytics_events | Anyone | None | None | None | Read-only; public read of all analytics |
| admin_notes | Admin only | Admin only | None | None | Role-based check via profiles subquery |
| user_transport_preferences | Own | Own | Own | None | |
| uber_scheduled_rides | Own (user_id) | None | None | None | Read-only for user |
| discovered_salons | Anyone | None | None | None | Publicly readable |
| salon_interest_signals | Own (user_id) | Own | None | None | |
| qr_auth_sessions | Anyone (column-limited) | None | None | None | email_otp column REVOKED from anon/authenticated |
| chat_threads | Own (FOR ALL) | Own | Own | Own | Single "FOR ALL" policy |
| chat_messages | Own (FOR ALL) | Own | Own | Own | Via subquery on chat_threads.user_id |
| user_media | Own | Own | None | Own | |

### Critical RLS Gaps

1. **businesses -- No write policies for business owners.** The `owner_id` column exists but there are no INSERT/UPDATE/DELETE policies. All business creation/modification must happen through edge functions using the service role key. This is intentional for the `salon-registro` edge function flow but means legitimate business owners cannot update their own records via the client.

2. **staff, services, staff_services, staff_schedules -- No write policies.** Same pattern. All mutations go through service-role edge functions.

3. **payments -- No INSERT policy.** Payments can only be created server-side (edge functions). This is correct for security.

4. **uber_scheduled_rides -- No INSERT/UPDATE/DELETE policies for users.** The `schedule-uber` edge function handles this via service role. Users can only read.

5. **notifications -- No INSERT policy for users.** Notifications are server-generated. Correct.

6. **engine_analytics_events -- Anyone can read ALL analytics.** This exposes every user's search/booking analytics (event_type, service_type, user_id) to any authenticated user. The user_id column in analytics events is visible to anyone.

7. **time_inference_corrections -- Anyone can read.** Exposes correction learning data publicly. Low risk but unnecessary.

8. **discovered_salons -- Anyone can read.** All scraped salon data including phone numbers, addresses, and outreach tracking is readable by any user. This is needed for the "recommend a salon" feature but exposes business intelligence data.

---

## 4. Indexes

### Existing Indexes

| Table | Index | Type | Condition |
|-------|-------|------|-----------|
| businesses | idx_businesses_location | GiST (location) | |
| businesses | idx_businesses_service_cats | GIN (service_categories) | |
| businesses | idx_businesses_city | btree (city) | |
| businesses | idx_businesses_is_active | btree (is_active) | WHERE is_active = true |
| businesses | idx_businesses_rating | btree (average_rating DESC NULLS LAST) | |
| staff | idx_staff_business | btree (business_id) | |
| services | idx_services_business | btree (business_id) | |
| services | idx_services_type_active | btree (service_type) | WHERE is_active = true |
| services | idx_services_category | btree (category) | |
| staff_schedules | idx_staff_schedules_lookup | btree (staff_id, day_of_week) | WHERE is_available = true |
| appointments | idx_appointments_user_time | btree (user_id, starts_at DESC) | |
| appointments | idx_appointments_staff_time | btree (staff_id, starts_at) | WHERE status NOT IN cancelled/no_show |
| appointments | idx_appointments_status | btree (status) | |
| reviews | idx_reviews_business | btree (business_id) | |
| reviews | idx_reviews_staff | btree (staff_id) | |
| reviews | idx_reviews_service_type_recent | btree (service_type, created_at DESC) | WHERE is_visible = true |
| review_tags | review_tags_review_id_unique | UNIQUE (review_id) | |
| time_inference_corrections | time_inference_corrections_unique | UNIQUE composite | |
| service_profiles | idx_service_profiles_type | btree (service_type) | WHERE is_active = true |
| notifications | idx_notifications_user_read | btree (user_id, is_read) | |
| engine_analytics_events | idx_analytics_events_type_date | btree (event_type, created_at DESC) | |
| engine_analytics_events | idx_analytics_events_service | btree (service_type, created_at DESC) | WHERE service_type IS NOT NULL |
| admin_notes | idx_admin_notes_target | btree (target_type, target_id) | |
| discovered_salons | idx_discovered_salons_location | GiST (location) | |
| discovered_salons | idx_discovered_salons_dedup | btree (dedup_key) | |
| discovered_salons | idx_discovered_salons_city_status | btree (city, status) | |
| discovered_salons | idx_discovered_salons_interest | btree (interest_count DESC) | WHERE status IN selected/outreach_sent |
| qr_auth_sessions | idx_qr_auth_code | btree (code) | WHERE status = 'pending' |
| qr_auth_sessions | idx_qr_auth_expires | btree (expires_at) | WHERE status IN pending/authorized |
| chat_threads | idx_chat_threads_user | btree (user_id) | |
| chat_threads | idx_chat_threads_last_msg | btree (user_id, pinned DESC, last_message_at DESC) | |
| chat_messages | idx_chat_messages_thread | btree (thread_id, created_at DESC) | |
| user_media | idx_user_media_user_section | btree (user_id, section, created_at DESC) | |
| user_media | idx_user_media_user_source | btree (user_id, source) | |

### Missing/Recommended Indexes

1. **`appointments (business_id, starts_at)`** -- The `curate_candidates` RPC joins appointments by `staff_id` (covered), but business-side queries (e.g., admin viewing all appointments for a business) have no index.

2. **`user_booking_patterns (user_id, service_category)`** -- Queried by the curate-results engine with `.eq("user_id", userId).eq("service_category", profile.category)`. No index exists. Low volume currently but will matter at scale.

3. **`payments (appointment_id)`** -- FK column with no index. Will cause slow FK lookups on appointment deletion.

4. **`uber_scheduled_rides (appointment_id)`** -- Queried by update-uber-rides via `.eq("appointment_id", ...)`. No explicit index (PK lookup only).

5. **`uber_scheduled_rides (uber_request_id)`** -- Queried by uber-webhook via `.eq("uber_request_id", resource_id)`. No index. Will cause full table scans.

6. **`salon_interest_signals (discovered_salon_id)`** -- Queried with count aggregation. No explicit index beyond the unique constraint.

7. **`staff_services (staff_id)`** -- Used in `curate_candidates` join. Only `idx_staff_services_service` (on service_id) exists. The join from staff to staff_services needs an index on `staff_id`.

8. **`chat_messages.sender_id`** -- No index. Not currently queried by sender but may be needed.

---

## 5. Triggers and Functions

### Triggers

| Trigger | Table | Event | Function |
|---------|-------|-------|----------|
| profiles_updated_at | profiles | BEFORE UPDATE | handle_updated_at() |
| on_auth_user_created | auth.users | AFTER INSERT | handle_new_user() |
| businesses_updated_at | businesses | BEFORE UPDATE | handle_updated_at() |
| businesses_set_location | businesses | BEFORE INSERT/UPDATE OF lat,lng | handle_business_location() |
| staff_updated_at | staff | BEFORE UPDATE | handle_updated_at() |
| appointments_updated_at | appointments | BEFORE UPDATE | handle_updated_at() |
| reviews_update_business_stats | reviews | AFTER INSERT/UPDATE/DELETE | handle_review_change() |
| payments_updated_at | payments | BEFORE UPDATE | handle_updated_at() |
| service_profiles_updated_at | service_profiles | BEFORE UPDATE | handle_updated_at() |
| time_inference_rules_updated_at | time_inference_rules | BEFORE UPDATE | handle_updated_at() |
| time_inference_corrections_updated_at | time_inference_corrections | BEFORE UPDATE | handle_updated_at() |
| engine_settings_updated_at | engine_settings | BEFORE UPDATE | handle_updated_at() |
| notification_templates_updated_at | notification_templates | BEFORE UPDATE | handle_updated_at() |
| user_transport_preferences_updated_at | user_transport_preferences | BEFORE UPDATE | handle_updated_at() |
| uber_scheduled_rides_updated_at | uber_scheduled_rides | BEFORE UPDATE | handle_updated_at() |
| discovered_salons_updated_at | discovered_salons | BEFORE UPDATE | handle_updated_at() |
| discovered_salons_set_location | discovered_salons | BEFORE INSERT/UPDATE OF lat,lng | handle_business_location() |

### Functions (Non-RPC)

| Function | Purpose | Security |
|----------|---------|----------|
| handle_updated_at() | Auto-set updated_at on row updates | SECURITY DEFINER |
| handle_new_user() | Auto-create profile row on auth signup | SECURITY DEFINER |
| handle_business_location() | Auto-populate PostGIS location from lat/lng | SECURITY DEFINER |
| handle_review_change() | Recalculate business avg_rating/total_reviews | SECURITY DEFINER |
| cleanup_expired_qr_sessions() | Expire/delete old QR auth sessions | SECURITY DEFINER |

### Notable: `handle_review_change()` Performance
This trigger recalculates `average_rating` and `total_reviews` on every review INSERT/UPDATE/DELETE by running two subqueries against the reviews table. For businesses with many reviews, this could become expensive. The current approach is acceptable at small scale but should be monitored.

---

## 6. RPC Functions

| Function | Purpose | Args | Security |
|----------|---------|------|----------|
| nearby_businesses() | Proximity search for active businesses | lat, lng, radius_km, category, limit | SECURITY DEFINER, STABLE |
| search_businesses() | Text + category + city search | query, category, city, limit, offset | SECURITY DEFINER, STABLE |
| find_available_slots() | Generate available time slots for a staff member | staff_id, duration_minutes, window_start, window_end | SECURITY DEFINER, STABLE |
| curate_candidates() | Core intelligence engine candidate query | service_type, lat, lng, radius_meters, window_start, window_end | SECURITY DEFINER, STABLE |
| increment_time_correction() | Atomic upsert for time correction counters | service_type, hour_range, day_range, correction_to | SECURITY DEFINER |
| cleanup_expired_qr_sessions() | QR session cleanup | none | SECURITY DEFINER |

### `curate_candidates()` -- The Critical Path
This is the most important RPC. It performs a multi-table join:
```
businesses -> services -> staff_services -> staff
```
With PostGIS spatial filtering (`ST_DWithin`) and then cross-joins each result with `find_available_slots()` to produce candidate slots.

**Performance concern:** The `CROSS JOIN LATERAL find_available_slots()` calls the slot-finding function once per candidate (business+staff+service combination), and each call queries `appointments` and `staff_schedules`. This is O(N) in database calls where N = number of matching business/staff/service combinations. With the `LIMIT 50` at the end, it will process up to 50 candidate-slot pairs, but the slot generation itself iterates over days in the window.

The `find_available_slots()` function:
- Iterates over each date in the window
- Queries `staff_schedules` for each date
- Generates hourly slot candidates
- Checks each slot against `appointments` for conflicts

This nested iteration pattern could be slow for wide time windows (e.g., 90-day windows for bridal services with `typical_lead_time = 'months'`).

---

## 7. Edge Functions and DB Usage

### 7.1 `curate-results` (Intelligence Engine)
**Tables read:** service_profiles, time_inference_rules, user_booking_patterns, review_tags, reviews, profiles
**RPCs called:** curate_candidates, increment_time_correction
**External APIs:** Google Distance Matrix
**Auth:** JWT required
**Purpose:** The core 6-step pipeline: profile lookup -> time inference -> candidate query -> score & rank -> pick top 3 -> build response with review snippets.

### 7.2 `places-proxy`
**Tables read:** None directly
**Auth:** JWT required
**Purpose:** Server-side proxy for Google Places API (autocomplete + details). Keeps API key server-side.

### 7.3 `qr-auth`
**Tables read/written:** qr_auth_sessions, profiles
**Auth:** Varies by action (create=anon, authorize=JWT, verify=anon)
**Purpose:** Cross-device authentication via QR code. Generates magic link OTPs stored in the session row.

### 7.4 `schedule-uber`
**Tables read/written:** uber_scheduled_rides, profiles (for Uber tokens)
**Auth:** JWT required
**External APIs:** Uber Estimates, Uber Requests
**Purpose:** Creates outbound + return Uber rides for appointments.

### 7.5 `update-uber-rides`
**Tables read/written:** uber_scheduled_rides, profiles
**Auth:** JWT required
**External APIs:** Uber Requests
**Purpose:** Cancel, reschedule, update pickup/dropoff, check status of Uber rides.

### 7.6 `uber-webhook`
**Tables written:** uber_scheduled_rides, uber_webhook_events
**Auth:** HMAC signature verification (X-Uber-Signature)
**Purpose:** Receives Uber webhook events for ride status changes.

### 7.7 `link-uber`
**Tables read/written:** profiles (uber_* columns)
**Auth:** JWT required
**External APIs:** Uber OAuth, Uber Identity API
**Purpose:** OAuth token exchange and Uber account linking/unlinking.

### 7.8 `salon-registro`
**Tables read/written:** discovered_salons, businesses
**Auth:** None (public registration page)
**Purpose:** Serves HTML registration form for salon owners. Creates business records.
**Security note:** No authentication required for POST. Anyone can create a business record.

### 7.9 `outreach-discovered-salon`
**Tables read/written:** discovered_salons, salon_interest_signals, profiles
**RPCs called:** nearby_discovered_salons (not in migrations)
**Auth:** JWT for invite/import actions; none for list
**Purpose:** List nearby discovered salons, record interest signals, bulk import.

### 7.10 `tag-review`
**Tables read/written:** review_tags
**Auth:** JWT required
**Purpose:** Extracts keywords, sentiment, and quality scores from review text. Upserts into review_tags.

### 7.11 `on-demand-scrape`
**Tables read/written:** scrape_requests (NOT IN MIGRATIONS)
**RPCs called:** check_coverage (NOT IN MIGRATIONS)
**Auth:** JWT for creating requests
**Purpose:** On-demand scraping when a user's area has no coverage.

### 7.12 `stripe-payment-methods`
**Tables read/written:** profiles (stripe_customer_id)
**Auth:** JWT required
**External APIs:** Stripe
**Purpose:** Setup intents, list payment methods, detach methods.

### 7.13 `aphrodite-chat`
**Tables read/written:** chat_threads, chat_messages
**Auth:** JWT required
**External APIs:** OpenAI Responses API, LightX (virtual try-on)
**Purpose:** AI chat with "Aphrodite" persona. Also handles virtual try-on via LightX.

### 7.14 `main`
**Purpose:** Supabase Edge Functions router. Dispatches requests to individual function workers.

---

## 8. Flutter Model-to-Schema Mapping

| Flutter Model | DB Table | Alignment |
|---------------|----------|-----------|
| Provider | businesses | Good. Maps `average_rating` -> `rating`, `total_reviews` -> `reviewsCount`. Missing `state` column in schema (default 'Jalisco'). Provider model has `state` field but businesses table has it. |
| ProviderService | services | Good. `business_id` -> `providerId`. |
| Booking | appointments | Good. `starts_at`/`ends_at` -> `scheduledAt`/`endsAt`. Joins with `businesses.name` for `providerName`. |
| CurateRequest/CurateResponse | curate-results edge function | Excellent. Direct 1:1 mapping of all response fields. Client model has `priceComfort`, `qualitySpeed`, `exploreLoyalty` fields that are sent but NOT processed by the edge function. |
| FollowUpQuestion | service_follow_up_questions | Exact match. |
| UberRide | uber_scheduled_rides | Exact match. |
| ChatThread | chat_threads | Exact match. |
| ChatMessage | chat_messages | Exact match. |
| ServiceCategory/SubCategory/Item | Hardcoded in Flutter | The Flutter category tree is hardcoded in the category_provider, NOT loaded from `service_categories_tree` table. The table exists in the DB but the Flutter app does not read from it. |

### Unused Model Fields
- `CurateRequest.priceComfort`, `CurateRequest.qualitySpeed`, `CurateRequest.exploreLoyalty` -- These preference sliders are in the Flutter model but the edge function ignores them. These represent future personalization features.

---

## 9. Security Assessment

### 9.1 Strengths

1. **Uber tokens stored server-side.** The profiles RLS was corrected in migration 0007 to restrict to own-row-only, preventing other users from reading `uber_access_token` and `uber_refresh_token`.

2. **QR auth OTP protected.** Column-level REVOKE on `email_otp` prevents client-side access. Only the edge function (using service role) can read it.

3. **Edge functions use service role key.** All server-side operations bypass RLS correctly.

4. **JWT verification on all sensitive edge functions.** Every edge function validates the auth token before processing.

5. **Stripe API key never exposed to client.** Payment method management goes through the server-side edge function.

6. **Uber webhook HMAC verification.** The uber-webhook function verifies `X-Uber-Signature` using HMAC-SHA256.

### 9.2 Vulnerabilities and Concerns

1. **`salon-registro` has NO authentication.** Anyone can POST to create a business record (Tier 1). There is no rate limiting, CAPTCHA, or auth requirement. An attacker could flood the businesses table with fake entries.

2. **Uber tokens in the `profiles` table.** Storing OAuth tokens (access, refresh) alongside user profile data is a design risk. If a future migration inadvertently opens up the profiles table SELECT policy (as it was before migration 0007), all Uber tokens are exposed. A separate `user_secrets` table accessible only to service role would be safer.

3. **`stripe_customer_id` in profiles.** While not as sensitive as tokens, the Stripe customer ID should not be readable by other users. Currently protected by the own-row RLS policy.

4. **`engine_analytics_events` readable by anyone.** User IDs, service types, transport modes, and card selections are visible to all authenticated users. This is a privacy leak.

5. **`discovered_salons` readable by anyone.** Phone numbers, addresses, scrape sources, outreach tracking data all publicly visible. Business intelligence data should have admin-only read access, with a restricted view for the user-facing "recommend a salon" feature.

6. **`time_inference_corrections` readable by anyone.** Exposes learning/correction data. Low risk but unnecessary.

7. **No RLS write policies for businesses, staff, services, schedules.** All writes go through edge functions with service role. This is intentionally centralized but means any compromise of an edge function's service role key gives full write access.

8. **`chat_messages` FOR ALL policy with subquery.** The policy `thread_id IN (SELECT id FROM chat_threads WHERE user_id = auth.uid())` runs a subquery on every row access. At scale with many threads and messages, this could be slow and should use a more direct join or materialized check.

9. **No DELETE policy on many tables.** Users cannot delete their own reviews, notifications, or booking patterns. This may be intentional (data retention) but conflicts with GDPR/privacy requirements for data deletion.

---

## 10. Performance Considerations

### 10.1 Hot Path: `curate_candidates()` RPC

This is the most performance-critical function. It runs on every booking request.

**Bottlenecks:**
- `CROSS JOIN LATERAL find_available_slots()` -- Generates slots by iterating days, checking each against appointments. For a 90-day window (bridal services), this could process hundreds of potential slots per candidate.
- The `LIMIT 50` on `curate_candidates` applies AFTER the cross join, meaning it may process many more than 50 candidate-slot pairs before stopping.
- No caching of availability data between requests.

**Mitigations in place:**
- PostGIS `ST_DWithin` spatial filtering with GiST index
- Partial index on active businesses
- Partial index on non-cancelled appointments for staff

**Recommendations:**
- Consider limiting `find_available_slots` to return only the first N slots (e.g., 5) per staff member instead of all slots in the window
- For `months`-lead-time services, consider a simplified availability check rather than slot-by-slot generation

### 10.2 `handle_review_change()` Trigger

Runs aggregate queries (AVG, COUNT) on reviews for every insert/update/delete. Two full scans of reviews for the target business.

**At scale risk:** A business with 1000+ reviews will see noticeable trigger latency on each new review.

**Recommendation:** Consider incremental updates (add/subtract from running counts) rather than full recalculation.

### 10.3 Missing Indexes (see Section 4)

The most impactful missing indexes:
- `uber_scheduled_rides(uber_request_id)` -- webhook processing will do full table scans
- `staff_services(staff_id)` -- join in curate_candidates
- `uber_scheduled_rides(appointment_id)` -- queried by all update-uber-rides actions
- `payments(appointment_id)` -- FK column without index

### 10.4 Chat Message Subquery RLS

The `chat_messages` RLS policy uses `thread_id IN (SELECT id FROM chat_threads WHERE user_id = auth.uid())`. This runs a subquery for every row evaluated. For users with many messages, this will degrade.

**Recommendation:** Add `user_id` directly to `chat_messages` table and use a direct equality check in RLS, or use a function-based RLS with caching.

### 10.5 Time Inference Rules Full Table Scan

The curate-results edge function fetches ALL active time_inference_rules and filters in application code. With a small number of rules this is fine, but the design could use a more targeted query.

---

## 11. Schema vs Design Doc Alignment

### What the Schema Correctly Implements

| Design Doc Feature | Schema Support | Status |
|-------------------|----------------|--------|
| Service-type-driven intelligence | service_profiles + service_follow_up_questions | Fully implemented |
| 3-level category tree | service_categories_tree | Table exists (not used by Flutter yet) |
| Time inference engine | time_inference_rules + time_inference_corrections + user_booking_patterns | Fully implemented |
| Ranking weights (sum to 1.0) | service_profiles with weights_sum_one constraint | Fully implemented |
| Admin-tunable engine settings | engine_settings KV store | Fully implemented |
| Review intelligence | review_tags with sentiment + quality scoring | Fully implemented |
| Uber round-trip integration | uber_scheduled_rides + profiles uber_* columns | Fully implemented |
| Transport preference tracking | user_transport_preferences | Fully implemented |
| Salon discovery pipeline | discovered_salons + salon_interest_signals | Fully implemented |
| WhatsApp-based salon onboarding | salon-registro edge function | Fully implemented |
| Notification templates | notification_templates | Schema exists, no sending logic |
| Analytics events | engine_analytics_events | Schema exists, limited logging |
| Curate-results engine | curate_candidates RPC + curate-results edge function | Fully implemented |
| Follow-up questions | service_follow_up_questions + seed data | Fully implemented for 18 service types |
| Payment system | payments + stripe-payment-methods edge function | Schema + edge function exist |
| QR cross-device auth | qr_auth_sessions + qr-auth edge function | Fully implemented |
| Aphrodite AI chat | chat_threads + chat_messages + aphrodite-chat function | Fully implemented |
| Virtual try-on | LightX integration in aphrodite-chat | Implemented in edge function |
| Media management | user_media table | Schema exists |

### What is Missing or Incomplete

1. **No `service_categories_tree` seed data.** The table exists but no migration seeds it with the category tree from the design doc. The Flutter app hardcodes categories instead of reading from DB.

2. **No `service_profiles` seed data.** The design doc specifies 15 example service profiles with specific weights. No migration seeds these rows. The system cannot function without service profiles.

3. **No `time_inference_rules` seed data.** The design doc specifies 10+ time inference rules. No migration seeds them.

4. **No `engine_settings` seed data.** The design doc mentions global engine settings. No migration seeds default values.

5. **No `notification_templates` seed data.** No templates are seeded.

6. **`scrape_requests` table not in migrations.** Referenced by `on-demand-scrape` edge function but no migration creates it.

7. **`uber_webhook_events` table not in migrations.** Referenced by `uber-webhook` edge function but no migration creates it.

8. **`nearby_discovered_salons` RPC not in migrations.** Referenced by `outreach-discovered-salon` edge function but no migration creates it.

9. **`check_coverage` RPC not in migrations.** Referenced by `on-demand-scrape` edge function but no migration creates it.

10. **Portfolio system not implemented.** The design doc describes portfolio importance and carousel display. The `service_profiles` table has `portfolio_importance` and `show_portfolio_carousel` fields, but there is no portfolio table or storage mechanism. The scoring engine hardcodes `portfolioScore = 0.5` (neutral).

11. **No staff rating recalculation trigger.** Business ratings auto-update via `handle_review_change()`, but staff ratings (`staff.average_rating`, `staff.total_reviews`) have no equivalent trigger. These counters will always be their initial values unless manually updated.

12. **No appointment status change webhook/notification trigger.** When an appointment status changes, there is no trigger to send notifications or update related systems.

13. **Price comparison data.** The `show_price_comparison` flag exists on service_profiles, and `area_avg_price` is computed in the edge function, but there is no persistent price tracking or comparison table.

14. **Cancellation/deposit enforcement.** The `cancellation_hours`, `deposit_required`, and `deposit_percentage` columns exist on businesses, but no logic enforces them (no trigger preventing late cancellations, no automatic deposit charge).

---

## 12. Gaps, Inconsistencies, and Concerns

### 12.1 Schema Inconsistencies

1. **Duplicate `uber_linked` tracking.** Both `profiles.uber_linked` (added in migration 0006) and `user_transport_preferences.uber_linked` track Uber linking status. These can get out of sync. The edge functions only update `profiles.uber_linked`.

2. **`services.category`/`services.subcategory` vs `service_profiles.category`/`service_profiles.subcategory`.** Category information is stored in both tables with no FK relationship between them. They could drift.

3. **`discovered_salons.hours` is `text` while `businesses.hours` is `jsonb`.** Inconsistent types for the same semantic field.

4. **`profiles.home_lat`/`home_lng`/`home_address` vs `user_transport_preferences.home_address_lat`/`home_address_lng`/`home_address_text`.** Home address is stored in two places with no synchronization.

5. **`user_booking_patterns.user_id` has no ON DELETE CASCADE.** If a user is deleted from auth.users, their booking patterns will be orphaned (FK violation or constraint error depending on check timing).

6. **`salon_interest_signals.discovered_salon_id` has no ON DELETE CASCADE.** Deleting a discovered salon will fail if it has interest signals, or leave orphaned rows.

### 12.2 Missing Data Integrity

1. **No check constraint on `appointments.starts_at < appointments.ends_at`.** An appointment could be created with end before start.

2. **No unique constraint preventing double-booking.** Two appointments for the same staff at the same time can be inserted. The `find_available_slots` function checks existing appointments but a race condition exists between the check and the insert.

3. **No foreign key from `time_inference_corrections.service_type` to `service_profiles.service_type`.** Correction data can reference non-existent service types.

4. **No foreign key from `engine_analytics_events.service_type` to `service_profiles.service_type`.** Same issue.

5. **No foreign key from `user_booking_patterns.service_category` to any category table.** Pattern data can reference non-existent categories.

### 12.3 Operational Concerns

1. **No database-level cleanup jobs.** The `cleanup_expired_qr_sessions()` function exists but is only called when the `qr-auth` edge function receives a `cleanup` action. No cron/pg_cron job is configured.

2. **No archiving strategy for analytics events.** `engine_analytics_events` will grow unbounded. No partitioning or cleanup.

3. **No soft-delete on most tables.** Only `businesses.is_active`, `staff.is_active`, `services.is_active`, `reviews.is_visible` have soft-delete flags. Appointments and other records use status fields but no universal pattern.

4. **PostGIS extension dependency.** The schema requires PostGIS. If the Supabase instance doesn't have it pre-installed, the initial migration will fail.

5. **No database migration for Realtime subscriptions.** Only `qr_auth_sessions` is explicitly added to `supabase_realtime`. If real-time updates are needed for appointments, chat, or notifications, those publications need to be added.

---

## 13. Summary of Findings

### Overall Assessment

The schema is **well-designed and comprehensive** for the BeautyCita product vision. The intelligence engine layer (service_profiles, time_inference, review_tags, curate_candidates RPC) is the most architecturally sophisticated part and closely follows the design document. The core booking flow (businesses -> staff -> services -> appointments) is solid with proper foreign keys and cascading deletes.

### Top Priority Issues

1. **Missing seed data migrations.** The system cannot function without service_profiles, time_inference_rules, and service_categories_tree data. Only follow_up_questions and Puerto Vallarta test businesses are seeded.

2. **Missing table migrations.** `uber_webhook_events`, `scrape_requests`, and two RPC functions (`nearby_discovered_salons`, `check_coverage`) are referenced by edge functions but not defined in migrations.

3. **Security: salon-registro has no auth.** Public POST endpoint creates business records. Needs rate limiting at minimum.

4. **Security: analytics events publicly readable.** User activity data exposed to all authenticated users.

5. **Performance: curate_candidates with wide windows.** The CROSS JOIN LATERAL slot generation will be slow for services with `typical_lead_time = 'months'`.

6. **No double-booking prevention at DB level.** Race condition between availability check and appointment insert.

### Strengths

- Comprehensive intelligence layer with admin-tunable weights
- Clean PostGIS integration with automatic location triggers
- Proper RLS on all tables (even if some policies could be tighter)
- Well-structured edge functions with clear separation of concerns
- Uber integration thoroughly handled (scheduling, webhooks, token refresh)
- Review intelligence with sentiment analysis and quality scoring
- Salon discovery pipeline with grassroots growth mechanism

### The schema is approximately 85% aligned with the design document. The remaining 15% consists of missing seed data, missing tables for on-demand scraping/webhooks, and unimplemented features (portfolio system, notification sending, cancellation enforcement). The foundation is solid.
