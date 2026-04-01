# BeautyCita — Release History

**BEAUTYCITA, S.A. de C.V.** | RFC: BEA260313MI8
beautycita.com | Puerto Vallarta, Jalisco

---

## v1.1.1 — Production Ready (March 2026)

### Financial System
- Complete payment processing: Stripe Connect, saldo, OXXO, cash walk-ins
- 3% platform commission on every transaction with full audit trail
- Tax withholding compliance: ISR 2.5% + IVA 8% per LISR Art. 113-A / LIVA Art. 18-J
- SAT real-time access API (CFF Art. 30-B) with HMAC-SHA256 authentication
- Automated SAT monthly reports + platform declarations
- Debt collection system: 50% cap per service, FIFO, deducted at Stripe payment time
- Saldo auto-apply: user credits used automatically before card charges
- Cancellation policy enforcement with deposit forfeiture rules
- Refund-to-saldo on all cancel paths (customer, business, admin, Stripe refund)

### Business Panel (14 tabs)
- Full dashboard with real-time revenue, tax breakdown (BC-withheld vs salon obligation), commission tracking, CFDI history, expense management
- Calendar with day/week/month views, drag reschedule, walk-in registration
- CRM: auto-populated client database with visit history, loyalty points, tags, notes
- Staff management: 5 positions (owner/manager/receptionist/stylist/assistant), commission rates, QR portfolio upload
- Marketing automation: 5 trigger types, configurable templates and channels
- Gift cards: Stripe-backed online + salon-issued physical/virtual
- Loyalty program: earn points on bookings, redeem for saldo credit
- Service revenue breakdown with trend charts
- Holiday/closure management integrated with booking engine
- Search, sort, date filters, CSV export on all screens

### Admin Panel (12 consolidated tabs)
- Executive Dashboard combining Finance + Operations + Analytics
- Trend charts: 30-day booking and revenue visualizations
- All list items tappable with full detail sheets
- Applications integrated into Salons workflow
- Engine configuration: service profiles, global settings, category tree, time rules

### Booking Engine
- 6-step intelligent curation pipeline
- Bell-curve time preference weighting (morning/afternoon/evening)
- Business hours enforcement + holiday closure respect
- Position-based staff filtering (only owners + stylists offered)
- Real-time slot availability via find_available_slots RPC

### Salon Storefront
- Public portfolio page: beautycita.com/salon/{slug}
- Services, staff, before/after gallery, reviews, products
- One-tap booking via Cita Express integration
- OG meta tags for social sharing
- Mobile-first responsive design

### Staff System
- PIN-protected QR code for portfolio photo uploads (no app needed)
- Consent-based account linking (staff must accept invitation)
- Monthly email reports for stylists (services, commissions, payments)
- Position-based panel access restrictions

### Image System
- Universal image editor: crop (free/1:1/4:3/16:9) + optional watermark
- Rear camera default, front for selfies
- All upload paths through editor before DB submission

### Legal Compliance
- RFC: BEA260313MI8 on all documents
- LFPDPPP privacy policy: 100% compliant (12 third-party transfer disclosures)
- PROFECO 5-day withdrawal right
- Gift card terms, loyalty terms, seller agreement
- Dispute resolution timeline (10/20 business days) + PROFECO escalation

### Web App (58+ pages)
- Full parity: CRM, marketing, gift cards, analytics, orders, tax reports, RP tracking, notification templates, admin chat
- Desktop-first design with responsive mobile support

### Security
- RLS enabled on all tables
- Edge function auth verification on all non-public endpoints
- Error message sanitization (no internal details leaked)
- Sentry error tracking with PII scrubbing
- File upload validation (10MB, magic bytes)

---

## v1.1.0 — Platform Hardening (March 2026)

### Quality Pass
- 31 issues fixed: SizedBox.shrink blank screens, null safety, validation
- Booking model: paymentMethod field added
- Stripe webhook: JSON.parse safety, race condition guard
- Route guards on unsafe state.extra casts

### Data Integrity
- Tax withholding backfill: 57 appointments with ISR/IVA data
- Staff-service links verified for all bookable staff
- Commission records backfilled for all paid appointments

---

## v1.0.8 — Design System + Web Redesign (March 2026)

### Design
- Approved design system: DESIGN-SYSTEM.md locked
- Lila (#C8A2C8) brand gradient standardized
- 250ms fade transitions, shredder animation for cancellations

### Web Rebuild
- 49 pages redesigned desktop-first
- Business portal: dashboard, calendar (Gantt), services, staff, payments
- Admin portal: 22 pages with data tables and side panels

---

## v1.0.5 — Security + Monitoring (March 2026)

### Security Audit
- 8 critical + 11 high issues fixed
- CORS locked, error sanitization, RLS tightening
- Honeypot system: 13 trap categories, fail2ban auto-ban

### Monitoring
- Grafana: 5 dashboards (Server Health, Database, Endpoints, Backups, Honeypot)
- Prometheus + Loki integration
- UptimeRobot: 4 monitors with email alerts

### Legal
- Privacy policy: 16 sections, LFPDPPP compliant
- Terms of service: commission rates, cancellation policy, tax withholding

---

## v1.0.0 — Initial Launch (February 2026)

### Core Platform
- Intelligent booking agent: service type → curated top 3 results
- 20+ beauty service categories with subcategories
- Stripe Connect payment processing
- Biometric-only registration with auto-generated usernames

### Business Portal
- Calendar, services CRUD, staff management
- Stripe onboarding, payment tracking
- Dispute resolution workflow

### AI Features
- Aphrodite: beauty advisor (GPT-4o)
- Eros: support agent (GPT-4o-mini)
- Virtual Studio: 4 tools (hair color, hairstyle, headshot, face swap)

### Infrastructure
- Self-hosted Supabase (PostgreSQL, Edge Functions, Realtime, Storage)
- Cloudflare R2 for media
- 55+ edge functions
- 67,000+ discovered salons in Mexico

---

## v0.9.0 — Foundation (January 2026)

### Architecture
- Flutter mobile app (Android API 29+)
- Flutter web app (desktop-first)
- Shared package: beautycita_core (models, theme, Supabase client)
- Booking engine design specification
- Scraper infrastructure on beautypi (Raspberry Pi)

---

*BeautyCita — Reservas inteligentes de belleza*
*RFC: BEA260313MI8 | beautycita.com*
