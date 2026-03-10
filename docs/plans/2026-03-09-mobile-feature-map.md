# BeautyCita Mobile App — Complete Feature Map

> Generated 2026-03-09 from full codebase scan. Objective inventory of what exists and works.

---

## 1. INTELLIGENT BOOKING ENGINE (Core Product)

### 1.1 Service Selection
- **Category grid** on home screen — 8 categories with emoji icons, color-coded
- **Subcategory sheets** — drill into 40+ subcategories, 100+ service items
- Categories: Unas (14 items), Cabello (24), Pestanas y Cejas (14), Maquillaje (7 subcats), Facial (3+6 subcats), Cuerpo y Spa (17), Cuidado Especializado (4 subcats), Barberia (4 items)
- Each service item maps to a `service_type` in `service_profiles` DB table
- **Files:** `home_screen.dart`, `subcategory_sheet.dart`, `data/categories.dart`

### 1.2 Follow-Up Questions
- Service-type-specific dynamic questions (e.g., lash style preference, hair length)
- Fetched from DB per service profile, rendered as visual cards
- Answers feed into ranking weights
- **Files:** `follow_up_question_screen.dart`, `services/follow_up_service.dart`

### 1.3 Time Inference
- **No calendar picker** — engine infers when user wants appointment
- Rules-based: current hour + day of week + service lead time → booking window
- User correction: "Today / Tomorrow / This Week / Next Week" + "Morning / Afternoon / Evening"
- Corrections logged to improve future inference
- Returning-user pattern blending (from `user_booking_patterns`)
- **Files:** `time_override_sheet.dart`, edge function `curate-results` (steps 2+)

### 1.4 Curate Engine (6-Step Pipeline)
1. Profile lookup — service-specific weights, radius, lead time
2. Time inference — predict ideal booking window
3. Candidate query — PostGIS radius search + auto-expansion (1.5x → 3x)
4. Discovered salon fallback — fill gaps with scraped salons (WhatsApp contact)
5. Score & rank — weighted: proximity, availability, rating (Bayesian), price, portfolio
6. Build response — review snippets, badges, transport data
- Google Distance Matrix for real transport times (car/transit)
- Target: 200-400ms total
- **Files:** `services/curate_service.dart`, edge function `curate-results`
- **Feature toggles:** `enable_instant_booking`, `enable_time_inference`

### 1.5 Result Cards
- Top 3 curated results as swipeable cards
- Each card: salon photo, staff name, rating, price, slot time, transport duration, review snippet
- Badges: `available_today`, `walk_in_ok`, `new_on_platform`, `instant_confirm`
- Discovered salon cards: Google data + WhatsApp contact CTA
- Swipe right = next, swipe left = previous, tap = confirm
- **Files:** `result_cards_screen.dart`

### 1.6 No-Results Fallback
- When < 3 results: shows discovered salons from Google Maps scrape data
- WhatsApp-themed invite UI — user can invite salon to join BeautyCita
- Interest signals tracked, escalating outreach triggered (1 → 3 → 5 → 10 → 20 invites)
- Identity gate: user must have verified phone or email to invite
- Rate limits: 10 invites/day, 30s cooldown between invites
- **Files:** `result_cards_screen.dart` (_NoResultsWithNearbySalons), `invite_salon_screen.dart`, edge function `outreach-discovered-salon`

### 1.7 Transport Selection
- Asked every booking: Car / Uber / Public Transit
- Uber mode: schedules round-trip rides automatically via Uber API
- Route map widget: OpenStreetMap polyline overlay with duration/distance
- **Files:** `transport_selection.dart`, `widgets/route_map_widget.dart`, `services/uber_service.dart`
- **Edge functions:** `link-uber`, `schedule-uber`, `update-uber-rides`, `uber-webhook`

### 1.8 Booking Confirmation & Payment
- Payment methods: Stripe card, OXXO cash, Bitcoin (BTCPay)
- Stripe PaymentSheet integration with saved cards
- 3% platform commission, optional deposit-only
- Tax withholding: ISR + IVA per Mexican LISR/LIVA (RFC'd vs unregistered rates)
- Email verification gate post-payment
- Multi-channel receipt: push + WhatsApp + email
- **Files:** `confirmation_screen.dart`, `email_verification_screen.dart`
- **Edge functions:** `create-payment-intent`, `btcpay-invoice`, `stripe-webhook`, `btcpay-webhook`, `booking-confirmation`

---

## 2. CITA EXPRESS (Walk-In Booking)

- QR code scan → instant service select → real-time slot search → one-tap book
- Bypasses curation engine, uses direct `find_available_slots` RPC
- If no slots today, suggests nearby salons with availability
- **Files:** `cita_express_screen.dart`, `qr_scan_screen.dart`, `providers/cita_express_provider.dart`
- **Feature toggle:** `enable_cita_express`

---

## 3. INSPIRATION FEED

### 3.1 Video Tab
- YouTube Shorts webviews, one per category (9 total), pre-loaded for instant switching
- Category chips: Todo, Cabello, Unas, Pestanas, Cejas, Maquillaje, Facial, Corporal, Novias
- Hashtag mapping per category (e.g., cabello → #hairtransformation)
- Top 50px clipped to hide YouTube branding
- IndexedStack for zero-flash tab switching
- **Files:** `screens/feed/feed_screen.dart` (_VideoFeedTab)

### 3.2 Photos Tab
- Portfolio feed from registered salons (product showcases, before/after)
- Category filter chips, infinite scroll with pagination
- Save/bookmark functionality
- **Currently empty** — depends on salon portfolio uploads and POS products
- **Files:** `screens/feed/feed_screen.dart` (_PhotosFeedTab), `screens/feed/feed_card.dart`
- **Edge function:** `feed-public`
- **Feature toggle:** `enable_feed`

---

## 4. CHAT SYSTEM

### 4.1 Aphrodite (Beauty AI Advisor)
- GPT-4o powered beauty consultant
- Virtual try-on requests (hair color, hairstyle, headshot, face swap via LightX API)
- Copy generation for staff bios, service descriptions (gpt-4o-mini)
- **Files:** `services/aphrodite_service.dart`, `services/lightx_service.dart`
- **Edge function:** `aphrodite-chat`

### 4.2 Eros (Customer Support AI)
- GPT-4o-mini powered support agent ("Aphrodite's son")
- Handles common questions, escalates to human
- **Edge function:** `eros-chat`

### 4.3 Salon Chat
- Direct messaging between customer and salon
- Real-time via Supabase Realtime subscriptions
- **Edge function:** `salon-chat`

### 4.4 Support Chat
- Human customer support channel
- **Edge function:** `support-chat`

### 4.5 Chat Infrastructure
- Thread-based: pinned threads, unread counts, real-time streaming
- Media sharing in chat (images from camera, gallery, or media library)
- **Files:** `chat_list_screen.dart`, `chat_conversation_screen.dart`, `chat_router_screen.dart`, `providers/chat_provider.dart`
- **Feature toggle:** `enable_chat`

---

## 5. VIRTUAL STUDIO

- Hair color try-on, hairstyle try-on, professional headshot, face swap
- LightX API via aphrodite-chat edge function
- Results saved to personal media library
- Share, save to gallery, delete
- **Files:** `virtual_studio_screen.dart`, `services/lightx_service.dart`, `services/media_service.dart`
- **Feature toggle:** `enable_virtual_studio`

---

## 6. USER PROFILE & SETTINGS

### 6.1 Profile
- Name, username (auto-generated cutesy names), avatar, birthday, gender
- Phone verification via OTP (edge function `phone-verify`)
- Discovered salon match detection on phone verify
- **Files:** `profile_screen.dart`, `providers/profile_provider.dart`

### 6.2 Security
- Biometric auth (fingerprint/face), Google OAuth linking, email/password
- TOTP 2FA for Bitcoin wallet
- **Files:** `security_screen.dart`, `providers/security_provider.dart`, `services/biometric_service.dart`

### 6.3 Payment Methods
- Stripe saved cards (list, add via SetupIntent, delete)
- **Files:** `payment_methods_screen.dart`, `providers/payment_methods_provider.dart`
- **Edge function:** `stripe-payment-methods`

### 6.4 Bitcoin Wallet
- BTCPay Server integration, deposit address generation
- TOTP 2FA required for withdrawals
- Balance tracking (USD/MXN conversion), deposit history
- **Files:** `btc_wallet_screen.dart`, `services/btcpay_service.dart`
- **Edge function:** `btc-wallet`
- **Feature toggle:** `enable_btc_payments`

### 6.5 Preferences
- Default transport mode, notification toggles
- Search radius, price comfort, quality vs speed, explore vs loyalty sliders
- **Files:** `preferences_screen.dart`, `providers/user_preferences_provider.dart`

### 6.6 My Bookings
- Appointment history list with status badges
- Upcoming bookings, past bookings
- **Files:** `my_bookings_screen.dart`, `booking_detail_screen.dart`

### 6.7 Device Manager
- Connected devices management
- **Files:** `device_manager_screen.dart`

### 6.8 Media Library
- All virtual try-on results, chat media, uploaded photos
- Full-screen viewer with carousel, share, delete, save to gallery
- **Files:** `media_manager_screen.dart`, `widgets/media_viewer.dart`, `services/media_service.dart`

---

## 7. BUSINESS MANAGEMENT (Salon Owner Panel)

**Access:** Left-edge gesture exclusion zone on home screen → `/business`

### 7.1 Dashboard
- Today/week/month KPIs: bookings, revenue, average rating
- Quick stats, daily breakdown chart
- **Files:** `business/business_dashboard_screen.dart`

### 7.2 Calendar
- Appointment calendar with drag-and-drop rescheduling
- Staff switching with auto-alerts to client
- Schedule blocks (lunch, breaks, time-off)
- External calendar sync (Google Calendar, ICS import/export)
- **Files:** `business/business_calendar_screen.dart`
- **Edge functions:** `calendar-ics`, `google-calendar-connect`, `google-calendar-sync`, `reschedule-notification`

### 7.3 Services Management
- Add/edit/remove service offerings
- Price, duration, staff assignment
- **Files:** `business/business_services_screen.dart`

### 7.4 Staff Management
- Add/remove staff, set schedules, assign services
- Staff analytics: productivity metrics (week/month)
- **Files:** `business/business_staff_screen.dart`, `business/business_staff_analytics_screen.dart`

### 7.5 Walk-In QR
- Generate/display QR code for Cita Express walk-in booking
- **Files:** `business/business_qr_screen.dart`

### 7.6 Disputes
- Customer dispute management and resolution
- **Files:** `business/business_disputes_screen.dart`
- **Feature toggle:** `enable_disputes`

### 7.7 Payments & Revenue
- Revenue tracking, payout history
- Stripe Connect onboarding for payouts
- **Files:** `business/business_payments_screen.dart`
- **Edge function:** `stripe-connect-onboard`

### 7.8 POS / Marketplace
- Product catalog management (add, edit, pricing, images)
- Order management (received orders, status updates)
- Requires seller agreement acceptance before enabling
- 10% commission on product sales
- **Files:** `business/pos_management_screen.dart`, `business/orders_screen.dart`, `business/pos_agreement_dialog.dart`
- **Edge function:** `create-product-payment`
- **Feature toggle:** `enable_pos`

### 7.9 Business Settings
- Business info, hours, location
- **Files:** `business/business_settings_screen.dart`

---

## 8. ADMIN PANEL

**Access:** Right-edge gesture exclusion zone on home screen → `/admin`

### 8.1 Dashboard — System KPIs, user counts, revenue
### 8.2 Users — User management, roles, bans
### 8.3 Applications — New salon/RP applications
### 8.4 Bookings — All bookings, search, filtering
### 8.5 Disputes — Complaints, refunds (`process-dispute-refund`)
### 8.6 Salons — Salon management, verification, suspend/hold (`suspend-salon`)
### 8.7 Analytics — Usage, retention, engagement metrics
### 8.8 Reviews — Moderation, abuse flags (`tag-review`)
### 8.9 Pipeline — RP pipeline, lead tracking, outreach log
### 8.10 Chat — Multi-user chat management
### 8.11 Tax Reports (SAT) — ISR/IVA withholding, compliance (`sat-access`, `sat-reporting`)
### 8.12 Finance Dashboard — Revenue, commissions, reconciliation
### 8.13 Operations — System health, error logs

**Superadmin-only (Motor + Sistema):**
### 8.14 Service Profile Editor — Ranking weights, search radius per service type
### 8.15 Engine Settings — Global booking engine parameters
### 8.16 Category Tree — Category/subcategory hierarchy management
### 8.17 Time Rules — Booking time inference rules
### 8.18 Notification Templates — SMS/push template management
### 8.19 Feature Toggles — 20 toggles across 6 groups

**Files:** `screens/admin/*.dart` (24 files)

---

## 9. RELATIONSHIP PROFESSIONAL (RP) PANEL

- Map view with assigned salon pins (color-coded by status)
- List view with status + interest tracking
- Geo-fence: must be within 300km of assigned zone
- Status flow: assigned → visited → onboarding_complete
- **Files:** `screens/rp/rp_shell_screen.dart`

---

## 10. NOTIFICATIONS

- Firebase Cloud Messaging (FCM) with custom Android channel
- Custom notification sound: `beautycita_notify`
- Custom vibration: attention pulse + confirm pulse
- Booking reminders: hourly cron, 2hrs before appointment
- Multi-channel receipts: push + WhatsApp + email
- Reschedule alerts to clients on drag-and-drop calendar changes
- Order follow-up: day 3 (reminder) → day 7 (warning) → day 14 (auto-refund)
- **Files:** `services/notification_service.dart`
- **Edge functions:** `send-push-notification`, `booking-reminder`, `booking-confirmation`, `reschedule-notification`, `order-followup`
- **Feature toggle:** `enable_push_notifications`

---

## 11. SALON ONBOARDING

- 60-second registration via WhatsApp invite link
- Multi-step HTML form: info → OTP → confirm → success
- HMAC-based secure token, WhatsApp OTP delivery
- Discovered salon → registered business flow
- **Edge function:** `salon-registro`
- **Growth:** "Recomienda tu salon" sends WhatsApp invite

---

## 12. OTA UPDATE SYSTEM

### Tier 1: Shorebird Code Push
- Silent Dart-only patches, applies on next cold start
- No user interaction required

### Tier 2: Full APK Binary
- Checks `version.json` on R2
- Required updates: forced prompt, no dismiss
- Optional updates: dismissible with 24h cooldown
- **Files:** `services/updater_service.dart`

---

## 13. DATA EXPORT

- Formats: CSV, Excel (Syncfusion), JSON, PDF, vCard
- Grouped worksheets in Excel, paginated PDF tables
- Native share sheet for output
- **Files:** `services/export_service.dart`

---

## 14. SECURITY FEATURES

- Biometric-only registration (no password required)
- Screenshot detection (Android native MethodChannel)
- Screenshot sending to admin for audit
- Gesture exclusion zones (prevents accidental navigation)
- TOTP 2FA for Bitcoin wallet operations
- Google RISC integration (compromised account protection)
- **Files:** `services/screenshot_detector_service.dart`, `services/screenshot_sender_service.dart`, `services/gesture_exclusion_service.dart`

---

## 15. FEATURE TOGGLES (20 Total)

| Group | Toggle | Controls |
|-------|--------|----------|
| **Payments** | `enable_stripe_payments` | Stripe card/OXXO |
| | `enable_btc_payments` | Bitcoin wallet + BTCPay |
| **Booking** | `enable_instant_booking` | Curate engine |
| | `enable_time_inference` | Time prediction |
| | `enable_cita_express` | Walk-in QR booking |
| **Social** | `enable_feed` | Inspiration feed tab |
| | `enable_chat` | Chat system |
| | `enable_disputes` | Dispute filing |
| **Experimental** | `enable_virtual_studio` | AI try-on studio |
| | `enable_push_notifications` | FCM push |
| **Platform** | `enable_pos` | Product marketplace |
| | `enable_uber_integration` | Uber scheduling |
| | `enable_google_calendar_sync` | Calendar sync |
| **Server-side** | Various | Edge function gates |

**Enforcement:** Client-side only (UI hides/shows). Server-side enforcement exists only in `curate-results`, `create-payment-intent`, `btcpay-invoice`, `feed-public`.

---

## 16. EXTERNAL INTEGRATIONS

| Service | Purpose | Status |
|---------|---------|--------|
| **Supabase** | Auth, DB, edge functions, storage, realtime | Active |
| **Stripe** | Payments, Connect, saved cards | Active |
| **BTCPay Server** | Bitcoin invoices, wallet | Active |
| **Google Maps** | Distance Matrix, Places autocomplete | Active |
| **Google Calendar** | Sync, OAuth | Active |
| **Google OAuth** | Sign-in, RISC | Active |
| **Firebase** | FCM push notifications | Active |
| **OpenAI** | GPT-4o (Aphrodite), GPT-4o-mini (Eros, copy gen) | Active |
| **LightX** | Virtual try-on (hair, headshot, face swap) | Active |
| **Uber** | Ride scheduling, OAuth, webhooks | Active |
| **IONOS SMTP** | Branded emails | Active |
| **beautypi WA API** | WhatsApp messaging (outreach, OTP, receipts) | Active |
| **Shorebird** | OTA code push | Active |
| **Cloudflare R2** | APK hosting, media | Active |

---

## BROKEN / TODO

> Items found during scan that need attention. Not exhaustive — just what the scan surfaced.

1. **Photos feed tab empty** — depends on salon portfolio uploads + POS products (no registered salons with content yet)
2. **Server-side toggle enforcement gaps** — most edge functions don't check toggles; only curate-results, create-payment-intent, btcpay-invoice, feed-public do
3. **Error reporting is manual only** — `user_error_reports` table has 0 rows; requires user to tap "Report" button; no automatic error capture
4. **Edge function errors** (from logs): `product_showcases` missing `businesses.slug` column; `portfolio_photos` missing relationship to `businesses`
5. **WA enrichment on beautypi** — was broken (Unauthorized), re-paired 2026-03-09, monitor stability
6. **Subcategory service_type gaps** — several subcategories have no `items` array (Nail Art, Cambio Esmalte, Reparacion, Relleno, Retiro under nails; Combo under lashes; all 7 Maquillaje subcats; 6 Facial subcats; 4 Specialized subcats; 2 Barberia subcats). These go through booking flow but may not map to service_profiles.
7. **ReviewSnippet.rating type mismatch** — FIXED 2026-03-09 (was `int?`, now `double?`; Shorebird patch 7 deployed)
8. **Category ID mismatch** — FIXED 2026-03-09 (matched_categories English→Spanish migration applied)
